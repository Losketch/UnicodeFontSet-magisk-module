#!/system/bin/sh

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

insert_fonts() {
    local file="$1"
    # 如果已经插入过，就跳过
    if grep -q "NotoSansSuper\.ttf" "$file"; then
        ui_print "  • $file 已包含目标字体，跳过"
        return
    fi
    # 增量插入所有需要的 <family> 块
    sed -i '/<\/familyset>/i \
<family>\
<font weight="400" style="normal">CtrlCtrl.otf<\/font>\
<\/family>\
<family>\
<font weight="400" style="normal">PlangothicP1-Regular.ttf<\/font>\
<\/family>\
<family>\
<font weight="400" style="normal">PlangothicP2-Regular.ttf<\/font>\
<\/family>\
<family>\
<font weight="400" style="normal">NotoUnicode.otf<\/font>\
<\/family>\
<family>\
<font weight="400" style="normal">NotoSansSC-Regular.otf<\/font>\
<\/family>\
<family>\
<font weight="400" style="normal">NotoSansKR-Regular.otf<\/font>\
<\/family>\
<family>\
<font weight="400" style="normal">MonuTemp.ttf<\/font>\
<\/family>\
<family>\
<font weight="400" style="normal">NotoSansSuper.ttf<\/font>\
<\/family>\
<family>\
<font weight="400" style="normal">Unicode.ttf<\/font>\
<\/family>' \
    "$file"
    ui_print "  ✓ 已向 $file 注入字体"
}

for FILE in $FILES; do
    [ "$API" -lt 26 ] && continue

    for P in $FILEPATHS; do
        SRC="$MIRRORPATH$P$FILE"

        case "$P" in
            /system/*) DSTDIR="$MODPATH$P" ;;
            *)         DSTDIR="$MODPATH/system$P" ;;
        esac

        DST="$DSTDIR$FILE"

        if [ -f "$DST" ]; then
            ui_print "检测到已有模块已替换 $FILE，进行合并："
            insert_fonts "$DST"

        elif [ -f "$SRC" ]; then
            ui_print "迁移并修改 $FILE ："
            mkdir -p "$DSTDIR"
            cp -af "$SRC" "$DST"
            insert_fonts "$DST"
        fi
    done
done

ui_print "- Migration done."
rm -f "$MODPATH/LICENSE*" 2>/dev/null