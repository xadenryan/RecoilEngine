#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

: "${RECOIL_BAR_PRESENT_CAPTURE_PREFIX:=bar_observation_present}"

export RECOIL_BAR_PRESENT_CAPTURE_PREFIX

exec "$SCRIPT_DIR/run-bar-playability-smoke.sh" "$@"
