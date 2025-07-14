#!/system/bin/sh
source "$MODPATH/common_functions.sh"

if command -v magisk > /dev/null; then
    MIRRORPATH="$(magisk --path)/.magisk/mirror"
else
    unset MIRRORPATH
fi

FILES="fonts.xml fonts_base.xml"
FILEPATHS="/system/etc/ /system_ext/etc/"
MODULE_PARENT="/data/adb/modules"
SELF_MOD_NAME=$(basename "$MODPATH")

if [ -z "$API" ]; then
    ui_print "Error: API level not set."
    exit 1
fi

[ "$API" -lt 26 ] && { ui_print "Android版本过低,跳过字体注入"; exit 0; }

# 优先处理其他模块的字体文件
ui_print "正在处理其他模块的字体文件..."
FOUND_MODULES=0

for MODULE_DIR in "$MODULE_PARENT"/*; do
    [ ! -d "$MODULE_DIR" ] && continue
    
    MOD_NAME=$(basename "$MODULE_DIR")
    
    # 跳过自己和禁用的模块
    if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
        continue
    fi
    
    MODULE_HAS_FONTS=0
    
    for SUB in system/etc system_ext/etc; do
        TARGET_DIR="$MODULE_DIR/$SUB"
        [ ! -d "$TARGET_DIR" ] && continue
        
        for F in $FILES; do
            TARGET_FILE="$TARGET_DIR/$F"
            [ ! -f "$TARGET_FILE" ] && continue
            
            if [ "$MODULE_HAS_FONTS" -eq 0 ]; then
                ui_print "  发现模块: $MOD_NAME"
                MODULE_HAS_FONTS=1
                FOUND_MODULES=$((FOUND_MODULES + 1))
            fi
            
            # 备份原始文件和记录SHA1
            BACKUP_DIR="$MODPATH/backup/$MOD_NAME/$SUB"
            BACKUP_FILE="$BACKUP_DIR/$F"
            SHA1_FILE="$MODPATH/sha1_${MOD_NAME}_${SUB//\//_}_$F"
            
            mkdir -p "$BACKUP_DIR"
            cp -af "$TARGET_FILE" "$BACKUP_FILE"
            sha1sum "$TARGET_FILE" | cut -d' ' -f1 > "$SHA1_FILE"
            
            # 删除其他模块的字体文件
            rm -f "$TARGET_FILE"
            ui_print "  已删除并备份：$MOD_NAME/$SUB/$F"
            
            # 如果目录为空则删除
            [ -d "$TARGET_DIR" ] && rmdir "$TARGET_DIR" 2>/dev/null
            
            # 替换到本模块的文件
            case "$SUB" in
                system/etc) DSTDIR="$MODPATH$SUB" ;;
                system_ext/etc) DSTDIR="$MODPATH/system$SUB" ;;
            esac
            
            DST="$DSTDIR/$F"
            mkdir -p "$(dirname "$DST")"
            cp -af "$TARGET_FILE" "$DST"
            insert_fonts "$DST"
            ui_print "  已替换 $MOD_NAME/$SUB/$F"
        done
    done
done

if [ "$FOUND_MODULES" -eq 0 ]; then
    ui_print "  未发现其他字体模块"
fi

# 如果还有系统的字体文件,则进行迁移
for FILE in $FILES; do
    for P in $FILEPATHS; do
        SRC="$MIRRORPATH$P$FILE"
        
        case "$P" in
            /system/*) DSTDIR="$MODPATH$P" ;;
            *)         DSTDIR="$MODPATH/system$P" ;;
        esac
        
        DST="$DSTDIR$FILE"
        
        if [ -f "$SRC" ]; then
            ui_print "迁移并修改 $FILE："
            mkdir -p "$DSTDIR"
            cp -af "$SRC" "$DST"
            insert_fonts "$DST"
            
            # 记录原始系统文件的SHA1
            SHA1_FILE="$MODPATH/sha1_system_${P//\//_}$FILE"
            sha1sum "$SRC" | cut -d' ' -f1 > "$SHA1_FILE"
        fi
    done
done

chmod 755 "$MODPATH/service.sh"
ui_print "- 安装完成,已清理冲突的字体文件"
rm -f "$MODPATH/LICENSE"* "$MODPATH/LICENSE_"* 2>/dev/null
