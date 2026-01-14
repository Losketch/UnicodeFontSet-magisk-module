#!/system/bin/sh

MODPATH=${0%/*}
MODULE_PARENT="/data/adb/modules"
LOCK_DIR="/data/adb/ufs_lock"

echo "[UnicodeFontSet] Starting uninstall restore..."

i=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    i=$((i+1))
    sleep 0.1
    [ "$i" -gt 300 ] && {
        echo "[UnicodeFontSet] Failed to acquire lock, abort uninstall restore"
        exit 1
    }
done

trap 'rmdir "$LOCK_DIR" 2>/dev/null; exit 0' INT TERM EXIT

BACKUP_DIR="$MODPATH/backup"

[ ! -d "$BACKUP_DIR" ] && {
    echo "[UnicodeFontSet] WARNING: backup directory missing."
    echo "[UnicodeFontSet] Files modified by this module cannot be restored."
    exit 0
}

for MOD_BACKUP in "$BACKUP_DIR"/*; do
    [ ! -d "$MOD_BACKUP" ] && continue

    MOD_NAME=$(basename "$MOD_BACKUP")
    DST_MOD_DIR="$MODULE_PARENT/$MOD_NAME"

    # if [ ! -d "$DST_MOD_DIR" ] || [ -f "$DST_MOD_DIR/disable" ]; then
    if [ ! -d "$DST_MOD_DIR" ]; then
        echo "[UnicodeFontSet] Target module missing, skip restore: $MOD_NAME"
        continue
    fi

    echo "[UnicodeFontSet] Restoring module: $MOD_NAME"

    find "$MOD_BACKUP" -type f 2>/dev/null | while read -r SRC_FILE; do
        REL_PATH="${SRC_FILE#$MOD_BACKUP/}"
        DST_FILE="$DST_MOD_DIR/$REL_PATH"

        echo "[UnicodeFontSet]   Restore: $MOD_NAME/$REL_PATH"

        mkdir -p "$(dirname "$DST_FILE")" || continue
        cp -af "$SRC_FILE" "$DST_FILE"
    done
done

rm -rf "$MODPATH/sha1" 2>/dev/null

echo "[UnicodeFontSet] Restore complete."
exit 0
