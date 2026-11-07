extends RefCounted
# Efeitos animados na ponta (cabo) dos tacos premium.
# cn = camada normal, ca = camada aditiva. ang = direção do taco para fora da ponta do cabo.


class Sink:
	var t: CanvasItem = null

	func draw_circle(c: Vector2, r: float, col: Color) -> void:
		if t != null:
			t.draw_circle(c, r, col)

	func draw_line(a: Vector2, b: Vector2, col: Color, w: float = 1.0) -> void:
		if t != null:
			t.draw_line(a, b, col, w)

	func draw_polyline(p: PackedVector2Array, col: Color, w: float = 1.0) -> void:
		if t != null:
			t.draw_polyline(p, col, w)

	func draw_colored_polygon(p: PackedVector2Array, col: Color) -> void:
		if t != null:
			t.draw_colored_polygon(p, col)

	func draw_text(p: Vector2, s: String, size: int, col: Color) -> void:
		if t != null:
			var fnt: Font = ThemeDB.fallback_font
			t.draw_string_outline(fnt, p + Vector2(-30, size * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 60, size, 4, Color(0, 0, 0, 0.45 * col.a))
			t.draw_string(fnt, p + Vector2(-30, size * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 60, size, col)

	func draw_arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = 1.0) -> void:
		if t != null:
			t.draw_arc(c, r, a0, a1, n, col, w)


static func hsh(x: float) -> float:
	return fposmod(sin(x * 127.1) * 43758.5453, 1.0)


static func pt(ax: Vector2, pp: Vector2, sc: float, u: float, v: float) -> Vector2:
	return ax * u * sc + pp * v * sc


static func poly(ax: Vector2, pp: Vector2, sc: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(pt(ax, pp, sc, p.x, p.y))
	return out


static func sparkle(ca, c: Vector2, r: float, col: Color) -> void:
	ca.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), col, 1.4)
	ca.draw_line(c - Vector2(0, r), c + Vector2(0, r), col, 1.4)
	ca.draw_circle(c, r * 0.35, col)


static func draw(cn, ca, kind: String, t: float, ang: float, sc: float) -> void:
	var ax := Vector2.from_angle(ang)
	var pp := ax.orthogonal()
	match kind:
		"dragon":
			_dragon(cn, ca, t, ax, pp, sc)
		"ice":
			_ice(cn, ca, t, ax, pp, sc)
		"galaxy":
			_galaxy(cn, ca, t, ax, pp, sc)
		"arc":
			_arc(cn, ca, t, ax, pp, sc)
		"eyes":
			_eyes(cn, ca, t, ax, pp, sc)
		"phoenix":
			_phoenix(cn, ca, t, ax, pp, sc)
		"storm":
			_storm(cn, ca, t, ax, pp, sc)
		"blade":
			_blade(cn, ca, t, ax, pp, sc)
		"moon":
			_moon(cn, ca, t, ax, pp, sc)
		"wave":
			_wave(cn, ca, t, ax, pp, sc)
		"gems":
			_gems(cn, ca, t, ax, pp, sc)
		"lava":
			_lava(cn, ca, t, ax, pp, sc)
		"aurora":
			_aurora(cn, ca, t, ax, pp, sc)
		"math":
			_math(cn, ca, t, ax, pp, sc)
		"comet":
			_comet(cn, ca, t, ax, pp, sc)
		"crown":
			_crown(cn, ca, t, ax, pp, sc)


