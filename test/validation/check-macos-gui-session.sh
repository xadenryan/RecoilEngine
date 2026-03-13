#!/bin/sh

set -eu

if [ "$(uname -s)" != "Darwin" ]; then
	exit 0
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SWIFT_SCRIPT="$SCRIPT_DIR/check-macos-gui-session.swift"

if [ ! -f "$SWIFT_SCRIPT" ]; then
	echo "Missing helper script: $SWIFT_SCRIPT" >&2
	exit 1
fi

if command -v xcrun >/dev/null 2>&1; then
	exec xcrun swift "$SWIFT_SCRIPT" "$@"
fi

if command -v swift >/dev/null 2>&1; then
	exec swift "$SWIFT_SCRIPT" "$@"
fi

echo "check-macos-gui-session.sh requires Xcode Swift tooling" >&2
exit 1
