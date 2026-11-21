extends Node
# NEGOCIAÇÃO entre amigos: cada um coloca itens (mesa, borda, taco, baralho, efeito) e moedas,
# os dois marcam PRONTO e depois CONFIRMAR. O servidor confere tudo (senha do aparelho, saldo,
# se cada um tem o que oferece e se a troca não é desigual demais: cada lado recebe pelo menos 25%
# do valor do que dá) e só aí troca. Quem dá um item pode comprar de novo na loja depois.

const MIN_PCT := 0.25
const DEFAULTS := {"felt": "verde", "rail": "rb_padrao", "cue": "classico", "deck": "classico", "wfx": "wf_confete"}

var game: Node
var ui
var layer: CanvasLayer
var root: Control
var st: Dictionary = {}      # último estado vindo do servidor
var tid := ""
var with_name := ""
var waiting := false
var my_items: Array = []
var my_coins := 0
var picker: Control
var _sent_has := false


func setup(g: Node) -> void:
	game = g
	ui = g.ui
	layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)


# ---------------------------------------------------------------- itens
func info(id: String) -> Dictionary:
	for f in game.FELTS:
		if str(f.id) == id:
			return {"cat": "MESA", "k": "felt", "d": f}
	for r in game.RAILS:
		if str(r.id) == id:
			return {"cat": "BORDA", "k": "rail", "d": r}
	for c in game.CUES + game.MONTHLY:
		if str(c.id) == id:
			return {"cat": "TACO", "k": "cue", "d": c}
	for c in game.ELITE:
		if str(c.id) == id:
			return {"cat": "TACO ELITE", "k": "cue", "d": c}
	for d in game.DECKS:
		if str(d.id) == id:
			return {"cat": "BARALHO", "k": "deck", "d": d}
	for w in game.WFX:
		if str(w.id) == id:
			return {"cat": "EFEITO", "k": "wfx", "d": w}
	return {}


func value(id: String) -> int:
	var i := info(id)
	if i.is_empty():
		return 0
	var d: Dictionary = i.d
	var v := int(d.get("price", 0))
	if v == 0 and d.has("pass"):
		v = int(d.pass) * 100
	return v


func offer_value(items: Array, coins: int) -> int:
	var t := coins
	for it in items:
		t += value(str(it))
	return t


func tradable() -> Array:
	var out: Array = []
	for id in game.save.owned:
		var s := str(id)
		if value(s) > 0 and not out.has(s):
			out.append(s)
	out.sort_custom(func(a, b): return value(a) > value(b))
	return out


func rare_col(id: String) -> Color:
	var i := info(id)
	if i.is_empty():
		return Color.WHITE
	if (i.d as Dictionary).has("rare"):
		return ui.rare_color(str(i.d.rare))
	var v := value(id)
	if v >= 10000:
		return Color("ffd34a")
	if v >= 3000:
		return Color("c77dff")
	if v >= 1000:
		return Color("5aa9ff")
	return Color("cfd8e3")


func fmt(n: int) -> String:
	var s := str(absi(n))
	var o := ""
	while s.length() > 3:
		o = "." + s.substr(s.length() - 3) + o
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + o


# ---------------------------------------------------------------- iniciar
func start_with(code: String, nm: String) -> void:
	if not game.net.server_ok:
		ui.say("Sem conexão com o servidor.")
		return
	if tradable().is_empty() and int(game.save.coins) <= 0:
		ui.say("Você ainda não tem itens para negociar.")
		return
	with_name = nm
	waiting = true
	tid = ""
	game.net.world_send({"t": "trade_req", "to": code.to_upper()})
	_build()


func on_msg(m: Dictionary) -> void:
	match str(m.t):
		"trade_invite":
			var id := str(m.id)
			var nm := str(m.get("name", "?"))
			ui.confirm("NEGOCIAÇÃO", "%s quer negociar com você!\nTrocar itens e moedas." % nm, "ABRIR", func():
				with_name = nm
				game.net.world_send({"t": "trade_resp", "id": id, "ok": true}), "RECUSAR", func():
				game.net.world_send({"t": "trade_resp", "id": id, "ok": false}))
		"trade_wait":
			tid = str(m.id)
			with_name = str(m.get("name", with_name))
			waiting = true
			_build()
		"trade":
			var first := tid != str(m.id) or waiting or root == null
			tid = str(m.id)
			st = m
			waiting = false
			with_name = str(m.get("withName", with_name))
			var mine: Dictionary = m.get("mine", {})
			my_items = (mine.get("items", []) as Array).duplicate()
			my_coins = int(mine.get("coins", 0))
			if first:
				ui.close_modal()
				_sent_has = false
				_build()
			else:
				_refresh()
			if not _sent_has:
				_sent_has = true
				game.net.world_send({"t": "trade_has", "id": tid, "owned": game.save.owned})
		"trade_end":
			var why := str(m.get("why", ""))
			close()
			if why != "":
				ui.confirm("NEGOCIAÇÃO", why, "OK", func(): pass, "", Callable())
		"trade_done":
			_done(m)


