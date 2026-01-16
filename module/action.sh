#!/system/bin/sh

SCRIPT_REAL_PATH="$(readlink -f "$0")"
MODPATH="${SCRIPT_REAL_PATH%/*}"
API=$(getprop ro.build.version.sdk)

[ "$API" -lt 26 ] && exit 0

if [ -f "$MODPATH/common_functions.sh" ]; then
    source "$MODPATH/common_functions.sh"
else
    echo "[UnicodeFontSet] Error: common_functions.sh not found!"
    exit 1
fi

MODULE_PARENT="/data/adb/modules"
SELF_MOD_NAME=$(basename "$MODPATH")

SHA1_DIR="$MODPATH/sha1"
mkdir -p "$SHA1_DIR"

if ! acquire_lock; then
    log_print "$TXT_LOCK_BUSY"
    exit 0
fi

trap 'release_lock; exit 0' INT TERM EXIT

monitor_font_modules "ui_print"
