ufs_load_user_config() {
    local raw_mode="${UFS_SPECIAL_PARTITION_XML_MODE:-}"
    local config_mode=""

    UFS_SPECIAL_PARTITION_XML_MODE_INVALID=""

    if [ -z "$raw_mode" ] && [ -r "$USER_CONFIG" ]; then
        config_mode="$(
            sed -n 's/^[[:space:]]*SPECIAL_PARTITION_XML_MODE[[:space:]]*=[[:space:]]*//p' "$USER_CONFIG" 2>/dev/null \
                | tail -n 1 \
                | sed 's/[[:space:]]*#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//'
        )"
        raw_mode="$config_mode"
    fi

    raw_mode="$(printf '%s' "$raw_mode" | tr '[:upper:]' '[:lower:]')"
    case "$raw_mode" in
        ''|safe)
            UFS_SPECIAL_PARTITION_XML_EFFECTIVE_MODE="safe"
            ;;
        force)
            UFS_SPECIAL_PARTITION_XML_EFFECTIVE_MODE="force"
            ;;
        *)
            UFS_SPECIAL_PARTITION_XML_MODE_INVALID="$raw_mode"
            UFS_SPECIAL_PARTITION_XML_EFFECTIVE_MODE="safe"
            ;;
    esac
}

ufs_resolve_api() {
    if [ -n "${API:-}" ]; then
        printf '%s\n' "$API"
        return 0
    fi
    getprop ro.build.version.sdk 2>/dev/null
}

ufs_init_context() {
    API="$(ufs_resolve_api)"
    SELF_MOD_NAME="$(basename "$MODPATH")"
    SHA1_DIR="${UFS_SHA1_DIR:-$MODPATH/sha1}"
    ufs_load_user_config
    mkdir -p "$SHA1_DIR" "$TEMP_DIR"
}

ufs_resolve_mirror_path() {
    local candidate=""

    if [ -n "${MAGISKTMP:-}" ]; then
        candidate="$MAGISKTMP/.magisk/mirror"
        if [ -d "$candidate/system" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi

    if command -v magisk >/dev/null 2>&1; then
        candidate="$(magisk --path 2>/dev/null)/.magisk/mirror"
        if [ -d "$candidate/system" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi

    return 1
}

ufs_manager_arch_to_abi() {
    case "${ARCH:-}" in
        arm64) printf '%s\n' "arm64-v8a" ;;
        arm)   printf '%s\n' "armeabi-v7a" ;;
        x64)   printf '%s\n' "x86_64" ;;
        x86)   printf '%s\n' "x86" ;;
        *)     return 1 ;;
    esac
}
