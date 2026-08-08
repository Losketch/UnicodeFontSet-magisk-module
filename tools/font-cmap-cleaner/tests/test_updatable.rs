use std::path::PathBuf;

use font_cmap_tool::updatable::{collect_active_updated_faces, parse_updatable_config};

fn fixture(path: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(path)
}

#[test]
fn parses_active_updated_dirs_and_collects_postscript_faces() {
    let config = parse_updatable_config(&fixture("updatable/config.xml")).unwrap();
    assert!(config.active_dirs.contains("~~active"));
    assert!(config.active_dirs.contains("~~named"));
    assert!(!config.active_dirs.contains("~~not-an-active-dir"));
    assert!(config.family_postscript_names.contains("SharedUpdatePS"));
    assert!(config.family_postscript_names.contains("NamedOnlyPS"));
    let faces = collect_active_updated_faces(&fixture("updatable/data"), &config).unwrap();
    let updated = faces.get("SharedUpdatePS").unwrap();
    assert!(updated.unicode.contains(&0x43));
    assert!(!updated.unicode.contains(&0x41));
    let named_only = faces.get("NamedOnlyPS").unwrap();
    assert!(named_only.unicode.contains(&0x45));
}
