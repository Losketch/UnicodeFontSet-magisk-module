
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
