extends CanvasLayer
# Tela de NOVIDADE que aparece uma vez depois de atualizar (marca em save.news_seen).

const NEWS_ID := "troca1"
const AV = preload("res://avatars.gd")

var game: Node
var ui
var root: Control
var _art: Control
var _t := 0.0
var _fx: Array = []


func setup(g: Node) -> void:
	game = g
	ui = g.ui
	layer = 45


func should_show() -> bool:
	return str(game.save.get("news_seen", "")) != NEWS_ID


func show_news() -> void:
	if root != null and is_instance_valid(root):
		return
	game.save["news_seen"] = NEWS_ID
	game.write_save()
	_t = 0.0
	_fx.clear()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.78)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1180, 680)
	card.add_theme_stylebox_override("panel", ui.sbox(Color(0.02, 0.04, 0.08, 0.98), 30, Color("f4c542"), 4, 26))
	cc.add_child(card)
	card.pivot_offset = Vector2(590, 340)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	# arte desenhada (fundo, faixa, jogadores, setas)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.custom_minimum_size = Vector2(1180, 680)
	_art.clip_contents = true
	card.add_child(_art)
	_art.draw.connect(_draw_art)
	# itens de verdade (com o mesmo visual da loja)
	_item(_art, "e_zeus", Vector2(250, 150))
	_item(_art, "rb_fogo", Vector2(250, 268))
	_item(_art, "aurora_m", Vector2(744, 150))
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 400)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sp)
	var steps := HBoxContainer.new()
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	steps.add_theme_constant_override("separation", 14)
	steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(steps)
	steps.add_child(_step(1, "CHAME O AMIGO", "Em AMIGOS, toque no botão laranja NEGOCIAR (ou no perfil dele)."))
	steps.add_child(_step(2, "MONTEM A TROCA", "Tacos, mesas, bordas, baralhos, efeitos e moedas: tudo que vocês têm."))
	steps.add_child(_step(3, "PRONTO + CONFIRMAR", "Os dois tocam PRONTO e depois CONFIRMAR. Pronto, trocado!"))
	var note: Label = ui.mk_lbl("Troca justa: cada um recebe pelo menos 25% do valor do que dá  •  Deu um item? Pode comprar de novo na loja", 15, Color(1, 0.9, 0.6, 0.8), 2)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(note)
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 18)
	vb.add_child(brow)
	var bf: Button = ui.mk_btn("VER MEUS AMIGOS", 300, 62, Color("d68a10"), 22)
	bf.pressed.connect(func():
		close()
		ui.show_screen("amigos"))
	brow.add_child(bf)
	var ok: Button = ui.mk_btn("ENTENDI!", 260, 62, Color("1b8f4c"), 24)
	ok.pressed.connect(close)
	brow.add_child(ok)


func close() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null


func _process(d: float) -> void:
	if root == null or not is_instance_valid(root):
		return
	_t += d
	ui.fx_t += d
	if _art != null and is_instance_valid(_art):
		_art.queue_redraw()
	for n in _fx:
		if is_instance_valid(n):
			(n as CanvasItem).queue_redraw()


func _item(parent: Control, id: String, pos: Vector2) -> void:
	var box := Control.new()
	box.position = pos
	box.size = Vector2(184, 110)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var pv := Control.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.size = Vector2(184, 150)
	box.add_child(pv)
	if id.begins_with("rb_"):
		pv.position = Vector2(0, -12)
		ui._rail_preview(pv, game.rail_for(id), game.felt_def())
	elif id.begins_with("e_") or id.begins_with("m_"):
		var it: Dictionary = {}
		for c in game.ELITE + game.MONTHLY + game.CUES:
			if str(c.id) == id:
				it = c
		pv.position = Vector2(0, -20)
		ui._cue_preview(pv, it, Vector2(86, 82), 140.0, -16.0, 20.0, 0.7, _fx)
	else:
		var fd: Dictionary = {}
		for f in game.FELTS:
			if str(f.id) == id:
				fd = f
		pv.position = Vector2(0, -12)
		ui._rail_preview(pv, game.rail_for(str(fd.get("rail", ""))), fd)
	for ch in pv.get_children():
		if ch is Control:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_fx.append(ch)


