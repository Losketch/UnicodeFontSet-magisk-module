#!/system/bin/sh

. "$MODPATH/lib/lib.sh"

API=$(getprop ro.build.version.sdk)

ui_print "$TXT_INSTALL_HEADER"
ui_print "$TXT_INSTALL_TITLE"
ui_print "$(safe_printf TXT_VERSION "$(grep '^version=' "$MODPATH/module.prop" | cut -d'=' -f2-)")"
ui_print "$TXT_INSTALL_HEADER"

if command -v magisk > /dev/null; then
    MAGISK_PATH="$(magisk --path)"
    MIRRORPATH="$MAGISK_PATH/.magisk/mirror"

    if [ ! -d "$MIRRORPATH/system" ]; then
        ui_print "$TXT_MAGISK_MIRROR_UNAVAIL"
        MIRRORPATH=""
    fi
else
    ui_print "$TXT_MAGISK_CMD_UNAVAIL"
    unset MIRRORPATH
fi

MODULE_PARENT="/data/adb/modules"
SELF_MOD_NAME=$(basename "$MODPATH")

if [ -z "$API" ]; then
    ui_print "$TXT_ERROR_API_LEVEL"
    exit 1
fi

[ "$API" -lt 26 ] && { ui_print "$TXT_API_TOO_LOW"; exit 0; }

SHA1_DIR="$MODPATH/sha1"
mkdir -p "$SHA1_DIR"

ui_print "$TXT_STEP_1"
ui_print "$TXT_INSTALL_XML_SCAN"
FOUND_XML_MODULES=0

for MODULE_DIR in "$MODULE_PARENT"/*; do
    [ ! -d "$MODULE_DIR" ] && continue

    MOD_NAME=$(basename "$MODULE_DIR")

    if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
        continue
    fi

    for SUB in $FONT_XML_SUBDIRS; do
        TARGET_DIR="$MODULE_DIR/$SUB"
        [ ! -d "$TARGET_DIR" ] && continue

        for F in $FONT_XML_FILES; do
            TARGET_FILE="$TARGET_DIR/$F"
            [ ! -f "$TARGET_FILE" ] && continue

            BACKUP_FILE="$MODPATH/backup/$MOD_NAME/$SUB/$F"
            SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_$F")"

            process_xml_font_action "ui_print" "$MOD_NAME" "$SUB" "$F" "$TARGET_FILE" "$BACKUP_FILE" "$SHA1_FILE" FOUND_XML_MODULES
        done
    done
done

if [ "$FOUND_XML_MODULES" -eq 0 ]; then
    ui_print "$TXT_XML_NONE"
fi

ui_print "$TXT_STEP_2"
process_binary_fonts_install

# --- 迁移并修改系统字体XML文件 (如果存在于镜像路径) ---
ui_print "$TXT_STEP_3"
ui_print "$TXT_INSTALL_SYSTEM_XML"
FOUND_SYSTEM_XML=0

for F in $FONT_XML_FILES; do
    for SUB in $FONT_XML_SUBDIRS; do
        P="/${SUB}/"

        if [ -n "$MIRRORPATH" ]; then
            SRC="$MIRRORPATH$P$F"
        else
            SRC="$P$F"
        fi

        DSTDIR=$(get_module_target_path "${P#/}")
        DST="$DSTDIR/$F"

        if [ -f "$SRC" ]; then
            if [ "$FOUND_SYSTEM_XML" -eq 0 ]; then
                FOUND_SYSTEM_XML=1
            fi

            ui_print "$(safe_printf "$TXT_INSTALL_PROCESS" "$SUB" "$F")"
            mkdir -p "$DSTDIR"
            if ! cp -af "$SRC" "$DST"; then
                ui_print "$(safe_printf "$TXT_INSTALL_COPY_FAIL" "$DST")"
                continue
            fi
            insert_fonts "$DST"

            SHA1_FILE="$SHA1_DIR/sha1_system_${P//\//_}$F"
            write_sha1_atomic "$(sha1sum "$SRC" | cut -d' ' -f1)" "$SHA1_FILE"
        fi
    done
done

if [ "$FOUND_SYSTEM_XML" -eq 0 ]; then
    ui_print "$TXT_SYSTEM_XML_NONE"
fi

ui_print "$TXT_STEP_4"

chmod 755 "$MODPATH/action.sh"
chmod 755 "$MODPATH/service.sh"
chmod 755 "$MODPATH/bin/"*

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

rm -f "$MODPATH/LICENSE"* "$MODPATH/LICENSE_"* 2>/dev/null
