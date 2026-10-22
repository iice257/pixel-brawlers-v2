class_name NetConfig
extends RefCounted
## Where online signalling lives. data/net.json picks the backend:
##   { "signal_type": "http", "signal_url": "https://relay.example" }                          the relay in tools/signal_server.py
##   { "signal_type": "supabase", "url": "https://<project>.supabase.co", "anon_key": "..." }   a Supabase Realtime broadcast channel
## A relay URL given as --signal=<url>, ?signal=<url> (web) or [online] signal_url in user://settings.cfg overrides data/net.json and selects the HTTP relay.
## With nothing configured, browsers cannot host or join; desktop and Android use direct UDP and need no signalling.

const SETTINGS := "user://settings.cfg"

static func _file() -> Dictionary:
	if FileAccess.file_exists("res://data/net.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/net.json"))
		if d is Dictionary: return d
	return {}

static func _override() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--signal="): return a.trim_prefix("--signal=")
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('signal') || ''")
		if q is String and q != "": return q
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK: return String(c.get_value("online", "signal_url", ""))
	return ""

static func make_signal(host: bool) -> SignalChannel:
	var d := _file()
	var url := _override()
	if url == "" and String(d.get("signal_type", "http")) == "supabase":
		if String(d.get("url", "")) == "" or String(d.get("anon_key", "")) == "": return null
		return SignalSupabase.new(String(d.url), String(d.anon_key), host)
	if url == "": url = String(d.get("signal_url", ""))
	return SignalHttp.new(url, host) if url != "" else null

## Simulated one-way latency in ms for testing the menu flow (--netlag=100).
static func sim_latency() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--netlag="): return int(a.trim_prefix("--netlag="))
	return 0
