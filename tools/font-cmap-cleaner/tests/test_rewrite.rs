use tempfile::tempdir;
use font_cmap_tool::rewrite::rewrite_font;
use ttf_parser::Face;
use std::fs;

#[test]
fn rewrite_font_keeps_only_specified_chars() {
    let dir = tempdir().unwrap();

    let src = "tests/fixtures/module_fonts/TestModule.ttf";
    let dst = dir.path().join("out.ttf");

    rewrite_font(src, dst.to_str().unwrap(), &[0x41]).unwrap();

    let data = fs::read(dst).unwrap();
    let face = Face::parse(&data, 0).unwrap();

    let mut chars = Vec::new();
    if let Some(cmap) = face.tables().cmap {
        for sub in cmap.subtables {
            sub.codepoints(|cp| chars.push(cp));
        }
    }

    assert!(chars.contains(&0x41));
    assert!(!chars.contains(&0x42));
}
