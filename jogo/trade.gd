extends Node
# NEGOCIAÇÃO entre amigos: cada um coloca itens (mesa, borda, taco, baralho, efeito) e moedas,
# os dois marcam PRONTO e depois CONFIRMAR. O servidor confere tudo (senha do aparelho, saldo,
# se cada um tem o que oferece e se a troca não é desigual demais: cada lado recebe pelo menos 25%
# do valor do que dá) e só aí troca. Quem dá um item pode comprar de novo na loja depois.

const MIN_PCT := 0.25
const DEFAULTS := {"felt": "verde", "rail": "rb_padrao", "cue": "classico", "deck": "classico", "wfx": "wf_confete"}
const DECK_COL := {"classico": Color("2f6fd6"), "esmeralda": Color("1f8a55"), "neon": Color("ff3df0"), "preto": Color("222228"), "ouro": Color("e3b341")}

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


# desenho pequeno do item (mesa, borda, taco, baralho, efeito)
func swatch(c: Control, id: String, r: Rect2, t: float) -> void:
	var i := info(id)
	if i.is_empty():
		return
	var d: Dictionary = i.d
	var cen := r.get_center()
	match str(i.k):
		"felt":
			var l: Color = d.get("light", Color("22a553"))
			var dk: Color = d.get("dark", Color("06512b"))
			c.draw_style_box(ui.sbox(Color("4a2a14"), 8), r)
			var inner := r.grow(-5)
			c.draw_style_box(ui.sbox(dk, 5), inner)
			c.draw_circle(inner.get_center(), inner.size.y * 0.42, l.lerp(dk, 0.25))
			c.draw_circle(inner.get_center(), inner.size.y * 0.25, l)
			if d.has("anim"):
				for k in 3:
					var a := t * 1.4 + k * 2.1
					c.draw_circle(inner.get_center() + Vector2(cos(a) * inner.size.x * 0.32, sin(a * 1.3) * inner.size.y * 0.3), 2.0, Color(1, 1, 1, 0.8))
		"rail":
			var c1: Color = d.get("c1", Color("6b4226"))
			var tr: Color = d.get("trim", Color("d9b36a"))
			c.draw_style_box(ui.sbox(c1, 9, tr, 3), r)
			c.draw_style_box(ui.sbox(Color("1a7a45"), 5), r.grow(-9))
			if d.has("edge"):
				var a2 := fposmod(t * 0.6, 1.0)
				var pp := r.position + Vector2(r.size.x * a2, 2)
				c.draw_circle(pp, 3.0, tr.lightened(0.4))
		"cue":
			var y := cen.y
			var x0 := r.position.x + 4
			var x1 := r.end.x - 4
			var glow: Color = d.get("glow", Color(0, 0, 0, 0))
			if glow.a > 0:
				c.draw_line(Vector2(x0, y), Vector2(x1, y), Color(glow.r, glow.g, glow.b, 0.25 + 0.15 * sin(t * 3)), 12.0)
			c.draw_line(Vector2(x0, y), Vector2(x0 + (x1 - x0) * 0.55, y), d.get("shaft", Color("ecd29c")), 5.0)
			c.draw_line(Vector2(x0 + (x1 - x0) * 0.55, y), Vector2(x1, y), d.get("butt", Color("5a2e14")), 8.0)
			if d.has("butt2"):
				c.draw_line(Vector2(x0 + (x1 - x0) * 0.72, y), Vector2(x0 + (x1 - x0) * 0.86, y), d.butt2, 8.0)
			c.draw_line(Vector2(x0 + (x1 - x0) * 0.55, y - 4), Vector2(x0 + (x1 - x0) * 0.55, y + 4), d.get("ring", Color("c9a24a")), 3.0)
			c.draw_line(Vector2(x0, y), Vector2(x0 + 4, y), Color("4aa3ff"), 5.0)
		"deck":
			var col: Color = DECK_COL.get(str(d.get("deck", "")), Color("2f6fd6"))
			for k in 2:
				var rr := Rect2(cen + Vector2(-14 + k * 10, -20 + k * 2), Vector2(24, 34))
				c.draw_style_box(ui.sbox(Color.WHITE, 4, Color(0, 0, 0, 0.3), 1), rr)
				c.draw_style_box(ui.sbox(col, 3), rr.grow(-3))
		"wfx":
			for k in 5:
				var a3 := t * 2.0 + k * TAU / 5.0
				var pc := cen + Vector2(cos(a3), sin(a3)) * r.size.y * 0.3
				c.draw_circle(pc, 3.5, Color.from_hsv(fposmod(k * 0.2 + t * 0.2, 1.0), 0.6, 1.0))
			c.draw_circle(cen, 6, Color("ffe066"))


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
var _my_list: HFlowContainer
var _their_list: HFlowContainer
var _my_head: Label
var _their_head: Label
var _coin_lbl: Label
var _fair_lbl: Label
var _ready_btn: Button
var _conf_btn: Button
var _add_btn: Button
var _coin_btns: Array = []
var _anim: Control
var _cards: Array = []


