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

[ -f "$MODPATH/lang/lang.sh" ] && . "$MODPATH/lang/lang.sh"

FONT_BINARY_SUBDIRS="system/fonts"
LOCK_DIR="/data/adb/ufs_lock"
LOG_FILE="${MODPATH:-/cache}/ufs.log"

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
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    echo "[UnicodeFontSet][$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

safe_ui_print() {
    ui_print "$(safe_text "$1")"
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
        ui_print "$(safe_printf TXT_XML_FORMAT_WARN "$file")"
        return 1
    fi
    return 0
}

insert_fonts() {
    local file="$1"
    local FRAGMENT="$MODPATH/config/fonts_fragment.xml"

    [ ! -f "$file" ] && { ui_print "$(safe_printf TXT_XML_NOT_FOUND "$file")"; return 1; }
    [ ! -f "$FRAGMENT" ] && { safe_ui_print TXT_XML_FRAGMENT_MISSING; return 1; }

    check_xml_format "$file" || return 1

    local tmp_file="${file}.tmp.$$"
    local block_file="${file}.block.$$"

    cp -f "$file" "$tmp_file" || return 1
    remove_old_fonts "$tmp_file" || true

    {
        echo "<!-- UnicodeFontSetModule Start -->"
        cat "$FRAGMENT"
        echo "<!-- UnicodeFontSetModule End -->"
    } > "$block_file"

    awk -v block="$(cat "$block_file")" '
        /<\/familyset>/ { print block }
        { print }
    ' "$tmp_file" > "${tmp_file}.new" || {
        rm -f "$tmp_file" "$block_file"
        return 1
    }

    mv -f "${tmp_file}.new" "$tmp_file"
    rm -f "$block_file"
    mv -f "$tmp_file" "$file"

    ui_print "$(safe_printf TXT_XML_INJECT_OK "$(basename "$file")")"
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

    local FOUND_XML_ACTIONS=0
    local FOUND_BINARY_ACTIONS=0

    $print_func "$(safe_text TXT_START_MONITOR)"

    THIS_MODULE_BINARY_FONTS=$(get_this_module_font_binaries)
    if [ -z "$THIS_MODULE_BINARY_FONTS" ]; then
        $print_func "$(safe_text TXT_WARN_NO_SELF_FONTS)"
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
                            $print_func "$(safe_printf TXT_XML_UPDATE "$MOD_NAME" "$SUB" "$F")"
                            ACTION_TAKEN=1
                            FOUND_XML_ACTIONS=1
                        else
                            $print_func "$(safe_printf TXT_XML_RECREATE "$MOD_NAME" "$SUB" "$F")"
                            ACTION_TAKEN=1
                            FOUND_XML_ACTIONS=1
                        fi
                    else
                        $print_func "$(safe_printf TXT_XML_NEW "$MOD_NAME" "$SUB" "$F")"
                        ACTION_TAKEN=1
                        FOUND_XML_ACTIONS=1
                    fi

                    if [ "$ACTION_TAKEN" -eq 1 ]; then
                        mkdir -p "$(dirname "$BACKUP_FILE")"
                        if ! cp -af "$TARGET_FILE" "$BACKUP_FILE"; then
                            $print_func "$(safe_printf TXT_XML_BACKUP_FAIL "$TARGET_FILE")"
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
                        $print_func "$(safe_printf TXT_XML_REPLACED "$MOD_NAME" "$SUB" "$F")"
                    fi
                elif [ -f "$BACKUP_FILE" ]; then
                    if [ ! -d "$MODULE_DIR" ]; then
                        $print_func "$(safe_printf TXT_MODULE_REMOVED_XML "$MOD_NAME" "$SUB")"
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
                                $print_func "$(safe_printf TXT_BIN_UPDATE "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
                                ACTION_TAKEN=1
                                FOUND_BINARY_ACTIONS=1
                            else
                                $print_func "$(safe_printf TXT_BIN_RECREATE "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
                                ACTION_TAKEN=1
                                FOUND_BINARY_ACTIONS=1
                            fi
                        else
                            $print_func "$(safe_printf TXT_BIN_NEW "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
                            ACTION_TAKEN=1
                            FOUND_BINARY_ACTIONS=1
                        fi

                        if [ "$ACTION_TAKEN" -eq 1 ]; then
                            mkdir -p "$(dirname "$BACKUP_FILE")"
                            if ! cp -af "$FONT_FILE" "$BACKUP_FILE"; then
                                $print_func "$(safe_printf TXT_BIN_BACKUP_FAIL "$FONT_FILE")"
                                continue
                            fi
                            write_sha1_atomic "$NEW_SHA1" "$SHA1_FILE"
                            rm -f "$FONT_FILE"
                            $print_func "$(safe_printf TXT_BIN_BACKUP_OK "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
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
                    $print_func "$(safe_printf TXT_MODULE_REMOVED_BIN "$MOD_NAME" "$SUB")"
                    rm -rf "$MODPATH/backup/$MOD_NAME/$SUB"
                    SAFE_PREFIX=$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_")
                    find "$SHA1_DIR" -maxdepth 1 -type f -name "sha1_${SAFE_PREFIX}*" -delete 2>/dev/null
                fi
            done
        fi
    done

    if [ "$FOUND_XML_ACTIONS" -eq 0 ] && [ "$FOUND_BINARY_ACTIONS" -eq 0 ]; then
        $print_func "$(safe_text TXT_NO_CONFLICT)"
    fi

    $print_func "$(safe_text TXT_MONITOR_DONE)"
}

