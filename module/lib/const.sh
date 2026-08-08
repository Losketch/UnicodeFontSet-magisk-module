# Shared configuration. Environment variables prefixed with UFS_ are test/runtime overrides.

FONT_XML_FILES="${UFS_FONT_XML_FILES:-fonts.xml fonts_base.xml fonts_fallback.xml fonts_inter.xml fonts_slate.xml fonts_ule.xml font_fallback.xml fonts_flyme.xml flyme_fallback.xml flyme_font_fallback.xml}"
FONT_XML_SUBDIRS="${UFS_FONT_XML_SUBDIRS:-system/etc system/product/etc system/system_ext/etc}"
FONT_BINARY_SUBDIRS="${UFS_FONT_BINARY_SUBDIRS:-system/fonts}"

LOCK_DIR="${UFS_LOCK_DIR:-/data/adb/ufs_lock}"
MODULE_PARENT="${UFS_MODULE_PARENT:-/data/adb/modules}"

MODULE_START_COMMENT="<!-- UnicodeFontSetModule Start -->"
MODULE_END_COMMENT="<!-- UnicodeFontSetModule End -->"

TEMP_DIR="${UFS_TEMP_DIR:-${TMPDIR:-/data/local/tmp}}"
CMAP_TOOL_PREFIX="font-cmap-tool"

THIS_MODULE_BINARY_FONTS_CACHE=""
