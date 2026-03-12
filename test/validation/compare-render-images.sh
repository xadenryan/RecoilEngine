#!/bin/sh

set -eu

if [ $# -ne 2 ]; then
	echo "Usage: $0 /path/to/reference.png /path/to/captured.png"
	exit 1
fi

REFERENCE_IMAGE="$1"
CAPTURED_IMAGE="$2"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SWIFT_SCRIPT="$SCRIPT_DIR/compare-render-images.swift"

if [ ! -f "$SWIFT_SCRIPT" ]; then
	echo "Missing helper script: $SWIFT_SCRIPT"
	exit 1
fi

if command -v xcrun >/dev/null 2>&1; then
	exec xcrun swift "$SWIFT_SCRIPT" "$REFERENCE_IMAGE" "$CAPTURED_IMAGE"
fi

if command -v swift >/dev/null 2>&1; then
	exec swift "$SWIFT_SCRIPT" "$REFERENCE_IMAGE" "$CAPTURED_IMAGE"
fi

echo "compare-render-images.sh requires Xcode Swift tooling"
exit 1
