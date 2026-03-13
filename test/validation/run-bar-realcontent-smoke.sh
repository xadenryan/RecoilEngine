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
VALIDATION_LUAUI_CONFIG_DIR="$SCRIPT_DIR/LuaUI/Config"

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
VALIDATION_SCREENSHOT_PATH=""
SELECTED_PRESENT_CAPTURE_PATH=""
PRESENT_CAPTURE_SELECTION_LOG_PATH=""
MAP_SEARCH_NAME="${RECOIL_BAR_MAP_SEARCH_NAME:-Angel Crossing 1.4}"
MAP_SCRIPT_NAME="${RECOIL_BAR_MAP_SCRIPT_NAME:-$MAP_SEARCH_NAME}"
GAME_TAG="${RECOIL_BAR_RAPID_TAG:-rapid://byar:test}"
CAPTURE_FRAME="${RECOIL_BAR_CAPTURE_FRAME:-60}"
PRESENT_CAPTURE_START_FRAME="${RECOIL_BAR_PRESENT_CAPTURE_START_FRAME:-1}"
PRESENT_CAPTURE_FRAME_COUNT="${RECOIL_BAR_PRESENT_CAPTURE_FRAME_COUNT:-0}"
PRESENT_CAPTURE_QUALITY="${RECOIL_BAR_PRESENT_CAPTURE_QUALITY:-90}"
PRESENT_CAPTURE_PREFIX="${RECOIL_BAR_PRESENT_CAPTURE_PREFIX:-bar_present}"
RENDER_MAX_DIFF_PIXELS="${RECOIL_BAR_RENDER_MAX_DIFF_PIXELS:-256}"
RENDER_MAX_CHANNEL_DELTA="${RECOIL_BAR_RENDER_MAX_CHANNEL_DELTA:-2}"
VALIDATION_HIDE_INTERFACE="${RECOIL_BAR_VALIDATION_HIDE_INTERFACE:-1}"
VALIDATION_CENTER_CAMERA="${RECOIL_BAR_VALIDATION_CENTER_CAMERA:-1}"
VALIDATION_PLAYER_START_CAMERA="${RECOIL_BAR_VALIDATION_PLAYER_START_CAMERA:-0}"
VALIDATION_SCENE_ONLY="${RECOIL_BAR_VALIDATION_SCENE_ONLY:-1}"
VALIDATION_HIDE_CURSOR="${RECOIL_BAR_VALIDATION_HIDE_CURSOR:-1}"
VALIDATION_CAMERA_HEIGHT="${RECOIL_BAR_VALIDATION_CAMERA_HEIGHT:-1200}"
VALIDATION_CAMERA_BACK_OFFSET="${RECOIL_BAR_VALIDATION_CAMERA_BACK_OFFSET:-900}"
WINDOW_HIDDEN="${RECOIL_BAR_SMOKE_HIDDEN:-1}"
BYAR_CONFIG_PATH=""
COMPARE_EXIT=0

cleanup() {
	if [ -n "$PID" ]; then
		kill "$PID" 2>/dev/null || true
		wait "$PID" 2>/dev/null || true
	fi
}

normalize_archive_key() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//'
}

