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
# um servidor só: com o servidor antigo de reserva, quando a Render estava "dormindo" uma pessoa caía num
# servidor e a outra no outro, e ninguém se encontrava online
const SERVERS := ["wss://sinucou.onrender.com"]
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
		ws.send_text(JSON.stringify({"t": "hello", "code": game.my_code(), "name": game.my_name(), "coins": int(game.save.coins), "felt": game.my_felt_tag(), "wfx": game.my_wfx(), "blk": game.safety.blocked_codes() if game.safety != null else [], "sig": app_sig(), "store": OS.has_feature("store"), "rule": str(game.save.get("rule", "classic"))}))


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
	var stk := int(game.save.get("bet_on", 0))
	world_send({"t": "queue", "game": pending_queue, "stake": stk, "coins": int(game.save.coins)})
	queued = true
	var vt := "" if stk <= 0 else "  •  valendo %d moedas" % stk
	_status(("Procurando mesa 2x2 (se demorar, a IA completa)..." if game.net_team else "Procurando oponente no mundo todo...") + vt)


var coins_sent := -1
var look_sent := ""


# ---------------------------------------------------------------- moedas no servidor
var eco_dirty := true
var eco_t := 99.0


func send_eco() -> void:
	if ws == null or not server_ok:
		return
	var q: Array = game.save.get("eco_q", [])
	var m := {"t": "eco", "tok": game.my_tok(), "txs": q}
	if not bool(game.save.get("eco_ok", false)):
		# primeira vez na versão nova: leva o saldo que estava no celular (uma vez só)
		var pc := 0
		var pg := 0
		for tx in q:
			pc += int(tx.c)
			pg += int(tx.g)
		m["init"] = {"coins": int(game.save.coins) - pc, "grana": int(game.save.get("grana", 0)) - pg}
	else:
		# segurança: se o servidor perder os dados, ele recomeça do último saldo que ELE confirmou
		m["init"] = {"coins": int(game.save.get("eco_srv_c", 0)), "grana": int(game.save.get("eco_srv_g", 0))}
	world_send(m)
	eco_dirty = false
	eco_t = 0.0


func eco_tick(delta: float) -> void:
	eco_t += delta
	if server_ok and eco_dirty and eco_t >= 1.0:
		send_eco()


# ---------------------------------------------------------------- backup na nuvem
# o save do celular (moedas, itens, progresso) vai para o banco do jogo a cada 30s quando muda;
# com uma senha, dá para entrar na mesma conta em outro celular
var csave_dirty := true
var csave_t := 99.0
var cloud_ok := false
# conta Google
var glink_n := ""
var glink_mode := ""
var glink_t := 0.0
var glink_age := 0.0
var g_mail := ""
var g_on := false
var cloud_pass := false
var cloud_fail := false
var cloud_last := ""


func send_csave() -> void:
	if ws == null or not server_ok:
		return
	var s2: Dictionary = game.save.duplicate(true)
	for k in ["chats", "tok", "server", "eco_q", "eco_seq", "eco_ok", "eco_srv_c", "eco_srv_g"]:
		s2.erase(k)
	world_send({"t": "csave", "tok": game.my_tok(), "save": s2})
	csave_dirty = false
	csave_t = 0.0


func cloud_tick(delta: float) -> void:
	csave_t += delta
	if server_ok and csave_dirty and csave_t >= 30.0:
		send_csave()


func send_setpass(pw: String) -> void:
	var s2: Dictionary = game.save.duplicate(true)
	for k in ["chats", "tok", "server", "eco_q", "eco_seq", "eco_ok", "eco_srv_c", "eco_srv_g"]:
		s2.erase(k)
	world_send({"t": "setpass", "tok": game.my_tok(), "pass": pw, "save": s2})


const G_WEB_ID := "555286434372-qbsj13u6rl46fteg264r5lkpcc551b56.apps.googleusercontent.com"
var g_cid := ""
var g_native_mode := ""
var g_native_ok := true  # se o nativo falhar por configuração, usa o navegador


# assinatura do app (só a versão da Play tem o plugin que lê isso)
var _sig := "?"
func app_sig() -> String:
	if _sig == "?":
		_sig = ""
		if Engine.has_singleton("SinucouGoogle"):
			var sg = Engine.get_singleton("SinucouGoogle")
			# (has_method não enxerga os métodos do plugin Android: chama direto)
			var r = sg.call("sigHash")
			if r != null:
				_sig = str(r)
	return _sig


# regra de sinuca escolhida (salas com amigos e convites usam a regra de quem criou/convidou)
func send_rule() -> void:
	if server_ok:
		world_send({"t": "rule", "rule": str(game.save.get("rule", "classic"))})


