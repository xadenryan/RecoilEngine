#!/bin/sh

set -eu

if [ $# -ne 2 ]; then
	echo "Usage: $0 /path/to/reference.png /path/to/captured.png"
	exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
	echo "compare-render-images.sh requires macOS 'sips'"
	exit 1
fi

REFERENCE_IMAGE="$1"
CAPTURED_IMAGE="$2"
TMP_BASE="${TMPDIR:-/tmp}"
WORK_DIR=$(mktemp -d "$TMP_BASE/recoil-render-compare.XXXXXX")
REFERENCE_TIFF="$WORK_DIR/reference.tiff"
CAPTURED_TIFF="$WORK_DIR/captured.tiff"

convert_image_to_tiff() {
	input_image="$1"
	output_image="$2"
	label="$3"

	if sips -s format tiff "$input_image" --out "$output_image" >/dev/null 2>&1; then
		return 0
	fi

	echo "Failed to convert $label image to TIFF with sips: $input_image"
	exit 1
}

cleanup() {
	rm -rf "$WORK_DIR"
}

trap cleanup EXIT HUP INT TERM

convert_image_to_tiff "$REFERENCE_IMAGE" "$REFERENCE_TIFF" "reference"
convert_image_to_tiff "$CAPTURED_IMAGE" "$CAPTURED_TIFF" "captured"

if cmp -s "$REFERENCE_TIFF" "$CAPTURED_TIFF"; then
	echo "Render images match."
	exit 0
fi

echo "Render images differ."
echo "Reference image: $REFERENCE_IMAGE"
echo "Captured image:  $CAPTURED_IMAGE"
exit 1
