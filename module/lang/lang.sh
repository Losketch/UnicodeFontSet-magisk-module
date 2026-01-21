# ================================
# UnicodeFontSet - Language Loader
# ================================

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
