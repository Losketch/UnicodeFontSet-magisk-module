use std::{collections::HashSet, fs, path::PathBuf};

use font_cmap_tool::rewrite::rewrite_font;
use tempfile::tempdir;
use ttf_parser::Face;

fn fixture(path: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(path)
}

fn unicode_codepoints(path: &std::path::Path) -> HashSet<u32> {
    let data = fs::read(path).unwrap();
    let face = Face::parse(&data, 0).unwrap();
    let mut chars = HashSet::new();

    if let Some(cmap) = face.tables().cmap {
        for subtable in cmap.subtables {
            if !subtable.is_unicode() {
                continue;
            }
            subtable.codepoints(|codepoint| {
                if subtable.glyph_index(codepoint).is_some() {
                    chars.insert(codepoint);
                }
            });
        }
    }

    chars
}

#[test]
fn rewrite_font_keeps_only_specified_chars() {
    let dir = tempdir().unwrap();
    let src = fixture("module_fonts/TestModule.ttf");
    let dst = dir.path().join("out.ttf");

    rewrite_font(
        src.to_str().expect("fixture path must be valid UTF-8"),
        dst.to_str().expect("temporary path must be valid UTF-8"),
        &[0x41],
    )
    .unwrap();

    let chars = unicode_codepoints(&dst);
    assert!(chars.contains(&0x41));
    assert!(!chars.contains(&0x42));
}

#[test]
fn rewrite_font_preserves_real_unicode_c1_range() {
    let dir = tempdir().unwrap();
    let src = fixture("edge_fonts/C1Unicode.ttf");
    let dst = dir.path().join("c1-out.ttf");
    let keep: Vec<u32> = (0x80..=0x9F).collect();

    rewrite_font(
        src.to_str().expect("fixture path must be valid UTF-8"),
        dst.to_str().expect("temporary path must be valid UTF-8"),
        &keep,
    )
    .unwrap();

    let chars = unicode_codepoints(&dst);
    for codepoint in 0x80..=0x9F {
        assert!(chars.contains(&codepoint), "missing U+{codepoint:04X}");
    }
    assert!(!chars.contains(&0x41));
}

#[test]
fn rewrite_font_does_not_promote_macroman_0x80_to_unicode_u0080() {
    let dir = tempdir().unwrap();
    let src = fixture("edge_fonts/C1LegacySlot.ttf");
    let dst = dir.path().join("legacy-out.ttf");

    let result = rewrite_font(
        src.to_str().expect("fixture path must be valid UTF-8"),
        dst.to_str().expect("temporary path must be valid UTF-8"),
        &[0x80],
    );

    assert!(result.is_err());
    assert!(!dst.exists());
}

#[test]
fn rewrite_font_preserves_uvs_when_nominal_bases_are_requested() {
    let dir = tempdir().unwrap();
    let src = fixture("edge_fonts/UvsModule.ttf");
    let dst = dir.path().join("uvs-out.ttf");

    rewrite_font(
        src.to_str().expect("fixture path must be valid UTF-8"),
        dst.to_str().expect("temporary path must be valid UTF-8"),
        &[0x41, 0x42],
    )
    .unwrap();

    let chars = unicode_codepoints(&dst);
    assert!(chars.contains(&0x41));
    assert!(chars.contains(&0x42));
    assert!(!chars.contains(&0x43));

    let data = fs::read(&dst).unwrap();
    let face = Face::parse(&data, 0).unwrap();
    assert!(face.glyph_variation_index('A', '\u{FE00}').is_some());
    assert!(face.glyph_variation_index('B', '\u{FE00}').is_some());
}

#[test]
fn rewrite_font_does_not_implicitly_restore_uvs_base_nominal_mappings() {
    let dir = tempdir().unwrap();
    let src = fixture("edge_fonts/UvsModule.ttf");
    let dst = dir.path().join("uvs-exact-out.ttf");

    rewrite_font(
        src.to_str().expect("fixture path must be valid UTF-8"),
        dst.to_str().expect("temporary path must be valid UTF-8"),
        &[0x41],
    )
    .unwrap();

    let chars = unicode_codepoints(&dst);
    assert!(chars.contains(&0x41));
    assert!(!chars.contains(&0x42));
    // format 14 is retained as raw source data; the rewrite layer controls nominal mappings only.
    let data = fs::read(&dst).unwrap();
    let face = Face::parse(&data, 0).unwrap();
    assert!(face.glyph_variation_index('A', '\u{FE00}').is_some());
}

#[test]
fn rewrite_font_rejects_empty_keep_set_and_does_not_emit_font() {
    let dir = tempdir().unwrap();
    let src = fixture("module_fonts/TestModule.ttf");
    let dst = dir.path().join("empty-out.ttf");

    let error = rewrite_font(
        src.to_str().expect("fixture path must be valid UTF-8"),
        dst.to_str().expect("temporary path must be valid UTF-8"),
        &[],
    )
    .unwrap_err();

    assert!(error.to_string().contains("空 Unicode cmap"));
    assert!(!dst.exists());
}
