#!/system/bin/sh

. "$MODPATH/lib/lib.sh"
ufs_init_context

BUILD_STATE="$(grep '^buildState=' "$MODPATH/module.prop" | cut -d= -f2-)"
[ "$BUILD_STATE" = "built" ] || abort "$TXT_ERROR_SOURCE_PACKAGE"

ui_print "$TXT_INSTALL_HEADER"
ui_print "$TXT_INSTALL_TITLE"
ui_print "$(safe_printf TXT_VERSION "$(grep '^version=' "$MODPATH/module.prop" | cut -d'=' -f2-)")"
ui_print "$TXT_INSTALL_HEADER"

if [ -z "$API" ]; then
    abort "$TXT_ERROR_API_LEVEL"
fi

MIN_API="$(grep '^minApi=' "$MODPATH/module.prop" | cut -d= -f2-)"
[ -n "$MIN_API" ] || abort "$TXT_ERROR_MIN_API"
if [ "$API" -lt "$MIN_API" ]; then
    abort "$(safe_printf TXT_API_TOO_LOW "$MIN_API")"
fi

ufs_import_previous_state || abort "$TXT_STATE_IMPORT_FAIL"

MIRRORPATH="$(ufs_resolve_mirror_path 2>/dev/null || true)"

ui_print "$TXT_STEP_1"
ui_print "$TXT_INSTALL_SYSTEM_XML"
if [ -n "${UFS_SYSTEM_ROOT:-}" ]; then
    ufs_refresh_stock_xml_from_root "ui_print" "$UFS_SYSTEM_ROOT" || abort "$TXT_STOCK_XML_FAIL"
elif [ -n "$MIRRORPATH" ]; then
    ufs_refresh_stock_xml_from_root "ui_print" "$MIRRORPATH" || abort "$TXT_STOCK_XML_FAIL"
else
    ui_print "$TXT_STOCK_XML_DEFERRED"
fi

ui_print "$TXT_STEP_2"
ui_print "$TXT_INSTALL_XML_SCAN"
if ! ufs_rebase_all_xml "ui_print"; then
    abort "$TXT_XML_REBASE_FAILED"
fi
[ "${UFS_XML_REBASE_ACTIONS:-0}" -eq 0 ] && ui_print "$TXT_XML_NONE"

ui_print "$TXT_STEP_3"
process_binary_fonts_install

ui_print "$TXT_STEP_4"
chmod 755 \
    "$MODPATH/action.sh" \
    "$MODPATH/service.sh" \
    "$MODPATH/post-fs-data.sh" \
    "$MODPATH/late-load.sh" 2>/dev/null || true
chmod 755 "$MODPATH/bin/"* 2>/dev/null || true

ui_print "$TXT_INSTALL_SEPARATOR"
ui_print "$TXT_INSTALL_DONE"
ui_print "$TXT_INSTALL_SEPARATOR"

ask_run_cmap_cleaner

ui_print "$TXT_INSTALL_HEADER"
ui_print "$TXT_INSTALL_COMPLETE"
ui_print "$TXT_REBOOT_REQUIRED"
ui_print "$TXT_INSTALL_HEADER"

rm -f "$MODPATH/LICENSE"* "$MODPATH/LICENSE_"* 2>/dev/null || true
