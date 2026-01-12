# ================================
# UnicodeFontSet - Language Loader
# ================================

safe_text() {
    local var_name="$1"
    local value
    eval "value=\$$var_name"
    
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$var_name"
    fi
}

safe_printf() {
    local key="$1"
    shift

    local fmt
    eval "fmt=\$$key"
    [ -z "$fmt" ] && fmt="$key"

    # Prevent %n format specifier for safety
    fmt="${fmt//%n/%%n}"

    local out
    out="$(printf "$fmt" "$@" 2>/dev/null)" || out="$fmt"

    printf '%s' "$out"
}

# 手动指定（最高优先级）
# 在 customize.sh / module.prop 中 export UFS_LANG=en_US
UFS_LANG="${UFS_LANG:-}"

if [ -z "$UFS_LANG" ]; then
    SYS_LANG="$(getprop persist.sys.locale 2>/dev/null)"

    case "$SYS_LANG" in
        zh*|zh-*) UFS_LANG="zh_CN" ;;
        *)        UFS_LANG="en_US" ;;
    esac
fi

LANG_DIR="$MODPATH/lang"

if [ -f "$LANG_DIR/lang_en_US.sh" ]; then
    . "$LANG_DIR/lang_en_US.sh"
else
    echo "Warning: Default language file lang_en_US.sh not found" >> "${LOG_FILE:-/cache/ufs.log}"
fi

case "$UFS_LANG" in
    en_US) 
        # 英文已经加载，无需重复加载
        ;;
    zh_CN) 
        if [ -f "$LANG_DIR/lang_zh_CN.sh" ]; then
            . "$LANG_DIR/lang_zh_CN.sh"
        fi
        ;;
    *) 
        echo "Warning: Unsupported language $UFS_LANG, using English" >> "${LOG_FILE:-/cache/ufs.log}"
        ;;
esac
