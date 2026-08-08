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
mkdir -p "$UFS_MODULE_PARENT"
[ ! -e "$UFS_TEMP_DIR" ] || fail "test precondition: temp directory should not exist yet"

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
[ -d "$UFS_TEMP_DIR" ] || fail "ufs_init_context should create a missing temp directory"

ui_result=$(ui_print hello)
assert_eq "$ui_result" "HOST_UI:hello" "host ui_print callback was overwritten"
abort_result=$(abort stop || true)
assert_eq "$abort_result" "HOST_ABORT:stop" "host abort callback was overwritten"
assert_eq "$(ufs_resolve_api)" "35" "manager-provided API should take priority"
assert_eq "$(detect_arch)" "arm64-v8a" "manager-provided ARCH should take priority"


# BCP 47 / Android locale extensions must not shift Script into Region.
parse_locale 'zh_Hans_CN_u_fw_mon_mu_celsius'
assert_eq "$_LOCALE_LANG" "zh" "locale language parsing failed"
assert_eq "$_LOCALE_SCRIPT" "Hans" "locale script parsing failed"
assert_eq "$_LOCALE_REGION" "CN" "locale region parsing failed"
assert_eq "$_LOCALE_VARIANT" "" "Unicode extension payload must not become a locale variant"
parse_locale 'en-US-POSIX'
assert_eq "$_LOCALE_LANG" "en" "hyphenated locale language parsing failed"
assert_eq "$_LOCALE_REGION" "US" "hyphenated locale region parsing failed"
assert_eq "$_LOCALE_VARIANT" "POSIX" "locale variant parsing failed"

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


# Content-derived XML rebase: stock is used only when no active sibling provider exists.
stock_root="$TMP_ROOT/stock-root"
mkdir -p "$stock_root/system/etc"
cat > "$stock_root/system/etc/fonts.xml" <<'XML'
<familyset>
  <family><font>StockV1.ttf</font></family>
</familyset>
XML
ufs_refresh_stock_xml_from_root ':' "$stock_root"
ufs_rebase_all_xml ':'
ufs_xml="$MODPATH/system/etc/fonts.xml"
[ -f "$ufs_xml" ] || fail "stock XML was not materialized by UFS"
grep -q 'StockV1.ttf' "$ufs_xml" || fail "stock XML content missing from UFS overlay"
assert_eq "$(grep -c 'UnicodeFontSetModule Start' "$ufs_xml")" "1" "stock rebase duplicated UFS block"

# Two sibling providers for the same path are BOTH patched; UFS removes its own same-path overlay
# so the host manager/metamodule keeps its native precedence instead of UFS guessing an order.
for sibling in sibling-a sibling-b; do
    mkdir -p "$UFS_MODULE_PARENT/$sibling/system/etc"
done
cat > "$UFS_MODULE_PARENT/sibling-a/system/etc/fonts.xml" <<'XML'
<familyset>
  <family><font>SiblingA.ttf</font></family>
</familyset>
XML
cat > "$UFS_MODULE_PARENT/sibling-b/system/etc/fonts.xml" <<'XML'
<familyset><family><font>SiblingB.ttf</font></family></familyset>
XML
ufs_rebase_all_xml ':'
assert_file_absent "$ufs_xml"
for sibling in sibling-a sibling-b; do
    managed="$UFS_MODULE_PARENT/$sibling/system/etc/fonts.xml"
    backup="$MODPATH/backup/$sibling/system/etc/fonts.xml"
    [ -f "$backup" ] || fail "pristine sibling backup missing: $sibling"
    assert_eq "$(grep -c 'UnicodeFontSetModule Start' "$managed")" "1" "sibling UFS block missing/duplicated: $sibling"
done
grep -q 'SiblingA.ttf' "$MODPATH/backup/sibling-a/system/etc/fonts.xml" || fail "sibling A backup is not pristine"
! grep -q 'UnicodeFontSetModule' "$MODPATH/backup/sibling-a/system/etc/fonts.xml" || fail "sibling backup contains UFS block"

