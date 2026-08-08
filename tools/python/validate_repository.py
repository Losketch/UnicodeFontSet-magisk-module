#!/usr/bin/env python3
"""Static repository consistency checks that do not require Android or Rust."""

from __future__ import annotations

import os
import re
import sys
import tomllib
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_toml(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            return tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        fail(f"cannot parse {path.relative_to(ROOT)}: {exc}")


def check_workspace() -> None:
    workspace = load_toml(ROOT / "Cargo.toml").get("workspace", {})
    members = workspace.get("members", [])
    expected = "tools/font-cmap-cleaner"
    if expected not in members:
        fail(f"Cargo workspace does not include {expected}")

    member_lock = ROOT / expected / "Cargo.lock"
    if member_lock.exists():
        fail(f"workspace member has a duplicate lock file: {member_lock.relative_to(ROOT)}")

    manifest = load_toml(ROOT / expected / "Cargo.toml")
    lock = load_toml(ROOT / "Cargo.lock")
    packages = lock.get("package", [])
    locked_names = {package["name"] for package in packages}

    git_packages = [
        package["name"]
        for package in packages
        if str(package.get("source", "")).startswith("git+")
    ]
    if git_packages:
        fail("Cargo.lock contains floating Git packages: " + ", ".join(sorted(git_packages)))

    for section in ("dependencies", "dev-dependencies"):
        for name in manifest.get(section, {}):
            if name not in locked_names:
                fail(f"{name} from [{section}] is missing from Cargo.lock")

    if (ROOT / "rust-project.json").exists():
        fail("rust-project.json duplicates Cargo workspace metadata")


def check_rust_module_graph() -> None:
    src = ROOT / "tools/font-cmap-cleaner/src"
    lib_text = (src / "lib.rs").read_text(encoding="utf-8")
    declared = set(re.findall(r"^pub mod ([A-Za-z0-9_]+);$", lib_text, re.MULTILINE))

    for path in src.glob("*.rs"):
        if path.name in {"main.rs", "lib.rs"}:
            continue
        if path.stem not in declared:
            fail(f"Rust source file is not in the module graph: {path.relative_to(ROOT)}")


def check_shell_library_graph() -> None:
    lib_dir = ROOT / "module/lib"
    loader = (lib_dir / "lib.sh").read_text(encoding="utf-8")
    for path in lib_dir.glob("*.sh"):
        if path.name == "lib.sh":
            continue
        expected = f'"$LIBDIR/{path.name}"'
        if expected not in loader:
            fail(f"Shell library is not loaded by lib.sh: {path.relative_to(ROOT)}")




def parse_shell_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    assignment = re.compile(r'^([A-Z][A-Z0-9_]*)=(?:"([^"]*)"|\'([^\']*)\')$')
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = assignment.match(line)
        if not match:
            fail(f"{path.relative_to(ROOT)}:{line_no}: expected a simple quoted KEY=VALUE assignment")
        values[match.group(1)] = match.group(2) if match.group(2) is not None else match.group(3)
    return values


def _parse_unicode_scalar(text: str, context: str) -> int:
    value = text.strip()
    if value.lower().startswith("u+"):
        value = value[2:]
    try:
        cp = int(value, 16)
    except ValueError:
        fail(f"{context}: invalid Unicode codepoint {text!r}")
    if cp > 0x10FFFF or 0xD800 <= cp <= 0xDFFF:
        fail(f"{context}: invalid Unicode scalar U+{cp:X}")
    return cp


def validate_range_spec(text: str, context: str) -> None:
    value = text.strip()
    if value in {"-", "*"}:
        return
    if value.startswith("[") or value.endswith("]"):
        if not (value.startswith("[") and value.endswith("]")):
            fail(f"{context}: unmatched [] in range specification")
        value = value[1:-1].strip()
    if not value:
        fail(f"{context}: empty [] range specification")
    for item in value.split(","):
        item = item.strip()
        if not item:
            fail(f"{context}: empty range item")
        if "-" in item:
            parts = item.split("-")
            if len(parts) != 2:
                fail(f"{context}: invalid range {item!r}")
            start = _parse_unicode_scalar(parts[0], context)
            end = _parse_unicode_scalar(parts[1], context)
            if start > end:
                fail(f"{context}: reversed range {item!r}")
            if start <= 0xDFFF and end >= 0xD800:
                fail(f"{context}: range intersects surrogate block: {item!r}")
        else:
            _parse_unicode_scalar(item, context)


def parse_font_policy(path: Path) -> list[tuple[str, str, str, str]]:
    entries: list[tuple[str, str, str, str]] = []
    seen: set[str] = set()
    valid_roles = {"system-overlay", "normal-fallback", "terminal-fallback"}
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        context = f"{path.relative_to(ROOT)}:{line_no}"
        if len(fields) != 4 or fields[0] not in valid_roles or not all(fields[1:]):
            fail(f"{context}: expected role<TAB>font<TAB>protect<TAB>remove")
        validate_range_spec(fields[2], context + " protect")
        validate_range_spec(fields[3], context + " remove")
        if fields[1] in seen:
            fail(f"{context}: duplicate font policy entry {fields[1]}")
        seen.add(fields[1])
        entries.append((fields[0], fields[1], fields[2], fields[3]))
    if not entries:
        fail("font-policy.tsv contains no entries")
    return entries


def check_shared_discovery_config() -> None:
    config_path = ROOT / "module/config/discovery.conf"
    values = parse_shell_config(config_path)
    required = {
        "FONT_XML_FAMILYSET_FILES",
        "FONT_XML_MODULE_SUBDIRS",
        "FONT_BINARY_MODULE_SUBDIRS",
        "FONT_XML_BASELINE_DIRS",
        "SYSTEM_FONT_BASELINE_DIRS",
        "SYSTEM_FONT_SEARCH_DIRS",
        "UPDATABLE_SYSTEM_FONT_DIR",
        "UPDATABLE_CONFIG_XML",
    }
    missing = sorted(required - values.keys())
    if missing:
        fail("discovery.conf is missing: " + ", ".join(missing))

    familyset_files = set(values["FONT_XML_FAMILYSET_FILES"].split())
    if "fonts.xml" not in familyset_files:
        fail("FONT_XML_FAMILYSET_FILES must include fonts.xml")
    if "fonts_customization.xml" in familyset_files:
        fail("fonts_customization.xml must not be treated as a global fallback familyset")

    baseline_dirs = set(values["SYSTEM_FONT_BASELINE_DIRS"].split())
    search_dirs = set(values["SYSTEM_FONT_SEARCH_DIRS"].split())
    if not baseline_dirs <= search_dirs:
        fail("SYSTEM_FONT_BASELINE_DIRS must be a subset of SYSTEM_FONT_SEARCH_DIRS")
    if {"/product/fonts", "/system/product/fonts"} & baseline_dirs:
        fail("product font roots must not enter the default fallback baseline")
    if "/product/fonts" not in search_dirs:
        fail("product fonts should remain available to the find diagnostic search")

    xml_baseline_dirs = set(values["FONT_XML_BASELINE_DIRS"].split())
    if "/product/etc" in xml_baseline_dirs or "/system/product/etc" in xml_baseline_dirs:
        fail("product XML roots must not be treated as global fallback baseline inputs")

    const_text = (ROOT / "module/lib/const.sh").read_text(encoding="utf-8")
    if "discovery.conf" not in const_text or "FONT_XML_FAMILYSET_FILES" not in const_text:
        fail("Shell constants are not sourced from discovery.conf")
    discovery_rs = (ROOT / "tools/font-cmap-cleaner/src/config.rs").read_text(encoding="utf-8")
    if 'include_str!("../../../module/config/discovery.conf")' not in discovery_rs:
        fail("Rust discovery configuration is not embedded from module/config/discovery.conf")

    for obsolete in (ROOT / "module/config/whitelist.txt", ROOT / "tools/font-cmap-cleaner/whitelist.txt"):
        if obsolete.exists():
            fail(f"obsolete whitelist configuration still exists: {obsolete.relative_to(ROOT)}")

def check_font_fragment() -> None:
    fragment_path = ROOT / "module/config/fonts_fragment.xml"
    fragment = fragment_path.read_text(encoding="utf-8")
    try:
        root = ET.fromstring(f"<familyset>{fragment}</familyset>")
    except ET.ParseError as exc:
        fail(f"fonts_fragment.xml is not well-formed XML: {exc}")

    fonts = []
    for node in root.iter("font"):
        if node.text and node.text.strip():
            fonts.append(node.text.strip())
    if not fonts:
        fail("fonts_fragment.xml does not reference any fonts")
    duplicates = sorted({font for font in fonts if fonts.count(font) > 1})
    if duplicates:
        fail(f"duplicate font entries in fonts_fragment.xml: {', '.join(duplicates)}")


    policy = parse_font_policy(ROOT / "module/config/font-policy.tsv")
    fallback_policy = [font for role, font, _, _ in policy if role in {"normal-fallback", "terminal-fallback"}]
    if fallback_policy != fonts:
        fail("font-policy normal/terminal order must exactly match fonts_fragment.xml")

    local_fonts = {
        path.name for path in (ROOT / "module/system/fonts").iterdir() if path.is_file()
    }
    classified = {font for _, font, _, _ in policy}
    unclassified_local = sorted(local_fonts - classified)
    if unclassified_local:
        fail("local module fonts missing from font-policy.tsv: " + ", ".join(unclassified_local))



def warn(message: str) -> None:
    print(f"WARNING: {message}", file=sys.stderr)


def check_release_config() -> None:
    config = load_toml(ROOT / "release.toml")
    project = config.get("project", {})
    release = config.get("release", {})
    variants = config.get("variants", {})

    for key in ("id", "name", "author", "description", "repository"):
        if not str(project.get(key, "")).strip():
            fail(f"release.toml [project] is missing {key}")
    for key in ("framework_version", "unicode_version", "unicode_label", "unicode_data_url"):
        if not str(release.get(key, "")).strip():
            fail(f"release.toml [release] is missing {key}")
    if not isinstance(release.get("version_code"), int) or release["version_code"] <= 0:
        fail("release.toml release.version_code must be a positive integer")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", release["framework_version"]):
        fail("release.toml framework_version must use SemVer-like syntax")

    required_variants = {"colrv1", "cbdt"}
    if set(variants) != required_variants:
        fail("release.toml must define exactly colrv1 and cbdt variants")
    for name, meta in variants.items():
        for key in ("label", "artifact", "update_asset", "nightly_update_asset"):
            if not str(meta.get(key, "")).strip():
                fail(f"release.toml variants.{name} is missing {key}")
        if not isinstance(meta.get("min_api"), int) or meta["min_api"] <= 0:
            fail(f"release.toml variants.{name}.min_api must be a positive integer")
    if variants["cbdt"]["min_api"] < 26:
        fail("CBDT min_api must not be lower than the currently supported UFS framework API 26")
    if variants["colrv1"]["min_api"] < 33:
        fail("COLRv1 min_api must not be lower than API 33")

    for obsolete in (ROOT / "update-cbdt.json", ROOT / "update-colrv1.json", ROOT / "update.json"):
        if obsolete.exists():
            fail(f"release update metadata must be generated as Release assets, not stored in the repository: {obsolete.name}")

    module_prop = {}
    for raw in (ROOT / "module/module.prop").read_text(encoding="utf-8").splitlines():
        if "=" in raw:
            key, value = raw.split("=", 1)
            module_prop[key] = value

    project = config["project"]
    expected_source = {
        "id": project["id"],
        "name": project["name"],
        "version": "SOURCE",
        "versionCode": "0",
        "author": project["author"],
        "updateJson": "",
        "buildState": "source",
    }
    for key, expected in expected_source.items():
        if module_prop.get(key) != expected:
            fail(f"module/module.prop source placeholder has invalid {key}: expected {expected!r}")

    for generated_key in ("frameworkVersion", "unicodeVersion", "variant", "minApi"):
        if generated_key in module_prop:
            fail(f"module/module.prop source placeholder must not contain generated field: {generated_key}")


def check_font_sources() -> None:
    source_path = ROOT / "font-source/font-sources.toml"
    if not source_path.is_file():
        fail("missing font-source/font-sources.toml")
    if (ROOT / "font-source/font-sources.tsv").exists():
        fail("font-source/font-sources.tsv is obsolete; use font-source/font-sources.toml")
    if (ROOT / "font-source/LICENSE").exists():
        fail("font-source/LICENSE is obsolete; license URLs belong in font-source/font-sources.toml")
    source_ofl = ROOT / "font-source/LICENSE-OFL-1.1"
    if not source_ofl.is_file():
        fail("missing font-source/LICENSE-OFL-1.1 for repository-owned OFL font sources")
    if "SIL OPEN FONT LICENSE Version 1.1" not in source_ofl.read_text(encoding="utf-8"):
        fail("font-source/LICENSE-OFL-1.1 does not contain the OFL-1.1 license text")
    if (ROOT / "font-source/licenses").exists():
        fail("font-source/licenses is obsolete; license texts are fetched from font-sources.toml URLs")

    sys.path.insert(0, str(ROOT / "tools/python"))
    from prepare_fonts import read_sources, select_sources  # type: ignore

    try:
        rows = read_sources(source_path)
    except SystemExit as exc:
        fail(str(exc))

    policy_fonts = {font for _, font, _, _ in parse_font_policy(ROOT / "module/config/font-policy.tsv")}
    licenses_warned: set[tuple[str, str]] = set()
    for row in rows:
        if row.acquisition == "local" and not (ROOT / row.source_location).is_file():
            fail(f"font-sources.toml: missing local source {row.source_location}")

        if row.license is None:
            key = (row.file, row.variant)
            if key not in licenses_warned:
                warn(f"license review pending for {row.file} ({row.variant})")
                licenses_warned.add(key)

    for variant in ("colrv1", "cbdt"):
        try:
            selected = select_sources(rows, variant)
        except SystemExit as exc:
            fail(str(exc))
        selected_set = {row.file for row in selected}
        if selected_set != policy_fonts:
            missing = sorted(policy_fonts - selected_set)
            extra = sorted(selected_set - policy_fonts)
            fail(f"font source selection for {variant} does not match font-policy.tsv; missing={missing}, extra={extra}")


def check_runtime_line_endings() -> None:
    roots = [ROOT / "module", ROOT / "font-source", ROOT / "tools/python", ROOT / "tools/font-cmap-cleaner", ROOT / "tests"]
    suffixes = {".sh", ".conf", ".tsv", ".toml", ".yml", ".yaml", ".py", ".rs", ".xml"}
    for root in roots:
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in suffixes and b"\r\n" in path.read_bytes():
                fail(f"runtime/build text file uses CRLF instead of LF: {path.relative_to(ROOT)}")

def check_entrypoint_permissions() -> None:
    for relative in (
        "module/action.sh",
        "module/customize.sh",
        "module/service.sh",
        "module/post-fs-data.sh",
        "module/late-load.sh",
        "module/uninstall.sh",
        "tests/shell/runtime_test.sh",
        "tests/shell/uninstall_test.sh",
        "tests/shell/upgrade_migration_test.sh",
    ):
        path = ROOT / relative
        if not os.access(path, os.X_OK):
            fail(f"entrypoint is not executable: {relative}")


def main() -> None:
    check_workspace()
    check_release_config()
    check_font_sources()
    check_rust_module_graph()
    check_shell_library_graph()
    check_shared_discovery_config()
    check_font_fragment()
    check_runtime_line_endings()
    check_entrypoint_permissions()
    print("Repository consistency checks passed.")


if __name__ == "__main__":
    main()
