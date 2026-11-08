extends Control
# Truco Paulista (baralho de 40 cartas, vira e manilhas) contra a IA GoScripts.
# Modos: 1 contra 1, ou 2 contra 2 (você + parceiro IA contra duas IAs).

const RANKS := ["4", "5", "6", "7", "Q", "J", "K", "A", "2", "3"]
const SUIT_NAMES := ["Ouros", "Espadas", "Copas", "Paus"]
const STEP := {1: 3, 3: 6, 6: 9, 9: 12}
const CALL := {3: "TRUCO!", 6: "SEIS!", 9: "NOVE!", 12: "DOZE!"}

var game: Node2D
var ui: CanvasLayer
var n := 2
var hands: Array = []
var plays: Array = []           # jogadas da rodada atual: {seat, c, hid}
var last_plays: Array = []      # rodada anterior (mostrada pequena)
var results: Array = []         # por rodada: 0, 1 ou -1 (empate)
var vira: Dictionary = {}
var value := 1
var last_raiser := -1
var pending := 0
var asker := -1
var turn := 0
var starter := 0
var dealer := 0
var score := [0, 0]
var quedas := [0, 0]           # melhor de 3 quedas (cada queda vai até 12)
var seat_peer := {}             # online (anfitrião): assento -> peer
var peer_seat := {}
var nview := 0                   # online (convidado): meu assento no anfitrião
var phase := "idle"
var ferro := false
var onze := -1
var hidden_next := false
var bubbles: Array = []
var msg := ""
var msg_t := 0.0
var t := 0.0
var sim := false
var winner := -1
var busy := false
var face_tex := {}
# online: "" = contra IA, "host" = anfitrião (roda as regras), "guest" = convidado (só mostra e manda ações)
var netmode := ""
var names := ["Você", "Adversário"]
var snap_t := 0.0
var beat_t := 0.0
var bw_last := -1
var last_snap := ""
var last_snaps := {}
var bub_id := 0
var seen_bub := 0
var over_shown := false
var prompt_key := ""
var round_win := -2
var queda_win := -1
var auto_t := 0.0
var auto_done := false

var btn_truco: Button
var btn_enc: Button
var btn_exit: Button
var modal: PanelContainer
var modal_box: VBoxContainer


func setup(g: Node2D, players: int, simulate: bool = false, role: String = "", info: Dictionary = {}) -> void:
	game = g
	n = players
	sim = simulate
	netmode = role
	if role != "":
		names = info.get("names", [str(game.my_name()), "Adversário"])
		seat_peer = info.get("peers", {})
		for k in seat_peer.keys():
			peer_seat[int(seat_peer[k])] = int(k)
	if not sim:
		ui = g.ui
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_build_ui()
	score = [0, 0]
	quedas = [0, 0]
	dealer = randi() % n
	if netmode == "guest":
		phase = "wait"
		say("Conectado! Esperando o anfitrião dar as cartas...")
		return
	new_hand()


func is_remote(seat: int) -> bool:
	return netmode == "host" and seat_peer.has(seat)


func team_has_remote(tm: int) -> bool:
	for k in seat_peer.keys():
		if int(k) % 2 == tm:
			return true
	return false


func remote_of_team(tm: int) -> int:
	for k in seat_peer.keys():
		if int(k) % 2 == tm:
			return int(k)
	return -1


func seat_dropped(peer: int) -> void:
	# convidado saiu: o assento dele passa para a IA e o jogo continua
	if not peer_seat.has(peer):
		return
	var st: int = peer_seat[peer]
	peer_seat.erase(peer)
	seat_peer.erase(st)
	say("%s saiu. A IA GoScripts assume o lugar." % str(names[st]))
	names[st] = "IA GoScripts"
	if phase == "play" and turn == st:
		_next()
	elif phase == "respond" and 1 - asker == st % 2 and not team_has_remote(st % 2) and st % 2 != 0:
		_later(0.6, _ai_respond)
	elif phase == "onze" and onze == st % 2 and onze != 0 and not team_has_remote(onze):
		_later(0.6, _ai_onze)


# simulação IA x IA (testes): roda até alguém fazer 12
func run_sim() -> void:
	var guard := 0
	while not queue.is_empty() and guard < 100000:
		var f: Callable = queue.pop_front()
		f.call()
		guard += 1


# ---------------------------------------------------------------- cartas
func team(seat: int) -> int:
	return seat % 2


func manilha_rank() -> int:
	return (int(vira.r) + 1) % 10


func power(c: Dictionary) -> int:
	if int(c.r) == manilha_rank():
		return 100 + int(c.s)
	return int(c.r)


func is_manilha(c: Dictionary) -> bool:
	return int(c.r) == manilha_rank()


func new_deck() -> Array:
	var d: Array = []
	for s in 4:
		for r in 10:
			d.append({"r": r, "s": s})
	d.shuffle()
	return d


# ---------------------------------------------------------------- fluxo
func new_hand() -> void:
	var deck := new_deck()
	hands = []
	for i in n:
		hands.append([deck.pop_back(), deck.pop_back(), deck.pop_back()])
	vira = deck.pop_back()
	value = 1
	last_raiser = -1
	pending = 0
	results = []
	plays = []
	last_plays = []
	hidden_next = false
	ferro = false
	onze = -1
	starter = (dealer + 1) % n
	turn = starter
	phase = "play"
	if score[0] == 11 and score[1] == 11:
		ferro = true
		say("MÃO DE FERRO! Todo mundo joga no escuro.")
	elif score[0] == 11 or score[1] == 11:
		onze = 0 if score[0] == 11 else 1
		phase = "onze"
		if onze == 0 and not sim:
			_show_onze()
			return
		if team_has_remote(onze):
			return
		_later(0.9, _ai_onze)
		return
	_next()


func _next_queda() -> void:
	score = [0, 0]
	queda_win = -1
	dealer = (dealer + 1) % n
	new_hand()


