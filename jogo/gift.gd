extends Node
# PRESENTES: comprar um item da loja para um amigo, embrulhado no papel que você escolher.
# O servidor desconta as moedas de quem dá (saldo de verdade fica lá) e entrega o pacote para quem
# recebe: na hora se estiver online, ou guardado até ele abrir o jogo. O pacote fica no inventário
# (aba PRESENTES) até a pessoa abrir. Se ela já tiver o item quando abrir, vira o valor em moedas.

const WRAPS := [
	{"id": "kraft", "name": "Papel Pardo", "price": 0, "paper": Color("b98a55"), "paper2": Color("94683a"), "rib": Color("efe3c6"), "pat": 0},
	{"id": "laco", "name": "Laço Vermelho", "price": 150, "paper": Color("f3efe6"), "paper2": Color("d9d2c3"), "rib": Color("d4232c"), "pat": 1},
	{"id": "festa", "name": "Festa", "price": 300, "paper": Color("2f7fd6"), "paper2": Color("1c58a6"), "rib": Color("ffd34a"), "pat": 2},
	{"id": "ouro", "name": "Dourado", "price": 600, "paper": Color("e3bb4c"), "paper2": Color("b08520"), "rib": Color("8a1424"), "pat": 3},
	{"id": "galaxia", "name": "Galáxia", "price": 1200, "paper": Color("2c1660"), "paper2": Color("110730"), "rib": Color("c77dff"), "pat": 4},
]

var game: Node
var ui
var layer: CanvasLayer
var _anims: Array = []
var _sending := false
var _told := false

# estado da janela de enviar
var _item: Dictionary = {}
var _to := ""
var _to_name := ""
var _wrap := "laco"
var _msg_edit: LineEdit
var _code_edit: LineEdit
var _total_lbl: Label
var _send_btn: Button
var _friend_btns: Dictionary = {}
var _wrap_btns: Dictionary = {}


func setup(g: Node) -> void:
	game = g
	ui = g.ui
	layer = CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	if not game.save.has("gifts"):
		game.save["gifts"] = []


var _frame := 0
func _process(_d: float) -> void:
	_frame += 1
	if _frame % 2 != 0:
		return
	var keep: Array = []
	for c in _anims:
		if is_instance_valid(c):
			if ui.on_screen(c):
				(c as CanvasItem).queue_redraw()
			keep.append(c)
	_anims = keep


func wrap_def(id: String) -> Dictionary:
	for w in WRAPS:
		if str(w.id) == id:
			return w
	return WRAPS[0]


func item_def(id: String) -> Dictionary:
	for it in game.FELTS + game.CUES + game.MONTHLY + game.ELITE + game.RAILS + game.DECKS + game.WFX:
		if str(it.id) == id:
			return it
	return {}


func can_gift(it: Dictionary) -> bool:
	return int(it.get("price", 0)) > 0 and not it.has("pass") and not str(it.id) in ["dk_classico", "wf_confete", "rb_padrao", "verde", "classico"]


func pending() -> Array:
	return game.save.get("gifts", [])


