extends CanvasLayer
# Tela de NOVIDADES que aparece uma vez depois de atualizar (marca em save.news_seen).
# Esta: conectar a conta Google + negociação entre amigos.

const NEWS_ID := "google1"
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
	_item(_art, "e_zeus", Vector2(660, 178))
	_item(_art, "aurora_m", Vector2(930, 178))
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
	var lbox := CenterContainer.new()
	lbox.custom_minimum_size = Vector2(600, 70)
	lbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbox)
	var connected: bool = game.net != null and str(game.net.g_mail) != ""
	_gbtn = ui.mk_btn("✓  GOOGLE JÁ CONECTADO" if connected else "G   CONECTAR AGORA", 400, 64, Color("1b8f4c") if connected else Color("4285f4"), 23)
	_gbtn.disabled = connected
	_gbtn.pressed.connect(func():
		close()
		game.net.send_glink("link")
		ui.say("Abrindo o Google... escolha sua conta e depois volte para o jogo."))
	lbox.add_child(_gbtn)
	var rbox := CenterContainer.new()
	rbox.custom_minimum_size = Vector2(600, 70)
	rbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rbox)
	var bf: Button = ui.mk_btn("VER MEUS AMIGOS", 400, 64, Color("d68a10"), 23)
	bf.pressed.connect(func():
		close()
		ui.show_screen("amigos"))
	rbox.add_child(bf)
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
	c.draw_string(f, p + Vector2(26, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, 500, 19, Color(1, 1, 1, 0.9))


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
	# ---- cartão Google (esquerda)
	var lr := Rect2(30, 128, 560, 418)
	c.draw_style_box(ui.sbox(Color(0.04, 0.08, 0.16, 0.95), 24, Color(0.26, 0.52, 0.96, 0.7), 3), lr)
	c.draw_circle(Vector2(100, 200), 44 + 3 * sin(t * 2.5), Color(1, 1, 1, 0.08))
	c.draw_circle(Vector2(100, 200), 40, Color.WHITE)
	_gee(c, Vector2(100, 200), 22)
	c.draw_string(f, Vector2(160, 190), "CONECTE SUA", HORIZONTAL_ALIGNMENT_LEFT, 400, 26, Color("8fc1ff"))
	c.draw_string(f, Vector2(160, 224), "CONTA GOOGLE", HORIZONTAL_ALIGNMENT_LEFT, 400, 30, Color.WHITE)
	var gb := Color("8fc1ff")
	_bullet(c, f, Vector2(60, 300), "Nunca perca suas moedas e itens", gb)
	_bullet(c, f, Vector2(60, 340), "Trocou de celular? Entre com o Google", gb)
	_bullet(c, f, Vector2(60, 380), "e tudo volta: nível, tacos, mesas...", gb)
	_bullet(c, f, Vector2(60, 420), "O Sinucou vai chegar na Play Store!", gb)
	c.draw_string(f, Vector2(60, 456), "Conecte agora para levar sua conta pra lá.", HORIZONTAL_ALIGNMENT_LEFT, 520, 16, Color(1, 1, 1, 0.55))
	# ---- cartão Negociação (direita)
	var rr := Rect2(610, 128, 560, 418)
	c.draw_style_box(ui.sbox(Color(0.1, 0.07, 0.02, 0.95), 24, Color(0.96, 0.77, 0.26, 0.7), 3), rr)
	c.draw_string(f, Vector2(610, 164), "NEGOCIE COM OS AMIGOS", HORIZONTAL_ALIGNMENT_CENTER, 560, 28, Color("ffd34a"))
	for r in [Rect2(654, 172, 196, 122), Rect2(924, 172, 196, 122)]:
		c.draw_style_box(ui.sbox(Color(0.03, 0.06, 0.1, 0.9), 14, Color(1, 0.83, 0.3, 0.5), 2), r)
	var mc := Vector2(887, 233)
	c.draw_circle(mc, 30, Color("2a1c04"))
	c.draw_arc(mc, 30, 0, TAU, 32, Color("ffd34a"), 3.0)
	for k in 2:
		var y := mc.y - 8 + k * 16
		var dx := 1.0 if k == 0 else -1.0
		c.draw_line(Vector2(mc.x - 14 * dx, y), Vector2(mc.x + 12 * dx, y), Color("ffe08a"), 4.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(mc.x + 18 * dx, y), Vector2(mc.x + 10 * dx, y - 6), Vector2(mc.x + 10 * dx, y + 6)]), Color("ffe08a"))
	var yb := Color("ffd34a")
	_bullet(c, f, Vector2(640, 340), "Troque tacos, mesas, bordas, efeitos", yb)
	_bullet(c, f, Vector2(640, 380), "e moedas com quem é seu amigo", yb)
	_bullet(c, f, Vector2(640, 420), "Em AMIGOS, toque no botão NEGOCIAR", yb)
	c.draw_string(f, Vector2(640, 456), "Os dois confirmam e a troca é segura.", HORIZONTAL_ALIGNMENT_LEFT, 520, 16, Color(1, 1, 1, 0.55))