func _build() -> void:
	if is_open():
		root.queue_free()
	picker = null
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.03, 0.06, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_anim = Control.new()
	_anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_anim)
	_anim.draw.connect(func():
		var t := Time.get_ticks_msec() / 1000.0
		var sz := _anim.size
		for k in 14:
			var x := fposmod(k * 97.0 + t * 18.0 * (1 + k % 3), sz.x)
			var y := fposmod(k * 53.0 - t * 12.0, sz.y)
			_anim.draw_circle(Vector2(x, y), 1.5 + k % 3, Color(1, 0.85, 0.3, 0.08)))
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + k, 30)
	mc.add_theme_constant_override("margin_top", 18)
	mc.add_theme_constant_override("margin_bottom", 16)
	root.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	mc.add_child(vb)
	vb.add_child(ui.mk_lbl("⇄  NEGOCIAÇÃO COM  %s" % with_name.to_upper(), 34, Color("f4c542"), 7))
	if waiting:
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(sp)
		vb.add_child(ui.mk_lbl("Esperando %s aceitar a negociação..." % with_name, 26, Color.WHITE, 4))
		var sp2 := Control.new()
		sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(sp2)
		var cb: Button = ui.mk_btn("CANCELAR", 260, 64, ui.GRAY, 22)
		cb.pressed.connect(_cancel)
		vb.add_child(cb)
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	# --- você
	var lp := _col_panel(Color("3ddc84"))
	cols.add_child(lp)
	var lv: VBoxContainer = lp.get_child(0).get_child(0)
	_my_head = ui.mk_lbl("", 22, Color("3ddc84"), 4)
	lv.add_child(_my_head)
	var ls := ScrollContainer.new()
	ls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(ls)
	_my_list = HFlowContainer.new()
	_my_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_my_list.add_theme_constant_override("h_separation", 8)
	_my_list.add_theme_constant_override("v_separation", 8)
	ls.add_child(_my_list)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 6)
	lv.add_child(crow)
	_coin_btns.clear()
	for dv in [-1000, -100]:
		crow.add_child(_coin_btn(dv))
	_coin_lbl = ui.mk_lbl("0", 24, Color("ffd34a"), 4)
	_coin_lbl.custom_minimum_size = Vector2(130, 0)
	crow.add_child(_coin_lbl)
	for dv in [100, 1000, 10000]:
		crow.add_child(_coin_btn(dv))
	_add_btn = ui.mk_btn("+ COLOCAR ITEM", 300, 52, Color("2f7fd6"), 20)
	_add_btn.pressed.connect(_open_picker)
	lv.add_child(_add_btn)
	# --- ele
	var rp := _col_panel(Color("5aa9ff"))
	cols.add_child(rp)
	var rv: VBoxContainer = rp.get_child(0).get_child(0)
	_their_head = ui.mk_lbl("", 22, Color("8fd0ff"), 4)
	rv.add_child(_their_head)
	var rs := ScrollContainer.new()
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(rs)
	_their_list = HFlowContainer.new()
	_their_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_their_list.add_theme_constant_override("h_separation", 8)
	_their_list.add_theme_constant_override("v_separation", 8)
	rs.add_child(_their_list)
	# --- rodapé
	_fair_lbl = ui.mk_lbl("", 18, Color.WHITE, 3)
	vb.add_child(_fair_lbl)
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 16)
	vb.add_child(brow)
	var cb2: Button = ui.mk_btn("CANCELAR", 220, 62, ui.GRAY, 20)
	cb2.pressed.connect(func(): _ask("CANCELAR?", "Sair da negociação?", "SAIR", _cancel))
	brow.add_child(cb2)
	_ready_btn = ui.mk_btn("PRONTO", 240, 62, Color("1b8f4c"), 22)
	_ready_btn.pressed.connect(func():
		game.net.world_send({"t": "trade_ready", "id": tid, "v": not bool(st.get("ready", false))}))
	brow.add_child(_ready_btn)
	_conf_btn = ui.mk_btn("CONFIRMAR TROCA", 300, 62, Color("d68a10"), 22)
	_conf_btn.pressed.connect(_confirm)
	brow.add_child(_conf_btn)
	_refresh()