# ---------------------------------------------------------------- desenho do pacote
# caixa embrulhada: papel com estampa, fita em cruz e laço. lid = quanto a tampa subiu (0..1), shake em px
func draw_box(c: CanvasItem, ctr: Vector2, s: float, w: Dictionary, t: float, lid: float = 0.0, shake: float = 0.0) -> void:
	var off := Vector2(sin(t * 40.0) * shake, 0)
	var p: Color = w.paper
	var p2: Color = w.paper2
	var rib: Color = w.rib
	var body := Rect2(ctr + off + Vector2(-s * 0.5, -s * 0.18), Vector2(s, s * 0.68))
	c.draw_rect(Rect2(body.position + Vector2(4, 6), body.size), Color(0, 0, 0, 0.3))
	c.draw_rect(body, p)
	c.draw_rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.16)), p2)
	_pattern(c, body, w, t)
	# fita vertical do corpo
	c.draw_rect(Rect2(body.position.x + body.size.x * 0.44, body.position.y, body.size.x * 0.12, body.size.y), rib)
	c.draw_rect(Rect2(body.position.x + body.size.x * 0.44, body.position.y, body.size.x * 0.03, body.size.y), rib.lightened(0.35))
	# tampa
	var lift := Vector2(lid * s * 0.25, -lid * s * 0.7)
	var lr := Rect2(ctr + off + lift + Vector2(-s * 0.56, -s * 0.36), Vector2(s * 1.12, s * 0.22))
	var la := lid * 0.5
	c.draw_set_transform(lr.get_center(), la, Vector2.ONE)
	var l0 := Rect2(-lr.size / 2.0, lr.size)
	c.draw_rect(Rect2(l0.position + Vector2(3, 4), l0.size), Color(0, 0, 0, 0.25))
	c.draw_rect(l0, p)
	_pattern(c, l0, w, t)
	c.draw_rect(Rect2(l0.position.x, l0.end.y - l0.size.y * 0.22, l0.size.x, l0.size.y * 0.22), p2)
	c.draw_rect(Rect2(-s * 0.06, l0.position.y, s * 0.12, l0.size.y), rib)
	# laço
	var bc := Vector2(0, l0.position.y)
	for sd in [-1.0, 1.0]:
		var pts := PackedVector2Array([bc, bc + Vector2(sd * s * 0.3, -s * 0.2), bc + Vector2(sd * s * 0.34, -s * 0.04), bc + Vector2(sd * s * 0.06, s * 0.02)])
		c.draw_colored_polygon(pts, rib)
		c.draw_polyline(PackedVector2Array([bc + Vector2(sd * s * 0.05, -s * 0.02), bc + Vector2(sd * s * 0.28, -s * 0.15)]), rib.darkened(0.25), maxf(1.0, s * 0.02))
		c.draw_colored_polygon(PackedVector2Array([bc + Vector2(sd * s * 0.02, s * 0.02), bc + Vector2(sd * s * 0.16, s * 0.2), bc + Vector2(sd * s * 0.08, s * 0.22)]), rib.darkened(0.15))
	c.draw_circle(bc, s * 0.07, rib.lightened(0.15))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pattern(c: CanvasItem, r: Rect2, w: Dictionary, t: float) -> void:
	match int(w.pat):
		1:
			for i in 6:
				for j in 4:
					var q := r.position + Vector2((i + 0.5 + (j % 2) * 0.5) * r.size.x / 6.0, (j + 0.5) * r.size.y / 4.0)
					if r.has_point(q):
						c.draw_circle(q, r.size.x * 0.018, Color(0.83, 0.14, 0.17, 0.35))
		2:
			var cols := [Color("ffd34a"), Color("ff5d8f"), Color("3ddc84"), Color.WHITE]
			for i in 18:
				var hx := fposmod(sin(float(i) * 12.99) * 43758.5, 1.0)
				var hy := fposmod(sin(float(i) * 78.23) * 43758.5, 1.0)
				var q := r.position + Vector2(hx, hy) * r.size
				c.draw_rect(Rect2(q, Vector2(r.size.x * 0.035, r.size.x * 0.018)), cols[i % 4])
		3:
			var n := 7
			for i in n:
				var x := r.position.x + (i + 0.5) * r.size.x / n
				c.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.18), r.size.x * 0.03)
		4:
			for i in 16:
				var hx := fposmod(sin(float(i) * 12.99) * 43758.5, 1.0)
				var hy := fposmod(sin(float(i) * 78.23) * 43758.5, 1.0)
				var a := 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 3.0 + i))
				c.draw_circle(r.position + Vector2(hx, hy) * r.size, r.size.x * (0.008 + 0.012 * hy), Color(1, 1, 1, a))


