#!/bin/sh

set -eu

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	echo "Usage: $0 /path/to/captured.png [/path/to/reference.png]"
	exit 1
fi

CAPTURED_IMAGE="$1"
REFERENCE_IMAGE="${2:-}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SWIFT_SCRIPT="$SCRIPT_DIR/analyze-render-image.swift"

if [ ! -f "$SWIFT_SCRIPT" ]; then
	echo "Missing helper script: $SWIFT_SCRIPT"
	exit 1
fi

if command -v xcrun >/dev/null 2>&1; then
	if [ -n "$REFERENCE_IMAGE" ]; then
		exec xcrun swift "$SWIFT_SCRIPT" "$CAPTURED_IMAGE" "$REFERENCE_IMAGE"
	fi
	exec xcrun swift "$SWIFT_SCRIPT" "$CAPTURED_IMAGE"
fi

if command -v swift >/dev/null 2>&1; then
	if [ -n "$REFERENCE_IMAGE" ]; then
		exec swift "$SWIFT_SCRIPT" "$CAPTURED_IMAGE" "$REFERENCE_IMAGE"
	fi
	exec swift "$SWIFT_SCRIPT" "$CAPTURED_IMAGE"
fi

echo "analyze-render-image.sh requires Xcode Swift tooling"
exit 1
