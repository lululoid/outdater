#!/system/bin/sh
# shellcheck disable=SC2086,SC3010,SC2034,SC3043,SC2046
BIN=/system/bin

outdater() {
	local EXEC_REMOVE=0
	local DETECTED_PKGS=
	local PKG_LIST_FILE=/data/adb/peulist.txt
	local PS_PKG_NAME=com.android.vending
	local PS_DATA_DIR=/data/data/$PS_PKG_NAME
	local PKG_LIST
	PKG_LIST=$(cat "$PKG_LIST_FILE")
	local LF="
"
	while true; do
		fg_app=$(dumpsys activity |
			$BIN/fgrep -w ResumedActivity |
			sed -n 's/.*u[0-9]\{1,\} \(.*\)\/.*/  \1/p' |
			tail -n 1 | sed 's/ //g' |
			$BIN/fgrep com.android.vending)

		[ -n "$fg_app" ] && {
			# shellcheck disable=SC2162
			while read PKGNAME; do
				[ -n "$PKGNAME" ] && {
					SELECT_PKG=$(./sqlite3 \
						"$PS_DATA_DIR/databases/library.db" \
						"SELECT doc_id FROM ownership WHERE doc_id='$PKGNAME'")

					[ -n "${SELECT_PKG}" ] && {
						EXEC_REMOVE=1
						DETECTED_PKGS=$DETECTED_PKGS$LF$SELECT_PKG
					}
				}
			done <<END
$PKG_LIST
END

			[ ${EXEC_REMOVE} -eq 1 ] && {
				# shellcheck disable=SC2162
				while read PKGNAME; do
					if [ -n "$PKGNAME" ]; then
						./sqlite3 "$PS_DATA_DIR/databases/auto_update.db" "DELETE FROM auto_update WHERE pk='$PKGNAME'"
						./sqlite3 "$PS_DATA_DIR/databases/library.db" "DELETE FROM ownership WHERE doc_id='$PKGNAME'"
						./sqlite3 "$PS_DATA_DIR/databases/localappstate.db" "DELETE FROM appstate WHERE package_name='$PKGNAME'"
						EXEC_REMOVE=0
					fi
				done <<END
$DETECTED_PKGS
END
				am force-stop $PS_PKG_NAME
			}
		}
		sleep 1
	done &

	resetprop outdater.pid $!
}
