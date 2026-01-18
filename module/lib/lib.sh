
[ -n "$_UFS_LIB_LOADED" ] && return
_UFS_LIB_LOADED=1

if [ -z "$MODPATH" ]; then
    SCRIPT_REAL_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"
    MODPATH="${SCRIPT_REAL_PATH%/*}"
fi

LIBDIR="$MODPATH/lib"
LOG_FILE="${MODPATH:-/cache}/ufs.log"

. "$LIBDIR/const.sh"
. "$LIBDIR/lang.sh"
. "$LIBDIR/log.sh"
. "$LIBDIR/lock.sh"
. "$LIBDIR/util.sh"
. "$LIBDIR/xml.sh"
. "$LIBDIR/binary.sh"
. "$LIBDIR/monitor.sh"
. "$LIBDIR/cmap.sh"
