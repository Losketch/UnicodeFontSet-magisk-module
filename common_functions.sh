# --- 全局配置变量 ---
# 字体XML配置文件列表
FONT_XML_FILES="fonts.xml fonts_base.xml fonts_fallback.xml fonts_inter.xml fonts_slate.xml fonts_ule.xml font_fallback.xml fonts_flyme.xml flyme_fallback.xml flyme_font_fallback.xml"
FONT_XML_SUBDIRS="system/etc system/product/etc system_ext/etc"

true <<'EOF'
flyme_fallback.xml      flyme_font_fallback.xml
fonts.xml               fonts_base.xml
fonts_fallback.xml      fonts_flyme.xml
fonts_inter.xml         fonts_slate.xml
fonts_ule.xml           font_fallback.xml
EOF

true <<'EOF'
system/etc
system/product/etc
system/system_ext/etc
EOF

FONT_BINARY_SUBDIRS="system/fonts"
LOCK_DIR="/data/adb/ufs_lock"

# --- 辅助函数 ---

# 日志函数
ui_print() {
    if [ -n "$OUTFD" ]; then
        echo "ui_print $1" >&$OUTFD
        echo "ui_print" >&$OUTFD
    else
        echo "$1"
    fi
}

log_print() {
    mkdir -p "$(dirname /cache/ufs.log)" 2>/dev/null
    echo "[UnicodeFontSet]($(date '+%Y-%m-%d %H:%M')) $1" >> /cache/ufs.log
}

# 根据原始子目录路径获取本模块内部的目标路径
# 用法: get_module_target_path <原始子目录>
# 示例: get_module_target_path system/etc -> $MODPATH/system/etc
# 示例: get_module_target_path system_ext/etc -> $MODPATH/system/system_ext/etc
# 示例: get_module_target_path system/fonts -> $MODPATH/system/fonts
get_module_target_path() {
    local original_subdir="$1"
    # 如果路径以 "system_ext/" 开头，则映射到 $MODPATH/system/system_ext/...
    if echo "$original_subdir" | grep -q "^system_ext/"; then
        echo "$MODPATH/system/$original_subdir"
    else
        # 否则，映射到 $MODPATH/system/... (例如 system/etc, system/fonts)
        echo "$MODPATH/$original_subdir"
    fi
}

# 获取本模块提供的字体二进制文件列表 (仅文件名)
# 结果返回一个空格分隔的字符串，每个文件名都带有一个前导空格，方便后续grep匹配
get_this_module_font_binaries() {
    local module_fonts_dir="$MODPATH/system/fonts"
    local font_list_raw=""

    if [ -d "$module_fonts_dir" ]; then
        # 查找目录下的所有文件，并提取文件名，每个文件名添加一个前导空格
        # 这样最终的字符串会是 " filename1 filename2 filename3 ..."
        # 便后续使用 " filename " 进行精确匹配
        font_list_raw=$(find "$module_fonts_dir" -maxdepth 1 -type f -print | \
                        while read -r FONT_PATH; do
                            echo " $(basename "$FONT_PATH")"
                        done | xargs)
    fi
    echo "$font_list_raw"
}

# 从XML文件中移除本模块旧的字体注入块
remove_old_fonts() {
    local file="$1"
    [ ! -f "$file" ] && return 1
    # 使用sed的'd'命令删除指定模式范围内的行
    sed -i '/<!-- UnicodeFontSetModule Start -->/,/<!-- UnicodeFontSetModule End -->/d' "$file"
}

# 从XML文件中移除指定模块的字体注入块 (如果它们使用了类似的标记)
remove_module_fonts() {
    local file="$1"
    local module_name="$2"
    [ ! -f "$file" ] && return 1
    sed -i "/<!-- ${module_name} fonts start -->/,/<!-- ${module_name} fonts end -->/d" "$file"
}

# 检查XML文件格式是否包含基本的<familyset>标签
check_xml_format() {
    local file="$1"
    if ! grep -q '</familyset>' "$file"; then
        ui_print "  ⚠ 警告：$file 格式可能不正确，跳过处理。"
        return 1
    fi
    return 0
}

# 插入本模块的字体配置到XML文件中
insert_fonts() {
    local file="$1"

    [ ! -f "$file" ] && { ui_print "  ✗ 文件不存在：$file"; return 1; }

    if ! check_xml_format "$file"; then
        return 1
    fi

    # 移除本模块已存在的配置，防止重复注入
    remove_old_fonts "$file"

    # 在</familyset>闭合标签前插入新的配置
    # XML块作为sed的'i' (insert) 命令的字面字符串提供
    sed -i '\|</familyset>|i \
<!-- UnicodeFontSetModule Start -->\
<family lang="und-Zsye">\
<font weight="400" style="normal" postScriptName="UFSEmoji-Ext-Regular">UFSEmoji-Ext.ttf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="Ctrl-Ctrl">CtrlCtrl.otf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="PlangothicP1">PlangothicP1-Regular.otf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="PlangothicP2">PlangothicP2-Regular.otf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="SourceHanSansSC-Regular">SourceHanSansSC-Regular.otf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="Noto-Unicode">NotoUnicode.otf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="NotoSansSuper-Regular">NotoSansSuper.otf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="KreativeSquare">KreativeSquare.ttf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="UFSZeroExt-Regular">UFSZeroExt.otf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="UnicodiaSesh">UnicodiaSesh.ttf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="NewGardiner">NewGardiner.ttf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="Monu-Temp">MonuTemp.ttf</font>\
</family>\
<family>\
<font weight="400" style="normal" postScriptName="LastResort-Regular">LastResort-Regular.ttf</font>\
</family>\
<!-- UnicodeFontSetModule End -->' "$file"

    if [ $? -eq 0 ]; then
        ui_print "  ✓ 已向 $(basename "$file") 注入字体配置"
        return 0
    else
        ui_print "  ✗ 注入失败：$(basename "$file")"
        return 1
    fi
}

acquire_lock() {
    # 使用 mkdir 原子操作作为锁
    local i=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        i=$((i+1))
        sleep 0.1
        # 超过 300 次（约30秒）则退出尝试，避免无限等待
        if [ "$i" -gt 300 ]; then
            return 1
        fi
    done
    return 0
}

release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
