
acquire_lock() {
    local i=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        i=$((i+1))
        sleep 0.1
        if [ "$i" -gt 300 ]; then
            log_print "$TXT_LOCK_TIMEOUT"
            return 1
        fi
    done
    return 0
}

release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