func _ai_onze() -> void:
	var st := team_strength(onze)
	if st >= 1.15 or randf() < 0.15:
		value = 3
		phase = "play"
		say("%s aceitou a MÃO DE 11 (vale 3)." % team_name(onze))
		_next()
	else:
		say("%s correu da MÃO DE 11." % team_name(onze))
		end_hand(1 - onze, 1)


func _next() -> void:
	if phase != "play":
		return
	_refresh()
	if (turn == 0 and not sim) or is_remote(turn):
		return
	_later(0.75 if not sim else 0.0, _ai_turn)


func play_card(seat: int, idx: int, hid: bool) -> void:
	if phase != "play" or seat != turn:
		return
	var h: Array = hands[seat]
	if idx < 0 or idx >= h.size():
		return
	var c: Dictionary = h[idx]
	h.remove_at(idx)
	var really_hidden := hid and results.size() >= 1
	plays.append({"seat": seat, "c": c, "hid": really_hidden or ferro, "show": not really_hidden})
	if not sim:
		game.play("click", 0.9)
	hidden_next = false
	turn = (turn + 1) % n
	if plays.size() == n:
		phase = "resolve"
		_refresh()
		_later(1.1 if not sim else 0.0, _resolve_round)
	else:
		_next()


func _resolve_round() -> void:
	var best := -1
	var best_seat := -1
	var tie := false
	for p in plays:
		var pw: int = -1 if (p.hid and not ferro) else power(p.c)
		if pw > best:
			best = pw
			best_seat = p.seat
			tie = false
		elif pw == best and pw >= 0 and team(p.seat) != team(best_seat):
			tie = true
	var r: int = -1 if tie else team(best_seat)
	results.append(r)
	# mostra as cartas abertas e quem ganhou a rodada antes de recolher
	round_win = -1 if tie else best_seat
	phase = "showround"
	say("Rodada empatou (amarrou)!" if tie else "%s fez a rodada." % seat_name(best_seat))
	_refresh()
	_later(2.2 if not sim else 0.0, _finish_round.bind(tie, best_seat))


func _finish_round(tie: bool, best_seat: int) -> void:
	for p in plays:
		p.show = true
	last_plays = plays
	plays = []
	round_win = -2
	var hw := hand_winner()
	if hw != -2:
		if hw == -1:
			say("Empatou tudo! Ninguém marca.")
			end_hand(-1, 0)
		else:
			end_hand(hw, value)
		return
	if not tie:
		starter = best_seat
	turn = starter
	phase = "play"
	_next()


# -2 = continua; -1 = ninguém; 0/1 = time vencedor
func hand_winner() -> int:
	var k := results.size()
	if k == 0:
		return -2
	var r1: int = results[0]
	if k == 1:
		return -2
	var r2: int = results[1]
	if r1 == -1:
		if r2 != -1:
			return r2
		if k == 2:
			return -2
		return results[2]
	if r2 == r1 or r2 == -1:
		return r1
	if k == 2:
		return -2
	var r3: int = results[2]
	return r1 if r3 == -1 else r3


func end_hand(tm: int, pts: int) -> void:
	phase = "handend"
	_close_modal()
	if tm >= 0:
		score[tm] = mini(12, score[tm] + pts)
		say("%s %s %d tento%s!" % [team_name(tm), "ganhou" if (tm == 1 or netmode != "") else "ganhamos", pts, "" if pts == 1 else "s"] if not sim else "")
		if not sim:
			game.play("pocket" if tm == 0 else "rail", 0.7)
	_refresh()
	if score[0] >= 12 or score[1] >= 12:
		var qw := 0 if score[0] >= 12 else 1
		quedas[qw] += 1
		if quedas[qw] >= (1 if OS.get_cmdline_user_args().has("--oneq") else 2):
			winner = qw
			phase = "over"
			if not sim:
				_later(1.2, _show_over)
			return
		# acabou uma queda: mostra e começa a próxima
		phase = "queda"
		queda_win = qw
		say("%s %s a %dª QUEDA!  (%d x %d)" % [team_name(qw), "venceu" if (qw == 1 or netmode != "") else "vencemos", quedas[0] + quedas[1], quedas[0], quedas[1]] if not sim else "")
		_refresh()
		_later(3.0 if not sim else 0.0, _next_queda)
		return
	dealer = (dealer + 1) % n
	_later(1.8 if not sim else 0.0, new_hand)


# ---------------------------------------------------------------- truco
func can_raise(seat: int) -> bool:
	return phase == "play" and turn == seat and value < 12 and last_raiser != team(seat) and onze == -1 and not ferro


func ask(seat: int) -> void:
	if not can_raise(seat):
		return
	asker = team(seat)
	pending = STEP[value]
	phase = "respond"
	bubble(seat, CALL[pending])
	if not sim:
		game.play("shot", 0.8)
	_refresh()
	var resp := 1 - asker
	if resp == 0 and not sim:
		_show_respond()
	elif team_has_remote(resp):
		pass
	else:
		_later(1.0 if not sim else 0.0, _ai_respond)


func respond(choice: String) -> void:
	if phase != "respond":
		return
	_close_modal()
	var resp_team := 1 - asker
	var who := _speaker(resp_team)
	if choice == "corre":
		bubble(who, "CORRO!")
		say("%s correu." % team_name(resp_team))
		end_hand(asker, value)
		return
	value = pending
	last_raiser = asker
	if choice == "aumenta" and value < 12:
		bubble(who, CALL[STEP[value]])
		asker = resp_team
		pending = STEP[value]
		if not sim:
			game.play("shot", 0.8)
		_refresh()
		if 1 - asker == 0 and not sim:
			_show_respond()
		elif team_has_remote(1 - asker):
			pass
		else:
			_later(1.0 if not sim else 0.0, _ai_respond)
		return
	bubble(who, "DESCE!" if value == 3 else "VAMO!")
	say("Valendo %d tentos." % value)
	phase = "play"
	_next()


func _speaker(tm: int) -> int:
	if turn % 2 == tm:
		return turn
	return (turn + 1) % n