func box_icon(sz: float, wrap_id: String, animated: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := wrap_def(wrap_id)
	c.draw.connect(func():
		var t := Time.get_ticks_msec() / 1000.0 if animated else 0.0
		draw_box(c, Vector2(sz / 2.0, sz * 0.56), sz * 0.66, w, t, 0.0, 0.0))
	if animated or int(w.pat) == 4:
		_anims.append(c)
	return c


# ícone de presente pequeno (para botões)
func gift_btn(cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Dar de presente"
	for st in ["normal", "hover", "pressed", "disabled"]:
		var col := Color("c2185b") if st != "pressed" else Color("8e0f42")
		b.add_theme_stylebox_override(st, ui.sbox(col, 26, Color("ff8ab8"), 2, 4))
	var ic := box_icon(44, "laco")
	ic.position = Vector2(4, 2)
	b.add_child(ic)
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- enviar presente
func open_send(it: Dictionary) -> void:
	if not game.net.server_ok:
		ui.say("Sem conexão com o servidor. Conecte para mandar presentes.")
		return
	_item = it
	_to = ""
	_to_name = ""
	_wrap = "laco"
	_friend_btns.clear()
	_wrap_btns.clear()
	ui.close_modal()
	var ml := Control.new()
	ml.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ml.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.root.add_child(ml)
	ui.modal_layer = ml
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.7)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ml.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ml.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1060, 0)
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.03, 0.04, 0.09, 0.98), 26, Color("ff8ab8"), 3, 20))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(ui.margin(vb, 18))
	vb.add_child(ui.mk_lbl("DAR DE PRESENTE", 34, Color("ff8ab8"), 6))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	vb.add_child(top)
	# esquerda: o item
	var lc := PanelContainer.new()
	lc.add_theme_stylebox_override("panel", ui.sbox(Color(0.05, 0.08, 0.14), 18, Color(1, 1, 1, 0.15), 2))
	top.add_child(lc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	lc.add_child(ui.margin(lv, 10))
	lv.add_child(item_preview(str(it.id)))
	lv.add_child(ui.mk_lbl(str(it.name), 22, Color.WHITE, 3))
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_child(ui.coin_icon(22))
	pr.add_child(ui.mk_lbl(" " + game.trade.fmt(int(it.price)), 20, Color("ffe08a"), 2))
	lv.add_child(pr)
	# direita: para quem, embrulho, recado
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rv)
	var l1: Label = ui.mk_lbl("PARA QUEM?", 18, Color("ffd34a"), 2)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rv.add_child(l1)
	var fsc := ScrollContainer.new()
	fsc.custom_minimum_size = Vector2(0, 58)
	fsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(fsc)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 8)
	fsc.add_child(frow)
	var fl: Array = game.save.get("friends", [])
	if fl.is_empty():
		frow.add_child(ui.mk_lbl("Você ainda não tem amigos. Digite o código do jogador ao lado.", 15, Color(1, 1, 1, 0.55), 2))
	for f in fl:
		var code := str(f.get("code", ""))
		var nm := str(f.get("name", code))
		var b: Button = ui.mk_btn(nm, maxf(110.0, nm.length() * 13.0 + 30.0), 50, ui.GRAY, 18)
		b.pressed.connect(func():
			_to = code
			_to_name = nm
			_code_edit.text = ""
			_paint())
		_friend_btns[code] = b
		frow.add_child(b)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	rv.add_child(crow)
	var ol: Label = ui.mk_lbl("ou código:", 16, Color(1, 1, 1, 0.6), 2)
	crow.add_child(ol)
	_code_edit = LineEdit.new()
	_code_edit.custom_minimum_size = Vector2(180, 44)
	_code_edit.max_length = 6
	_code_edit.placeholder_text = "ABC123"
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.add_theme_font_size_override("font_size", 20)
	_code_edit.add_theme_stylebox_override("normal", ui.sbox(Color(0.08, 0.1, 0.16), 12, Color(1, 1, 1, 0.25), 2))
	_code_edit.add_theme_stylebox_override("focus", ui.sbox(Color(0.1, 0.12, 0.2), 12, Color.WHITE, 2))
	_code_edit.text_changed.connect(func(tx: String):
		var up := tx.to_upper().strip_edges()
		if up != tx:
			_code_edit.text = up
			_code_edit.caret_column = up.length()
		if up.length() == 6:
			_to = up
			_to_name = up
		elif _to != "" and not _friend_btns.has(_to):
			_to = ""
		_paint())
	crow.add_child(_code_edit)
	var l2: Label = ui.mk_lbl("EMBRULHO", 18, Color("ffd34a"), 2)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rv.add_child(l2)
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 8)
	rv.add_child(wrow)
	for w in WRAPS:
		var wid := str(w.id)
		var wb := Button.new()
		wb.custom_minimum_size = Vector2(118, 118)
		wb.focus_mode = Control.FOCUS_NONE
		var wv := VBoxContainer.new()
		wv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wv.add_theme_constant_override("separation", 0)
		wb.add_child(wv)
		var bi := box_icon(66, wid)
		bi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wv.add_child(bi)
		var wn: Label = ui.mk_lbl(str(w.name), 13, Color.WHITE, 2)
		wn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wv.add_child(wn)
		var wp: Label = ui.mk_lbl("GRÁTIS" if int(w.price) == 0 else game.trade.fmt(int(w.price)), 14, Color("3ddc84") if int(w.price) == 0 else Color("ffe08a"), 2)
		wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wv.add_child(wp)
		wb.pressed.connect(func():
			_wrap = wid
			_paint())
		_wrap_btns[wid] = wb
		wrow.add_child(wb)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	rv.add_child(mrow)
	mrow.add_child(ui.mk_lbl("Recado:", 16, Color(1, 1, 1, 0.6), 2))
	_msg_edit = LineEdit.new()
	_msg_edit.custom_minimum_size = Vector2(420, 44)
	_msg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_edit.max_length = 60
	_msg_edit.placeholder_text = "Feliz aniversário! (opcional)"
	_msg_edit.add_theme_font_size_override("font_size", 18)
	_msg_edit.add_theme_stylebox_override("normal", ui.sbox(Color(0.08, 0.1, 0.16), 12, Color(1, 1, 1, 0.25), 2))
	_msg_edit.add_theme_stylebox_override("focus", ui.sbox(Color(0.1, 0.12, 0.2), 12, Color.WHITE, 2))
	mrow.add_child(_msg_edit)
	# rodapé
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 16)
	vb.add_child(brow)
	_total_lbl = ui.mk_lbl("", 22, Color.WHITE, 3)
	_total_lbl.custom_minimum_size = Vector2(300, 0)
	brow.add_child(_total_lbl)
	var cb: Button = ui.mk_btn("CANCELAR", 200, 60, ui.GRAY, 20)
	cb.pressed.connect(ui.close_modal)
	brow.add_child(cb)
	_send_btn = ui.mk_btn("ENVIAR PRESENTE", 300, 60, Color("c2185b"), 22)
	_send_btn.pressed.connect(_send)
	brow.add_child(_send_btn)
	_paint()


