use std::{collections::HashSet, ops::Range, path::Path};

use read_fonts::{tables::cmap::CmapSubtable, FontRef, TableProvider};
use ttf_parser::{Face, GlyphId};

pub fn face_indices(data: &[u8]) -> Range<u32> {
    0..ttf_parser::fonts_in_collection(data).unwrap_or(1).max(1)
}

pub fn is_font_path(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| {
            extension.eq_ignore_ascii_case("ttf")
                || extension.eq_ignore_ascii_case("otf")
                || extension.eq_ignore_ascii_case("ttc")
                || extension.eq_ignore_ascii_case("otc")
        })
}

pub fn is_rewritable_font_path(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| {
            extension.eq_ignore_ascii_case("ttf") || extension.eq_ignore_ascii_case("otf")
        })
}

pub fn postscript_name(face: &Face<'_>) -> Option<String> {
    face.names()
        .into_iter()
        .find(|name| name.name_id == ttf_parser::name_id::POST_SCRIPT_NAME && name.is_unicode())
        .and_then(|name| name.to_string())
}

pub fn unicode_codepoints(face: &Face<'_>) -> HashSet<u32> {
    let mut result = HashSet::new();

    let Some(cmap) = face.tables().cmap else {
        return result;
    };

    for subtable in cmap.subtables {
        if !subtable.is_unicode() {
            continue;
        }

        subtable.codepoints(|codepoint| {
            if char::from_u32(codepoint).is_some() && subtable.glyph_index(codepoint).is_some() {
                result.insert(codepoint);
            }
        });
    }

    result
}

pub fn unicode_glyph_index(face: &Face<'_>, codepoint: u32) -> Option<GlyphId> {
    char::from_u32(codepoint).and_then(|character| face.glyph_index(character))
}

pub fn variation_sequence_base_codepoints(data: &[u8]) -> HashSet<u32> {
    let mut result = HashSet::new();

    let Ok(font) = FontRef::new(data) else {
        return result;
    };
    let Ok(cmap) = font.cmap() else {
        return result;
    };
    for (index, _) in cmap.encoding_records().iter().enumerate() {
        let Ok(CmapSubtable::Format14(cmap14)) = cmap.subtable(index as u16) else {
            continue;
        };

        result.extend(
            cmap14
                .iter()
                .map(|(codepoint, _, _)| codepoint)
                .filter(|codepoint| char::from_u32(*codepoint).is_some()),
        );
    }

    result
}