process_binary_fonts_install() {
    local FOUND_BINARY_MODULES=0

    THIS_MODULE_BINARY_FONTS=$(get_this_module_font_binaries)
    if [ -z "$THIS_MODULE_BINARY_FONTS" ]; then
        ui_print "$TXT_WARN_NO_SELF_FONTS"
    fi

    ui_print "$TXT_INSTALL_BIN_SCAN"

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
                            ui_print "$(safe_printf TXT_MODULE_FOUND "$MOD_NAME")"
                            MODULE_HAS_FONTS_BINARY=1
                            FOUND_BINARY_MODULES=$((FOUND_BINARY_MODULES + 1))
                        fi

                        BACKUP_DIR="$MODPATH/backup/$MOD_NAME/$SUB"
                        BACKUP_FILE="$BACKUP_DIR/$FONT_FILENAME"
                        SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_${FONT_FILENAME}")"

                        mkdir -p "$BACKUP_DIR"
                        if ! cp -af "$FONT_FILE" "$BACKUP_FILE"; then
                            ui_print "$(safe_printf TXT_BIN_BACKUP_FAIL "$FONT_FILE")"
                            continue
                        fi
                        SHA1_VALUE=$(sha1sum "$FONT_FILE" | cut -d' ' -f1)
                        write_sha1_atomic "$SHA1_VALUE" "$SHA1_FILE"

                        rm -f "$FONT_FILE"
                        ui_print "$(safe_printf TXT_BIN_BACKUP_OK "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
                        if [ -d "$TARGET_DIR" ] && [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
                            rmdir "$TARGET_DIR" 2>/dev/null
                        fi
                        ;;
                esac
            done
        done
    done

    [ "$FOUND_BINARY_MODULES" -eq 0 ] && ui_print "$TXT_BIN_NONE"
}

acquire_lock() {
    local i=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        i=$((i+1))
        sleep 0.1
        if [ "$i" -gt 300 ]; then
            log_print "$TXT_LOCK_TIMEOUT"
            return 1
        fi
    done
    return 0
}

release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

select_font_cmap_tool() {
    local ABI ABI_LIST

    ABI="$(getprop ro.product.cpu.abi)"
    ABI_LIST="$(getprop ro.product.cpu.abilist)"

    ui_print "$(safe_printf TXT_ABI_PRIMARY "$ABI")"
    ui_print "$(safe_printf TXT_ABI_LIST "$ABI_LIST")"

    case "$ABI" in
        arm64-v8a)
            FONT_CMAP_TOOL="$MODPATH/bin/font-cmap-tool-arm64-v8a"
            ;;
        armeabi-v7a|armeabi)
            FONT_CMAP_TOOL="$MODPATH/bin/font-cmap-tool-armeabi-v7a"
            ;;
        x86_64)
            FONT_CMAP_TOOL="$MODPATH/bin/font-cmap-tool-x86_64"
            ;;
        x86)
            FONT_CMAP_TOOL="$MODPATH/bin/font-cmap-tool-x86"
            ;;
        *)
            ui_print "$(safe_printf TXT_ABI_UNSUPPORTED "$ABI")"
            return 1
            ;;
    esac

    if [ ! -x "$FONT_CMAP_TOOL" ]; then
        ui_print "$TXT_CMAP_TOOL_MISSING"
        ui_print "$(safe_printf TXT_CMAP_TOOL_PATH "$FONT_CMAP_TOOL")"
        return 1
    fi

    ui_print "$(safe_printf TXT_CMAP_TOOL_USING "$(basename "$FONT_CMAP_TOOL")")"
    return 0
}

