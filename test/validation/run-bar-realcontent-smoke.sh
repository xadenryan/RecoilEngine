#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "${RECOIL_SMOKE_WRAPPED:-0}" -ne 1 ]; then
	exec "$SCRIPT_DIR/run-smoke-wrapper.sh" /bin/sh "$0" "$@"
fi

if [ $# -lt 2 ] || [ $# -gt 4 ]; then
	echo "Usage: $0 /path/to/spring /path/to/pr-downloader [reference-image] [timeout-seconds]"
	exit 1
fi

SPRING_LEGACY="$1"
PR_DOWNLOADER="$2"
REFERENCE_IMAGE=""
TIMEOUT_SECS="${RECOIL_BAR_REALCONTENT_TIMEOUT_SECS:-240}"

case $# in
	3)
		case "$3" in
			''|*[!0-9]*)
				REFERENCE_IMAGE="$3"
			;;
			*)
				TIMEOUT_SECS="$3"
			;;
		esac
	;;
	4)
		REFERENCE_IMAGE="$3"
		TIMEOUT_SECS="$4"
	;;
esac

if [ ! -x "$SPRING_LEGACY" ]; then
	echo "Parameter 1 $SPRING_LEGACY isn't executable!"
	exit 1
fi

if [ ! -x "$PR_DOWNLOADER" ]; then
	echo "Parameter 2 $PR_DOWNLOADER isn't executable!"
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
			RECOIL_SMOKE_WRAPPED=1 \
			/bin/sh "$0" "$@"
	fi
fi

ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TMP_BASE="${TMPDIR:-/tmp}"

if [ -n "${RECOIL_BAR_CONTENT_CACHE_DIR:-}" ]; then
	CACHE_DIR="$RECOIL_BAR_CONTENT_CACHE_DIR"
elif [ "$(uname -s)" = "Darwin" ]; then
	CACHE_DIR="${HOME}/Library/Caches/RecoilEngine/apple-silicon/bar-realcontent"
else
	CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/RecoilEngine/apple-silicon/bar-realcontent"
fi

ISOLATION_DIR=$(mktemp -d "$TMP_BASE/recoil-bar-realcontent-smoke.XXXXXX")
PID=""
SCREENSHOT_PATH=""
MAP_SEARCH_NAME="${RECOIL_BAR_MAP_SEARCH_NAME:-Angel Crossing 1.4}"
MAP_SCRIPT_NAME="${RECOIL_BAR_MAP_SCRIPT_NAME:-$MAP_SEARCH_NAME}"
GAME_TAG="${RECOIL_BAR_RAPID_TAG:-rapid://byar:test}"
CAPTURE_FRAME="${RECOIL_BAR_CAPTURE_FRAME:-60}"
RENDER_MAX_DIFF_PIXELS="${RECOIL_BAR_RENDER_MAX_DIFF_PIXELS:-256}"
RENDER_MAX_CHANNEL_DELTA="${RECOIL_BAR_RENDER_MAX_CHANNEL_DELTA:-2}"

cleanup() {
	if [ -n "$PID" ]; then
		kill "$PID" 2>/dev/null || true
		wait "$PID" 2>/dev/null || true
	fi
}

trap cleanup EXIT INT TERM

mkdir -p "$CACHE_DIR"

: "${PRD_RAPID_USE_STREAMER:=false}"
: "${PRD_RAPID_REPO_MASTER:=https://repos-cdn.beyondallreason.dev/repos.gz}"
: "${PRD_HTTP_SEARCH_URL:=https://files-cdn.beyondallreason.dev/find}"
export PRD_RAPID_USE_STREAMER
export PRD_RAPID_REPO_MASTER
export PRD_HTTP_SEARCH_URL

"$PR_DOWNLOADER" \
	--filesystem-writepath "$CACHE_DIR" \
	--download-game "$GAME_TAG" \
	--download-map "$MAP_SEARCH_NAME"

mkdir -p \
	"$ISOLATION_DIR/base" \
	"$ISOLATION_DIR/demos"

ln -s "$CACHE_DIR/maps"     "$ISOLATION_DIR/maps"
ln -s "$CACHE_DIR/packages" "$ISOLATION_DIR/packages"
ln -s "$CACHE_DIR/pool"     "$ISOLATION_DIR/pool"
ln -s "$CACHE_DIR/rapid"    "$ISOLATION_DIR/rapid"

cp -R "$ROOT_DIR/cont/base/bitmaps"       "$ISOLATION_DIR/base/bitmaps.sdd"
cp -R "$ROOT_DIR/cont/base/cursors"       "$ISOLATION_DIR/base/cursors.sdd"
cp -R "$ROOT_DIR/cont/base/maphelper"     "$ISOLATION_DIR/base/maphelper.sdd"
cp -R "$ROOT_DIR/cont/base/springcontent" "$ISOLATION_DIR/base/springcontent.sdd"
cp -R "$ROOT_DIR/cont/fonts"              "$ISOLATION_DIR/fonts"

cat > "$ISOLATION_DIR/script.txt" <<EOF
[GAME]
{
	IsHost=1;
	MyPlayerName=Host;
	OnlyLocal=1;
	RecordDemo=1;
	FixedRNGSeed=1;
	StartPosType=0;
	MapName=$MAP_SCRIPT_NAME;
	GameType=$GAME_TAG;
	[PLAYER0]
	{
		Name=Host;
		Team=0;
		Spectator=0;
	}
	[TEAM0]
	{
		TeamLeader=0;
		AllyTeam=0;
		RGBColor=0.2 0.7 1.0;
		Side=Armada;
	}
	[ALLYTEAM0]
	{
		NumAllies=0;
	}
}
EOF

cat > "$ISOLATION_DIR/springsettings.cfg" <<EOF
ForceCoreContext = 1
Fullscreen = 0
WindowBorderless = 0
XResolutionWindowed = 1280
YResolutionWindowed = 800
ShowClock = 0
ShowFPS = 0
ShowSpeed = 0
ValidationRenderCapture = 1
ValidationRenderCaptureFrame = $CAPTURE_FRAME
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
	echo "BAR real-content smoke failed: screenshot was not created."
	echo "Cache dir: $CACHE_DIR"
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
	RECOIL_RENDER_COMPARE_MAX_DIFF_PIXELS="$RENDER_MAX_DIFF_PIXELS" \
	RECOIL_RENDER_COMPARE_MAX_CHANNEL_DELTA="$RENDER_MAX_CHANNEL_DELTA" \
	"$SCRIPT_DIR/compare-render-images.sh" "$REFERENCE_IMAGE" "$SCREENSHOT_PATH"
fi

if [ -n "${RECOIL_RENDER_CAPTURE_WRITE_BASELINE:-}" ]; then
	mkdir -p "$(dirname -- "$RECOIL_RENDER_CAPTURE_WRITE_BASELINE")"
	cp "$SCREENSHOT_PATH" "$RECOIL_RENDER_CAPTURE_WRITE_BASELINE"
fi

echo "BAR real-content smoke passed."
echo "Cache dir: $CACHE_DIR"
echo "Isolation dir: $ISOLATION_DIR"
echo "Screenshot: $SCREENSHOT_PATH"
