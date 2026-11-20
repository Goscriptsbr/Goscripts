extends CanvasLayer
# "OITÃO", o mascote do tutorial: uma bola 8 com cara, que fala num balão (texto aparecendo letra por
# letra), acende um holofote na parte da tela que está explicando e mostra uma mãozinha animada
# (tocar, arrastar, puxar). Tudo desenhado em código.

signal next_pressed
signal skip_pressed

const CARDS = preload("res://cards.gd")

var ui: CanvasLayer
var root: Control
var canvas: Control
var bubble: PanelContainer
var lbl: Label
var btn_row: HBoxContainer
var btn_next: Button
var btn_skip: Button
var extra_box: Control

var spot := Rect2()          # holofote (vazio = sem)
var hand := ""               # "", "tap", "drag_down", "drag_side", "drag_arc", "spin"
var hand_at := Vector2.ZERO
var mood := "happy"          # happy, wow, think, party
var t := 0.0
var talk_t := 0.0
var full_text := ""
var shown := 0.0
var coach_pos := Vector2(120, 600)
var look_at := Vector2(640, 360)
var block := true
var active := false
var dim_alpha := 0.0
var side_cur := "bottom"


func setup(u: CanvasLayer) -> void:
	ui = u
	layer = 70
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_canvas)
	root.add_child(canvas)
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", ui.sbox(Color(1, 0.99, 0.95, 0.98), 26, Color("f4c542"), 4, 0))
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bubble)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	bubble.add_child(ui.margin(vb, 18))
	lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 23)
	lbl.add_theme_color_override("font_color", Color("1d2433"))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(560, 0)
	vb.add_child(lbl)
	extra_box = VBoxContainer.new()
	vb.add_child(extra_box)
	btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(btn_row)
	btn_skip = ui.mk_btn("PULAR TUTORIAL", 200, 50, Color("8a93a6"), 17)
	btn_skip.pressed.connect(func(): skip_pressed.emit())
	btn_row.add_child(btn_skip)
	btn_next = ui.mk_btn("PRÓXIMO ▶", 200, 56, Color("1fa85a"), 22)
	btn_next.pressed.connect(func():
		if shown < float(full_text.length()):
			shown = float(full_text.length())   # primeiro toque: mostra o texto todo
			return
		next_pressed.emit())
	btn_row.add_child(btn_next)
	visible = false


# mostra uma fala. opts: spot (Rect2), hand, hand_at, btn ("" = espera uma ação do jogador),
# mood, side ("bottom"/"top"), skip (bool), extra (Control com ilustração), block (bool)
func say(text: String, opts: Dictionary = {}) -> void:
	visible = true
	active = true
	full_text = text
	shown = 0.0
	lbl.text = text
	lbl.visible_characters = 0
	spot = opts.get("spot", Rect2())
	hand = str(opts.get("hand", ""))
	hand_at = opts.get("hand_at", spot.get_center() if spot.size != Vector2.ZERO else Vector2.ZERO)
	mood = str(opts.get("mood", "happy"))
	var bt := str(opts.get("btn", "PRÓXIMO ▶"))
	btn_next.visible = bt != ""
	btn_next.text = bt
	btn_skip.visible = bool(opts.get("skip", true))
	btn_skip.text = str(opts.get("skip_txt", "PULAR TUTORIAL"))
	for c in extra_box.get_children():
		c.queue_free()
	if opts.has("extra"):
		extra_box.add_child(opts.extra)
	# com botão a tela fica travada (só o balão responde); esperando ação, o jogador mexe no jogo
	block = bool(opts.get("block", bt != ""))
	root.mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE
	var vs: Vector2 = root.get_viewport_rect().size
	var side := str(opts.get("side", "auto"))
	if side == "auto":
		side = "top" if spot.size != Vector2.ZERO and spot.get_center().y > vs.y * 0.55 else "bottom"
	bubble.reset_size()
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: Vector2 = bubble.size
	var bx := clampf(vs.x * 0.5 - bs.x * 0.5 + 60.0, 150.0, vs.x - bs.x - 16.0)
	if opts.has("bx"):
		bx = float(opts.bx)
	var by := vs.y - bs.y - 18.0 if side == "bottom" else 18.0
	side_cur = side
	bubble.position = Vector2(bx, by)
	coach_pos = Vector2(bx - 70.0, by + bs.y - 60.0) if side == "bottom" else Vector2(bx - 70.0, by + 70.0)
	look_at = spot.get_center() if spot.size != Vector2.ZERO else Vector2(bx + bs.x * 0.5, by + bs.y * 0.5)


