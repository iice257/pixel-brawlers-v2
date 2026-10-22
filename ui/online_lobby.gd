class_name OnlineLobby
extends Control
## ONLINE screen: pick a fighter, then HOST (shows a room code) or JOIN (type one). Browsers connect over WebRTC through the signalling relay with
## 4-letter codes; desktop and Android connect over direct UDP with an 11-character code that holds the host's address (same network, or a forwarded port).
## When the handshake finishes the screen hands the NetLink to the front end, which starts the fight.

var flow: Flow
var pick := 0
var link: NetLink
var phase := "menu"           # menu | hosting | joining
var _col: VBoxContainer
var _status: Label
var _code: Label
var _edit: LineEdit
var _rtc: RtcTransport
var _age := 0.0
var _handed := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_menu()

func _clear() -> void:
	if _col: _col.queue_free()
	_col = flow._column(100, 190)
	add_child(_col)
	for c in get_children():
		if c is Label and c.has_meta("lobby"): c.queue_free()

func _title() -> void:
	var t := flow._label("ONLINE", 90, Flow.STEAM); t.position = Vector2(100, 60); t.set_meta("lobby", true); add_child(t)

func _fighter_text() -> String:
	return "   FIGHTER  <  %s  >" % String(Flow.roster()[pick].name)

func _menu() -> void:
	phase = "menu"; _close_link()
	_clear(); _title()
	var fb := flow._button(_fighter_text(), func(): pass)
	fb.pressed.connect(func(): pick = (pick + 1) % Flow.roster().size(); fb.text = _fighter_text())
	fb.gui_input.connect(func(e: InputEvent):
		var d := 0
		if e.is_action_pressed("ui_left"): d = -1
		elif e.is_action_pressed("ui_right"): d = 1
		if d != 0:
			pick = posmod(pick + d, Flow.roster().size()); fb.text = _fighter_text(); flow.sfx.play("ui_move"); fb.accept_event())
	_col.add_child(fb)
	_col.add_child(flow._button("HOST A MATCH", _host))
	_col.add_child(flow._button("JOIN A MATCH", _join_form))
	_col.add_child(flow._button("BACK", func(): flow._goto("menu")))
	fb.call_deferred("grab_focus")
	var how := "ROOM CODES  -  %s" % ("BROWSER TO BROWSER" if OS.has_feature("web") else "SAME NETWORK OR FORWARDED UDP PORT %d" % UdpTransport.DEFAULT_PORT)
	var hint := flow._label(how, 22, Flow.BRASS, 4); hint.position = Vector2(100, 660); hint.set_meta("lobby", true); add_child(hint)

func _transport(host: bool, code := "") -> NetTransport:
	if OS.has_feature("web"):
		var url := NetConfig.signal_url()
		if url == "":
			_fail("NO SIGNALLING SERVER SET FOR THIS BUILD"); return null
		var r := RtcTransport.new(url)
		if host: r.host()
		else: r.join(code)
		_rtc = r
		return r
	var u := UdpTransport.new()
	if host:
		if u.host() != OK: _fail(u.error.to_upper()); return null
	else:
		var a := RoomCode.decode_addr(code)
		var ip := String(a.get("ip", ""))
		var port: int = int(a.get("port", UdpTransport.DEFAULT_PORT))
		if a.is_empty():                                  # also accept a plain "192.168.1.20" or "192.168.1.20:7777"
			var parts := code.strip_edges().split(":")
			ip = parts[0]
			if parts.size() > 1: port = int(parts[1])
			if not ip.is_valid_ip_address(): _fail("THAT CODE LOOKS WRONG"); return null
		if u.join(ip, port) != OK: _fail("THAT CODE LOOKS WRONG"); return null
	return u

func _fail(msg: String) -> void:
	if phase == "menu": return
	phase = "error"
	_clear(); _title()
	var m := flow._label(msg, 36, Flow.RED, 6); m.position = Vector2(100, 220); m.set_meta("lobby", true); add_child(m)
	var back := flow._button("BACK", _menu); _col.position = Vector2(100, 330); _col.add_child(back)
	back.call_deferred("grab_focus")

