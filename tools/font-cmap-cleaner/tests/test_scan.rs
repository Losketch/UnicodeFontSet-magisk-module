use std::path::Path;
use std::collections::HashSet;
use font_cmap_tool::scan::scan_effective_system_unicode;

#[test]
fn scan_system_unicode_basic() {
    let mut effective = HashSet::new();
    effective.insert("TestSystem.ttf".to_string());

    let set = scan_effective_system_unicode(
        Path::new("tests/fixtures/system_fonts"),
        &effective,
        1000,
    ).unwrap();

    assert!(set.contains(&0x41));
}
