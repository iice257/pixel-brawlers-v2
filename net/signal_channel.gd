class_name SignalChannel
extends RefCounted
## How two peers exchange WebRTC setup messages (offer, answer, ICE) before the direct channel opens. Two backends: SignalHttp (tools/signal_server.py)
## and SignalSupabase (a Supabase Realtime broadcast channel). Picked by data/net.json "signal_type", see NetConfig.make_signal().

var is_host := false
var code := ""            # room code, set once the room exists (host) or at join (guest)
var error := ""
var status := "idle"      # idle | reserving | ready | failed
var inbox: Array = []     # received message dictionaries, drained by take()

func open_room() -> void: pass                        # host: reserve a room, sets code
func join_room(_room: String) -> void: pass           # guest
func send(_m: Dictionary) -> void: pass               # to the other side
func poll() -> void: pass                             # called every tick
func close() -> void: pass

func take() -> Array:
	var a := inbox; inbox = []
	return a
