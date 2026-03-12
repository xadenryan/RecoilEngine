#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "${RECOIL_SMOKE_WRAPPED:-0}" -ne 1 ]; then
	exec "$SCRIPT_DIR/run-smoke-wrapper.sh" /bin/sh "$0" "$@"
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	echo "Usage: $0 /path/to/spring [reference-image]"
	exit 1
fi

SPRING_LEGACY="$1"
REFERENCE_IMAGE="${2:-}"
TIMEOUT_SECS="${RECOIL_LEGACY_RENDER_TIMEOUT_SECS:-45}"

if [ ! -x "$SPRING_LEGACY" ]; then
	echo "Parameter 1 $SPRING_LEGACY isn't executable!"
	exit 1
fi

if [ -n "$REFERENCE_IMAGE" ] && [ ! -f "$REFERENCE_IMAGE" ]; then
	echo "Reference image $REFERENCE_IMAGE doesn't exist!"
	exit 1
fi

if [ "$(uname -s)" = "Darwin" ] && [ "${RECOIL_LEGACY_SMOKE_GUI_BOOTSTRAP:-0}" -ne 1 ]; then
	GUI_UID=$(id -u)

	if launchctl print "gui/$GUI_UID" >/dev/null 2>&1; then
		exec launchctl asuser "$GUI_UID" /usr/bin/env \
			PATH="$PATH" \
			HOME="${HOME:-}" \
			TMPDIR="${TMPDIR:-}" \
			RECOIL_LEGACY_SMOKE_GUI_BOOTSTRAP=1 \
			/bin/sh "$0" "$@"
	fi
fi

ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TMP_BASE="${TMPDIR:-/tmp}"
ISOLATION_DIR=$(mktemp -d "$TMP_BASE/recoil-legacy-render-smoke.XXXXXX")
PID=""
SCREENSHOT_PATH=""

cleanup() {
	if [ -n "$PID" ]; then
		kill "$PID" 2>/dev/null || true
		wait "$PID" 2>/dev/null || true
	fi
}

trap cleanup EXIT INT TERM

mkdir -p \
	"$ISOLATION_DIR/base" \
	"$ISOLATION_DIR/demos" \
	"$ISOLATION_DIR/games/arm64-smoke.sdd"

cp -R "$ROOT_DIR/cont/base/bitmaps"       "$ISOLATION_DIR/base/bitmaps.sdd"
cp -R "$ROOT_DIR/cont/base/cursors"       "$ISOLATION_DIR/base/cursors.sdd"
cp -R "$ROOT_DIR/cont/base/maphelper"     "$ISOLATION_DIR/base/maphelper.sdd"
cp -R "$ROOT_DIR/cont/base/springcontent" "$ISOLATION_DIR/base/springcontent.sdd"
cp -R "$ROOT_DIR/cont/fonts"              "$ISOLATION_DIR/fonts"

cat > "$ISOLATION_DIR/games/arm64-smoke.sdd/modinfo.lua" <<'EOF'
return {
	name = "ARM64 Smoke Test",
	description = "Minimal legacy-client render smoke-test game for native Apple Silicon verification",
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
XResolutionWindowed = 640
YResolutionWindowed = 360
LuaAutoEnableUserWidgets = 1
ShowClock = 0
ShowFPS = 0
ShowSpeed = 0
ValidationRenderCapture = 1
ValidationRenderCaptureFrame = 30
EOF

"$SPRING_LEGACY" \
	-nocolor \
	-window \
	-hidden \
	-isolation \
	-isolation-dir "$ISOLATION_DIR" \
	"$ISOLATION_DIR/script.txt" \
	> "$ISOLATION_DIR/run.out" 2>&1 &
PID=$!

ITER=0
while [ "$ITER" -lt "$TIMEOUT_SECS" ]; do
	if [ -f "$ISOLATION_DIR/infolog.txt" ]; then
		if grep -q "Fatal: \\[ExitSpringProcess\\]" "$ISOLATION_DIR/infolog.txt" \
			|| grep -q "Segmentation fault" "$ISOLATION_DIR/infolog.txt" \
			|| grep -q "caught opengl_error" "$ISOLATION_DIR/infolog.txt"; then
			break
		fi
	fi

	SCREENSHOT_PATH=$(find "$ISOLATION_DIR/screenshots" -name 'screen_*.png' -print 2>/dev/null | head -n 1 || true)
	if [ -n "$SCREENSHOT_PATH" ]; then
		break
	fi

	if ! kill -0 "$PID" 2>/dev/null; then
		break
	fi

	sleep 1
	ITER=$((ITER + 1))
done

if ! kill -0 "$PID" 2>/dev/null; then
	wait "$PID" 2>/dev/null || true
	PID=""
	SCREENSHOT_PATH=$(find "$ISOLATION_DIR/screenshots" -name 'screen_*.png' -print 2>/dev/null | head -n 1 || true)
fi

if [ -z "$SCREENSHOT_PATH" ]; then
	echo "Legacy render smoke failed: screenshot was not created."
	echo "Isolation dir: $ISOLATION_DIR"
	if [ -f "$ISOLATION_DIR/infolog.txt" ]; then
		tail -n 200 "$ISOLATION_DIR/infolog.txt"
	fi
	exit 1
elif [ -n "$PID" ]; then
	wait "$PID"
	PID=""
fi

if [ -n "$REFERENCE_IMAGE" ]; then
	"$SCRIPT_DIR/compare-render-images.sh" "$REFERENCE_IMAGE" "$SCREENSHOT_PATH"
fi

if [ -n "${RECOIL_RENDER_CAPTURE_WRITE_BASELINE:-}" ]; then
	mkdir -p "$(dirname -- "$RECOIL_RENDER_CAPTURE_WRITE_BASELINE")"
	cp "$SCREENSHOT_PATH" "$RECOIL_RENDER_CAPTURE_WRITE_BASELINE"
fi

echo "Legacy render smoke passed."
echo "Isolation dir: $ISOLATION_DIR"
echo "Screenshot: $SCREENSHOT_PATH"
