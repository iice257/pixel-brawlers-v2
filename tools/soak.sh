#!/usr/bin/env sh
# Full seeded soak (200 matches). Slow: run before merges, not on every test run.
set -e
G="${GODOT:-godot}"
cd "$(dirname "$0")/.."
SOAK_MATCHES=200 "$G" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=test_match -gunit_test_name=test_soak -gexit
