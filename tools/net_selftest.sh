#!/usr/bin/env sh
# Two Godot processes play a full match over real UDP on localhost, each with 100 ms of simulated one-way latency by default.
# Usage: GODOT=<exe> sh tools/net_selftest.sh [latency_ms] [matches] [loss]    Exit 0 when every match ended without a desync and both peers agree.
G="${GODOT:-godot}"
LAT="${1:-100}"; N="${2:-3}"; LOSS="${3:-0}"
cd "$(dirname "$0")/.."
FAIL=0
for k in $(seq 1 "$N"); do
	PORT=$((7800 + k))
	case $k in 1) A=kestrel; B=briggs;; 2) A=briggs; B=kestrel;; *) A=kestrel; B=kestrel;; esac
	"$G" --headless --path . res://net/net_test.tscn -- --role=host --port=$PORT --pick=$A --latency=$LAT --loss=$LOSS > "/tmp/nt_host_$k.log" 2>&1 &
	HP=$!
	sleep 2
	"$G" --headless --path . res://net/net_test.tscn -- --role=guest --port=$PORT --pick=$B --latency=$LAT --loss=$LOSS > "/tmp/nt_guest_$k.log" 2>&1
	wait $HP
	H=$(grep '^RESULT' "/tmp/nt_host_$k.log"); GU=$(grep '^RESULT' "/tmp/nt_guest_$k.log")
	echo "match $k ($A vs $B)"; echo "  $H"; echo "  $GU"
	HW=$(echo "$H" | sed -n 's/.*wins=\(\[[^]]*\]\).*winner=\(-\?[0-9]*\).*hp=\([0-9,-]*\).*/\1 \2 \3/p')
	GW=$(echo "$GU" | sed -n 's/.*wins=\(\[[^]]*\]\).*winner=\(-\?[0-9]*\).*hp=\([0-9,-]*\).*/\1 \2 \3/p')
	if [ -z "$H" ] || [ -z "$GU" ] || echo "$H $GU" | grep -q "desync=true\|FAIL\|disconnected=true" || [ "$HW" != "$GW" ]; then echo "  -> MISMATCH or failure"; FAIL=1; else echo "  -> in sync"; fi
done
exit $FAIL
