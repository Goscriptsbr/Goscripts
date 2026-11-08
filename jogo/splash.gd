extends CanvasLayer
# Abertura animada da GoScripts.

const NAME_TXT := "GoScripts"
const TOTAL := 4.1

var game: Node2D
var t := 0.0
var root: Control
var bg: Control
var glow_c: Control
var logo_c: Control
var txt_c: Control
var logo_tex: Texture2D
var glow_tex: Texture2D
var font: Font
var parts: Array = []
var vw := 1280.0
var snd_p: AudioStreamPlayer
var logo_mat: ShaderMaterial
# carregamento: só começa a animação depois de preparar os gráficos (evita travadinha no texto)
var loading := true
var load_t := 0.0
var load_frames := 0
var warm: Control
var load_c: Control


func start(g: Node2D) -> void:
	game = g
	layer = 30
	font = ThemeDB.fallback_font
	logo_tex = load("res://assets/goscripts_logo.png")
	glow_tex = load("res://assets/goscripts_glow.png")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	bg = _layer()
	bg.draw.connect(_draw_bg)
	glow_c = _layer()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_c.material = add
	glow_c.draw.connect(_draw_glow)
	logo_c = _layer()
	logo_mat = ShaderMaterial.new()
	logo_mat.shader = load("res://shaders/logo_fx.gdshader")
	logo_c.material = logo_mat
	logo_c.draw.connect(_draw_logo)
	txt_c = _layer()
	txt_c.draw.connect(_draw_text)
	root.gui_input.connect(_on_input)
	if not game.bot and game.save.sfx:
		snd_p = AudioStreamPlayer.new()
		snd_p.stream = game.snd["intro"]
		add_child(snd_p)
		snd_p.play()
	for i in 46:
		parts.append({"x": randf(), "y": randf(), "s": randf_range(10.0, 40.0), "r": randf_range(1.5, 4.5), "p": randf() * TAU})
	_build_warmup()
	load_c = _layer()
	load_c.draw.connect(_draw_loading)
	if snd_p != null:
		snd_p.stop()


# desenha uma vez, quase invisível, tudo que tem shader pesado: o celular compila agora, no carregamento
func _build_warmup() -> void:
	warm = Control.new()
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warm.modulate.a = 0.02
	root.add_child(warm)
	root.move_child(warm, 0)
	for sp in ["ball", "cue", "cue_mythic", "felt", "logo_fx", "wood"]:
		var r := ColorRect.new()
		r.size = Vector2(48, 48)
		r.position = Vector2(-40, -40)
		var mt := ShaderMaterial.new()
		mt.shader = load("res://shaders/%s.gdshader" % sp)
		r.material = mt
		warm.add_child(r)
	var tx := TextureRect.new()
	tx.texture = logo_tex
	tx.size = Vector2(32, 32)
	tx.position = Vector2(-40, -40)
	warm.add_child(tx)
	var lb := Label.new()
	lb.text = NAME_TXT + " SINUCOU 0123456789 ÁÉÍÓÚÇÃÕ"
	lb.position = Vector2(-400, -60)
	lb.add_theme_font_size_override("font_size", 64)
	warm.add_child(lb)


func _draw_loading() -> void:
	if not loading:
		return
	var vh := 720.0
	load_c.draw_rect(Rect2(0, 0, vw, vh), Color("02050d"))
	var cx := vw / 2.0
	var a0 := load_t * 5.0
	load_c.draw_arc(Vector2(cx, vh * 0.5), 26.0, a0, a0 + 4.2, 32, Color(0.2, 0.85, 1.0, 0.9), 5.0)
	var p := clampf(load_t / 1.2, 0.0, 1.0)
	load_c.draw_rect(Rect2(cx - 120, vh * 0.5 + 56, 240, 6), Color(1, 1, 1, 0.12))
	load_c.draw_rect(Rect2(cx - 120, vh * 0.5 + 56, 240 * p, 6), Color(0.2, 0.85, 1.0, 0.9))
	load_c.draw_string(font, Vector2(cx - 150, vh * 0.5 + 100), "Carregando...", HORIZONTAL_ALIGNMENT_CENTER, 300, 22, Color(1, 1, 1, 0.7))


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and t > 0.6 and not loading:
		t = maxf(t, TOTAL - 0.45)