run_font_cmap_cleaner() {
    select_font_cmap_tool || return 1

    ui_print "$TXT_CMAP_START"

    TMP_BIN="/data/local/tmp/font-cmap-tool.$$"

    cp -f "$FONT_CMAP_TOOL" "$TMP_BIN" || {
        ui_print "$TXT_CMAP_COPY_FAIL"
        return 1
    }

    chmod 755 "$TMP_BIN"

    "$TMP_BIN" --help >/dev/null 2>&1 || {
        ui_print "$TXT_CMAP_CANNOT_RUN"
        rm -f "$TMP_BIN"
        return 127
    }

    "$TMP_BIN" \
        --system-fonts /system/fonts \
        --module-fonts "$MODPATH/system/fonts" \
        --skip-font-file "$MODPATH/config/whitelist.txt" \
        --no-color

    local RET=$?

    rm -f "$TMP_BIN"

    if [ "$RET" -ne 0 ]; then
        ui_print "$(safe_printf "$TXT_CMAP_FAIL" "$RET")"
        return "$RET"
    fi

    ui_print "$TXT_CMAP_DONE"
}

wait_volume_key() {
    local TIMEOUT="${1:-15}"
    local START_TS NOW KEYCHECK

    if [ -x "/keycheck" ]; then
        KEYCHECK="/keycheck"
    elif [ -n "$MAGISKBIN" ] && [ -x "$MAGISKBIN/keycheck" ]; then
        KEYCHECK="$MAGISKBIN/keycheck"
    else
        KEYCHECK=""
    fi

    if [ -n "$KEYCHECK" ]; then
        ui_print "$(safe_printf TXT_KEYCHECK_DETECT "$TIMEOUT")"

        START_TS=$(date +%s)
        while :; do
            "$KEYCHECK"
            case "$?" in
                42) return 0 ;;
                41) return 1 ;;
            esac

            NOW=$(date +%s)
            [ $((NOW - START_TS)) -ge "$TIMEOUT" ] && return 2
            sleep 1
        done
    fi

    if command -v getevent >/dev/null 2>&1; then
        ui_print "$(safe_printf TXT_GETEVENT_DETECT "$TIMEOUT")"

        local EVENT
        EVENT=$(timeout "$TIMEOUT" getevent -ql 2>/dev/null \
            | grep -m 1 -E "KEY_VOLUMEUP|KEY_VOLUMEDOWN")

        if echo "$EVENT" | grep -q "KEY_VOLUMEDOWN"; then
            return 0
        elif echo "$EVENT" | grep -q "KEY_VOLUMEUP"; then
            return 1
        else
            return 2
        fi
    fi

    ui_print "$TXT_NO_INPUT_METHOD"
    return 3
}

ask_run_cmap_cleaner() {
    ui_print ""
    ui_print "========================================"
    ui_print "$TXT_CMAP_TITLE"
    ui_print ""
    ui_print "$TXT_CMAP_DESC_1"
    ui_print "$TXT_CMAP_DESC_2"
    ui_print "$TXT_CMAP_DESC_3"
    ui_print ""
    ui_print "$TXT_CMAP_DESC_4"
    ui_print "$TXT_CMAP_DESC_5"
    ui_print ""
    ui_print "$TXT_CMAP_CHOICE"
    ui_print "$TXT_CMAP_SKIP_HINT"
    ui_print "$TXT_CMAP_RUN_HINT"
    ui_print "========================================"

    wait_volume_key 15
    case "$?" in
        0)
            ui_print "$TXT_CMAP_RUN"
            run_font_cmap_cleaner
            ;;
        1)
            ui_print "$TXT_CMAP_SKIP"
            ;;
        2)
            ui_print "$TXT_CMAP_TIMEOUT"
            ;;
        *)
            ui_print "$TXT_CMAP_UNSUPPORTED"
            ;;
    esac
}
