use std::path::PathBuf;

use assert_cmd::cargo::cargo_bin_cmd;
use predicates::prelude::*;
use predicates::str::contains;

fn fixture(path: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(path)
}

#[test]
fn cli_dry_run_works() {
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("-s")
        .arg(fixture("system_fonts"))
        .arg("-m")
        .arg(fixture("module_fonts"))
        .arg("--fonts-xml")
        .arg(fixture("fonts.xml"))
        .arg("--dry-run");

    cmd.assert()
        .success()
        .stdout(contains("系统 Unicode 扫描完成"));
}

#[test]
fn find_does_not_require_fonts_xml_and_searches_all_ttc_faces() {
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("-s")
        .arg(fixture("find_fonts"))
        .arg("find")
        .arg("43");

    cmd.assert()
        .success()
        .stdout(contains("CollectionOnly.ttc"));
}

#[test]
fn find_distinguishes_unicode_u0080_from_legacy_encoding_slot_0x80() {
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("-s")
        .arg(fixture("find_fonts"))
        .arg("find")
        .arg("U+0080");

    cmd.assert()
        .success()
        .stdout(contains("C1Unicode.ttf"))
        .stdout(predicate::str::contains("C1LegacySlot.ttf").not());
}

#[test]
fn output_mode_keeps_fully_covered_font_instead_of_dropping_file() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("out");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("-s")
        .arg(fixture("system_fonts"))
        .arg("-m")
        .arg(fixture("fully_covered_module"))
        .arg("--fonts-xml")
        .arg(fixture("fonts.xml"))
        .arg("--output")
        .arg(&output);

    cmd.assert().success();

    let source = fixture("fully_covered_module/FullyCovered.ttf");
    let copied = output.join("FullyCovered.ttf");
    assert!(copied.is_file());
    assert_eq!(
        std::fs::read(source).unwrap(),
        std::fs::read(copied).unwrap()
    );
}
