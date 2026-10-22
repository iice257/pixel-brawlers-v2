extends GutTest
## Room codes, the touch stick, and the ONLINE lobby: hosting through the menu and being joined by a second link starts an online fight.

func test_direct_code_round_trip() -> void:
	for t in [["192.168.1.20", 7777], ["10.0.0.5", 65535], ["172.16.254.1", 1], ["8.8.4.4", 7801]]:
		var code := RoomCode.encode_addr(t[0], t[1])
		assert_eq(code.length(), 11, "5 + dash + 5")
		var d := RoomCode.decode_addr(code.to_lower())
		assert_eq(d.ip, t[0]); assert_eq(d.port, t[1])
	assert_true(RoomCode.decode_addr("ABCD").is_empty(), "a relay code is not a direct code")
	assert_true(RoomCode.decode_addr("0OIL1-ZZZZZ").is_empty(), "bad symbols rejected")

func test_touch_stick_directions() -> void:
	var t := TouchControls.new(); add_child_autofree(t)
	t._down(1, Vector2(200, 500))
	t._drag(1, Vector2(200 + 60, 500))
	assert_true(t.stick_dirs().right); assert_false(t.stick_dirs().left)
	t._drag(1, Vector2(200, 500 - 60))
	assert_true(t.stick_dirs().up)
	t._up(1)
	assert_false(t.stick_dirs().up)
	t._down(2, TouchControls.BUTTONS[0].pos)
	t._sync()
	assert_true(Input.is_action_pressed("p1_light"))
	t._up(2); t._sync()
	assert_false(Input.is_action_pressed("p1_light"))

func test_hosting_from_the_menu_starts_an_online_fight() -> void:
	var f: Flow = load("res://ui/flow.tscn").instantiate()
	add_child_autofree(f)
	await wait_seconds(0.5)
	f._show("online")
	await wait_process_frames(2)
	var lobby: OnlineLobby = f.screen
	assert_true(lobby is OnlineLobby)
	lobby._host()
	await wait_process_frames(2)
	assert_eq(lobby.phase, "hosting")
	var code: String = lobby._code.text
	assert_true(RoomCode.is_direct(code), "host shows a direct code: " + code)
	var guest_t := UdpTransport.new()
	assert_eq(guest_t.join("127.0.0.1", UdpTransport.DEFAULT_PORT), OK)
	var guest := NetLink.new(guest_t, false, "briggs")
	var t := 0.0
	while t < 6.0 and f.fight == null:
		guest.poll(1.0 / 60.0)
		await wait_process_frames(1)
		t += get_process_delta_time()
	assert_not_null(f.fight, "fight instanced after the handshake")
	if f.fight:
		assert_eq(f.fight.cfg.mode, "online")
		assert_eq(String(f.fight.cfg.fighters[1]), "briggs", "host sees the guest's pick")
	guest.close()

func test_supabase_channel_routes_broadcasts_to_the_right_role() -> void:
	var host := SignalSupabase.new("https://x.supabase.co", "k", true)
	host._topic = "realtime:redline-ABCD"
	host._on_text(JSON.stringify({ "topic": "realtime:redline-ABCD", "event": "phx_reply", "payload": { "status": "ok" }, "ref": "1" }))
	assert_eq(host.status, "ready")
	host._on_text(JSON.stringify({ "topic": "realtime:redline-ABCD", "event": "broadcast", "payload": { "type": "broadcast", "event": "sig", "payload": { "t": "hello", "to": "host" } } }))
	host._on_text(JSON.stringify({ "topic": "realtime:redline-ABCD", "event": "broadcast", "payload": { "type": "broadcast", "event": "sig", "payload": { "t": "sdp", "to": "guest" } } }))
	host._on_text(JSON.stringify({ "topic": "realtime:redline-OTHER", "event": "broadcast", "payload": { "type": "broadcast", "event": "sig", "payload": { "t": "hello", "to": "host" } } }))
	var got := host.take()
	assert_eq(got.size(), 1, "only the message addressed to the host on this topic")
	assert_eq(got[0].t, "hello")

func test_signalling_backend_is_chosen_from_config() -> void:
	var ch := NetConfig.make_signal(true)
	assert_true(ch is SignalSupabase, "data/net.json selects the Supabase Realtime channel")
