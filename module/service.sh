#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib/lib.sh"
ufs_init_context

[ -n "$API" ] || exit 0
[ "$API" -lt 26 ] && exit 0

if ! acquire_lock; then
    log_print "$TXT_SERVICE_BUSY"
    exit 0
fi

trap 'release_lock; exit 0' INT TERM EXIT
log_print "$TXT_SERVICE_START"
monitor_font_modules "log_print"
