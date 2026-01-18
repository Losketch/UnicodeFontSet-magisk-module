
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
