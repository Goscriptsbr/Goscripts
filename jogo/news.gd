extends CanvasLayer
# Tela de NOVIDADES que aparece uma vez depois de atualizar (marca em save.news_seen).
# Esta: conectar a conta Google + presentes para amigos + negociação entre amigos.

const NEWS_ID := "presentes1"
const AV = preload("res://avatars.gd")

var game: Node
var ui
var root: Control
var _art: Control
var _t := 0.0
var _fx: Array = []
var _gbtn: Button


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
	dimr.color = Color(0, 0, 0, 0.8)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1200, 670)
	card.add_theme_stylebox_override("panel", ui.sbox(Color(0.02, 0.04, 0.08, 0.98), 30, Color("f4c542"), 4, 0))
	cc.add_child(card)
	card.pivot_offset = Vector2(600, 335)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.custom_minimum_size = Vector2(1200, 670)
	_art.clip_contents = true
	card.add_child(_art)
	_art.draw.connect(_draw_art)
	# itens de verdade no cartão da negociação
	_item(_art, "e_zeus", Vector2(812, 240), 0.62)
	_item(_art, "aurora_m", Vector2(1000, 240), 0.62)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 470)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sp)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	vb.add_child(row)
	var connected: bool = game.net != null and str(game.net.g_mail) != ""
	_gbtn = ui.mk_btn("✓  JÁ CONECTADO" if connected else "G   CONECTAR AGORA", 330, 62, Color("1b8f4c") if connected else Color("4285f4"), 21)
	_gbtn.disabled = connected
	_gbtn.pressed.connect(func():
		close()
		game.net.send_glink("link")
		ui.say("Abrindo o Google... escolha sua conta e depois volte para o jogo."))
	var mb: Button = ui.mk_btn("IR PARA A LOJA", 330, 62, Color("c2185b"), 21)
	mb.pressed.connect(func():
		close()
		ui.show_screen("shop"))
	var bf: Button = ui.mk_btn("VER MEUS AMIGOS", 330, 62, Color("d68a10"), 21)
	bf.pressed.connect(func():
		close()
		ui.show_screen("amigos"))
	for bt in [_gbtn, mb, bf]:
		var bx := CenterContainer.new()
		bx.custom_minimum_size = Vector2(400, 70)
		bx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bx)
		bx.add_child(bt)
	var okc := CenterContainer.new()
	okc.custom_minimum_size = Vector2(0, 100)
	okc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(okc)
	var ok: Button = ui.mk_btn("ENTENDI!", 280, 60, Color("3b4556"), 24)
	ok.pressed.connect(close)
	okc.add_child(ok)


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


func _item(parent: Control, id: String, pos: Vector2, k: float = 1.0) -> void:
	var box := Control.new()
	box.position = pos
	box.size = Vector2(184, 110)
	box.scale = Vector2(k, k)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var pv := Control.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.size = Vector2(184, 150)
	box.add_child(pv)
	if id.begins_with("e_") or id.begins_with("m_"):
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


func _gee(c: Control, p: Vector2, r: float) -> void:
	# "G" colorido do Google
	var cols := [Color("ea4335"), Color("fbbc05"), Color("34a853"), Color("4285f4")]
	var segs := [[-2.6, -1.0], [2.25, 2.85], [1.1, 2.25], [-1.0, 1.1]]
	for k in 4:
		c.draw_arc(p, r, segs[k][0], segs[k][1], 16, cols[k], r * 0.36)
	c.draw_line(p, p + Vector2(r * 1.15, 0), cols[3], r * 0.36)


