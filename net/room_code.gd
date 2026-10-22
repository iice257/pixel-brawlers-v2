class_name RoomCode
extends RefCounted
## Short room codes. UDP rooms encode the host's IPv4 address and port ("direct codes", 11 characters); the signalling server hands out 4-letter codes.

const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"     # 32 symbols, no I O 0 1

static func encode_addr(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4: return ""
	var n := 0
	for p in parts: n = (n << 8) | clampi(int(p), 0, 255)
	n = (n << 16) | (port & 0xFFFF)               # 48 bits -> 10 symbols of 5 bits
	var s := ""
	for i in 10:
		s = ALPHABET[n & 31] + s
		n >>= 5
	return s.substr(0, 5) + "-" + s.substr(5)

## { ip, port } or {} when the code is not a direct code.
static func decode_addr(code: String) -> Dictionary:
	var c := code.to_upper().replace("-", "").replace(" ", "")
	if c.length() != 10: return {}
	var n := 0
	for ch in c:
		var v := ALPHABET.find(ch)
		if v < 0: return {}
		n = (n << 5) | v
	var port := n & 0xFFFF
	n >>= 16
	return { "ip": "%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255], "port": port }

static func is_direct(code: String) -> bool:
	return not decode_addr(code).is_empty()

static func random_room(rng := RandomNumberGenerator.new()) -> String:
	rng.randomize()
	var s := ""
	for i in 4: s += ALPHABET[rng.randi() % 32]
	return s

## First private IPv4 address of this machine (what a guest on the same network types in).
static func local_ip() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."): continue
		if a.begins_with("192.168.") or a.begins_with("10."): return a
		var p := a.split(".")
		if a.begins_with("172.") and int(p[1]) >= 16 and int(p[1]) <= 31: return a
		if best == "": best = a
	return best