func hide_coach() -> void:
	active = false
	visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	if shown < float(full_text.length()):
		shown = minf(float(full_text.length()), shown + delta * 48.0)
		lbl.visible_characters = int(shown)
		talk_t += delta
	# o balão cresce enquanto o texto quebra em linhas: nunca deixa sair da tela
	var vs: Vector2 = root.get_viewport_rect().size
	if bubble.position.y + bubble.size.y > vs.y - 12.0:
		bubble.position.y = maxf(12.0, vs.y - bubble.size.y - 12.0)
	coach_pos = Vector2(bubble.position.x - 70.0, bubble.position.y + bubble.size.y - 60.0) if side_cur == "bottom" else Vector2(bubble.position.x - 70.0, bubble.position.y + 70.0)
	dim_alpha = move_toward(dim_alpha, 0.62 if spot.size != Vector2.ZERO else (0.45 if block else 0.0), delta * 2.5)
	canvas.queue_redraw()


func _draw_canvas() -> void:
	var c := canvas
	var vs: Vector2 = c.get_viewport_rect().size
	# escurece tudo menos o holofote
	if dim_alpha > 0.01:
		var dc := Color(0, 0, 0, dim_alpha)
		if spot.size == Vector2.ZERO:
			c.draw_rect(Rect2(Vector2.ZERO, vs), dc)
		else:
			var r := spot.grow(10)
			c.draw_rect(Rect2(0, 0, vs.x, r.position.y), dc)
			c.draw_rect(Rect2(0, r.end.y, vs.x, vs.y - r.end.y), dc)
			c.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dc)
			c.draw_rect(Rect2(r.end.x, r.position.y, vs.x - r.end.x, r.size.y), dc)
	if spot.size != Vector2.ZERO:
		var pul := 0.5 + 0.5 * sin(t * 4.0)
		var r2 := spot.grow(10 + pul * 4.0)
		c.draw_style_box(_ring(Color(1, 0.86, 0.3, 0.9), 4.0 + pul * 2.0), r2)
		c.draw_style_box(_ring(Color(1, 0.86, 0.3, 0.25), 12.0), r2.grow(6))
	_draw_hand(c)
	_draw_oitao(c, coach_pos, 52.0)


func _ring(col: Color, w: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(w))
	sb.set_corner_radius_all(18)
	return sb


# mãozinha: tocar (pulsa e faz ondinhas), arrastar para baixo (barra de força), arrastar de lado, círculo
func _draw_hand(c: Control) -> void:
	if hand == "":
		return
	var p := hand_at
	var press := 0.0
	match hand:
		"tap":
			var k := fposmod(t * 1.3, 1.0)
			press = 1.0 if k < 0.25 else 0.0
			for i in 2:
				var kk := fposmod(k + float(i) * 0.5, 1.0)
				c.draw_arc(p, 10.0 + kk * 40.0, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - kk)), 3.0)
		"drag_down":
			var k2 := fposmod(t * 0.7, 1.0)
			var e := smoothstep(0.1, 0.8, k2)
			c.draw_line(p, p + Vector2(0, 230), Color(1, 1, 1, 0.25), 6.0)
			c.draw_line(p, p + Vector2(0, 230 * e), Color(1, 0.86, 0.3, 0.8), 6.0)
			p += Vector2(0, 230.0 * e)
			press = 1.0 if k2 < 0.85 else 0.0
		"drag_side":
			var k3 := fposmod(t * 0.6, 1.0)
			var off := sin(k3 * TAU) * 120.0
			c.draw_arc(hand_at, 120.0, -0.5, 0.5, 24, Color(1, 1, 1, 0.3), 5.0)
			p += Vector2(off, -absf(off) * 0.25)
			press = 1.0
		"spin":
			var a := t * 2.5
			p += Vector2(cos(a), sin(a)) * 22.0
			press = 1.0
	_hand_shape(c, p + Vector2(6, 10), press)


func _hand_shape(c: Control, tip: Vector2, press: float) -> void:
	var s := 1.0 - press * 0.12
	var o := tip
	var skin := Color("ffd9b8")
	var line := Color("8a5a3a")
	# dedo indicador apontando para cima-esquerda + mão
	var pts := PackedVector2Array([
		o + Vector2(0, 0) * s, o + Vector2(12, -2) * s, o + Vector2(16, 30) * s, o + Vector2(40, 34) * s,
		o + Vector2(50, 46) * s, o + Vector2(48, 78) * s, o + Vector2(20, 88) * s, o + Vector2(2, 70) * s,
		o + Vector2(-6, 44) * s, o + Vector2(2, 36) * s,
	])
	c.draw_colored_polygon(pts, Color(0, 0, 0, 0.25))
	for i in pts.size():
		pts[i] -= Vector2(3, 3)
	c.draw_colored_polygon(pts, skin)
	var pl := pts.duplicate()
	pl.append(pts[0])
	c.draw_polyline(pl, line, 2.0)
	c.draw_line(pts[2], pts[2] + Vector2(-2, 14) * s, line, 1.5)
	c.draw_circle(pts[0] + Vector2(6, 4), 4.0, Color(1, 1, 1, 0.5 + 0.5 * press))