func _ai_respond() -> void:
	if phase != "respond":
		return
	var tm := 1 - asker
	var st := team_strength(tm)
	var need := 0.75 + 0.07 * float(pending)
	if st >= need + 0.45 and pending < 12 and randf() < 0.5:
		respond("aumenta")
	elif st >= need or randf() < 0.12:
		respond("aceita")
	else:
		respond("corre")


# ---------------------------------------------------------------- IA
func card_score(c: Dictionary) -> float:
	if is_manilha(c):
		return 1.0 + 0.1 * float(c.s)
	return float(c.r) / 10.0


func team_strength(tm: int) -> float:
	# força das cartas que restam do time (2x2: a IA só "sabe" das próprias)
	var best := 0.0
	var second := 0.0
	for seat in n:
		if team(seat) != tm:
			continue
		for c in hands[seat]:
			var s := card_score(c)
			if s > best:
				second = best
				best = s
			elif s > second:
				second = s
	var won := 0.0
	for r in results:
		if r == tm:
			won += 0.35
		elif r == 1 - tm:
			won -= 0.35
	return best + second * 0.6 + won


func _ai_turn() -> void:
	if phase != "play" or (turn == 0 and not sim) or is_remote(turn):
		return
	var seat := turn
	if can_raise(seat):
		var st := team_strength(team(seat))
		var chance := 0.0
		if st > 1.6:
			chance = 0.55
		elif st > 1.25:
			chance = 0.3
		if randf() < chance or randf() < 0.05:
			ask(seat)
			return
	var idx := choose_card(seat)
	var hid := false
	if results.size() >= 1 and plays.size() > 0:
		var h: Array = hands[seat]
		if power(h[idx]) < _table_best_opp(seat) and randf() < 0.25:
			hid = true
	play_card(seat, idx, hid)


func _table_best_opp(seat: int) -> int:
	var b := -1
	for p in plays:
		if team(p.seat) != team(seat) and not p.hid:
			b = maxi(b, power(p.c))
	return b


func choose_card(seat: int) -> int:
	var h: Array = hands[seat]
	var order: Array = range(h.size())
	order.sort_custom(func(a, b): return power(h[a]) < power(h[b]))
	if plays.is_empty():
		if results.is_empty():
			return order[order.size() / 2] if h.size() == 3 else order[0]
		if results[results.size() - 1] == team(seat):
			return order[order.size() - 1]
		return order[order.size() - 1]
	var best_opp := _table_best_opp(seat)
	var best_mine := -1
	for p in plays:
		if team(p.seat) == team(seat) and not p.hid:
			best_mine = maxi(best_mine, power(p.c))
	if best_mine > best_opp and plays.size() == n - 1:
		return order[0]
	for i in order:
		if power(h[i]) > best_opp:
			return i
	return order[0]


# ---------------------------------------------------------------- texto
func team_name(tm: int) -> String:
	if netmode != "":
		if n == 4:
			return "%s e %s" % [str(names[tm]), str(names[tm + 2])]
		return str(names[tm])
	return "NÓS" if tm == 0 else "ELES"


func seat_name(seat: int) -> String:
	if netmode != "":
		return "Você" if seat == 0 else str(names[seat])
	if seat == 0:
		return "Você"
	if n == 4 and seat == 2:
		return "Parceiro"
	return "IA %d" % (1 if seat == 1 else 2) if n == 4 else "IA GoScripts"


func say(s: String) -> void:
	if s == "":
		return
	msg = s
	msg_t = 3.2


func bubble(seat: int, s: String) -> void:
	bub_id += 1
	bubbles.append({"seat": seat, "txt": s, "t": 0.0, "id": bub_id})


var queue: Array = []


func _later(sec: float, f: Callable) -> void:
	if sim:
		queue.append(f)
		return
	# timer filho: se sair do truco, ele some junto e nada roda depois
	var tm := Timer.new()
	tm.one_shot = true
	tm.wait_time = maxf(sec, 0.01)
	add_child(tm)
	tm.timeout.connect(func():
		tm.queue_free()
		f.call())
	tm.start()


# ---------------------------------------------------------------- interface
func _build_ui() -> void:
	btn_truco = ui.mk_btn("TRUCO!", 190, 70, Color("c0392b"), 32)
	btn_truco.pressed.connect(act_ask)
	add_child(btn_truco)
	btn_enc = ui.mk_btn("ENCOBERTA", 190, 52, Color("3b4556"), 20)
	btn_enc.pressed.connect(func():
		hidden_next = not hidden_next
		_refresh())
	add_child(btn_enc)
	btn_exit = ui.mk_btn("SAIR", 120, 50, Color("3b4556"), 22)
	btn_exit.pressed.connect(on_back)
	add_child(btn_exit)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", ui.sbox(Color(0.02, 0.05, 0.09, 0.95), 26, Color("f4c542"), 3, 16))
	modal.visible = false
	add_child(modal)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 12)
	modal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	modal.add_child(ui.margin(modal_box, 22))


func _layout() -> void:
	var w := size.x
	var h := size.y
	btn_truco.position = Vector2(w - 220, h - 200)
	btn_enc.position = Vector2(w - 220, h - 118)
	btn_exit.position = Vector2(w - 140, 16)
	modal.position = (size - modal.size) / 2.0


func _refresh() -> void:
	if sim:
		return
	var my_turn := phase == "play" and turn == 0
	btn_truco.visible = can_raise(0)
	if value < 12:
		btn_truco.text = CALL[STEP[value]]
	btn_enc.visible = my_turn and results.size() >= 1 and not ferro
	btn_enc.text = "ENCOBERTA: SIM" if hidden_next else "ENCOBERTA"
	btn_enc.add_theme_stylebox_override("normal", ui.sbox(Color("8e44ad") if hidden_next else Color("3b4556"), 20, Color(1, 1, 1, 0.4), 3, 8))
	queue_redraw()


func _close_modal() -> void:
	if modal != null:
		modal.visible = false