func _process(_d: float) -> void:
	if is_open():
		if _anim != null and is_instance_valid(_anim):
			_anim.queue_redraw()
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
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.03, 0.06, 0.1, 0.95), 22, Color(col.r, col.g, col.b, 0.6), 3, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(ui.margin(v, 14))
	return p


func _coin_btn(dv: int) -> Button:
	var b: Button = ui.mk_btn(("+" if dv > 0 else "−") + (str(absi(dv) / 1000) + "k" if absi(dv) >= 1000 else str(absi(dv))), 78, 46, Color("8a6a10") if dv > 0 else Color("5a3a3a"), 17)
	b.pressed.connect(func():
		var nv := clampi(my_coins + dv, 0, int(game.save.coins))
		if dv > 0 and my_coins + dv > int(game.save.coins):
			ui.say("Você só tem %s moedas." % fmt(int(game.save.coins)))
		if nv != my_coins:
			my_coins = nv
			_send_offer())
	_coin_btns.append(b)
	return b


func _send_offer() -> void:
	game.net.world_send({"t": "trade_set", "id": tid, "items": my_items, "coins": my_coins})
	_refresh()


func _item_card(id: String, mine: bool) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 118)
	var rc := rare_col(id)
	b.add_theme_stylebox_override("normal", ui.sbox(Color(0.06, 0.1, 0.16, 0.95), 14, Color(rc.r, rc.g, rc.b, 0.75), 2, 4))
	b.add_theme_stylebox_override("hover", ui.sbox(Color(0.09, 0.14, 0.22, 0.95), 14, rc, 3, 4))
	b.add_theme_stylebox_override("pressed", ui.sbox(Color(0.04, 0.07, 0.12, 0.95), 14, rc, 2, 0))
	b.add_theme_stylebox_override("disabled", ui.sbox(Color(0.06, 0.1, 0.16, 0.95), 14, Color(rc.r, rc.g, rc.b, 0.75), 2, 4))
	var i := info(id)
	var nm := str(i.get("d", {}).get("name", id))
	var cat := str(i.get("cat", ""))
	var v := value(id)
	var cv := Control.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cv)
	cv.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		var t := Time.get_ticks_msec() / 1000.0
		cv.draw_string(f, Vector2(0, 16), cat, HORIZONTAL_ALIGNMENT_CENTER, 150, 11, Color(rc.r, rc.g, rc.b, 0.9))
		swatch(cv, id, Rect2(25, 22, 100, 46), t)
		cv.draw_string(f, Vector2(4, 88), nm, HORIZONTAL_ALIGNMENT_CENTER, 142, 15, Color.WHITE)
		cv.draw_string(f, Vector2(0, 108), "valor %s" % fmt(v), HORIZONTAL_ALIGNMENT_CENTER, 150, 12, Color("ffd34a"))
		if mine:
			cv.draw_circle(Vector2(138, 12), 9, Color("c94444"))
			cv.draw_line(Vector2(134, 8), Vector2(142, 16), Color.WHITE, 2.0)
			cv.draw_line(Vector2(142, 8), Vector2(134, 16), Color.WHITE, 2.0)
		pass)
	_cards.append(cv)
	if mine:
		b.pressed.connect(func():
			my_items.erase(id)
			_send_offer())
	return b


func _coin_card(n: int) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(150, 118)
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.16, 0.12, 0.02, 0.95), 14, Color("ffd34a"), 2, 4))
	var cv := Control.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cv)
	cv.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		for k in 3:
			var c := Vector2(60 + k * 14, 46 - k * 6)
			cv.draw_circle(c, 18, Color("b8860b"))
			cv.draw_circle(c, 15, Color("ffd34a"))
			cv.draw_string(f, c + Vector2(-5, 6), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("8a5c0c"))
		cv.draw_string(f, Vector2(0, 92), fmt(n), HORIZONTAL_ALIGNMENT_CENTER, 150, 20, Color.WHITE)
		cv.draw_string(f, Vector2(0, 110), "moedas", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, Color("ffd34a")))
	return p