# o mascote: bola 8 com olhos que olham para o que está explicando, sobrancelhas e boca falando
func _draw_oitao(c: Control, ctr: Vector2, r: float) -> void:
	var bob := sin(t * 2.6) * 5.0 + (sin(t * 18.0) * 2.0 if mood == "party" else 0.0)
	ctr.y += bob
	c.draw_circle(ctr + Vector2(0, r + 8), r * 0.75, Color(0, 0, 0, 0.0))
	c.draw_set_transform(ctr + Vector2(0, r * 0.95), 0.0, Vector2(1.0, 0.25))
	c.draw_circle(Vector2.ZERO, r * 0.8, Color(0, 0, 0, 0.35))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_circle(ctr, r, Color("15171c"))
	c.draw_circle(ctr + Vector2(-r * 0.3, -r * 0.35), r * 0.55, Color(1, 1, 1, 0.07))
	c.draw_circle(ctr + Vector2(-r * 0.42, -r * 0.5), r * 0.16, Color(1, 1, 1, 0.55))
	# "8" na testa
	var fc := ctr + Vector2(r * 0.38, -r * 0.48)
	c.draw_circle(fc, r * 0.26, Color("f4f4ee"))
	c.draw_string(ThemeDB.fallback_font, fc + Vector2(-r * 0.2, r * 0.13), "8", HORIZONTAL_ALIGNMENT_CENTER, r * 0.4, int(r * 0.34), Color("111111"))
	# olhos
	var dir := (look_at - ctr).normalized()
	var blink := 1.0 if fposmod(t, 3.7) > 0.12 else 0.1
	for sx in [-1.0, 1.0]:
		var ec := ctr + Vector2(sx * r * 0.33 - r * 0.05, -r * 0.02)
		c.draw_set_transform(ec, 0.0, Vector2(1.0, blink))
		c.draw_circle(Vector2.ZERO, r * 0.24, Color.WHITE)
		c.draw_circle(dir * r * 0.09, r * 0.12, Color("1b3a6b"))
		c.draw_circle(dir * r * 0.09, r * 0.065, Color.BLACK)
		c.draw_circle(dir * r * 0.09 + Vector2(-r * 0.03, -r * 0.04), r * 0.03, Color.WHITE)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# sobrancelha
		var lift: float = -r * 0.08 if mood == "wow" or mood == "party" else (r * 0.03 * sx if mood == "think" else 0.0)
		c.draw_line(ec + Vector2(-r * 0.2, -r * 0.33 + lift), ec + Vector2(r * 0.2, -r * 0.36 + lift - (r * 0.05 * sx if mood == "think" else 0.0)), Color("f4f4ee"), 3.0)
	# boca: abre e fecha enquanto o texto aparece
	var talking := shown < float(full_text.length())
	var mo := (0.5 + 0.5 * sin(talk_t * 22.0)) if talking else 0.0
	var mc := ctr + Vector2(-r * 0.05, r * 0.42)
	if mood == "wow" or mood == "party":
		c.draw_circle(mc, r * (0.1 + 0.06 * mo), Color("e8485a"))
	else:
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI * float(i) / 12.0
			pts.append(mc + Vector2(cos(a) * r * 0.24, sin(a) * r * (0.1 + 0.16 * mo)))
		pts.append(mc + Vector2(-r * 0.24, 0))
		c.draw_colored_polygon(pts, Color("e8485a"))
		c.draw_line(mc + Vector2(-r * 0.25, 0), mc + Vector2(r * 0.25, 0), Color("f4f4ee"), 2.0)
	# gravatinha vermelha
	var bt := ctr + Vector2(0, r * 0.98)
	c.draw_colored_polygon(PackedVector2Array([bt, bt + Vector2(-r * 0.3, -r * 0.16), bt + Vector2(-r * 0.3, r * 0.16)]), Color("d8262c"))
	c.draw_colored_polygon(PackedVector2Array([bt, bt + Vector2(r * 0.3, -r * 0.16), bt + Vector2(r * 0.3, r * 0.16)]), Color("d8262c"))
	c.draw_circle(bt, r * 0.07, Color("a51c22"))


