extends CanvasLayer
# Efeitos de vitória (comprados na loja): partículas desenhadas por cima da tela do fim da partida

var kind := "confete"
var t := 0.0
var dur := 4.5
var parts: Array = []
var canvas: Control
var rng := RandomNumberGenerator.new()


func play(k: String) -> void:
	kind = k
	layer = 40
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(func(): draw_fx(canvas, canvas.get_viewport_rect().size, parts, t, kind))
	rng.randomize()


func _process(delta: float) -> void:
	t += delta
	var vs: Vector2 = canvas.get_viewport_rect().size if canvas != null else Vector2(1280, 720)
	if t < dur - 1.2:
		spawn(parts, vs, kind, delta, rng)
	step(parts, delta, kind)
	if canvas != null:
		canvas.queue_redraw()
	if t > dur and parts.is_empty():
		queue_free()


static func spawn(ps: Array, vs: Vector2, k: String, delta: float, r: RandomNumberGenerator) -> void:
	match k:
		"confete":
			for i in int(ceil(delta * 90.0)):
				ps.append({"p": Vector2(r.randf() * vs.x, -20), "v": Vector2(r.randf_range(-60, 60), r.randf_range(120, 260)), "c": Color.from_hsv(r.randf(), 0.8, 1.0), "a": r.randf() * TAU, "w": r.randf_range(-6, 6), "s": r.randf_range(6, 12), "life": 6.0})
		"moedas":
			for i in int(ceil(delta * 30.0)):
				ps.append({"p": Vector2(r.randf() * vs.x, -30), "v": Vector2(r.randf_range(-30, 30), r.randf_range(160, 320)), "a": r.randf() * TAU, "w": r.randf_range(3, 8), "s": r.randf_range(14, 22), "life": 6.0})
		"coracoes":
			for i in int(ceil(delta * 22.0)):
				ps.append({"p": Vector2(r.randf() * vs.x, vs.y + 20), "v": Vector2(r.randf_range(-20, 20), r.randf_range(-160, -90)), "c": [Color("ff3d6e"), Color("ff7aa8"), Color("e01e4f")][r.randi() % 3], "s": r.randf_range(12, 24), "a": r.randf() * TAU, "w": r.randf_range(1, 3), "life": 6.0})
		"estrelas":
			for i in int(ceil(delta * 26.0)):
				ps.append({"p": Vector2(r.randf() * vs.x, r.randf() * vs.y), "v": Vector2.ZERO, "c": [Color("ffe066"), Color.WHITE, Color("7fe3ff")][r.randi() % 3], "s": r.randf_range(10, 26), "a": 0.0, "w": r.randf_range(-2, 2), "life": r.randf_range(0.8, 1.6), "max": 0.0})
		"fogos":
			if ps.size() < 30 or r.randf() < delta * 1.5:
				var c := Vector2(r.randf_range(0.15, 0.85) * vs.x, r.randf_range(0.15, 0.5) * vs.y)
				var col := Color.from_hsv(r.randf(), 0.75, 1.0)
				for j in 46:
					var an := float(j) / 46.0 * TAU
					ps.append({"p": c, "v": Vector2.from_angle(an) * r.randf_range(160, 300), "c": col, "s": 3.0, "life": r.randf_range(0.9, 1.4), "spark": true})
		"raios":
			if ps.is_empty() and r.randf() < maxf(delta * 4.0, 0.04):
				var x := r.randf_range(0.1, 0.9) * vs.x
				var pts := PackedVector2Array([Vector2(x, 0)])
				var y := 0.0
				while y < vs.y * 0.75:
					y += r.randf_range(30, 70)
					pts.append(Vector2(x + r.randf_range(-50, 50), y))
				ps.append({"pts": pts, "life": 0.35, "c": Color("bfe9ff")})


static func step(ps: Array, delta: float, k: String) -> void:
	for i in range(ps.size() - 1, -1, -1):
		var q: Dictionary = ps[i]
		q.life = float(q.life) - delta
		if q.has("p"):
			if q.has("spark"):
				q.v = (q.v as Vector2) * (1.0 - 1.6 * delta) + Vector2(0, 160) * delta
			q.p = (q.p as Vector2) + (q.v as Vector2) * delta
			q.a = float(q.get("a", 0.0)) + float(q.get("w", 0.0)) * delta
		if float(q.life) <= 0.0:
			ps.remove_at(i)


static func draw_fx(c: CanvasItem, vs: Vector2, ps: Array, t: float, k: String) -> void:
	for q in ps:
		match k:
			"confete":
				var s: float = q.s
				c.draw_set_transform(q.p, q.a, Vector2(1.0, absf(sin(float(q.a) * 2.0)) * 0.8 + 0.2))
				c.draw_rect(Rect2(-s / 2, -s / 4, s, s / 2), q.c)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"moedas":
				var sx := absf(cos(float(q.a)))
				c.draw_set_transform(q.p, 0.0, Vector2(maxf(0.15, sx), 1.0))
				c.draw_circle(Vector2.ZERO, q.s, Color("b07d12"))
				c.draw_circle(Vector2.ZERO, float(q.s) * 0.82, Color("f6c945"))
				c.draw_arc(Vector2.ZERO, float(q.s) * 0.6, 0, TAU, 16, Color("b07d12"), 2.0)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"coracoes":
				var pts := PackedVector2Array()
				var sz: float = q.s
				for j in 24:
					var tt := float(j) / 24.0 * TAU
					pts.append((q.p as Vector2) + Vector2(16.0 * pow(sin(tt), 3), -(13.0 * cos(tt) - 5.0 * cos(2 * tt) - 2.0 * cos(3 * tt) - cos(4 * tt))) * sz / 17.0 + Vector2(sin(t * 3.0 + float(q.a)) * 10.0, 0))
				var cc: Color = q.c
				cc.a = clampf(float(q.life), 0.0, 1.0)
				c.draw_colored_polygon(pts, cc)
			"estrelas":
				var lf: float = q.life
				var al := clampf(minf(lf * 2.0, 1.0), 0.0, 1.0)
				var sz2: float = float(q.s) * (0.4 + 0.6 * absf(sin(lf * 4.0)))
				var col: Color = q.c
				col.a = al
				var st := PackedVector2Array()
				for j in 8:
					st.append((q.p as Vector2) + Vector2.from_angle(float(j) * TAU / 8.0) * (sz2 if j % 2 == 0 else sz2 * 0.25))
				c.draw_colored_polygon(st, col)
			"fogos":
				var cf: Color = q.c
				cf.a = clampf(float(q.life), 0.0, 1.0)
				c.draw_circle(q.p, 3.0, cf)
				c.draw_line(q.p, (q.p as Vector2) - (q.v as Vector2) * 0.05, Color(cf.r, cf.g, cf.b, cf.a * 0.5), 2.0)
			"raios":
				var ca: Color = q.c
				ca.a = clampf(float(q.life) / 0.35, 0.0, 1.0)
				c.draw_polyline(q.pts, Color(1, 1, 1, ca.a), 4.0)
				c.draw_polyline(q.pts, Color(ca.r, ca.g, ca.b, ca.a * 0.5), 12.0)
	if k == "raios":
		var flash := 0.0
		for q in ps:
			flash = maxf(flash, float(q.life) / 0.35)
		if flash > 0.0:
			c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.75, 0.9, 1.0, 0.12 * flash))
