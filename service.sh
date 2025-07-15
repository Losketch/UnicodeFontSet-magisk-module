#!/system/bin/sh

MODPATH=${0%/*}
API=$(getprop ro.build.version.sdk)

[ "$API" -lt 26 ] && exit 0

if [ -f "$MODPATH/common_functions.sh" ]; then
    source "$MODPATH/common_functions.sh"
else
    echo "Error: common_functions.sh not found!" >> /cache/ufs.log
    exit 1
fi

MODULE_PARENT="/data/adb/modules"
SELF_MOD_NAME=$(basename "$MODPATH")

SHA1_DIR="$MODPATH/sha1"
mkdir -p "$SHA1_DIR"

log_print "开始监控其他模块的字体文件变化..."

# --- 监控其他模块的字体XML文件 ---
for MODULE_DIR in "$MODULE_PARENT"/*; do
    [ ! -d "$MODULE_DIR" ] && continue

    MOD_NAME=$(basename "$MODULE_DIR")

    if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
        continue
    fi

    for SUB in $FONT_XML_SUBDIRS; do
        TARGET_DIR="$MODULE_DIR/$SUB"

        for F in $FONT_XML_FILES; do
            TARGET_FILE="$TARGET_DIR/$F"
            BACKUP_FILE="$MODPATH/backup/$MOD_NAME/$SUB/$F"
            SHA1_FILE="$SHA1_DIR/sha1_${MOD_NAME}_${SUB//\//_}_$F"

            if [ -f "$TARGET_FILE" ]; then
                NEW_SHA1=$(sha1sum "$TARGET_FILE" | cut -d' ' -f1)

                ACTION_TAKEN=0
                if [ -f "$SHA1_FILE" ]; then
                    OLD_SHA1=$(cat "$SHA1_FILE")
                    if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
                        log_print "检测到模块 $MOD_NAME 更新了字体XML文件 $SUB/$F，重新处理。"
                        ACTION_TAKEN=1
                    else
                        log_print "检测到模块 $MOD_NAME 重新创建了字体XML文件 $SUB/$F。"
                        ACTION_TAKEN=1
                    fi
                else
                    log_print "检测到模块 $MOD_NAME 新增了字体XML文件 $SUB/$F。"
                    ACTION_TAKEN=1
                fi

                if [ "$ACTION_TAKEN" -eq 1 ]; then
                    mkdir -p "$(dirname "$BACKUP_FILE")"
                    cp -af "$TARGET_FILE" "$BACKUP_FILE"
                    echo "$NEW_SHA1" > "$SHA1_FILE"

                    MY_FILE=$(get_module_target_path "$SUB")/$F
                    mkdir -p "$(dirname "$MY_FILE")"
                    cp -af "$TARGET_FILE" "$MY_FILE"
                    insert_fonts "$MY_FILE"

                    rm -f "$TARGET_FILE"
                    [ -d "$TARGET_DIR" ] && rmdir "$TARGET_DIR" 2>/dev/null

                    log_print "已替换 $MOD_NAME 的 $SUB/$F 并重新注入字体。"
                fi

            elif [ -f "$BACKUP_FILE" ]; then
                if [ ! -d "$MODULE_DIR" ]; then
                    log_print "模块 $MOD_NAME 已被删除，清理相关字体XML备份 ($SUB)。"
                    rm -rf "$MODPATH/backup/$MOD_NAME/$SUB"
                    rm -f "$SHA1_DIR"/sha1_${MOD_NAME}_${SUB//\//_}_$F
                fi
            fi
        done
    done
done

THIS_MODULE_BINARY_FONTS=$(get_this_module_font_binaries)
if [ -z "$THIS_MODULE_BINARY_FONTS" ]; then
    log_print "警告: 本模块的 system/fonts 目录下未发现字体文件，将无法处理其他模块的重名字体。"
fi

# --- 监控其他模块的字体二进制文件---
for MODULE_DIR in "$MODULE_PARENT"/*; do
    [ ! -d "$MODULE_DIR" ] && continue

    MOD_NAME=$(basename "$MODULE_DIR")

    if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
        continue
    fi

    for SUB in $FONT_BINARY_SUBDIRS; do
        TARGET_DIR="$MODULE_DIR/$SUB"
        [ ! -d "$TARGET_DIR" ] && continue

        find "$TARGET_DIR" -maxdepth 1 -type f -print | while read -r FONT_FILE; do
            FONT_FILENAME=$(basename "$FONT_FILE")

            if [ -z "$THIS_MODULE_BINARY_FONTS" ]; then
                continue
            fi

            # 匹配逻辑: 检查 " $FONT_FILENAME " 是否存在于 " $THIS_MODULE_BINARY_FONTS " 中
            if echo "$THIS_MODULE_BINARY_FONTS" | grep -q " $FONT_FILENAME "; then
                BACKUP_DIR="$MODPATH/backup/$MOD_NAME/$SUB"
                BACKUP_FILE="$BACKUP_DIR/$FONT_FILENAME"
                SHA1_FILE="$SHA1_DIR/sha1_${MOD_NAME}_${SUB//\//_}_${FONT_FILENAME}"

                NEW_SHA1=$(sha1sum "$FONT_FILE" | cut -d' ' -f1)
                ACTION_TAKEN=0

                if [ -f "$SHA1_FILE" ]; then
                    OLD_SHA1=$(cat "$SHA1_FILE")
                    if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
                        log_print "检测到模块 $MOD_NAME 更新了重名字体二进制文件 $SUB/$FONT_FILENAME，重新处理。"
                        ACTION_TAKEN=1
                    else
                        log_print "检测到模块 $MOD_NAME 重新创建了重名字体二进制文件 $SUB/$FONT_FILENAME。"
                        ACTION_TAKEN=1
                    fi
                else
                    log_print "检测到模块 $MOD_NAME 新增了重名字体二进制文件 $SUB/$FONT_FILENAME。"
                    ACTION_TAKEN=1
                fi

                if [ "$ACTION_TAKEN" -eq 1 ]; then
                    mkdir -p "$(dirname "$BACKUP_FILE")"
                    cp -af "$FONT_FILE" "$BACKUP_FILE"
                    echo "$NEW_SHA1" > "$SHA1_FILE"

                    rm -f "$FONT_FILE"
                    log_print "已删除并备份：$MOD_NAME/$SUB/$FONT_FILENAME"

                    [ -d "$TARGET_DIR" ] && rmdir "$TARGET_DIR" 2>/dev/null
                fi
            fi
        done
    done

    # 清理已删除模块的二进制字体备份
    if [ ! -d "$MODULE_DIR" ]; then
        for SUB in $FONT_BINARY_SUBDIRS; do
            if [ -d "$MODPATH/backup/$MOD_NAME/$SUB" ]; then
                log_print "模块 $MOD_NAME 已被删除，清理相关字体二进制备份 ($SUB)。"
                rm -rf "$MODPATH/backup/$MOD_NAME/$SUB"
                find "$SHA1_DIR" -maxdepth 1 -type f -name "sha1_${MOD_NAME}_${SUB//\//_}_*" -delete
            fi
        done
    fi
done

log_print "字体文件监控完成"
