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

log_print "开始监控其他模块的字体文件变化..."

for MODULE_DIR in "$MODULE_PARENT"/*; do
    [ ! -d "$MODULE_DIR" ] && continue
    
    MOD_NAME=$(basename "$MODULE_DIR")
    
    # 跳过自己和禁用的模块
    if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
        continue
    fi
    
    for SUB in system/etc system_ext/etc; do
        TARGET_DIR="$MODULE_DIR/$SUB"
        
        for F in $TARGET_FILES; do
            TARGET_FILE="$TARGET_DIR/$F"
            BACKUP_FILE="$MODPATH/backup/$MOD_NAME/$SUB/$F"
            SHA1_FILE="$MODPATH/sha1_${MOD_NAME}_${SUB//\//_}_$F"
            
            if [ -f "$TARGET_FILE" ]; then
                # 发现有新的字体文件出现
                NEW_SHA1=$(sha1sum "$TARGET_FILE" | cut -d' ' -f1)
                
                if [ -f "$SHA1_FILE" ]; then
                    OLD_SHA1=$(cat "$SHA1_FILE")
                    if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
                        log_print "检测到$MOD_NAME更新了$SUB/$F，重新处理"
                    else
                        log_print "检测到$MOD_NAME重新创建了$SUB/$F"
                    fi
                else
                    log_print "检测到$MOD_NAME新增了$SUB/$F"
                fi
                
                # 备份新文件
                mkdir -p "$(dirname "$BACKUP_FILE")"
                cp -af "$TARGET_FILE" "$BACKUP_FILE"
                echo "$NEW_SHA1" > "$SHA1_FILE"
                
                # 替换到本模块的文件位置
                case "$SUB" in
                    system/etc) MY_FILE="$MODPATH/system/etc/$F" ;;
                    system_ext/etc) MY_FILE="$MODPATH/system/system_ext/etc/$F" ;;
                esac
                
                mkdir -p "$(dirname "$MY_FILE")"
                cp -af "$TARGET_FILE" "$MY_FILE"
                insert_fonts "$MY_FILE"
                
                # 删除其他模块的冲突文件
                rm -f "$TARGET_FILE"
                [ -d "$TARGET_DIR" ] && rmdir "$TARGET_DIR" 2>/dev/null
                
                log_print "已替换$MOD_NAME的$SUB/$F并重新注入字体"
                
            elif [ -f "$BACKUP_FILE" ]; then
                # 检查是否是模块被删除了
                if [ ! -d "$MODULE_DIR" ]; then
                    log_print "模块$MOD_NAME已被删除，清理相关备份"
                    rm -rf "$MODPATH/backup/$MOD_NAME"
                    rm -f "$MODPATH"/sha1_${MOD_NAME}_*
                fi
            fi
        done
    done
done

log_print "字体文件监控完成"
