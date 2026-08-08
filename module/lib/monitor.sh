monitor_xml_font_modules() {
    local print_func="$1"
    local action_flag_name="$2"
    local module_dir mod_name subdir target_dir file target_file backup_file sha1_file

    for module_dir in "$MODULE_PARENT"/*; do
        [ -d "$module_dir" ] || continue
        mod_name="$(basename "$module_dir")"
        if [ "$mod_name" = "$SELF_MOD_NAME" ] || [ -f "$module_dir/disable" ] || [ -f "$module_dir/remove" ]; then
            continue
        fi

        for subdir in $FONT_XML_SUBDIRS; do
            target_dir="$module_dir/$subdir"
            for file in $FONT_XML_FILES; do
                target_file="$target_dir/$file"
                [ -f "$target_file" ] || continue

                backup_file="$MODPATH/backup/$mod_name/$subdir/$file"
                sha1_file="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${mod_name}_${subdir}_$file")"
                process_xml_font_action \
                    "$print_func" "$mod_name" "$subdir" "$file" "$target_file" \
                    "$backup_file" "$sha1_file" "$action_flag_name"
            done
        done
    done
}

monitor_binary_font_modules() {
    local print_func="$1"
    local action_flag_name="$2"
    local this_module_binary_fonts="$3"
    local module_dir mod_name subdir target_dir font_file font_filename backup_file sha1_file

    [ -n "$this_module_binary_fonts" ] || return 0

    for module_dir in "$MODULE_PARENT"/*; do
        [ -d "$module_dir" ] || continue
        mod_name="$(basename "$module_dir")"
        if [ "$mod_name" = "$SELF_MOD_NAME" ] || [ -f "$module_dir/disable" ] || [ -f "$module_dir/remove" ]; then
            continue
        fi

        for subdir in $FONT_BINARY_SUBDIRS; do
            target_dir="$module_dir/$subdir"
            [ -d "$target_dir" ] || continue

            for font_file in "$target_dir"/*; do
                [ -f "$font_file" ] || continue
                font_filename="$(basename "$font_file")"
                case " $this_module_binary_fonts " in
                    *" $font_filename "*) ;;
                    *) continue ;;
                esac

                backup_file="$MODPATH/backup/$mod_name/$subdir/$font_filename"
                sha1_file="$SHA1_DIR/sha1_$(get_safe_sha1_filename "${mod_name}_${subdir}_${font_filename}")"
                process_binary_font_action \
                    "$print_func" "$mod_name" "$subdir" "$font_file" "$font_filename" \
                    "$backup_file" "$sha1_file" "$action_flag_name"
            done
        done
    done
}

cleanup_removed_module_backups() {
    local print_func="$1"
    local backup_root="$MODPATH/backup"
    local module_backup mod_name subdir safe_prefix

    [ -d "$backup_root" ] || return 0

    for module_backup in "$backup_root"/*; do
        [ -d "$module_backup" ] || continue
        mod_name="$(basename "$module_backup")"
        [ -d "$MODULE_PARENT/$mod_name" ] && continue

        for subdir in $FONT_XML_SUBDIRS; do
            if [ -d "$module_backup/$subdir" ]; then
                "$print_func" "$(safe_printf TXT_MODULE_REMOVED_XML "$mod_name" "$subdir")"
            fi
        done
        for subdir in $FONT_BINARY_SUBDIRS; do
            if [ -d "$module_backup/$subdir" ]; then
                "$print_func" "$(safe_printf TXT_MODULE_REMOVED_BIN "$mod_name" "$subdir")"
            fi
        done

        rm -rf "$module_backup"
        safe_prefix="$(get_safe_sha1_filename "${mod_name}_")"
        rm -f "$SHA1_DIR/sha1_${safe_prefix}"* 2>/dev/null || true
    done
}

monitor_font_modules() {
    local print_func="$1"
    local found_xml_actions=0
    local found_binary_actions=0
    local this_module_binary_fonts

    "$print_func" "$(safe_text TXT_START_MONITOR)"

    this_module_binary_fonts="$(get_this_module_font_binaries)"
    if [ -z "$this_module_binary_fonts" ]; then
        "$print_func" "$(safe_text TXT_WARN_NO_SELF_FONTS)"
    fi

    monitor_xml_font_modules "$print_func" found_xml_actions
    monitor_binary_font_modules "$print_func" found_binary_actions "$this_module_binary_fonts"
    cleanup_removed_module_backups "$print_func"

    if [ "$found_xml_actions" -eq 0 ] && [ "$found_binary_actions" -eq 0 ]; then
        "$print_func" "$(safe_text TXT_NO_CONFLICT)"
    fi

    "$print_func" "$(safe_text TXT_MONITOR_DONE)"
}
