# --- 全局配置变量 ---
FONT_XML_FILES="fonts.xml fonts_base.xml fonts_fallback.xml fonts_inter.xml fonts_slate.xml fonts_ule.xml font_fallback.xml fonts_flyme.xml flyme_fallback.xml flyme_font_fallback.xml"
FONT_XML_SUBDIRS="system/etc system/product/etc system/system_ext/etc"
FONT_BINARY_SUBDIRS="system/fonts"
LOCK_DIR="/data/adb/ufs_lock"

# 缓存变量，避免重复计算
THIS_MODULE_BINARY_FONTS_CACHE=""

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

get_module_target_path() {
    local original_subdir="$1"
    if echo "$original_subdir" | grep -q "^system_ext/"; then
        echo "$MODPATH/system/$original_subdir"
    else
        echo "$MODPATH/$original_subdir"
    fi
}

get_this_module_font_binaries() {
    [ -n "$THIS_MODULE_BINARY_FONTS_CACHE" ] && { echo "$THIS_MODULE_BINARY_FONTS_CACHE"; return 0; }

    local module_fonts_dir="$MODPATH/system/fonts"
    local font_list_raw=""

    if [ -d "$module_fonts_dir" ]; then
        font_list_raw=$(find "$module_fonts_dir" -maxdepth 1 -type f -printf " %f" 2>/dev/null)

        if [ -z "$font_list_raw" ]; then
            for f in "$module_fonts_dir"/*; do
                [ -f "$f" ] && font_list_raw="$font_list_raw $(basename "$f")"
            done
        fi
    fi

    THIS_MODULE_BINARY_FONTS_CACHE="$font_list_raw"
    echo "$font_list_raw"
}

remove_old_fonts() {
    local file="$1"
    [ ! -f "$file" ] && return 1
    grep -q 'UnicodeFontSetModule Start' "$file" || return 0
    sed -i '/<!-- UnicodeFontSetModule Start -->/,/<!-- UnicodeFontSetModule End -->/d' "$file"
    return $?
}

remove_module_fonts() {
    local file="$1"
    local module_name="$2"
    [ ! -f "$file" ] && return 1
    sed -i "/<!-- ${module_name} fonts start -->/,/<!-- ${module_name} fonts end -->/d" "$file"
}

check_xml_format() {
    local file="$1"
    if ! grep -q '<familyset' "$file" || ! grep -q '^[[:space:]]*</familyset>' "$file"; then
        ui_print "  ⚠ 警告：$file 格式可能不正确，跳过处理。"
        return 1
    fi
    return 0
}

insert_fonts() {
    local file="$1"
    [ ! -f "$file" ] && { ui_print "  ✗ 文件不存在：$file"; return 1; }

    if ! check_xml_format "$file"; then
        return 1
    fi

    local tmp_file="${file}.tmp.$$"

    cp -f "$file" "$tmp_file" || { ui_print "  ✗ 复制失败：$(basename "$file")"; return 1; }
    remove_old_fonts "$tmp_file" || { ui_print "  ✗ 清理旧配置失败"; return 1; }
 
    if ! sed -i '\|</familyset>|i \
<!-- UnicodeFontSetModule Start -->\
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
<!-- UnicodeFontSetModule End -->' "$tmp_file"
    then
        ui_print "  ✗ 注入失败：$(basename "$file")"
        rm -f "$tmp_file"
        return 1
    fi

    if ! mv -f "$tmp_file" "$file"; then
        rm -f "$tmp_file"
        ui_print "  ✗ 替换失败：$(basename "$file")"
        return 1
    fi
    
    ui_print "  ✓ 已向 $(basename "$file") 注入字体配置"
    return 0
}

write_sha1_atomic() {
    local sha1_value="$1"
    local sha1_file="$2"
    printf '%s' "$sha1_value" > "${sha1_file}.tmp" && mv -f "${sha1_file}.tmp" "$sha1_file"
}

get_safe_sha1_filename() {
    local prefix="$1"
    printf '%s' "$prefix" | tr '/' '_' | tr ' ' '_'
}

monitor_font_modules() {
    local print_func="$1"

    $print_func "开始监控其他字体模块的变化..."

    THIS_MODULE_BINARY_FONTS=$(get_this_module_font_binaries)
    if [ -z "$THIS_MODULE_BINARY_FONTS" ]; then
        $print_func "警告: 本模块的 system/fonts 目录下未发现字体文件，将无法处理其他模块的重名字体。"
    fi

    for MODULE_DIR in "$MODULE_PARENT"/*; do
        [ ! -d "$MODULE_DIR" ] && continue
        MOD_NAME=$(basename "$MODULE_DIR")
        if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
            continue
        fi

        for SUB in $FONT_XML_SUBDIRS; do
            TARGET_DIR="$MODULE_DIR/$SUB"
            for F in $FONT_XML_FILES; do
                TARGET_FILE="$TARGET_DIR/$F"
                BACKUP_FILE="$MODPATH/backup/$MOD_NAME/$SUB/$F"
                SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_$F")"

                if [ -f "$TARGET_FILE" ]; then
                    NEW_SHA1=$(sha1sum "$TARGET_FILE" | cut -d' ' -f1)
                    ACTION_TAKEN=0

                    if [ -f "$SHA1_FILE" ]; then
                        OLD_SHA1=$(cat "$SHA1_FILE")
                        if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
                            $print_func "检测到模块 $MOD_NAME 更新了字体XML文件 $SUB/$F，重新处理。"
                            ACTION_TAKEN=1
                        else
                            $print_func "检测到模块 $MOD_NAME 重新创建了字体XML文件 $SUB/$F。"
                            ACTION_TAKEN=1
                        fi
                    else
                        $print_func "检测到模块 $MOD_NAME 新增了字体XML文件 $SUB/$F。"
                        ACTION_TAKEN=1
                    fi

                    if [ "$ACTION_TAKEN" -eq 1 ]; then
                        mkdir -p "$(dirname "$BACKUP_FILE")"
                        if ! cp -af "$TARGET_FILE" "$BACKUP_FILE"; then
                            $print_func "  ✗ 备份失败：$TARGET_FILE，跳过处理"
                            continue
                        fi
                        write_sha1_atomic "$NEW_SHA1" "$SHA1_FILE"

                        MY_FILE=$(get_module_target_path "$SUB")/$F
                        mkdir -p "$(dirname "$MY_FILE")"
                        cp -af "$TARGET_FILE" "$MY_FILE"
                        insert_fonts "$MY_FILE"

                        rm -f "$TARGET_FILE"
                        if [ -d "$TARGET_DIR" ] && [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
                            rmdir "$TARGET_DIR" 2>/dev/null
                        fi
                        $print_func "已替换 $MOD_NAME 的 $SUB/$F 并重新注入字体。"
                    fi
                elif [ -f "$BACKUP_FILE" ]; then
                    if [ ! -d "$MODULE_DIR" ]; then
                        $print_func "模块 $MOD_NAME 已被删除，清理相关字体XML备份 ($SUB)。"
                        rm -rf "$MODPATH/backup/$MOD_NAME/$SUB"
                        rm -f "$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_$F")"
                    fi
                fi
            done
        done
    done

    for MODULE_DIR in "$MODULE_PARENT"/*; do
        [ ! -d "$MODULE_DIR" ] && continue
        MOD_NAME=$(basename "$MODULE_DIR")
        if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
            continue
        fi

        for SUB in $FONT_BINARY_SUBDIRS; do
            TARGET_DIR="$MODULE_DIR/$SUB"
            [ ! -d "$TARGET_DIR" ] && continue

            find "$TARGET_DIR" -maxdepth 1 -type f -print0 2>/dev/null |
            while IFS= read -r -d '' FONT_FILE; do
                [ -z "$FONT_FILE" ] && continue
                FONT_FILENAME=$(basename "$FONT_FILE")
                [ -z "$THIS_MODULE_BINARY_FONTS" ] && continue

                case " $THIS_MODULE_BINARY_FONTS " in
                    *" $FONT_FILENAME "*)
                        BACKUP_DIR="$MODPATH/backup/$MOD_NAME/$SUB"
                        BACKUP_FILE="$BACKUP_DIR/$FONT_FILENAME"
                        SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_${FONT_FILENAME}")"

                        NEW_SHA1=$(sha1sum "$FONT_FILE" | cut -d' ' -f1)
                        ACTION_TAKEN=0

                        if [ -f "$SHA1_FILE" ]; then
                            OLD_SHA1=$(cat "$SHA1_FILE")
                            if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
                                $print_func "检测到模块 $MOD_NAME 更新了重名字体二进制文件 $SUB/$FONT_FILENAME，重新处理。"
                                ACTION_TAKEN=1
                            else
                                $print_func "检测到模块 $MOD_NAME 重新创建了重名字体二进制文件 $SUB/$FONT_FILENAME。"
                                ACTION_TAKEN=1
                            fi
                        else
                            $print_func "检测到模块 $MOD_NAME 新增了重名字体二进制文件 $SUB/$FONT_FILENAME。"
                            ACTION_TAKEN=1
                        fi

                        if [ "$ACTION_TAKEN" -eq 1 ]; then
                            mkdir -p "$(dirname "$BACKUP_FILE")"
                            if ! cp -af "$FONT_FILE" "$BACKUP_FILE"; then
                                $print_func "  ✗ 备份失败：$FONT_FILE，跳过处理"
                                continue
                            fi
                            write_sha1_atomic "$NEW_SHA1" "$SHA1_FILE"
                            rm -f "$FONT_FILE"
                            $print_func "已删除并备份：$MOD_NAME/$SUB/$FONT_FILENAME"
                            if [ -d "$TARGET_DIR" ] && [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
                                rmdir "$TARGET_DIR" 2>/dev/null
                            fi
                        fi
                        ;;
                esac
            done
        done

        if [ ! -d "$MODULE_DIR" ]; then
            for SUB in $FONT_BINARY_SUBDIRS; do
                if [ -d "$MODPATH/backup/$MOD_NAME/$SUB" ]; then
                    $print_func "模块 $MOD_NAME 已被删除，清理相关字体二进制备份 ($SUB)。"
                    rm -rf "$MODPATH/backup/$MOD_NAME/$SUB"
                    SAFE_PREFIX=$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_")
                    find "$SHA1_DIR" -maxdepth 1 -type f -name "sha1_${SAFE_PREFIX}*" -delete 2>/dev/null
                fi
            done
        fi
    done

    $print_func "字体模块监控完成"
}

process_binary_fonts_install() {
    local FOUND_BINARY_MODULES=0

    THIS_MODULE_BINARY_FONTS=$(get_this_module_font_binaries)
    if [ -z "$THIS_MODULE_BINARY_FONTS" ]; then
        ui_print "警告: 本模块的 system/fonts 目录下未发现字体文件，将无法处理其他模块的重名字体。"
    fi

    ui_print "正在处理其他模块的字体二进制文件..."

    for MODULE_DIR in "$MODULE_PARENT"/*; do
        [ ! -d "$MODULE_DIR" ] && continue
        MOD_NAME=$(basename "$MODULE_DIR")
        if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
            continue
        fi

        MODULE_HAS_FONTS_BINARY=0

        for SUB in $FONT_BINARY_SUBDIRS; do
            TARGET_DIR="$MODULE_DIR/$SUB"
            [ ! -d "$TARGET_DIR" ] && continue

            find "$TARGET_DIR" -maxdepth 1 -type f -print0 2>/dev/null |
            while IFS= read -r -d '' FONT_FILE; do
                [ -z "$FONT_FILE" ] && continue
                FONT_FILENAME=$(basename "$FONT_FILE")
                [ -z "$THIS_MODULE_BINARY_FONTS" ] && continue

                case " $THIS_MODULE_BINARY_FONTS " in
                    *" $FONT_FILENAME "*)
                        if [ "$MODULE_HAS_FONTS_BINARY" -eq 0 ]; then
                            ui_print "  发现模块: $MOD_NAME"
                            MODULE_HAS_FONTS_BINARY=1
                            FOUND_BINARY_MODULES=$((FOUND_BINARY_MODULES + 1))
                        fi

                        BACKUP_DIR="$MODPATH/backup/$MOD_NAME/$SUB"
                        BACKUP_FILE="$BACKUP_DIR/$FONT_FILENAME"
                        SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_${FONT_FILENAME}")"

                        mkdir -p "$BACKUP_DIR"
                        if ! cp -af "$FONT_FILE" "$BACKUP_FILE"; then
                            ui_print "  ✗ 备份失败：$FONT_FILE，跳过处理"
                            continue
                        fi
                        SHA1_VALUE=$(sha1sum "$FONT_FILE" | cut -d' ' -f1)
                        write_sha1_atomic "$SHA1_VALUE" "$SHA1_FILE"

                        rm -f "$FONT_FILE"
                        ui_print "  已删除并备份：$MOD_NAME/$SUB/$FONT_FILENAME"
                        if [ -d "$TARGET_DIR" ] && [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
                            rmdir "$TARGET_DIR" 2>/dev/null
                        fi
                        ;;
                esac
            done
        done
    done

    [ "$FOUND_BINARY_MODULES" -eq 0 ] && ui_print "  未发现其他重名字体二进制模块"
}

acquire_lock() {
    local i=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        i=$((i+1))
        sleep 0.1
        if [ "$i" -gt 300 ]; then
            log_print "⚠ 锁获取超时（30秒），可能存在死锁或长时间运行的实例"
            return 1
        fi
    done
    return 0
}

release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
