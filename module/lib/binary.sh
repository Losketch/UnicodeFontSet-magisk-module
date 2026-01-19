
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

process_binary_font_action() {
    local print_func="$1"
    local MOD_NAME="$2"
    local SUB="$3"
    local FONT_FILE="$4"
    local FONT_FILENAME="$5"
    local BACKUP_DIR="$6"
    local BACKUP_FILE="$7"
    local SHA1_FILE="$8"
    local ACTION_FLAG_NAME="$9"

    local NEW_SHA1=$(sha1sum "$FONT_FILE" | cut -d' ' -f1)
    local ACTION_TAKEN=0

    if [ -f "$SHA1_FILE" ]; then
        local OLD_SHA1=$(cat "$SHA1_FILE")
        if [ "$OLD_SHA1" != "$NEW_SHA1" ]; then
            $print_func "$(safe_printf TXT_BIN_UPDATE "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
            ACTION_TAKEN=1
            eval "$ACTION_FLAG_NAME=1"
        else
            $print_func "$(safe_printf TXT_BIN_RECREATE "$MOD_NAME" "$SUB" "$FONT_FILENAME")"
            ACTION_TAKEN=1
            eval "$ACTION_FLAG_NAME=1"
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
    local MODULE_HAS_FONTS_BINARY_NAME="$6"
    local FOUND_BINARY_MODULES_NAME="$7"

    case " $THIS_MODULE_BINARY_FONTS " in
        *" $font_filename "*)
            local MODULE_HAS_FONTS_BINARY
            eval "MODULE_HAS_FONTS_BINARY=\$${MODULE_HAS_FONTS_BINARY_NAME}"
            if [ "$MODULE_HAS_FONTS_BINARY" -eq 0 ]; then
                ui_print "$(safe_printf TXT_MODULE_FOUND "$MOD_NAME")"
                eval "$MODULE_HAS_FONTS_BINARY_NAME=1"
                eval "$FOUND_BINARY_MODULES_NAME=$((\$${FOUND_BINARY_MODULES_NAME} + 1))"
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