func _done(m: Dictionary) -> void:
	var give: Array = m.get("give", [])
	var got: Array = m.get("get", [])
	for it in give:
		game.save.owned.erase(str(it))
	for it in got:
		if not game.save.owned.has(str(it)):
			game.save.owned.append(str(it))
	# se deu o item que estava usando, volta para o padrão
	var owned: Array = game.save.owned
	if give.has(str(game.save.felt)):
		game.save.felt = DEFAULTS.felt
	if give.has(str(game.save.get("rail", ""))):
		game.save["rail"] = DEFAULTS.rail
	if give.has(str(game.save.cue)):
		game.save.cue = DEFAULTS.cue
	if give.has("dk_" + str(game.save.get("deck", ""))):
		game.save.deck = DEFAULTS.deck
	if give.has(str(game.save.get("wfx", ""))):
		game.save["wfx"] = DEFAULTS.wfx
	if not owned.has("verde"):
		owned.append("verde")
	if not owned.has("classico"):
		owned.append("classico")
	game.eco_result(m)
	game.write_save()
	game.apply_felt()
	game.net.send_hello()
	game.net.send_csave()
	ui.refresh_top()
	close()
	game.play_victory()
	var names: Array = []
	for it in got:
		names.append(str(info(str(it)).get("d", {}).get("name", it)))
	var gc := int(st.get("theirs", {}).get("coins", 0))
	if gc > 0:
		names.append("%s moedas" % fmt(gc))
	var msg := "Você recebeu: " + (", ".join(names) if not names.is_empty() else "nada") + "\nOs itens novos já estão no seu inventário."
	ui.confirm("TROCA FEITA! ✓", msg, "LEGAL!", func(): pass, "", Callable())


func close() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
	picker = null
	tid = ""
	st = {}
	waiting = false


func is_open() -> bool:
	return root != null and is_instance_valid(root)


func _cancel() -> void:
	if tid != "":
		game.net.world_send({"t": "trade_cancel", "id": tid})
	close()


# ---------------------------------------------------------------- tela
const AV = preload("res://avatars.gd")
var _my_list: HFlowContainer
var _their_list: HFlowContainer
var _my_scroll: ScrollContainer
var _their_scroll: ScrollContainer
var _top: Control
var _bal: Control
var _coin_lbl: Label
var _fair_lbl: Label
var _ready_btn: Button
var _conf_btn: Button
var _add_btn: Button
var _coin_btns: Array = []
var _anim: Control
var _cards: Array = []
var _scroll_end := false
var _sig := ""
var _pick_cat := ""
var _pick_row: HBoxContainer
var _pick_scroll: ScrollContainer
var _pick_tabs: Array = []