# ---------------------------------------------------------------- ilustrações para o balão
# ordem das cartas do truco (da mais fraca para a mais forte)
static func card_strip(ranks: Array, suits: Array, labels: Array = [], hl: int = -1) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(560, 96)
	c.draw.connect(func():
		var n := ranks.size()
		var w := minf(52.0, 540.0 / float(n) - 4.0)
		var x0 := (560.0 - (w + 4.0) * float(n)) * 0.5
		for i in n:
			var r := Rect2(x0 + float(i) * (w + 4.0), 6, w, w * 1.4)
			if i == hl:
				r.position.y -= 4
				c.draw_style_box(_card_box(Color("fffbea"), Color("f4c542"), 3), r)
			else:
				c.draw_style_box(_card_box(Color.WHITE, Color("c8ccd6"), 1), r)
			var su: int = suits[i] if i < suits.size() else 3
			var col := Color("c0303a") if su == 0 or su == 2 else Color("1d2433")
			c.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, w * 0.5), str(ranks[i]), HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.42), col)
			CARDS.suit(c, r.position + Vector2(w * 0.5, w * 0.95), w * 0.38, su, col)
			if i < labels.size() and str(labels[i]) != "":
				c.draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 10, r.end.y + 14), str(labels[i]), HORIZONTAL_ALIGNMENT_CENTER, w + 20, 12, Color("5a6478")))
	return c


static func _card_box(bg: Color, bd: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bd
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 3
	return sb


# setinha "fraca  →  forte"
static func weak_strong() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(560, 22)
	c.draw.connect(func():
		c.draw_string(ThemeDB.fallback_font, Vector2(10, 16), "mais fraca", HORIZONTAL_ALIGNMENT_LEFT, 120, 15, Color("7a8294"))
		c.draw_line(Vector2(110, 11), Vector2(440, 11), Color("c8ccd6"), 3.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(448, 11), Vector2(436, 4), Vector2(436, 18)]), Color("c8ccd6"))
		c.draw_string(ThemeDB.fallback_font, Vector2(456, 16), "mais forte", HORIZONTAL_ALIGNMENT_LEFT, 120, 15, Color("1fa85a")))
	return c


# bolas: lisas (1-7), a 8 e listradas (9-15)
static func balls_strip() -> Control:
	var cols := {1: Color("f4c51e"), 2: Color("1f5fd1"), 3: Color("d8262c"), 4: Color("6a2aa8"), 5: Color("f07a12"), 6: Color("12904a"), 7: Color("8a1f1f"), 8: Color("141414")}
	var c := Control.new()
	c.custom_minimum_size = Vector2(560, 92)
	c.draw.connect(func():
		var f := ThemeDB.fallback_font
		var order := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
		for i in order.size():
			var n: int = order[i]
			var p := Vector2(28 + i * 36.0 + (12.0 if n >= 8 else 0.0) + (12.0 if n >= 9 else 0.0), 34)
			var r := 15.0
			var bc: Color = cols.get(n if n <= 8 else n - 8, Color.WHITE)
			c.draw_circle(p + Vector2(1, 2), r, Color(0, 0, 0, 0.25))
			if n > 8:
				c.draw_circle(p, r, Color("f4f4ee"))
				c.draw_rect(Rect2(p.x - r * 0.95, p.y - r * 0.5, r * 1.9, r), bc)
			else:
				c.draw_circle(p, r, bc)
			c.draw_circle(p, r * 0.5, Color("f4f4ee"))
			c.draw_string(f, p + Vector2(-r, r * 0.22), str(n), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 11, Color("111111"))
			c.draw_circle(p + Vector2(-r * 0.4, -r * 0.45), r * 0.2, Color(1, 1, 1, 0.5))
		c.draw_string(f, Vector2(28 - 15, 72), "LISAS (1 a 7)", HORIZONTAL_ALIGNMENT_CENTER, 7 * 36.0, 15, Color("1d2433"))
		c.draw_string(f, Vector2(28 + 7 * 36.0 + 12.0 - 30, 72), "a 8", HORIZONTAL_ALIGNMENT_CENTER, 60, 15, Color("c0303a"))
		c.draw_string(f, Vector2(28 + 8 * 36.0 + 24.0 - 15, 72), "LISTRADAS (9 a 15)", HORIZONTAL_ALIGNMENT_CENTER, 7 * 36.0, 15, Color("1d2433")))
	return c