func _modal(title: String, sub: String, buttons: Array, extra: Control = null) -> void:
	for c in modal_box.get_children():
		c.queue_free()
	modal_box.add_child(ui.mk_lbl(title, 40, Color("f4c542"), 8))
	if sub != "":
		modal_box.add_child(ui.mk_lbl(sub, 20, Color(1, 1, 1, 0.85), 3))
	if extra != null:
		modal_box.add_child(extra)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_box.add_child(row)
	for b in buttons:
		var bt: Button = ui.mk_btn(b[0], 200, 66, b[1], 26)
		bt.pressed.connect(b[2])
		row.add_child(bt)
	modal.visible = true
	modal.reset_size()
	_layout.call_deferred()


func _show_respond() -> void:
	var bs: Array = [["ACEITAR", Color("1fa85a"), func(): act_respond("aceita")], ["CORRER", Color("3b4556"), func(): act_respond("corre")]]
	if pending < 12:
		bs.append([CALL[STEP[pending]], Color("c0392b"), func(): act_respond("aumenta")])
	_modal("%s pediu %s" % [team_name(asker), CALL[pending]], "Se aceitar, vale %d. Se correr, %s leva %d." % [pending, team_name(asker), value], bs)


func _show_onze() -> void:
	var extra: Control = null
	if n == 4:
		extra = Control.new()
		extra.custom_minimum_size = Vector2(380, 150)
		var p: Array = hands[2]
		var ex := extra
		extra.draw.connect(func():
			ex.draw_string(ThemeDB.fallback_font, Vector2(0, 16), "Cartas do parceiro:", HORIZONTAL_ALIGNMENT_CENTER, 380, 18, Color(1, 1, 1, 0.8))
			for i in p.size():
				draw_card_on(ex, Rect2(40 + i * 110, 26, 90, 120), p[i], true, false))
	_modal("MÃO DE 11", "Jogar vale 3 tentos. Correr dá 1 tento para %s." % team_name(1), [["JOGAR", Color("1fa85a"), func(): act_onze("jogar")], ["CORRER", Color("3b4556"), func(): act_onze("correr")]], extra)


func _show_over() -> void:
	if over_shown:
		return
	over_shown = true
	var won := winner == 0
	var r := 0
	if netmode != "":
		r = 60 if won else 15
		if won:
			game.save.truco_wins = int(game.save.get("truco_wins", 0)) + 1
		else:
			game.save.truco_losses = int(game.save.get("truco_losses", 0)) + 1
		game.save.coins += r
		game.write_save()
		game.play("win")
		_modal("VITÓRIA!" if won else "DERROTA", "Quedas %d x %d   •   +%d moedas" % [quedas[0], quedas[1], r], [["MENU", Color("3b4556"), _quit]])
		return
	if won:
		r = 70 if n == 4 else 50
		game.save.truco_wins = int(game.save.get("truco_wins", 0)) + 1
	else:
		r = 10
		game.save.truco_losses = int(game.save.get("truco_losses", 0)) + 1
	game.save.coins += r
	game.write_save()
	game.play("win")
	_modal("VITÓRIA!" if won else "DERROTA", "Quedas %d x %d   •   +%d moedas" % [quedas[0], quedas[1], r], [["JOGAR DE NOVO", Color("1fa85a"), func():
		_close_modal()
		over_shown = false
		score = [0, 0]
		quedas = [0, 0]
		winner = -1
		dealer = randi() % n
		new_hand()], ["MENU", Color("3b4556"), _quit]])


func on_back() -> void:
	if phase == "over":
		_quit()
		return
	ui.confirm("SAIR DO TRUCO?", "A partida atual será perdida." if netmode == "" else "Você vai sair da partida online.", "SAIR", _quit, "CONTINUAR", func(): pass)


func _quit() -> void:
	game.paused = false
	if netmode != "" and game.net != null:
		game.net.close()
	ui.close_truco()


# ---------------------------------------------------------------- ações (local ou pela rede)
func act_play(i: int) -> void:
	if netmode == "guest":
		game.net.send_tact({"a": "play", "i": i, "h": hidden_next})
		hidden_next = false
		return
	play_card(0, i, hidden_next)


func act_ask() -> void:
	if netmode == "guest":
		game.net.send_tact({"a": "ask"})
		return
	ask(0)


func act_respond(c: String) -> void:
	_close_modal()
	if netmode == "guest":
		game.net.send_tact({"a": "resp", "c": c})
		return
	respond(c)


func act_onze(c: String) -> void:
	_close_modal()
	if netmode == "guest":
		game.net.send_tact({"a": "onze", "c": c})
		return
	_onze_choice(c)


func _onze_choice(c: String) -> void:
	if phase != "onze":
		return
	if c == "jogar":
		value = 3
		phase = "play"
		say("%s aceitou a MÃO DE 11 (vale 3)." % team_name(onze))
		_next()
	else:
		say("%s correu da MÃO DE 11." % team_name(onze))
		end_hand(1 - onze, 1)


# anfitrião recebe a ação de um convidado
func net_action(d: Dictionary, peer: int = 2) -> void:
	if netmode != "host" or not peer_seat.has(peer):
		return
	var st: int = peer_seat[peer]
	match str(d.get("a", "")):
		"play":
			if turn == st:
				play_card(st, int(d.i), bool(d.h))
		"ask":
			ask(st)
		"resp":
			if phase == "respond" and 1 - asker == st % 2:
				respond(str(d.c))
		"onze":
			if phase == "onze" and onze == st % 2:
				_onze_choice(str(d.c))


func _rs(s2: int, v: int) -> int:
	return s2 if s2 < 0 else (s2 - v + n) % n


func _rt(tm: int, v: int) -> int:
	return tm if tm < 0 else (tm + v) % 2