func _build() -> void:
	if is_open():
		root.queue_free()
	picker = null
	_sig = ""
	_cards.clear()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	_anim = bg
	bg.draw.connect(func():
		var t := Time.get_ticks_msec() / 1000.0
		var sz := bg.size
		bg.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.012, 0.025, 0.05, 0.97))
		bg.draw_circle(Vector2(sz.x * 0.25, sz.y * 0.55), sz.y * 0.75, Color(0.1, 0.8, 0.45, 0.035))
		bg.draw_circle(Vector2(sz.x * 0.75, sz.y * 0.55), sz.y * 0.75, Color(0.2, 0.5, 1.0, 0.035))
		for k in 22:
			var x := fposmod(k * 97.0 + t * 14.0 * (1 + k % 3), sz.x)
			var y := fposmod(k * 53.0 - t * 10.0 * (1 + k % 2), sz.y)
			bg.draw_circle(Vector2(x, y), 1.2 + k % 3, Color(1, 0.85, 0.3, 0.07 + 0.05 * sin(t * 2 + k))))
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + k, 26)
	mc.add_theme_constant_override("margin_top", 10)
	mc.add_theme_constant_override("margin_bottom", 12)
	root.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	mc.add_child(vb)
	# cabeçalho: você  ⇄  ele
	_top = Control.new()
	_top.custom_minimum_size = Vector2(0, 92)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_top)
	_top.draw.connect(_draw_top)
	if waiting:
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(sp)
		vb.add_child(ui.mk_lbl("Esperando %s aceitar a negociação..." % with_name, 28, Color.WHITE, 5))
		vb.add_child(ui.mk_lbl("Ele recebe um aviso na tela para ABRIR ou RECUSAR.", 18, Color(1, 1, 1, 0.6), 3))
		var sp2 := Control.new()
		sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(sp2)
		var cb: Button = ui.mk_btn("CANCELAR", 260, 64, ui.GRAY, 22)
		cb.pressed.connect(_cancel)
		vb.add_child(cb)
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	# --- você
	var lp := _col_panel(Color("3ddc84"))
	cols.add_child(lp)
	var lv: VBoxContainer = lp.get_child(0).get_child(0)
	_my_scroll = _mk_scroll()
	lv.add_child(_my_scroll)
	_my_list = _my_scroll.get_child(0)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 5)
	lv.add_child(crow)
	_coin_btns.clear()
	for dv in [-1000, -100]:
		crow.add_child(_coin_btn(dv))
	var cbox := PanelContainer.new()
	cbox.custom_minimum_size = Vector2(124, 44)
	cbox.add_theme_stylebox_override("panel", ui.sbox(Color(0.14, 0.1, 0.02, 0.95), 14, Color("ffd34a"), 2))
	_coin_lbl = ui.mk_lbl("0", 22, Color("ffd34a"), 4)
	cbox.add_child(_coin_lbl)
	crow.add_child(cbox)
	for dv in [100, 1000, 10000]:
		crow.add_child(_coin_btn(dv))
	_add_btn = ui.mk_btn("+  COLOCAR ITEM", 320, 52, Color("2f7fd6"), 21)
	_add_btn.pressed.connect(_open_picker)
	lv.add_child(_add_btn)
	# --- ele
	var rp := _col_panel(Color("5aa9ff"))
	cols.add_child(rp)
	var rv: VBoxContainer = rp.get_child(0).get_child(0)
	_their_scroll = _mk_scroll()
	rv.add_child(_their_scroll)
	_their_list = _their_scroll.get_child(0)
	var hint: Label = ui.mk_lbl("O que %s colocar aparece aqui na hora.\nToque num item seu para tirar da troca." % with_name, 15, Color(1, 1, 1, 0.45), 2)
	hint.custom_minimum_size = Vector2(0, 110)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rv.add_child(hint)
	# --- balança (justa / desigual)
	_bal = Control.new()
	_bal.custom_minimum_size = Vector2(0, 26)
	_bal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_bal)
	_bal.draw.connect(_draw_bal)
	_fair_lbl = ui.mk_lbl("", 17, Color.WHITE, 3)
	vb.add_child(_fair_lbl)
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 16)
	vb.add_child(brow)
	var cb2: Button = ui.mk_btn("CANCELAR", 220, 62, ui.GRAY, 20)
	cb2.pressed.connect(func(): _ask("CANCELAR?", "Sair da negociação?", "SAIR", _cancel))
	brow.add_child(cb2)
	_ready_btn = ui.mk_btn("✓  PRONTO", 250, 62, Color("1b8f4c"), 22)
	_ready_btn.pressed.connect(func():
		game.net.world_send({"t": "trade_ready", "id": tid, "v": not bool(st.get("ready", false))}))
	brow.add_child(_ready_btn)
	_conf_btn = ui.mk_btn("⇄  CONFIRMAR TROCA", 320, 62, Color("d68a10"), 22)
	_conf_btn.pressed.connect(_confirm)
	brow.add_child(_conf_btn)
	_refresh()


func _mk_scroll() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var fl := HFlowContainer.new()
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.add_theme_constant_override("h_separation", 8)
	fl.add_theme_constant_override("v_separation", 8)
	sc.add_child(fl)
	return sc


func _status(rdy: bool, conf: bool) -> Array:
	if conf:
		return ["✓ CONFIRMOU", Color("ffd34a")]
	if rdy:
		return ["✓ PRONTO", Color("3ddc84")]
	return ["montando a oferta...", Color(1, 1, 1, 0.5)]


