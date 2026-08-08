#!/system/bin/sh

. "$MODPATH/lib/lib.sh"
ufs_init_context

ui_print "$TXT_INSTALL_HEADER"
ui_print "$TXT_INSTALL_TITLE"
ui_print "$(safe_printf TXT_VERSION "$(grep '^version=' "$MODPATH/module.prop" | cut -d'=' -f2-)")"
ui_print "$TXT_INSTALL_HEADER"

if [ -z "$API" ]; then
    abort "$TXT_ERROR_API_LEVEL"
fi

if [ "$API" -lt 26 ]; then
    ui_print "$TXT_API_TOO_LOW"
    return 0 2>/dev/null || exit 0
fi

MIRRORPATH="$(ufs_resolve_mirror_path 2>/dev/null || true)"
if [ -z "$MIRRORPATH" ]; then
    if command -v magisk >/dev/null 2>&1 || [ -n "${MAGISKTMP:-}" ]; then
        ui_print "$TXT_MAGISK_MIRROR_UNAVAIL"
    else
        ui_print "$TXT_MAGISK_CMD_UNAVAIL"
    fi
fi

ui_print "$TXT_STEP_1"
ui_print "$TXT_INSTALL_XML_SCAN"
FOUND_XML_MODULES=0

for MODULE_DIR in "$MODULE_PARENT"/*; do
    [ -d "$MODULE_DIR" ] || continue
    MOD_NAME="$(basename "$MODULE_DIR")"

    if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ] || [ -f "$MODULE_DIR/remove" ]; then
        continue
    fi

    for SUB in $FONT_XML_SUBDIRS; do
        TARGET_DIR="$MODULE_DIR/$SUB"
        [ -d "$TARGET_DIR" ] || continue

        for F in $FONT_XML_FILES; do
            TARGET_FILE="$TARGET_DIR/$F"
            [ -f "$TARGET_FILE" ] || continue

            BACKUP_FILE="$MODPATH/backup/$MOD_NAME/$SUB/$F"
            SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_$F")"
            process_xml_font_action \
                "ui_print" "$MOD_NAME" "$SUB" "$F" "$TARGET_FILE" \
                "$BACKUP_FILE" "$SHA1_FILE" FOUND_XML_MODULES
        done
    done
done

[ "$FOUND_XML_MODULES" -eq 0 ] && ui_print "$TXT_XML_NONE"

ui_print "$TXT_STEP_2"
process_binary_fonts_install

ui_print "$TXT_STEP_3"
ui_print "$TXT_INSTALL_SYSTEM_XML"
FOUND_SYSTEM_XML=0
SYSTEM_ROOT="${UFS_SYSTEM_ROOT:-}"

for F in $FONT_XML_FILES; do
    for SUB in $FONT_XML_SUBDIRS; do
        if [ -n "$MIRRORPATH" ]; then
            SRC="$MIRRORPATH/$SUB/$F"
        else
            SRC="${SYSTEM_ROOT}/${SUB}/$F"
        fi
        DSTDIR="$(get_module_target_path "$SUB")"
        DST="$DSTDIR/$F"

        [ -f "$SRC" ] || continue
        FOUND_SYSTEM_XML=1
        ui_print "$(safe_printf TXT_INSTALL_PROCESS "$SUB" "$F")"

        mkdir -p "$DSTDIR" || continue
        if ! cp -af "$SRC" "$DST"; then
            ui_print "$(safe_printf TXT_INSTALL_COPY_FAIL "$DST")"
            continue
        fi
        if ! insert_fonts "$DST"; then
            rm -f "$DST"
            continue
        fi

        SHA1_FILE="$SHA1_DIR/sha1_system_$(get_safe_sha1_filename "${SUB}_$F")"
        write_sha1_atomic "$(sha1sum "$SRC" | cut -d' ' -f1)" "$SHA1_FILE"
    done
done

[ "$FOUND_SYSTEM_XML" -eq 0 ] && ui_print "$TXT_SYSTEM_XML_NONE"

ui_print "$TXT_STEP_4"
chmod 755 "$MODPATH/action.sh" "$MODPATH/service.sh" 2>/dev/null || true
chmod 755 "$MODPATH/bin/"* 2>/dev/null || true

ui_print "$TXT_INSTALL_SEPARATOR"
ui_print "$TXT_INSTALL_DONE"
ui_print "$TXT_INSTALL_SEPARATOR"

ask_run_cmap_cleaner

if [ -x "$MODPATH/service.sh" ]; then
    ui_print "$TXT_START_SERVICE"
    sh "$MODPATH/service.sh" &
fi

ui_print "$TXT_INSTALL_HEADER"
ui_print "$TXT_INSTALL_COMPLETE"
ui_print "$TXT_REBOOT_REQUIRED"
ui_print "$TXT_INSTALL_HEADER"

rm -f "$MODPATH/LICENSE"* "$MODPATH/LICENSE_"* 2>/dev/null || true
