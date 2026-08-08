#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ufs-shell-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    actual=$1
    expected=$2
    message=$3
    [ "$actual" = "$expected" ] || fail "$message (expected=$expected actual=$actual)"
}

assert_file_absent() {
    [ ! -e "$1" ] || fail "expected path to be absent: $1"
}

# Work from an isolated module tree so tests never mutate the checkout.
cp -a "$REPO_ROOT/module" "$TMP_ROOT/module"
MODPATH="$TMP_ROOT/module"
export MODPATH
export UFS_LOG_FILE="$TMP_ROOT/ufs.log"
export UFS_LOCK_DIR="$TMP_ROOT/lock"
export UFS_MODULE_PARENT="$TMP_ROOT/modules"
export UFS_TEMP_DIR="$TMP_ROOT/tmp"
export UFS_LANG=""
mkdir -p "$UFS_MODULE_PARENT" "$UFS_TEMP_DIR"

# The installer/runtime may inject these callbacks. UFS must not shadow them.
ui_print() {
    printf 'HOST_UI:%s\n' "$1"
}
abort() {
    printf 'HOST_ABORT:%s\n' "$1"
    return 97
}

API=35
ARCH=arm64
export API ARCH

# shellcheck source=/dev/null
. "$MODPATH/lib/lib.sh"
ufs_init_context

ui_result=$(ui_print hello)
assert_eq "$ui_result" "HOST_UI:hello" "host ui_print callback was overwritten"
abort_result=$(abort stop || true)
assert_eq "$abort_result" "HOST_ABORT:stop" "host abort callback was overwritten"
assert_eq "$(ufs_resolve_api)" "35" "manager-provided API should take priority"
assert_eq "$(detect_arch)" "arm64-v8a" "manager-provided ARCH should take priority"

# XML injection must be idempotent: one managed block after any number of runs.
xml_file="$TMP_ROOT/fonts.xml"
cat > "$xml_file" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<familyset version="23">
    <family>
        <font weight="400">Existing.ttf</font>
    </family>
</familyset>
XML

insert_fonts "$xml_file" >/dev/null
insert_fonts "$xml_file" >/dev/null
start_count=$(grep -c 'UnicodeFontSetModule Start' "$xml_file")
end_count=$(grep -c 'UnicodeFontSetModule End' "$xml_file")
assert_eq "$start_count" "1" "XML managed block should not duplicate"
assert_eq "$end_count" "1" "XML managed block should not duplicate"
grep -q 'PlangothicP1-Regular.otf' "$xml_file" || fail "font fragment was not inserted"
grep -q '</familyset>' "$xml_file" || fail "familyset closing tag was lost"

# Removed modules are discovered from UFS backup state, not from an impossible
# "missing directory while iterating existing directories" branch.
removed_name="removed-font-module"
mkdir -p "$MODPATH/backup/$removed_name/system/etc" "$SHA1_DIR"
printf 'backup' > "$MODPATH/backup/$removed_name/system/etc/fonts.xml"
printf 'deadbeef' > "$SHA1_DIR/sha1_${removed_name}_system_etc_fonts.xml"
cleanup_removed_module_backups ':'
assert_file_absent "$MODPATH/backup/$removed_name"
assert_file_absent "$SHA1_DIR/sha1_${removed_name}_system_etc_fonts.xml"

# Binary takeover is one transaction: backup first, then remove the conflicting
# source only after state was persisted.
active_name="active-font-module"
active_font_dir="$UFS_MODULE_PARENT/$active_name/system/fonts"
mkdir -p "$active_font_dir"
printf 'font-payload' > "$active_font_dir/NotoSansSuper.otf"
flag=0
backup_file="$MODPATH/backup/$active_name/system/fonts/NotoSansSuper.otf"
state_file="$SHA1_DIR/sha1_${active_name}_system_fonts_NotoSansSuper.otf"
process_binary_font_action ':' "$active_name" 'system/fonts' \
    "$active_font_dir/NotoSansSuper.otf" 'NotoSansSuper.otf' \
    "$backup_file" "$state_file" flag
assert_eq "$flag" "1" "binary takeover should report an action"
[ -f "$backup_file" ] || fail "binary backup was not created"
[ -f "$state_file" ] || fail "binary state was not persisted"
assert_file_absent "$active_font_dir/NotoSansSuper.otf"

printf 'All UFS shell runtime tests passed.\n'
