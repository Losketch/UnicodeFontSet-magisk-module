# ================================
# UnicodeFontSet - Language Loader
# ================================

# _getprop()
# 安全获取系统属性的值
# 参数:
#   $1 - 属性名
# 返回:
#   属性值或空
_getprop() {
    local value
    value="$(getprop "$1" 2>/dev/null)"
    value="$(echo "$value" | tr -d '\r')"
    echo "$value"
}

# _settings_get()
# 安全获取settings命令的值
# 参数:
#   $1 - namespace
#   $2 - key
# 返回:
#   设置值或空
_settings_get() {
    local value
    value="$(settings get "$1" "$2" 2>/dev/null)"
    value="$(echo "$value" | tr -d '\r')"
    [ -n "$value" ] && [ "$value" != "null" ] && ! echo "$value" | grep -q "Failed transaction" && echo "$value"
}

# get_system_locale()
# 从多个来源获取系统语言设置，按优先级尝试
# 优先级:
#   1. persist.sys.locale (直接)
#   2. persist.sys.language + persist.sys.country
#   3. settings get system system_locales
#   4. settings get global device_locale
#   5. 默认为 zh_CN
# 返回:
#   标准 locale 字符串 (如 zh_CN, en_US, zh_TW)
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

    if [ -z "$locale" ] || [ "$locale" = "null" ]; then
        locale="$(_settings_get system system_locales)"
    fi

    if [ -z "$locale" ] || [ "$locale" = "null" ]; then
        locale="$(_settings_get global device_locale)"
    fi

    if [ -z "$locale" ] || [ "$locale" = "null" ]; then
        locale="zh_CN"
    fi

    locale="${locale%,*}"
    locale="${locale//-/_}"
    echo "$locale"
}

