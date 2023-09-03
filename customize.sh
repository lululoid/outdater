# shellcheck disable=SC2034,SC2086,SC2046
SKIPUNZIP=1
export SKIPUNZIP
CONF=/data/adb/peulist.txt

case $ARCH in
"arm64")
	SQLITE_BIN_DIR="$TMPDIR/arm/arm64-v8a"
	;;
"arm")
	SQLITE_BIN_DIR="$TMPDIR/arm/armeabi-v7a"
	;;
"x64")
	SQLITE_BIN_DIR="$TMPDIR/x86/x86_64"
	;;
"x86")
	SQLITE_BIN_DIR="$TMPDIR/x86/x86"
	;;
*)
	abort "$ARCH is Unsupported Architecture!"
	;;
esac

unzip -o "$ZIPFILE" -d $TMPDIR >&2
cp -raf "$TMPDIR/module.prop" "$TMPDIR/service.sh" $TMPDIR/modules.sh $TMPDIR/system "$MODPATH/" || abort "Failed copy module files."
cp -af "$SQLITE_BIN_DIR/sqlite3" "$MODPATH/" || abort "Failed copy binary for $ARCH."
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/sqlite3 0 0 0755
set_perm $MODPATH/modules.sh 0 0 0755
set_perm $MODPATH/system/bin/outdater 0 0 0755

ui_print "> config path is $CONF"
touch /data/adb/peulist.txt
kill -9 $(resetprop outdater.pid)
resetprop --delete outdater.pid
cd $MODPATH || ui_print "$MODPATH is unavailable"
./system/bin/outdater
