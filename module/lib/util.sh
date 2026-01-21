
get_module_target_path() {
    [ -z "$1" ] && return 1
    local original_subdir="${1#/}"
    case "$original_subdir" in
        system_ext/*) echo "$MODPATH/system/$original_subdir" ;;
        *)            echo "$MODPATH/$original_subdir" ;;
    esac
}

write_sha1_atomic() {
    local sha1_value="$1"
    local sha1_file="$2"

    if ! printf '%s' "$sha1_value" > "${sha1_file}.tmp"; then
        log_print "$(safe_printf TXT_LOG_SHA1_WRITE_FAILED "${sha1_file}.tmp")"
        return 1
    fi

    if ! mv -f "${sha1_file}.tmp" "$sha1_file"; then
        log_print "$(safe_printf TXT_LOG_SHA1_MOVE_FAILED "${sha1_file}.tmp" "$sha1_file")"
        rm -f "${sha1_file}.tmp"
        return 1
    fi

    return 0
}

get_safe_sha1_filename() {
    local prefix="$1"
    printf '%s' "$prefix" | tr '/' '_' | tr ' ' '_'
}
