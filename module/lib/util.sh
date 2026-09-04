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

# Return the Android special partition represented by a module-relative XML directory.
# This is used only to protect UFS-owned materialization; sibling modules keep their own mount semantics.
ufs_special_partition_for_module_subdir() {
    local subdir="$1"
    local target rel

    target="$(get_module_target_path "$subdir")" || return 1
    case "$target" in
        "$MODPATH"/*) rel="${target#"$MODPATH"/}" ;;
        *) return 1 ;;
    esac

    case "$rel" in
        system/product|system/product/*)       printf '%s\n' product ;;
        system/system_ext|system/system_ext/*) printf '%s\n' system_ext ;;
        system/vendor|system/vendor/*)         printf '%s\n' vendor ;;
        system/odm|system/odm/*)               printf '%s\n' odm ;;
        system/oem|system/oem/*)               printf '%s\n' oem ;;
        *) return 1 ;;
    esac
}

ufs_partition_topology_path() {
    [ -n "$1" ] || return 1
    printf '%s/stock/.topology/system_%s.type\n' "$MODPATH" "$1"
}

# Capture the pre-mount /system/<partition> entry type alongside the stock XML snapshot. This keeps
# later Action/service reconciliation from making decisions from an already-overlaid /system tree.
ufs_refresh_special_partition_topology_from_root() {
    local root="${1%/}"
    local system_dir subdir partition path type marker tmp seen=""

    if [ -n "$root" ]; then
        system_dir="$root/system"
    else
        system_dir="/system"
    fi

    for subdir in $FONT_XML_SUBDIRS; do
        partition="$(ufs_special_partition_for_module_subdir "$subdir" 2>/dev/null || true)"
        [ -n "$partition" ] || continue
        case " $seen " in *" $partition "*) continue ;; esac
        seen="$seen $partition"

        path="$system_dir/$partition"
        if [ -L "$path" ]; then
            type="symlink"
        elif [ -d "$path" ]; then
            type="directory"
        elif [ -e "$path" ]; then
            type="other"
        else
            type="missing"
        fi

        marker="$(ufs_partition_topology_path "$partition")" || return 1
        mkdir -p "$(dirname "$marker")" || return 1
        tmp="${marker}.tmp.$$"
        printf '%s\n' "$type" > "$tmp" || { rm -f "$tmp"; return 1; }
        mv -f "$tmp" "$marker" || { rm -f "$tmp"; return 1; }
    done
    return 0
}

ufs_special_partition_xml_force_enabled() {
    [ "${UFS_SPECIAL_PARTITION_XML_EFFECTIVE_MODE:-safe}" = "force" ]
}

ufs_root_manager_label() {
    if [ "${APATCH:-false}" = true ]; then
        printf '%s\n' APatch
    elif [ "${KSU:-false}" = true ]; then
        printf '%s\n' KernelSU
    else
        printf '%s\n' Magisk
    fi
}

# Magisk owns special-partition routing in its core, while KernelSU/APatch delegate or implement
# mounting differently. UFS intentionally does not inspect metamodule names or capabilities; on
# KSU/APatch it protects UFS-owned special-partition aliases whenever the stock entry is a symlink.
ufs_should_guard_owned_partition_alias() {
    local subdir="$1"
    local partition marker type system_dir

    UFS_GUARDED_PARTITION=""
    UFS_GUARD_TOPOLOGY=""

    partition="$(ufs_special_partition_for_module_subdir "$subdir" 2>/dev/null || true)"
    [ -n "$partition" ] || return 1

    # force is an explicit user opt-in. It restores standard Magisk-layout materialization without
    # identifying or certifying the active third-party mount implementation.
    ufs_special_partition_xml_force_enabled && return 1

    # Neither variable is set by native Magisk. APatch explicitly exports APATCH=true and KernelSU
    # exports KSU=true in module scripts, so this distinction uses first-party manager APIs only.
    if [ "${APATCH:-false}" != true ] && [ "${KSU:-false}" != true ]; then
        return 1
    fi

    marker="$(ufs_partition_topology_path "$partition")" || return 1
    type=""
    [ -f "$marker" ] && type="$(cat "$marker" 2>/dev/null || true)"

    if [ "$type" = "symlink" ]; then
        UFS_GUARDED_PARTITION="$partition"
        UFS_GUARD_TOPOLOGY="symlink"
        return 0
    fi

    # During a fresh/legacy install there may be no topology snapshot yet. A live symlink is still
    # authoritative enough to protect. Otherwise remain conservative on KSU/APatch until the next
    # pre-mount refresh records the real stock topology.
    if [ -n "${UFS_SYSTEM_ROOT:-}" ]; then
        system_dir="${UFS_SYSTEM_ROOT%/}/system"
    else
        system_dir="/system"
    fi
    if [ -L "$system_dir/$partition" ]; then
        UFS_GUARDED_PARTITION="$partition"
        UFS_GUARD_TOPOLOGY="symlink"
        return 0
    fi

    if [ -z "$type" ]; then
        UFS_GUARDED_PARTITION="$partition"
        UFS_GUARD_TOPOLOGY="unknown"
        return 0
    fi

    return 1
}

# Remove empty UFS-owned directories up to (but not including) stop_dir.
ufs_prune_empty_parents() {
    local dir="${1%/}"
    local stop_dir="${2%/}"
    local parent

    [ -n "$dir" ] && [ -n "$stop_dir" ] || return 0
    case "$dir/" in
        "$stop_dir"/*) ;;
        *) return 0 ;;
    esac

    while [ "$dir" != "$stop_dir" ]; do
        if [ -d "$dir" ]; then
            rmdir "$dir" 2>/dev/null || break
        fi
        parent="${dir%/*}"
        [ -n "$parent" ] && [ "$parent" != "$dir" ] || break
        dir="$parent"
    done
}
