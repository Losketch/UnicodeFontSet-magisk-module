#!/system/bin/sh

MODPATH=${0%/*}
API=$(getprop ro.build.version.sdk)

[ "$API" -lt 26 ] && exit 0

if [ -f "$MODPATH/common_functions.sh" ]; then
    source "$MODPATH/common_functions.sh"
else
    exit 1
fi

MODULE_PARENT="/data/adb/modules"
TARGET_FILES="fonts.xml fonts_base.xml"
SELF_MOD_NAME=$(basename "$MODPATH")

log_print() {
    echo "[UnicodeFontSet] $1" >> /cache/magisk.log
}

log_print "开始检查其他模块的字体文件..."

for MODULE_DIR in "$MODULE_PARENT"/*; do
    [ ! -d "$MODULE_DIR" ] && continue
    
    MOD_NAME=$(basename "$MODULE_DIR")
    
    # 跳过自己和禁用的模块
    if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
        continue
    fi
    
    # 检查 system/etc/ 和 system_ext/etc/
    for SUB in system/etc system_ext/etc; do
        TARGET_DIR="$MODULE_DIR/$SUB"
        [ ! -d "$TARGET_DIR" ] && continue
        
        for F in $TARGET_FILES; do
            TARGET_FILE="$TARGET_DIR/$F"
            [ ! -f "$TARGET_FILE" ] && continue
            
            # 构建目标路径和SHA1文件路径
            OVERRIDE_DIR="$MODPATH/override/$MOD_NAME/$SUB"
            OVERRIDE_FILE="$OVERRIDE_DIR/$F"
            SHA1_FILE="$MODPATH/sha1_${MOD_NAME}_${SUB//\//_}_$F"
            
            NEW_SHA1=$(sha1sum "$TARGET_FILE" | cut -d' ' -f1)
            
            if [ ! -f "$SHA1_FILE" ]; then
                # 首次发现这个文件
                mkdir -p "$OVERRIDE_DIR"
                cp -af "$TARGET_FILE" "$OVERRIDE_FILE"
                insert_fonts "$OVERRIDE_FILE"
                echo "$NEW_SHA1" > "$SHA1_FILE"
                log_print "初次注入：$MOD_NAME/$SUB/$F"
                
            else
                # 检查是否有变化
                OLD_SHA1=$(cat "$SHA1_FILE")
                if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
                    mkdir -p "$OVERRIDE_DIR"
                    cp -af "$TARGET_FILE" "$OVERRIDE_FILE"
                    insert_fonts "$OVERRIDE_FILE"
                    echo "$NEW_SHA1" > "$SHA1_FILE"
                    log_print "检测到变化：$MOD_NAME/$SUB/$F，已重新注入"
                fi
            fi
        done
    done
done

log_print "字体注入检查完成"