func _host() -> void:
	phase = "hosting"
	var tr := _transport(true)
	if tr == null: return
	tr.sim_latency_ms = NetConfig.sim_latency()
	link = NetLink.new(tr, true, String(Flow.roster()[pick].id), flow.stage_id)
	_waiting_screen("WAITING FOR AN OPPONENT")

func _join_form() -> void:
	phase = "joining"; _close_link()
	_clear(); _title()
	var prompt := flow._label("ENTER THE ROOM CODE", 40, Flow.STEAM, 6); prompt.position = Vector2(100, 190); prompt.set_meta("lobby", true); add_child(prompt)
	_edit = LineEdit.new(); _edit.position = Vector2(100, 260); _edit.size = Vector2(520, 76)
	_edit.add_theme_font_override("font", Flow.FONT); _edit.add_theme_font_size_override("font_size", 52)
	_edit.add_theme_color_override("font_color", Flow.STEAM); _edit.add_theme_color_override("caret_color", Flow.RED)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(Flow.INK, 0.7); sb.border_width_bottom = 6; sb.border_color = Flow.RED
	sb.content_margin_left = 18
	_edit.add_theme_stylebox_override("normal", sb); _edit.add_theme_stylebox_override("focus", sb)
	_edit.max_length = 21
	_edit.placeholder_text = "ABCD" if OS.has_feature("web") else "ABCDE-FGHIJ"
	_edit.text_submitted.connect(func(_t: String): _connect())
	add_child(_edit)
	_col = flow._column(100, 360); add_child(_col)
	_col.add_child(flow._button("CONNECT", _connect))
	_col.add_child(flow._button("BACK", _menu))
	_edit.call_deferred("grab_focus")

func _connect() -> void:
	var code := _edit.text.strip_edges()
	if code == "": return
	var tr := _transport(false, code)
	if tr == null: return
	tr.sim_latency_ms = NetConfig.sim_latency()
	link = NetLink.new(tr, false, String(Flow.roster()[pick].id))
	_waiting_screen("CONNECTING")

func _waiting_screen(text: String) -> void:
	_age = 0.0
	_clear(); _title()
	if _edit: _edit.queue_free(); _edit = null
	_status = flow._label(text, 44, Flow.STEAM, 6); _status.position = Vector2(100, 400); add_child(_status)
	_status.set_meta("lobby", true)
	if phase == "hosting":
		var cap := flow._label("YOUR ROOM CODE", 30, Flow.BRASS, 5); cap.position = Vector2(100, 190); cap.set_meta("lobby", true); add_child(cap)
		_code = flow._label("...", 130, Flow.RED, 10); _code.position = Vector2(100, 220); _code.set_meta("lobby", true); add_child(_code)
		_update_code()
	var tw := _status.create_tween().set_loops()
	tw.tween_property(_status, "modulate:a", 0.35, 0.7); tw.tween_property(_status, "modulate:a", 1.0, 0.7)
	_col = flow._column(100, 520); add_child(_col)
	var cancel := flow._button("CANCEL", _menu); _col.add_child(cancel)
	cancel.call_deferred("grab_focus")

func _update_code() -> void:
	if _code == null: return
	if OS.has_feature("web"):
		_code.text = _rtc.code if _rtc != null and _rtc.code != "" else "..."
	else:
		var ip := RoomCode.local_ip()
		_code.text = RoomCode.encode_addr(ip, UdpTransport.DEFAULT_PORT) if ip != "" else "NO NETWORK"
		_code.add_theme_font_size_override("font_size", 100)

func _close_link() -> void:
	if link != null: link.close()
	link = null; _rtc = null; _code = null; _status = null

func _process(dt: float) -> void:
	if link == null or _handed: return
	link.poll(dt)
	_age += dt
	if phase == "hosting": _update_code()
	if link.transport.error != "" and link.state != "ready":
		var msg := link.transport.error.to_upper()
		_close_link(); _fail(msg); return
	if link.state == "ready":
		_handed = true
		if _status: _status.text = "OPPONENT FOUND"
		flow.start_online(link)
		return
	if phase == "joining" and _age > 25.0:
		_close_link(); _fail("NO RESPONSE FROM THAT ROOM")

func _exit_tree() -> void:
	if not _handed: _close_link()
