use std::{collections::BTreeSet, fs, path::Path};

use anyhow::{bail, Context, Result};
use read_fonts::{FontRef, TableProvider};
use tracing::{debug, trace};
use ttf_parser::Face;
use write_fonts::{
    dump_table,
    tables::cmap::Cmap,
    types::{GlyphId, Tag as WriteTag},
    FontBuilder,
};

use crate::font::unicode_glyph_index;

#[derive(Clone, Debug, Eq, PartialEq)]
struct RawCmapRecord {
    platform_id: u16,
    encoding_id: u16,
    subtable: Vec<u8>,
}

pub fn rewrite_font(src_path: &str, dst_path: &str, keep_runes: &[u32]) -> Result<()> {
    debug!(
        src = src_path,
        dst = dst_path,
        keep = keep_runes.len(),
        "rewrite font"
    );

    let font_data =
        fs::read(src_path).with_context(|| format!("读取字体文件失败: {}", src_path))?;
    let font_ref =
        FontRef::new(&font_data).with_context(|| format!("解析字体数据失败: {}", src_path))?;
    let parser_face =
        Face::parse(&font_data, 0).with_context(|| format!("解析字体 cmap 失败: {}", src_path))?;

    if font_ref.cff().is_ok() {
        debug!("检测到 CFF 表格");
    } else if font_ref.cff2().is_ok() {
        debug!("检测到 CFF2 表格");
    }

    let effective_keep: BTreeSet<u32> = keep_runes.iter().copied().collect();
    if effective_keep.is_empty() {
        bail!("拒绝生成空 Unicode cmap；过滤后无保留映射时应由上层省略该字体");
    }

    let mut char_to_gid: Vec<(char, GlyphId)> = effective_keep
        .iter()
        .filter_map(|&codepoint| {
            trace!(cp = format_args!("U+{:X}", codepoint), "map rune");
            let character = char::from_u32(codepoint)?;
            let glyph_id = unicode_glyph_index(&parser_face, codepoint)?;
            Some((character, GlyphId::new(u32::from(glyph_id.0))))
        })
        .collect();

    char_to_gid.sort_unstable_by_key(|(character, _)| *character as u32);
    char_to_gid.dedup_by_key(|(character, _)| *character as u32);

    if char_to_gid.is_empty() {
        bail!("请求保留的码位在 Unicode cmap 中均无有效 glyph 映射");
    }

    debug!(mappings = char_to_gid.len(), "cmap mappings built");

    let nominal_cmap = Cmap::from_mappings(char_to_gid).context("构建 cmap 表格失败")?;
    let nominal_bytes = dump_table(&nominal_cmap).context("序列化 cmap 表格失败")?;
    let source_cmap = parser_face
        .raw_face()
        .table(ttf_parser::Tag::from_bytes(b"cmap"))
        .context("源字体缺少有效 cmap 表格")?;
    let cmap_bytes = merge_nominal_cmap_with_uvs(&nominal_bytes, source_cmap)
        .context("保留 cmap format 14 (UVS/IVS) 失败")?;

    let mut builder = FontBuilder::new();
    builder.copy_missing_tables(font_ref);
    builder.add_raw(WriteTag::new(b"cmap"), cmap_bytes);

    let output = builder.build();

    if let Some(parent) = Path::new(dst_path).parent() {
        fs::create_dir_all(parent).with_context(|| format!("创建目录失败: {:?}", parent))?;
    }

    fs::write(dst_path, &output).with_context(|| format!("写入字体文件失败: {}", dst_path))?;

    Ok(())
}

fn merge_nominal_cmap_with_uvs(nominal: &[u8], source: &[u8]) -> Result<Vec<u8>> {
    let mut records = parse_cmap_records(nominal)?;

    for record in extract_format14_records(source)? {
        if !records.contains(&record) {
            records.push(record);
        }
    }

    build_cmap(&records)
}

fn parse_cmap_records(cmap: &[u8]) -> Result<Vec<RawCmapRecord>> {
    let count = cmap_record_count(cmap)?;
    let mut records = Vec::with_capacity(count);

    for index in 0..count {
        let record_offset = 4 + index * 8;
        let platform_id = read_u16(cmap, record_offset)?;
        let encoding_id = read_u16(cmap, record_offset + 2)?;
        let subtable_offset = read_u32(cmap, record_offset + 4)? as usize;
        let length = cmap_subtable_length(cmap, subtable_offset)?;
        let end = subtable_offset
            .checked_add(length)
            .context("cmap subtable 长度溢出")?;
        let subtable = cmap
            .get(subtable_offset..end)
            .context("cmap subtable 数据越界")?
            .to_vec();

        records.push(RawCmapRecord {
            platform_id,
            encoding_id,
            subtable,
        });
    }

    Ok(records)
}

