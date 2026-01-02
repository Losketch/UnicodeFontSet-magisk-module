use anyhow::Result;
use read_fonts::FontRef;
use std::fs;
use ttf_parser::Face;
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

    let font_data = fs::read(src_path)?;
    let face = Face::parse(&font_data, 0)?;
    let font_ref = FontRef::new(&font_data)?;

    let char_to_gid: Vec<(char, GlyphId)> = keep_runes
        .iter()
        .filter_map(|&cp| {
            trace!(cp = format_args!("U+{:X}", cp), "map rune");
            let ch = std::char::from_u32(cp)?;
            let gid = face.glyph_index(ch)?;
            Some((ch, GlyphId::new(gid.0 as u32)))
        })
        .collect();

    debug!(mappings = char_to_gid.len(), "cmap mappings built");

    let cmap = Cmap::from_mappings(char_to_gid)?;

    let mut builder = FontBuilder::new();
    builder.copy_missing_tables(font_ref);
    builder.add_table(&cmap)?;

    let out = builder.build();

    if let Some(parent) = std::path::Path::new(dst_path).parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(dst_path, out)?;
    Ok(())
}
