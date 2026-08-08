# Magisk/KernelSU/APatch installers provide ui_print/abort while customize.sh is sourced.
# Preserve those host callbacks and only provide runtime fallbacks when they are absent.
if ! command -v ui_print >/dev/null 2>&1; then
    ui_print() {
        printf '%s\n' "$1"
    }
fi

log_print() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    printf '[UnicodeFontSet][%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

safe_ui_print() {
    ui_print "$(safe_text "$1")"
}

if ! command -v abort >/dev/null 2>&1; then
    abort() {
        ui_print "$1"
        rm -f "$TEMP_DIR/$CMAP_TOOL_PREFIX".* 2>/dev/null
        release_lock 2>/dev/null || true
        exit 1
    }
fi
