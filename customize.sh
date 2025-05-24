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

remove_old_fonts(){
  sed -i '/<!-- UnicodeFontSetModule Start -->/,/<!-- UnicodeFontSetModule End -->/d' "$1"
}

insert_fonts() {
    local file="$1"
    remove_old_fonts "$file"
    sed -i '/<\/familyset>/i \
<!-- UnicodeFontSetModule Start -->\
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
<\/family>\
<family>\
<font weight="400" style="normal">MonuLast.ttf<\/font>\
<\/family>\
<!-- UnicodeFontSetModule End -->' \
    "$file"
    ui_print "  ✓ 已向 $file 注入／刷新字体"
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

            SRC="$MIRRORPATH$P$FILE"
            if [ -f "$SRC" ]; then
                sha1sum "$SRC" | cut -d' ' -f1 > "$MODPATH/sha1_${P//\//_}_$FILE"
            fi

        elif [ -f "$SRC" ]; then
            ui_print "迁移并修改 $FILE ："
            mkdir -p "$DSTDIR"
            cp -af "$SRC" "$DST"
            insert_fonts "$DST"

            sha1sum "$SRC" | cut -d' ' -f1 > "$MODPATH/sha1_${P//\//_}_$FILE"
        fi
    done
done

chmod 755 "$MODPATH/service.sh"

ui_print "- Migration done."
rm -f "$MODPATH/LICENSE*" "$MODPATH/LICENSE_*" 2>/dev/null