# estado da mesa visto por quem está no assento v (ele vira o assento 0)
func guest_snapshot(v: int = 1) -> Dictionary:
	var pl := []
	for p in plays:
		var q := {"seat": _rs(int(p.seat), v), "c": p.c, "hid": p.hid, "show": p.show}
		if (p.hid and not ferro) or (ferro and phase != "resolve" and phase != "showround"):
			if int(p.seat) != v or ferro:
				q.c = {}
		pl.append(q)
	var lp := []
	for p in last_plays:
		var q2 := {"seat": _rs(int(p.seat), v), "c": p.c, "hid": p.hid, "show": p.show}
		if p.hid and not ferro:
			q2.c = {}
		lp.append(q2)
	var res := []
	for r in results:
		res.append(_rt(r, v))
	var bl := []
	for b in bubbles:
		bl.append({"seat": _rs(int(b.seat), v), "txt": b.txt, "id": b.id})
	var counts := []
	var nm := []
	for r in n:
		var ab := (r + v) % n
		counts.append(hands[ab].size())
		nm.append(names[ab])
	var partner := []
	if n == 4 and phase == "onze" and onze == v % 2:
		partner = hands[(v + 2) % n]
	var sc: Array = [score[0], score[1]] if v % 2 == 0 else [score[1], score[0]]
	var qd: Array = [quedas[0], quedas[1]] if v % 2 == 0 else [quedas[1], quedas[0]]
	return {"n": n, "score": sc, "quedas": qd, "value": value, "vira": vira, "phase": phase, "turn": _rs(turn, v),
		"results": res, "plays": pl, "last": lp, "hand": hands[v], "counts": counts, "partner": partner, "lr": _rt(last_raiser, v),
		"asker": _rt(asker, v), "pending": pending, "onze": _rt(onze, v), "ferro": ferro, "winner": _rt(winner, v),
		"msg": msg if msg_t > 0.0 else "", "bub": bl, "names": nm, "tl": tl, "ws": _rs(ws_view, v), "rw": _rs(round_win, v),
		"qw": _rt(queda_win, v)}


func apply_snapshot(s2: Dictionary) -> void:
	n = int(s2.get("n", 2))
	score = s2.score
	quedas = s2.get("quedas", [0, 0])
	value = int(s2.value)
	vira = s2.vira
	phase = str(s2.phase)
	turn = int(s2.turn)
	results = s2.results
	plays = s2.plays
	last_plays = s2.last
	var cnt: Array = s2.get("counts", [])
	hands = [s2.hand]
	for r in range(1, n):
		var h: Array = []
		for i in (int(cnt[r]) if r < cnt.size() else 0):
			h.append({})
		hands.append(h)
	var pt: Array = s2.get("partner", [])
	if n == 4 and not pt.is_empty():
		hands[2] = pt
	last_raiser = int(s2.lr)
	asker = int(s2.asker)
	pending = int(s2.pending)
	onze = int(s2.onze)
	ferro = bool(s2.ferro)
	winner = int(s2.winner)
	queda_win = int(s2.get("qw", -1))
	names = s2.names
	tl = float(s2.get("tl", TURN_T))
	round_win = int(s2.get("rw", -2))
	ws_view = int(s2.get("ws", -1))
	if str(s2.msg) != "" and str(s2.msg) != msg:
		say(str(s2.msg))
	for b in s2.bub:
		if int(b.id) > seen_bub:
			seen_bub = int(b.id)
			bubbles.append({"seat": int(b.seat), "txt": str(b.txt), "t": 0.0})
			game.play("shot", 0.6)
	var pkey := "%s|%d|%d|%d" % [phase, asker, pending, onze]
	if pkey != prompt_key:
		prompt_key = pkey
		_close_modal()
		if phase == "respond" and asker == 1:
			_show_respond()
		elif phase == "onze" and onze == 0:
			_show_onze()
		elif phase == "over":
			_show_over()
	_refresh()


# ---------------------------------------------------------------- desenho
func _process(delta: float) -> void:
	if sim:
		return
	t += delta
	if msg_t > 0.0:
		msg_t -= delta
	for i in range(bubbles.size() - 1, -1, -1):
		bubbles[i].t += delta
		if bubbles[i].t > 1.8:
			bubbles.remove_at(i)
	_tick_timer(delta)
	_layout()
	queue_redraw()
	if game.net_auto and netmode != "":
		_autoplay(delta)
		if netmode == "host" and int(t) % 30 == 0 and int(t) != bw_last and int(t) > 0:
			bw_last = int(t)
			print("TBW t=", int(t), " envios=", game.net.tsends, " bytes=", game.net.tbytes)
	if netmode == "host" and game.net != null and game.net.active:
		# manda só quando algo muda na mesa (o relógio cada celular conta sozinho)
		# + uma conferência a cada 2 s para corrigir quem perdeu alguma mensagem
		snap_t += delta
		beat_t += delta
		if snap_t > 0.05:
			snap_t = 0.0
			var beat := beat_t >= 2.0
			if beat:
				beat_t = 0.0
			for st in seat_peer.keys():
				var sn := guest_snapshot(int(st))
				var cmp := sn.duplicate()
				cmp.erase("tl")
				var key := str(cmp) if not OS.get_cmdline_user_args().has("--oldsnap") else str(sn)
				if beat or key != str(last_snaps.get(st, "")):
					last_snaps[st] = key
					game.net.send_tstate_to(int(seat_peer[st]), sn)


func card_rect_hand(i: int, cnt: int) -> Rect2:
	var w := 120.0
	var hgt := 172.0
	var gap := 18.0
	var total := cnt * w + (cnt - 1) * gap
	var x0 := size.x / 2.0 - total / 2.0
	return Rect2(x0 + i * (w + gap), size.y - hgt - 24.0, w, hgt)


func seat_pos(seat: int) -> Vector2:
	var c := Vector2(size.x / 2.0, size.y / 2.0 - 10.0)
	if n == 2:
		return c + (Vector2(0, 80) if seat == 0 else Vector2(0, -95))
	return c + [Vector2(0, 80), Vector2(170, -8), Vector2(0, -95), Vector2(-170, -8)][seat]