func _draw_top() -> void:
	var c := _top
	var f: Font = ThemeDB.fallback_font
	var t := Time.get_ticks_msec() / 1000.0
	var w := c.size.x
	var cx := w / 2.0
	c.draw_style_box(ui.sbox(Color(0.03, 0.07, 0.11, 0.9), 22, Color(1, 0.83, 0.3, 0.35), 2), Rect2(0, 4, w, 84))
	var me := [str(game.save.get("av", "b8")), str(game.save.get("frame", "simples"))]
	AV.draw(c, Vector2(52, 46), 32, me[0], me[1], t)
	c.draw_string(f, Vector2(96, 40), "VOCÊ", HORIZONTAL_ALIGNMENT_LEFT, 300, 24, Color("3ddc84"))
	var s1: Array = _status(bool(st.get("ready", false)), bool(st.get("conf", false))) if not waiting else ["", Color.WHITE]
	c.draw_string(f, Vector2(96, 66), str(s1[0]), HORIZONTAL_ALIGNMENT_LEFT, 300, 16, s1[1])
	AV.draw(c, Vector2(w - 52, 46), 32, str(st.get("withAv", "b8")), str(st.get("withFr", "simples")), t)
	c.draw_string(f, Vector2(w - 396, 40), with_name.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 300, 24, Color("8fd0ff"))
	var s2: Array = _status(bool(st.get("theirReady", false)), bool(st.get("theirConf", false))) if not waiting else ["esperando aceitar...", Color(1, 1, 1, 0.5)]
	c.draw_string(f, Vector2(w - 396, 66), str(s2[0]), HORIZONTAL_ALIGNMENT_RIGHT, 300, 16, s2[1])
	# medalhão do meio com as setas girando
	var mc := Vector2(cx, 46)
	c.draw_circle(mc, 40, Color(1, 0.8, 0.2, 0.12 + 0.05 * sin(t * 3)))
	c.draw_circle(mc, 33, Color("2a1c04"))
	c.draw_arc(mc, 33, 0, TAU, 40, Color("ffd34a"), 3.0)
	for k in 2:
		var a0 := t * 1.6 + k * PI
		c.draw_arc(mc, 24, a0, a0 + 2.2, 18, Color("ffe08a"), 4.0)
		var tip := mc + Vector2.from_angle(a0 + 2.2) * 24
		var dir := Vector2.from_angle(a0 + 2.2 + PI / 2)
		var nrm := Vector2.from_angle(a0 + 2.2)
		c.draw_colored_polygon(PackedVector2Array([tip + dir * 8, tip + nrm * 7, tip - nrm * 7]), Color("ffe08a"))
	c.draw_string(f, Vector2(cx - 250, 54), "NEGOCIAÇÃO", HORIZONTAL_ALIGNMENT_RIGHT, 190, 22, Color("f4c542"))
	c.draw_string(f, Vector2(cx + 56, 54), "TROCA SEGURA", HORIZONTAL_ALIGNMENT_LEFT, 200, 15, Color(1, 0.85, 0.4, 0.75))


func _vals() -> Array:
	var th: Dictionary = st.get("theirs", {})
	return [offer_value(my_items, my_coins), offer_value(th.get("items", []), int(th.get("coins", 0)))]


func _draw_bal() -> void:
	var c := _bal
	var f: Font = ThemeDB.fallback_font
	var v := _vals()
	var mv: int = v[0]
	var tv: int = v[1]
	var w := c.size.x
	var bx := 230.0
	var bw := w - bx * 2
	c.draw_string(f, Vector2(0, 19), "VOCÊ DÁ  %s" % fmt(mv), HORIZONTAL_ALIGNMENT_RIGHT, bx - 14, 17, Color("3ddc84"))
	c.draw_string(f, Vector2(w - bx + 14, 19), "%s  VOCÊ RECEBE" % fmt(tv), HORIZONTAL_ALIGNMENT_LEFT, bx, 17, Color("8fd0ff"))
	c.draw_style_box(ui.sbox(Color(0.08, 0.1, 0.14), 8), Rect2(bx, 6, bw, 14))
	var tot := float(mv + tv)
	var fr := 0.5 if tot <= 0 else float(mv) / tot
	# zona justa: cada lado recebe ≥25% do que dá  =>  fr entre 0.2 e 0.8
	c.draw_style_box(ui.sbox(Color(0.2, 0.75, 0.4, 0.28), 6), Rect2(bx + bw * 0.2, 6, bw * 0.6, 14))
	var ok := fair_msg(mv, tv) == ""
	var mx := bx + bw * fr
	c.draw_circle(Vector2(mx, 13), 11, Color("3ddc84") if ok else Color("ff6a4a"))
	c.draw_circle(Vector2(mx, 13), 6, Color.WHITE)


