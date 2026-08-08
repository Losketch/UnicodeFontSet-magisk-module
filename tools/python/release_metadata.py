#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = ROOT / "release.toml"


def load_config(path: Path = DEFAULT_CONFIG) -> dict:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def is_prerelease(version: str) -> bool:
    return "-" in version


def nightly_version_code(run_number: int) -> int:
    stamp = int(datetime.now(timezone.utc).strftime("%Y%m%d"))
    return stamp * 100000 + (run_number % 100000)


def display_version(config: dict, variant: str, channel: str, run_number: int = 0, sha: str = "") -> tuple[str, int]:
    release = config["release"]
    label = config["variants"][variant]["label"]
    base = release["framework_version"]
    if channel == "nightly":
        date = datetime.now(timezone.utc).strftime("%Y%m%d")
        short_sha = (sha or "unknown")[:7]
        return f"{base}.{date}.{run_number} [{short_sha}-Nightly-{label}]", nightly_version_code(run_number)
    return f"{base} [{label}]", int(release["version_code"])


def update_url(config: dict, variant: str, channel: str) -> str:
    repo = config["project"]["repository"].rstrip("/")
    meta = config["variants"][variant]
    version = config["release"]["framework_version"]
    if channel == "nightly":
        return f"{repo}/releases/download/nightly/{meta['nightly_update_asset']}"
    if channel == "release" and not is_prerelease(version):
        return f"{repo}/releases/latest/download/{meta['update_asset']}"
    return ""


def render_module_prop(config: dict, variant: str, channel: str, run_number: int = 0, sha: str = "") -> str:
    project = config["project"]
    release = config["release"]
    meta = config["variants"][variant]
    version, version_code = display_version(config, variant, channel, run_number, sha)
    lines = [
        f"id={project['id']}",
        f"name={project['name']}",
        f"version={version}",
        f"versionCode={version_code}",
        f"author={project['author']}",
        f"description={project['description']} GitHub project URL: {project['repository']}.",
        f"updateJson={update_url(config, variant, channel)}",
        f"frameworkVersion={release['framework_version']}",
        f"unicodeVersion={release['unicode_version']}",
        f"variant={meta['label']}",
        f"minApi={meta['min_api']}",
        "buildState=built",
    ]
    return "\n".join(lines) + "\n"


def update_payload(config: dict, variant: str, channel: str, tag: str = "", run_number: int = 0, sha: str = "") -> dict:
    project = config["project"]
    release = config["release"]
    meta = config["variants"][variant]
    version, version_code = display_version(config, variant, channel, run_number, sha)
    repo = project["repository"].rstrip("/")

    if channel == "nightly":
        base = f"{repo}/releases/download/nightly"
        changelog = f"{base}/changelog.md"
    elif not tag:
        raise ValueError("release update JSON requires --tag")
    elif is_prerelease(release["framework_version"]):
        base = f"{repo}/releases/download/{tag}"
        changelog = f"{base}/changelog.md"
    else:
        base = f"{repo}/releases/latest/download"
        changelog = f"{base}/changelog.md"

    return {
        "version": version,
        "versionCode": version_code,
        "zipUrl": f"{base}/{meta['artifact']}",
        "changelog": changelog,
    }


def matrix_payload(config: dict) -> dict:
    items = []
    for name, meta in config["variants"].items():
        items.append(
            {
                "name": name,
                "label": meta["label"],
                "min_api": meta["min_api"],
                "artifact": meta["artifact"],
                "update_asset": meta["update_asset"],
                "nightly_update_asset": meta["nightly_update_asset"],
            }
        )
    return {"variant": items}


def expected_tag(config: dict) -> str:
    return f"v{config['release']['framework_version']}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate UFS release/build metadata from release.toml")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("matrix")

    info = sub.add_parser("info")
    info.add_argument("--field", choices=["version", "version_code", "unicode_version", "unicode_label", "unicode_data_url", "prerelease", "expected_tag", "release_name"], required=True)

    module_prop = sub.add_parser("module-prop")
    module_prop.add_argument("--variant", required=True)
    module_prop.add_argument("--channel", choices=["build", "release", "nightly"], required=True)
    module_prop.add_argument("--run-number", type=int, default=0)
    module_prop.add_argument("--sha", default="")
    module_prop.add_argument("--output", type=Path, required=True)

    update = sub.add_parser("update-json")
    update.add_argument("--variant", required=True)
    update.add_argument("--channel", choices=["release", "nightly"], required=True)
    update.add_argument("--tag", default="")
    update.add_argument("--run-number", type=int, default=0)
    update.add_argument("--sha", default="")
    update.add_argument("--output", type=Path, required=True)

    tag = sub.add_parser("validate-tag")
    tag.add_argument("tag")

    args = parser.parse_args()
    config = load_config(args.config)

    if args.command == "matrix":
        print(json.dumps(matrix_payload(config), separators=(",", ":")))
        return

    if args.command == "info":
        release = config["release"]
        value = {
            "version": release["framework_version"],
            "version_code": release["version_code"],
            "unicode_version": release["unicode_version"],
            "unicode_label": release["unicode_label"],
            "unicode_data_url": release["unicode_data_url"],
            "prerelease": str(is_prerelease(release["framework_version"])).lower(),
            "expected_tag": expected_tag(config),
            "release_name": f"Unicode Font Set v{release['framework_version']}",
        }[args.field]
        print(value)
        return

    if args.command == "validate-tag":
        expected = expected_tag(config)
        if args.tag != expected:
            raise SystemExit(f"tag mismatch: expected {expected}, got {args.tag}")
        return

    if args.variant not in config["variants"]:
        raise SystemExit(f"unknown variant: {args.variant}")

    if args.command == "module-prop":
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            render_module_prop(config, args.variant, args.channel, args.run_number, args.sha),
            encoding="utf-8",
        )
        return

    if args.command == "update-json":
        payload = update_payload(config, args.variant, args.channel, args.tag, args.run_number, args.sha)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return


if __name__ == "__main__":
    main()
