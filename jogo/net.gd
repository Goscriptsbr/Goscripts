extends Node
# Multiplayer online (rede local / IP) usando ENet da Godot.
# O anfitrião (assento 0) é a autoridade: resolve as regras e manda o estado final da mesa.

const PORT := 24680
var game: Node2D
var peer: ENetMultiplayerPeer
var is_host := false
var active := false
var joined := false
var snaps := 0
# busca automática na rede local (broadcast UDP)
const DPORT := 24681
var disc: PacketPeerUDP
var searching := false
var my_id := 0
var beacon_t := 0.0
# internet: servidor de encontro no Render (fila, amigos e repasse)
# servidores em ordem: o novo (conta GoScripts) primeiro; se não responder, usa o antigo
const SERVERS := ["wss://sinucou.onrender.com", "wss://sinuca-goscripts.onrender.com"]
var srv_i := 0
var was_ok := false
const RelayPeer := preload("res://relay_peer.gd")
var ws: WebSocketPeer
var ws_state := -1
var hello_sent := false
var keep_online := false
var retry_t := 0.0
var retry_wait := 3.0
var server_ok := false
var relay: MultiplayerPeerExtension
var pending_queue := ""
var queued := false
var world_t := 0.0
var room_players: Array = []
var room_seats := 2
var my_peer := 1


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_gone)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	# fica conectado ao servidor desde que o jogo abre: assim os amigos já veem você ONLINE
	var args := OS.get_cmdline_user_args()
	keep_online = (DisplayServer.get_name() != "headless" and not args.has("--nosplash")) or args.has("--stayonline")
	if keep_online:
		get_tree().create_timer(1.0).timeout.connect(connect_server)


func local_ip() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		if a.begins_with("192.168."):
			return a
		if best == "" and (a.begins_with("10.") or a.begins_with("172.")):
			best = a
	return best


func code_for_ip(ip: String) -> String:
	var p := ip.split(".")
	if p.size() == 4 and ip.begins_with("192.168."):
		return "%05d" % (int(p[2]) * 256 + int(p[3]))
	return ""


func ip_for_code(code: String) -> String:
	var t := code.strip_edges()
	if t.contains("."):
		return t
	if not t.is_valid_int():
		return ""
	var n := int(t)
	if n < 0 or n > 65535:
		return ""
	return "192.168.%d.%d" % [n / 256, n % 256]


func start_host(keep_search: bool = false) -> bool:
	if not keep_search:
		stop_search()
	close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	active = true
	return true


func start_join(addr: String, keep_search: bool = false) -> bool:
	if not keep_search:
		stop_search()
	close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, PORT)
	if err != OK:
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	active = true
	return true


func start_search() -> void:
	close()
	stop_search()
	my_id = randi() % 1000000000 + 1
	disc = PacketPeerUDP.new()
	if disc.bind(DPORT) != OK:
		if disc.bind(DPORT + 1) != OK:
			_status("Não consegui procurar na rede. Use o código abaixo.")
			disc = null
			return
	disc.set_broadcast_enabled(true)
	searching = true
	beacon_t = 1.0
	_status("Procurando oponente na rede local...")


func stop_search() -> void:
	searching = false
	if disc != null:
		disc.close()
	disc = null


func _beacon() -> void:
	var msg := ("SINUCA1|%d|%s|%s" % [my_id, "H" if is_host else "S", game.net_game]).to_utf8_buffer()
	for dest in ["255.255.255.255", "127.0.0.1"]:
		for p in [DPORT, DPORT + 1]:
			disc.set_dest_address(dest, p)
			disc.put_packet(msg)


func server_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server="):
			return a.substr(9)
	var s := str(game.save.get("server", ""))
	var lst: Array = SERVERS
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("--servers="):
			lst = a2.substr(10).split(",")
	return s if s != "" else str(lst[srv_i % lst.size()])


