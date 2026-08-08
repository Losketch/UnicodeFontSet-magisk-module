
_getprop() {
    local value
    value="$(getprop "$1" 2>/dev/null)"
    value="$(echo "$value" | tr -d '\r')"
    echo "$value"
}

_settings_get() {
    local value
    value="$(settings get "$1" "$2" 2>/dev/null)"
    value="$(echo "$value" | tr -d '\r')"
    [ -n "$value" ] && [ "$value" != "null" ] && ! echo "$value" | grep -q "Failed transaction" && echo "$value"
}

get_system_locale() {
    local locale=""
    local lang=""
    local country=""
    local region=""

    locale="$(_getprop persist.sys.locale)"

    if [ -z "$locale" ] || [ "$locale" = "null" ]; then
        lang="$(_getprop persist.sys.language)"
        country="$(_getprop persist.sys.country)"
        if [ -n "$lang" ]; then
            if [ -n "$country" ]; then
                locale="${lang}_${country}"
            else
                locale="$lang"
            fi
        fi
    fi

    # settings talks to Android system services, which are not available during pre-mount
    # boot stages. Avoid binder calls there; persisted properties are sufficient.
    if [ -z "$locale" ] || [ "$locale" = "null" ]; then
        if [ "${UFS_EARLY_BOOT:-0}" != "1" ]; then
            locale="$(_settings_get system system_locales)"
        fi
    fi

    if [ -z "$locale" ] || [ "$locale" = "null" ]; then
        if [ "${UFS_EARLY_BOOT:-0}" != "1" ]; then
            locale="$(_settings_get global device_locale)"
        fi
    fi

    if [ -z "$locale" ] || [ "$locale" = "null" ]; then
        locale="zh_CN"
    fi

    locale="${locale%%,*}"
    locale="$(printf '%s' "$locale" | tr '-' '_')"
    echo "$locale"
}

parse_locale() {
    local input="$1"
    local rest token first remainder variants=""

    _LOCALE_LANG=""
    _LOCALE_SCRIPT=""
    _LOCALE_REGION=""
    _LOCALE_VARIANT=""

    [ -n "$input" ] || return 1

    input="$(printf '%s' "$input" | tr '-' '_')"
    _LOCALE_LANG="${input%%_*}"
    _LOCALE_LANG="$(printf '%s' "$_LOCALE_LANG" | tr '[:upper:]' '[:lower:]')"
    [ -n "$_LOCALE_LANG" ] || return 1

    if [ "$input" = "${input#*_}" ]; then
        return 0
    fi
    rest="${input#*_}"

    while [ -n "$rest" ]; do
        token="${rest%%_*}"
        if [ "$rest" = "$token" ]; then
            rest=""
        else
            rest="${rest#*_}"
        fi
        [ -n "$token" ] || continue

        # A one-character alphanumeric singleton starts a BCP 47 extension (for example `u`).
        # The extension payload does not participate in language/script/region selection.
        if [ "${#token}" -eq 1 ]; then
            case "$token" in
                [A-Za-z0-9]) break ;;
            esac
        fi

        if [ -z "$_LOCALE_SCRIPT" ] && [ "${#token}" -eq 4 ]; then
            case "$token" in
                *[!A-Za-z]*) ;;
                *)
                    first="$(printf '%s' "$token" | cut -c1 | tr '[:lower:]' '[:upper:]')"
                    remainder="$(printf '%s' "$token" | cut -c2- | tr '[:upper:]' '[:lower:]')"
                    _LOCALE_SCRIPT="${first}${remainder}"
                    continue
                    ;;
            esac
        fi

        if [ -z "$_LOCALE_REGION" ]; then
            case "$token" in
                [A-Za-z][A-Za-z])
                    _LOCALE_REGION="$(printf '%s' "$token" | tr '[:lower:]' '[:upper:]')"
                    continue
                    ;;
                [0-9][0-9][0-9])
                    _LOCALE_REGION="$token"
                    continue
                    ;;
            esac
        fi

        if [ -z "$variants" ]; then
            variants="$token"
        else
            variants="${variants}_$token"
        fi
    done

    _LOCALE_VARIANT="$variants"
    return 0
}

get_fallback_language() {
    local lang="$1"
    case "$lang" in
        zh)
            echo "zh_CN"
            ;;
        zh_hans|zh_hant)
            echo "zh_CN"
            ;;
        *)
            echo "en_US"
            ;;
    esac
}

load_language_file() {
    local lang_dir="$1"
    local lang_code="$2"
    local lang_base=""
    local script=""
    local region=""
    local variant=""
    local try_path=""

    parse_locale "$lang_code"

    lang_base="$_LOCALE_LANG"
    script="$_LOCALE_SCRIPT"
    region="$_LOCALE_REGION"
    variant="$_LOCALE_VARIANT"

    try_source() {
        [ -f "$1" ] && . "$1" && return 0
        return 1
    }

    if [ -n "$region" ]; then
        if [ -n "$script" ]; then
            try_source "$lang_dir/lang_${lang_base}_${script}_${region}.sh" && return 0
        fi
        try_source "$lang_dir/lang_${lang_base}_${region}.sh" && return 0
    fi

    if [ -n "$script" ]; then
        try_source "$lang_dir/lang_${lang_base}_${script}.sh" && return 0
    fi

    try_source "$lang_dir/lang_${lang_base}.sh" && return 0

    for f in "$lang_dir"/lang_${lang_base}_*.sh; do
        [ -f "$f" ] && try_source "$f" && return 0
    done

    return 1
}

