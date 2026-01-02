#!/system/bin/sh
API=$(getprop ro.build.version.sdk)
source "$MODPATH/common_functions.sh"

if command -v magisk > /dev/null; then
    MIRRORPATH="$(magisk --path)/.magisk/mirror"
else
    unset MIRRORPATH
fi

MODULE_PARENT="/data/adb/modules"
SELF_MOD_NAME=$(basename "$MODPATH")

if [ -z "$API" ]; then
    ui_print "Error: API level not set."
    exit 1
fi

[ "$API" -lt 26 ] && { ui_print "Android版本过低,跳过字体注入"; exit 0; }

SHA1_DIR="$MODPATH/sha1"
mkdir -p "$SHA1_DIR"

ui_print "正在处理其他模块的字体XML文件..."
FOUND_XML_MODULES=0

for MODULE_DIR in "$MODULE_PARENT"/*; do
    [ ! -d "$MODULE_DIR" ] && continue

    MOD_NAME=$(basename "$MODULE_DIR")

    if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
        continue
    fi

    MODULE_HAS_FONTS_XML=0

    for SUB in $FONT_XML_SUBDIRS; do
        TARGET_DIR="$MODULE_DIR/$SUB"
        [ ! -d "$TARGET_DIR" ] && continue

        for F in $FONT_XML_FILES; do
            TARGET_FILE="$TARGET_DIR/$F"
            [ ! -f "$TARGET_FILE" ] && continue

            if [ "$MODULE_HAS_FONTS_XML" -eq 0 ]; then
                ui_print "  发现模块: $MOD_NAME"
                MODULE_HAS_FONTS_XML=1
                FOUND_XML_MODULES=$((FOUND_XML_MODULES + 1))
            fi

            BACKUP_DIR="$MODPATH/backup/$MOD_NAME/$SUB"
            BACKUP_FILE="$BACKUP_DIR/$F"
            SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_$F")"

            mkdir -p "$BACKUP_DIR"
            if ! cp -af "$TARGET_FILE" "$BACKUP_FILE"; then
                ui_print "  ✗ 备份失败：$TARGET_FILE，跳过处理"
                continue
            fi
            sha1sum "$TARGET_FILE" | cut -d' ' -f1 > "$SHA1_FILE"

            rm -f "$TARGET_FILE"
            ui_print "  已删除并备份：$MOD_NAME/$SUB/$F"

            if [ -d "$TARGET_DIR" ] && [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
                rmdir "$TARGET_DIR" 2>/dev/null
            fi

            DSTDIR=$(get_module_target_path "$SUB")
            DST="$DSTDIR/$F"
            mkdir -p "$(dirname "$DST")"
            if ! cp -af "$BACKUP_FILE" "$DST"; then
                ui_print "  ✗ 复制失败：$DST"
                continue
            fi
            insert_fonts "$DST"
            ui_print "  已替换 $MOD_NAME/$SUB/$F"
        done
    done
done

if [ "$FOUND_XML_MODULES" -eq 0 ]; then
    ui_print "  未发现其他字体XML模块"
fi

process_binary_fonts_install

# --- 迁移并修改系统字体XML文件 (如果存在于镜像路径) ---
for F in $FONT_XML_FILES; do
    for P in /system/etc/ /system_ext/etc/; do
        SRC="$MIRRORPATH$P$F"

        DSTDIR=$(get_module_target_path "${P#/}")
        DST="$DSTDIR/$F"

        if [ -f "$SRC" ]; then
            ui_print "迁移并修改 $F (来自系统)："
            mkdir -p "$DSTDIR"
            if ! cp -af "$SRC" "$DST"; then
                ui_print "  ✗ 复制失败：$DST"
                continue
            fi
            insert_fonts "$DST"

            SHA1_FILE="$SHA1_DIR/sha1_system_${P//\//_}$F"
            sha1sum "$SRC" | cut -d' ' -f1 > "$SHA1_FILE"
        fi
    done
done

chmod 755 "$MODPATH/action.sh"
chmod 755 "$MODPATH/service.sh"
ui_print "- 安装完成,已清理冲突的字体文件"

if [ -x "$MODPATH/service.sh" ]; then
    sh "$MODPATH/service.sh" &
fi
rm -f "$MODPATH/LICENSE"* "$MODPATH/LICENSE_"* 2>/dev/null
