#!/system/bin/sh
# shellcheck disable=SC2086,SC3010
MODDIR=${0%/*}
# shellcheck disable=SC1091
. $MODDIR/outdater.sh

cd $MODDIR || log -t Magisk "$MODDIR doesn't exist"
outdater
