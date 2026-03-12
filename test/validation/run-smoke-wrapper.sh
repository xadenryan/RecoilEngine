#!/bin/sh

set -eu

if [ $# -lt 1 ]; then
	echo "Usage: $0 command [args...]"
	exit 1
fi

capture_tracked_pids() {
	capture_tracked_processes | awk '{ print $1 }'
}

capture_tracked_processes() {
	ps -axo pid=,command= | awk '
		function basename(path, count, parts) {
			count = split(path, parts, "/")
			return parts[count]
		}

		{
			pid = $1
			command = $2
			name = basename(command)

			if (name == "spring" || name == "spring-dedicated" || name == "spring-headless" || name == "ReportCrash" || name == "CrashReporterSupportHelper") {
				print pid "\t" name
			}
		}
	'
}

is_baseline_pid() {
	case " $BASELINE_PIDS " in
		*" $1 "*) return 0 ;;
	esac

	return 1
}

terminate_pid() {
	pid="$1"

	if ! kill -0 "$pid" 2>/dev/null; then
		return 0
	fi

	kill "$pid" 2>/dev/null || true
	sleep 1

	if kill -0 "$pid" 2>/dev/null; then
		kill -9 "$pid" 2>/dev/null || true
	fi
}

kill_new_crash_helpers() {
	capture_tracked_processes | while IFS='	' read -r pid name; do
		if is_baseline_pid "$pid"; then
			continue
		fi

		case "$name" in
			ReportCrash|CrashReporterSupportHelper)
				terminate_pid "$pid"
			;;
		esac
	done
}

monitor_tracked_processes() {
	while [ -n "$CMD_PID" ] && kill -0 "$CMD_PID" 2>/dev/null; do
		kill_new_crash_helpers
		sleep 1
	done
}

cleanup() {
	exit_code=$?

	if [ "$CLEANED_UP" -eq 1 ]; then
		exit "$exit_code"
	fi

	CLEANED_UP=1

	if [ -n "$MONITOR_PID" ] && kill -0 "$MONITOR_PID" 2>/dev/null; then
		kill "$MONITOR_PID" 2>/dev/null || true
		wait "$MONITOR_PID" 2>/dev/null || true
	fi

	if [ -n "$CMD_PID" ] && kill -0 "$CMD_PID" 2>/dev/null; then
		terminate_pid "$CMD_PID"
		wait "$CMD_PID" 2>/dev/null || true
	fi

	for pid in $(capture_tracked_pids); do
		if is_baseline_pid "$pid"; then
			continue
		fi

		terminate_pid "$pid"
	done

	exit "$exit_code"
}

BASELINE_PIDS="$(capture_tracked_pids | tr '\n' ' ')"
CMD_PID=""
MONITOR_PID=""
CLEANED_UP=0

trap cleanup EXIT HUP INT TERM

RECOIL_SMOKE_WRAPPED=1 "$@" &
CMD_PID="$!"

monitor_tracked_processes &
MONITOR_PID="$!"

wait "$CMD_PID"
