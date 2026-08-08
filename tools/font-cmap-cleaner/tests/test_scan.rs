use std::collections::{HashMap, HashSet};
use std::path::PathBuf;

use font_cmap_tool::scan::scan_effective_system_unicode;

fn fixture(path: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(path)
}

#[test]
fn scan_system_unicode_basic() {
    let mut effective = HashMap::new();
    effective.insert("TestSystem.ttf".to_string(), HashSet::from([0]));

    let set = scan_effective_system_unicode(&fixture("system_fonts"), &effective, 1000).unwrap();

    assert!(set.contains(&0x41));
}

#[test]
fn scan_ignores_legacy_encoding_slots_in_c1_range() {
    let mut effective = HashMap::new();
    effective.insert("C1LegacySlot.ttf".to_string(), HashSet::from([0]));

    let set = scan_effective_system_unicode(&fixture("edge_fonts"), &effective, 1000).unwrap();

    assert!(set.contains(&0x41));
    assert!(!set.contains(&0x80));
}

#[test]
fn scan_keeps_real_unicode_c1_mappings() {
    let mut effective = HashMap::new();
    effective.insert("C1Unicode.ttf".to_string(), HashSet::from([0]));

    let set = scan_effective_system_unicode(&fixture("edge_fonts"), &effective, 1000).unwrap();

    for codepoint in 0x80..=0x9F {
        assert!(set.contains(&codepoint), "missing U+{codepoint:04X}");
    }
}

#[test]
fn ttc_threshold_is_applied_per_face_not_to_collection_union() {
    let mut effective = HashMap::new();
    effective.insert("CollectionOnly.ttc".to_string(), HashSet::from([0, 1]));

    let set = scan_effective_system_unicode(&fixture("find_fonts"), &effective, 2).unwrap();

    assert!(set.contains(&0x41));
    assert!(set.contains(&0x42));
    assert!(!set.contains(&0x43));
}

#[test]
fn ttc_scan_honors_fonts_xml_face_index() {
    let mut effective = HashMap::new();
    effective.insert("CollectionOnly.ttc".to_string(), HashSet::from([1]));

    let set = scan_effective_system_unicode(&fixture("find_fonts"), &effective, 1000).unwrap();

    assert!(set.contains(&0x43));
}

#[test]
fn ttc_scan_does_not_include_unreferenced_face() {
    let mut effective = HashMap::new();
    effective.insert("CollectionOnly.ttc".to_string(), HashSet::from([0]));

    let set = scan_effective_system_unicode(&fixture("find_fonts"), &effective, 1000).unwrap();

    assert!(set.contains(&0x41));
    assert!(set.contains(&0x42));
    assert!(!set.contains(&0x43));
}

#[test]
fn scan_can_shadow_stock_by_filename() {
    let mut effective = HashMap::new();
    effective.insert("TestSystem.ttf".to_string(), HashSet::from([0]));
    let shadowed = HashSet::from(["TestSystem.ttf".to_string()]);
    let result = font_cmap_tool::scan::scan_effective_system_view(
        &fixture("system_fonts"),
        &effective,
        1000,
        &shadowed,
        &HashSet::new(),
    )
    .unwrap();
    assert!(!result.unicode.contains(&0x41));
}
