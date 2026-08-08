# Shared discovery configuration. Environment variables prefixed with UFS_ are test/runtime overrides.
# discovery.conf is the single source of truth shared with the Rust cleaner.

DISCOVERY_CONFIG="${UFS_DISCOVERY_CONFIG:-$MODPATH/config/discovery.conf}"
if [ ! -r "$DISCOVERY_CONFIG" ]; then
    printf 'UnicodeFontSet: missing discovery config: %s\n' "$DISCOVERY_CONFIG" >&2
    return 1 2>/dev/null || exit 1
fi
# shellcheck source=/dev/null
. "$DISCOVERY_CONFIG" || {
    printf 'UnicodeFontSet: failed to load discovery config: %s\n' "$DISCOVERY_CONFIG" >&2
    return 1 2>/dev/null || exit 1
}

for _ufs_required_config in \
    FONT_XML_FAMILYSET_FILES FONT_XML_MODULE_SUBDIRS FONT_BINARY_MODULE_SUBDIRS \
    FONT_XML_BASELINE_DIRS SYSTEM_FONT_BASELINE_DIRS SYSTEM_FONT_SEARCH_DIRS \
    UPDATABLE_SYSTEM_FONT_DIR UPDATABLE_CONFIG_XML; do
    eval "_ufs_required_value=\${$_ufs_required_config:-}"
    if [ -z "$_ufs_required_value" ]; then
        printf 'UnicodeFontSet: discovery config key is empty: %s\n' "$_ufs_required_config" >&2
        unset _ufs_required_config _ufs_required_value
        return 1 2>/dev/null || exit 1
    fi
done
unset _ufs_required_config _ufs_required_value

# Backward-compatible internal names. Their values come only from discovery.conf unless a
# deliberate UFS_* test/runtime override is supplied.
FONT_XML_FILES="${UFS_FONT_XML_FILES:-$FONT_XML_FAMILYSET_FILES}"
FONT_XML_SUBDIRS="${UFS_FONT_XML_SUBDIRS:-$FONT_XML_MODULE_SUBDIRS}"
FONT_BINARY_SUBDIRS="${UFS_FONT_BINARY_SUBDIRS:-$FONT_BINARY_MODULE_SUBDIRS}"

LOCK_DIR="${UFS_LOCK_DIR:-/data/adb/ufs_lock}"
MODULE_PARENT="${UFS_MODULE_PARENT:-/data/adb/modules}"

MODULE_START_COMMENT="<!-- UnicodeFontSetModule Start -->"
MODULE_END_COMMENT="<!-- UnicodeFontSetModule End -->"

TEMP_DIR="${UFS_TEMP_DIR:-${TMPDIR:-/data/local/tmp}}"
CMAP_TOOL_PREFIX="font-cmap-tool"

THIS_MODULE_BINARY_FONTS_CACHE=""