func total() -> int:
	return int(_item.get("price", 0)) + int(wrap_def(_wrap).price)


func _paint() -> void:
	for code in _friend_btns.keys():
		var b: Button = _friend_btns[code]
		var on: bool = code == _to
		var col: Color = Color("c2185b") if on else ui.GRAY
		b.add_theme_stylebox_override("normal", ui.sbox(col, 20, col.lightened(0.35), 3, 6))
	for wid in _wrap_btns.keys():
		var wb: Button = _wrap_btns[wid]
		var on2: bool = wid == _wrap
		for st in ["normal", "hover", "pressed"]:
			wb.add_theme_stylebox_override(st, ui.sbox(Color(0.2, 0.06, 0.13) if on2 else Color(0.07, 0.09, 0.14), 16, Color("ff8ab8") if on2 else Color(1, 1, 1, 0.15), 3 if on2 else 1))
	var tt := total()
	_total_lbl.text = "Total: %s moedas" % game.trade.fmt(tt)
	_total_lbl.add_theme_color_override("font_color", Color("ffe08a") if int(game.save.coins) >= tt else Color("ff6a4a"))
	_send_btn.disabled = _to == "" or _sending
	_send_btn.text = "ENVIAR PRESENTE" if _to == "" else "ENVIAR PARA " + _to_name.to_upper().left(12)


