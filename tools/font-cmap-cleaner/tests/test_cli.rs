use assert_cmd::cargo::cargo_bin_cmd;
use predicates::str::contains;

#[test]
fn cli_dry_run_works() {
    let mut cmd = cargo_bin_cmd!("font-cmap-tool");

    cmd.args(&[
        "-s", "tests/fixtures/system_fonts",
        "-m", "tests/fixtures/module_fonts",
        "--fonts-xml", "tests/fixtures/fonts.xml",
        "--dry-run",
    ]);

    cmd.assert()
        .success()
        .stdout(contains("系统 Unicode 扫描完成"));
}