func _process(delta: float) -> void:
	vw = get_viewport().get_visible_rect().size.x
	if loading:
		# espera alguns quadros lisos seguidos (gráficos prontos) ou no máximo 3 s
		load_t += minf(delta, 0.1)
		load_frames = load_frames + 1 if delta < 0.04 else 0
		load_c.queue_redraw()
		if (load_frames >= 12 and load_t > 0.5) or load_t > 3.0:
			loading = false
			warm.queue_free()
			load_c.queue_redraw()
			if snd_p != null:
				snd_p.play()
		return
	# um quadro lento não faz a animação "pular"
	t += minf(delta, 1.0 / 30.0)
	vw = get_viewport().get_visible_rect().size.x
	if snd_p != null and t > TOTAL - 0.45:
		snd_p.volume_db = linear_to_db(maxf(0.001, (TOTAL - t) / 0.45))
	var fade := clampf((TOTAL - t) / 0.45, 0.0, 1.0)
	root.modulate.a = fade
	bg.queue_redraw()
	glow_c.queue_redraw()
	logo_c.queue_redraw()
	txt_c.queue_redraw()
	if t >= TOTAL:
		game.music_ok = true
		queue_free()


func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


func ease_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var k := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + c3 * k * k * k + c1 * k * k


func logo_center() -> Vector2:
	return Vector2(vw / 2.0, 255.0 + sin(t * 1.9) * 3.0 * clampf(t - 1.0, 0.0, 1.0))


func logo_w() -> float:
	return minf(vw * 0.42, 440.0)


func _draw_bg() -> void:
	var vh := 720.0
	var top := Color("0a1c3a")
	var bot := Color("02050d")
	bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(vw, vh), Vector2(0, vh)]), PackedColorArray([top, top, bot, bot]))
	var c := logo_center()
	var a := clampf(t / 1.2, 0.0, 1.0)
	for k in 8:
		bg.draw_circle(c, 90.0 + k * 70.0 + sin(t * 1.6) * 8.0, Color(0.05, 0.5, 0.85, 0.03 * (1.0 - k / 8.0) * a))
	for p in parts:
		var y: float = fposmod(p.y * vh - t * p.s, vh + 20.0)
		var x: float = p.x * vw + sin(t * 0.8 + p.p) * 12.0
		var tw := 0.35 + 0.35 * sin(t * 2.0 + p.p)
		bg.draw_circle(Vector2(x, y), p.r, Color(0.2, 0.85, 1.0, tw * 0.5 * a))


func _draw_glow() -> void:
	var c0 := logo_center()
	# raios de luz girando atrás da logo
	var ra := clampf((t - 0.3) / 1.0, 0.0, 1.0) * 0.55
	for r in 12:
		var ang := t * 0.22 + r * TAU / 12.0
		var wd := 0.075 + 0.03 * sin(t * 1.3 + r)
		var len := 560.0
		var pa := PackedVector2Array([c0, c0 + Vector2.from_angle(ang - wd) * len, c0 + Vector2.from_angle(ang + wd) * len])
		var c_in := Color(0.2, 0.7, 1.0, 0.11 * ra)
		var c_out := Color(0.1, 0.4, 0.9, 0.0)
		glow_c.draw_polygon(pa, PackedColorArray([c_in, c_out, c_out]))
	# onda de choque no impacto
	var rk := (t - 1.0) / 0.9
	if rk > 0.0 and rk < 1.0:
		var rad := 30.0 + ease_out(rk) * 620.0
		glow_c.draw_arc(c0, rad, 0, TAU, 96, Color(0.4, 0.9, 1.0, 0.55 * (1.0 - rk)), 5.0 * (1.0 - rk) + 1.0)
		glow_c.draw_arc(c0, rad * 0.8, 0, TAU, 96, Color(0.2, 0.6, 1.0, 0.3 * (1.0 - rk)), 3.0)
		glow_c.draw_rect(Rect2(0, 0, vw, 720), Color(0.15, 0.5, 0.9, 0.1 * (1.0 - rk)), true)
	var s := logo_w() / 450.0
	var sz := Vector2(glow_tex.get_width(), glow_tex.get_height()) * s
	var a := clampf(t / 0.9, 0.0, 1.0) * (0.55 + 0.25 * sin(t * 3.0))
	var sc := 0.9 + 0.1 * ease_out(t / 1.0)
	glow_c.draw_texture_rect(glow_tex, Rect2(logo_center() - sz * sc / 2.0, sz * sc), false, Color(1, 1, 1, a))


