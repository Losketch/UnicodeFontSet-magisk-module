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
        .arg("--font-policy")
        .arg(fixture("policy_testmodule.tsv"))
        .arg("--dry-run");

    cmd.assert()
        .success()
        .stdout(contains("系统字体字符统计完成"));
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
fn output_mode_omits_fully_covered_font_instead_of_emitting_zero_coverage_font() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("out");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("-s")
        .arg(fixture("system_fonts"))
        .arg("-m")
        .arg(fixture("fully_covered_module"))
        .arg("--fonts-xml")
        .arg(fixture("fonts.xml"))
        .arg("--font-policy")
        .arg(fixture("policy_fully_covered.tsv"))
        .arg("--output")
        .arg(&output);

    cmd.assert()
        .success()
        .stdout(contains("没有可保留的 Unicode 映射"));

    assert!(
        !output.join("FullyCovered.ttf").exists(),
        "fully covered font must be omitted instead of emitting a zero-coverage font"
    );
}

#[test]
fn inplace_mode_removes_fully_covered_font() {
    let dir = tempfile::tempdir().unwrap();
    let module = dir.path().join("module");
    std::fs::create_dir_all(&module).unwrap();
    std::fs::copy(
        fixture("fully_covered_module/FullyCovered.ttf"),
        module.join("FullyCovered.ttf"),
    )
    .unwrap();

    let mut cmd = cargo_bin_cmd!("font-cmap-tool");
    cmd.arg("-s")
        .arg(fixture("system_fonts"))
        .arg("-m")
        .arg(&module)
        .arg("--fonts-xml")
        .arg(fixture("fonts.xml"))
        .arg("--font-policy")
        .arg(fixture("policy_fully_covered.tsv"));

    cmd.assert().success();
    assert!(!module.join("FullyCovered.ttf").exists());
}

#[test]
fn font_policy_protect_and_remove_ranges_drive_nominal_cmap_filtering() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("out");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("-s")
        .arg(fixture("system_fonts"))
        .arg("-m")
        .arg(fixture("module_fonts"))
        .arg("--fonts-xml")
        .arg(fixture("fonts.xml"))
        .arg("--font-policy")
        .arg(fixture("policy_range_filter.tsv"))
        .arg("--output")
        .arg(&output);

    cmd.assert().success();

    assert_eq!(
        font_codepoints(&output.join("TestModule.ttf")),
        std::collections::HashSet::from([0x42])
    );
}

#[test]
fn standalone_filter_subcommand_removes_requested_ranges() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("Filtered.ttf");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("filter")
        .arg(fixture("module_fonts/TestModule.ttf"))
        .arg("--remove")
        .arg("[41,43]")
        .arg("--output")
        .arg(&output);

    cmd.assert()
        .success()
        .stdout(contains("将删除: 2"))
        .stdout(contains("完成:"));

    assert_eq!(
        font_codepoints(&output),
        std::collections::HashSet::from([0x42])
    );
}

#[test]
fn standalone_filter_keep_only_retains_requested_ranges() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("Kept.ttf");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("filter")
        .arg(fixture("module_fonts/TestModule.ttf"))
        .arg("--keep")
        .arg("[41-42]")
        .arg("--output")
        .arg(&output);

    cmd.assert()
        .success()
        .stdout(contains("将删除: 1"))
        .stdout(contains("完成:"));

    assert_eq!(
        font_codepoints(&output),
        std::collections::HashSet::from([0x41, 0x42])
    );
}

#[test]
fn standalone_filter_keep_and_remove_can_be_combined() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("KeptAndRemoved.ttf");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("filter")
        .arg(fixture("module_fonts/TestModule.ttf"))
        .arg("--keep")
        .arg("[41-43]")
        .arg("--remove")
        .arg("42")
        .arg("--output")
        .arg(&output);

    cmd.assert().success();

    assert_eq!(
        font_codepoints(&output),
        std::collections::HashSet::from([0x41, 0x43])
    );
}

#[test]
fn standalone_filter_requires_at_least_one_range_operation() {
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("filter")
        .arg(fixture("module_fonts/TestModule.ttf"));

    cmd.assert()
        .failure()
        .stderr(contains("--keep"))
        .stderr(contains("--remove"));
}

#[test]
fn standalone_filter_dry_run_does_not_write_output() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("Filtered.ttf");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("filter")
        .arg(fixture("module_fonts/TestModule.ttf"))
        .arg("--remove")
        .arg("41")
        .arg("--output")
        .arg(&output)
        .arg("--dry-run");

    cmd.assert()
        .success()
        .stdout(contains("预览完成，未修改文件"));
    assert!(!output.exists());
}

