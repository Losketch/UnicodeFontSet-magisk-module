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
backup_root="$TMP_ROOT/ufs/backup/example-font-module"
backup="$backup_root/system/etc/fonts.xml"
binary_backup="$backup_root/system/fonts/Shared.ttf"
mkdir -p "$target/system/etc" "$target/system/fonts" "$(dirname "$backup")" "$(dirname "$binary_backup")" "$TMP_ROOT/ufs/sha1"
printf 'old-sibling-config\n' > "$backup"
printf 'restored-binary\n' > "$binary_backup"
printf 'state' > "$TMP_ROOT/ufs/sha1/example"

# Current patch-in-place UFS never removes sibling XML, so a missing XML is preserved as a sibling
# deletion. Duplicate binary fonts are still takeover-based and must be restored when missing.
UFS_MODULE_PARENT="$modules" UFS_LOCK_DIR="$lock" \
    /usr/bin/env sh "$TMP_ROOT/ufs/uninstall.sh" >/dev/null
[ ! -f "$target/system/etc/fonts.xml" ] || fail "uninstall resurrected a deleted sibling XML"
[ -f "$target/system/fonts/Shared.ttf" ] || fail "uninstall did not restore the backed-up binary font"
[ "$(cat "$target/system/fonts/Shared.ttf")" = "restored-binary" ] || fail "restored binary content differs"
[ ! -d "$TMP_ROOT/ufs/sha1" ] || fail "uninstall did not clear state directory"
[ ! -d "$lock" ] || fail "uninstall lock was not released"

# Current patched XML wins over an older backup: uninstall strips only UFS's managed block and
# preserves sibling changes made outside that block.
mkdir -p "$TMP_ROOT/ufs/sha1"
cat > "$backup" <<'XML'
<familyset>
  <family><font>OldSibling.ttf</font></family>
</familyset>
XML
cat > "$target/system/etc/fonts.xml" <<'XML'
<familyset>
  <family><font>SiblingUpdatedWhileUFSInstalled.ttf</font></family>
<!-- UnicodeFontSetModule Start -->
  <family><font>UFS.ttf</font></family>
<!-- UnicodeFontSetModule End -->
</familyset>
XML
UFS_MODULE_PARENT="$modules" UFS_LOCK_DIR="$lock" \
    /usr/bin/env sh "$TMP_ROOT/ufs/uninstall.sh" >/dev/null
current="$target/system/etc/fonts.xml"
grep -q 'SiblingUpdatedWhileUFSInstalled.ttf' "$current" || fail "uninstall lost newer sibling XML content"
! grep -q 'UnicodeFontSetModule' "$current" || fail "uninstall left UFS XML markers behind"
! grep -q 'OldSibling.ttf' "$current" || fail "uninstall overwrote newer sibling XML with stale backup"

# If a sibling already replaced the patched file with its own clean update, uninstall leaves it alone.
cat > "$target/system/etc/fonts.xml" <<'XML'
<familyset>
  <family><font>SiblingCleanV3.ttf</font></family>
</familyset>
XML
UFS_MODULE_PARENT="$modules" UFS_LOCK_DIR="$lock" \
    /usr/bin/env sh "$TMP_ROOT/ufs/uninstall.sh" >/dev/null
grep -q 'SiblingCleanV3.ttf' "$current" || fail "uninstall overwrote sibling-owned clean XML"
! grep -q 'OldSibling.ttf' "$current" || fail "stale backup replaced clean sibling XML"

printf 'UFS uninstall restore test passed.\n'