find_cached_map_archive() {
	target_key=$(normalize_archive_key "$1")

	for path in "$CACHE_DIR"/maps/*; do
		[ -f "$path" ] || continue

		case "$path" in
			*.sd7|*.sdz) ;;
			*) continue ;;
		esac

		archive_name=$(basename "$path")
		archive_key=$(normalize_archive_key "${archive_name%.*}")

		if [ "$archive_key" = "$target_key" ]; then
			printf '%s\n' "$path"
			return 0
		fi
	done

	return 1
}

print_bar_ui_diagnostics() {
	"$SCRIPT_DIR/report-bar-ui-diagnostics.sh" \
		"$ISOLATION_DIR/infolog.txt" \
		"$BYAR_CONFIG_PATH"
}

select_first_present_capture_frame() {
	if [ "$PRESENT_CAPTURE_FRAME_COUNT" -le 0 ]; then
		return 0
	fi

	set -- "$ISOLATION_DIR/screenshots"/${PRESENT_CAPTURE_PREFIX}_df*.png

	if [ ! -e "$1" ]; then
		return 0
	fi

	PRESENT_CAPTURE_SELECTION_LOG_PATH="$ISOLATION_DIR/present-capture-selection.log"

	if SELECTED_PRESENT_CAPTURE_PATH=$(
		"$SCRIPT_DIR/select-first-nonblack-render-frame.sh" "$@" \
			2>"$PRESENT_CAPTURE_SELECTION_LOG_PATH"
	); then
		return 0
	fi

	SELECTED_PRESENT_CAPTURE_PATH=""
}

trap cleanup EXIT INT TERM

mkdir -p "$CACHE_DIR"
CACHE_DIR=$(CDPATH= cd -- "$CACHE_DIR" && pwd)

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
	"$ISOLATION_DIR/demos" \
	"$ISOLATION_DIR/maps"

MAP_ARCHIVE=$(find_cached_map_archive "$MAP_SCRIPT_NAME") || {
	echo "BAR real-content smoke failed: cached map archive for \"$MAP_SCRIPT_NAME\" was not found in $CACHE_DIR/maps." >&2
	exit 1
}

ln -s "$MAP_ARCHIVE"        "$ISOLATION_DIR/maps/$(basename "$MAP_ARCHIVE")"
ln -s "$CACHE_DIR/packages" "$ISOLATION_DIR/packages"
ln -s "$CACHE_DIR/pool"     "$ISOLATION_DIR/pool"
ln -s "$CACHE_DIR/rapid"    "$ISOLATION_DIR/rapid"

cp -R "$ROOT_DIR/cont/base/bitmaps"       "$ISOLATION_DIR/base/bitmaps.sdd"
cp -R "$ROOT_DIR/cont/base/cursors"       "$ISOLATION_DIR/base/cursors.sdd"
cp -R "$ROOT_DIR/cont/base/maphelper"     "$ISOLATION_DIR/base/maphelper.sdd"
cp -R "$ROOT_DIR/cont/base/springcontent" "$ISOLATION_DIR/base/springcontent.sdd"
cp -R "$ROOT_DIR/cont/LuaUI"              "$ISOLATION_DIR/LuaUI"
cp -R "$ROOT_DIR/cont/fonts"              "$ISOLATION_DIR/fonts"
BYAR_CONFIG_PATH="$ISOLATION_DIR/LuaUI/Config/BYAR.lua"

if [ -f "$VALIDATION_LUAUI_CONFIG_DIR/BYAR.lua" ]; then
	cp "$VALIDATION_LUAUI_CONFIG_DIR/BYAR.lua" "$BYAR_CONFIG_PATH"
fi

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
ValidationDisableSplashScreen = 1
LuaAutoEnableUserWidgets = 1
ShowClock = 0
ShowFPS = 0
ShowSpeed = 0
ValidationRenderCapture = 1
ValidationRenderCaptureFrame = $CAPTURE_FRAME
ValidationRenderCaptureHideInterface = $VALIDATION_HIDE_INTERFACE
ValidationRenderCaptureCenterCamera = $VALIDATION_CENTER_CAMERA
ValidationRenderCapturePlayerStartCamera = $VALIDATION_PLAYER_START_CAMERA
ValidationRenderCaptureSceneOnly = $VALIDATION_SCENE_ONLY
ValidationRenderCaptureHideCursor = $VALIDATION_HIDE_CURSOR
ValidationRenderCaptureCameraHeight = $VALIDATION_CAMERA_HEIGHT
ValidationRenderCaptureCameraBackOffset = $VALIDATION_CAMERA_BACK_OFFSET
EOF

if [ "$PRESENT_CAPTURE_FRAME_COUNT" -gt 0 ]; then
cat >> "$ISOLATION_DIR/springsettings.cfg" <<EOF
ValidationPresentCapture = 1
ValidationPresentCaptureStartFrame = $PRESENT_CAPTURE_START_FRAME
ValidationPresentCaptureFrameCount = $PRESENT_CAPTURE_FRAME_COUNT
ValidationPresentCaptureQuality = $PRESENT_CAPTURE_QUALITY
ValidationPresentCapturePrefix = $PRESENT_CAPTURE_PREFIX
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

ITER=0
while [ "$ITER" -lt "$TIMEOUT_SECS" ]; do
	if [ -f "$ISOLATION_DIR/infolog.txt" ]; then
		if grep -q "Fatal: \\[ExitSpringProcess\\]" "$ISOLATION_DIR/infolog.txt" \
			|| grep -q "Segmentation fault" "$ISOLATION_DIR/infolog.txt" \
			|| grep -q "caught opengl_error" "$ISOLATION_DIR/infolog.txt"; then
			break
		fi
	fi

	VALIDATION_SCREENSHOT_PATH=$(find "$ISOLATION_DIR/screenshots" -name 'screen_*.png' -print 2>/dev/null | head -n 1 || true)
	if [ -n "$VALIDATION_SCREENSHOT_PATH" ]; then
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
	VALIDATION_SCREENSHOT_PATH=$(find "$ISOLATION_DIR/screenshots" -name 'screen_*.png' -print 2>/dev/null | head -n 1 || true)
fi

select_first_present_capture_frame
SCREENSHOT_PATH="$VALIDATION_SCREENSHOT_PATH"

if [ -z "$SCREENSHOT_PATH" ]; then
	echo "BAR real-content smoke failed: screenshot was not created."
	echo "Cache dir: $CACHE_DIR"
	echo "Isolation dir: $ISOLATION_DIR"
	if [ -n "$PRESENT_CAPTURE_SELECTION_LOG_PATH" ] && [ -f "$PRESENT_CAPTURE_SELECTION_LOG_PATH" ]; then
		echo "Present capture selection log:"
		cat "$PRESENT_CAPTURE_SELECTION_LOG_PATH"
	fi
	print_bar_ui_diagnostics
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
	"$SCRIPT_DIR/compare-render-images.sh" "$REFERENCE_IMAGE" "$SCREENSHOT_PATH" || COMPARE_EXIT=$?
fi

if [ -n "${RECOIL_RENDER_CAPTURE_WRITE_BASELINE:-}" ]; then
	mkdir -p "$(dirname -- "$RECOIL_RENDER_CAPTURE_WRITE_BASELINE")"
	cp "$SCREENSHOT_PATH" "$RECOIL_RENDER_CAPTURE_WRITE_BASELINE"
fi

print_bar_ui_diagnostics

if [ "$COMPARE_EXIT" -ne 0 ]; then
	exit "$COMPARE_EXIT"
fi

echo "BAR real-content smoke passed."
echo "Cache dir: $CACHE_DIR"
echo "Isolation dir: $ISOLATION_DIR"
echo "Screenshot: $SCREENSHOT_PATH"
if [ -n "$VALIDATION_SCREENSHOT_PATH" ]; then
	echo "Validation screenshot: $VALIDATION_SCREENSHOT_PATH"
fi
if [ -n "$SELECTED_PRESENT_CAPTURE_PATH" ]; then
	echo "Selected present capture: $SELECTED_PRESENT_CAPTURE_PATH"
elif [ "$PRESENT_CAPTURE_FRAME_COUNT" -gt 0 ]; then
	echo "Selected present capture: none usable; fell back to validation screenshot"
fi
if [ -n "$PRESENT_CAPTURE_SELECTION_LOG_PATH" ] && [ -f "$PRESENT_CAPTURE_SELECTION_LOG_PATH" ]; then
	echo "Present capture selection log: $PRESENT_CAPTURE_SELECTION_LOG_PATH"
fi
