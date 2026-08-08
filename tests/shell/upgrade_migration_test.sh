#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ufs-upgrade-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

modules="$TMP_ROOT/modules"
update_root="$TMP_ROOT/modules_update/unicode_font_set"
old_ufs="$modules/unicode_font_set"
sibling="$modules/sibling"
mkdir -p "$update_root" "$old_ufs/backup/sibling/system/etc" "$sibling/system/etc"
cp -a "$REPO_ROOT/module/." "$update_root/"

# Simulate the legacy takeover model: UFS owns the pristine backup while the sibling XML itself
# was physically removed. Importing old state into the new patch-in-place model must restore it ONCE.
cat > "$old_ufs/backup/sibling/system/etc/fonts.xml" <<'XML'
<familyset>
  <family><font>LegacySibling.ttf</font></family>
</familyset>
XML

export MODPATH="$update_root"
export UFS_MODULE_PARENT="$modules"
export UFS_LOCK_DIR="$TMP_ROOT/lock"
export UFS_TEMP_DIR="$TMP_ROOT/tmp"
export UFS_LOG_FILE="$TMP_ROOT/ufs.log"
export UFS_LANG=en_US
export UFS_EARLY_BOOT=1

getprop() {
    case "$1" in
        ro.build.version.sdk) printf '%s\n' 35 ;;
        persist.sys.locale) printf '%s\n' en_US ;;
        *) printf '%s\n' '' ;;
    esac
}

# shellcheck source=/dev/null
. "$MODPATH/lib/lib.sh"
ufs_init_context
ufs_import_previous_state || fail "previous state import failed"

restored="$sibling/system/etc/fonts.xml"
[ -f "$restored" ] || fail "legacy taken-over sibling XML was not restored during upgrade"
grep -q 'LegacySibling.ttf' "$restored" || fail "restored legacy sibling XML has wrong content"
! grep -q 'UnicodeFontSetModule' "$restored" || fail "legacy pristine XML unexpectedly contains UFS block"

# New reconciliation then patches the restored sibling and removes any UFS-owned same-path overlay.
ufs_rebase_all_xml ':' || fail "post-import rebase failed"
[ "$(grep -c 'UnicodeFontSetModule Start' "$restored")" -eq 1 ] || fail "restored sibling was not patched exactly once"
[ ! -f "$MODPATH/system/etc/fonts.xml" ] || fail "UFS guessed precedence instead of deferring to sibling"

printf 'UFS legacy-upgrade migration test passed.\n'