func _process(_d: float) -> void:
	if is_open():
		ui.fx_t += _d
		if _anim != null and is_instance_valid(_anim):
			_anim.queue_redraw()
		if _top != null and is_instance_valid(_top):
			_top.queue_redraw()
		var keep: Array = []
		for c in _cards:
			if is_instance_valid(c):
				(c as Control).queue_redraw()
				keep.append(c)
		_cards = keep


func _col_panel(col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.025, 0.05, 0.085, 0.96), 22, Color(col.r, col.g, col.b, 0.55), 3, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(ui.margin(v, 12))
	return p


func _coin_btn(dv: int) -> Button:
	var b: Button = ui.mk_btn(("+" if dv > 0 else "−") + (str(absi(dv) / 1000) + "k" if absi(dv) >= 1000 else str(absi(dv))), 70, 44, Color("8a6a10") if dv > 0 else Color("5a3a3a"), 17)
	b.pressed.connect(func():
		var nv := clampi(my_coins + dv, 0, int(game.save.coins))
		if dv > 0 and my_coins + dv > int(game.save.coins):
			ui.say("Você só tem %s moedas." % fmt(int(game.save.coins)))
		if nv != my_coins:
			my_coins = nv
			_scroll_end = true
			_send_offer())
	_coin_btns.append(b)
	return b


func _send_offer() -> void:
	game.net.world_send({"t": "trade_set", "id": tid, "items": my_items, "coins": my_coins})
	_refresh()


# toque sem arrastar (deixa a lista rolar com o dedo sem escolher item sem querer)
func _tap(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := e as InputEventMouseButton
			if mb.pressed:
				c.set_meta("tp", mb.global_position)
				c.set_meta("tt", Time.get_ticks_msec())
			elif c.has_meta("tp"):
				var d: float = (mb.global_position - (c.get_meta("tp") as Vector2)).length()
				var dt: int = Time.get_ticks_msec() - int(c.get_meta("tt"))
				c.remove_meta("tp")
				if d < 16.0 and dt < 700:
					game.play("click", 0.6)
					cb.call())


# prévia igual à da loja (taco com o efeito, mesa com a borda e brilho, baralho, efeito de vitória)
func preview(id: String, w: float, h: float) -> Control:
	var i := info(id)
	var d: Dictionary = i.get("d", {})
	var rc := rare_col(id)
	var box := Control.new()
	box.custom_minimum_size = Vector2(w, h)
	box.size = Vector2(w, h)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Control.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(glow)
	glow.draw.connect(func():
		var t := Time.get_ticks_msec() / 1000.0
		glow.draw_style_box(ui.sbox(Color(0.01, 0.02, 0.05, 0.85), 12), Rect2(Vector2.ZERO, Vector2(w, h)))
		var pulse := 0.08 + 0.04 * sin(t * 2.4)
		glow.draw_circle(Vector2(w * 0.62, h * 0.4), h * 0.62, Color(rc.r, rc.g, rc.b, pulse))
		glow.draw_circle(Vector2(w * 0.62, h * 0.4), h * 0.36, Color(rc.r, rc.g, rc.b, pulse)))
	_cards.append(glow)
	var pv := Control.new()
	pv.size = Vector2(184, 150)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := minf(w / 184.0, h / 150.0)
	pv.scale = Vector2(k, k)
	pv.position = Vector2((w - 184 * k) / 2.0, (h - 150 * k) / 2.0)
	box.add_child(pv)
	var store: Array = []
	match str(i.get("k", "")):
		"cue":
			ui._cue_preview(pv, d, Vector2(84, 86), 148.0, -32.0, 22.0, 0.8, store)
		"deck":
			ui._deck_preview(pv, str(d.deck))
		"wfx":
			ui._wfx_preview(pv, str(d.wfx))
		"rail":
			ui._rail_preview(pv, d, game.felt_def())
		"felt":
			ui._rail_preview(pv, game.rail_for(str(d.get("rail", ""))), d)
	for ch in pv.get_children():
		if ch is Control:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_cards.append(ch)
	if d.has("rare"):
		var rt: Label = ui.mk_lbl(str(d.rare), 13, ui.rare_color(str(d.rare)), 4)
		rt.position = Vector2(6, 2)
		box.add_child(rt)
	return box


