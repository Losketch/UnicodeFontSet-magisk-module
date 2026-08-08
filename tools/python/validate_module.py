#!/usr/bin/env python3
"""Validate assets that must exist in a built UFS Magisk module."""

from __future__ import annotations

import argparse
import csv
import hashlib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from prepare_fonts import license_filename

EXPECTED_ABIS = ("arm64-v8a", "armeabi-v7a", "x86", "x86_64")


def error(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def referenced_fonts(fragment_path: Path) -> list[str]:
    fragment = fragment_path.read_text(encoding="utf-8")
    try:
        root = ET.fromstring(f"<familyset>{fragment}</familyset>")
    except ET.ParseError as exc:
        error(f"invalid font fragment: {exc}")

    return [
        node.text.strip()
        for node in root.iter("font")
        if node.text and node.text.strip()
    ]



def _policy_scalar(text: str, line_no: int) -> int:
    value = text.strip()
    if value.lower().startswith("u+"):
        value = value[2:]
    try:
        cp = int(value, 16)
    except ValueError:
        error(f"invalid Unicode codepoint in font-policy.tsv line {line_no}: {text}")
    if cp > 0x10FFFF or 0xD800 <= cp <= 0xDFFF:
        error(f"invalid Unicode scalar in font-policy.tsv line {line_no}: U+{cp:X}")
    return cp


def _validate_policy_ranges(text: str, line_no: int) -> None:
    value = text.strip()
    if value in {"-", "*"}:
        return
    if value.startswith("[") or value.endswith("]"):
        if not (value.startswith("[") and value.endswith("]")):
            error(f"unmatched range brackets in font-policy.tsv line {line_no}")
        value = value[1:-1].strip()
    if not value:
        error(f"empty range policy in font-policy.tsv line {line_no}")
    for item in value.split(","):
        item = item.strip()
        if not item:
            error(f"empty range item in font-policy.tsv line {line_no}")
        parts = item.split("-")
        if len(parts) == 1:
            _policy_scalar(parts[0], line_no)
            continue
        if len(parts) != 2:
            error(f"invalid Unicode range in font-policy.tsv line {line_no}: {item}")
        start = _policy_scalar(parts[0], line_no)
        end = _policy_scalar(parts[1], line_no)
        if start > end:
            error(f"reversed Unicode range in font-policy.tsv line {line_no}: {item}")
        if start <= 0xDFFF and end >= 0xD800:
            error(f"Unicode range intersects surrogate block in font-policy.tsv line {line_no}: {item}")


def parse_policy_fonts(path: Path) -> set[str]:
    fonts: set[str] = set()
    valid_roles = {"system-overlay", "normal-fallback", "terminal-fallback"}
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 4 or fields[0] not in valid_roles or not all(fields[1:]):
            error(f"invalid font-policy.tsv row at line {line_no}")
        _validate_policy_ranges(fields[2], line_no)
        _validate_policy_ranges(fields[3], line_no)
        if fields[1] in fonts:
            error(f"duplicate font-policy.tsv entry: {fields[1]}")
        fonts.add(fields[1])
    if not fonts:
        error("font-policy.tsv contains no entries")
    return fonts



def validate_license_manifest(module: Path, packaged_fonts: set[str]) -> None:
    licenses = module / "META-INF/licenses"
    manifest = licenses / "font-manifest.tsv"
    if not manifest.is_file():
        error("missing META-INF/licenses/font-manifest.tsv")
    seen: set[str] = set()
    with manifest.open(encoding="utf-8", newline="") as handle:
        rows = csv.DictReader(handle, delimiter="\t")
        required = {"file", "sha256", "size", "license", "review_status"}
        if not rows.fieldnames or not required <= set(rows.fieldnames):
            error("invalid font-manifest.tsv header")
        for row in rows:
            name = row["file"]
            if name in seen:
                error(f"duplicate font-manifest.tsv entry: {name}")
            seen.add(name)
            font = module / "system/fonts" / name
            if not font.is_file():
                error(f"font-manifest.tsv references missing font: {name}")
            data = font.read_bytes()
            if hashlib.sha256(data).hexdigest() != row["sha256"]:
                error(f"font-manifest.tsv SHA-256 mismatch: {name}")
            if str(len(data)) != row["size"]:
                error(f"font-manifest.tsv size mismatch: {name}")
            license_url = row["license"]
            if license_url != "REVIEW_REQUIRED":
                license_file = license_filename(name)
                if not (licenses / license_file).is_file():
                    error(f"missing declared license file for {name}: {license_file}")
            if row["review_status"] != "ok":
                print(f"WARNING: license review pending for {name}: {row['review_status']}", file=sys.stderr)
    if seen != packaged_fonts:
        error("font-manifest.tsv does not exactly match packaged fonts")

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--module", type=Path, default=Path("module"))
    args = parser.parse_args()
    module = args.module.resolve()

    fragment = module / "config/fonts_fragment.xml"
    if not fragment.is_file():
        error(f"missing {fragment}")

    missing_fonts = []
    for name in referenced_fonts(fragment):
        path = module / "system/fonts" / name
        if not path.is_file() or path.stat().st_size == 0:
            missing_fonts.append(name)
    if missing_fonts:
        error("missing fonts referenced by fonts_fragment.xml: " + ", ".join(missing_fonts))

    for config_name in ("discovery.conf", "font-policy.tsv"):
        config = module / "config" / config_name
        if not config.is_file() or not config.read_text(encoding="utf-8").strip():
            error(f"missing or empty config/{config_name}")

    policy_fonts = parse_policy_fonts(module / "config/font-policy.tsv")
    packaged_fonts = {path.name for path in (module / "system/fonts").iterdir() if path.is_file()}
    missing_policy = sorted(packaged_fonts - policy_fonts)
    stale_policy = sorted(policy_fonts - packaged_fonts)
    if missing_policy:
        error("packaged fonts missing from font-policy.tsv: " + ", ".join(missing_policy))
    if stale_policy:
        error("font-policy.tsv references missing packaged fonts: " + ", ".join(stale_policy))

    validate_license_manifest(module, packaged_fonts)

    prop = {}
    for raw in (module / "module.prop").read_text(encoding="utf-8").splitlines():
        if "=" in raw:
            key, value = raw.split("=", 1)
            prop[key] = value
    if prop.get("buildState") != "built":
        error("module.prop is not a built module artifact")
    for key in ("frameworkVersion", "unicodeVersion", "variant", "minApi"):
        if not prop.get(key):
            error(f"module.prop missing generated field: {key}")

    if (module / "config/whitelist.txt").exists():
        error("obsolete config/whitelist.txt must not be packaged")

    missing_bins = []
    for abi in EXPECTED_ABIS:
        path = module / "bin" / f"font-cmap-tool-{abi}"
        if not path.is_file() or path.stat().st_size == 0:
            missing_bins.append(abi)
    if missing_bins:
        error("missing font-cmap-tool binaries for: " + ", ".join(missing_bins))

    cleaner_license = module / "META-INF/licenses/LICENSE-font-cmap-tool"
    if not cleaner_license.is_file() or cleaner_license.stat().st_size == 0:
        error("missing font-cmap-tool license")

    installer = module / "META-INF/com/google/android/update-binary"
    if not installer.is_file():
        error("missing Magisk update-binary")
    installer_text = installer.read_text(encoding="utf-8", errors="replace")
    if "dummy file that should be replaced" in installer_text:
        error("update-binary is still the repository placeholder")

    print("Built module asset validation passed.")


if __name__ == "__main__":
    main()
