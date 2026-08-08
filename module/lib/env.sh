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
    mkdir -p "$SHA1_DIR"
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
