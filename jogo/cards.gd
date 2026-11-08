extends RefCounted
# Desenho das cartas do truco (frente e verso) com os estilos de baralho da loja.
# Usado pelo truco e pela prévia na loja/inventário.

const RANKS := ["4", "5", "6", "7", "Q", "J", "K", "A", "2", "3"]

# estilos: cores da frente, do verso e dos naipes
const STYLES := {
	"classico": {"face": Color("fbfaf4"), "edge": Color(0.2, 0.2, 0.2, 0.55), "ew": 1.0, "red": Color("c0262d"), "black": Color("161616"),
		"frame": Color(0, 0, 0, 0), "b_bg": Color("143a6b"), "b_rim": Color("f4f4f4"), "b_in": Color("1d4f8f"), "b_trim": Color("f4c542"), "b_pat": 0, "b_txt": Color("143a6b")},
	"ouro": {"face": Color("f7e7b4"), "face2": Color("fff6d6"), "edge": Color("c99312"), "ew": 3.0, "red": Color("9b111e"), "black": Color("2b1d00"),
		"frame": Color("c99312"), "b_bg": Color("7a5410"), "b_rim": Color("ffe08a"), "b_in": Color("b8861b"), "b_trim": Color("fff1b0"), "b_pat": 1, "b_txt": Color("4a3205")},
	"preto": {"face": Color("161616"), "face2": Color("262626"), "edge": Color("c8c8c8"), "ew": 2.0, "red": Color("ff4757"), "black": Color("eeeeee"),
		"frame": Color("8a8a8a"), "b_bg": Color("0b0b0b"), "b_rim": Color("c8c8c8"), "b_in": Color("181818"), "b_trim": Color("e53935"), "b_pat": 2, "b_txt": Color("0b0b0b")},
	"neon": {"face": Color("0c1030"), "face2": Color("151a48"), "edge": Color("00e5ff"), "ew": 2.0, "red": Color("ff3df2"), "black": Color("39e6ff"),
		"frame": Color("00e5ff"), "b_bg": Color("070a1f"), "b_rim": Color("00e5ff"), "b_in": Color("0c1236"), "b_trim": Color("ff3df2"), "b_pat": 3, "b_txt": Color("070a1f"), "glow": true},
	"esmeralda": {"face": Color("f3f8f1"), "edge": Color("0f6b45"), "ew": 2.5, "red": Color("b3122e"), "black": Color("0b3d2a"),
		"frame": Color("0f6b45"), "b_bg": Color("0a4430"), "b_rim": Color("d4af37"), "b_in": Color("0f6b45"), "b_trim": Color("d4af37"), "b_pat": 1, "b_txt": Color("0a4430")},
}

static var face_tex := {}


static func style(id: String) -> Dictionary:
	return STYLES.get(id, STYLES["classico"])


static func sbox(col: Color, rad: int, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(rad)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.anti_aliasing = true
	return s


static func suit(ci: CanvasItem, c: Vector2, sz: float, s: int, col: Color) -> void:
	if s == 0:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -sz), c + Vector2(sz * 0.72, 0), c + Vector2(0, sz), c + Vector2(-sz * 0.72, 0)]), col)
	elif s == 2:
		ci.draw_circle(c + Vector2(-sz * 0.42, -sz * 0.25), sz * 0.48, col)
		ci.draw_circle(c + Vector2(sz * 0.42, -sz * 0.25), sz * 0.48, col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-sz * 0.9, -sz * 0.1), c + Vector2(sz * 0.9, -sz * 0.1), c + Vector2(0, sz)]), col)
	elif s == 1:
		ci.draw_circle(c + Vector2(-sz * 0.42, sz * 0.2), sz * 0.48, col)
		ci.draw_circle(c + Vector2(sz * 0.42, sz * 0.2), sz * 0.48, col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-sz * 0.9, sz * 0.05), c + Vector2(sz * 0.9, sz * 0.05), c + Vector2(0, -sz)]), col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, sz * 0.3), c + Vector2(sz * 0.35, sz), c + Vector2(-sz * 0.35, sz)]), col)
	else:
		ci.draw_circle(c + Vector2(0, -sz * 0.45), sz * 0.42, col)
		ci.draw_circle(c + Vector2(-sz * 0.45, sz * 0.12), sz * 0.42, col)
		ci.draw_circle(c + Vector2(sz * 0.45, sz * 0.12), sz * 0.42, col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, sz * 0.1), c + Vector2(sz * 0.35, sz), c + Vector2(-sz * 0.35, sz)]), col)


