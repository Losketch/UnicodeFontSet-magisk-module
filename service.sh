#!/system/bin/sh

MODPATH=${0%/*}
API=$(getprop ro.build.version.sdk)

[ "$API" -lt 26 ] && exit 0

if [ -f "$MODPATH/common_functions.sh" ]; then
    source "$MODPATH/common_functions.sh"
else
    echo "Error: common_functions.sh not found!" >> /cache/ufs.log
    exit 1
fi

MODULE_PARENT="/data/adb/modules"
SELF_MOD_NAME=$(basename "$MODPATH")

SHA1_DIR="$MODPATH/sha1"
mkdir -p "$SHA1_DIR"

run_once() {
    log_print "=== 开始执行字体模块监控任务 ==="
    monitor_font_modules "log_print"
}

if ! acquire_lock; then
    log_print "⚠ 另一实例正在运行，退出本次 service 启动"
    exit 0
fi

trap 'release_lock; exit 0' INT TERM EXIT

run_once
