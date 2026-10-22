class_name UdpTransport
extends NetTransport
## Direct UDP between two machines (desktop and Android; browsers cannot open UDP, they use RtcTransport).
## The host binds a port and learns the guest's address from its first packet; the guest sends to the host's address.

const DEFAULT_PORT := 7777

var udp := PacketPeerUDP.new()
var is_host := false
var port := DEFAULT_PORT

func host(listen_port := DEFAULT_PORT) -> int:
	is_host = true; port = listen_port
	var err := udp.bind(listen_port)
	if err != OK: error = "port %d is in use" % listen_port
	return err

func join(ip: String, remote_port := DEFAULT_PORT) -> int:
	is_host = false
	var err := udp.set_dest_address(ip, remote_port)
	if err != OK: error = "bad address"
	else: connected = true
	return err

func _raw_send(b: PackedByteArray) -> void:
	if connected: udp.put_packet(b)

func _raw_poll() -> void:
	while udp.get_available_packet_count() > 0:
		var pkt := udp.get_packet()
		if is_host and not connected:
			udp.set_dest_address(udp.get_packet_ip(), udp.get_packet_port())
			connected = true
		_in.append(pkt)

func close() -> void:
	udp.close()