func _send() -> void:
	if _to == "" or _sending:
		return
	if _to == str(game.save.get("pcode", "")):
		ui.say("Não dá para mandar presente para você mesmo.")
		return
	var tt := total()
	if int(game.save.coins) < tt:
		ui.say("Moedas insuficientes! Faltam %s." % game.trade.fmt(tt - int(game.save.coins)))
		return
	_sending = true
	_paint()
	# manda antes as moedas que ainda estão na fila, para o saldo do servidor estar em dia
	game.net.send_eco()
	game.net.world_send({"t": "gift_send", "tok": game.my_tok(), "to": _to, "item": str(_item.id), "wrap": _wrap, "msg": _msg_edit.text.strip_edges().left(60)})
	get_tree().create_timer(15.0).timeout.connect(func():
		if _sending:
			_sending = false
			ui.say("O servidor não respondeu. Tente de novo.")
			if ui.has_modal() and _send_btn != null and is_instance_valid(_send_btn):
				_paint())


# ---------------------------------------------------------------- mensagens do servidor
func on_msg(m: Dictionary) -> void:
	match str(m.t):
		"gift_ok":
			_sending = false
			game.eco_result(m)
			game.write_save()
			ui.refresh_top()
			ui.close_modal()
			var w := wrap_def(str(m.get("wrap", "kraft")))
			_celebrate_sent(str(m.get("name", _to_name)), str(m.get("item", "")), w)
		"gift_fail":
			_sending = false
			ui.say(str(m.get("msg", "Não deu para mandar o presente.")))
			if ui.has_modal() and _send_btn != null and is_instance_valid(_send_btn):
				_paint()
		"gift":
			_receive(m)


func _receive(m: Dictionary) -> void:
	var gid := str(m.get("gid", ""))
	if gid == "":
		return
	var gl: Array = pending()
	for g in gl:
		if str(g.get("gid", "")) == gid:
			return
	var opened: Array = game.save.get("gifts_open", [])
	if opened.has(gid):
		return
	gl.append({"gid": gid, "from": str(m.get("from", "")), "name": str(m.get("name", "?")), "item": str(m.get("item", "")), "wrap": str(m.get("wrap", "kraft")), "msg": str(m.get("msg", "")), "ts": int(m.get("ts", 0))})
	game.save["gifts"] = gl
	game.write_save()
	game.net.send_csave()
	game.play("click", 0.8)
	notify()


# aviso de presente: ao chegar ou ao abrir o jogo com pacotes guardados
func notify() -> void:
	var gl := pending()
	if gl.is_empty():
		return
	if ui.has_modal() or (game.trade != null and game.trade.is_open()) or game.st != game.St.MENU:
		# está ocupado (partida, troca ou outra janela): só um aviso rápido
		ui.say("Você recebeu um presente! Abra em INVENTÁRIO > PRESENTES.", 4.0)
		return
	var last: Dictionary = gl[gl.size() - 1]
	var txt := "%s te mandou um presente!" % str(last.name)
	if gl.size() > 1:
		txt = "Você tem %d presentes esperando para abrir!" % gl.size()
	ui.close_modal()
	var ml := Control.new()
	ml.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ml.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.root.add_child(ml)
	ui.modal_layer = ml
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.7)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ml.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ml.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.03, 0.04, 0.09, 0.98), 26, Color("ff8ab8"), 3, 20))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(ui.margin(vb, 24))
	vb.add_child(ui.mk_lbl("PRESENTE!", 40, Color("ff8ab8"), 6))
	var bi := box_icon(170, str(last.wrap), true)
	bi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(bi)
	vb.add_child(ui.mk_lbl(txt, 24, Color.WHITE, 3))
	if str(last.msg) != "" and gl.size() == 1:
		vb.add_child(ui.mk_lbl("“%s”" % str(last.msg), 19, Color(1, 0.9, 0.95, 0.85), 2))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var ob: Button = ui.mk_btn("ABRIR AGORA", 240, 62, Color("c2185b"), 22)
	ob.pressed.connect(func():
		ui.close_modal()
		open_gift(str(last.gid)))
	row.add_child(ob)
	var lb: Button = ui.mk_btn("DEPOIS", 180, 62, ui.GRAY, 20)
	lb.pressed.connect(ui.close_modal)
	row.add_child(lb)


# chamado quando o menu principal aparece (uma vez por sessão)
func on_menu() -> void:
	if _told or pending().is_empty():
		return
	_told = true
	notify.call_deferred()