func connect_server() -> void:
	if ws != null and (ws.get_ready_state() == WebSocketPeer.STATE_OPEN or ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING):
		return
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	hello_sent = false
	server_ok = false
	was_ok = false
	world_t = 0.0
	ws.connect_to_url(server_url())


func send_hello() -> void:
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify({"t": "hello", "code": game.my_code(), "name": game.my_name()}))


func world_send(d: Dictionary) -> void:
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and server_ok:
		ws.send_text(JSON.stringify(d))


func world_search(g: String) -> void:
	if game.net_team and not g.ends_with("4"):
		g += "4"
	close()
	stop_search()
	pending_queue = g
	queued = false
	connect_server()
	_status("Conectando ao servidor... (se estiver dormindo, pode levar até 1 minuto)")
	if server_ok:
		_send_queue()


func world_cancel() -> void:
	pending_queue = ""
	if queued:
		world_send({"t": "unqueue"})
	queued = false


func _send_queue() -> void:
	if pending_queue == "":
		return
	world_send({"t": "queue", "game": pending_queue})
	queued = true
	_status("Procurando mesa 2x2 (se demorar, a IA completa)..." if game.net_team else "Procurando oponente no mundo todo...")


func _world_poll(delta: float) -> void:
	if keep_online:
		var down: bool = ws == null or ws.get_ready_state() == WebSocketPeer.STATE_CLOSED
		if down:
			retry_t += delta
			if retry_t >= retry_wait:
				retry_t = 0.0
				retry_wait = minf(retry_wait * 1.6, 30.0)
				connect_server()
		elif server_ok:
			retry_wait = 3.0
	if ws == null:
		return
	ws.poll()
	var stt := ws.get_ready_state()
	if stt == WebSocketPeer.STATE_OPEN and not hello_sent:
		hello_sent = true
		ws.send_text(JSON.stringify({"t": "hello", "code": game.my_code(), "name": game.my_name()}))
	if stt == WebSocketPeer.STATE_CONNECTING:
		world_t += delta
	while stt == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
		var pk := ws.get_packet()
		if ws.was_string_packet():
			var m = JSON.parse_string(pk.get_string_from_utf8())
			if m is Dictionary:
				_world_msg(m)
		elif relay != null and pk.size() >= 1:
			relay.push(int(pk[0]), pk.slice(1))
	if stt == WebSocketPeer.STATE_CLOSED and ws_state != WebSocketPeer.STATE_CLOSED:
		if not was_ok:
			# nem chegou a conectar: tenta o próximo servidor da lista logo em seguida
			srv_i = (srv_i + 1) % SERVERS.size()
			retry_t = retry_wait
		server_ok = false
		queued = false
		if relay != null:
			relay.lost()
			relay = null
			if active:
				active = false
				game.net_lost()
		elif pending_queue != "":
			_status("Sem conexão com o servidor. Toque em PROCURAR para tentar de novo.")
			pending_queue = ""
		if game.ui != null:
			game.ui.friends_offline()
			game.ui.lobby_update({"members": [], "leader": "", "msg": ""})
	ws_state = stt