# ponto embaixo da placa do jogador (para o balão do chat)
func plate_anchor(seat: int) -> Vector2:
	if seat == 0:
		return Vector2(96 + 110, size.y - 128)
	var hp := seat_hand_pos(seat)
	if n == 4 and seat != 2:
		return hp + Vector2(0, -150 + 52)
	return hp + Vector2(84 + 100, -40 + 56)


func seat_hand_pos(seat: int) -> Vector2:
	if n == 2 or seat == 2:
		return Vector2(size.x / 2.0, 92)
	return Vector2(size.x - 150.0 if seat == 1 else 150.0, size.y / 2.0 + 20.0)


const TURN_T := 20.0
var tl := 20.0
var wait_key := ""
var ws_view := -1
var mesa_tex: Texture2D


func waiting_seat() -> int:
	if phase == "play":
		if (turn == 0 and not sim) or is_remote(turn):
			return turn
	elif phase == "respond":
		var rt := 1 - asker
		if rt == 0:
			return 0
		if team_has_remote(rt):
			return remote_of_team(rt)
	elif phase == "onze":
		if onze == 0:
			return 0
		if team_has_remote(onze):
			return remote_of_team(onze)
	return -1


func _tick_timer(delta: float) -> void:
	if sim:
		return
	if netmode == "guest":
		# o relógio desce aqui mesmo; o anfitrião só manda o valor quando a vez muda (e a cada 2 s)
		if ws_view >= 0:
			tl = maxf(0.0, tl - delta)
		return
	var key := "%s|%d|%d|%d|%d|%d" % [phase, turn, asker, pending, onze, results.size()]
	if key != wait_key:
		wait_key = key
		tl = TURN_T
	var ws := waiting_seat()
	ws_view = ws
	if ws < 0:
		return
	tl -= delta
	if tl <= 0.0:
		tl = TURN_T
		_timeout(ws)


func _timeout(ws: int) -> void:
	_close_modal()
	if phase == "play":
		var h: Array = hands[ws]
		if h.is_empty():
			return
		var lo := 0
		for k in h.size():
			if power(h[k]) < power(h[lo]):
				lo = k
		say("Tempo esgotado! Foi jogada a menor carta.")
		play_card(ws, lo, false)
	elif phase == "respond":
		say("Tempo esgotado! Correu.")
		respond("corre")
	elif phase == "onze":
		say("Tempo esgotado! Correu da mão de 11.")
		_onze_choice("correr")


