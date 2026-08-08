#!/usr/bin/env python3
"""Validate assets that must exist in a built UFS Magisk module."""

from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

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

    whitelist = module / "config/whitelist.txt"
    if not whitelist.is_file() or not whitelist.read_text(encoding="utf-8").strip():
        error("missing or empty config/whitelist.txt")

    missing_bins = []
    for abi in EXPECTED_ABIS:
        path = module / "bin" / f"font-cmap-tool-{abi}"
        if not path.is_file() or path.stat().st_size == 0:
            missing_bins.append(abi)
    if missing_bins:
        error("missing font-cmap-tool binaries for: " + ", ".join(missing_bins))

    installer = module / "META-INF/com/google/android/update-binary"
    if not installer.is_file():
        error("missing Magisk update-binary")
    installer_text = installer.read_text(encoding="utf-8", errors="replace")
    if "dummy file that should be replaced" in installer_text:
        error("update-binary is still the repository placeholder")

    print("Built module asset validation passed.")


if __name__ == "__main__":
    main()
