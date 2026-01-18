
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
