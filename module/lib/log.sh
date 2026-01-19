
ui_print() {
    if [ -n "$OUTFD" ]; then
        printf 'ui_print %s\n' "$1" >&"$OUTFD"
    else
        printf '%s\n' "$1"
    fi
}

log_print() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    echo "[UnicodeFontSet][$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

safe_ui_print() {
    ui_print "$(safe_text "$1")"
}