func _bullet(c: Control, f: Font, p: Vector2, txt: String, col: Color) -> void:
	c.draw_circle(p + Vector2(8, -6), 9, Color(col.r, col.g, col.b, 0.25))
	c.draw_line(p + Vector2(3, -6), p + Vector2(7, -2), col, 2.5)
	c.draw_line(p + Vector2(7, -2), p + Vector2(13, -11), col, 2.5)
	c.draw_string(f, p + Vector2(26, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, 310, 17, Color(1, 1, 1, 0.9))


func _draw_art() -> void:
	var c := _art
	var f: Font = ThemeDB.fallback_font
	var t := _t
	var w := 1200.0
	for k in 14:
		var a := t * 0.12 + k * TAU / 14.0
		var p0 := Vector2(w / 2, 90)
		c.draw_colored_polygon(PackedVector2Array([p0, p0 + Vector2.from_angle(a - 0.07) * 900, p0 + Vector2.from_angle(a + 0.07) * 900]), Color(1, 0.8, 0.25, 0.02))
	var bw := 300.0
	var by := 20.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(w / 2 - bw / 2 - 22, by + 21), Vector2(w / 2 - bw / 2, by), Vector2(w / 2 + bw / 2, by), Vector2(w / 2 + bw / 2 + 22, by + 21), Vector2(w / 2 + bw / 2, by + 42), Vector2(w / 2 - bw / 2, by + 42)]), Color("e53935"))
	c.draw_string(f, Vector2(w / 2 - bw / 2, by + 31), "★  NOVIDADES  ★", HORIZONTAL_ALIGNMENT_CENTER, bw, 22, Color.WHITE)
	var pulse := 1.0 + 0.025 * sin(t * 3.0)
	c.draw_set_transform(Vector2(w / 2, 104), 0.0, Vector2(pulse, pulse))
	c.draw_string_outline(f, Vector2(-500, 0), "ATUALIZAÇÃO DO SINUCOU", HORIZONTAL_ALIGNMENT_CENTER, 1000, 40, 10, Color(0, 0, 0, 0.7))
	c.draw_string(f, Vector2(-500, 0), "ATUALIZAÇÃO DO SINUCOU", HORIZONTAL_ALIGNMENT_CENTER, 1000, 40, Color("ffd34a"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cw := 370.0
	var xs := [30.0, 415.0, 800.0]
	var cy := 128.0
	var chh := 418.0
	# ---- 1) Google
	var x0: float = xs[0]
	c.draw_style_box(ui.sbox(Color(0.04, 0.08, 0.16, 0.95), 24, Color(0.26, 0.52, 0.96, 0.7), 3), Rect2(x0, cy, cw, chh))
	var gc := Vector2(x0 + cw / 2, cy + 70)
	c.draw_circle(gc, 44 + 3 * sin(t * 2.5), Color(1, 1, 1, 0.08))
	c.draw_circle(gc, 40, Color.WHITE)
	_gee(c, gc, 22)
	c.draw_string(f, Vector2(x0, cy + 148), "CONECTE SUA", HORIZONTAL_ALIGNMENT_CENTER, cw, 22, Color("8fc1ff"))
	c.draw_string(f, Vector2(x0, cy + 178), "CONTA GOOGLE", HORIZONTAL_ALIGNMENT_CENTER, cw, 28, Color.WHITE)
	var gb := Color("8fc1ff")
	_bullet(c, f, Vector2(x0 + 26, cy + 222), "Nunca perca moedas e itens", gb)
	_bullet(c, f, Vector2(x0 + 26, cy + 256), "Trocou de celular? É só entrar", gb)
	_bullet(c, f, Vector2(x0 + 26, cy + 290), "Leve sua conta pra Play Store", gb)
	c.draw_string(f, Vector2(x0, cy + 324), "O Sinucou já está na Play Store!", HORIZONTAL_ALIGNMENT_CENTER, cw, 15, Color(1, 1, 1, 0.55))
	# ---- 2) Presentes
	var x1: float = xs[1]
	c.draw_style_box(ui.sbox(Color(0.12, 0.03, 0.08, 0.95), 24, Color(1, 0.54, 0.72, 0.7), 3), Rect2(x1, cy, cw, chh))
	c.draw_string(f, Vector2(x1, cy + 36), "PRESENTEIE", HORIZONTAL_ALIGNMENT_CENTER, cw, 22, Color("ff8ab8"))
	c.draw_string(f, Vector2(x1, cy + 66), "UM AMIGO", HORIZONTAL_ALIGNMENT_CENTER, cw, 28, Color.WHITE)
	if game.gift != null:
		var wl: Array = game.gift.WRAPS
		var bounce := absf(sin(t * 2.4)) * 8.0
		game.gift.draw_box(c, Vector2(x1 + 100, cy + 170), 70, wl[2], t)
		game.gift.draw_box(c, Vector2(x1 + cw / 2, cy + 160 - bounce), 96, wl[4], t, 0.0, 0.0)
		game.gift.draw_box(c, Vector2(x1 + cw - 100, cy + 170), 70, wl[1], t)
	var rb := Color("ff9ac4")
	_bullet(c, f, Vector2(x1 + 26, cy + 222), "Qualquer item da loja", rb)
	_bullet(c, f, Vector2(x1 + 26, cy + 256), "Escolha o embrulho e um recado", rb)
	_bullet(c, f, Vector2(x1 + 26, cy + 290), "Ele abre no inventário", rb)
	c.draw_string(f, Vector2(x1, cy + 324), "Na LOJA, toque no botão rosa de presente.", HORIZONTAL_ALIGNMENT_CENTER, cw, 15, Color(1, 1, 1, 0.55))
	# ---- 3) Negociação
	var x2: float = xs[2]
	c.draw_style_box(ui.sbox(Color(0.1, 0.07, 0.02, 0.95), 24, Color(0.96, 0.77, 0.26, 0.7), 3), Rect2(x2, cy, cw, chh))
	c.draw_string(f, Vector2(x2, cy + 36), "NEGOCIE COM", HORIZONTAL_ALIGNMENT_CENTER, cw, 22, Color("ffd34a"))
	c.draw_string(f, Vector2(x2, cy + 66), "OS AMIGOS", HORIZONTAL_ALIGNMENT_CENTER, cw, 28, Color.WHITE)
	for r in [Rect2(x2 + 8, cy + 108, 122, 76), Rect2(x2 + 196, cy + 108, 122, 76)]:
		c.draw_style_box(ui.sbox(Color(0.03, 0.06, 0.1, 0.9), 12, Color(1, 0.83, 0.3, 0.5), 2), r)
	var mc := Vector2(x2 + 163, cy + 146)
	c.draw_circle(mc, 24, Color("2a1c04"))
	c.draw_arc(mc, 24, 0, TAU, 32, Color("ffd34a"), 3.0)
	for k in 2:
		var y := mc.y - 6 + k * 12
		var dx := 1.0 if k == 0 else -1.0
		c.draw_line(Vector2(mc.x - 11 * dx, y), Vector2(mc.x + 9 * dx, y), Color("ffe08a"), 3.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(mc.x + 14 * dx, y), Vector2(mc.x + 8 * dx, y - 5), Vector2(mc.x + 8 * dx, y + 5)]), Color("ffe08a"))
	var yb := Color("ffd34a")
	_bullet(c, f, Vector2(x2 + 26, cy + 222), "Tacos, mesas, bordas e moedas", yb)
	_bullet(c, f, Vector2(x2 + 26, cy + 256), "Em AMIGOS, toque em NEGOCIAR", yb)
	_bullet(c, f, Vector2(x2 + 26, cy + 290), "Os dois confirmam: é seguro", yb)
	c.draw_string(f, Vector2(x2, cy + 324), "Itens voando de um lado pro outro!", HORIZONTAL_ALIGNMENT_CENTER, cw, 15, Color(1, 1, 1, 0.55))