# anti-trapaça: avisa o servidor (vai para a lista de denúncias do dono)
func send_cheat(code: String, why: String) -> void:
	if server_ok and code != "":
		world_send({"t": "cheat_flag", "code": code, "why": why})


func send_glink(mode: String) -> void:
	connect_server()
	if mode == "link":
		send_csave()
	glink_n = ""
	g_native_mode = mode
	g_wait = 0.0
	g_busy = true
	# versão da Play Store: janelinha do Google dentro do jogo (sem navegador)
	if g_native_ok and Engine.has_singleton("SinucouGoogle"):
		var sg = Engine.get_singleton("SinucouGoogle")
		if not sg.is_connected("google_ok", _g_native_ok):
			# o Android avisa de outra thread: CONNECT_DEFERRED traz a resposta para o jogo com segurança
			sg.connect("google_ok", _g_native_ok, CONNECT_DEFERRED)
			sg.connect("google_fail", _g_native_fail, CONNECT_DEFERRED)
		sg.signIn(g_cid if g_cid != "" else G_WEB_ID)
		return
	_g_send({"t": "glink_start", "mode": mode, "tok": game.my_tok()})


# manda para o servidor; se ele ainda estiver acordando, guarda e manda assim que conectar
var g_pending: Dictionary = {}
var g_last_err := ""
var g_wait := 0.0
var g_busy := false
func _g_send(d: Dictionary) -> void:
	connect_server()
	if server_ok:
		world_send(d)
	else:
		g_pending = d
		if game.ui != null:
			game.ui.say("Conectando ao servidor... (pode levar até 1 minuto)")


func _g_watch(delta: float) -> void:
	if not g_pending.is_empty() and server_ok:
		world_send(g_pending)
		g_pending = {}
	if g_busy:
		g_wait += delta
		if g_wait > 75.0:
			g_busy = false
			g_pending = {}
			if game.ui != null:
				game.ui.say("O Google não respondeu. Confira a internet e tente de novo.", 5.0)


func _g_native_ok(id_token: String, _email: String) -> void:
	if game.ui != null:
		game.ui.say("Conferindo sua conta Google...")
	_g_send({"t": "glink_token", "mode": g_native_mode, "cred": id_token, "tok": game.my_tok()})


func _g_native_fail(kind: String, detail: String) -> void:
	print("google nativo: ", kind, " ", detail)
	# o Android às vezes devolve "cancelado" quando na verdade deu erro (ex.: "[16] Account reauth failed").
	# Só é cancelamento de verdade quando a mensagem diz que foi o usuário que fechou.
	var dl := detail.to_lower()
	if kind == "cancelado" and (dl.find("user") >= 0 or dl.find("usuário") >= 0) and dl.find("[16]") < 0 and dl.find("reauth") < 0:
		g_busy = false
		if game.ui != null:
			game.ui.say("Login com Google cancelado.")
		return
	# não deu na janelinha: tenta pelo navegador (e mostra o motivo, para sabermos o que foi)
	g_native_ok = false
	g_last_err = (kind + ": " + detail).left(140)
	# registra no servidor (aparece na lista de Denúncias do dono) para sabermos o motivo exato
	world_send({"t": "gdiag", "why": g_last_err, "v": game.APP_VERSION})
	if game.ui != null:
		game.ui.say("Abrindo o login do Google pelo navegador... (%s)" % detail.left(60), 6.0)
	_g_send({"t": "glink_start", "mode": g_native_mode, "tok": game.my_tok()})


func _glink_tick(delta: float) -> void:
	_g_watch(delta)
	if glink_n == "":
		return
	glink_age += delta
	glink_t += delta
	if glink_age > 900.0:
		glink_n = ""
		return
	if glink_t >= 2.0:
		glink_t = 0.0
		world_send({"t": "glink_poll", "n": glink_n})


