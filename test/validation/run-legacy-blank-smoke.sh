#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ $# -lt 1 ]; then
	echo "Usage: $0 /path/to/spring [timeout-seconds]"
	exit 1
fi

SPRING_LEGACY="$1"
TIMEOUT_SECS="${2:-25}"
STABLE_SECS="${RECOIL_LEGACY_SMOKE_STABLE_SECS:-3}"
WINDOW_HIDDEN="${RECOIL_LEGACY_SMOKE_HIDDEN:-}"

if [ ! -x "$SPRING_LEGACY" ]; then
	echo "Parameter 1 $SPRING_LEGACY isn't executable!"
	exit 1
fi

if [ "$(uname -s)" = "Darwin" ] && [ "${RECOIL_MACOS_SKIP_GUI_SESSION_CHECK:-0}" -ne 1 ]; then
	GUI_SESSION_OK=0

	if "$SCRIPT_DIR/check-macos-gui-session.sh" --count-only >/dev/null 2>&1; then
		GUI_SESSION_OK=1
	fi

	if [ "${RECOIL_LEGACY_SMOKE_GUI_BOOTSTRAP:-0}" -ne 1 ]; then
		GUI_UID=$(id -u)
		CONSOLE_USER=$(stat -f %Su /dev/console 2>/dev/null || true)

		if launchctl print "gui/$GUI_UID" >/dev/null 2>&1 && {
			[ "${RECOIL_LEGACY_SMOKE_FORCE_ASUSER:-0}" -eq 1 ] \
			|| [ "$CONSOLE_USER" != "$(id -un)" ] \
			|| [ "$GUI_SESSION_OK" -ne 1 ];
		}; then
			exec launchctl asuser "$GUI_UID" /usr/bin/env \
				PATH="$PATH" \
				HOME="${HOME:-}" \
				TMPDIR="${TMPDIR:-}" \
				RECOIL_MACOS_SKIP_GUI_SESSION_CHECK=1 \
				RECOIL_LEGACY_SMOKE_GUI_BOOTSTRAP=1 \
				RECOIL_SMOKE_WRAPPED=1 \
				/bin/sh "$0" "$@"
		fi
	fi

	if [ "$GUI_SESSION_OK" -ne 1 ]; then
		echo "Legacy blank-map smoke requires an interactive macOS GUI login session with at least one Aqua-attached display."
		echo "This shell currently has no visible NSScreen instances, so SDL window creation would fail before the engine can render anything."
		echo "Run the same command from Terminal or iTerm inside the desktop session, or set RECOIL_MACOS_SKIP_GUI_SESSION_CHECK=1 if you are intentionally using a custom GUI launcher."
		exit 1
	fi
fi

if [ "${RECOIL_SMOKE_WRAPPED:-0}" -ne 1 ]; then
	if [ "$(uname -s)" = "Darwin" ]; then
		exec /usr/bin/env RECOIL_SMOKE_WRAPPER_FOREGROUND=1 "$SCRIPT_DIR/run-smoke-wrapper.sh" /bin/sh "$0" "$@"
	fi

	exec "$SCRIPT_DIR/run-smoke-wrapper.sh" /bin/sh "$0" "$@"
fi

if [ -z "$WINDOW_HIDDEN" ]; then
	if [ "$(uname -s)" = "Darwin" ]; then
		WINDOW_HIDDEN=0
	else
		WINDOW_HIDDEN=1
	fi
fi

ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TMP_BASE="${TMPDIR:-/tmp}"
ISOLATION_DIR=$(mktemp -d "$TMP_BASE/recoil-legacy-smoke.XXXXXX")
PID=""
READY_STREAK=0

cleanup() {
	if [ -n "$PID" ]; then
		kill "$PID" 2>/dev/null || true
		wait "$PID" 2>/dev/null || true
	fi
}

trap cleanup EXIT INT TERM

mkdir -p "$ISOLATION_DIR/base" "$ISOLATION_DIR/games" "$ISOLATION_DIR/demos"

cp -R "$ROOT_DIR/cont/base/bitmaps"       "$ISOLATION_DIR/base/bitmaps.sdd"
cp -R "$ROOT_DIR/cont/base/cursors"       "$ISOLATION_DIR/base/cursors.sdd"
cp -R "$ROOT_DIR/cont/base/maphelper"     "$ISOLATION_DIR/base/maphelper.sdd"
cp -R "$ROOT_DIR/cont/base/springcontent" "$ISOLATION_DIR/base/springcontent.sdd"
cp -R "$ROOT_DIR/cont/fonts"              "$ISOLATION_DIR/fonts"