func _draw_logo() -> void:
	var p := clampf(t / 1.0, 0.0, 1.0)
	var e := ease_out(p)
	var lw := logo_w()
	var lh := lw * float(logo_tex.get_height()) / float(logo_tex.get_width())
	var sc := 0.84 + 0.16 * ease_back(p)
	var sz := Vector2(lw, lh) * sc
	logo_mat.set_shader_parameter("reveal", e * 1.18)
	logo_mat.set_shader_parameter("alpha", clampf(t / 0.45, 0.0, 1.0))
	logo_mat.set_shader_parameter("shine", -0.4 + clampf((t - 1.9) / 1.0, 0.0, 1.0) * 2.0)
	logo_c.draw_texture_rect(logo_tex, Rect2(logo_center() - sz / 2.0, sz), false)


func _draw_text() -> void:
	var fs := 92
	var sp := 7.0
	var widths: Array = []
	var total := 0.0
	for ch in NAME_TXT:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w + sp
	total -= sp
	var x0 := vw / 2.0 - total / 2.0
	var base_y := 540.0
	var shine_x := lerpf(x0 - 120.0, x0 + total + 120.0, clampf((t - 2.15) / 0.9, 0.0, 1.0))
	var x := x0
	var n := NAME_TXT.length()
	for i in n:
		var ch := NAME_TXT[i]
		var st := 1.0 + i * 0.075
		var k := clampf((t - st) / 0.4, 0.0, 1.0)
		var w: float = widths[i]
		if k > 0.0:
			var sc := 0.55 + 0.45 * ease_back(k)
			var cx := x + w / 2.0
			var grad := float(i) / float(n - 1)
			var col := Color("19e3f6").lerp(Color("2a7be8"), grad)
			var br := smoothstep(90.0, 0.0, absf(cx - shine_x))
			col = col.lerp(Color.WHITE, br * 0.85)
			var pos := Vector2(cx - w * sc / 2.0, base_y + (1.0 - k) * 34.0)
			var fsz := int(fs * sc)
			txt_c.draw_string_outline(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 16, Color(0.1, 0.7, 1.0, 0.16 * k))
			txt_c.draw_string_outline(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 8, Color(0.1, 0.8, 1.0, 0.3 * k))
			txt_c.draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(col, k))
		x += w + sp
	# linha de luz
	var lk := ease_out((t - 1.9) / 0.7)
	if lk > 0.0:
		var lw := 440.0 * lk
		var cy := 566.0
		txt_c.draw_rect(Rect2(vw / 2.0 - lw / 2.0, cy - 5, lw, 10), Color(0.1, 0.8, 1.0, 0.12), true)
		txt_c.draw_rect(Rect2(vw / 2.0 - lw / 2.0, cy - 1.5, lw, 3), Color(0.5, 0.95, 1.0, 0.9), true)
	# apresenta
	var ak := clampf((t - 2.2) / 0.6, 0.0, 1.0)
	if ak > 0.0:
		var word := "A P R E S E N T A"
		txt_c.draw_string(font, Vector2(vw / 2.0 - 400.0, 618.0), word, HORIZONTAL_ALIGNMENT_CENTER, 800, 24, Color(1, 1, 1, 0.7 * ak))