func _world_msg(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"welcome":
			server_ok = true
			was_ok = true
			if game.ui != null and m.has("app"):
				game.ui.check_update(m.app)
			# reenvia pedidos de amizade pendentes (o servidor não guarda nada)
			for o in game.save.get("f_out", []):
				world_send({"t": "fsend", "kind": "req", "to": str(o.code)})
			if pending_queue != "":
				_send_queue()
			if game.ui != null:
				game.ui.friends_refresh()
		"match":
			queued = false
			pending_queue = ""
			stop_search()
			if peer != null:
				peer.close()
				peer = null
			relay = RelayPeer.new()
			var pl: Array = m.get("players", [])
			var ids := []
			for p in pl:
				ids.append(int(p.peer))
			relay.setup(ws, int(m.peer), ids)
			is_host = str(m.role) == "host"
			room_players = pl
			room_seats = int(m.get("seats", 2))
			my_peer = int(m.peer)
			active = true
			joined = false
			game.net_game = str(m.get("game", game.net_game)).trim_suffix("4")
			var opp: Dictionary = m.get("opp", {})
			game.net_peer_name = str(opp.get("name", "Adversário"))
			multiplayer.multiplayer_peer = relay
			_status("Oponente encontrado: %s! Conectando..." % game.net_peer_name)
			relay.announce()
			if room_seats == 4:
				game.net_start4(is_host, room_players, my_peer)
		"waiting":
			if game.ui != null:
				game.ui.online_wait(int(m.get("have", 1)), int(m.get("need", 4)), int(m.get("left", -1)))
		"peer_left":
			if not bool(m.get("end", true)) and relay != null:
				relay.peer_gone(int(m.get("peer", 0)))
				game.net_peer_dropped(int(m.get("peer", 0)))
				return
			if relay != null:
				relay.lost()
				relay = null
				multiplayer.multiplayer_peer = null
			if active:
				active = false
				joined = false
				game.net_lost()
		"search":
			if game.ui != null:
				game.ui.search_results(str(m.get("q", "")), m.get("list", []))
		"fmsg":
			if game.ui != null:
				game.ui.friend_msg(str(m.get("kind", "")), str(m.get("from", "")), str(m.get("name", "")))
		"fsent":
			if game.ui != null and str(m.get("kind", "")) == "req" and not bool(m.get("delivered", false)):
				game.ui.friend_sent_offline(str(m.get("to", "")))
		"presence":
			if game.ui != null:
				game.ui.friends_update(m.get("list", []))
		"invited":
			if game.ui != null:
				game.ui.show_invite(str(m.get("from", "")), str(m.get("name", "")), str(m.get("game", "sinuca")), bool(m.get("lobby", false)))
		"invite_ok":
			if game.ui != null:
				if bool(m.get("lobby", false)):
					game.ui.say("Convite enviado para %s! Quando aceitar, ele entra no seu lobby." % str(m.get("name", "")))
				else:
					game.ui.say("Convite enviado para %s! Esperando aceitar..." % str(m.get("name", "")))
		"lobby":
			if game.ui != null:
				game.ui.lobby_update(m)
		"pm":
			if game.ui != null:
				game.ui.got_pm(str(m.get("from", "")), str(m.get("name", "")), str(m.get("txt", "")).left(120), int(m.get("ts", 0)))
		"invite_fail":
			if game.ui != null:
				game.ui.say(str(m.get("msg", "Convite não deu certo")))


func _process(delta: float) -> void:
	_world_poll(delta)
	if not searching or disc == null:
		return
	beacon_t += delta
	if beacon_t > 0.4:
		beacon_t = 0.0
		_beacon()
	while disc.get_available_packet_count() > 0:
		var pk := disc.get_packet()
		var ip := disc.get_packet_ip()
		var parts := pk.get_string_from_utf8().split("|")
		if parts.size() != 4 or parts[0] != "SINUCA1" or parts[3] != game.net_game:
			continue
		var oid := int(parts[1])
		if oid == my_id or oid <= 0:
			continue
		if my_id < oid:
			if not active:
				if start_host(true):
					_status("Oponente encontrado! Conectando...")
		elif parts[2] == "H" and not active:
			if start_join(ip, true):
				_status("Oponente encontrado! Conectando...")


func close() -> void:
	if relay != null:
		world_send({"t": "leave"})
		relay = null
	world_cancel()
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	active = false
	joined = false
	is_host = false


func _status(t: String) -> void:
	if game != null and game.ui != null:
		game.ui.online_status(t)


func _on_peer_connected(_id: int) -> void:
	if is_host and active and not joined:
		_status("Adversário conectado! Começando...")


func _on_peer_gone(_id: int) -> void:
	if room_seats == 4 and relay != null:
		return
	if is_host and active:
		joined = false
		game.net_lost()


func _on_connected() -> void:
	stop_search()
	_status("Conectado! Aguardando o anfitrião iniciar...")
	r_hello.rpc_id(1, {"cue": str(game.save.cue), "name": game.my_name(), "game": game.net_game})


func _on_failed() -> void:
	close()
	if searching:
		_status("Procurando oponente na rede local...")
		return
	_status("Não consegui conectar. Confira o código/IP e se os dois estão no mesmo Wi-Fi.")


func _on_server_gone() -> void:
	close()
	game.net_lost()


# ---------------------------------------------------------------- envio
func send_start(snap: Dictionary) -> void:
	r_start.rpc(snap)


func send_state(snap: Dictionary) -> void:
	snaps += 1
	r_state.rpc(snap)


func send_shot(d: Dictionary) -> void:
	r_shot.rpc(d)


func send_tstate(d: Dictionary) -> void:
	r_tstate.rpc(d)


# ---- chat e voz da partida (vai para todos os outros da mesa)
func send_chat(txt: String) -> void:
	if multiplayer.multiplayer_peer != null and active:
		r_chat.rpc(txt)


func send_voice(data: PackedByteArray) -> void:
	if multiplayer.multiplayer_peer != null and active:
		r_voice.rpc(data)


@rpc("any_peer", "call_remote", "reliable")
func r_chat(txt: String) -> void:
	if game.chat != null:
		game.chat.add(multiplayer.get_remote_sender_id(), str(txt).left(40), false)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func r_voice(data: PackedByteArray) -> void:
	if game.chat != null and data.size() <= 4000:
		game.chat.got_voice(multiplayer.get_remote_sender_id(), data)


var tbytes := 0
var tsends := 0


func send_tstate_to(peer_id: int, d: Dictionary) -> void:
	if game.net_auto:
		tbytes += var_to_bytes(d).size()
		tsends += 1
	r_tstate.rpc_id(peer_id, d)


func send_tact(d: Dictionary) -> void:
	r_tact.rpc_id(1, d)


func send_tstart(d: Dictionary) -> void:
	r_tstart.rpc(d)


@rpc("any_peer", "call_remote", "reliable")
func r_tstart(d: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	game.ui.open_truco_net("guest", {})


@rpc("any_peer", "call_remote", "reliable")
func r_tstate(d: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var tn = game.ui.truco_node
	if tn != null and is_instance_valid(tn):
		tn.apply_snapshot(d)


@rpc("any_peer", "call_remote", "reliable")
func r_tact(d: Dictionary) -> void:
	if not is_host:
		return
	var tn = game.ui.truco_node
	if tn != null and is_instance_valid(tn):
		tn.net_action(d, multiplayer.get_remote_sender_id())


func send_aim(d: Dictionary) -> void:
	r_aim.rpc(d)


# ---------------------------------------------------------------- recepção
@rpc("any_peer", "call_remote", "reliable")
func r_hello(d: Dictionary) -> void:
	if is_host and active and room_seats == 4:
		game.net_hello4(multiplayer.get_remote_sender_id(), d)
		return
	if not is_host or not active or joined:
		return
	if str(d.get("game", "sinuca")) != game.net_game:
		return
	joined = true
	stop_search()
	game.net_peer_cue = game.cue_by_id(str(d.get("cue", "classico"))).id
	game.net_peer_name = str(d.get("name", "Adversário")).strip_edges().left(16)
	if game.net_peer_name == "":
		game.net_peer_name = "Adversário"
	game.net_start_match()

@rpc("any_peer", "call_remote", "reliable")
func r_start(snap: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	game.net_client_start(snap)


@rpc("any_peer", "call_remote", "reliable")
func r_state(snap: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	snaps += 1
	game.net_receive_state(snap)


@rpc("any_peer", "call_remote", "reliable")
func r_shot(d: Dictionary) -> void:
	game.net_remote_shot(d)


@rpc("any_peer", "call_remote", "unreliable")
func r_aim(d: Dictionary) -> void:
	game.net_remote_aim(d)