mkdir -p "$ISOLATION_DIR/games/arm64-smoke.sdd"
cat > "$ISOLATION_DIR/games/arm64-smoke.sdd/modinfo.lua" <<'EOF'
return {
	name = "ARM64 Smoke Test",
	description = "Minimal legacy-client smoke-test game for native Apple Silicon verification",
	modtype = 1,
	depend = {
		"Spring content v1",
		"Map Helper v1",
	},
}
EOF

cat > "$ISOLATION_DIR/script.txt" <<'EOF'
[GAME]
{
	IsHost=1;
	MyPlayerName=Host;
	OnlyLocal=1;
	RecordDemo=1;
	FixedRNGSeed=1;
	GameType=ARM64 Smoke Test;
	MapName=ARM64 Blank Smoke Map;
	InitBlank=1;
	[MAPOPTIONS]
	{
		blank_map_x=8;
		blank_map_y=8;
	}
	[PLAYER0]
	{
		Name=Host;
		Team=0;
		Spectator=1;
	}
	[TEAM0]
	{
		TeamLeader=0;
		AllyTeam=0;
	}
	[ALLYTEAM0]
	{
		NumAllies=0;
	}
}
EOF

cat > "$ISOLATION_DIR/springsettings.cfg" <<'EOF'
ForceCoreContext = 1
Fullscreen = 0
WindowBorderless = 0
XResolutionWindowed = 1280
YResolutionWindowed = 800
ValidationDisableSplashScreen = 1
EOF

if [ "$(uname -s)" = "Darwin" ]; then
cat >> "$ISOLATION_DIR/springsettings.cfg" <<'EOF'
VSync = 0
ValidationForceDisableVSync = 1
EOF
fi

set -- \
	"$SPRING_LEGACY" \
	-nocolor \
	-window

if [ "$WINDOW_HIDDEN" -eq 1 ]; then
	set -- "$@" -hidden
fi

set -- "$@" \
	-isolation \
	-isolation-dir "$ISOLATION_DIR" \
	"$ISOLATION_DIR/script.txt"

"$@" > "$ISOLATION_DIR/run.out" 2>&1 &
PID=$!

PASSED=0
ITER=0
while [ "$ITER" -lt "$TIMEOUT_SECS" ]; do
	if [ -f "$ISOLATION_DIR/infolog.txt" ]; then
		if grep -q "Fatal: \\[ExitSpringProcess\\]" "$ISOLATION_DIR/infolog.txt" "$ISOLATION_DIR/run.out" \
			|| grep -q "Segmentation fault" "$ISOLATION_DIR/infolog.txt" "$ISOLATION_DIR/run.out" \
			|| grep -q "caught opengl_error" "$ISOLATION_DIR/infolog.txt" "$ISOLATION_DIR/run.out"; then
			break
		fi

		if grep -q "SDL version :" "$ISOLATION_DIR/infolog.txt" \
			&& grep -q "GL version  :" "$ISOLATION_DIR/infolog.txt" \
			&& grep -q "Initialized OpenGL Context:" "$ISOLATION_DIR/infolog.txt" \
			&& (
				grep -q "\[PreGame::GameDataReceived\] recording demo to" "$ISOLATION_DIR/infolog.txt" \
				|| grep -q "\[PreGame::GameDataReceived\] recording demo to" "$ISOLATION_DIR/run.out"
			); then
			READY_STREAK=$((READY_STREAK + 1))

			if [ "$READY_STREAK" -ge "$STABLE_SECS" ] && kill -0 "$PID" 2>/dev/null; then
				PASSED=1
				break
			fi
		else
			READY_STREAK=0
		fi
	fi

	if ! kill -0 "$PID" 2>/dev/null; then
		break
	fi

	sleep 1
	ITER=$((ITER + 1))
done

if [ "$PASSED" -ne 1 ]; then
	echo "Legacy blank-map smoke failed."
	echo "Isolation dir: $ISOLATION_DIR"
	if [ -f "$ISOLATION_DIR/infolog.txt" ]; then
		tail -n 200 "$ISOLATION_DIR/infolog.txt"
	fi
	if [ -f "$ISOLATION_DIR/run.out" ]; then
		tail -n 120 "$ISOLATION_DIR/run.out"
	fi
	exit 1
fi

if ! ls "$ISOLATION_DIR"/demos/*.sdfz >/dev/null 2>&1; then
	echo "Legacy blank-map smoke failed: demo file was not created."
	echo "Isolation dir: $ISOLATION_DIR"
	exit 1
fi

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
PID=""

echo "Legacy blank-map smoke passed."
echo "Isolation dir: $ISOLATION_DIR"
