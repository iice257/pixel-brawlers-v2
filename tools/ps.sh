#!/usr/bin/env sh
# Pose contact sheet: sh tools/ps.sh <out.png> <cols> <list> e.g. sh tools/ps.sh s.png 4 L:ant,L:imp
G="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
"$G" --path . res://tools/pose_sheet.tscn -- --out="$1" --cols="$2" --list="$3" 2>&1 | grep -iE "error|SCRIPT" | grep -v leaked
