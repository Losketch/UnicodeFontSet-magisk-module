# 日志函数
ui_print() {
    if [ -n "$OUTFD" ]; then
        echo "ui_print $1" >&$OUTFD
        echo "ui_print" >&$OUTFD
    else
        echo "$1"
    fi
}

# 移除旧的字体注入
remove_old_fonts() {
    local file="$1"
    [ ! -f "$file" ] && return 1
    sed -i '/<!-- UnicodeFontSetModule Start -->/,/<!-- UnicodeFontSetModule End -->/d' "$file"
}

# 移除指定模块的字体注入
remove_module_fonts() {
    local file="$1"
    local module_name="$2"
    [ ! -f "$file" ] && return 1
    sed -i "/<!-- ${module_name} fonts start -->/,/<!-- ${module_name} fonts end -->/d" "$file"
}

# 检查XML文件格式
check_xml_format() {
    local file="$1"
    if ! grep -q '</familyset>' "$file"; then
        ui_print "  ⚠ 警告：$file 格式可能不正确"
        return 1
    fi
    return 0
}

# 从备份文件中提取字体配置
extract_font_families() {
    local backup_file="$1"
    local module_name="$2"
    
    # 提取所有 <family> 块，排除本模块注入内容
    sed -n '/<family>/,/<\/family>/p' "$backup_file" | \
    sed '/<!-- UnicodeFontSetModule Start -->/,/<!-- UnicodeFontSetModule End -->/d' | \
    sed "1i <!-- ${module_name} fonts start -->" | \
    sed "$ a <!-- ${module_name} fonts end -->"
}

# 插入本模块字体配置
insert_fonts() {
    local file="$1"
    
    [ ! -f "$file" ] && { ui_print "  ✗ 文件不存在：$file"; return 1; }
    
    if ! check_xml_format "$file"; then
        return 1
    fi
    
    # 移除旧配置
    remove_old_fonts "$file"
    
    # 插入新配置
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
    
    if [ $? -eq 0 ]; then
        ui_print "  ✓ 已向 $(basename "$file") 注入字体配置"
        return 0
    else
        ui_print "  ✗ 注入失败：$(basename "$file")"
        return 1
    fi
}