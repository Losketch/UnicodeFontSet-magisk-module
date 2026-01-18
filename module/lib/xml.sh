
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
