extends Node
# TUTORIAL: o Oitão (mascote) ensina do começo: o menu, a sinuca (jogando de verdade: mirar, força,
# efeito, ajuste fino, regras, encaçapar) e o truco (mão arrumada: vira, manilhas, Zap, pedir truco).
# Aparece sozinho para quem acabou de instalar e dá para rever em AJUSTES > COMO JOGAR.

const COACH = preload("res://coach.gd")

var game: Node
var ui: CanvasLayer
var coach: CanvasLayer
var running := false
var skipped := false
var _got := ""


func setup(g: Node) -> void:
	game = g
	ui = g.ui
	coach = COACH.new()
	add_child(coach)
	coach.setup(ui)
	coach.next_pressed.connect(func(): _got = "next")
	coach.skip_pressed.connect(func():
		_got = "skip"
		skipped = true)


# ---------------------------------------------------------------- ajudantes
func _step(text: String, opts: Dictionary = {}) -> bool:
	if skipped:
		return false
	_got = ""
	await coach.say(text, opts)
	while _got == "":
		await get_tree().process_frame
	return _got == "next"


# espera o jogador fazer algo (cond) — o tutorial continua quando cond() fica verdadeira
func _action(text: String, cond: Callable, opts: Dictionary = {}, give_up_after := 0.0) -> bool:
	if skipped:
		return false
	_got = ""
	opts["btn"] = ""
	await coach.say(text, opts)
	var tt := 0.0
	var shown_btn := false
	while true:
		await get_tree().process_frame
		if skipped:
			return false
		if bool(cond.call()):
			return true
		tt += get_process_delta_time()
		if give_up_after > 0.0 and tt > give_up_after and not shown_btn:
			shown_btn = true
			coach.btn_next.visible = true
			coach.btn_next.text = "CONTINUAR ▶"
		if _got == "next":
			return true
	return true


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _rect_of(c: Control) -> Rect2:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()


func _to_screen(p: Vector2) -> Vector2:
	return game.get_global_transform_with_canvas() * p


func _reward(key: String, coins: int) -> void:
	if bool(game.save.get(key, false)):
		return
	game.save[key] = true
	game.save.coins += coins
	game.eco(coins, 0, "tutorial")
	game.write_save()
	ui.refresh_top()
	var fx: CanvasLayer = load("res://victory_fx.gd").new()
	game.add_child(fx)
	fx.play("confete")


func _finish() -> void:
	running = false
	coach.hide_coach()
	game.save["tut_done"] = true
	game.write_save()


# ---------------------------------------------------------------- tutorial completo
func start_full() -> void:
	if running:
		return
	running = true
	skipped = false
	if ui.has_modal():
		ui.close_modal()
	ui.show_screen("main")
	await _wait(0.3)
	var go := await _step("Oi! Eu sou o OITÃO, a bola 8 mais esperta do bar!\nBem-vindo ao SINUCOU! Quer que eu te ensine tudo rapidinho? Leva uns 3 minutos e você ainda ganha moedas.", {"btn": "VAMOS NESSA!", "skip_txt": "JÁ SEI JOGAR", "mood": "party"})
	if not go:
		_finish()
		return
	await _menu_tour()
	if skipped:
		_finish()
		return
	await _sinuca_part()
	if skipped:
		_back_menu_safe()
		_finish()
		return
	await _step("Agora vamos para o TRUCO! Bora lá?", {"btn": "BORA!", "mood": "happy"})
	if skipped:
		_finish()
		return
	await _truco_part(true)
	_finish()


func start_sinuca() -> void:
	if running:
		return
	running = true
	skipped = false
	await _sinuca_part()
	_back_menu_safe()
	_finish()


func start_truco() -> void:
	if running:
		return
	running = true
	skipped = false
	await _truco_part(false)
	_finish()


func _back_menu_safe() -> void:
	if game.st != game.St.MENU:
		game.go_menu()