# Re-running reconciliation is idempotent.
ufs_rebase_all_xml ':'
assert_eq "$(grep -c 'UnicodeFontSetModule Start' "$UFS_MODULE_PARENT/sibling-a/system/etc/fonts.xml")" "1" "sibling reconcile is not idempotent"

# Disabled/removed providers no longer suppress the UFS stock overlay.
touch "$UFS_MODULE_PARENT/sibling-a/disable" "$UFS_MODULE_PARENT/sibling-b/remove"
ufs_rebase_all_xml ':'
[ -f "$ufs_xml" ] || fail "stock overlay was not restored after siblings became inactive"
grep -q 'StockV1.ttf' "$ufs_xml" || fail "wrong stock base after sibling disable/remove"

# skip_mount modules are not system providers and must not suppress the stock-derived UFS overlay.
mkdir -p "$UFS_MODULE_PARENT/sibling-skip/system/etc"
cat > "$UFS_MODULE_PARENT/sibling-skip/system/etc/fonts.xml" <<'XML'
<familyset>
  <family><font>SkipMount.ttf</font></family>
</familyset>
XML
touch "$UFS_MODULE_PARENT/sibling-skip/skip_mount"
ufs_rebase_all_xml ':'
[ -f "$ufs_xml" ] || fail "skip_mount sibling incorrectly suppressed stock overlay"
assert_file_absent "$MODPATH/backup/sibling-skip/system/etc/fonts.xml"

# Re-enabling a sibling automatically restores native precedence and removes UFS's same-path XML.
rm -f "$UFS_MODULE_PARENT/sibling-b/remove"
ufs_rebase_all_xml ':'
assert_file_absent "$ufs_xml"

# A sibling update replaces the pristine backup, then receives exactly one fresh UFS block.
cat > "$UFS_MODULE_PARENT/sibling-b/system/etc/fonts.xml" <<'XML'
<familyset>
  <family><font>SiblingB-V2.ttf</font></family>
</familyset>
XML
ufs_rebase_all_xml ':'
grep -q 'SiblingB-V2.ttf' "$MODPATH/backup/sibling-b/system/etc/fonts.xml" || fail "sibling update did not refresh pristine backup"
! grep -q 'UnicodeFontSetModule' "$MODPATH/backup/sibling-b/system/etc/fonts.xml" || fail "updated sibling backup contains UFS block"
assert_eq "$(grep -c 'UnicodeFontSetModule Start' "$UFS_MODULE_PARENT/sibling-b/system/etc/fonts.xml")" "1" "updated sibling was not re-injected exactly once"

# If an active sibling later removes the XML path, a stale backup must NOT resurrect that provider.
rm -f "$UFS_MODULE_PARENT/sibling-b/system/etc/fonts.xml"
ufs_rebase_all_xml ':'
[ -f "$ufs_xml" ] || fail "stock overlay was not restored after sibling dropped XML path"
assert_file_absent "$UFS_MODULE_PARENT/sibling-b/system/etc/fonts.xml"
assert_file_absent "$MODPATH/backup/sibling-b/system/etc/fonts.xml"

# OTA-like stock changes are captured from the authoritative pre-mount root and rebased.
touch "$UFS_MODULE_PARENT/sibling-b/disable"
cat > "$stock_root/system/etc/fonts.xml" <<'XML'
<familyset>
  <family><font>StockV2-OTA.ttf</font></family>
</familyset>
XML
ufs_refresh_stock_xml_from_root ':' "$stock_root"
ufs_rebase_all_xml ':'
[ -f "$ufs_xml" ] || fail "OTA stock XML was not materialized"
grep -q 'StockV2-OTA.ttf' "$ufs_xml" || fail "OTA stock change was not rebased"
! grep -q 'StockV1.ttf' "$ufs_xml" || fail "stale pre-OTA stock XML survived rebase"

# A stock XML removed by OTA must remove the stale UFS overlay too.
rm -f "$stock_root/system/etc/fonts.xml"
ufs_refresh_stock_xml_from_root ':' "$stock_root"
ufs_rebase_all_xml ':'
assert_file_absent "$ufs_xml"

printf 'All UFS shell runtime tests passed.\n'
