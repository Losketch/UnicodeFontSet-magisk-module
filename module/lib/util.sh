get_module_target_path() {
    [ -z "$1" ] && return 1
    local original_subdir="${1#/}"
    case "$original_subdir" in
        system_ext/*) printf '%s\n' "$MODPATH/system/$original_subdir" ;;
        *)            printf '%s\n' "$MODPATH/$original_subdir" ;;
    esac
}

write_sha1_atomic() {
    local sha1_value="$1"
    local sha1_file="$2"

    mkdir -p "$(dirname "$sha1_file")" || return 1

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
    printf '%s' "$prefix" | tr '/ ' '__'
}

ufs_set_flag() {
    local name="$1"
    local value="${2:-1}"

    case "$name" in
        ''|*[!A-Za-z0-9_]*) return 1 ;;
    esac
    eval "$name=\$value"
}

ufs_get_flag() {
    local name="$1"

    case "$name" in
        ''|*[!A-Za-z0-9_]*) return 1 ;;
    esac
    eval "printf '%s\n' \"\${${name}:-0}\""
}

ufs_dir_is_empty() {
    [ -d "$1" ] || return 1
    [ -z "$(ls -A "$1" 2>/dev/null)" ]
}

ufs_remove_empty_dir() {
    local dir="$1"
    ufs_dir_is_empty "$dir" && rmdir "$dir" 2>/dev/null || true
}