func _item_card(id: String, mine: bool, w: float = 136.0, h: float = 168.0) -> Control:
	var rc := rare_col(id)
	var i := info(id)
	var d: Dictionary = i.get("d", {})
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(w, h)
	card.add_theme_stylebox_override("panel", ui.sbox(Color(0.05, 0.08, 0.14, 0.97), 14, Color(rc.r, rc.g, rc.b, 0.85), 2, 4))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ui.margin(vb, 5))
	var cat: Label = ui.mk_lbl(str(i.get("cat", "")), 11 if w < 180 else 13, Color(rc.r, rc.g, rc.b, 0.95), 2)
	cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cat)
	var pw := w - 10
	var ph := h - 70 if w < 180 else 200.0
	vb.add_child(preview(id, pw, ph))
	var nm: Label = ui.mk_lbl(str(d.get("name", id)), 14 if w < 180 else 19, Color.WHITE, 3)
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(pw, 0)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	var vl: Label = ui.mk_lbl("valor " + fmt(value(id)), 12 if w < 180 else 15, Color("ffd34a"), 2)
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(vl)
	if w >= 180:
		if str(i.get("k", "")) == "cue":
			for sr in [["Mira", "aim"], ["Força", "pow"], ["Precisão", "prec"], ["Efeito", "spin"]]:
				var row: Control = ui._stat_row(str(sr[0]), float(d.get(sr[1], 0)))
				row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vb.add_child(row)
		else:
			var tg: Label = ui.mk_lbl(str(d.get("tag", "")), 15, Color(1, 1, 1, 0.65), 2)
			tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tg.custom_minimum_size = Vector2(pw, 0)
			tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(tg)
	if mine:
		var x := Control.new()
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		x.draw.connect(func():
			var p := Vector2(w - 14, 14)
			x.draw_circle(p, 11, Color("c94444"))
			x.draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), Color.WHITE, 2.5)
			x.draw_line(p + Vector2(5, -5), p + Vector2(-5, 5), Color.WHITE, 2.5))
		card.add_child(x)
		_tap(card, func():
			my_items.erase(id)
			_send_offer())
	else:
		card.mouse_filter = Control.MOUSE_FILTER_PASS
	return card


func _coin_card(n: int) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(136, 168)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.16, 0.12, 0.02, 0.97), 14, Color("ffd34a"), 2, 4))
	var cv := Control.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cv)
	cv.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		var t := Time.get_ticks_msec() / 1000.0
		cv.draw_circle(Vector2(68, 64), 52, Color(1, 0.8, 0.2, 0.1 + 0.05 * sin(t * 3)))
		for k in 3:
			var c := Vector2(48 + k * 18, 76 - k * 12 + sin(t * 2 + k) * 2)
			cv.draw_circle(c, 25, Color("b8860b"))
			cv.draw_circle(c, 21, Color("ffd34a"))
			cv.draw_arc(c, 16, PI * 1.1, PI * 1.7, 8, Color(1, 1, 1, 0.6), 2.0)
			cv.draw_string(f, c + Vector2(-7, 8), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8a5c0c"))
		cv.draw_string(f, Vector2(0, 136), fmt(n), HORIZONTAL_ALIGNMENT_CENTER, 136, 22, Color.WHITE)
		cv.draw_string(f, Vector2(0, 156), "MOEDAS", HORIZONTAL_ALIGNMENT_CENTER, 136, 12, Color("ffd34a")))
	_cards.append(cv)
	return p


