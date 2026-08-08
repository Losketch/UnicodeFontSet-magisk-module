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


def check_entrypoint_permissions() -> None:
    for relative in (
        "module/action.sh",
        "module/customize.sh",
        "module/service.sh",
        "module/uninstall.sh",
        "tests/shell/runtime_test.sh",
        "tests/shell/uninstall_test.sh",
    ):
        path = ROOT / relative
        if not os.access(path, os.X_OK):
            fail(f"entrypoint is not executable: {relative}")


def main() -> None:
    check_workspace()
    check_rust_module_graph()
    check_shell_library_graph()
    check_font_fragment()
    check_entrypoint_permissions()
    print("Repository consistency checks passed.")


if __name__ == "__main__":
    main()
