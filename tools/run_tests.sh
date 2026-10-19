#!/usr/bin/env sh
# Headless test run: GUT over res://tests, then the smoke test. GODOT may point at the Godot binary.
set -e
G="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$G" --headless --path . --import >/dev/null 2>&1 || true
"$G" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
"$G" --headless --path . --script res://tools/smoke.gd
