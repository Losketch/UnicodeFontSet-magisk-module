#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib/lib.sh" || exit 1
ufs_init_context

[ -n "$API" ] || exit 0
[ "$API" -lt 26 ] && exit 0

if ! acquire_lock; then
    ui_print "$TXT_LOCK_BUSY"
    exit 0
fi

trap 'release_lock; exit 0' INT TERM EXIT
monitor_font_modules "ui_print"
