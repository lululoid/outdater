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

chk_lm() {
	local file=$1
	stat -c %y "$file"
}

settings_changed() {
	local last_modified
	local last_modified0
	local PKG_LIST_MODIFIED
	local PKG_LIST_MODIFIED0
	last_modified=$(chk_lm $PS_DATA_DIR/databases/library.db)
	last_modified0=$(chk_lm $PS_DATA_DIR/databases/library.db)

	[[ "$last_modified" != "$last_modified0" ]] ||
		{
			[ $SKIPUNZIP -eq 1 ] || {
				PKG_LIST_MODIFIED=$(chk_lm $PKG_LIST_FILE)
				PKG_LIST_MODIFIED0=$(chk_lm $PKG_LIST_FILE)

				[[ "$PKG_LIST_MODIFIED" != "$PKG_LIST_MODIFIED0" ]]
			}
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
	local is_opening_ps

	while true; do
		settings_changed && {
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
						./sqlite3 "$PS_DATA_DIR/databases/library.db" \
							"DELETE FROM auto_update WHERE pk='$PKGNAME'"
						./sqlite3 "$PS_DATA_DIR/databases/library.db" \
							"DELETE FROM ownership WHERE doc_id='$PKGNAME'"
						./sqlite3 \
							"$PS_DATA_DIR/databases/localappstate.db" \
							"DELETE FROM appstate WHERE package_name='$PKGNAME'"
						loger "$PKGNAME excluded"
						EXEC_REMOVE=0
					fi
				done <<END
$DETECTED_PKGS
END
				is_opening_ps=$(
					dumpsys activity activities | ./sed -n \
						'/\bResumedActivity\b/s/.*u0 \(.*\)\/.*/\1/p' |
						$BIN/fgrep $PS_PKG_NAME
				)
				am force-stop $PS_PKG_NAME

				[ -n "$is_opening_ps" ] &&
					am start -n \
						$PS_PKG_NAME/com.google.android.finsky.activities.MainActivity
			}
		}
		sleep 8
	done &

	resetprop outdater.pid $!
	loger "service started"
}