log_locale_info() {
    local log_file="${UFS_LOG_FILE:-${LOG_FILE:-/cache/ufs.log}}"
    local locale="$1"
    local lang="$2"
    local script="$3"
    local region="$4"

    echo "[Language] Detected locale: $locale" >> "$log_file" 2>/dev/null
    [ -n "$lang" ] && echo "[Language] Parsed - Lang: $lang, Script: $script, Region: $region" >> "$log_file" 2>/dev/null
}

init_language() {
    local system_locale=""
    local detected_lang=""
    local fallback_lang=""

    system_locale="$(get_system_locale)"

    if [ -n "$UFS_LANG" ]; then
        detected_lang="$UFS_LANG"
    else
        detected_lang="$system_locale"
    fi

    if [ -z "$detected_lang" ]; then
        detected_lang="zh_CN"
    fi

    if [ -f "$LANG_DIR/lang_en_US.sh" ]; then
        . "$LANG_DIR/lang_en_US.sh"
    fi

    load_language_file "$LANG_DIR" "$detected_lang"
    local load_result=$?

    if [ $load_result -ne 0 ]; then
        parse_locale "$detected_lang"
        fallback_lang="$(get_fallback_language "$_LOCALE_LANG")"
        if [ "$fallback_lang" != "$detected_lang" ]; then
            load_language_file "$LANG_DIR" "$fallback_lang"
            load_result=$?
        fi
    fi

    if [ $load_result -ne 0 ]; then
        if [ -f "$LANG_DIR/lang_zh_CN.sh" ]; then
            . "$LANG_DIR/lang_zh_CN.sh"
        fi
    fi

    log_locale_info "$system_locale" "$_LOCALE_LANG" "$_LOCALE_SCRIPT" "$_LOCALE_REGION"
}

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
    [ -z "$fmt" ] && fmt="<$key>"

    # Prevent %n format specifier for security
    fmt="${fmt//%n/%%n}"

    local out

    case "$fmt" in
        *%[0-9]\$s*|*%[0-9]\$d*|*%[0-9]\$u*|*%[0-9][0-9]\$s*|*%[0-9][0-9]\$d*|*%[0-9][0-9]\$u*)
            out="$(_printf_with_positional "$fmt" "$@")"
            ;;
        *)
            out="$(printf "$fmt" "$@" 2>/dev/null)" || out="$fmt"
            ;;
    esac

    printf '%s' "$out"
}

_escape_value() {
    local value="$1"
    value="${value//$'\n'/ }"    # 换行转为空格
    value="${value//$'\r'/ }"    # 回车转为空格
    value="${value//\\/\\\\}"    # \ 转义
    value="${value//&/\\&}"      # & 转义
    value="${value//|/\\|}"      # | 转义
    printf '%s' "$value"
}

_find_max_positional_index() {
    local fmt="$1"
    local max_idx=0
    local pos

    case "$fmt" in
        *%[0-9]\$s*|*%[0-9]\$d*|*%[0-9]\$u*|*%[0-9][0-9]\$s*|*%[0-9][0-9]\$d*|*%[0-9][0-9]\$u*)
            ;;
        *)
            _MAX_POS_INDEX=0
            return 0
            ;;
    esac

    pos=1
    while [ "$pos" -le 99 ]; do
        case "$fmt" in
            *%"$pos"\$s*|*%"$pos"\$d*|*%"$pos"\$u*)
                max_idx=$pos
                ;;
        esac
        pos=$((pos + 1))
    done

    _MAX_POS_INDEX=$max_idx
}

_replace_positional_params() {
    local fmt="$1"
    local result="$fmt"
    local pos=1

    while [ "$pos" -le 99 ]; do
        case "$result" in
            *%"$pos"\$s*)
                result="${result//%"$pos"\$s/___POS_${pos}___}"
                ;;
            *%"$pos"\$d*)
                result="${result//%"$pos"\$d/___POS_${pos}___}"
                ;;
            *%"$pos"\$u*)
                result="${result//%"$pos"\$u/___POS_${pos}___}"
                ;;
        esac
        pos=$((pos + 1))
    done

    _FMT_WITH_PLACEHOLDERS="$result"
}

_printf_with_positional() {
    local fmt="$1"
    shift

    local result="$fmt"
    local max_index=0
    local i
    local arg
    local value

    _find_max_positional_index "$fmt"
    max_index=$_MAX_POS_INDEX

    if [ "$max_index" -eq 0 ]; then
        printf '%s' "$fmt"
        return $?
    fi

    _replace_positional_params "$fmt"
    result="$_FMT_WITH_PLACEHOLDERS"

    i=1
    while [ "$i" -le "$max_index" ]; do
        eval "arg=\${$i}"
        value="$(_escape_value "${arg:-}")"
        result="${result//___POS_${i}___/$value}"
        i=$((i + 1))
    done

    printf '%s' "$result"
}

if [ -n "$MODPATH" ]; then
    LANG_DIR="$MODPATH/lang"
else
    LANG_DIR="${0%/*}/lang"
fi

if [ ! -d "$LANG_DIR" ]; then
    LANG_DIR="${MODPATH:-}/lang"
    [ ! -d "$LANG_DIR" ] && LANG_DIR="${0%/*}/lang"
fi

init_language
