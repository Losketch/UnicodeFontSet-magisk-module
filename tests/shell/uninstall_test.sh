#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ufs-uninstall-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

cp -a "$REPO_ROOT/module" "$TMP_ROOT/ufs"
modules="$TMP_ROOT/modules"
lock="$TMP_ROOT/lock"
target="$modules/example-font-module"
backup="$TMP_ROOT/ufs/backup/example-font-module/system/etc/fonts.xml"
mkdir -p "$target/system/etc" "$(dirname "$backup")" "$TMP_ROOT/ufs/sha1"
printf 'restored-config\n' > "$backup"
printf 'state' > "$TMP_ROOT/ufs/sha1/example"

UFS_MODULE_PARENT="$modules" UFS_LOCK_DIR="$lock" \
    /usr/bin/env sh "$TMP_ROOT/ufs/uninstall.sh" >/dev/null

[ -f "$target/system/etc/fonts.xml" ] || fail "uninstall did not restore the backed-up XML"
[ "$(cat "$target/system/etc/fonts.xml")" = "restored-config" ] || fail "restored XML content differs"
[ ! -d "$TMP_ROOT/ufs/sha1" ] || fail "uninstall did not clear state directory"
[ ! -d "$lock" ] || fail "uninstall lock was not released"

printf 'UFS uninstall restore test passed.\n'
