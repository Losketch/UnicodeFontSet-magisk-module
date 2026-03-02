#!/system/bin/sh

MODPATH=${0%/*}
MODULE_PARENT="/data/adb/modules"
LOCK_DIR="/data/adb/ufs_lock"

log_msg() {
    echo "[UnicodeFontSet] $1"
}

log_msg "Starting uninstall restore..."

i=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    i=$((i+1))
    sleep 0.1
    [ "$i" -gt 300 ] && {
        log_msg "[!] Failed to acquire lock, abort uninstall restore"
        exit 1
    }
done

trap 'rmdir "$LOCK_DIR" 2>/dev/null; exit 0' INT TERM EXIT

BACKUP_DIR="$MODPATH/backup"

if [ ! -d "$BACKUP_DIR" ]; then
    log_msg "[!] WARNING: backup directory missing."
    log_msg "[!] Files modified by this module cannot be restored."
    exit 0
fi

RESTORED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for MOD_BACKUP in "$BACKUP_DIR"/*; do
    [ ! -d "$MOD_BACKUP" ] && continue

    MOD_NAME=$(basename "$MOD_BACKUP")
    DST_MOD_DIR="$MODULE_PARENT/$MOD_NAME"

    if [ ! -d "$DST_MOD_DIR" ]; then
        log_msg "[-] Target module missing, skip restore: $MOD_NAME"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    if [ -f "$DST_MOD_DIR/disable" ]; then
        log_msg "[!] Target module is disabled: $MOD_NAME"
        log_msg "[!] Restoring anyway, but the module may not function properly."
    fi

    if [ -f "$DST_MOD_DIR/remove" ]; then
        log_msg "[-] Target module pending removal: $MOD_NAME"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    log_msg "[+] Restoring module: $MOD_NAME"

    FILE_COUNT=0
    while read -r SRC_FILE; do
        REL_PATH="${SRC_FILE#$MOD_BACKUP/}"
        DST_FILE="$DST_MOD_DIR/$REL_PATH"

        log_msg "    -> $REL_PATH"

        if ! mkdir -p "$(dirname "$DST_FILE")" 2>/dev/null; then
            log_msg "[!] Failed to create directory: $(dirname "$DST_FILE")"
            continue
        fi

        if ! cp -af "$SRC_FILE" "$DST_FILE" 2>/dev/null; then
            log_msg "[!] Failed to restore: $REL_PATH"
            continue
        fi

        FILE_COUNT=$((FILE_COUNT + 1))
    done < <(find "$MOD_BACKUP" -type f 2>/dev/null)

    RESTORED_COUNT=$((RESTORED_COUNT + 1))
done

rm -rf "$MODPATH/sha1" 2>/dev/null

log_msg "=========================================="
log_msg "Restore complete."
log_msg "  Restored modules: $RESTORED_COUNT"
log_msg "  Skipped modules:  $SKIPPED_COUNT"
log_msg "=========================================="

exit 0
