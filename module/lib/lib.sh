[ -n "${_UFS_LIB_LOADED:-}" ] && return
_UFS_LIB_LOADED=1

if [ -z "${MODPATH:-}" ]; then
    SCRIPT_REAL_PATH="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
    MODPATH="${SCRIPT_REAL_PATH%/*}"
fi

LIBDIR="$MODPATH/lib"
LOG_FILE="${UFS_LOG_FILE:-$MODPATH/ufs.log}"

. "$LIBDIR/const.sh" || { return 1 2>/dev/null || exit 1; }
. "$LIBDIR/lang.sh"
. "$LIBDIR/log.sh"
. "$LIBDIR/lock.sh"
. "$LIBDIR/util.sh"
. "$LIBDIR/env.sh"
. "$LIBDIR/xml.sh"
. "$LIBDIR/reconcile.sh"
. "$LIBDIR/binary.sh"
. "$LIBDIR/monitor.sh"
. "$LIBDIR/cmap.sh"