# parse_locale()
# 解析 locale 字符串，提取语言、脚本、地区等组成部分
# 参数:
#   $1 - locale 字符串 (如 zh_CN, zh_Hans_CN, en_US_POSIX)
# 设置全局变量:
#   _LOCALE_LANG - 语言代码 (如 zh, en)
#   _LOCALE_SCRIPT - 脚本代码 (如 Hans, Hant)
#   _LOCALE_REGION - 地区代码 (如 CN, TW, US)
#   _LOCALE_VARIANT - 变体 (如 POSIX)
parse_locale() {
    local input="$1"
    local rest

    _LOCALE_LANG=""
    _LOCALE_SCRIPT=""
    _LOCALE_REGION=""
    _LOCALE_VARIANT=""

    if [ -z "$input" ]; then
        return 1
    fi

    input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"

    _LOCALE_LANG="${input%%[-_]*}"
    rest="${input#${_LOCALE_LANG}}"
    rest="${rest#[-_]}"

    if [ -n "$rest" ] && [ ${#rest} -eq 4 ]; then
        _LOCALE_SCRIPT="$(echo "${rest:0:1}" | tr '[:lower:]' '[:upper:]')${rest:1:3}"
        rest="${rest#????}"
        rest="${rest#[-_]}"
    fi

    if [ -n "$rest" ]; then
        local lower_reg="${rest%%[-_]*}"
        _LOCALE_REGION="$(echo "$lower_reg" | tr '[:lower:]' '[:upper:]')"
        rest="${rest#${lower_reg}}"
        rest="${rest#[-_]}"
    fi

    if [ -n "$rest" ]; then
        _LOCALE_VARIANT="$rest"
    fi

    [ -n "$_LOCALE_LANG" ]
}

# get_fallback_language()
# 根据当前系统语言获取合适的回退语言
# 参数:
#   $1 - 语言代码
# 返回:
#   最佳匹配的语言代码
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

# load_language_file()
# 尝试加载语言文件，支持多级回退
# 参数:
#   $1 - 语言目录
#   $2 - 语言代码 (如 zh_CN, en_US, zh_TW)
# 返回:
#   0 - 成功加载, 1 - 未找到文件
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

# log_locale_info()
# 记录语言检测的详细信息到日志
log_locale_info() {
    local log_file="${UFS_LOG_FILE:-${LOG_FILE:-/cache/ufs.log}}"
    local locale="$1"
    local lang="$2"
    local script="$3"
    local region="$4"

    echo "[Language] Detected locale: $locale" >> "$log_file" 2>/dev/null
    [ -n "$lang" ] && echo "[Language] Parsed - Lang: $lang, Script: $script, Region: $region" >> "$log_file" 2>/dev/null
}

# init_language()
# 初始化语言环境，根据系统设置加载对应语言包
# 优先级:
#   1. UFS_LANG 环境变量 (手动指定，最高优先级)
#   2. 系统语言设置 (自动检测)
#   3. 默认英文 (fallback)
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

# safe_text()
# 获取本地化文本，如果未定义则返回变量名
# 参数:
#   $1 - 变量名
# 返回:
#   变量的值或变量名本身
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

# safe_printf()
# 安全格式化输出，支持位置参数 %N$s / %N$d / %N$u
#
# 支持的格式说明符:
#   %s, %d, %u, %% (字面量百分号)
#   %1$s, %2$d, %3$u 等位置参数
#
# 不支持的格式说明符（会原样输出）:
#   %f, %x, %c, %o, %b, %e, %g 等
#   宽度/精度修饰符，如 %10s, %.5d
#
# 参数:
#   $1 - 格式字符串变量名 或 直接的格式字符串
#   $2... - 格式化参数
#
# 使用示例:
#   safe_printf TXT_HELLO "world"           # TXT_HELLO="%s你好"
#   safe_printf "Hello %1\$s from %2\$s" "A" "B"  # 位置参数
safe_printf() {
    local key="$1"
    shift

    local fmt
    eval "fmt=\$$key"
    [ -z "$fmt" ] && fmt="<$key>"

    # Prevent %n format specifier for security
    fmt="${fmt//%n/%%n}"

    local out

    # Check if format string contains positional parameters (e.g., %1$s, %2$d)
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

# _escape_value()
# 转义参数值中的特殊字符，防止字符串替换时出问题
# 参数:
#   $1 - 要转义的字符串
# 返回:
#   转义后的字符串
_escape_value() {
    local value="$1"
    # 转义顺序重要：先转义换行，再转义其他
    value="${value//$'\n'/ }"    # 换行转为空格
    value="${value//$'\r'/ }"    # 回车转为空格
    value="${value//\\/\\\\}"    # \ 转义
    value="${value//&/\\&}"      # & 转义
    value="${value//|/\\|}"      # | 转义
    printf '%s' "$value"
}

# _find_max_positional_index()
# 从格式字符串中提取最大位置参数索引
# 参数:
#   $1 - 格式字符串
# 返回:
#   最大索引数字（通过返回值传递到全局变量 _MAX_POS_INDEX）
_find_max_positional_index() {
    local fmt="$1"
    local max_idx=0
    local pos

    # 快速检查是否包含位置参数
    case "$fmt" in
        *%[0-9]\$s*|*%[0-9]\$d*|*%[0-9]\$u*|*%[0-9][0-9]\$s*|*%[0-9][0-9]\$d*|*%[0-9][0-9]\$u*)
            ;;
        *)
            _MAX_POS_INDEX=0
            return 0
            ;;
    esac

    # 提取所有位置参数索引，找出最大值
    # 方式：逐个检查可能的索引
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

# _replace_positional_params()
# 将格式字符串中的位置参数替换为占位符
# 参数:
#   $1 - 格式字符串
# 返回:
#   替换后的字符串（通过全局变量 _FMT_WITH_PLACEHOLDERS 返回）
_replace_positional_params() {
    local fmt="$1"
    local result="$fmt"
    local pos=1

    # 逐个替换位置参数为占位符
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

# _printf_with_positional()
# 模拟 printf 的位置参数功能（纯 shell 实现）
#
# 工作原理:
# 1. 找出格式字符串中最大的位置参数索引
#   2. 将所有位置参数替换为临时占位符（___POS_N___）
# 3. 用实际参数值替换占位符
# 4. 输出结果
#
# 限制:
# - 不支持混用 %s 和 %1$s
# - 不支持宽度/精度修饰符（%10s, %.5d）
# - 不支持特殊格式（%f, %x, %c, %o 等）
# - 参数值中的换行会被替换为空格
#
# 参数:
#   $1 - 格式字符串
#   $2... - 格式化参数
# 返回:
#   格式化后的字符串
_printf_with_positional() {
    local fmt="$1"
    shift

    local result="$fmt"
    local max_index=0
    local i
    local arg
    local value

    # 查找最大位置参数索引
    _find_max_positional_index "$fmt"
    max_index=$_MAX_POS_INDEX

    # 如果没有位置参数，直接使用原生 printf
    if [ "$max_index" -eq 0 ]; then
        printf '%s' "$fmt"
        return $?
    fi

    # 将位置参数替换为占位符
    _replace_positional_params "$fmt"
    result="$_FMT_WITH_PLACEHOLDERS"

    # 替换占位符为实际参数值
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