func _refresh() -> void:
	if not is_open() or waiting or _my_list == null or not is_instance_valid(_my_list):
		return
	var th: Dictionary = st.get("theirs", {})
	var t_items: Array = th.get("items", [])
	var t_coins := int(th.get("coins", 0))
	# só redesenha as listas quando mudam (assim a animação e a rolagem não pulam)
	var sig := JSON.stringify([my_items, my_coins, t_items, t_coins])
	if sig != _sig:
		var grew_t := t_items.size() + (1 if t_coins > 0 else 0) > _their_list.get_child_count() and _sig != ""
		_sig = sig
		for ch in _my_list.get_children():
			ch.queue_free()
		for ch in _their_list.get_children():
			ch.queue_free()
		for it in my_items:
			_my_list.add_child(_item_card(str(it), true))
		if my_coins > 0:
			_my_list.add_child(_coin_card(my_coins))
		if my_items.is_empty() and my_coins == 0:
			_my_list.add_child(_empty_lbl("Toque em  + COLOCAR ITEM\nou coloque moedas"))
		for it in t_items:
			_their_list.add_child(_item_card(str(it), false))
		if t_coins > 0:
			_their_list.add_child(_coin_card(t_coins))
		if t_items.is_empty() and t_coins == 0:
			_their_list.add_child(_empty_lbl("%s ainda não colocou nada" % with_name))
		if _scroll_end:
			_scroll_end = false
			_to_end.call_deferred(_my_scroll)
		if grew_t:
			_to_end.call_deferred(_their_scroll)
	var v := _vals()
	var mv: int = v[0]
	var tv: int = v[1]
	var rdy := bool(st.get("ready", false))
	var trdy := bool(st.get("theirReady", false))
	var conf := bool(st.get("conf", false))
	_coin_lbl.text = fmt(my_coins)
	var why := fair_msg(mv, tv)
	if why != "":
		_fair_lbl.text = "⚠ " + why
		_fair_lbl.add_theme_color_override("font_color", Color("ff8a6a"))
	elif conf:
		_fair_lbl.text = "Você confirmou. Esperando %s confirmar..." % with_name
		_fair_lbl.add_theme_color_override("font_color", Color("ffd34a"))
	elif rdy and trdy:
		_fair_lbl.text = "Os dois estão prontos! Confira tudo e toque em CONFIRMAR TROCA."
		_fair_lbl.add_theme_color_override("font_color", Color("3ddc84"))
	else:
		_fair_lbl.text = "Montem a troca e toquem em PRONTO. Se alguém mudar algo, o PRONTO dos dois sai."
		_fair_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_ready_btn.text = "TIRAR PRONTO" if rdy else "✓  PRONTO"
	_ready_btn.disabled = why != "" or conf
	_conf_btn.disabled = not (rdy and trdy) or conf or why != ""
	_add_btn.disabled = conf
	for b in _coin_btns:
		(b as Button).disabled = conf
	if _bal != null:
		_bal.queue_redraw()


func _empty_lbl(t: String) -> Label:
	var l: Label = ui.mk_lbl(t, 16, Color(1, 1, 1, 0.42), 2)
	l.custom_minimum_size = Vector2(520, 150)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _to_end(sc: ScrollContainer) -> void:
	if sc == null or not is_instance_valid(sc):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


func fair_msg(mv: int, tv: int) -> String:
	if mv == 0 and tv == 0:
		return "Coloque alguma coisa na troca."
	if tv < ceili(mv * MIN_PCT):
		return "Troca muito desigual: você precisa receber pelo menos %s (25%% do que está dando)." % fmt(ceili(mv * MIN_PCT))
	if mv < ceili(tv * MIN_PCT):
		return "Troca muito desigual: %s precisa receber pelo menos %s (25%% do que dá)." % [with_name, fmt(ceili(tv * MIN_PCT))]
	return ""


func _confirm() -> void:
	var th: Dictionary = st.get("theirs", {})
	var names: Array = []
	for it in th.get("items", []):
		names.append(str(info(str(it)).get("d", {}).get("name", it)))
	if int(th.get("coins", 0)) > 0:
		names.append("%s moedas" % fmt(int(th.get("coins", 0))))
	var gv: Array = []
	for it in my_items:
		gv.append(str(info(str(it)).get("d", {}).get("name", it)))
	if my_coins > 0:
		gv.append("%s moedas" % fmt(my_coins))
	var msg := "Você DÁ: %s\nVocê RECEBE: %s\n\nA troca NÃO pode ser desfeita." % [", ".join(gv) if not gv.is_empty() else "nada", ", ".join(names) if not names.is_empty() else "nada"]
	_ask("CONFIRMAR TROCA?", msg, "CONFIRMAR", func():
		game.net.send_eco()
		game.net.world_send({"t": "trade_confirm", "id": tid, "tok": game.my_tok(), "owned": game.save.owned}))


# pergunta por cima da tela de troca
func _ask(title: String, msg: String, yes: String, cb: Callable) -> void:
	if not is_open():
		return
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(ov)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.7)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.02, 0.05, 0.08, 0.98), 26, Color("f4c542"), 3, 20))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	p.add_child(ui.margin(vb, 24))
	vb.add_child(ui.mk_lbl(title, 32, Color("f4c542"), 6))
	var ml: Label = ui.mk_lbl(msg, 20, Color(1, 1, 1, 0.9), 2) as Label
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size = Vector2(620, 0)
	vb.add_child(ml)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var by: Button = ui.mk_btn(yes, 220, 60, Color("1b8f4c") if yes != "SAIR" else Color("c94444"), 22) as Button
	by.pressed.connect(func():
		ov.queue_free()
		cb.call())
	row.add_child(by)
	var bn: Button = ui.mk_btn("VOLTAR", 220, 60, Color("3b4556"), 20) as Button
	bn.pressed.connect(func(): ov.queue_free())
	row.add_child(bn)