func _refresh() -> void:
	if not is_open() or waiting or _my_list == null or not is_instance_valid(_my_list):
		return
	for ch in _my_list.get_children():
		ch.queue_free()
	for ch in _their_list.get_children():
		ch.queue_free()
	for it in my_items:
		_my_list.add_child(_item_card(str(it), true))
	if my_coins > 0:
		_my_list.add_child(_coin_card(my_coins))
	if my_items.is_empty() and my_coins == 0:
		_my_list.add_child(ui.mk_lbl("Toque em + COLOCAR ITEM\nou coloque moedas", 16, Color(1, 1, 1, 0.45), 2))
	var th: Dictionary = st.get("theirs", {})
	var t_items: Array = th.get("items", [])
	var t_coins := int(th.get("coins", 0))
	for it in t_items:
		_their_list.add_child(_item_card(str(it), false))
	if t_coins > 0:
		_their_list.add_child(_coin_card(t_coins))
	if t_items.is_empty() and t_coins == 0:
		_their_list.add_child(ui.mk_lbl("%s ainda não colocou nada" % with_name, 16, Color(1, 1, 1, 0.45), 2))
	var mv := offer_value(my_items, my_coins)
	var tv := offer_value(t_items, t_coins)
	var rdy := bool(st.get("ready", false))
	var trdy := bool(st.get("theirReady", false))
	var conf := bool(st.get("conf", false))
	var tconf := bool(st.get("theirConf", false))
	_my_head.text = "VOCÊ OFERECE  •  valor %s%s" % [fmt(mv), "   ✓ PRONTO" if rdy else ""]
	_their_head.text = "%s OFERECE  •  valor %s%s" % [with_name.to_upper(), fmt(tv), ("   ✓ CONFIRMOU" if tconf else ("   ✓ PRONTO" if trdy else ""))]
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
		_fair_lbl.text = "Montem a troca e toquem em PRONTO. Mudou alguma coisa? O PRONTO dos dois sai."
		_fair_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_ready_btn.text = "TIRAR PRONTO" if rdy else "PRONTO"
	_ready_btn.disabled = why != "" or conf
	_conf_btn.disabled = not (rdy and trdy) or conf or why != ""
	_add_btn.disabled = conf
	for b in _coin_btns:
		(b as Button).disabled = conf


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
func _open_picker() -> void:
	if picker != null and is_instance_valid(picker):
		picker.queue_free()
	picker = Control.new()
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(picker)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.75)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.add_child(dimr)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + k, 40)
	picker.add_child(mc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.02, 0.05, 0.08, 0.98), 24, Color("5aa9ff"), 3, 16))
	mc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(ui.margin(vb, 16))
	vb.add_child(ui.mk_lbl("ESCOLHA O QUE OFERECER", 28, Color("8fd0ff"), 5))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var fl := HFlowContainer.new()
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.add_theme_constant_override("h_separation", 10)
	fl.add_theme_constant_override("v_separation", 10)
	sc.add_child(fl)
	var has: Array = st.get("theirHas", [])
	var n := 0
	for id in tradable():
		if my_items.has(id):
			continue
		n += 1
		var card := _item_card(id, false) as Button
		var sid := str(id)
		if has.has(sid):
			card.disabled = true
			card.tooltip_text = "%s já tem" % with_name
			card.modulate = Color(1, 1, 1, 0.55)
			var tag: Label = ui.mk_lbl("ELE JÁ TEM", 15, Color("ff8a6a"), 5)
			tag.position = Vector2(0, 34)
			tag.size = Vector2(150, 22)
			card.add_child(tag)
		else:
			card.pressed.connect(func():
				if my_items.size() >= 30:
					return
				my_items.append(sid)
				picker.queue_free()
				picker = null
				_send_offer())
		fl.add_child(card)
	if n == 0:
		fl.add_child(ui.mk_lbl("Você não tem mais itens para oferecer.\n(Itens grátis como a mesa verde e o taco clássico não entram.)", 18, Color(1, 1, 1, 0.6), 2))
	var bc: Button = ui.mk_btn("VOLTAR", 220, 56, ui.GRAY, 20)
	bc.pressed.connect(func():
		picker.queue_free()
		picker = null)
	vb.add_child(bc)
