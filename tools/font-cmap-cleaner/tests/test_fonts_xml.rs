use std::path::PathBuf;

use font_cmap_tool::fonts_xml::parse_fonts_xml;

fn fixture(path: &str) -> PathBuf {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(path);

    assert!(path.exists(), "missing test fixture: {}", path.display());

    path
}

#[test]
fn parse_fonts_xml_basic() {
    let fonts = parse_fonts_xml(&fixture("fonts.xml")).unwrap();

    assert_eq!(
        fonts.get("TestSystem.ttf"),
        Some(&std::collections::HashSet::from([0]))
    );
    assert!(!fonts.contains_key("Fallback.ttf"));
}

#[test]
fn parse_fonts_xml_preserves_collection_face_index() {
    let fonts = parse_fonts_xml(&fixture("fonts_index.xml")).unwrap();

    assert_eq!(
        fonts.get("CollectionOnly.ttc"),
        Some(&std::collections::HashSet::from([1]))
    );
    assert_eq!(
        fonts.get("TestSystem.ttf"),
        Some(&std::collections::HashSet::from([0]))
    );
}

#[test]
fn parse_fonts_xml_excludes_later_named_families_from_global_fallback() {
    let fonts = parse_fonts_xml(&fixture("fonts_named_families.xml")).unwrap();

    assert!(fonts.contains_key("DefaultNamed.ttf"));
    assert!(fonts.contains_key("GlobalFallback.ttf"));
    assert!(!fonts.contains_key("SerifOnly.ttf"));
    assert!(!fonts.contains_key("SerifSpecificFallback.ttf"));
    assert!(!fonts.contains_key("OptionalNamedList.ttf"));
}