static func _dragon(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var o := Vector2.ZERO
	# chifres
	cn.draw_colored_polygon(poly(ax, pp, sc, [Vector2(5, -8), Vector2(-14, -20), Vector2(14, -11)]), Color("e3d3a6"))
	cn.draw_colored_polygon(poly(ax, pp, sc, [Vector2(5, 8), Vector2(-14, 20), Vector2(14, 11)]), Color("e3d3a6"))
	# cabeça
	var head := poly(ax, pp, sc, [Vector2(0, -9), Vector2(10, -13), Vector2(24, -11), Vector2(36, -7), Vector2(43, -4), Vector2(32, -1), Vector2(42, 5), Vector2(35, 9), Vector2(21, 7), Vector2(8, 10), Vector2(0, 9)])
	cn.draw_colored_polygon(head, Color("a31515"))
	var hl := poly(ax, pp, sc, [Vector2(4, -7), Vector2(14, -10), Vector2(28, -8), Vector2(36, -5), Vector2(24, -4), Vector2(10, -4)])
	cn.draw_colored_polygon(hl, Color(1.0, 0.45, 0.25, 0.35))
	head.append(head[0])
	cn.draw_polyline(head, Color("2a0404"), 1.6)
	# espinhos
	for k in 4:
		var u := 6.0 + k * 7.0
		cn.draw_colored_polygon(poly(ax, pp, sc, [Vector2(u, -11), Vector2(u + 3, -17 + k), Vector2(u + 6, -11)]), Color("5a0a0a"))
	# dentes
	for k in 3:
		var u := 33.0 + k * 3.0
		cn.draw_colored_polygon(poly(ax, pp, sc, [Vector2(u, -1.5), Vector2(u + 1.5, 2.0), Vector2(u + 3, -1.5)]), Color("f4efe0"))
	# olho
	var eye := pt(ax, pp, sc, 21.0, -4.5)
	ca.draw_circle(eye, 6.0 * sc, Color(1.0, 0.8, 0.1, 0.30 + 0.18 * sin(t * 6.0)))
	cn.draw_circle(eye, 2.6 * sc, Color("ffe14a"))
	cn.draw_line(eye - pp * 2.0 * sc, eye + pp * 2.0 * sc, Color(0.1, 0.0, 0.0), 1.2)
	# brilho da boca + fogo
	var mouth := pt(ax, pp, sc, 40.0, 1.0)
	ca.draw_circle(mouth, (10.0 + 2.0 * sin(t * 14.0)) * sc, Color(1.0, 0.5, 0.1, 0.35))
	for i in 26:
		var life := fposmod(t * 1.15 + float(i) / 26.0, 1.0)
		var u := 42.0 + life * 86.0
		var v := 1.0 + sin(float(i) * 5.1 + t * 5.0) * life * 17.0
		var r := ((1.0 - life) * 8.5 + 2.0) * sc
		var col := Color(1.0, 1.0 - life * 0.72, 0.25 * (1.0 - life), (1.0 - life) * 0.85)
		ca.draw_circle(pt(ax, pp, sc, u, v), r, col)
		if life < 0.55:
			ca.draw_circle(pt(ax, pp, sc, u, v), r * 0.5, Color(1, 1, 0.8, 0.55 * (1.0 - life)))
	# fagulhas
	for i in 8:
		var life := fposmod(t * 0.7 + float(i) * 0.137, 1.0)
		var u := 44.0 + life * 120.0
		var v := sin(float(i) * 9.1 + t * 2.0) * (10.0 + life * 30.0)
		ca.draw_circle(pt(ax, pp, sc, u, v), 1.5 * sc, Color(1.0, 0.75, 0.2, 1.0 - life))


static func _ice(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	for k in 7:
		var a := (k - 3) * 0.3
		var d := ax.rotated(a)
		var n := d.orthogonal()
		var l := (24.0 + float(k % 3) * 9.0 + 4.0 * sin(t * 1.5 + k)) * sc
		var w := (4.5 + float(k % 2) * 1.5) * sc
		var base := d * 3.0 * sc
		var pts := PackedVector2Array([base, base + d * l * 0.45 + n * w, base + d * l, base + d * l * 0.45 - n * w])
		cn.draw_colored_polygon(pts, Color(0.55, 0.88, 1.0, 0.82))
		var inner := PackedVector2Array([base + d * l * 0.1, base + d * l * 0.5 + n * w * 0.3, base + d * l * 0.9, base + d * l * 0.5 - n * w * 0.5])
		cn.draw_colored_polygon(inner, Color(0.95, 1.0, 1.0, 0.55))
		var edge := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
		cn.draw_polyline(edge, Color(1, 1, 1, 0.95), 1.3)
	ca.draw_circle(ax * 14.0 * sc, 16.0 * sc, Color(0.4, 0.8, 1.0, 0.16 + 0.06 * sin(t * 2.0)))
	for i in 9:
		var tw := 0.5 + 0.5 * sin(t * 3.0 + float(i) * 1.7)
		var u := 14.0 + float(i) * 7.0
		var v := sin(t * 1.2 + float(i) * 2.1) * (10.0 + float(i) * 1.6)
		sparkle(ca, pt(ax, pp, sc, u, v), (2.0 + tw * 4.5) * sc, Color(0.85, 0.97, 1.0, 0.35 + 0.65 * tw))
	for i in 10:
		var life := fposmod(t * 0.25 + float(i) * 0.1, 1.0)
		var p := pt(ax, pp, sc, 8.0 + hsh(float(i)) * 60.0, (hsh(float(i) + 4.0) - 0.5) * 36.0 + life * 20.0)
		ca.draw_circle(p, 1.4 * sc, Color(1, 1, 1, 0.8 * (1.0 - life)))


static func _galaxy(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var c := pt(ax, pp, sc, 28.0, 0.0)
	ca.draw_circle(c, 30.0 * sc, Color(0.55, 0.25, 1.0, 0.12 + 0.05 * sin(t * 2.0)))
	ca.draw_circle(c, 20.0 * sc, Color(0.3, 0.6, 1.0, 0.10))
	var tilt := 0.45
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	for i in 41:
		var a := float(i) / 40.0 * TAU
		var p := Vector2(cos(a) * 21.0, sin(a) * 6.5).rotated(tilt)
		var q := c + (ax * p.x + pp * p.y) * sc
		if sin(a) < 0.0:
			back.append(q)
		else:
			front.append(q)
	if back.size() > 1:
		cn.draw_polyline(back, Color(0.85, 0.7, 1.0, 0.6), 2.0 * sc)
	cn.draw_circle(c, 11.0 * sc, Color("2b1466"))
	cn.draw_circle(c, 10.0 * sc, Color("5a2fc4"))
	cn.draw_circle(c + Vector2(-2.5, -3.0) * sc, 6.5 * sc, Color("8d63f0"))
	cn.draw_circle(c + Vector2(-4.0, -4.5) * sc, 2.6 * sc, Color(1, 1, 1, 0.55))
	if front.size() > 1:
		cn.draw_polyline(front, Color(0.95, 0.85, 1.0, 0.95), 2.2 * sc)
	# luas
	for m in 2:
		var ph := t * (1.4 + m * 0.9) + m * 2.4
		var p := Vector2(cos(ph) * (30.0 + m * 9.0), sin(ph) * (12.0 + m * 4.0))
		var q := c + (ax * p.x + pp * p.y) * sc
		ca.draw_circle(q, 5.0 * sc, Color(0.5, 0.9, 1.0, 0.28))
		cn.draw_circle(q, 2.6 * sc, Color(0.85, 1.0, 1.0))
	for i in 14:
		var tw := 0.5 + 0.5 * sin(t * 2.5 + float(i) * 2.3)
		var p := pt(ax, pp, sc, 4.0 + hsh(float(i)) * 80.0, (hsh(float(i) + 9.0) - 0.5) * 60.0)
		sparkle(ca, p, (1.5 + tw * 3.2) * sc, Color(1, 1, 1, 0.3 + 0.7 * tw))


static func _arc(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var o := ax * 9.0 * sc
	ca.draw_circle(o, (13.0 + 2.0 * sin(t * 20.0)) * sc, Color(0.3, 0.6, 1.0, 0.28))
	cn.draw_circle(o, 5.0 * sc, Color(0.75, 0.9, 1.0))
	cn.draw_circle(o, 2.4 * sc, Color.WHITE)
	var seed := floorf(t * 14.0)
	for b in 5:
		var a := (hsh(seed * 3.1 + float(b) * 7.7) - 0.5) * 2.6
		var d := ax.rotated(a)
		var n := d.orthogonal()
		var pts := PackedVector2Array([o])
		var cur := o
		for s in 7:
			cur += d * 9.0 * sc + n * (hsh(seed * 5.3 + float(b) * 11.0 + float(s)) - 0.5) * 14.0 * sc
			pts.append(cur)
		ca.draw_polyline(pts, Color(0.35, 0.65, 1.0, 0.28), 6.0 * sc)
		ca.draw_polyline(pts, Color(0.75, 0.92, 1.0, 0.95), 1.8 * sc)
	for i in 6:
		var life := fposmod(t * 1.6 + float(i) * 0.17, 1.0)
		ca.draw_circle(o + ax.rotated((hsh(float(i) + seed) - 0.5) * 3.0) * life * 34.0 * sc, 1.5 * sc, Color(0.7, 0.9, 1.0, 1.0 - life))


static func _eyes(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var blink := fposmod(t, 3.4) < 0.12
	for s in [-1.0, 1.0]:
		var e := pt(ax, pp, sc, 16.0, s * 7.0)
		ca.draw_circle(e, (9.0 + 1.5 * sin(t * 3.0)) * sc, Color(1.0, 0.55, 0.1, 0.33))
		if blink:
			cn.draw_line(e - ax * 5.0 * sc, e + ax * 5.0 * sc, Color(1.0, 0.7, 0.2), 1.8 * sc)
		else:
			var pts := PackedVector2Array([e + ax * 6.0 * sc, e + pp * 3.4 * sc, e - ax * 6.0 * sc, e - pp * 3.4 * sc])
			cn.draw_colored_polygon(pts, Color(1.0, 0.72, 0.15))
			cn.draw_line(e + pp * 2.6 * sc, e - pp * 2.6 * sc, Color(0.05, 0.02, 0.0), 1.6 * sc)
	for i in 3:
		var life := fposmod(t * 0.8 + float(i) * 0.33, 1.0)
		ca.draw_circle(pt(ax, pp, sc, 22.0 + life * 40.0, sin(float(i) * 3.0 + t) * 10.0), 1.8 * sc, Color(1.0, 0.6, 0.2, 1.0 - life))


static func _phoenix(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	ca.draw_circle(ax * 14.0 * sc, 24.0 * sc, Color(1.0, 0.45, 0.1, 0.16 + 0.06 * sin(t * 5.0)))
	for s in [-1.0, 1.0]:
		for k in 6:
			var a: float = s * (0.45 + float(k) * 0.24)
			var d := ax.rotated(a)
			var n := d.orthogonal()
			var ln := (30.0 + float(k) * 7.0) * (1.0 + 0.09 * sin(t * 8.0 + float(k) * 1.3 + s)) * sc
			var w := (6.5 - float(k) * 0.3) * sc
			var b := ax * 5.0 * sc
			var outer := PackedVector2Array([b, b + d * ln * 0.4 + n * w, b + d * ln, b + d * ln * 0.4 - n * w])
			cn.draw_colored_polygon(outer, Color(0.78, 0.1, 0.04, 0.95))
			var mid := PackedVector2Array([b + d * 2.0, b + d * ln * 0.4 + n * w * 0.62, b + d * ln * 0.88, b + d * ln * 0.4 - n * w * 0.62])
			cn.draw_colored_polygon(mid, Color(1.0, 0.5, 0.08, 0.95))
			var inner := PackedVector2Array([b + d * 3.0, b + d * ln * 0.38 + n * w * 0.25, b + d * ln * 0.6, b + d * ln * 0.38 - n * w * 0.25])
			cn.draw_colored_polygon(inner, Color(1.0, 0.92, 0.5, 0.95))
			ca.draw_circle(b + d * ln, 3.2 * sc, Color(1.0, 0.7, 0.2, 0.45))
	cn.draw_circle(ax * 12.0 * sc, 7.0 * sc, Color("ffcf4a"))
	cn.draw_colored_polygon(PackedVector2Array([ax * 17.0 * sc + pp * 3.0 * sc, ax * 27.0 * sc, ax * 17.0 * sc - pp * 3.0 * sc]), Color("ffe9a0"))
	cn.draw_circle(ax * 13.0 * sc + pp * 3.0 * sc, 1.5 * sc, Color(0.4, 0.02, 0.0))
	for i in 16:
		var life := fposmod(t * 0.8 + float(i) * 0.0625, 1.0)
		var p := pt(ax, pp, sc, 10.0 + life * 70.0, sin(float(i) * 6.7 + t * 2.0) * (6.0 + life * 30.0))
		ca.draw_circle(p, (1.0 + (1.0 - life) * 2.6) * sc, Color(1.0, 0.65, 0.15, 1.0 - life))


static func _storm(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var c := ax * 20.0 * sc
	var flash := maxf(0.0, sin(t * 9.0)) * maxf(0.0, sin(t * 3.7))
	ca.draw_circle(c, 34.0 * sc, Color(0.45, 0.5, 1.0, 0.12 + 0.3 * flash))
	for i in 9:
		var a := t * 1.3 + float(i) * TAU / 9.0
		var p := c + Vector2(cos(a), sin(a) * 0.7).rotated(ang_of(ax)) * (15.0 + 4.0 * sin(t * 2.0 + float(i))) * sc
		cn.draw_circle(p, (8.0 + 2.0 * sin(float(i) * 2.0)) * sc, Color(0.2, 0.18, 0.4, 0.82))
		cn.draw_circle(p + Vector2(-1.5, -1.5) * sc, 5.0 * sc, Color(0.35, 0.33, 0.6, 0.85))
	cn.draw_circle(c, 7.0 * sc, Color(0.85, 0.9, 1.0))
	ca.draw_circle(c, 11.0 * sc, Color(0.6, 0.7, 1.0, 0.4))
	var seed := floorf(t * 11.0)
	for b in 5:
		var a := hsh(seed * 3.3 + float(b) * 5.7) * TAU
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var pts := PackedVector2Array([c])
		var cur := c
		for s in 6:
			cur += d * 8.0 * sc + n * (hsh(seed * 7.1 + float(b) * 13.0 + float(s)) - 0.5) * 12.0 * sc
			pts.append(cur)
		ca.draw_polyline(pts, Color(0.5, 0.6, 1.0, 0.3), 6.0 * sc)
		ca.draw_polyline(pts, Color(1.0, 0.97, 0.7, 0.95), 1.8 * sc)


static func ang_of(v: Vector2) -> float:
	return v.angle()


static func _blade(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	ca.draw_circle(pt(ax, pp, sc, 46.0, 0.0), 46.0 * sc, Color(1.0, 0.18, 0.3, 0.12 + 0.05 * sin(t * 2.0)))
	# sol vermelho
	var sun := pt(ax, pp, sc, 50.0, -4.0)
	ca.draw_circle(sun, 46.0 * sc, Color(1.0, 0.25, 0.3, 0.16 + 0.05 * sin(t * 1.6)))
	cn.draw_circle(sun, 32.0 * sc, Color("c4142e"))
	cn.draw_circle(sun, 28.0 * sc, Color("e32a40"))
	ca.draw_arc(sun, 32.0 * sc, 0, TAU, 40, Color(1.0, 0.6, 0.6, 0.5), 2.0 * sc)
	# galho de cerejeira
	var br := PackedVector2Array()
	for i in 13:
		var s := float(i) / 12.0
		br.append(pt(ax, pp, sc, 4.0 + s * 100.0, 14.0 - sin(s * 3.0) * 24.0 + s * s * 14.0))
	cn.draw_polyline(br, Color("2a140c"), 4.2 * sc)
	cn.draw_polyline(br, Color("4a2616"), 2.4 * sc)
	var twig := [[4, -12.0], [7, 14.0], [9, -10.0]]
	var tips := []
	for tw in twig:
		var p0: Vector2 = br[tw[0]]
		var p1 := p0 + (ax * 14.0 + pp * float(tw[1]) * 1.4) * sc
		cn.draw_line(p0, p1, Color("3a1d10"), 2.2 * sc)
		tips.append(p1)
	var fl := [br[3], br[6], br[8], br[11], br[12]] + tips
	for i in fl.size():
		var p: Vector2 = fl[i]
		var big := 7.2 if i % 2 == 0 else 5.6
		var r := float(i) * 1.3 + sin(t * 0.8 + float(i)) * 0.15
		ca.draw_circle(p, big * 2.0 * sc, Color(1.0, 0.5, 0.7, 0.18))
		for k in 5:
			var d := Vector2.from_angle(r + float(k) * TAU / 5.0)
			cn.draw_circle(p + d * big * 0.62 * sc, big * 0.52 * sc, Color("ffb3cf"))
			cn.draw_circle(p + d * big * 0.5 * sc, big * 0.3 * sc, Color("ffe1ec"))
		cn.draw_circle(p, big * 0.3 * sc, Color("ffd34a"))
	for i in 18:
		var life := fposmod(t * 0.3 + float(i) * 0.0556, 1.0)
		var sway := sin(t * 1.7 + float(i) * 2.3) * 8.0
		var p := pt(ax, pp, sc, 4.0 + hsh(float(i)) * 96.0 + life * 10.0, (hsh(float(i) + 3.0) - 0.5) * 60.0 + life * 30.0 + sway)
		var r := t * 1.5 + float(i) * 1.7
		var al := sin(life * PI)
		var big := 3.4 if i % 3 == 0 else 2.3
		var pc := Color(1.0, 0.62, 0.78, 0.95 * al)
		for k in 5:
			var d := Vector2.from_angle(r + float(k) * TAU / 5.0)
			cn.draw_colored_polygon(PackedVector2Array([p, p + d.rotated(0.45) * big * 1.3 * sc, p + d * big * 2.0 * sc, p + d.rotated(-0.45) * big * 1.3 * sc]), pc)
		cn.draw_circle(p, big * 0.45 * sc, Color(1.0, 0.86, 0.3, al))
		ca.draw_circle(p, big * 2.2 * sc, Color(1.0, 0.4, 0.6, 0.12 * al))


static func _moon(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var c := pt(ax, pp, sc, 26.0, 0.0)
	ca.draw_circle(c, 34.0 * sc, Color(0.6, 0.72, 1.0, 0.13 + 0.05 * sin(t * 1.5)))
	var pts := PackedVector2Array()
	for i in 21:
		var a := -2.4 + float(i) / 20.0 * 4.8
		pts.append(c + (ax * cos(a) + pp * sin(a)) * 17.0 * sc)
	for i in 21:
		var a := 2.2 - float(i) / 20.0 * 4.4
		pts.append(c + (ax * (cos(a) * 14.0 + 8.0) + pp * sin(a) * 15.0) * sc)
	cn.draw_colored_polygon(pts, Color("f4f1d6"))
	ca.draw_colored_polygon(pts, Color(1.0, 1.0, 0.85, 0.25))
	for e in [-1.0, 1.0]:
		var ep := pt(ax, pp, sc, 40.0, e * 5.0)
		ca.draw_circle(ep, 4.0 * sc, Color(1.0, 0.85, 0.2, 0.4))
		cn.draw_colored_polygon(PackedVector2Array([ep + ax * 3.0 * sc, ep + pp * 1.4 * sc, ep - ax * 3.0 * sc, ep - pp * 1.4 * sc]), Color(1.0, 0.9, 0.3))
	for i in 12:
		var tw := 0.5 + 0.5 * sin(t * 2.7 + float(i) * 2.1)
		sparkle(ca, pt(ax, pp, sc, 4.0 + hsh(float(i)) * 80.0, (hsh(float(i) + 7.0) - 0.5) * 60.0), (1.4 + tw * 3.0) * sc, Color(0.85, 0.92, 1.0, 0.3 + 0.7 * tw))
	for i in 5:
		var life := fposmod(t * 0.2 + float(i) * 0.2, 1.0)
		ca.draw_circle(pt(ax, pp, sc, 6.0 + life * 70.0, sin(float(i) * 3.0 + t * 0.7) * 14.0), (6.0 + life * 8.0) * sc, Color(0.7, 0.8, 1.0, 0.09 * (1.0 - life)))


static func _wave(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var c := ax * 22.0 * sc
	ca.draw_circle(c, 30.0 * sc, Color(0.2, 0.7, 1.0, 0.14))
	for arm in 2:
		var pts := PackedVector2Array()
		for i in 44:
			var a := float(i) * 0.3 - t * 3.0 + float(arm) * PI
			var r := (4.0 + float(i) * 0.65) * sc
			pts.append(c + Vector2(cos(a), sin(a) * 0.8).rotated(ax.angle()) * r)
		cn.draw_polyline(pts, Color(0.1, 0.55, 0.9, 0.9), 5.0 * sc)
		cn.draw_polyline(pts, Color(0.35, 0.85, 0.95, 0.95), 3.0 * sc)
		ca.draw_polyline(pts, Color(0.9, 1.0, 1.0, 0.5), 1.2 * sc)
	for i in 12:
		var life := fposmod(t * 0.6 + float(i) * 0.083, 1.0)
		var p := pt(ax, pp, sc, 6.0 + life * 62.0, sin(float(i) * 4.1 + t) * (8.0 + life * 20.0))
		ca.draw_arc(p, (1.5 + life * 3.0) * sc, 0, TAU, 12, Color(0.8, 0.97, 1.0, 1.0 - life), 1.2)


static func _gems(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var c := ax * 22.0 * sc
	ca.draw_circle(c, 32.0 * sc, Color(0.2, 1.0, 0.55, 0.12 + 0.05 * sin(t * 2.0)))
	for i in 5:
		var a := t * 1.2 + float(i) * TAU / 5.0
		var p := c + Vector2(cos(a), sin(a) * 0.6).rotated(ax.angle()) * 20.0 * sc
		var z := 0.75 + 0.25 * sin(a)
		var r := (7.0 + 2.0 * z) * sc
		var hexa := PackedVector2Array()
		for k in 6:
			hexa.append(p + Vector2.from_angle(float(k) * TAU / 6.0 + 0.5) * r)
		cn.draw_colored_polygon(hexa, Color(0.05, 0.62, 0.35))
		var top := PackedVector2Array([p, hexa[0], hexa[1], hexa[2]])
		cn.draw_colored_polygon(top, Color(0.35, 0.95, 0.65, 0.9))
		cn.draw_colored_polygon(PackedVector2Array([p, hexa[3], hexa[4], hexa[5]]), Color(0.02, 0.4, 0.22))
		hexa.append(hexa[0])
		cn.draw_polyline(hexa, Color(0.85, 1.0, 0.9, 0.9), 1.1)
		sparkle(ca, p + Vector2(-r * 0.3, -r * 0.3), (1.0 + 2.5 * maxf(0.0, sin(t * 4.0 + float(i) * 2.0))) * sc, Color(1, 1, 1, 0.9))
	var cr := c
	cn.draw_colored_polygon(PackedVector2Array([cr + pp * 8.0 * sc, cr + pp * 5.0 * sc + ax * 9.0 * sc, cr + ax * 4.0 * sc, cr - pp * 5.0 * sc + ax * 9.0 * sc, cr - pp * 8.0 * sc, cr]), Color("e8c548"))


static func _lava(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var c := ax * 20.0 * sc
	for i in 7:
		var life := fposmod(t * 0.35 + float(i) * 0.143, 1.0)
		cn.draw_circle(c + ax * (10.0 + life * 60.0) * sc + pp * sin(float(i) * 3.0 + t) * 10.0 * sc, (6.0 + life * 10.0) * sc, Color(0.12, 0.1, 0.1, 0.5 * (1.0 - life)))
	ca.draw_circle(c, (30.0 + 3.0 * sin(t * 4.0)) * sc, Color(1.0, 0.35, 0.05, 0.2))
	cn.draw_circle(c, 14.0 * sc, Color(0.28, 0.07, 0.03))
	cn.draw_circle(c, 12.0 * sc, Color(0.85, 0.2, 0.03))
	cn.draw_circle(c + Vector2(-1.0, -1.0) * sc, 8.5 * sc, Color(1.0, 0.55, 0.05))
	cn.draw_circle(c + Vector2(-2.0, -2.0) * sc, 4.5 * sc, Color(1.0, 0.92, 0.45))
	for k in 5:
		var a := float(k) * 1.26 + 0.4
		var d := Vector2.from_angle(a)
		cn.draw_line(c + d * 8.0 * sc, c + d * 13.0 * sc, Color(0.2, 0.04, 0.02), 2.0 * sc)
	for i in 20:
		var life := fposmod(t * 0.9 + float(i) * 0.05, 1.0)
		var p := pt(ax, pp, sc, 14.0 + life * 80.0, sin(float(i) * 5.3 + t * 2.0) * (5.0 + life * 24.0))
		ca.draw_circle(p, (1.0 + (1.0 - life) * 2.4) * sc, Color(1.0, 0.55 + 0.3 * (1.0 - life), 0.1, 1.0 - life))


static func _aurora(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var cols := [Color(0.2, 1.0, 0.65), Color(0.35, 0.8, 1.0), Color(0.75, 0.45, 1.0)]
	for r in 3:
		var prev := Vector2.ZERO
		for i in 26:
			var u := 4.0 + float(i) * 4.2
			var v := sin(u * 0.11 - t * 2.2 + float(r) * 1.7) * (5.0 + u * 0.16) + (float(r) - 1.0) * 9.0
			var p := pt(ax, pp, sc, u, v)
			if i > 0:
				var fade := 1.0 - float(i) / 26.0
				var col: Color = cols[r]
				ca.draw_line(prev, p, Color(col.r, col.g, col.b, 0.28 * fade), 9.0 * sc)
				ca.draw_line(prev, p, Color(col.r, col.g, col.b, 0.9 * fade), 2.6 * sc)
			prev = p
	ca.draw_circle(ax * 6.0 * sc, 9.0 * sc, Color(0.6, 1.0, 0.9, 0.3))
	for i in 12:
		var tw := 0.5 + 0.5 * sin(t * 3.0 + float(i) * 1.9)
		sparkle(ca, pt(ax, pp, sc, 6.0 + hsh(float(i)) * 90.0, (hsh(float(i) + 5.0) - 0.5) * 50.0), (1.2 + tw * 3.0) * sc, Color(1, 1, 1, 0.3 + 0.7 * tw))


# katana de verdade: cabo trançado, guarda dourada e lâmina curva com hamon
static func _katana(cn, ca, t: float, o: Vector2, d: Vector2, sc: float, ph: float) -> void:
	var n := d.orthogonal()
	var P := func(u: float, v: float) -> Vector2:
		return o + (d * u + n * v) * sc
	# cabo
	var hw := 3.6
	cn.draw_colored_polygon(PackedVector2Array([P.call(0.0, -hw), P.call(24.0, -hw), P.call(24.0, hw), P.call(0.0, hw)]), Color("1a0b0b"))
	for k in 6:
		var u := 2.0 + float(k) * 3.8
		cn.draw_colored_polygon(PackedVector2Array([P.call(u, 0.0), P.call(u + 1.9, -hw), P.call(u + 3.8, 0.0), P.call(u + 1.9, hw)]), Color("b0121f"))
		cn.draw_circle(P.call(u + 1.9, 0.0), 0.9 * sc, Color("f2e8d8"))
	cn.draw_circle(P.call(0.0, 0.0), 3.4 * sc, Color("c9a23a"))
	# guarda (tsuba)
	cn.draw_circle(P.call(25.5, 0.0), 7.5 * sc, Color("7a5a14"))
	cn.draw_circle(P.call(25.5, 0.0), 6.2 * sc, Color("e2bb4a"))
	cn.draw_circle(P.call(25.5, 0.0), 3.0 * sc, Color("3a2a08"))
	cn.draw_colored_polygon(PackedVector2Array([P.call(27.0, -3.0), P.call(31.0, -3.0), P.call(31.0, 3.0), P.call(27.0, 3.0)]), Color("e8c45a"))
	# lâmina curva
	var back := PackedVector2Array()
	var edge := PackedVector2Array()
	var hamon := PackedVector2Array()
	var N := 16
	for i in N + 1:
		var s := float(i) / float(N)
		var u := 31.0 + s * 74.0
		var c := -s * s * 7.0
		var w := 3.4 * (1.0 - 0.3 * s)
		if s > 0.9:
			w *= (1.0 - s) / 0.1
		back.append(P.call(u, c - w))
		edge.append(P.call(u, c + w))
		hamon.append(P.call(u, c + w * (0.15 + 0.22 * sin(s * 40.0))))
	var blade := back.duplicate()
	var er := edge.duplicate()
	er.reverse()
	blade.append_array(er)
	cn.draw_colored_polygon(blade, Color("9aa3b0"))
	var hi := hamon.duplicate()
	hi.append_array(er)
	cn.draw_colored_polygon(hi, Color("eef3f8"))
	cn.draw_polyline(back, Color("5c6470"), 1.0)
	ca.draw_polyline(edge, Color(1.0, 0.45, 0.6, 0.35 + 0.25 * sin(t * 3.0 + ph * 6.0)), 3.0 * sc)
	ca.draw_polyline(edge, Color(1, 1, 1, 0.5), 1.0)
	var g := fposmod(t * 0.7 + ph, 1.5)
	if g < 1.0:
		var gi := clampi(int(g * float(N)), 0, N)
		sparkle(ca, edge[gi], (5.0 + 4.0 * sin(g * PI)) * sc, Color(1, 1, 1, sin(g * PI)))


static func _math(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var c := pt(ax, pp, sc, 34.0, 0.0)
	ca.draw_circle(c, 40.0 * sc, Color(0.2, 0.9, 1.0, 0.12 + 0.04 * sin(t * 2.0)))
	# órbitas como um átomo / gráfico
	for o in 2:
		var pts := PackedVector2Array()
		for i in 33:
			var a := float(i) / 32.0 * TAU
			pts.append(c + Vector2(cos(a) * 30.0, sin(a) * 12.0).rotated(ax.angle() + float(o) * 1.1 + t * 0.3) * sc)
		ca.draw_polyline(pts, Color(0.4, 0.95, 1.0, 0.45), 1.6 * sc)
	cn.draw_circle(c, 12.0 * sc, Color("0d2a24"))
	ca.draw_arc(c, 12.0 * sc, 0, TAU, 32, Color(0.4, 1.0, 1.0, 0.9), 2.0 * sc)
	cn.draw_text(c, "π", int(18.0 * sc), Color("ffd34a"))
	var syms := ["+", "×", "÷", "=", "√", "7", "3", "1", "4", "∞"]
	for i in syms.size():
		var a := t * 0.9 + float(i) * TAU / float(syms.size())
		var r := (34.0 + 6.0 * sin(t * 1.7 + float(i))) * sc
		var p := c + Vector2(cos(a) * r, sin(a) * r * 0.55).rotated(ax.angle())
		var tw := 0.6 + 0.4 * sin(t * 3.0 + float(i) * 1.3)
		var col: Color = [Color(0.4, 1.0, 1.0), Color(1.0, 0.85, 0.3), Color(1, 1, 1), Color(1.0, 0.45, 0.6)][i % 4]
		col.a = tw
		cn.draw_text(p, syms[i], int(15.0 * sc), col)


# COMETA: uma bola de luz orbitando a ponta com cauda azul e poeira de estrelas
static func _comet(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var c := pt(ax, pp, sc, 22.0, 0.0)
	ca.draw_circle(c, 26.0 * sc, Color(0.3, 0.6, 1.0, 0.10 + 0.04 * sin(t * 2.0)))
	for k in 2:
		var ph := t * (2.2 + k * 0.7) + k * PI
		var tail := PackedVector2Array()
		for i in 18:
			var a := ph - float(i) * 0.09
			var r := 20.0 + 3.0 * sin(a * 2.0)
			tail.append(c + (ax * cos(a) * r + pp * sin(a) * r * 0.55) * sc)
		for i in range(tail.size() - 1):
			var f := 1.0 - float(i) / tail.size()
			ca.draw_line(tail[i], tail[i + 1], Color(0.45, 0.8, 1.0, 0.55 * f), (6.0 * f + 1.0) * sc)
			ca.draw_line(tail[i], tail[i + 1], Color(0.9, 0.97, 1.0, 0.8 * f), (2.0 * f + 0.5) * sc)
		var hd: Vector2 = tail[0]
		ca.draw_circle(hd, 7.0 * sc, Color(0.6, 0.85, 1.0, 0.35))
		cn.draw_circle(hd, 3.6 * sc, Color(1.0, 1.0, 0.95))
	# núcleo: pequeno planeta gelado
	cn.draw_circle(c, 7.5 * sc, Color("123a7a"))
	cn.draw_circle(c + Vector2(-1.5, -1.5) * sc, 5.5 * sc, Color("3d8bff"))
	cn.draw_circle(c + Vector2(-2.6, -2.8) * sc, 2.2 * sc, Color(1, 1, 1, 0.7))
	for i in 12:
		var life := fposmod(t * 0.4 + float(i) / 12.0, 1.0)
		var p := pt(ax, pp, sc, 6.0 + life * 70.0, (hsh(float(i)) - 0.5) * 40.0 * (0.3 + life))
		sparkle(ca, p, (1.2 + (1.0 - life) * 2.8) * sc, Color(0.8, 0.95, 1.0, 0.9 * (1.0 - life)))


# IMPERADOR: coroa de ouro flutuando, joias brilhando e chuva de faíscas douradas
static func _crown(cn, ca, t: float, ax: Vector2, pp: Vector2, sc: float) -> void:
	var bob := sin(t * 2.0) * 2.0
	var u0 := 16.0 + bob
	ca.draw_circle(pt(ax, pp, sc, u0 + 12.0, 0.0), 24.0 * sc, Color(1.0, 0.8, 0.3, 0.14 + 0.06 * sin(t * 3.0)))
	# a coroa fica "em pé" apontando para fora da ponta do taco
	var base := [Vector2(u0, -13), Vector2(u0 + 7, -13), Vector2(u0 + 7, 13), Vector2(u0, 13)]
	cn.draw_colored_polygon(poly(ax, pp, sc, base), Color("b8860b"))
	var top := [Vector2(u0 + 7, -13), Vector2(u0 + 24, -16), Vector2(u0 + 13, -7), Vector2(u0 + 27, 0), Vector2(u0 + 13, 7), Vector2(u0 + 24, 16), Vector2(u0 + 7, 13)]
	cn.draw_colored_polygon(poly(ax, pp, sc, top), Color("f2c230"))
	cn.draw_polyline(poly(ax, pp, sc, top + [top[0]]), Color("fff1a8"), 1.4 * sc)
	cn.draw_line(pt(ax, pp, sc, u0 + 3.5, -13), pt(ax, pp, sc, u0 + 3.5, 13), Color("ffe58a"), 1.6 * sc)
	# joias nas pontas e na faixa
	var gems := [[Vector2(u0 + 24, -16), Color("ff2d55")], [Vector2(u0 + 27, 0), Color("3ddc84")], [Vector2(u0 + 24, 16), Color("4f8bff")], [Vector2(u0 + 3.5, 0), Color("ff2d55")]]
	for i in gems.size():
		var gp: Vector2 = pt(ax, pp, sc, gems[i][0].x, gems[i][0].y)
		var gc: Color = gems[i][1]
		var tw := 0.5 + 0.5 * sin(t * 4.0 + i * 1.7)
		ca.draw_circle(gp, (4.0 + tw * 3.0) * sc, Color(gc.r, gc.g, gc.b, 0.35))
		cn.draw_circle(gp, 2.6 * sc, gc)
		cn.draw_circle(gp + Vector2(-0.8, -0.8) * sc, 1.0 * sc, Color(1, 1, 1, 0.8))
	# faíscas douradas caindo
	for i in 14:
		var life := fposmod(t * 0.35 + float(i) / 14.0, 1.0)
		var p := pt(ax, pp, sc, u0 + 30.0 + hsh(float(i)) * 30.0 - life * 10.0, (hsh(float(i) + 3.0) - 0.5) * 50.0)
		var tw2 := 0.5 + 0.5 * sin(t * 6.0 + float(i))
		sparkle(ca, p, (1.4 + tw2 * 2.6) * sc, Color(1.0, 0.86, 0.4, 0.85 * (1.0 - life)))
