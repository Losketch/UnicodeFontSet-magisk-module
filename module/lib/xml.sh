remove_old_fonts() {
    local file="$1"
    [ -f "$file" ] || return 1
    grep -q "^[[:space:]]*$MODULE_START_COMMENT" "$file" || return 0
    sed -i "/^[[:space:]]*$MODULE_START_COMMENT/,/^[[:space:]]*$MODULE_END_COMMENT/d" "$file"
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
    local fragment="$2"

    if [ ! -f "$file" ]; then
        ui_print "$(safe_printf TXT_XML_NOT_FOUND "$file")"
        log_print "$(safe_printf TXT_LOG_FILE_NOT_FOUND "$file")"
        return 1
    fi

    if [ ! -f "$fragment" ]; then
        safe_ui_print TXT_XML_FRAGMENT_MISSING
        log_print "$(safe_printf TXT_LOG_FRAGMENT_NOT_FOUND "$fragment")"
        return 1
    fi

    if ! check_xml_format "$file"; then
        log_print "$(safe_printf TXT_LOG_INVALID_XML_FORMAT "$file")"
        return 1
    fi
}

copy_xml_to_temp() {
    local file="$1"
    local tmp_file="$2"

    if ! cp -f "$file" "$tmp_file"; then
        ui_print "$(safe_printf TXT_ERROR_COPY "$file" "$tmp_file")"
        log_print "$(safe_printf TXT_LOG_COPY_FAILED "$file" "$tmp_file")"
        return 1
    fi
}

create_font_module_block() {
    local fragment="$1"
    local block_file="$2"
    local tmp_file="${block_file}.tmp"

    if ! {
        printf '%s\n' "$MODULE_START_COMMENT"
        cat "$fragment"
        printf '%s\n' "$MODULE_END_COMMENT"
    } > "$tmp_file"; then
        ui_print "$(safe_printf TXT_ERROR_WRITE "$block_file")"
        log_print "$(safe_printf TXT_LOG_WRITE_FAILED "$tmp_file")"
        rm -f "$tmp_file"
        return 1
    fi

    if ! grep -q "^[[:space:]]*$MODULE_START_COMMENT" "$tmp_file" \
       || ! grep -q "^[[:space:]]*$MODULE_END_COMMENT" "$tmp_file"; then
        ui_print "$(safe_printf TXT_ERROR_WRITE "$block_file")"
        log_print "$(safe_printf TXT_LOG_MISSING_COMMENTS "$tmp_file")"
        rm -f "$tmp_file"
        return 1
    fi

    if ! mv -f "$tmp_file" "$block_file"; then
        ui_print "$(safe_printf TXT_ERROR_WRITE "$block_file")"
        log_print "$(safe_printf TXT_LOG_REPLACE_FAILED "$block_file" "$tmp_file")"
        rm -f "$tmp_file"
        return 1
    fi
}

insert_module_block() {
    local tmp_file="$1"
    local block_file="$2"

    if ! awk -v block_file="$block_file" '
        BEGIN {
            while ((getline line < block_file) > 0) {
                block = block line "\n"
            }
            close(block_file)
        }
        /^[[:space:]]*<\/familyset>/ { print block }
        { print }
    ' "$tmp_file" > "${tmp_file}.new"; then
        ui_print "$(safe_printf TXT_ERROR_PROCESS "$tmp_file")"
        log_print "$(safe_printf TXT_LOG_PROCESS_FAILED "$tmp_file")"
        return 1
    fi

    if ! mv -f "${tmp_file}.new" "$tmp_file"; then
        ui_print "$(safe_printf TXT_ERROR_MOVE "${tmp_file}.new" "$tmp_file")"
        log_print "$(safe_printf TXT_LOG_MOVE_FAILED "${tmp_file}.new" "$tmp_file")"
        rm -f "${tmp_file}.new"
        return 1
    fi
}

finalize_insert_fonts() {
    local file="$1"
    local tmp_file="$2"
    local block_file="$3"

    rm -f "$block_file" || log_print "$(safe_printf TXT_LOG_REMOVE_FAILED "$block_file")"

    if ! mv -f "$tmp_file" "$file"; then
        ui_print "$(safe_printf TXT_ERROR_MOVE "$tmp_file" "$file")"
        log_print "$(safe_printf TXT_LOG_MOVE_FAILED "$tmp_file" "$file")"
        rm -f "$tmp_file"
        return 1
    fi

    ui_print "$(safe_printf TXT_XML_INJECT_OK "$(basename "$file")")"
    log_print "$(safe_printf TXT_LOG_XML_PROCESSED "$file")"
}

insert_fonts() {
    local file="$1"
    local fragment="$MODPATH/config/fonts_fragment.xml"
    local tmp_file="${file}.tmp.$$"
    local block_file="${file}.block.$$"

    validate_insert_fonts_input "$file" "$fragment" || return 1
    copy_xml_to_temp "$file" "$tmp_file" || return 1

    remove_old_fonts "$tmp_file" || log_print "$(safe_printf TXT_LOG_OLD_FONTS_REMOVE_FAILED "$tmp_file")"

    if ! create_font_module_block "$fragment" "$block_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    if ! insert_module_block "$tmp_file" "$block_file"; then
        rm -f "$tmp_file" "$block_file"
        return 1
    fi

    finalize_insert_fonts "$file" "$tmp_file" "$block_file"
}

process_xml_font_action() {
    local print_func="$1"
    local mod_name="$2"
    local subdir="$3"
    local file_name="$4"
    local target_file="$5"
    local backup_file="$6"
    local sha1_file="$7"
    local action_flag_name="$8"
    local new_sha1 old_sha1 module_file target_dir

    new_sha1="$(sha1sum "$target_file" | cut -d' ' -f1)"

    if [ -f "$sha1_file" ]; then
        old_sha1="$(cat "$sha1_file")"
        if [ "$old_sha1" != "$new_sha1" ]; then
            "$print_func" "$(safe_printf TXT_XML_UPDATE "$mod_name" "$subdir" "$file_name")"
        else
            "$print_func" "$(safe_printf TXT_XML_RECREATE "$mod_name" "$subdir" "$file_name")"
        fi
    else
        "$print_func" "$(safe_printf TXT_XML_NEW "$mod_name" "$subdir" "$file_name")"
    fi
    ufs_set_flag "$action_flag_name" 1 || return 1

    mkdir -p "$(dirname "$backup_file")" || return 1
    if ! cp -af "$target_file" "$backup_file"; then
        "$print_func" "$(safe_printf TXT_XML_BACKUP_FAIL "$target_file")"
        return 1
    fi
    write_sha1_atomic "$new_sha1" "$sha1_file" || return 1

    module_file="$(get_module_target_path "$subdir")/$file_name"
    mkdir -p "$(dirname "$module_file")" || return 1
    if ! cp -af "$target_file" "$module_file"; then
        "$print_func" "$(safe_printf TXT_ERROR_COPY "$target_file" "$module_file")"
        return 1
    fi
    if ! insert_fonts "$module_file"; then
        rm -f "$module_file"
        return 1
    fi

    if ! rm -f "$target_file"; then
        "$print_func" "$(safe_printf TXT_ERROR_PROCESS "$target_file")"
        return 1
    fi
    target_dir="$(dirname "$target_file")"
    ufs_remove_empty_dir "$target_dir"

    "$print_func" "$(safe_printf TXT_XML_REPLACED "$mod_name" "$subdir" "$file_name")"
}