#[test]
fn standalone_filter_rejects_font_collections() {
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.arg("filter")
        .arg(fixture("find_fonts/CollectionOnly.ttc"))
        .arg("--remove")
        .arg("43");

    cmd.assert().failure().stderr(contains("TTC/OTC 字体集合"));
}

fn font_codepoints(path: &std::path::Path) -> std::collections::HashSet<u32> {
    let data = std::fs::read(path).unwrap();
    let face = ttf_parser::Face::parse(&data, 0).unwrap();
    font_cmap_tool::font::unicode_codepoints(&face)
}

#[test]
fn ordered_intra_ufs_dedup_uses_prior_retained_fallbacks_as_baseline() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("out");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");
    cmd.arg("-s")
        .arg(fixture("ordered/system"))
        .arg("-m")
        .arg(fixture("ordered/module"))
        .arg("--fonts-xml")
        .arg(fixture("ordered/fonts.xml"))
        .arg("--font-policy")
        .arg(fixture("ordered/policy.tsv"))
        .arg("--output")
        .arg(&output);
    cmd.assert().success();

    assert_eq!(
        font_codepoints(&output.join("First.ttf")),
        std::collections::HashSet::from([0x43])
    );
    assert_eq!(
        font_codepoints(&output.join("Second.ttf")),
        std::collections::HashSet::from([0x44])
    );
}

#[test]
fn system_overlay_shadows_stock_font_before_normal_fallback_dedup() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("out");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");
    cmd.arg("-s")
        .arg(fixture("shadow/system"))
        .arg("-m")
        .arg(fixture("shadow/module"))
        .arg("--fonts-xml")
        .arg(fixture("shadow/fonts.xml"))
        .arg("--font-policy")
        .arg(fixture("shadow/policy.tsv"))
        .arg("--output")
        .arg(&output);
    cmd.assert().success();

    // Stock Overlay.ttf contains U+0041, but module Overlay.ttf shadows it and only contains U+0043.
    // Therefore the normal fallback must retain U+0041 and U+0044.
    assert_eq!(
        font_codepoints(&output.join("Fallback.ttf")),
        std::collections::HashSet::from([0x41, 0x44])
    );
    assert_eq!(
        std::fs::read(fixture("shadow/module/Overlay.ttf")).unwrap(),
        std::fs::read(output.join("Overlay.ttf")).unwrap()
    );
}

#[test]
fn omitted_system_overlay_restores_stock_font_to_baseline() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("out");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");
    cmd.arg("-s")
        .arg(fixture("shadow/system"))
        .arg("-m")
        .arg(fixture("shadow/module"))
        .arg("--fonts-xml")
        .arg(fixture("shadow/fonts.xml"))
        .arg("--font-policy")
        .arg(fixture("shadow/policy_overlay_empty.tsv"))
        .arg("--output")
        .arg(&output);
    cmd.assert().success();

    // Overlay.ttf is removed by policy, so it must not shadow stock U+0041.
    assert!(!output.join("Overlay.ttf").exists());
    assert_eq!(
        font_codepoints(&output.join("Fallback.ttf")),
        std::collections::HashSet::from([0x44])
    );
}

#[test]
fn active_data_font_shadows_stock_postscript_name_in_baseline() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().join("out");
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");
    cmd.arg("-s")
        .arg(fixture("updatable/system"))
        .arg("-m")
        .arg(fixture("updatable/module"))
        .arg("--fonts-xml")
        .arg(fixture("updatable/fonts.xml"))
        .arg("--font-policy")
        .arg(fixture("updatable/policy.tsv"))
        .arg("--updatable-font-dir")
        .arg(fixture("updatable/data"))
        .arg("--updatable-config")
        .arg(fixture("updatable/config.xml"))
        .arg("--output")
        .arg(&output);
    cmd.assert().success();

    // Stock SharedUpdatePS contains U+0041 but the active /data font replaces it with U+0043.
    // U+0041 must therefore remain available from the UFS fallback. The active NamedOnlyPS font
    // contains U+0045 but is referenced only by a persistent named family, so U+0045 must also stay.
    assert_eq!(
        font_codepoints(&output.join("Fallback.ttf")),
        std::collections::HashSet::from([0x41, 0x44, 0x45])
    );
}

#[test]
fn find_reports_provenance_and_collection_face() {
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");
    cmd.arg("-s")
        .arg(fixture("find_fonts"))
        .arg("find")
        .arg("43");
    cmd.assert()
        .success()
        .stdout(contains("[custom]"))
        .stdout(contains("CollectionOnly.ttc#face=1"));
}