fn extract_format14_records(cmap: &[u8]) -> Result<Vec<RawCmapRecord>> {
    let count = cmap_record_count(cmap)?;
    let mut records = Vec::new();

    for index in 0..count {
        let record_offset = 4 + index * 8;
        let subtable_offset = read_u32(cmap, record_offset + 4)? as usize;
        if read_u16(cmap, subtable_offset)? != 14 {
            continue;
        }

        let platform_id = read_u16(cmap, record_offset)?;
        let encoding_id = read_u16(cmap, record_offset + 2)?;
        let length = read_u32(cmap, checked_offset(subtable_offset, 2)?)? as usize;
        if length == 0 {
            bail!("cmap format 14 subtable 长度为 0");
        }
        let end = subtable_offset
            .checked_add(length)
            .context("cmap format 14 subtable 长度溢出")?;
        let subtable = cmap
            .get(subtable_offset..end)
            .context("cmap format 14 subtable 数据越界")?
            .to_vec();

        records.push(RawCmapRecord {
            platform_id,
            encoding_id,
            subtable,
        });
    }

    Ok(records)
}

fn cmap_record_count(cmap: &[u8]) -> Result<usize> {
    if read_u16(cmap, 0)? != 0 {
        bail!("不支持的 cmap table version");
    }

    let count = read_u16(cmap, 2)? as usize;
    let records_end = 4usize
        .checked_add(count.checked_mul(8).context("cmap record 数量溢出")?)
        .context("cmap record directory 溢出")?;
    if records_end > cmap.len() {
        bail!("cmap encoding record directory 越界");
    }

    Ok(count)
}

fn cmap_subtable_length(cmap: &[u8], offset: usize) -> Result<usize> {
    let format = read_u16(cmap, offset)?;
    let length = match format {
        0 | 2 | 4 | 6 => read_u16(cmap, checked_offset(offset, 2)?)? as usize,
        8 | 10 | 12 | 13 => read_u32(cmap, checked_offset(offset, 4)?)? as usize,
        14 => read_u32(cmap, checked_offset(offset, 2)?)? as usize,
        _ => bail!("不支持的 cmap subtable format: {}", format),
    };

    if length == 0 {
        bail!("cmap subtable format {} 长度为 0", format);
    }
    Ok(length)
}

fn build_cmap(records: &[RawCmapRecord]) -> Result<Vec<u8>> {
    let count = u16::try_from(records.len()).context("cmap encoding record 过多")?;
    let directory_len = 4usize
        .checked_add(
            records
                .len()
                .checked_mul(8)
                .context("cmap directory 溢出")?,
        )
        .context("cmap directory 溢出")?;

    let mut output = vec![0u8; directory_len];
    write_u16(&mut output, 0, 0)?;
    write_u16(&mut output, 2, count)?;

    for (index, record) in records.iter().enumerate() {
        while output.len() % 4 != 0 {
            output.push(0);
        }

        let subtable_offset = u32::try_from(output.len()).context("cmap table 超过 4 GiB")?;
        let record_offset = 4 + index * 8;
        write_u16(&mut output, record_offset, record.platform_id)?;
        write_u16(&mut output, record_offset + 2, record.encoding_id)?;
        write_u32(&mut output, record_offset + 4, subtable_offset)?;
        output.extend_from_slice(&record.subtable);
    }

    Ok(output)
}

fn checked_offset(offset: usize, delta: usize) -> Result<usize> {
    offset.checked_add(delta).context("cmap offset 溢出")
}

fn read_u16(data: &[u8], offset: usize) -> Result<u16> {
    let end = checked_offset(offset, 2)?;
    let bytes: [u8; 2] = data
        .get(offset..end)
        .context("读取 u16 越界")?
        .try_into()
        .expect("slice length checked");
    Ok(u16::from_be_bytes(bytes))
}

fn read_u32(data: &[u8], offset: usize) -> Result<u32> {
    let end = checked_offset(offset, 4)?;
    let bytes: [u8; 4] = data
        .get(offset..end)
        .context("读取 u32 越界")?
        .try_into()
        .expect("slice length checked");
    Ok(u32::from_be_bytes(bytes))
}

fn write_u16(data: &mut [u8], offset: usize, value: u16) -> Result<()> {
    data.get_mut(offset..offset + 2)
        .context("写入 u16 越界")?
        .copy_from_slice(&value.to_be_bytes());
    Ok(())
}

fn write_u32(data: &mut [u8], offset: usize, value: u32) -> Result<()> {
    data.get_mut(offset..offset + 4)
        .context("写入 u32 越界")?
        .copy_from_slice(&value.to_be_bytes());
    Ok(())
}
