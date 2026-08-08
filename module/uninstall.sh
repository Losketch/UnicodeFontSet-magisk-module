#!/system/bin/sh

MODPATH=${0%/*}
MODULE_PARENT="${UFS_MODULE_PARENT:-/data/adb/modules}"
LOCK_DIR="${UFS_LOCK_DIR:-/data/adb/ufs_lock}"
BACKUP_DIR="$MODPATH/backup"
FILE_LIST="$MODPATH/.uninstall-files.$$"

log_msg() {
    printf '[UnicodeFontSet] %s\n' "$1"
}

cleanup() {
    rm -f "$FILE_LIST" 2>/dev/null || true
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

strip_ufs_xml_block() {
    local src="$1"
    local dst="$2"
    awk '
        /^[[:space:]]*<!--[[:space:]]*UnicodeFontSetModule Start[[:space:]]*-->/ { in_ufs=1; next }
        /^[[:space:]]*<!--[[:space:]]*UnicodeFontSetModule End[[:space:]]*-->/ { in_ufs=0; next }
        !in_ufs { print }
    ' "$src" > "$dst"
}

log_msg "Starting uninstall restore..."

i=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    i=$((i + 1))
    sleep 0.1
    if [ "$i" -gt 300 ]; then
        log_msg "[!] Failed to acquire lock, abort uninstall restore"
        exit 1
    fi
done

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ ! -d "$BACKUP_DIR" ]; then
    log_msg "[!] WARNING: backup directory missing."
    log_msg "[!] Files modified by this module cannot be restored."
    exit 0
fi

RESTORED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for MOD_BACKUP in "$BACKUP_DIR"/*; do
    [ -d "$MOD_BACKUP" ] || continue

    MOD_NAME="$(basename "$MOD_BACKUP")"
    DST_MOD_DIR="$MODULE_PARENT/$MOD_NAME"

    if [ ! -d "$DST_MOD_DIR" ]; then
        log_msg "[-] Target module missing, skip restore: $MOD_NAME"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    if [ -f "$DST_MOD_DIR/remove" ]; then
        log_msg "[-] Target module pending removal: $MOD_NAME"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi

    if [ -f "$DST_MOD_DIR/disable" ]; then
        log_msg "[!] Target module is disabled: $MOD_NAME"
        log_msg "[!] Restoring anyway, but the module may not function until re-enabled."
    fi

    log_msg "[+] Restoring module: $MOD_NAME"
    if ! find "$MOD_BACKUP" -type f -print > "$FILE_LIST" 2>/dev/null; then
        log_msg "[!] Failed to enumerate backup files: $MOD_NAME"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi

    MODULE_FAILED=0
    while IFS= read -r SRC_FILE; do
        [ -n "$SRC_FILE" ] || continue
        REL_PATH="${SRC_FILE#$MOD_BACKUP/}"
        DST_FILE="$DST_MOD_DIR/$REL_PATH"
        DST_PARENT="$(dirname "$DST_FILE")"

        log_msg "    -> $REL_PATH"
        if ! mkdir -p "$DST_PARENT" 2>/dev/null; then
            log_msg "[!] Failed to create directory: $DST_PARENT"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            MODULE_FAILED=1
            continue
        fi

        # XML providers are patched in-place by current UFS versions. If the sibling changed its
        # XML while UFS was installed, stripping our managed block from the CURRENT file preserves
        # that newer sibling content. A current file without our marker is already sibling-owned and
        # must not be overwritten by a stale backup. Missing XML means the sibling removed that
        # provider and stays absent; missing duplicate binary fonts still use the pristine backup.
        if [ -f "$DST_FILE" ]; then
            if grep -q 'UnicodeFontSetModule Start' "$DST_FILE" 2>/dev/null; then
                TMP_RESTORE="${DST_FILE}.ufs-uninstall.$$"
                if strip_ufs_xml_block "$DST_FILE" "$TMP_RESTORE" \
                    && mv -f "$TMP_RESTORE" "$DST_FILE" 2>/dev/null; then
                    continue
                fi
                rm -f "$TMP_RESTORE" 2>/dev/null || true
                log_msg "[!] Failed to remove UFS XML block: $REL_PATH"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                MODULE_FAILED=1
                continue
            fi

            log_msg "       current sibling file has no UFS block; preserving newer file"
            continue
        fi

        case "$REL_PATH" in
            *.xml)
                # Current patch-in-place UFS never removes sibling XML. If it is missing now, the
                # sibling/user removed it after our backup was captured; preserve that deletion.
                log_msg "       sibling XML is currently absent; preserving deletion"
                continue
                ;;
        esac

        if ! cp -af "$SRC_FILE" "$DST_FILE" 2>/dev/null; then
            log_msg "[!] Failed to restore: $REL_PATH"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            MODULE_FAILED=1
        fi
    done < "$FILE_LIST"

    [ "$MODULE_FAILED" -eq 0 ] && RESTORED_COUNT=$((RESTORED_COUNT + 1))
done

rm -rf "$MODPATH/sha1" 2>/dev/null || true

log_msg "=========================================="
log_msg "Restore complete."
log_msg "  Restored modules: $RESTORED_COUNT"
log_msg "  Skipped modules:  $SKIPPED_COUNT"
log_msg "  Failed files:     $FAILED_COUNT"
log_msg "=========================================="

[ "$FAILED_COUNT" -eq 0 ]
