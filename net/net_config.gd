class_name NetConfig
extends RefCounted
## Where the signalling relay lives. Precedence: --signal=<url> user arg, ?signal=<url> in the page address (web), [online] signal_url in
## user://settings.cfg, then data/net.json. An empty value means "no relay": browsers cannot host or join, desktop and Android use direct UDP.

const SETTINGS := "user://settings.cfg"

static func signal_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--signal="): return a.trim_prefix("--signal=")
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('signal') || ''")
		if q is String and q != "": return q
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		var v := String(c.get_value("online", "signal_url", ""))
		if v != "": return v
	if FileAccess.file_exists("res://data/net.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/net.json"))
		if d is Dictionary: return String(d.get("signal_url", ""))
	return ""

## Simulated one-way latency in ms for testing the menu flow (--netlag=100).
static func sim_latency() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--netlag="): return int(a.trim_prefix("--netlag="))
	return 0