# ---------------------------------------------------------------- 1) o menu
func _menu_tour() -> void:
	var r: Dictionary = ui.tut_refs
	await _step("Esse é o menu principal. Aqui você joga SINUCA: contra a IA, com um amigo no mesmo celular ou ONLINE contra gente de verdade.", {"spot": _rect_of(r.get("sinuca")), "hand": "tap"})
	await _step("E aqui fica o TRUCO PAULISTA: 1 contra 1 ou 2 contra 2, contra a IA ou com os amigos.", {"spot": _rect_of(r.get("truco")), "hand": "tap"})
	var top := _rect_of(ui.coin_lbl.get_parent() if ui.coin_lbl != null else null)
	await _step("Essas são suas MOEDAS. Com elas você compra tacos, mesas e efeitos na loja. Ganha jogando, fazendo missões, na roleta e no prêmio diário.", {"spot": top})
	await _step("Aqui do lado: AMIGOS (chame para jogar), ROLETA diária, PASSE e MISSÕES. Passe aqui todo dia, que sempre tem prêmio!", {"spot": _rect_of(r.get("rail"))})
	await _step("E embaixo: LOJA, INVENTÁRIO, PERFIL, RANKING semanal e AJUSTES (onde você cria a senha da sua conta e revê este tutorial).", {"spot": _rect_of(r.get("nav"))})
	await _step("Agora a parte boa: vamos para a mesa aprender a jogar sinuca!", {"btn": "BORA PRA MESA!", "mood": "party"})


# ---------------------------------------------------------------- 2) sinuca jogando de verdade
func _sinuca_part() -> void:
	if skipped:
		return
	coach.hide_coach()
	if ui.has_modal():
		ui.close_modal()
	game.start_game(game.Mode.TRAIN, 1)
	ui.show_screen("")
	await _wait(0.9)
	var cue: Dictionary = game.get_ball(0)
	var cp := _to_screen(cue.pos)
	if not await _step("Essa é a mesa! A bola BRANCA é a sua: é nela que o taco bate, e ela empurra as outras.", {"spot": Rect2(cp - Vector2(40, 40), Vector2(80, 80)), "side": "bottom"}):
		return
	# MIRAR
	var a0: float = game.aim_angle
	var moved := [0.0]
	var last := [a0]
	var tbl := Rect2(_to_screen(Vector2(-300, -180)), _to_screen(Vector2(300, 180)) - _to_screen(Vector2(-300, -180)))
	if not await _action("MIRAR: arraste o dedo pela mesa para girar o taco. Tente agora!", func():
		moved[0] += absf(angle_difference(last[0], game.aim_angle))
		last[0] = game.aim_angle
		return moved[0] > 0.7, {"hand": "drag_side", "hand_at": tbl.get_center() + Vector2(0, 60), "side": "top"}, 25.0):
		return
	await _step("Isso! A linha mostra para onde a branca vai e para onde a bola que ela acertar vai depois.", {"mood": "wow", "side": "top"})
	# FORÇA
	var br: Rect2 = game.bar_rect()
	if not await _action("FORÇA: puxe a barra da direita para BAIXO e solte. Quanto mais puxar, mais forte a tacada!", func(): return game.st == game.St.STRIKE or game.st == game.St.ROLL, {"spot": br, "hand": "drag_down", "hand_at": br.position + Vector2(br.size.x * 0.5, 30)}):
		return
	coach.hide_coach()
	var tw := 0.0
	while game.st != game.St.AIM and tw < 15.0:
		await get_tree().process_frame
		tw += get_process_delta_time()
	if not await _step("Boa! É assim que se dá uma tacada. Viu como a branca empurra as outras?", {"mood": "wow", "side": "top"}):
		return
	# EFEITO
	var sc: Vector2 = game.spin_center()
	if not await _action("EFEITO: toque na bolinha branca aqui em cima e arraste. Batendo EMBAIXO a branca volta (puxada); EM CIMA ela segue em frente; dos lados ela curva na tabela.", func(): return (game.spin as Vector2).length() > 0.3, {"spot": Rect2(sc - Vector2(56, 56), Vector2(112, 112)), "hand": "spin", "hand_at": sc}, 25.0):
		return
	# AJUSTE FINO
	var dc: Vector2 = game.dial_center()
	var r0: float = game.dial_rot
	await _action("AJUSTE FINO: gire essa rodinha para acertar a mira devagarinho, milímetro por milímetro. Ótimo para tacadas difíceis!", func(): return absf(float(game.dial_rot) - r0) > 0.8, {"spot": Rect2(dc - Vector2(56, 56), Vector2(112, 112)), "hand": "spin", "hand_at": dc}, 8.0)
	if skipped:
		return
	# REGRAS
	if not await _step("REGRAS: quem encaçapar primeiro escolhe o grupo: LISAS (1 a 7) ou LISTRADAS (9 a 15). Encaçape todas as suas e, por último, a 8 para ganhar!", {"extra": COACH.balls_strip(), "side": "top"}):
		return
	if not await _step("CUIDADO com as FALTAS: derrubar a branca ou não acertar uma bola sua primeiro dá BOLA NA MÃO para o adversário (ele põe a branca onde quiser). E derrubar a 8 antes da hora é derrota na hora!", {"mood": "think", "side": "top"}):
		return
	# ENCAÇAPAR
	var base := _pocketed_count()
	var ok := await _action("Agora é com você: mire, puxe a força e ENCAÇAPE uma bola! (dica: comece com bolas perto das caçapas)", func(): return _pocketed_count() > base, {"side": "top", "skip_txt": "PULAR"}, 60.0)
	if skipped:
		return
	coach.hide_coach()
	while game.st != game.St.AIM and game.st != game.St.MENU:
		await get_tree().process_frame
	_reward("tut_rw_s", 150)
	await _step(("BOA! Encaçapou! " if ok else "") + "Agora você já sabe jogar sinuca. Ganhou 150 moedas de presente!", {"mood": "party", "btn": "VALEU!", "skip": false})
	game.go_menu()
	await _wait(0.4)


