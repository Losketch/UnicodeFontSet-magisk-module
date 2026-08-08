get_this_module_font_binaries() {
    if [ -n "$THIS_MODULE_BINARY_FONTS_CACHE" ]; then
        printf '%s\n' "$THIS_MODULE_BINARY_FONTS_CACHE"
        return 0
    fi

    local module_fonts_dir="$MODPATH/system/fonts"
    local font_list_raw=""
    local font_file

    if [ -d "$module_fonts_dir" ]; then
        for font_file in "$module_fonts_dir"/*; do
            [ -f "$font_file" ] || continue
            font_list_raw="$font_list_raw $(basename "$font_file")"
        done
    fi

    THIS_MODULE_BINARY_FONTS_CACHE="$font_list_raw"
    printf '%s\n' "$THIS_MODULE_BINARY_FONTS_CACHE"
}

process_binary_font_action() {
    local print_func="$1"
    local mod_name="$2"
    local subdir="$3"
    local font_file="$4"
    local font_filename="$5"
    local backup_file="$6"
    local sha1_file="$7"
    local action_flag_name="$8"
    local new_sha1 old_sha1 target_dir

    new_sha1="$(sha1sum "$font_file" | cut -d' ' -f1)"

    if [ -f "$sha1_file" ]; then
        old_sha1="$(cat "$sha1_file")"
        if [ "$old_sha1" != "$new_sha1" ]; then
            "$print_func" "$(safe_printf TXT_BIN_UPDATE "$mod_name" "$subdir" "$font_filename")"
        else
            "$print_func" "$(safe_printf TXT_BIN_RECREATE "$mod_name" "$subdir" "$font_filename")"
        fi
    else
        "$print_func" "$(safe_printf TXT_BIN_NEW "$mod_name" "$subdir" "$font_filename")"
    fi
    ufs_set_flag "$action_flag_name" 1 || return 1

    mkdir -p "$(dirname "$backup_file")" || return 1
    if ! cp -af "$font_file" "$backup_file"; then
        "$print_func" "$(safe_printf TXT_BIN_BACKUP_FAIL "$font_file")"
        return 1
    fi

    write_sha1_atomic "$new_sha1" "$sha1_file" || return 1

    if ! rm -f "$font_file"; then
        "$print_func" "$(safe_printf TXT_ERROR_PROCESS "$font_file")"
        return 1
    fi

    "$print_func" "$(safe_printf TXT_BIN_BACKUP_OK "$mod_name" "$subdir" "$font_filename")"
    target_dir="$(dirname "$font_file")"
    ufs_remove_empty_dir "$target_dir"
    return 0
}

check_module_has_fonts() {
    if [ -z "$1" ]; then
        ui_print "$TXT_WARN_NO_SELF_FONTS"
        return 1
    fi
    return 0
}

process_single_binary_font() {
    local mod_name="$1"
    local subdir="$2"
    local font_file="$3"
    local font_filename="$4"
    local this_module_binary_fonts="$5"
    local module_has_fonts_name="$6"
    local found_binary_modules_name="$7"
    local module_has_fonts backup_file sha1_file

    case " $this_module_binary_fonts " in
        *" $font_filename "*) ;;
        *) return 0 ;;
    esac

    module_has_fonts="$(ufs_get_flag "$module_has_fonts_name")"
    if [ "$module_has_fonts" -eq 0 ]; then
        ui_print "$(safe_printf TXT_MODULE_FOUND "$mod_name")"
        ufs_set_flag "$module_has_fonts_name" 1
    fi

    backup_file="$MODPATH/backup/$mod_name/$subdir/$font_filename"
    sha1_file="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${mod_name}_${subdir}_${font_filename}")"

    process_binary_font_action \
        "ui_print" "$mod_name" "$subdir" "$font_file" "$font_filename" \
        "$backup_file" "$sha1_file" "$found_binary_modules_name"
}

process_binary_fonts_install() {
    local found_binary_modules=0
    local this_module_binary_fonts module_dir mod_name module_has_fonts
    local subdir target_dir font_file font_filename

    this_module_binary_fonts="$(get_this_module_font_binaries)"
    check_module_has_fonts "$this_module_binary_fonts" || return 0

    ui_print "$TXT_INSTALL_BIN_SCAN"

    for module_dir in "$MODULE_PARENT"/*; do
        [ -d "$module_dir" ] || continue
        mod_name="$(basename "$module_dir")"

        if [ "$mod_name" = "$SELF_MOD_NAME" ] || [ -f "$module_dir/disable" ] || [ -f "$module_dir/remove" ]; then
            continue
        fi

        module_has_fonts=0
        for subdir in $FONT_BINARY_SUBDIRS; do
            target_dir="$module_dir/$subdir"
            [ -d "$target_dir" ] || continue

            for font_file in "$target_dir"/*; do
                [ -f "$font_file" ] || continue
                font_filename="$(basename "$font_file")"
                process_single_binary_font \
                    "$mod_name" "$subdir" "$font_file" "$font_filename" \
                    "$this_module_binary_fonts" module_has_fonts found_binary_modules
            done
        done
    done

    [ "$found_binary_modules" -eq 0 ] && ui_print "$TXT_BIN_NONE"
}
