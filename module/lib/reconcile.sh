# Reconcile Android font XML providers without reproducing the host manager's mount precedence.
#
# Every active sibling XML is backed up and receives the UFS block in-place. If at least one
# active sibling provides a path, UFS deliberately does NOT provide that same path itself; the
# root manager/metamodule therefore keeps its native provider precedence. If no sibling provides
# the path, UFS materializes stock XML + its fragment from the pre-mount stock snapshot.

ufs_module_is_active() {
    local module_dir="$1"
    [ -d "$module_dir" ] || return 1
    [ ! -f "$module_dir/disable" ] || return 1
    [ ! -f "$module_dir/remove" ] || return 1
    [ ! -f "$module_dir/skip_mount" ] || return 1
    return 0
}

ufs_stock_snapshot_path() {
    printf '%s/stock/%s/%s\n' "$MODPATH" "$1" "$2"
}

ufs_sibling_backup_path() {
    printf '%s/backup/%s/%s/%s\n' "$MODPATH" "$1" "$2" "$3"
}

ufs_live_root_path() {
    local root="${1%/}"
    local subdir="$2"
    local file="$3"
    printf '%s/%s/%s\n' "$root" "$subdir" "$file"
}

ufs_file_sha1() {
    [ -f "$1" ] || return 1
    sha1sum "$1" 2>/dev/null | cut -d' ' -f1
}

ufs_copy_if_changed() {
    local src="$1"
    local dst="$2"
    local src_sha dst_sha
    [ -f "$src" ] || return 1
    src_sha="$(ufs_file_sha1 "$src")" || return 1
    dst_sha=""
    [ -f "$dst" ] && dst_sha="$(ufs_file_sha1 "$dst" 2>/dev/null || true)"
    [ "$src_sha" = "$dst_sha" ] && return 2

    mkdir -p "$(dirname "$dst")" || return 1
    cp -af "$src" "${dst}.tmp.$$" || return 1
    mv -f "${dst}.tmp.$$" "$dst" || return 1
    return 0
}

# `root` is a pre-module-mount filesystem root. Missing files are authoritative and remove stale
# snapshots, which is required after OTA when a stock XML disappears or moves.
ufs_refresh_stock_xml_from_root() {
    local print_func="$1"
    local root="$2"
    local subdir file src dst rc

    for subdir in $FONT_XML_SUBDIRS; do
        for file in $FONT_XML_FILES; do
            src="$(ufs_live_root_path "$root" "$subdir" "$file")"
            dst="$(ufs_stock_snapshot_path "$subdir" "$file")"
            if [ -f "$src" ]; then
                ufs_copy_if_changed "$src" "$dst"
                rc=$?
                if [ "$rc" -eq 0 ]; then
                    "$print_func" "$(safe_printf TXT_STOCK_XML_UPDATED "$subdir" "$file")"
                elif [ "$rc" -ne 2 ]; then
                    "$print_func" "$(safe_printf TXT_ERROR_COPY "$src" "$dst")"
                    return 1
                fi
            elif [ -f "$dst" ]; then
                rm -f "$dst" || return 1
                ufs_remove_empty_dir "$(dirname "$dst")"
                "$print_func" "$(safe_printf TXT_STOCK_XML_REMOVED "$subdir" "$file")"
            fi
        done
    done
    return 0
}

