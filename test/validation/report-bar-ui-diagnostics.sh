#!/bin/sh

set -eu

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
	echo "Usage: $0 /path/to/infolog.txt [/path/to/LuaUI/Config/BYAR.lua] [validation-widget-profile]"
	exit 1
fi

INFOLOG_PATH="$1"
BYAR_PATH="${2:-}"
VALIDATION_WIDGET_PROFILE="${3:-default}"
TOP_BAR_BASENAME="${RECOIL_BAR_TOP_BAR_BASENAME:-gui_top_bar.lua}"
TOP_BAR_WIDGET_NAME="${RECOIL_BAR_TOP_BAR_WIDGET_NAME:-}"
TOP_BAR_SOURCE="not-observed"
USER_WIDGET_SUMMARY="not-observed"
TOP_BAR_ORDER="not-found"
TOP_BAR_WIDGET_FALLBACK="${RECOIL_BAR_TOP_BAR_WIDGET_FALLBACK:-Top Bar}"
PROFILE_WIDGET_SUMMARY="n/a"

extract_widget_line() {
	path="$1"
	basename="$2"

	if [ ! -f "$path" ]; then
		return 0
	fi

	awk -v basename="$basename" '
		index($0, "Loading widget from ") && index($0, "<" basename ">") {
			line = $0
		}
		END {
			if (line != "")
				print line
		}
	' "$path"
}

extract_user_widget_summary() {
	path="$1"

	if [ ! -f "$path" ]; then
		echo "not-observed"
		return 0
	fi

	awk '
		index($0, "Loading widget from user:") {
			line = $0
			sub(/.*Loading widget from user:[[:space:]]+/, "", line)
			sub(/[[:space:]]+<[^>]+>.*/, "", line)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)

			if (line != "" && !seen[line]) {
				seen[line] = 1
				names[++count] = line
			}
		}

		END {
			if (count == 0) {
				print "no"
				exit
			}

			printf "yes (%d): ", count

			for (i = 1; i <= count; ++i) {
				if (i > 1)
					printf ", "
				printf "%s", names[i]
			}

			printf "\n"
		}
	' "$path"
}

extract_top_bar_order() {
	path="$1"
	name="$2"

	if [ ! -f "$path" ] || [ -z "$name" ]; then
		return 0
	fi

	awk -v name="$name" '
		index($0, "[\"" name "\"]") > 0 {
			line = $0
			if (match(line, /=[[:space:]]*-?[0-9]+/)) {
				value = substr(line, RSTART, RLENGTH)
				sub(/=[[:space:]]*/, "", value)
				print value
				exit
			}
		}
	' "$path"
}

extract_loaded_widget_names() {
	path="$1"

	if [ ! -f "$path" ]; then
		return 0
	fi

	awk '
		index($0, "Loading widget from ") {
			line = $0
			sub(/.*Loading widget from (mod:|user:)[[:space:]]+/, "", line)
			sub(/[[:space:]]+<[^>]+>.*/, "", line)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)

			if (line != "" && !seen[line]) {
				seen[line] = 1
				print line
			}
		}
	' "$path"
}

profile_widget_names() {
	case "$1" in
		macos-minimap-screencopy-triage)
			cat <<'EOF'
Minimap
RelativeMinimap
API Screencopy Manager
Minimap Rotation Manager
GUI Shader
EOF
		;;
		macos-postfx-triage)
			cat <<'EOF'
Distortion GL4
SSAO
Bloom Shader Deferred
Stained Glass
Unit Stencil GL4
EOF
		;;
	esac
}

extract_profile_widget_summary() {
	path="$1"
	profile="$2"
	loaded_widgets="$3"

	if [ ! -f "$path" ]; then
		echo "not-observed"
		return 0
	fi

	profile_widgets="$(profile_widget_names "$profile")"

	if [ -z "$profile_widgets" ]; then
		echo "n/a"
		return 0
	fi

	total=0
	loaded_count=0
	loaded_names=""

	while IFS= read -r widget_name; do
		[ -n "$widget_name" ] || continue
		total=$((total + 1))

		if printf '%s\n' "$loaded_widgets" | grep -Fqx "$widget_name"; then
			loaded_count=$((loaded_count + 1))
			if [ -n "$loaded_names" ]; then
				loaded_names="$loaded_names, $widget_name"
			else
				loaded_names="$widget_name"
			fi
		fi
	done <<EOF
$profile_widgets
EOF

	if [ "$loaded_count" -eq 0 ]; then
		printf 'no (%d/%d tracked widgets loaded)\n' "$loaded_count" "$total"
	else
		printf 'yes (%d/%d): %s\n' "$loaded_count" "$total" "$loaded_names"
	fi
}

TOP_BAR_LINE="$(extract_widget_line "$INFOLOG_PATH" "$TOP_BAR_BASENAME")"
LOADED_WIDGET_NAMES="$(extract_loaded_widget_names "$INFOLOG_PATH")"

if [ -n "$TOP_BAR_LINE" ]; then
	TOP_BAR_SOURCE="$(printf '%s\n' "$TOP_BAR_LINE" | sed -E 's/.*Loading widget from (mod:|user:).*/\1/' | sed 's/:$//')"

	if [ -z "$TOP_BAR_WIDGET_NAME" ]; then
		TOP_BAR_WIDGET_NAME="$(printf '%s\n' "$TOP_BAR_LINE" | sed -E "s/.*Loading widget from (mod:|user:)[[:space:]]+(.*)[[:space:]]+<${TOP_BAR_BASENAME}>.*/\\2/" | sed 's/[[:space:]]*$//')"
	fi
fi

USER_WIDGET_SUMMARY="$(extract_user_widget_summary "$INFOLOG_PATH")"
PROFILE_WIDGET_SUMMARY="$(extract_profile_widget_summary "$INFOLOG_PATH" "$VALIDATION_WIDGET_PROFILE" "$LOADED_WIDGET_NAMES")"

if [ -z "$TOP_BAR_WIDGET_NAME" ]; then
	TOP_BAR_WIDGET_NAME="$TOP_BAR_WIDGET_FALLBACK"
fi

if [ -n "$BYAR_PATH" ] && [ -f "$BYAR_PATH" ]; then
	TOP_BAR_ORDER="$(extract_top_bar_order "$BYAR_PATH" "$TOP_BAR_WIDGET_NAME")"
fi

if [ -z "$TOP_BAR_ORDER" ]; then
	TOP_BAR_ORDER="not-found"
fi

echo "BAR UI diagnostics:"
echo "  Validation widget profile: $VALIDATION_WIDGET_PROFILE"
echo "  Top Bar source: $TOP_BAR_SOURCE"
echo "  Top Bar widget: $TOP_BAR_WIDGET_NAME"
echo "  User widgets loaded: $USER_WIDGET_SUMMARY"
echo "  Profile-tracked widgets loaded: $PROFILE_WIDGET_SUMMARY"

if [ -n "$BYAR_PATH" ]; then
	if [ -f "$BYAR_PATH" ]; then
		echo "  BYAR config: $BYAR_PATH"
		echo "  Top Bar order: $TOP_BAR_ORDER"
	else
		echo "  BYAR config: missing ($BYAR_PATH)"
		echo "  Top Bar order: not-found"
	fi
fi
