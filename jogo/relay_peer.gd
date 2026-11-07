extends MultiplayerPeerExtension
# "Cabo" do multiplayer da Godot que passa pelo servidor de encontro (WebSocket).
# O servidor só repassa os pacotes entre os dois celulares; as RPCs do jogo continuam iguais.

var ws: WebSocketPeer
var my_id := 0
var other := 0
var others: Array = []
var target := 0
var status := MultiplayerPeer.CONNECTION_DISCONNECTED
var inbox: Array = []
var cur_from := 0
var tmode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var tchan := 0


func setup(w: WebSocketPeer, id: int, all_ids: Array = []) -> void:
	ws = w
	my_id = id
	other = 2 if id == 1 else 1
	others = []
	for p in all_ids:
		if int(p) != id:
			others.append(int(p))
	if others.is_empty():
		others = [other]
	status = MultiplayerPeer.CONNECTION_CONNECTED


func announce() -> void:
	for p in others:
		peer_connected.emit(p)


func peer_gone(p: int) -> void:
	if others.has(p):
		others.erase(p)
		peer_disconnected.emit(p)


func push(from: int, data: PackedByteArray) -> void:
	inbox.append([from, data])


func lost() -> void:
	if status == MultiplayerPeer.CONNECTION_CONNECTED:
		status = MultiplayerPeer.CONNECTION_DISCONNECTED
		for p in others:
			peer_disconnected.emit(p)
		others = []


func _get_available_packet_count() -> int:
	return inbox.size()


func _get_max_packet_size() -> int:
	return 1 << 20


func _get_packet_script() -> PackedByteArray:
	if inbox.is_empty():
		return PackedByteArray()
	var p: Array = inbox.pop_front()
	cur_from = int(p[0])
	return p[1]


func _put_packet_script(buf: PackedByteArray) -> Error:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNAVAILABLE
	var dests: Array = []
	if target == 0:
		dests = [0]
	elif target > 0:
		dests = [target]
	else:
		for p in others:
			if p != -target:
				dests.append(p)
	for d in dests:
		var out := PackedByteArray([d])
		out.append_array(buf)
		ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)
	return OK


func _get_packet_channel() -> int:
	return 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _set_transfer_channel(c: int) -> void:
	tchan = c


func _get_transfer_channel() -> int:
	return tchan


func _set_transfer_mode(m: MultiplayerPeer.TransferMode) -> void:
	tmode = m


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return tmode


func _set_target_peer(p: int) -> void:
	target = p


func _get_packet_peer() -> int:
	# a Godot pergunta quem mandou ANTES de ler o pacote
	if not inbox.is_empty():
		return int(inbox[0][0])
	return cur_from


func _is_server() -> bool:
	return my_id == 1


func _poll() -> void:
	pass


func _close() -> void:
	status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _disconnect_peer(_p: int, _force: bool) -> void:
	lost()


func _get_unique_id() -> int:
	return my_id


func _set_refuse_new_connections(_b: bool) -> void:
	pass


func _is_refusing_new_connections() -> bool:
	return false


func _is_server_relay_supported() -> bool:
	return false


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return status