# ---------------------------------------------------------------- abrir presente
func open_gift(gid: String) -> void:
	var g: Dictionary = {}
	for x in pending():
		if str(x.get("gid", "")) == gid:
			g = x
	if g.is_empty():
		return
	var it := item_def(str(g.item))
	var already: bool = game.save.owned.has(str(g.item))
	var val := int(it.get("price", 0))
	# tira da lista e guarda (antes da animação, para não abrir duas vezes)
	var gl: Array = pending()
	gl.erase(g)
	game.save["gifts"] = gl
	var opened: Array = game.save.get("gifts_open", [])
	opened.append(gid)
	if opened.size() > 200:
		opened = opened.slice(opened.size() - 200)
	game.save["gifts_open"] = opened
	if it.is_empty():
		pass
	elif already:
		game.save.coins = int(game.save.coins) + val
		game.eco(val, 0, "gift_dup", {"gid": gid})
	else:
		game.save.owned.append(str(g.item))
	game.write_save()
	game.net.send_csave()
	ui.refresh_top()
	_show_open(g, it, already, val)


func _show_open(g: Dictionary, it: Dictionary, already: bool, val: int) -> void:
	var w := wrap_def(str(g.wrap))
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(ov)
	var t0 := Time.get_ticks_msec()
	var stage := [0]
	var cv := Control.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cv)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	cards.modulate.a = 0.0
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	cc.add_child(cards)
	cv.draw.connect(func():
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		var sz := cv.size
		var ctr := sz / 2.0
		cv.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.01, 0.01, 0.04, 0.9))
		# raios girando atrás
		var rc: Color = w.rib
		var rays := clampf((t - 1.2) * 2.0, 0.0, 1.0)
		if rays > 0.0:
			for k in 14:
				var a := t * 0.5 + k * TAU / 14.0
				cv.draw_colored_polygon(PackedVector2Array([ctr, ctr + Vector2.from_angle(a - 0.08) * sz.x, ctr + Vector2.from_angle(a + 0.08) * sz.x]), Color(rc.r, rc.g, rc.b, 0.08 * rays))
		if t < 1.6:
			var shake := 0.0
			if t < 1.1:
				shake = 3.0 + t * 7.0
			var lid := clampf((t - 1.1) * 3.0, 0.0, 1.0)
			var s := 220.0 + sin(t * 10.0) * 4.0 * (1.0 if t < 1.1 else 0.0)
			cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_box(cv, ctr + Vector2(0, 40), s, w, t, lid, shake)
			if t < 1.1:
				cv.draw_string(ThemeDB.fallback_font, Vector2(0, sz.y - 70), "abrindo...", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 24, Color(1, 1, 1, 0.6))
		# confete quando abre
		if t > 1.15:
			var ct := t - 1.15
			for k in 60:
				var hx := fposmod(sin(float(k) * 12.99) * 43758.5, 1.0)
				var hy := fposmod(sin(float(k) * 78.23) * 43758.5, 1.0)
				var dir := Vector2.from_angle(-PI / 2.0 + (hx - 0.5) * 2.4)
				var sp := 380.0 + hy * 420.0
				var q := ctr + Vector2(0, 40) + dir * sp * ct + Vector2(0, 260.0 * ct * ct)
				var col: Color = [Color("ffd34a"), Color("ff5d8f"), Color("3ddc84"), Color("5aa9ff"), rc][k % 5]
				cv.draw_rect(Rect2(q, Vector2(9, 5)), Color(col.r, col.g, col.b, clampf(2.5 - ct, 0.0, 1.0)))
		if t > 1.5 and stage[0] == 0:
			stage[0] = 1
			game.play("click", 1.0)
			var tw := cards.create_tween()
			tw.tween_property(cards, "modulate:a", 1.0, 0.35))
	_anims.append(cv)
	var head: Label = ui.mk_lbl("PRESENTE DE %s" % str(g.name).to_upper(), 30, Color("ff8ab8"), 6)
	cards.add_child(head)
	if str(g.msg) != "":
		cards.add_child(ui.mk_lbl("“%s”" % str(g.msg), 20, Color(1, 0.92, 0.96), 2))
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ui.sbox(Color(0.04, 0.06, 0.12, 0.97), 20, Color(1, 1, 1, 0.25), 2, 10))
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards.add_child(pc)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	pc.add_child(ui.margin(iv, 12))
	if not it.is_empty():
		iv.add_child(item_preview(str(it.id), 1.4))
		iv.add_child(ui.mk_lbl(str(it.name), 28, Color.WHITE, 4))
	if already:
		cards.add_child(ui.mk_lbl("Você já tinha esse item, então ele virou %s moedas!" % game.trade.fmt(val), 20, Color("ffe08a"), 3))
	else:
		cards.add_child(ui.mk_lbl("Agora é seu! Já está no seu inventário.", 20, Color("3ddc84"), 3))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	cards.add_child(row)
	if not already and not it.is_empty():
		var ub: Button = ui.mk_btn("USAR AGORA", 230, 60, ui.BLUE, 22)
		ub.pressed.connect(func():
			ov.queue_free()
			ui._equip(str(it.id))
			_after_close())
		row.add_child(ub)
	var okb: Button = ui.mk_btn("LEGAL!", 200, 60, ui.GREEN, 22)
	okb.pressed.connect(func():
		ov.queue_free()
		_after_close())
	row.add_child(okb)