func _pocketed_count() -> int:
	var n := 0
	for b in game.balls:
		if int(b.n) != 0 and not bool(b.on):
			n += 1
	return n


# ---------------------------------------------------------------- 3) truco com a mão arrumada
func _truco_part(full: bool) -> void:
	if skipped:
		return
	coach.hide_coach()
	if game.st != game.St.MENU:
		game.go_menu()
		await _wait(0.3)
	ui.open_truco(2, true)
	await _wait(0.8)
	var tn = ui.truco_node
	if tn == null:
		return
	if not await _step("Bem-vindo ao TRUCO PAULISTA! Usamos 40 cartas (sem 8, 9 e 10). Cada mão vale 1 ponto e quem fizer 12 pontos ganha a partida.", {"side": "bottom"}):
		_truco_skip(tn)
		return
	var strip := VBoxContainer.new()
	strip.add_child(COACH.card_strip(["4", "5", "6", "7", "Q", "J", "K", "A", "2", "3"], [0, 1, 2, 3, 0, 1, 2, 3, 0, 1]))
	strip.add_child(COACH.weak_strong())
	if not await _step("Essa é a força das cartas comuns, da mais fraca para a mais forte. Repara: o 3 é a carta comum mais forte!", {"extra": strip, "side": "bottom"}):
		_truco_skip(tn)
		return
	var vr := Rect2(336, 14, 104, 150)
	if not await _step("Essa carta no alto é a VIRA. Nesta mão ela é um 4.\nAs MANILHAS são as cartas LOGO ACIMA da vira: aqui, todos os 5! Elas ganham de qualquer carta comum.", {"spot": vr, "side": "bottom"}):
		_truco_skip(tn)
		return
	if not await _step("Entre as manilhas também tem ordem, pelo naipe:\nZAP (paus)  >  COPAS  >  ESPADA  >  OUROS.", {"extra": COACH.card_strip(["5", "5", "5", "5"], [3, 2, 1, 0], ["ZAP", "COPAS", "ESPADA", "OUROS"], 0), "side": "bottom"}):
		_truco_skip(tn)
		return
	var hr := _hand_rect(tn)
	if not await _step("Olha a sua mão: você tem o ZAP (o 5 de paus), a carta mais forte do jogo! E também um 3 de copas, muito bom.", {"spot": hr, "side": "top", "mood": "wow"}):
		_truco_skip(tn)
		return
	# rodada 1
	var c0: Rect2 = tn.card_rect_hand(0, (tn.hands[0] as Array).size())
	if not await _action("A mão é MELHOR DE 3 RODADAS: quem ganhar 2 leva os pontos. Toque no 3 de COPAS para jogar e ganhar a primeira rodada!", func(): return (tn.results as Array).size() >= 1, {"spot": c0, "hand": "tap", "side": "top"}):
		_truco_skip(tn)
		return
	coach.hide_coach()
	await _wait(0.6)
	# pedir truco
	var tw2 := 0.0
	while not tn.can_raise(0) and (tn.results as Array).size() < 2 and int(tn.tut_hand) < 2 and tw2 < 8.0:
		await get_tree().process_frame
		tw2 += get_process_delta_time()
	if tn.can_raise(0):
		if not await _action("Ganhou a primeira rodada! Agora PEÇA TRUCO: a mão passa a valer 3 pontos. O adversário pode ACEITAR, CORRER (aí você ganha o que valia) ou AUMENTAR para SEIS, NOVE e DOZE.", func(): return int(tn.value) >= 3, {"spot": _rect_of(tn.btn_truco), "hand": "tap", "side": "top"}):
			_truco_skip(tn)
			return
		coach.hide_coach()
		await _wait(0.5)
	# rodada 2: o Zap
	var sc0: int = int((tn.score as Array)[0])
	var zi := 0
	var h: Array = tn.hands[0]
	for i in h.size():
		if int(h[i].r) == 1 and int(h[i].s) == 3:
			zi = i
	var cz: Rect2 = tn.card_rect_hand(zi, h.size())
	var ztxt := "Ele ACEITOU: agora vale 3! Jogue o ZAP e feche a mão!" if int(tn.value) >= 3 else "Agora jogue o ZAP e feche a mão!"
	if not await _action(ztxt, func(): return int((tn.score as Array)[0]) > sc0 or int((tn.score as Array)[1]) > 0 or int(tn.tut_hand) >= 2, {"spot": cz, "hand": "tap", "side": "top", "mood": "wow"}):
		_truco_skip(tn)
		return
	coach.hide_coach()
	await _wait(0.8)
	_reward("tut_rw_t", 150)
	if not await _step("ISSO! A mão é sua: +3 pontos! Ganhou também 150 moedas de presente.", {"mood": "party", "skip": false}):
		_truco_skip(tn)
		return
	await _step("Últimas dicas:\n- A partir da 2ª rodada dá para jogar ENCOBERTA (carta virada, para blefar).\n- Com 11 pontos é a MÃO DE 11: você vê as cartas e decide se joga (vale 3).\n- 11 a 11 é a MÃO DE FERRO: todo mundo joga no escuro!", {"mood": "think", "skip": false})
	tn.tut = false
	var cont := await _step("Pronto, você já sabe jogar truco!" + ("\nDica: em AJUSTES > COMO JOGAR você revê este tutorial quando quiser." if full else "") + "\nQuer continuar essa partida contra a IA?", {"btn": "CONTINUAR JOGANDO", "skip_txt": "IR PARA O MENU", "mood": "party"})
	coach.hide_coach()
	if not cont:
		skipped = false
		if is_instance_valid(tn):
			tn._quit()


func _truco_skip(tn) -> void:
	if is_instance_valid(tn):
		tn.tut = false
	coach.hide_coach()


func _hand_rect(tn) -> Rect2:
	var h: Array = tn.hands[0]
	var r := Rect2()
	for i in h.size():
		var cr: Rect2 = tn.card_rect_hand(i, h.size())
		r = cr if i == 0 else r.merge(cr)
	return r
