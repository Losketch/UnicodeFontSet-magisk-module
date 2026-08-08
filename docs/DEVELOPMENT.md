# Development and validation

The repository is organized as a Cargo workspace plus a small Android module runtime.
The build is expected to stay reproducible and to fail before packaging when a required
asset or quality gate is missing.

## Rust quality gates

Run from the repository root:

```bash
cargo fmt --all -- --check
cargo check --workspace --all-targets --locked
cargo test --workspace --all-targets --locked
cargo clippy --workspace --all-targets --locked -- -D warnings
```

`Cargo.lock` lives at the workspace root and is the only Rust lock file in the repository.

## Shell validation

All module scripts must parse as `/system/bin/sh` compatible shell. The host-side
regression tests can be run without Android:

```bash
for script in module/*.sh module/lib/*.sh module/lang/*.sh tests/shell/*.sh; do
    busybox ash -n "$script"
done

for test_script in tests/shell/*_test.sh; do
    busybox ash "$test_script"
done
```

The tests use temporary module roots and environment overrides such as
`UFS_MODULE_PARENT`, `UFS_LOCK_DIR`, and `UFS_TEMP_DIR`; they must not mutate the
checkout.

## Repository checks

```bash
python3 -m compileall -q tools/python
python3 tools/python/validate_repository.py
```

`validate_repository.py` checks the Cargo workspace/lock relationship, Rust and shell
module graphs, font fragment structure, and executable entrypoints.

After CI has downloaded fonts and cross-compiled the Android binaries, run:

```bash
python3 tools/python/validate_module.py --module module
```

This ensures every font referenced by `fonts_fragment.xml` exists, all four supported
ABI binaries were produced, the cmap whitelist is present, and the Magisk installer
placeholder was replaced.

## Runtime boundaries

- `customize.sh` is the installer adapter. It consumes manager-provided variables when
  available instead of replacing manager callbacks such as `ui_print` and `abort`.
- `action.sh` and `service.sh` are thin runtime entrypoints and share initialization in
  `module/lib/env.sh`.
- `module/lib/xml.sh` and `module/lib/binary.sh` own takeover transactions.
- `uninstall.sh` intentionally remains self-contained so recovery can still work if the
  normal runtime library is unavailable.
- `tools/font-cmap-cleaner` owns binary cmap processing and is kept separate from shell
  module lifecycle logic.
