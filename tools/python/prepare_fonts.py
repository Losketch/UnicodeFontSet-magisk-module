#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import re
import sys
import time
import tomllib
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCES = ROOT / "font-source/font-sources.toml"
VALID_VARIANTS = {"all", "colrv1", "cbdt"}
VALID_ACQUISITIONS = {"local", "direct", "google-css"}


@dataclass(frozen=True)
class FontSource:
    file: str
    acquisition: str
    source_location: str
    variant: str = "all"
    license: str | None = None


def warn(message: str) -> None:
    print(f"::warning title=Font licensing::{message}")


def _required_string(item: dict[str, object], key: str, index: int) -> str:
    value = item.get(key)
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(f"font-source/font-sources.toml: fonts[{index}] is missing non-empty {key}")
    return value.strip()


def _optional_string(item: dict[str, object], key: str, index: int) -> str | None:
    value = item.get(key)
    if value is None:
        return None
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(f"font-source/font-sources.toml: fonts[{index}].{key} must be a non-empty string")
    return value.strip()


def read_sources(path: Path) -> list[FontSource]:
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise SystemExit(f"failed to read {path}: {exc}") from exc

    unknown_root = sorted(set(data) - {"schema", "fonts"})
    if unknown_root:
        raise SystemExit(f"{path}: unknown top-level keys: {', '.join(unknown_root)}")
    if data.get("schema") != 1:
        raise SystemExit(f"{path}: unsupported or missing schema (expected 1)")

    raw_fonts = data.get("fonts")
    if not isinstance(raw_fonts, list) or not raw_fonts:
        raise SystemExit(f"{path}: expected one or more [[fonts]] entries")

    sources: list[FontSource] = []
    allowed = {
        "file",
        "variant",
        "acquisition",
        "source_location",
        "license",
    }
    for index, item in enumerate(raw_fonts, 1):
        if not isinstance(item, dict):
            raise SystemExit(f"{path}: fonts[{index}] must be a table")
        unknown = sorted(set(item) - allowed)
        if unknown:
            raise SystemExit(f"{path}: fonts[{index}] has unknown keys: {', '.join(unknown)}")

        variant = _optional_string(item, "variant", index) or "all"
        acquisition = _required_string(item, "acquisition", index)
        if variant not in VALID_VARIANTS:
            raise SystemExit(f"{path}: fonts[{index}].variant has invalid value {variant!r}")
        if acquisition not in VALID_ACQUISITIONS:
            raise SystemExit(f"{path}: fonts[{index}].acquisition has invalid value {acquisition!r}")
        license_url = _optional_string(item, "license", index)
        if license_url is not None:
            try:
                _validate_license_url(license_url)
            except ValueError as exc:
                raise SystemExit(f"{path}: fonts[{index}].license: {exc}") from exc

        sources.append(
            FontSource(
                file=_required_string(item, "file", index),
                variant=variant,
                acquisition=acquisition,
                source_location=_required_string(item, "source_location", index),
                license=license_url,
            )
        )
    return sources


def select_sources(sources: list[FontSource], variant: str) -> list[FontSource]:
    selected = [source for source in sources if source.variant in {"all", variant}]
    by_file: dict[str, FontSource] = {}
    for source in selected:
        if source.file in by_file:
            raise SystemExit(f"duplicate selected source for {source.file} ({variant})")
        by_file[source.file] = source
    return list(by_file.values())


def fetch(url: str, attempts: int = 3) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    last: Exception | None = None
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return response.read()
        except Exception as exc:  # network error is reported after retries
            last = exc
            if attempt + 1 < attempts:
                time.sleep(2 ** attempt)
    raise RuntimeError(f"failed to download {url}: {last}")


def resolve_and_load(source: FontSource) -> tuple[bytes, str]:
    if source.acquisition == "local":
        path = ROOT / source.source_location
        if not path.is_file():
            raise FileNotFoundError(path)
        return path.read_bytes(), source.source_location
    if source.acquisition == "direct":
        return fetch(source.source_location), source.source_location
    css = fetch(source.source_location).decode("utf-8", errors="replace")
    matches = re.findall(r"https://[^)\s]+\.ttf", css)
    if not matches:
        raise RuntimeError(f"no TTF URL found in Google Fonts CSS: {source.source_location}")
    resolved = matches[0]
    return fetch(resolved), resolved


def _validate_license_url(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc:
        raise ValueError(f"license must be an HTTPS URL, got {url!r}")


def license_filename(font_file: str) -> str:
    name = Path(font_file).name
    stem = Path(name).stem
    if not stem or name in {".", ".."}:
        raise ValueError(f"invalid font filename for license derivation: {font_file!r}")
    return f"LICENSE-{stem}"


def write_license(font_file: str, license_url: str, target_dir: Path, cache: dict[str, bytes]) -> None:
    target_dir.mkdir(parents=True, exist_ok=True)
    data = cache.get(license_url)
    if data is None:
        data = fetch(license_url)
        cache[license_url] = data
    (target_dir / license_filename(font_file)).write_bytes(data)


def review_status(source: FontSource) -> str:
    return "ok" if source.license is not None else "review-required:license"


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare UFS bundled fonts and build-specific license manifest")
    parser.add_argument("--variant", choices=["colrv1", "cbdt"], required=True)
    parser.add_argument("--sources", type=Path, default=DEFAULT_SOURCES)
    parser.add_argument("--font-dir", type=Path, default=ROOT / "module/system/fonts")
    parser.add_argument("--licenses-output", type=Path, default=ROOT / "module/META-INF/licenses")
    args = parser.parse_args()

    sources = select_sources(read_sources(args.sources), args.variant)
    args.font_dir.mkdir(parents=True, exist_ok=True)
    if args.licenses_output.exists():
        for path in args.licenses_output.iterdir():
            if path.is_file() or path.is_symlink():
                path.unlink()
    args.licenses_output.mkdir(parents=True, exist_ok=True)

    expected = {source.file for source in sources}
    for path in args.font_dir.iterdir():
        if path.is_file() and path.name not in expected:
            path.unlink()

    manifest_rows = []
    license_cache: dict[str, bytes] = {}
    for source in sources:
        print(f"Preparing {source.file} from {source.source_location}")
        data, resolved = resolve_and_load(source)
        target = args.font_dir / source.file
        target.write_bytes(data)
        sha256 = hashlib.sha256(data).hexdigest()
        status = review_status(source)
        if source.license is not None:
            print(f"Preparing {license_filename(source.file)} from {source.license}")
            write_license(source.file, source.license, args.licenses_output, license_cache)
        else:
            warn(f"{source.file}: {status}. Add a reviewed license URL before a public release.")
        manifest_rows.append(
            [
                source.file,
                args.variant,
                source.source_location,
                resolved,
                sha256,
                str(len(data)),
                source.license or "REVIEW_REQUIRED",
                status,
            ]
        )

    manifest = args.licenses_output / "font-manifest.tsv"
    with manifest.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(
            [
                "file",
                "variant",
                "source_location",
                "resolved_location",
                "sha256",
                "size",
                "license",
                "review_status",
            ]
        )
        writer.writerows(manifest_rows)

    print(f"Prepared {len(manifest_rows)} fonts; manifest: {manifest}")


if __name__ == "__main__":
    main()