func _step(n: int, title: String, txt: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(360, 110)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", ui.sbox(Color(0.05, 0.09, 0.15, 0.95), 18, Color(1, 0.83, 0.3, 0.45), 2, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ui.margin(h, 10))
	var num := Control.new()
	num.custom_minimum_size = Vector2(54, 54)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	num.draw.connect(func():
		num.draw_circle(Vector2(27, 27), 26, Color("b8860b"))
		num.draw_circle(Vector2(27, 25), 23, Color("ffd34a"))
		num.draw_string(ThemeDB.fallback_font, Vector2(0, 36), str(n), HORIZONTAL_ALIGNMENT_CENTER, 54, 30, Color("3a2604")))
	h.add_child(num)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var tl: Label = ui.mk_lbl(title, 19, Color("ffd34a"), 3)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(tl)
	var dl: Label = ui.mk_lbl(txt, 15, Color(1, 1, 1, 0.85), 1)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(270, 0)
	v.add_child(dl)
	return p


func _draw_art() -> void:
	var c := _art
	var f: Font = ThemeDB.fallback_font
	var t := _t
	var w := 1180.0
	# raios de luz atrás do título
	for k in 14:
		var a := t * 0.15 + k * TAU / 14.0
		var p0 := Vector2(w / 2, 250)
		c.draw_colored_polygon(PackedVector2Array([p0, p0 + Vector2.from_angle(a - 0.08) * 700, p0 + Vector2.from_angle(a + 0.08) * 700]), Color(1, 0.8, 0.25, 0.025))
	# faixa NOVIDADE
	var bw := 260.0
	var by := 18.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(w / 2 - bw / 2 - 22, by + 21), Vector2(w / 2 - bw / 2, by), Vector2(w / 2 + bw / 2, by), Vector2(w / 2 + bw / 2 + 22, by + 21), Vector2(w / 2 + bw / 2, by + 42), Vector2(w / 2 - bw / 2, by + 42)]), Color("e53935"))
	c.draw_string(f, Vector2(w / 2 - bw / 2, by + 31), "★  NOVIDADE  ★", HORIZONTAL_ALIGNMENT_CENTER, bw, 22, Color.WHITE)
	var pulse := 1.0 + 0.03 * sin(t * 3.0)
	c.draw_set_transform(Vector2(w / 2, 104), 0.0, Vector2(pulse, pulse))
	c.draw_string_outline(f, Vector2(-500, 0), "NEGOCIAÇÃO ENTRE AMIGOS", HORIZONTAL_ALIGNMENT_CENTER, 1000, 46, 10, Color(0, 0, 0, 0.7))
	c.draw_string(f, Vector2(-500, 0), "NEGOCIAÇÃO ENTRE AMIGOS", HORIZONTAL_ALIGNMENT_CENTER, 1000, 46, Color("ffd34a"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_string(f, Vector2(0, 136), "Troque tacos, mesas, bordas, baralhos, efeitos e moedas com quem você joga!", HORIZONTAL_ALIGNMENT_CENTER, w, 19, Color(1, 1, 1, 0.8))
	# você (esquerda) e o amigo (direita)
	var me := [str(game.save.get("av", "b8")), str(game.save.get("frame", "simples"))]
	c.draw_circle(Vector2(140, 268), 70, Color(0.24, 0.86, 0.52, 0.10))
	AV.draw(c, Vector2(140, 258), 52, me[0], me[1], t)
	c.draw_string(f, Vector2(40, 336), "VOCÊ", HORIZONTAL_ALIGNMENT_CENTER, 200, 20, Color("3ddc84"))
	c.draw_circle(Vector2(w - 140, 268), 70, Color(0.35, 0.66, 1, 0.10))
	AV.draw(c, Vector2(w - 140, 258), 52, "crown", "ouro", t)
	c.draw_string(f, Vector2(w - 240, 336), "SEU AMIGO", HORIZONTAL_ALIGNMENT_CENTER, 200, 20, Color("8fd0ff"))
	# molduras dos itens
	for r in [Rect2(244, 144, 196, 122), Rect2(244, 262, 196, 122), Rect2(738, 144, 196, 122)]:
		c.draw_style_box(ui.sbox(Color(0.03, 0.06, 0.1, 0.9), 14, Color(1, 0.83, 0.3, 0.5), 2), r)
	# moedas do amigo
	var cc := Vector2(836, 322)
	c.draw_style_box(ui.sbox(Color(0.16, 0.12, 0.02, 0.95), 14, Color("ffd34a"), 2), Rect2(738, 262, 196, 122))
	for k in 3:
		var p := cc + Vector2(-26 + k * 20, -6 - k * 8 + sin(t * 2 + k) * 2)
		c.draw_circle(p, 22, Color("b8860b"))
		c.draw_circle(p, 18, Color("ffd34a"))
		c.draw_string(f, p + Vector2(-6, 7), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("8a5c0c"))
	c.draw_string(f, Vector2(738, 372), "+ 5.000 moedas", HORIZONTAL_ALIGNMENT_CENTER, 196, 16, Color.WHITE)
	# setas da troca indo e voltando
	var mc := Vector2(w / 2, 262)
	c.draw_circle(mc, 56, Color(1, 0.8, 0.2, 0.12 + 0.06 * sin(t * 3)))
	c.draw_circle(mc, 46, Color("2a1c04"))
	c.draw_arc(mc, 46, 0, TAU, 48, Color("ffd34a"), 4.0)
	var off := fposmod(t * 1.2, 1.0)
	for k in 2:
		var y := mc.y - 14 + k * 28
		var dirx := 1.0 if k == 0 else -1.0
		var x0 := mc.x - 26 * dirx
		var x1 := mc.x + 22 * dirx
		c.draw_line(Vector2(x0, y), Vector2(x1, y), Color("ffe08a"), 5.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x1 + 10 * dirx, y), Vector2(x1 - 2 * dirx, y - 9), Vector2(x1 - 2 * dirx, y + 9)]), Color("ffe08a"))
		# brilhos correndo entre os itens
		var sx := lerpf(450.0, 730.0, off) if k == 0 else lerpf(730.0, 450.0, off)
		c.draw_circle(Vector2(sx, y), 4.0, Color(1, 0.95, 0.6, 0.8 * sin(off * PI)))
