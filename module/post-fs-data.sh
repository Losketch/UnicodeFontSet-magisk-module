#!/system/bin/sh

# Runs before module system overlays are mounted. This is the authoritative point for refreshing
# stock XML after OTA.
UFS_EARLY_BOOT=1
export UFS_EARLY_BOOT
MODDIR=${0%/*}
MODPATH="$MODDIR"
export MODPATH
. "$MODDIR/lib/lib.sh" || exit 1
ufs_init_context

[ -n "$API" ] || exit 0
[ "$API" -lt 26 ] && exit 0

if ! acquire_lock; then
    log_print "$TXT_LOCK_BUSY"
    exit 0
fi
trap 'release_lock; exit 0' INT TERM EXIT

log_print "$TXT_EARLY_REBASE_START"
if ! ufs_early_reconcile "log_print"; then
    log_print "$TXT_XML_REBASE_FAILED"
fi
