#!/system/bin/sh
MODPATH=${0%/*}
API=$(getprop ro.build.version.sdk)

[ "$API" -lt 26 ] && exit 0

MODULE_PARENT="/data/adb/modules"
TARGET_FILES="fonts.xml fonts_base.xml"

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
<!-- UnicodeFontSetModule End -->' "$file"
}

SELF_MOD_NAME=$(basename "$MODPATH")

for MODULE_DIR in "$MODULE_PARENT"/*; do
  # 如果是自己模块就跳过
  if [ "$(basename "$MODULE_DIR")" = "$SELF_MOD_NAME" ]; then
    continue
  fi

  # 在该模块中查找 system/etc/ 和 system_ext/etc/
  for SUB in system/etc system_ext/etc; do
    TARGET_DIR="$MODULE_DIR/$SUB"
    [ ! -d "$TARGET_DIR" ] && continue

    for F in $TARGET_FILES; do
      [ ! -f "$TARGET_DIR/$F" ] && continue

      SHA1_FILE="$MODPATH/sha1_$(basename "$MODULE_DIR")_$(echo "$SUB" | tr '/ ' '_')_$F"
      DSTDIR="$MODPATH/$MODULE_DIR/$SUB"
      DST="$DSTDIR/$F"
      NEW_SHA1=$(sha1sum "$TARGET_DIR/$F" | cut -d' ' -f1)

      if [ ! -f "$SHA1_FILE" ]; then
        mkdir -p "$DSTDIR"; cp -af "$TARGET_DIR/$F" "$DST"; insert_fonts "$DST"
        echo "$NEW_SHA1" > "$SHA1_FILE"
        ui_print "⚡ 初次注入：$MODULE_DIR/$SUB/$F"
      else
        OLD_SHA1=$(cat "$SHA1_FILE")
        if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
          mkdir -p "$DSTDIR"; cp -af "$TARGET_DIR/$F" "$DST"; insert_fonts "$DST"
          echo "$NEW_SHA1" > "$SHA1_FILE"
          ui_print "⚡ 检测到变化：$MODULE_DIR/$SUB/$F，已重注"
        fi
      fi
    done
  done
done