func _plate(r: Rect2, nm: String, tm: int, active: bool, frac: float) -> void:
	var f: Font = ThemeDB.fallback_font
	var tc := Color("6fd3ff") if tm == 0 else Color("ff8a8a")
	draw_style_box(ui.sbox(Color(0.03, 0.05, 0.08, 0.88), int(r.size.y / 2.0), Color(0.96, 0.77, 0.26, 0.95) if active else Color(1, 1, 1, 0.22), 3 if active else 2, 8), r)
	var ac := r.position + Vector2(r.size.y / 2.0, r.size.y / 2.0)
	var rad := r.size.y / 2.0 - 6.0
	draw_circle(ac, rad, tc.darkened(0.45))
	draw_circle(ac, rad - 3.0, tc.darkened(0.2))
	draw_string(f, ac + Vector2(-rad, rad * 0.42), nm.left(1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, int(rad * 1.2), Color.WHITE)
	if active and frac >= 0.0:
		var col := Color("3ddc84") if frac > 0.5 else (Color("ffb020") if frac > 0.25 else Color("ff4040"))
		draw_arc(ac, rad + 3.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, col, 4.0)
	draw_string(f, Vector2(r.position.x + r.size.y + 4, r.position.y + r.size.y * 0.45), nm, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - r.size.y - 10, 18, Color.WHITE)
	draw_string(f, Vector2(r.position.x + r.size.y + 4, r.position.y + r.size.y * 0.82), ("NÓS" if tm == 0 else "ELES") + ("   • %ds" % int(ceil(tl)) if active and frac >= 0.0 else ""), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - r.size.y - 10, 14, tc)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if mesa_tex == null:
		mesa_tex = load("res://cards/mesa.jpg")
	draw_texture_rect(mesa_tex, Rect2(0, 0, w, h), false)
	var f: Font = ThemeDB.fallback_font
	if vira.is_empty() or hands.size() < n:
		draw_string(f, Vector2(0, h / 2.0), "Aguardando o anfitrião...", HORIZONTAL_ALIGNMENT_CENTER, w, 30, Color(1, 1, 1, 0.85))
		return
	var frac := clampf(tl / TURN_T, 0.0, 1.0)
	# placar
	var sp := Rect2(18, 14, 300, 134)
	draw_style_box(ui.sbox(Color(0.03, 0.05, 0.08, 0.9), 20, Color(0.96, 0.77, 0.26, 0.7), 2, 10), sp)
	draw_style_box(ui.sbox(Color("1d4f8f"), 14), Rect2(28, 24, 84, 80))
	draw_style_box(ui.sbox(Color("8a1c24"), 14), Rect2(120, 24, 84, 80))
	draw_string(f, Vector2(28, 46), "NÓS", HORIZONTAL_ALIGNMENT_CENTER, 84, 17, Color(1, 1, 1, 0.85))
	draw_string(f, Vector2(28, 92), str(score[0]), HORIZONTAL_ALIGNMENT_CENTER, 84, 42, Color.WHITE)
	draw_string(f, Vector2(120, 46), "ELES", HORIZONTAL_ALIGNMENT_CENTER, 84, 17, Color(1, 1, 1, 0.85))
	draw_string(f, Vector2(120, 92), str(score[1]), HORIZONTAL_ALIGNMENT_CENTER, 84, 42, Color.WHITE)
	draw_string(f, Vector2(212, 44), "MÃO VALE", HORIZONTAL_ALIGNMENT_CENTER, 100, 14, Color(1, 1, 1, 0.7))
	draw_string(f, Vector2(212, 86), str(value), HORIZONTAL_ALIGNMENT_CENTER, 100, 38, Color("f4c542"))
	for tq in 2:
		for k in 2:
			var qp := Vector2(48 + tq * 92 + k * 24, 116)
			var on: bool = quedas[tq] > k
			draw_circle(qp, 7, (Color("6fd3ff") if tq == 0 else Color("ff8a8a")) if on else Color(1, 1, 1, 0.14))
			if on:
				draw_circle(qp, 3, Color.WHITE)
	draw_string(f, Vector2(18, 140), "QUEDAS (melhor de 3)", HORIZONTAL_ALIGNMENT_CENTER, 190, 12, Color(1, 1, 1, 0.55))
	for i in 3:
		var cc := Color(1, 1, 1, 0.16)
		if i < results.size():
			cc = Color("6fd3ff") if results[i] == 0 else (Color("ff8a8a") if results[i] == 1 else Color("cccccc"))
		draw_circle(Vector2(240 + i * 20, 100), 6, cc)
	# vira e monte
	var vr := Rect2(340, 18, 78, 112)
	for k in 3:
		draw_card_on(self, Rect2(vr.position + Vector2(96 + k * 2, 4 - k * 2), vr.size), {}, false, false)
	draw_card_on(self, vr, vira, true, false)
	draw_string(f, Vector2(vr.position.x - 10, vr.end.y + 20), "VIRA  •  manilha: %s" % RANKS[manilha_rank()], HORIZONTAL_ALIGNMENT_LEFT, 260, 16, Color("f4c542"))
	draw_string(f, Vector2(vr.position.x - 10, vr.end.y + 38), "Zap > Copas > Espada > Ouros", HORIZONTAL_ALIGNMENT_LEFT, 260, 13, Color(1, 1, 1, 0.65))
	# outros jogadores
	for seat in range(1, n):
		var hp := seat_hand_pos(seat)
		var cnt: int = hands[seat].size()
		var side := n == 4 and seat != 2
		for i in cnt:
			var off := (float(i) - (cnt - 1) / 2.0) * 30.0
			var rr := Rect2(hp + (Vector2(-34, off - 48) if side else Vector2(off - 34, -48)), Vector2(68, 96))
			draw_card_on(self, rr, {}, false, false)
		var pr: Rect2
		if side:
			pr = Rect2(hp + Vector2(-90, -150), Vector2(180, 52))
		else:
			pr = Rect2(hp + Vector2(84, -40), Vector2(200, 56))
		_plate(pr, seat_name(seat), team(seat), ws_view == seat or (phase == "play" and turn == seat), frac if ws_view == seat else -1.0)
	# minha placa
	_plate(Rect2(96, h - 128, 220, 60), names[0] if netmode != "" else str(game.my_name()), 0, ws_view == 0, frac if ws_view == 0 else -1.0)
	# rodada anterior
	if not last_plays.is_empty():
		draw_style_box(ui.sbox(Color(0, 0, 0, 0.35), 12), Rect2(w - 290, 132, 270, 100))
		draw_string(f, Vector2(w - 280, 152), "RODADA ANTERIOR", HORIZONTAL_ALIGNMENT_LEFT, 250, 13, Color(1, 1, 1, 0.6))
		for k in last_plays.size():
			var p: Dictionary = last_plays[k]
			draw_card_on(self, Rect2(Vector2(w - 278 + k * 62, 160), Vector2(48, 66)), p.c, (not p.hid or ferro) and not p.c.is_empty(), false)
	# jogadas da rodada
	for p in plays:
		var cp := seat_pos(p.seat)
		var face: bool = p.show and not (p.hid and not ferro) and not p.c.is_empty()
		if ferro and phase != "resolve" and phase != "showround":
			face = false
		var cr := Rect2(cp - Vector2(50, 70), Vector2(100, 140))
		var win: bool = phase == "showround" and round_win == int(p.seat)
		if win:
			var pul := 0.5 + 0.5 * sin(t * 6.0)
			cr = cr.grow(6.0)
			draw_style_box(ui.sbox(Color(1.0, 0.85, 0.2, 0.35 + 0.3 * pul), 18), cr.grow(10.0))
		draw_card_on(self, cr, p.c, face, win)
		if win:
			draw_style_box(ui.sbox(Color("f4c542"), 10, Color("7a4a00"), 2), Rect2(cr.get_center().x - 52, cr.end.y - 6, 104, 28))
			draw_string(f, Vector2(cr.get_center().x - 52, cr.end.y + 15), "GANHOU", HORIZONTAL_ALIGNMENT_CENTER, 104, 18, Color("3a2a00"))
	if phase == "showround" and round_win == -1:
		draw_style_box(ui.sbox(Color("bbbbbb"), 12, Color("333333"), 2), Rect2(w / 2.0 - 80, h / 2.0 - 30, 160, 40))
		draw_string(f, Vector2(w / 2.0 - 80, h / 2.0 - 2), "AMARROU!", HORIZONTAL_ALIGNMENT_CENTER, 160, 24, Color("222222"))
	# minha mão
	var mine: Array = hands[0] if not hands.is_empty() else []
	var my_turn := phase == "play" and turn == 0
	for i in mine.size():
		var r := card_rect_hand(i, mine.size())
		if my_turn:
			r.position.y -= 12.0 + 4.0 * sin(t * 4.0 + i)
		draw_card_on(self, r, mine[i], not ferro, my_turn)
	if my_turn:
		var tt := "SUA VEZ  •  %ds" % int(ceil(tl)) + ("   (vai ENCOBERTA)" if hidden_next else "")
		var bw2 := 360.0
		draw_style_box(ui.sbox(Color(0, 0, 0, 0.5), 14), Rect2(w / 2.0 - bw2 / 2.0, h - 262, bw2, 34))
		draw_rect(Rect2(w / 2.0 - bw2 / 2.0 + 8, h - 234, (bw2 - 16) * frac, 4), Color("3ddc84") if frac > 0.5 else (Color("ffb020") if frac > 0.25 else Color("ff4040")))
		draw_string(f, Vector2(0, h - 238), tt, HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color("f4c542"))
	# balões
	for b in bubbles:
		var bp := Vector2(w / 2.0, h - 250)
		if b.seat != 0:
			bp = seat_hand_pos(b.seat) + Vector2(0, 92 if n == 2 or b.seat == 2 else -92)
		var sc := 1.0 + 0.25 * maxf(0.0, 1.0 - b.t * 4.0)
		var bw := 230.0 * sc
		draw_style_box(ui.sbox(Color("ffe066"), 22, Color("c0392b"), 4, 8), Rect2(bp - Vector2(bw / 2.0, 34 * sc), Vector2(bw, 60 * sc)))
		draw_string(f, bp - Vector2(bw / 2.0, -10 * sc), b.txt, HORIZONTAL_ALIGNMENT_CENTER, bw, int(34 * sc), Color("8a1010"))
	if msg_t > 0.0:
		var a := clampf(msg_t, 0.0, 1.0)
		var mr := Rect2(w - 300, 244, 280, 74)
		draw_style_box(ui.sbox(Color(0, 0, 0, 0.6 * a), 14, Color(0.96, 0.77, 0.26, 0.5 * a), 2), mr)
		draw_multiline_string(f, mr.position + Vector2(12, 26), msg, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x - 24, 17, 3, Color(1, 1, 1, a))


func _suit(ci: CanvasItem, c: Vector2, sz: float, s: int, col: Color) -> void:
	if s == 0:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -sz), c + Vector2(sz * 0.72, 0), c + Vector2(0, sz), c + Vector2(-sz * 0.72, 0)]), col)
	elif s == 2:
		ci.draw_circle(c + Vector2(-sz * 0.42, -sz * 0.25), sz * 0.48, col)
		ci.draw_circle(c + Vector2(sz * 0.42, -sz * 0.25), sz * 0.48, col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-sz * 0.9, -sz * 0.1), c + Vector2(sz * 0.9, -sz * 0.1), c + Vector2(0, sz)]), col)
	elif s == 1:
		ci.draw_circle(c + Vector2(-sz * 0.42, sz * 0.2), sz * 0.48, col)
		ci.draw_circle(c + Vector2(sz * 0.42, sz * 0.2), sz * 0.48, col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-sz * 0.9, sz * 0.05), c + Vector2(sz * 0.9, sz * 0.05), c + Vector2(0, -sz)]), col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, sz * 0.3), c + Vector2(sz * 0.35, sz), c + Vector2(-sz * 0.35, sz)]), col)
	else:
		ci.draw_circle(c + Vector2(0, -sz * 0.45), sz * 0.42, col)
		ci.draw_circle(c + Vector2(-sz * 0.45, sz * 0.12), sz * 0.42, col)
		ci.draw_circle(c + Vector2(sz * 0.45, sz * 0.12), sz * 0.42, col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, sz * 0.1), c + Vector2(sz * 0.35, sz), c + Vector2(-sz * 0.35, sz)]), col)


