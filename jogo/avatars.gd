extends RefCounted
# Avatares, molduras e títulos do perfil (tudo desenhado em código, sem imagens)

const CARDS = preload("res://cards.gd")

# id, nome, como libera ("" = já vem liberado; "lv:N" = nível N; "ach:id" = conquista)
const AVATARS := [
	{"id": "b8", "name": "Bola 8", "need": ""},
	{"id": "b1", "name": "Bola 1", "need": ""},
	{"id": "b3", "name": "Bola 3", "need": ""},
	{"id": "b6", "name": "Bola 6", "need": ""},
	{"id": "b11", "name": "Bola 11", "need": "lv:5"},
	{"id": "b13", "name": "Bola 13", "need": "lv:10"},
	{"id": "ace", "name": "Ás de Espadas", "need": "ach:truco10"},
	{"id": "zap", "name": "Zap", "need": "ach:truco50"},
	{"id": "crown", "name": "Coroa", "need": "ach:win100"},
	{"id": "bolt", "name": "Raio", "need": "ach:streak5"},
	{"id": "fire", "name": "Fogo", "need": "ach:streak10"},
	{"id": "star", "name": "Estrela", "need": "ach:pocket500"},
	{"id": "diamond", "name": "Diamante", "need": "div:3"},
	{"id": "money", "name": "Apostador", "need": "ach:bet1k"},
]

const FRAMES := [
	{"id": "simples", "name": "Simples", "need": "", "col": Color("e3a928")},
	{"id": "bronze", "name": "Bronze", "need": "div:0", "col": Color("c27c3a")},
	{"id": "prata", "name": "Prata", "need": "div:1", "col": Color("c9d3dd")},
	{"id": "ouro", "name": "Ouro", "need": "div:2", "col": Color("ffd34a")},
	{"id": "diamante", "name": "Diamante", "need": "div:3", "col": Color("6fe3ff")},
	{"id": "mestre", "name": "Mestre", "need": "div:4", "col": Color("ff5ad6")},
	{"id": "fogo", "name": "Chamas", "need": "ach:streak10", "col": Color("ff7a1a")},
]

const TITLES := [
	{"id": "novato", "name": "Novato", "need": ""},
	{"id": "jogador", "name": "Jogador de Bar", "need": "ach:win10"},
	{"id": "tubarao", "name": "Tubarão da Sinuca", "need": "ach:sinuca50"},
	{"id": "trucador", "name": "Trucador", "need": "ach:truco10"},
	{"id": "mestre_truco", "name": "Mestre do Truco", "need": "ach:truco50"},
	{"id": "imparavel", "name": "Imparável", "need": "ach:streak10"},
	{"id": "apostador", "name": "Apostador", "need": "ach:bet10"},
	{"id": "lenda", "name": "Lenda", "need": "ach:win100"},
	{"id": "fiel", "name": "Fiel", "need": "ach:daily7"},
	{"id": "campeao", "name": "Campeão da Liga", "need": "div:4"},
]

const BALL_COLS := {1: Color("f4c51e"), 2: Color("1f5fd1"), 3: Color("d8262c"), 4: Color("6a2aa8"), 5: Color("f07a12"), 6: Color("12904a"), 7: Color("8a1f1f"), 8: Color("141414")}


static func find(list: Array, id: String) -> Dictionary:
	for it in list:
		if str(it.id) == id:
			return it
	return list[0]


