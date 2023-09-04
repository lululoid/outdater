#!/system/bin/sh
# shellcheck disable=SC2086,SC3010,SC2034,SC3043,SC2046
BIN=/system/bin

loger() {
	log=$2
	p=$1
	true && {
		if [ -z $log ]; then
			log="$1" && p=i
		fi
		$BIN/log -p "$p" -t outdater "$log"
	}
}

outdater() {
	local EXEC_REMOVE=0
	local DETECTED_PKGS=
	local PKG_LIST_FILE=/data/adb/peulist.txt
	local PS_PKG_NAME=com.android.vending
	local PS_DATA_DIR=/data/data/$PS_PKG_NAME
	local PKG_LIST
	local LF="
"
	local last_modified
	last_modified=$(stat $PS_DATA_DIR/databases/library.db | grep "^Modify*")
	local fg_app

	while true; do
		last_modified0=$(stat $PS_DATA_DIR/databases/library.db | grep "^Modify*")

		[[ "$last_modified" != "$last_modified0" ]] ||
			[ $SKIPUNZIP -eq 1 ] && {
			PKG_LIST=$(cat "$PKG_LIST_FILE")
			# shellcheck disable=SC2162
			while read PKGNAME; do
				[ -n "$PKGNAME" ] && {
					SELECT_PKG=$(./sqlite3 \
						"$PS_DATA_DIR/databases/library.db" \
						"SELECT doc_id FROM ownership WHERE doc_id='$PKGNAME'")

					[ -n "$SELECT_PKG" ] && {
						EXEC_REMOVE=1
						DETECTED_PKGS=$DETECTED_PKGS$LF$SELECT_PKG
					}
				}
			done <<END
$PKG_LIST
END

			[ $EXEC_REMOVE -eq 1 ] && {
				# shellcheck disable=SC2162
				while read PKGNAME; do
					if [ -n "$PKGNAME" ]; then
						./sqlite3 "$PS_DATA_DIR/databases/library.db" "DELETE FROM auto_update WHERE pk='$PKGNAME'"
						./sqlite3 "$PS_DATA_DIR/databases/library.db" "DELETE FROM ownership WHERE doc_id='$PKGNAME'"
						./sqlite3 "$PS_DATA_DIR/databases/localappstate.db" "DELETE FROM appstate WHERE package_name='$PKGNAME'"
						loger "$PKGNAME excluded"
						EXEC_REMOVE=0
					fi
				done <<END
$DETECTED_PKGS
END
				is_opening_ps=$(dumpsys activity |
					$BIN/fgrep -w ResumedActivity |
					sed -n 's/.*u[0-9]\{1,\} \(.*\)\/.*/  \1/p' |
					tail -n 1 | sed 's/ //g' |
					$BIN/fgrep $PS_PKG_NAME)
				am force-stop $PS_PKG_NAME

				[ -n "$is_opening_ps" ] &&
					am start -n com.android.vending/com.google.android.finsky.activities.MainActivity
			}
		}
		last_modified=$(stat $PS_DATA_DIR/databases/library.db | grep "^Modify*")
		last_modified0=$last_modified
		sleep 1
	done &

	loger "service started"
	resetprop outdater.pid $!
}
