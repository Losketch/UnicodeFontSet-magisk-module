
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
