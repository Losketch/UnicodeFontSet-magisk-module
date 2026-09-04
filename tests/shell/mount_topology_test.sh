#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ufs-topology-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

cp -a "$REPO_ROOT/module" "$TMP_ROOT/module"
MODPATH="$TMP_ROOT/module"
export MODPATH
export UFS_MODULE_PARENT="$TMP_ROOT/modules"
export UFS_SYSTEM_ROOT="$TMP_ROOT/root"
export UFS_TEMP_DIR="$TMP_ROOT/tmp"
export UFS_LOCK_DIR="$TMP_ROOT/lock"
export UFS_LOG_FILE="$TMP_ROOT/ufs.log"
export UFS_USER_CONFIG="$TMP_ROOT/config.conf"
export UFS_LANG=en_US
mkdir -p "$UFS_MODULE_PARENT" "$UFS_SYSTEM_ROOT/system/etc" \
    "$UFS_SYSTEM_ROOT/system_ext/etc" "$UFS_SYSTEM_ROOT/product/etc"
ln -s ../system_ext "$UFS_SYSTEM_ROOT/system/system_ext"
ln -s ../product "$UFS_SYSTEM_ROOT/system/product"

cat > "$UFS_SYSTEM_ROOT/system/etc/fonts.xml" <<'XML'
<familyset><family><font>System.ttf</font></family></familyset>
XML
cat > "$UFS_SYSTEM_ROOT/system_ext/etc/fonts_base.xml" <<'XML'
<familyset><family><font>SystemExt.ttf</font></family></familyset>
XML
API=36
ARCH=arm64
export API ARCH
# shellcheck source=/dev/null
. "$MODPATH/lib/lib.sh"
ufs_init_context

test_print() {
    printf '%s\n' "$1" >> "$UFS_LOG_FILE"
}

# APatch: capture stock topology before overlay mounting, then keep UFS-owned special aliases out.
export APATCH=true
ufs_refresh_stock_xml_from_root test_print "$UFS_SYSTEM_ROOT" || fail 'stock refresh failed'
[ "$(cat "$MODPATH/stock/.topology/system_system_ext.type")" = symlink ] || fail 'system_ext topology was not captured as symlink'
ufs_rebase_all_xml test_print || fail 'APatch safety rebase failed'
[ -f "$MODPATH/system/etc/fonts.xml" ] || fail 'safe system/etc XML was not materialized'
[ ! -e "$MODPATH/system/system_ext" ] || fail 'UFS-owned system_ext alias was materialized under APatch'
[ ! -e "$MODPATH/system/product" ] || fail 'empty product alias was materialized without XML payload'
grep -q 'Mount-safety fallback' "$UFS_LOG_FILE" || fail 'safety fallback was not reported to the user'

# Explicit force mode restores standard Magisk-layout materialization without identifying the
# installed metamodule. The user assumes responsibility for mount-backend compatibility.
printf '%s\n' 'SPECIAL_PARTITION_XML_MODE=force' > "$UFS_USER_CONFIG"
ufs_init_context
ufs_rebase_all_xml test_print || fail 'APatch force-mode rebase failed'
[ -f "$MODPATH/system/system_ext/etc/fonts_base.xml" ] || fail 'force mode did not restore UFS-owned system_ext XML'
grep -q 'Special-partition XML mode is force' "$UFS_LOG_FILE" || fail 'force-mode safety warning was not reported'

# Invalid values must fail safely back to safe and clean the UFS-owned alias again.
printf '%s\n' 'SPECIAL_PARTITION_XML_MODE=invalid-value' > "$UFS_USER_CONFIG"
ufs_init_context
[ "$UFS_SPECIAL_PARTITION_XML_EFFECTIVE_MODE" = safe ] || fail 'invalid special-partition XML mode did not fall back to safe'
ufs_rebase_all_xml test_print || fail 'invalid-mode safe fallback rebase failed'
[ ! -e "$MODPATH/system/system_ext" ] || fail 'invalid mode retained UFS-owned system_ext alias'
grep -q 'Invalid SPECIAL_PARTITION_XML_MODE=invalid-value' "$UFS_LOG_FILE" || fail 'invalid mode warning was not reported'

# Keep the remainder of the test in the documented default mode.
printf '%s\n' 'SPECIAL_PARTITION_XML_MODE=safe' > "$UFS_USER_CONFIG"
ufs_init_context

