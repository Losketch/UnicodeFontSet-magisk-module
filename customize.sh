#!/system/bin/sh
source "$MODPATH/common_functions.sh"

if command -v magisk > /dev/null; then
    MIRRORPATH="$(magisk --path)/.magisk/mirror"
else
    unset MIRRORPATH
fi

FILES="fonts.xml fonts_base.xml"
FILEPATHS="/system/etc/ /system_ext/etc/"

if [ -z "$API" ]; then
    ui_print "Error: API level not set."
    exit 1
fi

[ "$API" -lt 26 ] && { ui_print "Android版本过低，跳过字体注入"; exit 0; }

for FILE in $FILES; do
    for P in $FILEPATHS; do
        SRC="$MIRRORPATH$P$FILE"
        
        case "$P" in
            /system/*) DSTDIR="$MODPATH$P" ;;
            *)         DSTDIR="$MODPATH/system$P" ;;
        esac
        
        DST="$DSTDIR$FILE"
        SHA1_FILE="$MODPATH/sha1_${P//\//_}$FILE"
        
        if [ -f "$DST" ]; then
            ui_print "检测到已有模块已替换 $FILE，进行合并："
            insert_fonts "$DST"
        elif [ -f "$SRC" ]; then
            ui_print "迁移并修改 $FILE："
            mkdir -p "$DSTDIR"
            cp -af "$SRC" "$DST"
            insert_fonts "$DST"
            
            # 记录原始文件的SHA1
            sha1sum "$SRC" | cut -d' ' -f1 > "$SHA1_FILE"
        fi
    done
done

chmod 755 "$MODPATH/service.sh"
ui_print "- Migration done."
rm -f "$MODPATH/LICENSE*" "$MODPATH/LICENSE_*" 2>/dev/null
