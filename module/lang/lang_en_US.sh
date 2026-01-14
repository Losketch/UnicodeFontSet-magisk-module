# ================================
# English Language Pack
# ================================

# --- General ---
TXT_SERVICE_START="=== Starting font module monitor task ==="
TXT_START_MONITOR="Starting monitoring of other font modules..."
TXT_MONITOR_DONE="Font module monitoring completed"
TXT_NO_CONFLICT="  No conflicting font modules detected"

TXT_LOCK_BUSY="⚠ Another instance is running, skipping this run"
TXT_SERVICE_BUSY="⚠ Another instance is running, exiting service"

TXT_ERROR_COMMON_MISSING="Error: common_functions.sh not found!"
TXT_API_TOO_LOW="Android version too low, skipping font injection"
TXT_ERROR_API_LEVEL="Error: API level not set."

# --- Font XML ---
TXT_XML_NEW="Detected new font XML from module %s: %s/%s."
TXT_XML_UPDATE="Detected updated font XML from module %s: %s/%s, reprocessing."
TXT_XML_RECREATE="Detected recreated font XML from module %s: %s/%s."

TXT_XML_BACKUP_FAIL="  ✗ Backup failed: %s, skipping"
TXT_XML_COPY_FAIL="  ✗ Copy failed: %s"

TXT_XML_INJECT_OK="  ✓ Injected font configuration into %s"
TXT_XML_REPLACED="Replaced %s %s/%s and re-injected fonts."

TXT_XML_FORMAT_WARN="  ⚠ Warning: %s format may be invalid, skipping."
TXT_XML_NOT_FOUND="  ✗ File not found: %s"
TXT_XML_FRAGMENT_MISSING="  ✗ Font fragment configuration missing"
TXT_XML_NONE="  No other font XML modules found"

# --- Font binaries ---
TXT_WARN_NO_SELF_FONTS="⚠ No font files found in this module's system/fonts, binary conflicts cannot be handled"
TXT_BIN_NEW="Detected new conflicting font binary from module %s: %s/%s."
TXT_BIN_UPDATE="Detected updated conflicting font binary from module %s: %s/%s."
TXT_BIN_RECREATE="Detected recreated conflicting font binary from module %s: %s/%s."

TXT_BIN_BACKUP_OK="Removed and backed up: %s/%s/%s"
TXT_BIN_BACKUP_FAIL="  ✗ Backup failed: %s, skipping"
TXT_BIN_NONE="  No conflicting font binaries found"

# --- Install phase ---
TXT_INSTALL_XML_SCAN="Processing font XML files from other modules..."
TXT_INSTALL_BIN_SCAN="Processing font binary files from other modules..."
TXT_INSTALL_SYSTEM_XML="Scanning system font XML files..."
TXT_INSTALL_DONE="- Installation completed, font conflicts resolved"
TXT_INSTALL_PROCESS="  Processing: %s/%s"
TXT_INSTALL_COPY_FAIL="  ✗ Copy failed: %s"
TXT_SYSTEM_XML_NONE="  No system font XML files found"

# --- Module lifecycle ---
TXT_MODULE_FOUND="  Found module: %s"
TXT_MODULE_REMOVED_XML="Module %s removed, cleaning XML backups (%s)."
TXT_MODULE_REMOVED_BIN="Module %s removed, cleaning binary backups (%s)."

# --- Input detection ---
TXT_KEYCHECK_DETECT="- Using keycheck for volume key detection (%s seconds)"
TXT_GETEVENT_DETECT="- Using getevent for volume key detection (%s seconds)"
TXT_NO_INPUT_METHOD="- No available input method detected"

# --- cmap cleanup ---
TXT_CMAP_TITLE="📌 Optional: cmap table cleanup"
TXT_CMAP_DESC_1="If you encounter:"
TXT_CMAP_DESC_2=" - Kaomoji (like ʕ•ᴥ•ʔ、(╯°□°)、 ๑⃙⃘´༥`๑⃙⃘ 、(ͼ̤͂ ͜ ͽ̤͂)✧) display abnormally"
TXT_CMAP_DESC_3=" - Emoji shows as blank / squares / misaligned (like😀.png 、🤓:nerd face)"
TXT_CMAP_DESC_4="👉 This is usually caused by font cmap conflicts"
TXT_CMAP_DESC_5="⚠ This operation modifies module font files (safe & reversible)"

# --- Magisk ---
TXT_MAGISK_MIRROR_UNAVAIL="⚠ Magisk mirror path unavailable, will use system path directly"
TXT_MAGISK_CMD_UNAVAIL="⚠ Magisk command unavailable, will use system path directly"

TXT_CMAP_CHOICE="Within 15 seconds:"
TXT_CMAP_SKIP_HINT="  [+]Volume Up → Skip"
TXT_CMAP_RUN_HINT="  [-]Volume Down → Run cleanup"

TXT_CMAP_RUN="🚀 User chose to run cmap cleanup"
TXT_CMAP_SKIP="↩ User chose to skip"
TXT_CMAP_TIMEOUT="⏱ Timeout, skipped"
TXT_CMAP_UNSUPPORTED="ℹ Key detection not supported, skipped"

TXT_CMAP_START="🔧 Running font-cmap-cleaner..."
TXT_CMAP_DONE="✓ font-cmap-cleaner completed"
TXT_CMAP_FAIL="⚠ font-cmap-cleaner failed (exit=%s)"
TXT_CMAP_COPY_FAIL="✗ Failed to copy font-cmap-tool"
TXT_CMAP_CANNOT_RUN="⚠ font-cmap-cleaner cannot run on current system"
TXT_CMAP_TOOL_PATH="  %s"

# --- ABI / tool ---
TXT_ABI_PRIMARY="- Primary ABI: %s"
TXT_ABI_LIST="- ABI list: %s"
TXT_ABI_UNSUPPORTED="! Unsupported ABI: %s"
TXT_CMAP_TOOL_MISSING="! font-cmap-cleaner binary not found or not executable"
TXT_CMAP_TOOL_USING="- Using font-cmap-cleaner: %s"

# --- Lock ---
TXT_LOCK_TIMEOUT="⚠ Lock acquisition timeout (30s), possible deadlock"
