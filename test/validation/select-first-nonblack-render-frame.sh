#!/bin/sh

set -eu

if [ $# -lt 1 ]; then
	echo "Usage: $0 /path/to/frame1.png [/path/to/frame2.png ...]"
	exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SWIFT_SCRIPT="$SCRIPT_DIR/select-first-nonblack-render-frame.swift"

if [ ! -f "$SWIFT_SCRIPT" ]; then
	echo "Missing helper script: $SWIFT_SCRIPT"
	exit 1
fi

if command -v xcrun >/dev/null 2>&1; then
	exec xcrun swift "$SWIFT_SCRIPT" "$@"
fi

if command -v swift >/dev/null 2>&1; then
	exec swift "$SWIFT_SCRIPT" "$@"
fi

echo "select-first-nonblack-render-frame.sh requires Xcode Swift tooling"
exit 1