func _after_close() -> void:
	if ui.cur == "shop" or ui.cur == "inv":
		ui._shop_tab(ui.shop_tab)


func _celebrate_sent(nm: String, item_id: String, w: Dictionary) -> void:
	var it := item_def(item_id)
	ui.say("Presente enviado para %s! (%s)" % [nm, str(it.get("name", item_id))], 4.0)


# prévia do item (mesma da loja), num tamanho fixo
func item_preview(id: String, k: float = 1.0) -> Control:
	var it := item_def(id)
	var box := Control.new()
	box.custom_minimum_size = Vector2(184, 150) * k
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pv := Control.new()
	pv.size = Vector2(184, 150)
	pv.scale = Vector2(k, k)
	pv.clip_contents = true
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pv)
	if it.is_empty():
		return box
	if it.has("shaft"):
		ui._cue_preview(pv, it, Vector2(60, 100), 140.0, -40.0, 22.0, 0.85, ui.fx_nodes)
	elif it.has("deck"):
		ui._deck_preview(pv, str(it.deck))
	elif it.has("wfx"):
		ui._wfx_preview(pv, str(it.wfx))
	elif str(it.id).begins_with("rb_"):
		ui._rail_preview(pv, it, game.felt_def())
	else:
		ui._rail_preview(pv, game.rail_for(str(it.get("rail", ""))), it)
	for ch in pv.get_children():
		if ch is CanvasItem:
			_anims.append(ch)
	return box


# ---------------------------------------------------------------- aba PRESENTES do inventário
func render_tab(row: HBoxContainer) -> void:
	var gl := pending()
	if gl.is_empty():
		var el: Label = ui.mk_lbl("Nenhum presente para abrir.\nNa LOJA, toque no botão rosa de presente em qualquer item para mandar um para um amigo!", 24, Color(1, 1, 1, 0.8), 4)
		el.custom_minimum_size = Vector2(1100, 380)
		el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(el)
		return
	for g in gl:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(212, 404)
		card.add_theme_stylebox_override("panel", ui.sbox(Color(0.07, 0.04, 0.1), 22, Color("ff8ab8"), 3, 10))
		row.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		card.add_child(ui.margin(vb, 14))
		var bi := box_icon(180, str(g.wrap), true)
		bi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(bi)
		vb.add_child(ui.mk_lbl("PRESENTE", 24, Color("ff8ab8"), 4))
		vb.add_child(ui.mk_lbl("de " + str(g.name), 18, Color.WHITE, 2))
		var ml: Label = ui.mk_lbl(("“%s”" % str(g.msg)) if str(g.msg) != "" else " ", 15, Color(1, 1, 1, 0.65), 2)
		ml.custom_minimum_size = Vector2(184, 46)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(ml)
		var ob: Button = ui.mk_btn("ABRIR", 184, 56, Color("c2185b"), 26)
		var gid := str(g.gid)
		ob.pressed.connect(func(): open_gift(gid))
		vb.add_child(ob)
