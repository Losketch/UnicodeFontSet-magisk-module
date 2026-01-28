use anyhow::{Context, Result};
use read_fonts::{FontRef, TableProvider};
use std::fs;
use write_fonts::{
    FontBuilder,
    tables::cmap::Cmap,
    types::GlyphId,
};
use tracing::{debug, trace};

pub fn rewrite_font(
    src_path: &str,
    dst_path: &str,
    keep_runes: &[u32],
) -> Result<()> {
    debug!(src = src_path, dst = dst_path, keep = keep_runes.len(), "rewrite font");

    let font_data = fs::read(src_path)
        .with_context(|| format!("读取字体文件失败: {}", src_path))?;

    let font_ref = FontRef::new(&font_data)
        .with_context(|| format!("解析字体数据失败: {}", src_path))?;

    if font_ref.cff().is_ok() {
        debug!("检测到 CFF 表格");
    } else if font_ref.cff2().is_ok() {
        debug!("检测到 CFF2 表格");
    }

    let char_to_gid: Vec<(char, GlyphId)> = keep_runes
        .iter()
        .filter_map(|&cp| {
            trace!(cp = format_args!("U+{:X}", cp), "map rune");
            let ch = std::char::from_u32(cp)?;
            let gid = font_ref.cmap().ok()?.map_codepoint(ch)?;
            Some((ch, gid))
        })
        .collect();

    debug!(mappings = char_to_gid.len(), "cmap mappings built");

    let cmap = Cmap::from_mappings(char_to_gid)
        .context("构建 cmap 表格失败")?;

    let mut builder = FontBuilder::new();
    builder.copy_missing_tables(font_ref);
    builder.add_table(&cmap)
        .context("添加 cmap 表格失败")?;

    let out = builder.build();

    if let Some(parent) = std::path::Path::new(dst_path).parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("创建目录失败: {:?}", parent))?;
    }

    fs::write(dst_path, &out)
        .with_context(|| format!("写入字体文件失败: {}", dst_path))?;

    Ok(())
}