# Guard only UFS-owned materialization: an existing sibling provider must still be patched in place.
mkdir -p "$UFS_MODULE_PARENT/sibling/system/system_ext/etc"
cat > "$UFS_MODULE_PARENT/sibling/module.prop" <<'PROP'
id=sibling
name=Sibling Font Module
version=1
versionCode=1
PROP
cat > "$UFS_MODULE_PARENT/sibling/system/system_ext/etc/fonts_base.xml" <<'XML'
<familyset><family><font>Sibling.ttf</font></family></familyset>
XML
ufs_rebase_all_xml test_print || fail 'sibling patch under guarded alias failed'
grep -q "$MODULE_START_COMMENT" "$UFS_MODULE_PARENT/sibling/system/system_ext/etc/fonts_base.xml" || fail 'guard incorrectly skipped sibling XML patching'
[ ! -e "$MODPATH/system/system_ext" ] || fail 'sibling patch caused UFS-owned alias materialization'
rm -rf "$UFS_MODULE_PARENT/sibling"

# Old UFS payload from a previous build must be removed completely, including the empty partition root.
mkdir -p "$MODPATH/system/system_ext/etc"
printf stale > "$MODPATH/system/system_ext/etc/fonts_base.xml"
ufs_rebase_all_xml test_print || fail 'stale alias cleanup failed'
[ ! -e "$MODPATH/system/system_ext" ] || fail 'stale system_ext alias directory survived cleanup'

# Native Magisk keeps the standard special-partition layout: do not apply the KSU/APatch guard.
unset APATCH
unset KSU 2>/dev/null || true
ufs_rebase_all_xml test_print || fail 'Magisk rebase failed'
[ -f "$MODPATH/system/system_ext/etc/fonts_base.xml" ] || fail 'native Magisk special-partition XML was incorrectly degraded'
rm -rf "$MODPATH/system/system_ext"

# KernelSU receives the same conservative self-owned guard without inspecting metamodule identity.
export KSU=true
ufs_rebase_all_xml test_print || fail 'KernelSU safety rebase failed'
[ ! -e "$MODPATH/system/system_ext" ] || fail 'KernelSU re-enabled UFS-owned system_ext alias materialization'
unset KSU

# A real stock directory under /system is structurally safe even in APatch and should remain supported.
export APATCH=true
rm -f "$UFS_SYSTEM_ROOT/system/system_ext" "$UFS_SYSTEM_ROOT/system/product"
mkdir -p "$UFS_SYSTEM_ROOT/system/system_ext/etc" "$UFS_SYSTEM_ROOT/system/product/etc"
cp "$UFS_SYSTEM_ROOT/system_ext/etc/fonts_base.xml" "$UFS_SYSTEM_ROOT/system/system_ext/etc/fonts_base.xml"
cat > "$UFS_SYSTEM_ROOT/system/product/etc/fonts.xml" <<'XML'
<familyset><family><font>Product.ttf</font></family></familyset>
XML
ufs_refresh_stock_xml_from_root test_print "$UFS_SYSTEM_ROOT" || fail 'real-directory topology refresh failed'
ufs_rebase_all_xml test_print || fail 'real-directory topology rebase failed'
[ -f "$MODPATH/system/system_ext/etc/fonts_base.xml" ] || fail 'safe real-directory system_ext XML was not materialized'
[ -f "$MODPATH/system/product/etc/fonts.xml" ] || fail 'safe real-directory product XML was not materialized'

# If topology has not been captured yet, KSU/APatch must not infer safety from an already-overlaid
# real directory. Treat the unknown state conservatively until the next pre-mount refresh.
rm -rf "$MODPATH/system/system_ext" "$MODPATH/stock/.topology/system_system_ext.type"
ufs_rebase_all_xml test_print || fail 'unknown-topology conservative rebase failed'
[ ! -e "$MODPATH/system/system_ext" ] || fail 'unknown topology allowed UFS-owned special alias materialization'
grep -q 'stock type of /system/system_ext is not available yet' "$UFS_LOG_FILE" || fail 'unknown-topology fallback was not reported'

# Restore the risky stock topology and verify fail-closed cleanup for unknown UFS-module residuals.
rm -rf "$UFS_SYSTEM_ROOT/system/system_ext" "$UFS_SYSTEM_ROOT/system/product"
ln -s ../system_ext "$UFS_SYSTEM_ROOT/system/system_ext"
ln -s ../product "$UFS_SYSTEM_ROOT/system/product"
ufs_refresh_stock_xml_from_root test_print "$UFS_SYSTEM_ROOT" || fail 'risk topology refresh failed'
mkdir -p "$MODPATH/system/system_ext"
printf unexpected > "$MODPATH/system/system_ext/unknown.payload"
if ufs_rebase_all_xml test_print; then
    fail 'unknown residual under guarded UFS alias should fail closed'
fi
[ -f "$MODPATH/system/system_ext/unknown.payload" ] || fail 'fail-closed cleanup removed unknown payload'

printf 'UFS mount-topology regression test passed.\n'