# ---------------------------------------------------------------- escolher item
const PICK_CATS := [["", "TODOS"], ["cue", "TACOS"], ["felt", "MESAS"], ["rail", "BORDAS"], ["deck", "BARALHOS"], ["wfx", "EFEITOS"]]


func _open_picker() -> void:
	if picker != null and is_instance_valid(picker):
		picker.queue_free()
	picker = Control.new()
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(picker)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.8)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.add_child(dimr)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + k, 30)
	for k in ["top", "bottom"]:
		mc.add_theme_constant_override("margin_" + k, 24)
	picker.add_child(mc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.02, 0.045, 0.08, 0.98), 24, Color("5aa9ff"), 3, 16))
	mc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(ui.margin(vb, 16))
	vb.add_child(ui.mk_lbl("ESCOLHA O QUE OFERECER", 30, Color("8fd0ff"), 6))
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	_pick_tabs.clear()
	for c in PICK_CATS:
		var n := _count_cat(str(c[0]))
		var tb: Button = ui.mk_btn("%s (%d)" % [c[1], n], 160, 46, Color("2f7fd6"), 17)
		var key := str(c[0])
		tb.set_meta("k", key)
		tb.disabled = n == 0
		tb.pressed.connect(func(): _pick_show(key))
		tabs.add_child(tb)
		_pick_tabs.append(tb)
	_pick_scroll = ScrollContainer.new()
	_pick_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pick_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vb.add_child(_pick_scroll)
	_pick_row = HBoxContainer.new()
	_pick_row.add_theme_constant_override("separation", 14)
	_pick_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pick_scroll.add_child(_pick_row)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	vb.add_child(foot)
	foot.add_child(ui.mk_lbl("Arraste para o lado para ver mais  •  toque no item para colocar", 15, Color(1, 1, 1, 0.5), 2))
	var bc: Button = ui.mk_btn("VOLTAR", 200, 54, ui.GRAY, 20)
	bc.pressed.connect(func():
		picker.queue_free()
		picker = null)
	foot.add_child(bc)
	_pick_show(_pick_cat if _count_cat(_pick_cat) > 0 else "")


func _count_cat(k: String) -> int:
	var n := 0
	for id in tradable():
		if my_items.has(id):
			continue
		if k == "" or str(info(id).get("k", "")) == k:
			n += 1
	return n


func _pick_show(k: String) -> void:
	_pick_cat = k
	for tb in _pick_tabs:
		var on: bool = str((tb as Button).get_meta("k")) == k
		var col := Color("e3a928") if on else Color("23364f")
		(tb as Button).add_theme_stylebox_override("normal", ui.sbox(col, 20, col.lightened(0.35), 3, 6))
	for ch in _pick_row.get_children():
		ch.queue_free()
	_pick_scroll.scroll_horizontal = 0
	var has: Array = st.get("theirHas", [])
	var n := 0
	for id in tradable():
		if my_items.has(id):
			continue
		if k != "" and str(info(id).get("k", "")) != k:
			continue
		n += 1
		var sid := str(id)
		var card := _item_card(sid, false, 228.0, 330.0)
		if has.has(sid):
			var dim := ColorRect.new()
			dim.color = Color(0, 0, 0, 0.6)
			dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(dim)
			var tag: Label = ui.mk_lbl("%s JÁ TEM" % with_name.to_upper(), 17, Color("ff8a6a"), 5)
			tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			tag.position = Vector2(0, 140)
			tag.size = Vector2(228, 30)
			card.add_child(tag)
		else:
			_tap(card, func():
				if my_items.size() >= 30 or my_items.has(sid):
					return
				my_items.append(sid)
				_scroll_end = true
				if picker != null and is_instance_valid(picker):
					picker.queue_free()
				picker = null
				_send_offer())
		_pick_row.add_child(card)
	if n == 0:
		var l: Label = ui.mk_lbl("Você não tem mais itens para oferecer aqui.\n(Itens grátis, como a mesa verde e o taco clássico, não entram.)", 18, Color(1, 1, 1, 0.6), 2)
		l.custom_minimum_size = Vector2(900, 300)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_pick_row.add_child(l)