# verso da carta
static func draw_back(ci: CanvasItem, r: Rect2, st: Dictionary) -> void:
	var rad := int(r.size.x * 0.1)
	ci.draw_style_box(sbox(Color(0, 0, 0, 0.35), rad), Rect2(r.position + Vector2(3, 5), r.size))
	ci.draw_style_box(sbox(st.b_bg, rad, st.b_rim, maxi(2, int(r.size.x * 0.04))), r)
	var inner := r.grow(-r.size.x * 0.11)
	ci.draw_style_box(sbox(st.b_in, maxi(2, rad - 3), st.b_trim, 1), inner)
	var pat: int = int(st.b_pat)
	var lc: Color = st.b_trim
	if pat == 1:
		# treliça de losangos (cortada certinho na borda de dentro)
		var step := inner.size.x / 5.0
		var lc1 := Color(lc.r, lc.g, lc.b, 0.3)
		for k in range(-8, 14):
			var x0 := inner.position.x + k * step
			_seg(ci, Vector2(x0, inner.position.y), Vector2(x0 + inner.size.y, inner.end.y), inner, lc1, 1.0)
			_seg(ci, Vector2(x0, inner.end.y), Vector2(x0 + inner.size.y, inner.position.y), inner, lc1, 1.0)
	elif pat == 2:
		# listras diagonais vermelhas
		var step2 := inner.size.x / 4.0
		for k in range(-8, 12):
			var x1 := inner.position.x + k * step2
			_seg(ci, Vector2(x1, inner.position.y), Vector2(x1 + inner.size.y, inner.end.y), inner, Color(lc.r, lc.g, lc.b, 0.55), maxf(1.0, r.size.x * 0.025))
	elif pat == 3:
		# grade neon
		var gs := inner.size.x / 6.0
		var gx := inner.position.x + gs
		while gx < inner.end.x - 1.0:
			ci.draw_line(Vector2(gx, inner.position.y + 2), Vector2(gx, inner.end.y - 2), Color(st.b_rim.r, st.b_rim.g, st.b_rim.b, 0.25), 1.0)
			gx += gs
		var gy := inner.position.y + gs
		while gy < inner.end.y - 1.0:
			ci.draw_line(Vector2(inner.position.x + 2, gy), Vector2(inner.end.x - 2, gy), Color(st.b_rim.r, st.b_rim.g, st.b_rim.b, 0.25), 1.0)
			gy += gs
	var cc := inner.get_center()
	var d := inner.size.x * 0.28
	ci.draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -d * 1.3), cc + Vector2(d, 0), cc + Vector2(0, d * 1.3), cc + Vector2(-d, 0)]), Color(lc.r, lc.g, lc.b, 0.92))
	ci.draw_string(ThemeDB.fallback_font, cc + Vector2(-d, d * 0.3), "GS", HORIZONTAL_ALIGNMENT_CENTER, d * 2.0, int(d * 0.9), st.b_txt)


# linha cortada dentro do retângulo (Liang–Barsky)
static func _seg(ci: CanvasItem, a: Vector2, b: Vector2, rc: Rect2, col: Color, w: float) -> void:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var ps := [-d.x, d.x, -d.y, d.y]
	var qs := [a.x - rc.position.x, rc.end.x - a.x, a.y - rc.position.y, rc.end.y - a.y]
	for i in 4:
		var pp: float = ps[i]
		var qq: float = qs[i]
		if absf(pp) < 0.0001:
			if qq < 0.0:
				return
		else:
			var tt := qq / pp
			if pp < 0.0:
				t0 = maxf(t0, tt)
			else:
				t1 = minf(t1, tt)
	if t0 < t1:
		ci.draw_line(a + d * t0, a + d * t1, col, w)


# canto da carta: valor e naipe dentro de uma coluna (nunca passa da borda)
static func _index(ci: CanvasItem, r: Rect2, rk: int, s: int, col: Color) -> void:
	var f: Font = ThemeDB.fallback_font
	var cw := r.size.x * 0.22
	var fs := int(r.size.x * 0.19)
	var x0 := r.position.x + r.size.x * 0.035
	ci.draw_string(f, Vector2(x0, r.position.y + fs * 1.0), RANKS[rk], HORIZONTAL_ALIGNMENT_CENTER, cw, fs, col)
	suit(ci, Vector2(x0 + cw / 2.0, r.position.y + fs * 1.42), r.size.x * 0.058, s, col)


