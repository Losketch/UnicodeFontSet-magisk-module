use std::path::Path;
use font_cmap_tool::fonts_xml::parse_fonts_xml;

#[test]
fn parse_fonts_xml_basic() {
    let path = Path::new("tests/fixtures/fonts.xml");

    let fonts = parse_fonts_xml(path).unwrap();

    assert!(fonts.contains("TestSystem.ttf"));
    assert!(!fonts.contains("Fallback.ttf"));
}