const CARDS = preload("res://cards.gd")


func draw_card_on(ci: CanvasItem, r: Rect2, c: Dictionary, face: bool, hl: bool) -> void:
	var st: Dictionary = CARDS.style(str(game.save.get("deck", "classico")))
	if not face or c.is_empty():
		CARDS.draw_back(ci, r, st)
		return
	CARDS.draw_face(ci, r, c, st, is_manilha(c), hl)
	_draw_manilha_tag(ci, r, c)


func _draw_manilha_tag(ci: CanvasItem, r: Rect2, c: Dictionary) -> void:
	var f: Font = ThemeDB.fallback_font
	if is_manilha(c):
		var tag: String = ["OUROS", "ESPADA", "COPAS", "ZAP"][int(c.s)]
		ci.draw_style_box(ui.sbox(Color("f4c542"), 6), Rect2(r.position.x + 4, r.end.y - r.size.y * 0.2, r.size.x - 8, r.size.y * 0.14))
		ci.draw_string(f, Vector2(r.position.x, r.end.y - r.size.y * 0.09), tag, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.x * 0.11), Color("3a2a00"))


func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
	elif e is InputEventScreenTouch and e.pressed:
		pos = e.position
	else:
		return
	if phase != "play" or turn != 0 or modal.visible:
		return
	var mine: Array = hands[0]
	for i in mine.size():
		var r := card_rect_hand(i, mine.size()).grow(8)
		r.position.y -= 14
		if r.has_point(pos):
			act_play(i)
			accept_event()
			return


# teste automático online (dois processos no mesmo computador)
func _autoplay(delta: float) -> void:
	auto_t += delta
	if auto_t < (3.0 if OS.get_cmdline_user_args().has("--slowplay") else 0.35):
		return
	auto_t = 0.0
	if phase == "over":
		if not auto_done:
			auto_done = true
			print("TNET ", netmode, " placar=", score, " vencedor=", winner, " envios=", game.net.tsends, " bytes=", game.net.tbytes, " tempo=", int(t))
			if OS.get_cmdline_user_args().has("--backlobby"):
				var gm = game
				get_tree().create_timer(1.0).timeout.connect(func(): _quit())
				gm.get_tree().create_timer(4.0).timeout.connect(func():
					print("BACK tela=", gm.ui.cur, " lobby=", gm.ui.in_lobby(), " membros=", (gm.ui.lobby.get("members", []) as Array).size())
					gm.get_tree().quit())
			else:
				get_tree().create_timer(1.5).timeout.connect(func(): get_tree().quit())
		return
	if phase == "respond" and asker == 1:
		act_respond(["aceita", "corre", "aumenta"][randi() % 3] if pending < 12 else "aceita")
	elif phase == "onze" and onze == 0:
		act_onze("jogar")
	elif phase == "play" and turn == 0 and not hands.is_empty() and hands[0].size() > 0:
		if can_raise(0) and randf() < 0.15:
			act_ask()
		else:
			act_play(randi() % hands[0].size())