func _glink_result(m: Dictionary) -> void:
	var st := str(m.get("st", ""))
	if st == "wait":
		return
	g_busy = false
	if st == "gone":
		glink_n = ""
		return
	if m.has("n") and str(m.n) != glink_n and glink_n != "":
		return
	glink_n = ""
	var ui = game.ui
	if ui == null:
		return
	match st:
		"linked":
			g_mail = str(m.get("msg", ""))
			ui.cloud_refresh()
			ui.confirm("GOOGLE CONECTADO ✓", "Sua conta do Sinucou agora está ligada ao Google %s.\nEm outro celular (ou na versão da Play Store), é só tocar em ENTRAR COM GOOGLE para trazer suas moedas, itens e progresso." % g_mail, "LEGAL!", func(): pass, "", Callable())
		"login":
			if str(m.get("code", "")) == game.my_code():
				ui.say("Esse Google já está ligado a ESTA conta.")
				return
			m["ok"] = true
			ui.cloud_recover_result(m)
		_:
			var msg := str(m.get("msg", "Não deu certo, tente de novo."))
			if msg.find("já está ligada a outro jogador") >= 0:
				# o Google já tem uma conta: em vez de erro, oferece entrar nela
				ui.close_modal()
				ui.confirm("VOCÊ JÁ TEM UMA CONTA!", "Esse Google já está ligado a uma conta do Sinucou.\nQuer ENTRAR nela? Suas moedas, itens e nível voltam.\n\n(Escolha o mesmo Google de novo na próxima tela.)", "ENTRAR NA MINHA CONTA", func(): send_glink("login"), "CANCELAR", Callable())
			else:
				ui.close_modal()
				ui.confirm("GOOGLE", msg, "OK", func(): pass, "", Callable())


func send_recover(code: String, pw: String) -> void:
	world_send({"t": "recover", "code": code.strip_edges().to_upper(), "pass": pw})


# troca de conta (depois de recuperar): reconecta com o código novo
func reconnect() -> void:
	if ws != null:
		ws.close()
	ws = null
	server_ok = false
	connect_server()


# o servidor confere se cada um tem moedas para a aposta
func send_coins() -> void:
	var c := int(game.save.coins)
	var lk: String = game.my_felt_tag() + "|" + str(game.my_wfx())
	if (c == coins_sent and lk == look_sent) or ws == null or not server_ok:
		return
	coins_sent = c
	look_sent = lk
	world_send({"t": "coins", "n": c, "felt": game.my_felt_tag(), "wfx": game.my_wfx()})


func send_score() -> void:
	if server_ok:
		var lg: Dictionary = game.league()
		world_send({"t": "score", "wk": int(lg.week), "pts": int(lg.pts)})


func send_profile() -> void:
	if server_ok:
		world_send({"t": "prof", "data": game.profile_data()})


func ask_rank() -> void:
	var codes := []
	for f in game.save.friends:
		codes.append(str(f.code))
	world_send({"t": "rank", "wk": game.week_id(), "codes": codes})


func ask_rematch() -> void:
	world_send({"t": "rematch", "coins": int(game.save.coins)})


