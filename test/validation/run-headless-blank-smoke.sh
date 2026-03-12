#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "${RECOIL_SMOKE_WRAPPED:-0}" -ne 1 ]; then
	exec "$SCRIPT_DIR/run-smoke-wrapper.sh" /bin/sh "$0" "$@"
fi

if [ $# -lt 1 ]; then
	echo "Usage: $0 /path/to/spring-headless [timeout-seconds]"
	exit 1
fi

SPRING_HEADLESS="$1"
TIMEOUT_SECS="${2:-20}"

if [ ! -x "$SPRING_HEADLESS" ]; then
	echo "Parameter 1 $SPRING_HEADLESS isn't executable!"
	exit 1
fi

ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TMP_BASE="${TMPDIR:-/tmp}"
ISOLATION_DIR=$(mktemp -d "$TMP_BASE/recoil-headless-smoke.XXXXXX")
PID=""

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

mkdir -p "$ISOLATION_DIR/games/arm64-smoke.sdd"
cat > "$ISOLATION_DIR/games/arm64-smoke.sdd/modinfo.lua" <<'EOF'
return {
	name = "ARM64 Smoke Test",
	description = "Minimal headless smoke-test game for native Apple Silicon verification",
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

"$SPRING_HEADLESS" \
	-nocolor \
	-isolation \
	-isolation-dir "$ISOLATION_DIR" \
	"$ISOLATION_DIR/script.txt" \
	> "$ISOLATION_DIR/run.out" 2>&1 &
PID=$!

PASSED=0
ITER=0
while [ "$ITER" -lt "$TIMEOUT_SECS" ]; do
	if [ -f "$ISOLATION_DIR/infolog.txt" ]; then
		if grep -q "\[PreGame::StartServer\]" "$ISOLATION_DIR/infolog.txt" \
			&& grep -q "\[GameServer\] Initialize:" "$ISOLATION_DIR/infolog.txt" \
			&& grep -q "\[PreGame::GameDataReceived\] recording demo to" "$ISOLATION_DIR/infolog.txt"; then
			PASSED=1
			break
		fi
	fi

	if ! kill -0 "$PID" 2>/dev/null; then
		break
	fi

	sleep 1
	ITER=$((ITER + 1))
done

if [ "$PASSED" -ne 1 ]; then
	echo "Headless blank-map smoke failed."
	echo "Isolation dir: $ISOLATION_DIR"
	if [ -f "$ISOLATION_DIR/infolog.txt" ]; then
		tail -n 200 "$ISOLATION_DIR/infolog.txt"
	fi
	exit 1
fi

if ! ls "$ISOLATION_DIR"/demos/*.sdfz >/dev/null 2>&1; then
	echo "Headless blank-map smoke failed: demo file was not created."
	echo "Isolation dir: $ISOLATION_DIR"
	exit 1
fi

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
PID=""

echo "Headless blank-map smoke passed."
echo "Isolation dir: $ISOLATION_DIR"
