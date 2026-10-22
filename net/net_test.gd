extends Node
## Headless end-to-end netplay check: one process per player over real UDP on localhost, CPU brains playing, optional simulated latency.
## godot --headless --path . res://net/net_test.tscn -- --role=host|guest --port=7801 --pick=kestrel --latency=100 [--loss=0.02] [--tier=7]
## Prints one RESULT line when the match ends; tools/net_selftest.sh runs a pair and compares the lines.

var link: NetLink
var session: RollbackSession
var brain: CpuBrain
var is_host := true
var latency := 0
var tier := 7
var _t := 0
var _t0 := 0
var _logged := false

func _ready() -> void:
	var role := "host"; var port := UdpTransport.DEFAULT_PORT; var pick := "kestrel"; var loss := 0.0
	var ip := "127.0.0.1"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): role = a.trim_prefix("--role=")
		elif a.begins_with("--port="): port = int(a.trim_prefix("--port="))
		elif a.begins_with("--pick="): pick = a.trim_prefix("--pick=")
		elif a.begins_with("--latency="): latency = int(a.trim_prefix("--latency="))
		elif a.begins_with("--loss="): loss = float(a.trim_prefix("--loss="))
		elif a.begins_with("--tier="): tier = int(a.trim_prefix("--tier="))
		elif a.begins_with("--ip="): ip = a.trim_prefix("--ip=")
	is_host = role == "host"
	var tr := UdpTransport.new()
	tr.sim_latency_ms = latency; tr.sim_loss = loss
	if is_host: tr.host(port)
	else: tr.join(ip, port)
	link = NetLink.new(tr, is_host, pick)
	_t0 = Time.get_ticks_msec()

func _physics_process(dt: float) -> void:
	link.poll(dt)
	if Time.get_ticks_msec() - _t0 > 120000:
		print("RESULT role=%s FAIL timeout state=%s" % [role(), link.state]); get_tree().quit(2); return
	if link.state != "ready": return
	if session == null:
		var m := MatchSim.new(link.info.fighters[0], link.info.fighters[1], int(link.info.seed), 3)
		session = RollbackSession.new(m, link.local_index())
		link.bind_session(session)
		brain = CpuBrain.new(tier, link.local_index(), 5 + link.local_index())
		print("START role=%s fighters=%s seed=%d" % [role(), str(link.info.fighters), int(link.info.seed)])
	var inp := brain.think(session.sim.world.fighters) if session.sim.inputs_live() else WorldSim.neutral()
	session.advance(inp)
	link.poll(0.0)                 # flush this tick's packets
	_t += 1
	if session.desync or session.is_disconnected() or session.sim.phase == "over":
		if _logged: return
		_logged = true
		var s := session.sim
		print("RESULT role=%s desync=%s disconnected=%s phase=%s wins=%s winner=%d hp=%d,%d frames=%d rollbacks=%d depth=%d stalls=%d latency=%d" % [
			role(), session.desync, session.is_disconnected(), s.phase, str(s.wins), s.match_winner,
			s.world.fighters[0].hp, s.world.fighters[1].hp, session.frame, session.rollbacks, session.max_depth, session.stall_frames, latency])
		# keep answering for a moment so the peer can finish its last frames, then leave
		await get_tree().create_timer(1.5).timeout
		get_tree().quit(1 if session.desync else 0)

func role() -> String:
	return "host" if is_host else "guest"