static func draw_face(ci: CanvasItem, r: Rect2, c: Dictionary, st: Dictionary, manilha: bool, hl: bool) -> void:
	var rad := int(r.size.x * 0.1)
	ci.draw_style_box(sbox(Color(0, 0, 0, 0.35), rad), Rect2(r.position + Vector2(3, 5), r.size))
	var border: Color = Color("f4c542") if manilha else (Color("ffe066") if hl else st.edge)
	var bw := 4 if (manilha or hl) else int(st.ew)
	ci.draw_style_box(sbox(st.face, rad, border, bw), r)
	if st.has("face2"):
		# brilho suave na metade de cima
		ci.draw_style_box(sbox(Color(st.face2.r, st.face2.g, st.face2.b, 0.55), maxi(2, rad - 2)), Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.45)))
	var s := int(c.s)
	var red: bool = s == 0 or s == 2
	var col: Color = st.red if red else st.black
	var rk := int(c.r)
	var frame: Color = st.frame
	if frame.a > 0.0:
		ci.draw_style_box(sbox(Color(0, 0, 0, 0), maxi(2, rad - 3), Color(frame.r, frame.g, frame.b, 0.6), 1), r.grow(-r.size.x * 0.06))
	if rk >= 4 and rk <= 6:
		# figura: retrato numa janela entre as colunas dos cantos
		var key := rk * 10 + s
		if not face_tex.has(key):
			face_tex[key] = load("res://cards/face_%d_%d.png" % [rk, s])
		# recorta só o retrato (sem a borda e os naipes do canto da arte) e mantém a proporção, sem esticar
		var tex: Texture2D = face_tex[key]
		var ts := tex.get_size()
		var src := Rect2(ts.x * 0.15, ts.y * 0.085, ts.x * 0.7, ts.y * 0.83)
		var aw := r.size.x * 0.56
		var ah := minf(aw * src.size.y / src.size.x, r.size.y * 0.86)
		var ar := Rect2(r.position.x + (r.size.x - aw) / 2.0, r.position.y + (r.size.y - ah) / 2.0, aw, ah)
		ci.draw_texture_rect_region(tex, ar, src)
		ci.draw_rect(ar, Color(frame.r, frame.g, frame.b, 0.9) if frame.a > 0.0 else Color(0, 0, 0, 0.35), false, maxf(1.0, r.size.x * 0.012))
	elif rk == 7:
		# Ás: naipe grande no meio (o de espadas com moldura, como o baralho de verdade)
		var big := r.size.x * (0.26 if s == 1 else 0.21)
		if s == 1:
			ci.draw_arc(r.get_center(), r.size.x * 0.3, 0, TAU, 40, Color(col.r, col.g, col.b, 0.45), maxf(1.0, r.size.x * 0.012))
		suit(ci, r.get_center(), big, s, col)
	else:
		var PIPS := {0: [[-1, -1], [1, -1], [-1, 1], [1, 1]], 1: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]],
			2: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]], 3: [[-1, -1], [1, -1], [0, -0.5], [-1, 0], [1, 0], [-1, 1], [1, 1]],
			8: [[0, -1], [0, 1]], 9: [[0, -1], [0, 0], [0, 1]]}
		var area := Rect2(r.position.x + r.size.x * 0.34, r.position.y + r.size.y * 0.2, r.size.x * 0.32, r.size.y * 0.6)
		var psz := r.size.x * 0.085
		for pp in PIPS.get(rk, [[0, 0]]):
			suit(ci, area.get_center() + Vector2(float(pp[0]) * area.size.x * 0.5, float(pp[1]) * area.size.y * 0.5), psz, s, col)
	if st.get("glow", false):
		ci.draw_style_box(sbox(Color(0, 0, 0, 0), rad, Color(col.r, col.g, col.b, 0.35), 2), r.grow(2))
	# cantos: em cima à esquerda e (de cabeça para baixo) embaixo à direita
	_index(ci, r, rk, s, col)
	var cen := r.get_center()
	ci.draw_set_transform(cen * 2.0, PI, Vector2.ONE)
	_index(ci, r, rk, s, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