func _world_poll(delta: float) -> void:
	if keep_online:
		var down: bool = ws == null or ws.get_ready_state() == WebSocketPeer.STATE_CLOSED
		if down:
			retry_t += delta
			if retry_t >= retry_wait:
				retry_t = 0.0
				retry_wait = minf(retry_wait * 1.6, 12.0)
				connect_server()
		elif server_ok:
			retry_wait = 3.0
	if ws == null:
		return
	ws.poll()
	var stt := ws.get_ready_state()
	if stt == WebSocketPeer.STATE_OPEN and not hello_sent:
		hello_sent = true
		ws.send_text(JSON.stringify({"t": "hello", "code": game.my_code(), "name": game.my_name(), "coins": int(game.save.coins), "felt": game.my_felt_tag(), "wfx": game.my_wfx(), "blk": game.safety.blocked_codes() if game.safety != null else [], "sig": app_sig(), "store": OS.has_feature("store"), "rule": str(game.save.get("rule", "classic"))}))
	if stt == WebSocketPeer.STATE_CONNECTING:
		world_t += delta
	cloud_tick(delta)
	eco_tick(delta)
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
			coins_sent = int(game.save.coins)
			look_sent = game.my_felt_tag() + "|" + game.my_wfx()
			send_score()
			send_profile()
			was_ok = true
			send_eco()
			send_csave()
			world_send({"t": "glink_info"})
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
			# aposta: as moedas saem agora; quem sair no meio perde, quem ganhar leva a mesa
			game.net_owner = int(m.get("owner", -1))
			game.net_rule = str(m.get("rule", "classic"))
			game.bet_begin(int(m.get("stake", 0)), true)
			game.match_stake = game.bet_cur
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
				var who := str(m.get("name", ""))
				if bool(m.get("host", false)) and who != "":
					game.net_lost("%s (quem criou a sala) saiu ou perdeu a conexão. Partida encerrada." % who)
				else:
					game.net_lost()
		"search":
			if game.ui != null:
				game.ui.search_results(str(m.get("q", "")), m.get("list", []))
		"fmsg":
			if game.safety != null and game.safety.is_blocked(str(m.get("from", ""))):
				return
			if game.ui != null:
				game.ui.friend_msg(str(m.get("kind", "")), str(m.get("from", "")), str(m.get("name", "")))
		"fsent":
			if game.ui != null and str(m.get("kind", "")) == "req" and not bool(m.get("delivered", false)):
				game.ui.friend_sent_offline(str(m.get("to", "")))
		"presence":
			if game.ui != null:
				game.ui.friends_update(m.get("list", []))
		"invited":
			if game.safety != null and game.safety.is_blocked(str(m.get("from", ""))):
				world_send({"t": "decline", "code": str(m.get("from", ""))})
				return
			if game.ui != null:
				game.ui.show_invite(str(m.get("from", "")), str(m.get("name", "")), str(m.get("game", "sinuca")), bool(m.get("lobby", false)), int(m.get("stake", 0)), bool(m.get("tour", false)), str(m.get("rule", "classic")))
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
			if game.safety != null and game.safety.is_blocked(str(m.get("from", ""))):
				return
			if game.ui != null:
				var ptxt := str(m.get("txt", "")).left(120)
				if game.safety != null:
					ptxt = game.safety.clean(ptxt)
					game.safety.log_chat(str(m.get("from", "")).to_upper(), ptxt)
				game.ui.got_pm(str(m.get("from", "")), str(m.get("name", "")), ptxt, int(m.get("ts", 0)))
		"invite_fail":
			if game.ui != null:
				game.ui.say(str(m.get("msg", "Convite não deu certo")))
		"qfail":
			pending_queue = ""
			queued = false
			if game.ui != null:
				game.ui.say(str(m.get("msg", "")))
				game.ui.online_status(str(m.get("msg", "")))
				game.ui._online_btn_refresh()
		"tour":
			game.tour_update(m)
		"eco_r":
			game.eco_result(m)
		"reports", "delete_r", "report_ok", "block_ok", "modded":
			if game.safety != null:
				game.safety.on_msg(m)
		"trade_invite", "trade_wait", "trade", "trade_end", "trade_done", "trade_chat", "trade_voice":
			if str(m.t) == "trade_invite" and game.safety != null and game.safety.is_blocked(str(m.get("from", ""))):
				world_send({"t": "trade_resp", "id": str(m.get("id", "")), "ok": false})
				return
			if game.trade != null:
				game.trade.on_msg(m)
		"gift_ok", "gift_fail", "gift":
			if game.gift != null:
				game.gift.on_msg(m)
		"toast":
			if game.ui != null:
				game.ui.say(str(m.get("msg", "")))
		"csave_ok":
			cloud_ok = bool(m.get("ok", false))
			cloud_pass = bool(m.get("pass", false)) or cloud_pass
			cloud_fail = false
			if cloud_ok:
				cloud_last = Time.get_time_string_from_system().substr(0, 5)
			if game.safety != null:
				game.safety.on_csave_ok(cloud_ok)
		"csave_fail":
			cloud_ok = false
			cloud_fail = true
			if game.safety != null:
				game.safety.on_csave_ok(false)
		"setpass_r":
			if bool(m.get("ok", false)):
				cloud_pass = true
			if game.ui != null:
				game.ui.say(str(m.get("msg", "")))
				game.ui.cloud_refresh()
		"recover_r":
			if game.ui != null:
				game.ui.cloud_recover_result(m)
		"glink_url":
			g_busy = false
			glink_n = str(m.get("n", ""))
			glink_mode = str(m.get("mode", ""))
			glink_age = 0.0
			glink_t = 0.0
			OS.shell_open(str(m.get("url", "")))
		"glink_r":
			_glink_result(m)
		"glink_info":
			g_mail = str(m.get("mail", ""))
			g_on = bool(m.get("on", false))
			g_cid = str(m.get("cid", ""))
			if game.ui != null:
				game.ui.cloud_refresh()
		"rank":
			if game.ui != null:
				game.ui.rank_update(m)
		"prof":
			if game.ui != null:
				game.ui.profile_remote(m)
		"rematch_req":
			if game.ui != null:
				game.ui.rematch_req(str(m.get("name", "Adversário")))
		"rematch_fail":
			if game.ui != null:
				game.ui.say(str(m.get("msg", "")))


func _process(delta: float) -> void:
	_world_poll(delta)
	_glink_tick(delta)
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
	d["_from"] = multiplayer.get_remote_sender_id()
	game.net_remote_shot(d)


@rpc("any_peer", "call_remote", "unreliable")
func r_aim(d: Dictionary) -> void:
	game.net_remote_aim(d)
