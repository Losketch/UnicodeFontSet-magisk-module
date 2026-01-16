# --- 全局配置变量 ---
FONT_XML_FILES="fonts.xml fonts_base.xml fonts_fallback.xml fonts_inter.xml fonts_slate.xml fonts_ule.xml font_fallback.xml fonts_flyme.xml flyme_fallback.xml flyme_font_fallback.xml"
FONT_XML_SUBDIRS="system/etc system/product/etc system/system_ext/etc"
FONT_BINARY_SUBDIRS="system/fonts"
LOCK_DIR="/data/adb/ufs_lock"
LOG_FILE="${MODPATH:-/cache}/ufs.log"

MODULE_START_COMMENT="<!-- UnicodeFontSetModule Start -->"
MODULE_END_COMMENT="<!-- UnicodeFontSetModule End -->"
TEMP_DIR="/data/local/tmp"
CMAP_TOOL_PREFIX="font-cmap-tool"


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
    [ -n "$THIS_MODULE_BINARY_FONTS_CACHE" ] && {
        echo "$THIS_MODULE_BINARY_FONTS_CACHE"
        return 0
    }

    local module_fonts_dir="$MODPATH/system/fonts"
    local font_list_raw=""
    local font_files

    if [ -d "$module_fonts_dir" ]; then
        for font_file in "$module_fonts_dir"/*; do
            [ -f "$font_file" ] && {
                font_list_raw="$font_list_raw $(basename "$font_file")"
            }
        done
    fi

    THIS_MODULE_BINARY_FONTS_CACHE="$font_list_raw"
    echo "$THIS_MODULE_BINARY_FONTS_CACHE"
}

remove_old_fonts() {
    local file="$1"
    [ ! -f "$file" ] && return 1
    grep -q "$MODULE_START_COMMENT" "$file" || return 0
    sed -i "/$MODULE_START_COMMENT/,/$MODULE_END_COMMENT/d" "$file"
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

validate_insert_fonts_input() {
    local file="$1"
    local FRAGMENT="$2"

    if [ ! -f "$file" ]; then
        ui_print "$(safe_printf TXT_XML_NOT_FOUND "$file")"
        log_print "$(safe_printf TXT_LOG_ERROR "File not found: $file")"
        return 1
    fi

    if [ ! -f "$FRAGMENT" ]; then
        safe_ui_print TXT_XML_FRAGMENT_MISSING
        log_print "$(safe_printf TXT_LOG_ERROR "Font fragment file not found: $FRAGMENT")"
        return 1
    fi

    check_xml_format "$file" || {
        log_print "$(safe_printf TXT_LOG_ERROR "Invalid XML format: $file")"
        return 1
    }

    return 0
}

prepare_temp_files() {
    local file="$1"
    local tmp_file="$2"
    local block_file="$3"

    if ! cp -f "$file" "$tmp_file"; then
        ui_print "$(safe_printf TXT_ERROR_COPY "$file" "$tmp_file")"
        log_print "$(safe_printf TXT_LOG_ERROR "Failed to copy $file to $tmp_file")"
        return 1
    fi

    return 0
}

create_font_module_block() {
    local FRAGMENT="$1"
    local block_file="$2"

    if ! {
        echo "$MODULE_START_COMMENT"
        cat "$FRAGMENT"
        echo "$MODULE_END_COMMENT"
    } > "$block_file"; then
        ui_print "$(safe_printf TXT_ERROR_WRITE "$block_file")"
        log_print "$(safe_printf TXT_LOG_ERROR "Failed to write to $block_file")"
        return 1
    fi

    return 0
}

insert_module_block() {
    local tmp_file="$1"
    local block_file="$2"

    if ! awk '
        BEGIN {
            while ((getline line < block_file) > 0) {
                block = block line "\n"
            }
            close(block_file)
        }
        /<\/familyset>/ { print block }
        { print }
    ' block_file="$block_file" "$tmp_file" > "${tmp_file}.new"; then
        ui_print "$(safe_printf TXT_ERROR_PROCESS "$tmp_file")"
        log_print "$(safe_printf TXT_LOG_ERROR "Failed to process $tmp_file with awk")"
        return 1
    fi

    if ! mv -f "${tmp_file}.new" "$tmp_file"; then
        ui_print "$(safe_printf TXT_ERROR_MOVE "${tmp_file}.new" "$tmp_file")"
        log_print "$(safe_printf TXT_LOG_ERROR "Failed to move ${tmp_file}.new to $tmp_file")"
        rm -f "${tmp_file}.new"
        return 1
    fi

    return 0
}

finalize_insert_fonts() {
    local file="$1"
    local tmp_file="$2"
    local block_file="$3"

    if ! rm -f "$block_file"; then
        log_print "$(safe_printf TXT_LOG_WARNING "Failed to remove temporary file $block_file")"
    fi

    if ! mv -f "$tmp_file" "$file"; then
        ui_print "$(safe_printf TXT_ERROR_MOVE "$tmp_file" "$file")"
        log_print "$(safe_printf TXT_LOG_ERROR "Failed to move $tmp_file to $file")"
        rm -f "$tmp_file"
        return 1
    fi

    ui_print "$(safe_printf TXT_XML_INJECT_OK "$(basename "$file")")"
    log_print "$(safe_printf TXT_LOG_SUCCESS "Successfully processed font XML: $file")"
    return 0
}

insert_fonts() {
    local file="$1"
    local FRAGMENT="$MODPATH/config/fonts_fragment.xml"

    validate_insert_fonts_input "$file" "$FRAGMENT" || return 1

    local tmp_file="${file}.tmp.$$"
    local block_file="${file}.block.$$"

    prepare_temp_files "$file" "$tmp_file" "$block_file" || {
        return 1
    }

    remove_old_fonts "$tmp_file" || {
        log_print "Warning: Failed to remove old fonts from $tmp_file"
    }

    create_font_module_block "$FRAGMENT" "$block_file" || {
        rm -f "$tmp_file"
        return 1
    }

    insert_module_block "$tmp_file" "$block_file" || {
        rm -f "$tmp_file" "$block_file"
        return 1
    }

    finalize_insert_fonts "$file" "$tmp_file" "$block_file" || {
        return 1
    }

    return 0
}

write_sha1_atomic() {
    local sha1_value="$1"
    local sha1_file="$2"

    if ! printf '%s' "$sha1_value" > "${sha1_file}.tmp"; then
        log_print "Error: Failed to write SHA1 value to ${sha1_file}.tmp"
        return 1
    fi

    if ! mv -f "${sha1_file}.tmp" "$sha1_file"; then
        log_print "Error: Failed to move ${sha1_file}.tmp to $sha1_file"
        rm -f "${sha1_file}.tmp"
        return 1
    fi

    return 0
}

get_safe_sha1_filename() {
    local prefix="$1"
    printf '%s' "$prefix" | tr '/' '_' | tr ' ' '_'
}

process_xml_font_action() {
    local print_func="$1"
    local MOD_NAME="$2"
    local SUB="$3"
    local F="$4"
    local TARGET_FILE="$5"
    local BACKUP_FILE="$6"
    local SHA1_FILE="$7"
    local -n ACTION_FLAG="$8"

    local NEW_SHA1=$(sha1sum "$TARGET_FILE" | cut -d' ' -f1)
    local ACTION_TAKEN=0

    if [ -f "$SHA1_FILE" ]; then
        local OLD_SHA1=$(cat "$SHA1_FILE")
        if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
            $print_func "$(safe_printf TXT_XML_UPDATE "$MOD_NAME" "$SUB" "$F")"
            ACTION_TAKEN=1
            ACTION_FLAG=1
        else
            $print_func "$(safe_printf TXT_XML_RECREATE "$MOD_NAME" "$SUB" "$F")"
            ACTION_TAKEN=1
            ACTION_FLAG=1
        fi
    else
        $print_func "$(safe_printf TXT_XML_NEW "$MOD_NAME" "$SUB" "$F")"
        ACTION_TAKEN=1
        ACTION_FLAG=1
    fi

    if [ "$ACTION_TAKEN" -eq 1 ]; then
        mkdir -p "$(dirname "$BACKUP_FILE")"
        if ! cp -af "$TARGET_FILE" "$BACKUP_FILE"; then
            $print_func "$(safe_printf TXT_XML_BACKUP_FAIL "$TARGET_FILE")"
            return
        fi
        write_sha1_atomic "$NEW_SHA1" "$SHA1_FILE"

        local MY_FILE=$(get_module_target_path "$SUB")/$F
        mkdir -p "$(dirname "$MY_FILE")"
        cp -af "$TARGET_FILE" "$MY_FILE"
        insert_fonts "$MY_FILE"

        rm -f "$TARGET_FILE"
        local TARGET_DIR=$(dirname "$TARGET_FILE")
        if [ -d "$TARGET_DIR" ] && [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
            rmdir "$TARGET_DIR" 2>/dev/null
        fi
        $print_func "$(safe_printf TXT_XML_REPLACED "$MOD_NAME" "$SUB" "$F")"
    fi
}

process_binary_font_action() {
    local print_func="$1"
    local MOD_NAME="$2"
    local SUB="$3"
    local FONT_FILE="$4"
    local FONT_FILENAME="$5"
    local BACKUP_DIR="$6"
    local BACKUP_FILE="$7"
    local SHA1_FILE="$8"
    local -n ACTION_FLAG="$9"

    local NEW_SHA1=$(sha1sum "$FONT_FILE" | cut -d' ' -f1)
    local ACTION_TAKEN=0

    if [ -f "$SHA1_FILE" ]; then
        local OLD_SHA1=$(cat "$SHA1_FILE")
        if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
            $print_func "$(safe_printf TXT_BIN_UPDATE "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
            ACTION_TAKEN=1
            ACTION_FLAG=1
        else
            $print_func "$(safe_printf TXT_BIN_RECREATE "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
            ACTION_TAKEN=1
            ACTION_FLAG=1
        fi
    else
        $print_func "$(safe_printf TXT_BIN_NEW "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
        ACTION_TAKEN=1
        ACTION_FLAG=1
    fi

    if [ "$ACTION_TAKEN" -eq 1 ]; then
        mkdir -p "$(dirname "$BACKUP_FILE")"
        if ! cp -af "$FONT_FILE" "$BACKUP_FILE"; then
            $print_func "$(safe_printf TXT_BIN_BACKUP_FAIL "$FONT_FILE")"
            return
        fi
        write_sha1_atomic "$NEW_SHA1" "$SHA1_FILE"
        rm -f "$FONT_FILE"
        $print_func "$(safe_printf TXT_BIN_BACKUP_OK "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
        local TARGET_DIR=$(dirname "$FONT_FILE")
        if [ -d "$TARGET_DIR" ] && [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
            rmdir "$TARGET_DIR" 2>/dev/null
        fi
    fi
}

monitor_xml_font_modules() {
    local print_func="$1"
    local -n ACTION_FLAG="$2"

    for MODULE_DIR in "$MODULE_PARENT"/*; do
        [ ! -d "$MODULE_DIR" ] && continue
        local MOD_NAME=$(basename "$MODULE_DIR")
        if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
            continue
        fi

        for SUB in $FONT_XML_SUBDIRS; do
            local TARGET_DIR="$MODULE_DIR/$SUB"
            for F in $FONT_XML_FILES; do
                local TARGET_FILE="$TARGET_DIR/$F"
                local BACKUP_FILE="$MODPATH/backup/$MOD_NAME/$SUB/$F"
                local SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_$F")"

                if [ -f "$TARGET_FILE" ]; then
                    process_xml_font_action "$print_func" "$MOD_NAME" "$SUB" "$F" "$TARGET_FILE" "$BACKUP_FILE" "$SHA1_FILE" ACTION_FLAG
                elif [ -f "$BACKUP_FILE" ]; then
                    if [ ! -d "$MODULE_DIR" ]; then
                        $print_func "$(safe_printf TXT_MODULE_REMOVED_XML "$MOD_NAME" "$SUB")"
                        rm -rf "$MODPATH/backup/$MOD_NAME/$SUB"
                        rm -f "$SHA1_FILE"
                    fi
                fi
            done
        done
    done
}

monitor_binary_font_modules() {
    local print_func="$1"
    local -n ACTION_FLAG="$2"
    local THIS_MODULE_BINARY_FONTS="$3"

    for MODULE_DIR in "$MODULE_PARENT"/*; do
        [ ! -d "$MODULE_DIR" ] && continue
        local MOD_NAME=$(basename "$MODULE_DIR")
        if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
            continue
        fi

        for SUB in $FONT_BINARY_SUBDIRS; do
            local TARGET_DIR="$MODULE_DIR/$SUB"
            [ ! -d "$TARGET_DIR" ] && continue

            for FONT_FILE in "$TARGET_DIR"/*; do
                [ ! -f "$FONT_FILE" ] && continue
                local FONT_FILENAME=$(basename "$FONT_FILE")
                [ -z "$THIS_MODULE_BINARY_FONTS" ] && continue

                case " $THIS_MODULE_BINARY_FONTS " in
                    *" $FONT_FILENAME "*)
                        local BACKUP_DIR="$MODPATH/backup/$MOD_NAME/$SUB"
                        local BACKUP_FILE="$BACKUP_DIR/$FONT_FILENAME"
                        local SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_${FONT_FILENAME}")"
                        process_binary_font_action "$print_func" "$MOD_NAME" "$SUB" "$FONT_FILE" "$FONT_FILENAME" "$BACKUP_DIR" "$BACKUP_FILE" "$SHA1_FILE" ACTION_FLAG
                        ;;
                esac
            done
        done
    done
}

handle_removed_binary_modules() {
    local print_func="$1"

    for MODULE_DIR in "$MODULE_PARENT"/*; do
        [ ! -d "$MODULE_DIR" ] && continue
        local MOD_NAME=$(basename "$MODULE_DIR")
        if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
            continue
        fi

        if [ ! -d "$MODULE_DIR" ]; then
            for SUB in $FONT_BINARY_SUBDIRS; do
                if [ -d "$MODPATH/backup/$MOD_NAME/$SUB" ]; then
                    $print_func "$(safe_printf TXT_MODULE_REMOVED_BIN "$MOD_NAME" "$SUB")"
                    rm -rf "$MODPATH/backup/$MOD_NAME/$SUB"
                    local SAFE_PREFIX=$(get_safe_sha1_filename "${MOD_NAME}_${SUB}_")
                    rm -f "$SHA1_DIR/sha1_${SAFE_PREFIX}"* 2>/dev/null
                fi
            done
        fi
    done
}

monitor_font_modules() {
    local print_func="$1"

    local FOUND_XML_ACTIONS=0
    local FOUND_BINARY_ACTIONS=0

    $print_func "$(safe_text TXT_START_MONITOR)"

    local THIS_MODULE_BINARY_FONTS=$(get_this_module_font_binaries)
    if [ -z "$THIS_MODULE_BINARY_FONTS" ]; then
        $print_func "$(safe_text TXT_WARN_NO_SELF_FONTS)"
    fi

    monitor_xml_font_modules "$print_func" FOUND_XML_ACTIONS

    monitor_binary_font_modules "$print_func" FOUND_BINARY_ACTIONS "$THIS_MODULE_BINARY_FONTS"

    handle_removed_binary_modules "$print_func"

    if [ "$FOUND_XML_ACTIONS" -eq 0 ] && [ "$FOUND_BINARY_ACTIONS" -eq 0 ]; then
        $print_func "$(safe_text TXT_NO_CONFLICT)"
    fi

    $print_func "$(safe_text TXT_MONITOR_DONE)"
}

check_module_has_fonts() {
    local THIS_MODULE_BINARY_FONTS="$1"

    if [ -z "$THIS_MODULE_BINARY_FONTS" ]; then
        ui_print "$TXT_WARN_NO_SELF_FONTS"
        return 1
    fi
    return 0
}

process_single_binary_font() {
    local MOD_NAME="$1"
    local sub_dir="$2"
    local font_file="$3"
    local font_filename="$4"
    local THIS_MODULE_BINARY_FONTS="$5"
    local -n MODULE_HAS_FONTS_BINARY="$6"
    local -n FOUND_BINARY_MODULES="$7"

    case " $THIS_MODULE_BINARY_FONTS " in
        *" $font_filename "*)
            if [ "$MODULE_HAS_FONTS_BINARY" -eq 0 ]; then
                ui_print "$(safe_printf TXT_MODULE_FOUND "$MOD_NAME")"
                MODULE_HAS_FONTS_BINARY=1
                FOUND_BINARY_MODULES=$((FOUND_BINARY_MODULES + 1))
            fi

            local BACKUP_DIR="$MODPATH/backup/$MOD_NAME/$sub_dir"
            local BACKUP_FILE="$BACKUP_DIR/$font_filename"
            local SHA1_FILE="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${MOD_NAME}_${sub_dir}_${font_filename}")"

            mkdir -p "$BACKUP_DIR"
            if ! cp -af "$font_file" "$BACKUP_FILE"; then
                ui_print "$(safe_printf TXT_BIN_BACKUP_FAIL "$font_file")"
                return
            fi

            local SHA1_VALUE=$(sha1sum "$font_file" | cut -d' ' -f1)
            write_sha1_atomic "$SHA1_VALUE" "$SHA1_FILE"

            rm -f "$font_file"
            ui_print "$(safe_printf TXT_BIN_BACKUP_OK "$MOD_NAME" "$sub_dir" "$font_filename")"

            local target_dir=$(dirname "$font_file")
            if [ -z "$(ls -A "$target_dir" 2>/dev/null)" ]; then
                rmdir "$target_dir" 2>/dev/null
            fi
            ;;
    esac
}

process_binary_fonts_install() {
    local FOUND_BINARY_MODULES=0
    local THIS_MODULE_BINARY_FONTS=$(get_this_module_font_binaries)

    check_module_has_fonts "$THIS_MODULE_BINARY_FONTS" || return 0

    ui_print "$TXT_INSTALL_BIN_SCAN"

    for MODULE_DIR in "$MODULE_PARENT"/*; do
        [ ! -d "$MODULE_DIR" ] && continue

        local MOD_NAME=$(basename "$MODULE_DIR")

        if [ "$MOD_NAME" = "$SELF_MOD_NAME" ] || [ -f "$MODULE_DIR/disable" ]; then
            continue
        fi

        local MODULE_HAS_FONTS_BINARY=0

        for sub_dir in $FONT_BINARY_SUBDIRS; do
            local target_dir="$MODULE_DIR/$sub_dir"

            [ ! -d "$target_dir" ] && continue

            for font_file in "$target_dir"/*; do
                [ ! -f "$font_file" ] && continue

                local font_filename=$(basename "$font_file")
                process_single_binary_font "$MOD_NAME" "$sub_dir" "$font_file" "$font_filename" "$THIS_MODULE_BINARY_FONTS" MODULE_HAS_FONTS_BINARY FOUND_BINARY_MODULES
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

    TMP_BIN="$TEMP_DIR/$CMAP_TOOL_PREFIX.$$"
    local SYSTEM_FONTS_DIR="/system/fonts"
    local MODULE_FONTS_DIR="$MODPATH/system/fonts"
    local WHITELIST_FILE="$MODPATH/config/whitelist.txt"

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
        --system-fonts "$SYSTEM_FONTS_DIR" \
        --module-fonts "$MODULE_FONTS_DIR" \
        --skip-font-file "$WHITELIST_FILE" \
        --no-color

    local RET=$?

    rm -f "$TMP_BIN"

    if [ "$RET" -ne 0 ]; then
        ui_print "$(safe_printf "$TXT_CMAP_FAIL" "$RET")"
        return "$RET"
    fi

    ui_print "$TXT_CMAP_DONE"
}

detect_keycheck_tool() {
    local KEYCHECK=""

    if [ -x "/keycheck" ]; then
        KEYCHECK="/keycheck"
    elif [ -n "$MAGISKBIN" ] && [ -x "$MAGISKBIN/keycheck" ]; then
        KEYCHECK="$MAGISKBIN/keycheck"
    fi

    echo "$KEYCHECK"
}

wait_with_keycheck() {
    local KEYCHECK="$1"
    local TIMEOUT="$2"

    ui_print "$(safe_printf TXT_KEYCHECK_DETECT "$TIMEOUT")"

    local START_TS=$(date +%s)
    local NOW
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
}

wait_with_getevent() {
    local TIMEOUT="$1"

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
}

wait_volume_key() {
    local TIMEOUT="${1:-15}"

    local KEYCHECK=$(detect_keycheck_tool)

    if [ -n "$KEYCHECK" ]; then
        wait_with_keycheck "$KEYCHECK" "$TIMEOUT"
        return $?
    fi

    if command -v getevent >/dev/null 2>&1; then
        wait_with_getevent "$TIMEOUT"
        return $?
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
