#!/system/bin/sh

. "${0%/*}/lib/lib.sh"

API=$(getprop ro.build.version.sdk)
[ "$API" -lt 26 ] && exit 0

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
