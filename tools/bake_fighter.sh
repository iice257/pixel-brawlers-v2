#!/usr/bin/env sh
# Drop-in fighter bake: tools/bake_fighter.sh <vrm path> <fighter id>   (GODOT may point at the Godot binary)
# Pass 1 writes the model and its 1024-px textures, the import pass registers the textures, pass 2 links the model to them.
set -e
G="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$G" --headless --path . --script res://tools/a0_bake_model.gd -- "$1" "$2" 2>/dev/null | grep "^baked"
"$G" --headless --path . --import >/dev/null 2>&1 || true
"$G" --headless --path . --script res://tools/a0_bake_model.gd -- "$1" "$2" 2>/dev/null | grep "^baked"
if grep -q '"within_budget": false' "fighters/$2/budget.json"; then
	echo "OVER BUDGET: see fighters/$2/budget.json (the model was still baked)" >&2
	exit 3
fi