# desenha o avatar (com a moldura) num círculo de raio r
static func draw(c: CanvasItem, ctr: Vector2, r: float, av: String, fr: String = "simples", t: float = 0.0) -> void:
	var fd: Dictionary = find(FRAMES, fr)
	var fc: Color = fd.col
	c.draw_circle(ctr, r, Color("0b1220"))
	var ir := r * 0.86
	if av.begins_with("b"):
		var n := int(av.substr(1))
		var bc: Color = BALL_COLS.get(n if n <= 8 else n - 8, Color.WHITE)
		if n > 8:
			c.draw_circle(ctr, ir, Color("f4f4ee"))
			# faixa da bola listrada (feita com um polígono dentro do círculo)
			var band := PackedVector2Array()
			for k in 13:
				var a := -0.52 + float(k) / 12.0 * 1.04
				band.append(ctr + Vector2(cos(a), sin(a)) * ir)
			for k in 13:
				var a2 := PI - 0.52 + float(k) / 12.0 * 1.04
				band.append(ctr + Vector2(cos(a2), sin(a2)) * ir)
			c.draw_colored_polygon(band, bc)
		else:
			c.draw_circle(ctr, ir, bc)
		c.draw_circle(ctr, ir * 0.48, Color("f4f4ee"))
		c.draw_string(ThemeDB.fallback_font, ctr + Vector2(-ir * 0.6, ir * 0.24), str(n), HORIZONTAL_ALIGNMENT_CENTER, ir * 1.2, int(ir * 0.62), Color("111111"))
		c.draw_circle(ctr + Vector2(-ir * 0.4, -ir * 0.45), ir * 0.17, Color(1, 1, 1, 0.45))
	elif av == "ace" or av == "zap":
		c.draw_circle(ctr, ir, Color("fbfaf4"))
		CARDS.suit(c, ctr + Vector2(0, ir * 0.05), ir * 1.05, 2 if av == "ace" else 3, Color("141414") if av == "ace" else Color("1a1a1a"))
		c.draw_string(ThemeDB.fallback_font, ctr + Vector2(-ir, -ir * 0.3), "A" if av == "ace" else "4", HORIZONTAL_ALIGNMENT_CENTER, ir * 0.9, int(ir * 0.45), Color("c0303a"))
	elif av == "crown":
		c.draw_circle(ctr, ir, Color("5a1f8a"))
		var w := ir * 1.2
		var base := ctr + Vector2(0, ir * 0.35)
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(-w / 2, 0), base + Vector2(-w / 2, -ir * 0.75), base + Vector2(-w / 4, -ir * 0.4), base + Vector2(0, -ir * 0.95), base + Vector2(w / 4, -ir * 0.4), base + Vector2(w / 2, -ir * 0.75), base + Vector2(w / 2, 0)]), Color("ffd34a"))
		for k in 3:
			c.draw_circle(base + Vector2((k - 1) * w / 3.0, -ir * 0.2), ir * 0.08, Color("e53935"))
	elif av == "bolt":
		c.draw_circle(ctr, ir, Color("1d3a8a"))
		c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(ir * 0.15, -ir * 0.8), ctr + Vector2(-ir * 0.45, ir * 0.1), ctr + Vector2(-ir * 0.02, ir * 0.1), ctr + Vector2(-ir * 0.2, ir * 0.8), ctr + Vector2(ir * 0.45, -ir * 0.15), ctr + Vector2(ir * 0.02, -ir * 0.15)]), Color("ffe94a"))
	elif av == "fire":
		c.draw_circle(ctr, ir, Color("3a0d06"))
		var fl := 0.06 * sin(t * 9.0)
		for k in 3:
			var s := 1.0 - k * 0.28
			var col: Color = [Color("ff3d1a"), Color("ff9a1a"), Color("ffe36a")][k]
			var top := ctr + Vector2(fl * ir * 2.0, -ir * 0.85 * s)
			var pts := PackedVector2Array([top])
			for j in 13:
				var a := PI * 0.05 + float(j) / 12.0 * PI * 0.9
				pts.append(ctr + Vector2(cos(a) * ir * 0.55 * s, ir * 0.35 + sin(a) * ir * 0.42 * s - ir * 0.1 * k))
			c.draw_colored_polygon(pts, col)
	elif av == "star":
		c.draw_circle(ctr, ir, Color("0f4d3a"))
		var pts2 := PackedVector2Array()
		for k in 10:
			pts2.append(ctr + Vector2.from_angle(-PI / 2.0 + float(k) * PI / 5.0) * (ir * 0.8 if k % 2 == 0 else ir * 0.34))
		c.draw_colored_polygon(pts2, Color("ffd34a"))
	elif av == "diamond":
		c.draw_circle(ctr, ir, Color("0a2a40"))
		var d := PackedVector2Array([ctr + Vector2(-ir * 0.6, -ir * 0.2), ctr + Vector2(-ir * 0.3, -ir * 0.55), ctr + Vector2(ir * 0.3, -ir * 0.55), ctr + Vector2(ir * 0.6, -ir * 0.2), ctr + Vector2(0, ir * 0.7)])
		c.draw_colored_polygon(d, Color("6fe3ff"))
		c.draw_line(ctr + Vector2(-ir * 0.6, -ir * 0.2), ctr + Vector2(ir * 0.6, -ir * 0.2), Color(1, 1, 1, 0.7), 2.0)
		c.draw_line(ctr + Vector2(-ir * 0.15, -ir * 0.2), ctr + Vector2(0, ir * 0.7), Color(1, 1, 1, 0.5), 1.5)
	elif av == "money":
		c.draw_circle(ctr, ir, Color("10502a"))
		for k in 3:
			var cc := ctr + Vector2(0, ir * 0.35 - k * ir * 0.28)
			c.draw_circle(cc + Vector2(0, 3), ir * 0.5, Color("8a5a10"))
			c.draw_circle(cc, ir * 0.5, Color("ffd34a"))
			c.draw_arc(cc, ir * 0.36, 0, TAU, 24, Color("c98a12"), 2.0)
	# moldura
	var bw := maxf(2.5, r * 0.12)
	if fr == "mestre" or fr == "fogo":
		for k in 24:
			var a0 := float(k) / 24.0 * TAU + t * 1.5
			var cc2: Color = Color.from_hsv(fmod(float(k) / 24.0 + t * 0.2, 1.0), 0.75, 1.0) if fr == "mestre" else [Color("ff3d1a"), Color("ffb01a"), Color("ffe36a")][k % 3]
			c.draw_arc(ctr, r - bw * 0.5, a0, a0 + TAU / 24.0 + 0.02, 4, cc2, bw)
	else:
		c.draw_arc(ctr, r - bw * 0.5, 0, TAU, 48, fc, bw)
		c.draw_arc(ctr, r - bw * 0.5, PI * 1.1, PI * 1.6, 16, fc.lightened(0.5), bw * 0.5)
	if fr == "diamante":
		for k in 4:
			var sp := ctr + Vector2.from_angle(float(k) * TAU / 4.0 + PI / 4.0) * (r - bw * 0.5)
			c.draw_circle(sp, bw * 0.55, Color.WHITE)