# Preserve state across an in-place module upgrade. `state/` from older experimental builds is not
# imported: XML reconciliation is content-derived now and has no shadow state to drift.
ufs_restore_legacy_taken_over_xml() {
    local module_backup mod_name subdir file backup current
    local backup_root="$MODPATH/backup"

    [ -d "$backup_root" ] || return 0
    for module_backup in "$backup_root"/*; do
        [ -d "$module_backup" ] || continue
        mod_name="$(basename "$module_backup")"
        [ -d "$MODULE_PARENT/$mod_name" ] || continue
        [ ! -f "$MODULE_PARENT/$mod_name/remove" ] || continue

        for subdir in $FONT_XML_SUBDIRS; do
            for file in $FONT_XML_FILES; do
                backup="$module_backup/$subdir/$file"
                current="$MODULE_PARENT/$mod_name/$subdir/$file"
                [ -f "$backup" ] || continue
                [ -f "$current" ] && continue
                mkdir -p "$(dirname "$current")" || return 1
                cp -af "$backup" "$current" || return 1
            done
        done
    done
    return 0
}

ufs_import_previous_state() {
    local previous="$MODULE_PARENT/$SELF_MOD_NAME"
    local name imported=0
    [ -d "$previous" ] || return 0
    [ "$(readlink -f "$previous" 2>/dev/null || printf '%s' "$previous")" != \
      "$(readlink -f "$MODPATH" 2>/dev/null || printf '%s' "$MODPATH")" ] || return 0

    for name in backup stock sha1; do
        [ -d "$previous/$name" ] || continue
        mkdir -p "$MODPATH/$name" || return 1
        cp -af "$previous/$name/." "$MODPATH/$name/" || return 1
        imported=1
    done

    # The previous takeover design physically removed sibling XML files. Restore those XMLs once
    # while importing the old state, before the new patch-in-place reconciler takes ownership.
    # Normal reconciliation must never resurrect a provider merely because a stale backup exists.
    [ "$imported" -eq 1 ] && ufs_restore_legacy_taken_over_xml
    return 0
}

ufs_build_managed_xml() {
    local source="$1"
    local output="$2"
    local work="${output}.build.$$"

    mkdir -p "$(dirname "$output")" || return 1
    cp -af "$source" "$work" || return 1
    if ! insert_fonts "$work" >/dev/null; then
        rm -f "$work"
        return 1
    fi
    mv -f "$work" "$output" || { rm -f "$work"; return 1; }
}

# Keep the pristine sibling file in backup. If the currently installed sibling XML already carries
# an older UFS block, strip that block before deciding whether the sibling itself changed.
ufs_refresh_sibling_backup() {
    local current="$1"
    local backup="$2"
    local stripped="${backup}.stripped.$$"
    local current_base_sha backup_sha

    [ -f "$current" ] || return 1
    mkdir -p "$(dirname "$backup")" || return 1

    if grep -q "$MODULE_START_COMMENT" "$current" 2>/dev/null; then
        cp -af "$current" "$stripped" || return 1
        remove_old_fonts "$stripped" || { rm -f "$stripped"; return 1; }
        current_base_sha="$(ufs_file_sha1 "$stripped")" || { rm -f "$stripped"; return 1; }
        backup_sha=""
        [ -f "$backup" ] && backup_sha="$(ufs_file_sha1 "$backup" 2>/dev/null || true)"
        if [ "$current_base_sha" != "$backup_sha" ]; then
            mv -f "$stripped" "$backup" || { rm -f "$stripped"; return 1; }
            return 0
        fi
        rm -f "$stripped"
        return 2
    fi

    ufs_copy_if_changed "$current" "$backup"
}

ufs_patch_sibling_xml() {
    local print_func="$1"
    local mod_name="$2"
    local subdir="$3"
    local file="$4"
    local current="$5"
    local backup expected current_sha expected_sha backup_rc

    backup="$(ufs_sibling_backup_path "$mod_name" "$subdir" "$file")"

    [ -f "$current" ] || return 1

    ufs_refresh_sibling_backup "$current" "$backup"
    backup_rc=$?
    [ "$backup_rc" -eq 1 ] && return 1
    [ "$backup_rc" -eq 0 ] && "$print_func" "$(safe_printf TXT_XML_CAPTURED "$mod_name" "$subdir" "$file")"

    expected="$TEMP_DIR/ufs-managed-${mod_name}-$(get_safe_sha1_filename "${subdir}_${file}").$$"
    mkdir -p "$TEMP_DIR" || return 1
    ufs_build_managed_xml "$backup" "$expected" || { rm -f "$expected"; return 1; }

    current_sha="$(ufs_file_sha1 "$current")" || { rm -f "$expected"; return 1; }
    expected_sha="$(ufs_file_sha1 "$expected")" || { rm -f "$expected"; return 1; }
    if [ "$current_sha" = "$expected_sha" ]; then
        rm -f "$expected"
        return 2
    fi

    cp -af "$expected" "${current}.ufs-new.$$" || { rm -f "$expected"; return 1; }
    mv -f "${current}.ufs-new.$$" "$current" || {
        rm -f "$expected" "${current}.ufs-new.$$"
        return 1
    }
    rm -f "$expected"
    "$print_func" "$(safe_printf TXT_XML_SIBLING_PATCHED "$mod_name" "$subdir" "$file")"
    return 0
}

# Reconcile one logical XML path. All active sibling providers are patched, preserving the host's
# own precedence. UFS only owns the path when there is no active sibling provider.
ufs_rebase_xml_path() {
    local print_func="$1"
    local subdir="$2"
    local file="$3"
    local module_dir mod_name current backup
    local active_count=0 actions=0 rc
    local target stock expected target_sha expected_sha

    # Shell glob order is irrelevant here: every provider is patched and host precedence is kept.
    for module_dir in "$MODULE_PARENT"/*; do
        [ -d "$module_dir" ] || continue
        mod_name="$(basename "$module_dir")"
        [ "$mod_name" = "$SELF_MOD_NAME" ] && continue
        ufs_module_is_active "$module_dir" || continue

        current="$module_dir/$subdir/$file"
        backup="$(ufs_sibling_backup_path "$mod_name" "$subdir" "$file")"

        # In the patch-in-place model, file absence means this module no longer provides the path.
        # Drop an XML-only stale backup instead of resurrecting a provider removed by an update.
        if [ ! -f "$current" ]; then
            if [ -f "$backup" ]; then
                rm -f "$backup" || return 1
                ufs_remove_empty_dir "$(dirname "$backup")"
            fi
            continue
        fi

        active_count=$((active_count + 1))
        ufs_patch_sibling_xml "$print_func" "$mod_name" "$subdir" "$file" "$current"
        rc=$?
        [ "$rc" -eq 1 ] && return 1
        [ "$rc" -eq 0 ] && actions=$((actions + 1))
    done

    target="$(get_module_target_path "$subdir")/$file"
    if [ "$active_count" -gt 0 ]; then
        # Native module precedence must decide which patched sibling wins.
        if [ -f "$target" ]; then
            rm -f "$target" || return 1
            ufs_remove_empty_dir "$(dirname "$target")"
            actions=$((actions + 1))
            "$print_func" "$(safe_printf TXT_XML_NATIVE_PRECEDENCE "$subdir" "$file" "$active_count")"
        fi
        UFS_XML_PATH_ACTIONS="$actions"
        return 0
    fi

    stock="$(ufs_stock_snapshot_path "$subdir" "$file")"
    if [ ! -f "$stock" ]; then
        if [ -f "$target" ]; then
            rm -f "$target" || return 1
            ufs_remove_empty_dir "$(dirname "$target")"
            actions=$((actions + 1))
            "$print_func" "$(safe_printf TXT_XML_PROVIDER_NONE "$subdir" "$file")"
        fi
        UFS_XML_PATH_ACTIONS="$actions"
        return 0
    fi

    expected="$TEMP_DIR/ufs-stock-$(get_safe_sha1_filename "${subdir}_${file}").$$"
    mkdir -p "$TEMP_DIR" || return 1
    ufs_build_managed_xml "$stock" "$expected" || { rm -f "$expected"; return 1; }
    target_sha=""
    [ -f "$target" ] && target_sha="$(ufs_file_sha1 "$target" 2>/dev/null || true)"
    expected_sha="$(ufs_file_sha1 "$expected")" || { rm -f "$expected"; return 1; }

    if [ "$target_sha" != "$expected_sha" ]; then
        mkdir -p "$(dirname "$target")" || { rm -f "$expected"; return 1; }
        cp -af "$expected" "${target}.ufs-new.$$" || { rm -f "$expected"; return 1; }
        mv -f "${target}.ufs-new.$$" "$target" || {
            rm -f "$expected" "${target}.ufs-new.$$"
            return 1
        }
        actions=$((actions + 1))
        "$print_func" "$(safe_printf TXT_XML_STOCK_REBASED "$subdir" "$file")"
    fi
    rm -f "$expected"
    UFS_XML_PATH_ACTIONS="$actions"
    return 0
}

ufs_rebase_all_xml() {
    local print_func="$1"
    local subdir file actions=0

    for subdir in $FONT_XML_SUBDIRS; do
        for file in $FONT_XML_FILES; do
            UFS_XML_PATH_ACTIONS=0
            ufs_rebase_xml_path "$print_func" "$subdir" "$file" || return 1
            actions=$((actions + UFS_XML_PATH_ACTIONS))
        done
    done
    UFS_XML_REBASE_ACTIONS="$actions"
    return 0
}

# Pre-mount reconciliation is the authoritative OTA stock snapshot point.
ufs_early_reconcile() {
    local print_func="${1:-log_print}"
    local root="${UFS_SYSTEM_ROOT:-}"

    ufs_refresh_stock_xml_from_root "$print_func" "$root" || return 1
    ufs_rebase_all_xml "$print_func" || return 1
    cleanup_removed_module_backups "$print_func"
    return 0
}
