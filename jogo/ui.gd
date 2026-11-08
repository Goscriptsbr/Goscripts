extends CanvasLayer
# Menus: principal, modos, loja, estatísticas, ajustes, pausa e fim de jogo.

var game: Node2D
var root: Control
var dim: ColorRect
var screens := {}
var topbar: Control
var coin_lbl: Label
var level_lbl: Label
var level_bar: ProgressBar
var toast: Label
var cur := ""
var diff_sel := 1
var shop_tab := "felt"
var shop_row: HBoxContainer
var shop_scroll: ScrollContainer
var fx_nodes: Array = []
var fx_t := 0.0
var drag_id := -1
var drag_moved := 0.0
var swallow_click := false
const FxScript := preload("res://fx.gd")
var tab_btns := {}
var over_title: Label
var over_sub: Label
var over_reward: Label
var diff_btns: Array = []
var diff_desc: Label
var inv_sub := "cue"
var hero_nodes: Array = []
var truco_node: Control
var online_from := "play"
var shop_title: Label
var inv_btns := {}
var name_lbl: Label
var name_edit: LineEdit
var grana_lbl: Label
var top_center: HBoxContainer
var spin_top_btn: Button
var pass_top_btn: Button
var wheel: Control
var spin_btn: Button
var spin_lbl: Label
var spinning := false
var pass_scroll: ScrollContainer
var pass_row: HBoxContainer
var pass_head: Label
var pass_bar: ProgressBar
const PURPLE := Color("8e44ad")
var online_edit: LineEdit
var online_lbl: Label
var online_code: Label
var radar: Control
var online_game_btns := {}
var team_btns := {}
var online_mode := "world"
var online_mode_btns := {}
var code_row: HBoxContainer
var friends_box: VBoxContainer
var friend_edit: LineEdit
var search_box: VBoxContainer
var fr_btn: Button
var friends_t := 0.0
var invite_panel: PanelContainer
var invite_box: VBoxContainer
var search_btn: Button
var over_rematch: Button
var month_box: VBoxContainer
var month_fx: Array = []
var sfx_btn: Button
var timer_btn: Button
var vib_btn: Button
var stats_box: VBoxContainer

const GREEN := Color("1fa85a")
const GOLD := Color("e3a928")
const BLUE := Color("2f7fd6")
const GRAY := Color("3b4556")
const RED := Color("c94444")
const NAVY := Color(0.04, 0.08, 0.11, 0.9)


func sbox(col: Color, radius: int = 18, border: Color = Color(1, 1, 1, 0.0), bw: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, 4)
	return s


func mk_btn(text: String, w: float, h: float, col: Color, fs: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("normal", sbox(col, 20, col.lightened(0.35), 3, 8))
	b.add_theme_stylebox_override("hover", sbox(col.lightened(0.12), 20, Color.WHITE, 3, 8))
	b.add_theme_stylebox_override("pressed", sbox(col.darkened(0.2), 20, col.lightened(0.2), 3, 2))
	b.add_theme_stylebox_override("disabled", sbox(col.darkened(0.45), 20, Color(1, 1, 1, 0.15), 2, 0))
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.85))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("outline_size", 5)
	b.pressed.connect(game.play.bind("click", 0.6))
	return b


func mk_lbl(text: String, size: int, col: Color = Color.WHITE, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func mk_screen(sname: String, sep: int = 14) -> VBoxContainer:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	root.add_child(s)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	screens[sname] = s
	return v


func panel(w: float, h: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", sbox(NAVY, 26, Color(0.89, 0.66, 0.16, 0.55), 3, 16))
	return p


func margin(c: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	for k in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + k, m)
	mc.add_child(c)
	return mc


func build() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.05, 0.04, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	_build_main()
	_build_play()
	_build_online()
	_build_truco_menu()
	_build_amigos()
	_build_roleta()
	_build_passe()
	_build_shop()
	_build_stats()
	_build_settings()
	_build_pause()
	_build_over()
	_build_topbar()
	toast = mk_lbl("", 28, Color("ffe066"), 8)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position = Vector2(-300, -90)
	toast.size = Vector2(600, 50)
	toast.modulate.a = 0.0
	root.add_child(toast)


func say(t: String) -> void:
	toast.text = t
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)


# ---------------------------------------------------------------- barra superior
func coin_icon(sz: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	var f := func():
		var ctr := Vector2(sz / 2, sz / 2)
		c.draw_circle(ctr + Vector2(0, 2), sz / 2 - 1, Color(0, 0, 0, 0.35))
		c.draw_circle(ctr, sz / 2 - 2, Color("f2c230"))
		c.draw_arc(ctr, sz / 2 - 2, 0, TAU, 28, Color("b07a10"), 2.5)
		c.draw_arc(ctr, sz / 2 - 8, 0, TAU, 28, Color("c9951a"), 2.0)
		c.draw_circle(ctr + Vector2(-sz * 0.12, -sz * 0.14), sz * 0.1, Color(1, 1, 1, 0.55))
	c.draw.connect(f)
	return c


func grana_icon(sz: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	var f := func():
		var ctr := Vector2(sz / 2, sz / 2)
		var r := sz / 2 - 2
		var pts := PackedVector2Array([ctr + Vector2(0, -r), ctr + Vector2(r * 0.85, -r * 0.25), ctr + Vector2(0, r), ctr + Vector2(-r * 0.85, -r * 0.25)])
		c.draw_colored_polygon(pts, Color("a24cff"))
		c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -r), ctr + Vector2(r * 0.85, -r * 0.25), ctr + Vector2(0, -r * 0.1), ctr + Vector2(-r * 0.85, -r * 0.25)]), Color("d9a8ff"))
		c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -r * 0.1), ctr + Vector2(r * 0.85, -r * 0.25), ctr + Vector2(0, r)]), Color("6a1fb0"))
		pts.append(pts[0])
		c.draw_polyline(pts, Color("f3e3ff"), 1.5)
		c.draw_circle(ctr + Vector2(-r * 0.25, -r * 0.45), r * 0.12, Color(1, 1, 1, 0.8))
	c.draw.connect(f)
	return c


func _build_topbar() -> void:
	topbar = Control.new()
	topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topbar.custom_minimum_size = Vector2(0, 90)
	topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(topbar)
	# perfil
	var pf := PanelContainer.new()
	pf.add_theme_stylebox_override("panel", sbox(NAVY, 40, Color(1, 1, 1, 0.25), 2, 6))
	pf.position = Vector2(16, 14)
	topbar.add_child(pf)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	pf.add_child(margin(hb, 8))
	var av := Control.new()
	av.custom_minimum_size = Vector2(54, 54)
	var avf := func():
		av.draw_circle(Vector2(27, 27), 26, Color("141414"))
		av.draw_circle(Vector2(27, 27), 15, Color("f4f4ee"))
		av.draw_string(ThemeDB.fallback_font, Vector2(0, 38), "8", HORIZONTAL_ALIGNMENT_CENTER, 54, 28, Color("111111"))
		av.draw_circle(Vector2(17, 16), 5, Color(1, 1, 1, 0.4))
		av.draw_arc(Vector2(27, 27), 26, 0, TAU, 32, Color("e3a928"), 3.0)
	av.draw.connect(avf)
	hb.add_child(av)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	var nm := mk_lbl("Jogador", 24, Color.WHITE)
	name_lbl = nm
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(nm)
	level_lbl = mk_lbl("Nível 1", 18, Color("ffe066"))
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(level_lbl)
	level_bar = ProgressBar.new()
	level_bar.custom_minimum_size = Vector2(150, 8)
	level_bar.show_percentage = false
	level_bar.add_theme_stylebox_override("background", sbox(Color(0, 0, 0, 0.5), 4))
	level_bar.add_theme_stylebox_override("fill", sbox(GOLD, 4))
	vb.add_child(level_bar)
	# moedas
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", sbox(NAVY, 30, Color(0.89, 0.66, 0.16, 0.7), 2, 6))
	cp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cp.position = Vector2(-210, 22)
	cp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	topbar.add_child(cp)
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 10)
	cp.add_child(margin(hb2, 8))
	hb2.add_child(coin_icon(40))
	coin_lbl = mk_lbl("0", 30, Color("ffe066"), 5)
	coin_lbl.custom_minimum_size = Vector2(90, 0)
	hb2.add_child(coin_lbl)
	var gpn := PanelContainer.new()
	gpn.add_theme_stylebox_override("panel", sbox(NAVY, 30, Color(0.64, 0.3, 1.0, 0.7), 2, 6))
	gpn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gpn.position = Vector2(-370, 22)
	gpn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	topbar.add_child(gpn)
	var hb3 := HBoxContainer.new()
	hb3.add_theme_constant_override("separation", 8)
	gpn.add_child(margin(hb3, 8))
	hb3.add_child(grana_icon(38))
	grana_lbl = mk_lbl("0", 30, Color("e2c4ff"), 5)
	grana_lbl.custom_minimum_size = Vector2(56, 0)
	hb3.add_child(grana_lbl)
	top_center = HBoxContainer.new()
	top_center.add_theme_constant_override("separation", 14)
	top_center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_center.position = Vector2(-380, 20)
	topbar.add_child(top_center)

	refresh_top()


func refresh_top() -> void:
	var s: Dictionary = game.save
	coin_lbl.text = str(s.coins)
	if name_lbl != null:
		name_lbl.text = game.my_name()
	grana_lbl.text = str(int(s.get("grana", 0)))
	if spin_top_btn != null:
		_set_badge(spin_top_btn, "!" if game.can_spin() else "")
		var nin: int = game.save.get("f_in", []).size() + unread_total()
		_set_badge(fr_btn, str(nin) if nin > 0 else "")
		var pp: int = game.pass_pending()
		_set_badge(pass_top_btn, str(pp) if pp > 0 else "")
	level_lbl.text = "Nível %d" % game.player_level()
	level_bar.value = game.xp() % 100


# ---------------------------------------------------------------- telas
func _gloss(c: Control, r: Rect2, rad: int) -> void:
	c.draw_style_box(sbox(Color(1, 1, 1, 0.13), rad), Rect2(r.position + Vector2(4, 3), Vector2(r.size.x - 8, r.size.y * 0.45)))


func icon_btn(text: String, kind: String, col: Color, w: float) -> Button:
	var b := mk_btn("", w, 58, col, 19)
	var ic := Control.new()
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := func():
		var r := Rect2(Vector2.ZERO, ic.size)
		_gloss(ic, r, 18)
		_small_icon(ic, kind, Vector2(30, r.size.y / 2.0))
		var fnt: Font = ThemeDB.fallback_font
		ic.draw_string_outline(fnt, Vector2(52, r.size.y / 2.0 + 7), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 58, 19, 4, Color(0, 0, 0, 0.45))
		ic.draw_string(fnt, Vector2(52, r.size.y / 2.0 + 7), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 58, 19, Color.WHITE)
		var bd: String = ic.get_meta("badge", "")
		if bd != "":
			var bc := Vector2(r.size.x - 6, 6)
			ic.draw_circle(bc, 13, Color("e53935"))
			ic.draw_arc(bc, 13, 0, TAU, 24, Color.WHITE, 2.0)
			ic.draw_string(fnt, bc + Vector2(-13, 6), bd, HORIZONTAL_ALIGNMENT_CENTER, 26, 16, Color.WHITE)
	ic.draw.connect(f)
	b.add_child(ic)
	b.set_meta("ic", ic)
	return b


func _set_badge(b: Button, t: String, key := "badge") -> void:
	var ic: Control = b.get_meta("ic")
	ic.set_meta(key, t)
	ic.queue_redraw()


var friends_online := 0
var presence_t := 0.0


func _friends_badge() -> void:
	if fr_btn != null:
		_set_badge(fr_btn, str(friends_online) if friends_online > 0 else "", "badge2")


# pergunta ao servidor quem dos amigos está online (para a bolinha azul do menu)
func presence_poll() -> void:
	var codes := []
	for f in game.save.friends:
		codes.append(str(f.code))
	if codes.is_empty():
		friends_online = 0
		_friends_badge()
		return
	if game.net.server_ok:
		game.net.world_send({"t": "friends", "codes": codes})


func _small_icon(c: Control, kind: String, p: Vector2) -> void:
	if kind == "wheel":
		var cols := [Color("f4c542"), Color("e53935"), Color("2f7fd6"), Color("1fa85a"), Color("ff8f00"), Color("8e24aa")]
		for k in 6:
			var pts := PackedVector2Array([p])
			for j in 7:
				pts.append(p + Vector2.from_angle(float(k) * TAU / 6.0 + float(j) * TAU / 36.0) * 15.0)
			c.draw_colored_polygon(pts, cols[k])
		c.draw_arc(p, 15, 0, TAU, 32, Color.WHITE, 2.5)
		c.draw_circle(p, 4, Color.WHITE)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -19), p + Vector2(5, -19), p + Vector2(0, -11)]), Color("e53935"))
	elif kind == "ticket":
		var r := Rect2(p - Vector2(16, 11), Vector2(32, 22))
		c.draw_style_box(sbox(Color("f4c542"), 4), r)
		c.draw_circle(p + Vector2(-16, 0), 4, Color("16897f"))
		c.draw_circle(p + Vector2(16, 0), 4, Color("16897f"))
		for y in [-7, -2, 3, 8]:
			c.draw_line(p + Vector2(6, y), p + Vector2(6, y + 3), Color("8a5a10"), 1.5)
		c.draw_colored_polygon(_star(p + Vector2(-4, 0), 7, 3), Color("8a5a10"))
	elif kind == "globe":
		c.draw_circle(p, 15, Color("2fe6f6"))
		c.draw_arc(p, 15, 0, TAU, 32, Color.WHITE, 2.0)
		c.draw_line(p + Vector2(-15, 0), p + Vector2(15, 0), Color.WHITE, 1.5)
		c.draw_arc(p, 7, -PI / 2.0, PI / 2.0, 16, Color.WHITE, 1.5)
		c.draw_arc(p, 7, PI / 2.0, PI * 1.5, 16, Color.WHITE, 1.5)
		c.draw_line(p + Vector2(0, -15), p + Vector2(0, 15), Color.WHITE, 1.5)
	elif kind == "people":
		c.draw_circle(p + Vector2(8, -6), 6, Color(1, 1, 1, 0.65))
		c.draw_colored_polygon(_arcpoly(p + Vector2(8, 12), 11), Color(1, 1, 1, 0.65))
		c.draw_circle(p + Vector2(-4, -5), 7, Color.WHITE)
		c.draw_colored_polygon(_arcpoly(p + Vector2(-4, 14), 13), Color.WHITE)


func _arcpoly(base: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(base + Vector2.from_angle(PI + float(i) * PI / 12.0) * r)
	return pts


func _star(c: Vector2, r1: float, r2: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + float(i) * PI / 5.0) * (r1 if i % 2 == 0 else r2))
	return pts


func game_btn(title: String, sub: String, kind: String, col: Color) -> Button:
	var b := mk_btn("", 234, 118, col, 20)
	var ic := Control.new()
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := func():
		var r := Rect2(Vector2.ZERO, ic.size)
		_gloss(ic, r, 20)
		var fnt: Font = ThemeDB.fallback_font
		var p := Vector2(52, r.size.y / 2.0)
		if kind == "ball":
			ic.draw_circle(p + Vector2(2, 4), 33, Color(0, 0, 0, 0.3))
			ic.draw_circle(p, 33, Color("111111"))
			ic.draw_circle(p + Vector2(-3, -3), 15, Color("f4f4ee"))
			ic.draw_string(fnt, p + Vector2(-18, 6), "8", HORIZONTAL_ALIGNMENT_CENTER, 30, 22, Color("111111"))
			ic.draw_circle(p + Vector2(-14, -16), 7, Color(1, 1, 1, 0.35))
		else:
			for k in 3:
				var a := (float(k) - 1.0) * 0.32
				ic.draw_set_transform(p + Vector2(0, 26), a, Vector2.ONE)
				ic.draw_style_box(sbox(Color(0, 0, 0, 0.3), 5), Rect2(-17, -64, 36, 52))
				ic.draw_style_box(sbox(Color("fbfaf4"), 5, Color(0.2, 0.2, 0.2, 0.6), 1), Rect2(-19, -66, 36, 52))
				var red := k != 1
				var cc := Color("c0262d") if red else Color("161616")
				ic.draw_string(fnt, Vector2(-16, -50), ["3", "A", "7"][k], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cc)
				if red:
					ic.draw_circle(Vector2(-5, -36), 6, cc)
					ic.draw_circle(Vector2(5, -36), 6, cc)
					ic.draw_colored_polygon(PackedVector2Array([Vector2(-11, -34), Vector2(11, -34), Vector2(0, -22)]), cc)
				else:
					ic.draw_circle(Vector2(0, -44), 6, cc)
					ic.draw_circle(Vector2(-6, -36), 6, cc)
					ic.draw_circle(Vector2(6, -36), 6, cc)
					ic.draw_rect(Rect2(-2, -36, 4, 12), cc)
			ic.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ic.draw_string_outline(fnt, Vector2(96, r.size.y / 2.0 + 6), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 100, 32, 6, Color(0, 0, 0, 0.45))
		ic.draw_string(fnt, Vector2(96, r.size.y / 2.0 + 6), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 100, 32, Color.WHITE)
		ic.draw_string(fnt, Vector2(97, r.size.y / 2.0 + 32), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 100, 14, Color(1, 1, 1, 0.8))
		# seta de jogar
		var ap := Vector2(r.size.x - 22, r.size.y - 22)
		ic.draw_circle(ap, 11, Color(0, 0, 0, 0.25))
		ic.draw_colored_polygon(PackedVector2Array([ap + Vector2(-3, -6), ap + Vector2(6, 0), ap + Vector2(-3, 6)]), Color.WHITE)
	ic.draw.connect(f)
	b.add_child(ic)
	return b


func menu_tile(title: String, kind: String, col: Color) -> Button:
	var b := mk_btn("", 111, 112, col, 20)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	b.add_child(vb)
	var gl := Control.new()
	gl.set_anchors_preset(Control.PRESET_FULL_RECT)
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gl.draw.connect(func(): _gloss(gl, Rect2(Vector2.ZERO, gl.size), 18))
	b.add_child(gl)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(0, 58)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := func():
		_tile_icon(ic, kind, 111.0)
	ic.draw.connect(f)
	vb.add_child(ic)
	var t := mk_lbl(title, 15, Color.WHITE, 4)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(t)
	return b


func _tile_icon(c: Control, kind: String, w: float) -> void:
	var p := Vector2(w / 2.0, 30)
	var sh := Color(0, 0, 0, 0.28)
	if kind == "shop":
		# sacola de compras com moeda
		var bag := Rect2(p.x - 22, p.y - 12, 44, 36)
		c.draw_style_box(sbox(sh, 6), Rect2(bag.position + Vector2(2, 3), bag.size))
		c.draw_style_box(sbox(Color("fff3d6"), 6, Color("8a5a10"), 2), bag)
		c.draw_arc(p + Vector2(0, -12), 11, PI, TAU, 20, Color("8a5a10"), 3.0)
		c.draw_circle(p + Vector2(0, 7), 11, Color("f6c945"))
		c.draw_arc(p + Vector2(0, 7), 11, 0, TAU, 24, Color("b07d12"), 2.0)
		c.draw_string(ThemeDB.fallback_font, p + Vector2(-8, 13), "$", HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color("8a5a10"))
	elif kind == "inv":
		# baú
		var body := Rect2(p.x - 26, p.y - 4, 52, 28)
		c.draw_style_box(sbox(sh, 5), Rect2(body.position + Vector2(2, 3), body.size))
		c.draw_style_box(sbox(Color("8a5226"), 4, Color("3a2008"), 2), body)
		c.draw_style_box(sbox(Color("a8682f"), 10, Color("3a2008"), 2), Rect2(p.x - 26, p.y - 22, 52, 22))
		for x in [-18, 14]:
			c.draw_rect(Rect2(p.x + x, p.y - 22, 4, 46), Color("f4c542"))
		c.draw_style_box(sbox(Color("f4c542"), 3, Color("8a5a10"), 1), Rect2(p.x - 7, p.y - 9, 14, 16))
		c.draw_circle(p + Vector2(0, -2), 2.5, Color("3a2008"))
	elif kind == "stats":
		# troféu
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -22), p + Vector2(18, -22), p + Vector2(14, -2), p + Vector2(0, 6), p + Vector2(-14, -2)]), Color("f6c945"))
		c.draw_arc(p + Vector2(-18, -12), 9, PI * 0.5, PI * 1.5, 16, Color("f6c945"), 4.0)
		c.draw_arc(p + Vector2(18, -12), 9, -PI * 0.5, PI * 0.5, 16, Color("f6c945"), 4.0)
		c.draw_rect(Rect2(p.x - 4, p.y + 4, 8, 10), Color("d9a521"))
		c.draw_style_box(sbox(Color("8a5226"), 3), Rect2(p.x - 15, p.y + 14, 30, 9))
		c.draw_colored_polygon(_star(p + Vector2(0, -10), 7, 3), Color("fff3c0"))
		c.draw_line(p + Vector2(-12, -19), p + Vector2(-10, -6), Color(1, 1, 1, 0.5), 2.0)
	else:
		# engrenagem
		var teeth := PackedVector2Array()
		for i in 48:
			var a := float(i) / 48.0 * TAU
			var rr := 24.0 if (i / 3) % 2 == 0 else 18.0
			teeth.append(p + Vector2.from_angle(a) * rr)
		c.draw_colored_polygon(teeth, Color("e8edf2"))
		c.draw_circle(p, 17, Color("cfd6de"))
		c.draw_circle(p, 8, Color("3b4556"))
		c.draw_arc(p, 17, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.8), 2.0)


func _open_site() -> void:
	OS.shell_open("https://goscripts.com.br")


const RAIL_W := 130.0
const CARD_W := 330.0


func _build_main() -> void:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	root.add_child(s)
	screens["main"] = s
	var bg := TextureRect.new()
	bg.texture = load("res://assets/menu_bg.jpg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(bg)
	var shift := -(CARD_W + 40.0 - RAIL_W) / 2.0
	# logo
	var tt := Control.new()
	tt.custom_minimum_size = Vector2(600, 118)
	tt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tf := func():
		var f: Font = ThemeDB.fallback_font
		var w := 600.0
		tt.draw_string(f, Vector2(0, 84), "SINUCOU", HORIZONTAL_ALIGNMENT_CENTER, w, 92, Color(0, 0, 0, 0.5))
		tt.draw_string_outline(f, Vector2(0, 76), "SINUCOU", HORIZONTAL_ALIGNMENT_CENTER, w, 92, 16, Color("3a2402"))
		tt.draw_string_outline(f, Vector2(0, 76), "SINUCOU", HORIZONTAL_ALIGNMENT_CENTER, w, 92, 6, Color("ffe9a0"))
		tt.draw_string(f, Vector2(0, 76), "SINUCOU", HORIZONTAL_ALIGNMENT_CENTER, w, 92, Color("f7c33a"))
		var rb := Rect2(w / 2.0 - 120, 84, 240, 32)
		tt.draw_colored_polygon(PackedVector2Array([rb.position + Vector2(-18, 5), rb.position + Vector2(0, 5), rb.position + Vector2(0, 28), rb.position + Vector2(-18, 28), rb.position + Vector2(-9, 16)]), Color("7a1820"))
		tt.draw_colored_polygon(PackedVector2Array([rb.end + Vector2(18, -27), rb.end + Vector2(0, -27), rb.end + Vector2(0, -4), rb.end + Vector2(18, -4), rb.end + Vector2(9, -16)]), Color("7a1820"))
		tt.draw_style_box(sbox(Color("c0303a"), 6, Color("f4c542"), 2), rb)
		tt.draw_string(f, Vector2(rb.position.x, rb.position.y + 23), "SINUCA  &  TRUCO", HORIZONTAL_ALIGNMENT_CENTER, rb.size.x, 18, Color.WHITE)
	tt.draw.connect(tf)
	s.add_child(tt)
	tt.anchor_left = 0.5
	tt.anchor_right = 0.5
	tt.anchor_top = 0.0
	tt.anchor_bottom = 0.0
	tt.offset_left = -300 + shift
	tt.offset_right = 300 + shift
	tt.offset_top = 84
	tt.offset_bottom = 84 + 118
	# cartões dos jogos
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 26)
	s.add_child(hr)
	var h1 := hero_btn("SINUCA", "8 bolas  •  IA, 2 jogadores e online", "res://assets/hero_sinuca.png", Color("3ddc84"))
	h1.pressed.connect(show_screen.bind("play"))
	hr.add_child(h1)
	var h2 := hero_btn("TRUCO", "paulista  •  1x1, 2x2 e online", "res://assets/hero_truco.png", Color("ff7a7a"))
	h2.pressed.connect(show_screen.bind("truco"))
	hr.add_child(h2)
	hr.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	hr.offset_left += shift
	hr.offset_right += shift
	hr.offset_top += 18
	hr.offset_bottom += 18
	# trilho da esquerda: roleta, passe, amigos
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 14)
	s.add_child(rail)
	spin_top_btn = rail_btn("ROLETA", "wheel", PURPLE)
	spin_top_btn.pressed.connect(show_screen.bind("roleta"))
	rail.add_child(spin_top_btn)
	pass_top_btn = rail_btn("PASSE", "ticket", Color("16897f"))
	pass_top_btn.pressed.connect(show_screen.bind("passe"))
	rail.add_child(pass_top_btn)
	fr_btn = rail_btn("AMIGOS", "people", BLUE)
	fr_btn.pressed.connect(show_screen.bind("amigos"))
	rail.add_child(fr_btn)
	rail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 22)
	rail.offset_top -= 10
	rail.offset_bottom -= 10
	# taco do mês (direita)
	var mc := PanelContainer.new()
	mc.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.82), 26, Color(0.96, 0.77, 0.26, 0.75), 2, 16))
	s.add_child(mc)
	month_box = VBoxContainer.new()
	month_box.add_theme_constant_override("separation", 3)
	mc.add_child(margin(month_box, 12))
	mc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
	mc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mc.grow_vertical = Control.GROW_DIRECTION_BOTH
	mc.offset_top -= 10
	mc.offset_bottom -= 10
	# barra de baixo
	var nav := PanelContainer.new()
	var nsb := sbox(Color(0.01, 0.03, 0.05, 0.9), 0)
	nsb.border_width_top = 2
	nsb.border_color = Color(0.96, 0.77, 0.26, 0.7)
	nav.add_theme_stylebox_override("panel", nsb)
	s.add_child(nav)
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	nav.offset_top = -86
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	nh.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_child(nh)
	for it in [["LOJA", "shop", "shop"], ["INVENTÁRIO", "inv", "inv"], ["ESTATÍSTICAS", "stats", "stats"], ["AJUSTES", "gear", "settings"]]:
		var nb := nav_btn(it[0], it[1])
		nb.pressed.connect(show_screen.bind(it[2]))
		nh.add_child(nb)
	# crédito GoScripts (canto de baixo à esquerda, dentro da barra)
	var cr := Button.new()
	cr.flat = true
	cr.focus_mode = Control.FOCUS_NONE
	cr.custom_minimum_size = Vector2(230, 70)
	var ce := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		cr.add_theme_stylebox_override(st, ce)
	var lg: Texture2D = load("res://assets/goscripts_logo.png")
	var crd := Control.new()
	crd.set_anchors_preset(Control.PRESET_FULL_RECT)
	crd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crd.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		crd.draw_texture_rect(lg, Rect2(8, 10, 70, 50), false)
		crd.draw_string(f, Vector2(84, 30), "DESENVOLVIDO POR", HORIZONTAL_ALIGNMENT_LEFT, 150, 11, Color(1, 1, 1, 0.55))
		crd.draw_string(f, Vector2(84, 52), "GoScripts", HORIZONTAL_ALIGNMENT_LEFT, 150, 22, Color("2fe6f6"))
		crd.draw_string(f, Vector2(84, 66), "goscripts.com.br", HORIZONTAL_ALIGNMENT_LEFT, 150, 11, Color(0.6, 0.95, 1.0, 0.8)))
	cr.add_child(crd)
	cr.pressed.connect(game.play.bind("click", 0.6))
	cr.pressed.connect(_open_site)
	s.add_child(cr)
	cr.anchor_left = 0.0
	cr.anchor_right = 0.0
	cr.anchor_top = 1.0
	cr.anchor_bottom = 1.0
	cr.offset_left = 10
	cr.offset_right = 240
	cr.offset_top = -78
	cr.offset_bottom = -8


func hero_btn(title: String, sub: String, img: String, glow: Color, sz: Vector2 = Vector2(320, 268), tsz: int = 46, badge: String = "") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = sz
	var e := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, e)
	b.pivot_offset = sz / 2.0
	var tex: Texture2D = load(img)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var r := Rect2(Vector2.ZERO, c.size)
		var pul := 0.5 + 0.5 * sin(fx_t * 2.2)
		c.draw_style_box(sbox(Color(glow.r, glow.g, glow.b, 0.16 + 0.12 * pul), 34), r.grow(6))
		c.draw_style_box(sbox(Color(0, 0, 0, 0.45), 28), Rect2(r.position + Vector2(4, 10), r.size))
		c.draw_texture_rect(tex, r, false)
		var f: Font = ThemeDB.fallback_font
		c.draw_string_outline(f, Vector2(22, r.size.y - 44), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, tsz, 8, Color(0, 0, 0, 0.6))
		c.draw_string(f, Vector2(22, r.size.y - 44), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, tsz, Color.WHITE)
		if badge != "":
			var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 22
			c.draw_style_box(sbox(Color(0, 0, 0, 0.55), 12, glow, 2), Rect2(14, 14, bw, 28))
			c.draw_string(f, Vector2(14, 33), badge, HORIZONTAL_ALIGNMENT_CENTER, bw, 14, glow.lightened(0.4))
		c.draw_string(f, Vector2(24, r.size.y - 18), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 15, Color(1, 1, 1, 0.82))
		var big := r.size.x >= 315.0
		var pr := 25.0 if big else 17.0
		var pc := Vector2(r.size.x - 42, r.size.y - 50) if big else Vector2(r.size.x - 30, 34)
		c.draw_circle(pc, pr, glow.darkened(0.2))
		c.draw_arc(pc, pr, 0, TAU, 32, Color.WHITE, 2.5)
		var ts := pr / 25.0
		c.draw_colored_polygon(PackedVector2Array([pc + Vector2(-7, -11) * ts, pc + Vector2(12, 0) * ts, pc + Vector2(-7, 11) * ts]), Color.WHITE))
	b.add_child(c)
	hero_nodes.append(c)
	b.mouse_entered.connect(func(): create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.12))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	b.button_down.connect(func(): create_tween().tween_property(b, "scale", Vector2(0.96, 0.96), 0.06))
	b.button_up.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	b.pressed.connect(game.play.bind("click", 0.6))
	return b


func rail_btn(text: String, kind: String, col: Color) -> Button:
	var b := mk_btn("", 104, 104, col, 16)
	for st in ["normal", "hover", "pressed"]:
		var sb := sbox(col if st != "pressed" else col.darkened(0.2), 52, col.lightened(0.4) if st == "normal" else Color.WHITE, 3, 10 if st != "pressed" else 2)
		b.add_theme_stylebox_override(st, sb)
	var ic := Control.new()
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func():
		var r := Rect2(Vector2.ZERO, ic.size)
		ic.draw_circle(Vector2(52, 38), 40, Color(1, 1, 1, 0.08))
		ic.draw_set_transform(Vector2(52, 40), 0.0, Vector2(1.45, 1.45))
		_small_icon(ic, kind, Vector2.ZERO)
		ic.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var f: Font = ThemeDB.fallback_font
		ic.draw_string_outline(f, Vector2(0, 84), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, 4, Color(0, 0, 0, 0.5))
		ic.draw_string(f, Vector2(0, 84), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color.WHITE)
		var bd: String = ic.get_meta("badge", "")
		if bd != "":
			var bc := Vector2(r.size.x - 12, 12)
			ic.draw_circle(bc, 14, Color("e53935"))
			ic.draw_arc(bc, 14, 0, TAU, 24, Color.WHITE, 2.0)
			ic.draw_string(f, bc + Vector2(-14, 6), bd, HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color.WHITE)
		# bolinha azul: quantos amigos estão online agora
		var b2: String = ic.get_meta("badge2", "")
		if b2 != "":
			var c2 := Vector2(12, 12)
			ic.draw_circle(c2, 14, Color("1e88e5"))
			ic.draw_arc(c2, 14, 0, TAU, 24, Color.WHITE, 2.0)
			ic.draw_circle(c2 + Vector2(10, 10), 5, Color("3ddc84"))
			ic.draw_arc(c2 + Vector2(10, 10), 5, 0, TAU, 16, Color.WHITE, 1.5)
			ic.draw_string(f, c2 + Vector2(-14, 6), b2, HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color.WHITE))
	b.add_child(ic)
	b.set_meta("ic", ic)
	return b


func nav_btn(text: String, kind: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(128, 80)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", sbox(Color(1, 1, 1, 0.08), 16))
	b.add_theme_stylebox_override("pressed", sbox(Color(1, 1, 1, 0.14), 16))
	var ic := Control.new()
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func():
		ic.draw_set_transform(Vector2(64 - 55.5 * 0.78, 6), 0.0, Vector2(0.78, 0.78))
		_tile_icon(ic, kind, 111.0)
		ic.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ic.draw_string(ThemeDB.fallback_font, Vector2(0, 72), text, HORIZONTAL_ALIGNMENT_CENTER, 128, 14, Color(1, 1, 1, 0.9)))
	b.add_child(ic)
	b.pressed.connect(game.play.bind("click", 0.6))
	return b


func mode_card(title: String, desc: String, icon: String, col: Color, badge: String = "") -> Button:
	var b := mk_btn("", 330, 262, col, 20)
	b.add_theme_stylebox_override("normal", sbox(Color(0.03, 0.07, 0.12, 0.93), 28, col.lightened(0.1), 3, 14))
	b.add_theme_stylebox_override("hover", sbox(Color(0.06, 0.12, 0.2, 0.96), 28, Color.WHITE, 4, 18))
	b.add_theme_stylebox_override("pressed", sbox(Color(0.02, 0.05, 0.09, 0.96), 28, col, 3, 4))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 8)
	b.add_child(vb)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(0, 118)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := func():
		ic.draw_circle(Vector2(165, 58), 62, Color(col.r, col.g, col.b, 0.16))
		ic.draw_circle(Vector2(165, 58), 48, Color(col.r, col.g, col.b, 0.18))
		ic.draw_arc(Vector2(165, 58), 62, 0, TAU, 48, Color(col.r, col.g, col.b, 0.6), 2.0)
		_icon(ic, icon, 330.0, col)
	ic.draw.connect(f)
	vb.add_child(ic)
	var t := mk_lbl(title, 31, Color.WHITE, 5)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(t)
	var d := mk_lbl(desc, 19, Color(1, 1, 1, 0.78))
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(d)
	if badge != "":
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_theme_stylebox_override("panel", sbox(Color(col.r, col.g, col.b, 0.3), 14, col.lightened(0.2), 2, 0))
		var pl := mk_lbl(badge, 14, col.lightened(0.5))
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(margin(pl, 5))
		vb.add_child(pill)
	return b


func _icon(c: Control, kind: String, w: float, col: Color) -> void:
	var ctr := Vector2(w / 2, 52)
	if kind == "tr1" or kind == "tr2":
		var cnt := 2 if kind == "tr1" else 4
		for i in cnt:
			var a := (float(i) - (cnt - 1) / 2.0) * 0.32
			c.draw_set_transform(ctr + Vector2(0, 30), a, Vector2.ONE)
			c.draw_rect(Rect2(-20, -78, 40, 58), Color("fbfaf4"), true)
			c.draw_rect(Rect2(-20, -78, 40, 58), Color(0.1, 0.1, 0.1, 0.6), false, 1.5)
			var red := i % 2 == 0
			c.draw_string(ThemeDB.fallback_font, Vector2(-16, -60), ["3", "A", "2", "K"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c0262d") if red else Color("161616"))
			c.draw_circle(Vector2(0, -46), 7, Color("c0262d") if red else Color("161616"))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if kind == "ai":
		c.draw_rect(Rect2(ctr.x - 46, ctr.y - 34, 92, 60), Color("e9eef2"), true)
		c.draw_rect(Rect2(ctr.x - 40, ctr.y - 28, 80, 48), Color("123526"), true)
		c.draw_circle(ctr + Vector2(-12, -4), 9, Color("d12a1e"))
		c.draw_circle(ctr + Vector2(14, 6), 9, Color("f4f4ee"))
		c.draw_rect(Rect2(ctr.x - 14, ctr.y + 26, 28, 8), Color("e9eef2"), true)
		c.draw_rect(Rect2(ctr.x - 26, ctr.y + 32, 52, 6), Color("c8d0d6"), true)
	elif kind == "two":
		for sx in [-1.0, 1.0]:
			c.draw_circle(ctr + Vector2(sx * 34, -14), 17, Color("f1d3a8") if sx < 0 else Color("e0b88a"))
			c.draw_circle(ctr + Vector2(sx * 34, 34), 28, Color("2f7fd6") if sx < 0 else Color("c94444"))
		c.draw_rect(Rect2(0, 0, 0, 0), Color.WHITE)
	else:
		var cols := [Color("f2c200"), Color("1a4fb4"), Color("d12a1e"), Color("5a2a82"), Color("0b0b0b"), Color("12823f")]
		var k := 0
		for row in 3:
			for j in row + 1:
				var p := ctr + Vector2(-28 + row * 26, (j - row / 2.0) * 28 - 0)
				c.draw_circle(p, 13, cols[k % cols.size()])
				c.draw_circle(p + Vector2(-4, -4), 4, Color(1, 1, 1, 0.45))
				k += 1
		c.draw_circle(ctr + Vector2(-74, 0), 13, Color("f4f4ee"))


func add_bg(sname: String, tex_path: String, dark: float = 0.25) -> void:
	var scr: Control = screens[sname]
	var bg := TextureRect.new()
	bg.texture = load(tex_path)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(bg)
	scr.move_child(bg, 0)
	if dark > 0.0:
		var d := ColorRect.new()
		d.color = Color(0, 0, 0, dark)
		d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scr.add_child(d)
		scr.move_child(d, 1)


func _seg_paint(btns: Array, sel: int, cols: Array) -> void:
	for k in btns.size():
		var b: Button = btns[k]
		var on := k == sel
		var col: Color = cols[k % cols.size()] if on else Color(0.09, 0.12, 0.17, 0.95)
		b.add_theme_stylebox_override("normal", sbox(col, 22, Color.WHITE if on else Color(1, 1, 1, 0.18), 3 if on else 2, 8 if on else 0))
		b.add_theme_stylebox_override("hover", sbox(col.lightened(0.12), 22, Color.WHITE, 3, 8))


func _section(t: String) -> Label:
	var l := mk_lbl(t, 14, Color("f4c542"), 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _build_play() -> void:
	var v := mk_screen("play", 14)
	add_bg("play", "res://assets/menu_bg.jpg", 0.15)
	var hd := Control.new()
	hd.custom_minimum_size = Vector2(700, 86)
	hd.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		hd.draw_string_outline(f, Vector2(0, 54), "SINUCA", HORIZONTAL_ALIGNMENT_CENTER, 700, 58, 10, Color("3a2402"))
		hd.draw_string(f, Vector2(0, 54), "SINUCA", HORIZONTAL_ALIGNMENT_CENTER, 700, 58, Color("f7c33a"))
		hd.draw_string(f, Vector2(0, 82), "ESCOLHA COMO VOCÊ QUER JOGAR", HORIZONTAL_ALIGNMENT_CENTER, 700, 18, Color(1, 1, 1, 0.75)))
	v.add_child(hd)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var c1 := hero_btn("CONTRA A IA", "Desafie a IA GoScripts", "res://assets/mode_ai.png", Color("3ddc84"), Vector2(330, 290), 34, "GANHE MOEDAS")
	c1.pressed.connect(_start.bind(game.Mode.AI))
	var c2 := hero_btn("2 JOGADORES", "Revezando no mesmo celular", "res://assets/mode_2p.png", Color("6fb4ff"), Vector2(330, 290), 34, "DUELO LOCAL")
	c2.pressed.connect(_start.bind(game.Mode.TWO))
	var c3 := hero_btn("TREINO LIVRE", "Sem regras e sem tempo", "res://assets/mode_train.png", Color("ffd35a"), Vector2(330, 290), 34, "PRATIQUE")
	c3.pressed.connect(_start.bind(game.Mode.TRAIN))
	row.add_child(c1)
	row.add_child(c2)
	row.add_child(c3)
	# dificuldade
	var dp := PanelContainer.new()
	dp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.85), 28, Color(1, 1, 1, 0.2), 2, 10))
	v.add_child(dp)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	dp.add_child(margin(dh, 10))
	var dl := mk_lbl("IA:", 18, Color("f4c542"), 2)
	dl.custom_minimum_size = Vector2(44, 0)
	dh.add_child(dl)
	var names := ["★  FÁCIL", "★★  MÉDIO", "★★★  DIFÍCIL"]
	diff_btns.clear()
	for i in 3:
		var b := mk_btn(names[i], 170, 48, GRAY, 19)
		b.pressed.connect(_set_diff.bind(i))
		diff_btns.append(b)
		dh.add_child(b)
	diff_desc = mk_lbl("", 15, Color(1, 1, 1, 0.8))
	diff_desc.custom_minimum_size = Vector2(300, 0)
	dh.add_child(diff_desc)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 18)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(brow)
	var back := mk_btn("◀  VOLTAR", 200, 60, GRAY, 24)
	back.pressed.connect(show_screen.bind("main"))
	brow.add_child(back)
	var onl := icon_btn("JOGAR ONLINE  •  1x1 OU 2x2", "globe", BLUE, 440)
	onl.custom_minimum_size = Vector2(440, 60)
	onl.pressed.connect(func():
		game.net_game = "sinuca"
		online_from = "play"
		show_screen("online"))
	brow.add_child(onl)
	_set_diff(diff_sel)


func _build_online() -> void:
	var v := mk_screen("online", 10)
	add_bg("online", "res://assets/menu_bg.jpg", 0.2)
	online_bg_truco = TextureRect.new()
	online_bg_truco.texture = load("res://assets/menu_bg.jpg")
	online_bg_truco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	online_bg_truco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	online_bg_truco.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	online_bg_truco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	online_bg_truco.modulate = Color(1.0, 0.42, 0.42)
	screens["online"].add_child(online_bg_truco)
	screens["online"].move_child(online_bg_truco, 1)
	var hd := Control.new()
	hd.custom_minimum_size = Vector2(700, 64)
	hd.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		hd.draw_string_outline(f, Vector2(0, 50), "JOGAR ONLINE", HORIZONTAL_ALIGNMENT_CENTER, 700, 50, 10, Color("3a2402"))
		hd.draw_string(f, Vector2(0, 50), "JOGAR ONLINE", HORIZONTAL_ALIGNMENT_CENTER, 700, 50, Color("f7c33a")))
	v.add_child(hd)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(body)
	# ---- coluna de opções
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.88), 26, Color(1, 1, 1, 0.18), 2, 12))
	body.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lp.add_child(margin(lv, 16))
	lv.add_child(_section("JOGO"))
	var gs := HBoxContainer.new()
	gs.add_theme_constant_override("separation", 10)
	lv.add_child(gs)
	for k in [["sinuca", "SINUCA"], ["truco", "TRUCO"]]:
		var gb := mk_btn(k[1], 190, 58, GRAY, 22)
		gb.pressed.connect(_online_game.bind(k[0]))
		online_game_btns[k[0]] = gb
		gs.add_child(gb)
	lv.add_child(_section("MESA"))
	var ts := HBoxContainer.new()
	ts.add_theme_constant_override("separation", 10)
	lv.add_child(ts)
	for k in [[false, "1 CONTRA 1"], [true, "2 CONTRA 2"]]:
		var tb := mk_btn(k[1], 190, 58, GRAY, 20)
		tb.pressed.connect(_online_team.bind(k[0]))
		team_btns[k[0]] = tb
		ts.add_child(tb)
	lv.add_child(_section("CONEXÃO"))
	var cs := HBoxContainer.new()
	cs.add_theme_constant_override("separation", 10)
	lv.add_child(cs)
	for k in [["world", "INTERNET"], ["lan", "MESMO WI-FI"]]:
		var mb := mk_btn(k[1], 190, 58, GRAY, 19)
		mb.pressed.connect(_online_mode.bind(k[0]))
		online_mode_btns[k[0]] = mb
		cs.add_child(mb)
	lobby_btn = icon_btn("CRIAR LOBBY DE AMIGOS", "people", Color("8e44ad"), 390)
	lobby_btn.pressed.connect(func(): lobby_create_ask(""))
	lv.add_child(lobby_btn)
	var fb := icon_btn("AMIGOS  •  CONVIDAR", "people", Color("16897f"), 390)
	fb.pressed.connect(show_screen.bind("amigos"))
	lv.add_child(fb)
	lv.add_child(mk_lbl("Vitória +60 moedas  •  Derrota +15", 15, Color("ffe066"), 2))
	# ---- painel de busca
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.9), 26, Color("5aa9ff"), 3, 14))
	body.add_child(rp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	rp.add_child(margin(pv, 16))
	radar = Control.new()
	radar.custom_minimum_size = Vector2(600, 300)
	radar.draw.connect(_draw_seats)
	pv.add_child(radar)
	lobby_row = HBoxContainer.new()
	lobby_row.add_theme_constant_override("separation", 8)
	lobby_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lobby_row.custom_minimum_size = Vector2(600, 38)
	pv.add_child(lobby_row)
	online_lbl = mk_lbl("", 19, Color(1, 1, 1, 0.92), 3)
	online_lbl.custom_minimum_size = Vector2(600, 50)
	online_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(online_lbl)
	var sbr := HBoxContainer.new()
	sbr.add_theme_constant_override("separation", 12)
	sbr.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(sbr)
	search_btn = mk_btn("CANCELAR BUSCA", 300, 58, RED, 22)
	search_btn.pressed.connect(_online_toggle_search)
	sbr.add_child(search_btn)
	start_btn = mk_btn("JOGAR AGORA", 300, 58, Color("e67e22"), 22)
	start_btn.pressed.connect(func():
		game.net.world_send({"t": "lstart"})
		online_status("Montando a mesa com seu lobby..."))
	start_btn.visible = false
	sbr.add_child(start_btn)
	# ---- código de sala (só no Wi-Fi)
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 10)
	mr.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(mr)
	code_row = mr
	mr.add_child(mk_lbl("Não achou? Use código:", 17, Color(1, 1, 1, 0.75), 2))
	var hb := mk_btn("CRIAR SALA", 170, 50, GREEN, 20)
	hb.pressed.connect(_online_host)
	mr.add_child(hb)
	online_code = mk_lbl("", 26, Color("ffe066"), 4)
	mr.add_child(online_code)
	online_edit = LineEdit.new()
	online_edit.placeholder_text = "código ou IP"
	online_edit.custom_minimum_size = Vector2(200, 50)
	online_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_edit.add_theme_font_size_override("font_size", 22)
	online_edit.add_theme_stylebox_override("normal", sbox(Color(0.02, 0.05, 0.09, 0.95), 14, Color(1, 1, 1, 0.35), 2, 0))
	online_edit.add_theme_stylebox_override("focus", sbox(Color(0.02, 0.05, 0.09, 0.95), 14, Color("5aa9ff"), 3, 0))
	mr.add_child(online_edit)
	var jb := mk_btn("ENTRAR", 130, 50, BLUE, 20)
	jb.pressed.connect(_online_join)
	mr.add_child(jb)
	var back := mk_btn("◀  VOLTAR", 220, 54, GRAY, 24)
	back.pressed.connect(_online_back)
	v.add_child(back)


var online_bg_truco: TextureRect
var wait_have := 1
var wait_need := 2
var wait_left := -1.0
var _last_busy := false
var lobby := {}
var lobby_row: HBoxContainer
var start_btn: Button
var lobby_btn: Button
var lobby_invite_after := ""


# antes de criar o lobby: qual jogo e quantos jogadores
func lobby_create_ask(invite_code: String) -> void:
	close_modal()
	var sel := {"g": game.net_game, "four": true}
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.65)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.05, 0.1, 0.97), 28, Color("b07cff"), 3, 24))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(margin(vb, 26))
	vb.add_child(mk_lbl("CRIAR LOBBY DE AMIGOS", 34, Color("f4c542"), 6))
	vb.add_child(mk_lbl("Monte a mesa com seus amigos e jogue quando quiser.", 18, Color(1, 1, 1, 0.75), 2))
	vb.add_child(_section("QUAL JOGO?"))
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", 12)
	gr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(gr)
	var gb := []
	for k in [["sinuca", "SINUCA"], ["truco", "TRUCO"]]:
		var b := mk_btn(k[1], 220, 64, GRAY, 26)
		gr.add_child(b)
		gb.append(b)
	vb.add_child(_section("QUANTOS JOGADORES?"))
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 12)
	tr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(tr)
	var tb := []
	for k in [[false, "1 CONTRA 1"], [true, "2 CONTRA 2"]]:
		var b2 := mk_btn(k[1], 220, 64, GRAY, 22)
		tr.add_child(b2)
		tb.append(b2)
	var paint := func():
		_seg_paint(gb, 0 if sel.g == "sinuca" else 1, [GREEN, Color("b8323a")])
		_seg_paint(tb, 1 if sel.four else 0, [Color("e67e22")])
	for i in 2:
		gb[i].pressed.connect(func():
			sel.g = "sinuca" if i == 0 else "truco"
			paint.call())
		tb[i].pressed.connect(func():
			sel.four = i == 1
			paint.call())
	paint.call()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var ok := mk_btn("CRIAR LOBBY", 240, 64, GREEN, 24)
	ok.pressed.connect(func():
		close_modal()
		if not game.net.server_ok:
			game.net.connect_server()
			say("Conectando ao servidor... tente de novo em alguns segundos.")
			return
		game.net.stop_search()
		game.net.world_cancel()
		game.net_game = str(sel.g)
		game.net_team = bool(sel.four)
		online_mode = "world"
		lobby_invite_after = invite_code
		game.net.world_send({"t": "lcreate", "game": sel.g, "four": sel.four}))
	row.add_child(ok)
	var no := mk_btn("CANCELAR", 200, 64, GRAY, 22)
	no.pressed.connect(close_modal)
	row.add_child(no)

var _keep_search := false


func in_lobby() -> bool:
	return (lobby.get("members", []) as Array).size() >= 1 and str(lobby.get("leader", "")) != ""


func lobby_leader() -> bool:
	return in_lobby() and str(lobby.get("leader", "")) == game.my_code()


# o servidor manda o estado do lobby (amigos juntos procurando mesa)
func lobby_update(m: Dictionary) -> void:
	var was := in_lobby()
	lobby = m
	var msg := str(m.get("msg", ""))
	if not in_lobby():
		lobby = {}
		if was:
			game.net.pending_queue = ""
			game.net.queued = false
			if msg != "":
				say(msg)
			if cur == "online":
				online_status((msg + " Toque em PROCURAR OPONENTE para jogar sozinho.") if msg != "" else "Você saiu do lobby.")
		_lobby_paint()
		_online_btn_refresh()
		return
	# no meio de uma partida: só guarda o lobby (volta para ele quando a partida acabar)
	if game.net.active or (truco_node != null and is_instance_valid(truco_node)) or (game.mode == game.Mode.ONLINE and game.st != game.St.MENU):
		return
	game.net_game = str(m.get("game", "sinuca"))
	game.net_team = bool(m.get("four", true))
	if not lobby_leader():
		game.net.pending_queue = ""
		game.net.queued = false
	elif not bool(m.get("searching", false)):
		game.net.pending_queue = ""
		game.net.queued = false
	if cur != "online":
		if truco_node != null and is_instance_valid(truco_node):
			return
		online_mode = "world"
		_keep_search = true
		show_screen("online")
		_keep_search = false
	_online_paint_opts()
	_lobby_paint()
	if msg != "":
		say(msg)
	if lobby_invite_after != "" and lobby_leader():
		var code := lobby_invite_after
		lobby_invite_after = ""
		game.net.world_send({"t": "invite", "code": code, "game": game.net_game, "lobby": true})
	if lobby_leader():
		if bool(m.get("searching", false)):
			online_status("Lobby pronto! Procurando adversários... a IA completa se demorar.")
		elif (m.members as Array).size() < 2:
			online_status("Lobby criado! Chame amigos em AMIGOS • CONVIDAR (botão CHAMAR P/ LOBBY).")
		elif game.net_team:
			online_status("%d no lobby. Toque no nome (⇄) para trocar de time. JOGAR AGORA começa já (a IA completa)." % (m.members as Array).size())
		else:
			online_status("Toque em JOGAR 1x1 para jogar contra seu amigo.")
	else:
		online_status("Você está no lobby de %s. %s" % [_lobby_name(str(m.leader)), "Procurando adversários..." if bool(m.get("searching", false)) else "Esperando o dono começar a partida."])
	_online_btn_refresh()


var update_seen := false


# o servidor diz qual é a versão mais nova; se for maior que a nossa, oferece baixar
func check_update(info: Dictionary) -> void:
	var nv: int = int(info.get("versao", 0))
	if nv <= game.APP_VERSION or update_seen or str(info.get("url", "")) == "":
		return
	if game.net.active or (truco_node != null and is_instance_valid(truco_node)) or game.st != game.St.MENU:
		return  # não atrapalha no meio de uma partida; aparece na próxima vez que conectar
	update_seen = true
	show_update(nv, str(info.url), str(info.get("notas", "")))


func show_update(nv: int, url: String, notas: String) -> void:
	close_modal()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.72)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.05, 0.1, 0.97), 28, Color("3ddc84"), 3, 24))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(margin(vb, 24))
	vb.add_child(mk_lbl("NOVA VERSÃO DO SINUCOU!", 36, Color("3ddc84"), 8))
	if notas != "":
		var nl := mk_lbl(notas, 18, Color(1, 1, 1, 0.85), 2)
		nl.custom_minimum_size = Vector2(640, 0)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(nl)
	var steps := PanelContainer.new()
	steps.add_theme_stylebox_override("panel", sbox(Color(1, 1, 1, 0.05), 16, Color(1, 1, 1, 0.15), 1, 0))
	vb.add_child(steps)
	var sl := mk_lbl("1.  Toque em ATUALIZAR AGORA e espere a barra encher\n2.  Se o Android pedir, permita o Sinucou \"instalar apps\" e volte\n3.  Toque em ATUALIZAR na tela do Android\n     (seus tacos, moedas e amigos continuam)", 17, Color.WHITE, 2)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	steps.add_child(margin(sl, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	upd_bar = ProgressBar.new()
	upd_bar.custom_minimum_size = Vector2(600, 26)
	upd_bar.show_percentage = true
	upd_bar.visible = false
	upd_bar.add_theme_stylebox_override("background", sbox(Color(0, 0, 0, 0.55), 10))
	upd_bar.add_theme_stylebox_override("fill", sbox(GREEN, 10))
	upd_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(upd_bar)
	upd_lbl = mk_lbl("", 16, Color(1, 1, 1, 0.75), 2)
	vb.add_child(upd_lbl)
	var ok := mk_btn("ATUALIZAR AGORA", 300, 64, GREEN, 24)
	ok.pressed.connect(func():
		ok.disabled = true
		_update_download(url))
	row.add_child(ok)
	var web := mk_btn("PELO NAVEGADOR", 220, 64, BLUE, 18)
	web.pressed.connect(func(): OS.shell_open(url))
	row.add_child(web)
	var no := mk_btn("DEPOIS", 160, 64, GRAY, 22)
	no.pressed.connect(func():
		if upd_req != null:
			upd_req.cancel_request()
			upd_req.queue_free()
			upd_req = null
		close_modal())
	row.add_child(no)


var upd_req: HTTPRequest
var upd_bar: ProgressBar
var upd_lbl: Label
const UPD_FILE := "user://update.apk"
var upd_try := 0


# baixa o APK novo dentro do próprio jogo e abre a instalação do Android
func _update_download(url: String) -> void:
	if upd_req != null:
		upd_req.queue_free()
	upd_req = HTTPRequest.new()
	upd_req.download_file = UPD_FILE
	upd_req.max_redirects = 10
	upd_req.timeout = 600.0
	# sem pedir compactado: o GitHub dava erro 504 tentando compactar o APK inteiro na hora
	upd_req.accept_gzip = false
	upd_req.use_threads = true
	add_child(upd_req)
	upd_req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		var rq := upd_req
		upd_req = null
		if rq != null:
			rq.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			if upd_try < 3 and upd_lbl != null and is_instance_valid(upd_lbl):
				upd_try += 1
				upd_lbl.text = "O servidor demorou, tentando de novo (%d/3)..." % upd_try
				get_tree().create_timer(2.0).timeout.connect(func(): _update_download(url))
				return
			if upd_lbl != null and is_instance_valid(upd_lbl):
				upd_lbl.text = "Não consegui baixar (erro %d/%d). Toque em PELO NAVEGADOR." % [result, code]
			return
		if upd_bar != null and is_instance_valid(upd_bar):
			upd_bar.value = 100
		if upd_lbl != null and is_instance_valid(upd_lbl):
			upd_lbl.text = "Pronto! Abrindo a instalação..."
		var path := ProjectSettings.globalize_path(UPD_FILE)
		if OS.get_cmdline_user_args().has("--updtest"):
			print("UPDTEST baixou ", FileAccess.get_file_as_bytes(UPD_FILE).size(), " bytes em ", path)
			return
		OS.shell_open(path))
	var err := upd_req.request(url, PackedStringArray(["User-Agent: Sinucou/" + str(game.APP_VERSION), "Accept: */*"]))
	if err != OK:
		upd_lbl.text = "Não consegui começar o download. Tente PELO NAVEGADOR."
		return
	upd_bar.visible = true
	upd_bar.value = 0
	upd_lbl.text = "Baixando..."


# fim da partida com lobby: volta todo mundo para a tela do lobby
func back_to_lobby() -> void:
	game.net_game = str(lobby.get("game", "sinuca"))
	game.net_team = bool(lobby.get("four", true))
	online_mode = "world"
	_keep_search = true
	show_screen("online")
	_keep_search = false
	lobby_update(lobby.duplicate())


func _lobby_name(code: String) -> String:
	for o in lobby.get("members", []):
		if str(o.code) == code:
			return str(o.name)
	return "amigo"


func _lobby_paint() -> void:
	if lobby_row == null:
		return
	for ch in lobby_row.get_children():
		ch.queue_free()
	var lock: bool = in_lobby() and not lobby_leader()
	for d in [online_game_btns, team_btns, online_mode_btns]:
		for b in d.values():
			(b as Control).modulate = Color(1, 1, 1, 0.45) if lock else Color.WHITE
	if not in_lobby():
		var h := mk_lbl("Chame amigos para a sua mesa em  AMIGOS • LOBBY", 15, Color(1, 1, 1, 0.55), 2)
		lobby_row.add_child(h)
		return
	lobby_row.add_child(mk_lbl("LOBBY %s %s:" % ["TRUCO" if str(lobby.get("game", "")) == "truco" else "SINUCA", "2x2" if bool(lobby.get("four", true)) else "1x1"], 16, Color("ffe066"), 2))
	for o in lobby.members:
		var lead: bool = str(o.code) == str(lobby.leader)
		var me: bool = str(o.code) == game.my_code()
		var nm := str(o.name)
		if nm.length() > 12:
			nm = nm.substr(0, 11) + "…"
		var four_l: bool = bool(lobby.get("four", true))
		var my_t := 0
		for o2 in lobby.members:
			if str(o2.code) == game.my_code():
				my_t = int(o2.get("team", 0))
		var same: bool = int(o.get("team", 0)) == my_t
		var ccol: Color = (Color("1d5c9e") if same else Color("a83232")) if four_l else Color("16897f")
		var txt: String = ("♛ " if lead else "") + (nm + " (você)" if me else nm)
		if lobby_leader() and four_l and not lead:
			# o dono toca no nome para mudar o amigo de time
			var cb := mk_btn(txt + "  ⇄", 0, 36, ccol, 15)
			var oc := str(o.code)
			cb.pressed.connect(func(): game.net.world_send({"t": "lteam", "code": oc}))
			lobby_row.add_child(cb)
		else:
			var chip := PanelContainer.new()
			chip.add_theme_stylebox_override("panel", sbox(ccol, 14, Color("ffe066") if lead else Color(1, 1, 1, 0.3), 2, 0))
			chip.add_child(margin(mk_lbl(txt, 15, Color.WHITE, 2), 6))
			lobby_row.add_child(chip)
	if lobby_leader():
		var lv := mk_btn("SAIR", 90, 36, Color("7a2a2a"), 15)
		lv.pressed.connect(_lobby_leave)
		lobby_row.add_child(lv)


func _lobby_leave() -> void:
	if in_lobby():
		game.net.world_send({"t": "lleave"})
	lobby = {}
	game.net.pending_queue = ""
	game.net.queued = false
	_lobby_paint()
	_online_btn_refresh()
	online_status("Você saiu do lobby.")


func _lobby_locked() -> bool:
	if in_lobby() and not lobby_leader():
		say("No lobby, quem escolhe o jogo e a mesa é o líder (♛).")
		return true
	return false


# pinta os botões de jogo/mesa/conexão conforme o estado atual (sem iniciar busca)
func _online_paint_opts() -> void:
	if online_bg_truco != null:
		online_bg_truco.visible = game.net_game == "truco"
	_team_paint()
	for k in online_game_btns.keys():
		var b: Button = online_game_btns[k]
		var col: Color = (GREEN if k == "sinuca" else Color("b8323a")) if k == game.net_game else GRAY
		b.add_theme_stylebox_override("normal", sbox(col, 20, col.lightened(0.35), 3, 8))
	for k in online_mode_btns.keys():
		var b2: Button = online_mode_btns[k]
		var col2: Color = BLUE if k == online_mode else GRAY
		b2.add_theme_stylebox_override("normal", sbox(col2, 18, col2.lightened(0.35), 3, 6))
	if code_row != null:
		code_row.visible = online_mode == "lan"


func online_wait(have: int, need: int, left_ms: int) -> void:
	wait_have = have
	wait_need = need
	wait_left = float(left_ms) / 1000.0 if left_ms >= 0 else -1.0
	if need == 4:
		if wait_left >= 0.0:
			online_status("Achamos %d de 4 jogadores." % have)
		else:
			online_status("Esperando mais 1 jogador para começar (a IA completa o resto)...")


# mesa com os lugares: mostra quem já entrou e quanto falta para a IA completar
func _draw_seats() -> void:
	var r := Rect2(Vector2.ZERO, radar.size)
	var c := r.get_center() + Vector2(0, -6)
	var f: Font = ThemeDB.fallback_font
	var busy: bool = _online_busy() or game.net.active
	var four: bool = game.net_team
	var truco: bool = game.net_game == "truco"
	var tw := 330.0
	var th := 140.0
	var tr := Rect2(c - Vector2(tw, th) / 2.0, Vector2(tw, th))
	radar.draw_style_box(sbox(Color("5a3418"), 60), tr.grow(10))
	radar.draw_style_box(sbox(Color("8b0f22") if truco else Color("0e6b3a"), 54), tr)
	if busy:
		for k in 3:
			var ph := fposmod(fx_t * 0.5 + k / 3.0, 1.0)
			radar.draw_arc(c, 20.0 + ph * 120.0, 0, TAU, 48, Color(0.5, 0.9, 1.0, 0.45 * (1.0 - ph)), 2.0)
	var seats: Array = [c + Vector2(0, th / 2.0 + 30), c + Vector2(0, -th / 2.0 - 30)]
	if four:
		seats = [c + Vector2(0, th / 2.0 + 30), c + Vector2(tw / 2.0 + 34, 0), c + Vector2(0, -th / 2.0 - 30), c + Vector2(-tw / 2.0 - 34, 0)]
	var have: int = wait_have if (four and busy) else 1
	# quem está em cada lugar (visão: 0 = você embaixo, 2 = parceiro em cima)
	var vnames: Array = ["", "", "", ""]
	var vfill: Array = [true, false, false, false]
	var vfriend: Array = [false, false, false, false]
	if in_lobby():
		var ms: Array = lobby.members
		var mi := 0
		for k in ms.size():
			if str(ms[k].code) == game.my_code():
				mi = k
		# lugar de cada um: time do dono nos lugares 0 e 2, o outro time em 1 e 3
		var absd: Array = []
		var used := [0, 0]
		for k in ms.size():
			if four:
				var tm: int = int(ms[k].get("team", 0))
				absd.append([0, 2][mini(used[0], 1)] if tm == 0 else [1, 3][mini(used[1], 1)])
				used[tm] += 1
			else:
				absd.append(k % 2)
		for k in ms.size():
			var vs: int = (int(absd[k]) - int(absd[mi]) + 4) % 4 if four else (k - mi + 2) % 2
			if k != mi:
				vfill[vs] = true
				vfriend[vs] = true
				vnames[vs] = str(ms[k].name)
		var extra: int = maxi(0, have - ms.size()) if four else 0
		for vq in [1, 3, 2]:
			if extra > 0 and not vfill[vq]:
				vfill[vq] = true
				extra -= 1
	else:
		for k in range(1, 4):
			vfill[k] = four and k < have
	for i in seats.size():
		var p: Vector2 = seats[i]
		var filled: bool = bool(vfill[i]) or (game.net.active)
		var col: Color = Color("2f7fd6") if i % 2 == 0 else Color("c0392b")
		radar.draw_circle(p + Vector2(0, 3), 26, Color(0, 0, 0, 0.35))
		if filled:
			radar.draw_circle(p, 26, col)
			radar.draw_arc(p, 26, 0, TAU, 32, Color.WHITE, 3.0)
			radar.draw_circle(p + Vector2(0, -6), 8, Color.WHITE)
			radar.draw_colored_polygon(_arcpoly(p + Vector2(0, 16), 14), Color.WHITE)
		else:
			var pul := 0.5 + 0.5 * sin(fx_t * 4.0 + i)
			radar.draw_circle(p, 26, Color(0.1, 0.13, 0.18, 0.95))
			radar.draw_arc(p, 26, 0, TAU, 32, Color(1, 1, 1, 0.25 + 0.4 * pul), 2.5)
			radar.draw_string(f, p + Vector2(-26, 9), "?", HORIZONTAL_ALIGNMENT_CENTER, 52, 26, Color(1, 1, 1, 0.5 + 0.4 * pul))
		var lab := "VOCÊ" if i == 0 else ("JOGADOR" if filled else "...")
		if four and i == 2:
			lab = "PARCEIRO" if filled else "PARCEIRO?"
		if vfriend[i]:
			lab = str(vnames[i]).substr(0, 12).to_upper()
			radar.draw_arc(p, 31, 0, TAU, 36, Color("3ddc84"), 3.0)
		var lp2: Vector2 = p + Vector2(-60, -34)
		if i == 0:
			lp2 = p + Vector2(-60, 46)
		elif four and (i == 1 or i == 3):
			lp2 = p + Vector2(-60, 46)
		radar.draw_string(f, lp2, lab, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, 0.85))
	# centro: contagem da IA ou VS
	if four and busy and wait_left >= 0.0:
		var s := int(ceil(wait_left))
		radar.draw_circle(c, 40, Color(0, 0, 0, 0.55))
		radar.draw_arc(c, 40, -PI / 2.0, -PI / 2.0 + TAU * clampf(wait_left / 40.0, 0.0, 1.0), 40, Color("f4c542"), 5.0)
		radar.draw_string(f, c + Vector2(-40, 12), str(s), HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Color.WHITE)
		radar.draw_string(f, c + Vector2(-100, 60), "IA ENTRA EM %ds" % s, HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color("ffe066"))
	else:
		radar.draw_string_outline(f, c + Vector2(-60, 14), "VS", HORIZONTAL_ALIGNMENT_CENTER, 120, 40, 6, Color(0, 0, 0, 0.6))
		radar.draw_string(f, c + Vector2(-60, 14), "VS", HORIZONTAL_ALIGNMENT_CENTER, 120, 40, Color("f4c542"))


func _online_team(t: bool) -> void:
	if _lobby_locked():
		return
	if in_lobby() and not t and (lobby.members as Array).size() > 2:
		say("1 contra 1 só com 2 no lobby.")
		return
	game.net_team = t
	_team_paint()
	if cur == "online":
		if t and online_mode == "lan":
			_online_mode("world")
		else:
			_online_start()


func _team_paint() -> void:
	_seg_paint([team_btns[false], team_btns[true]], 1 if game.net_team else 0, [Color("e67e22")])


func _online_game(g: String) -> void:
	if _lobby_locked():
		return
	game.net_game = g
	if online_bg_truco != null:
		online_bg_truco.visible = g == "truco"
	for k in online_game_btns.keys():
		var b: Button = online_game_btns[k]
		var col: Color = (GREEN if k == "sinuca" else Color("b8323a")) if k == g else GRAY
		b.add_theme_stylebox_override("normal", sbox(col, 20, col.lightened(0.35), 3, 8))
	if cur == "online":
		_online_start()


func _online_mode(m: String) -> void:
	if m == "lan" and in_lobby():
		say("O lobby com amigos é só pela INTERNET.")
		m = "world"
	if m == "lan" and game.net_team:
		say("2 contra 2 é só pela INTERNET.")
		game.net_team = false
		_team_paint()
	online_mode = m
	for k in online_mode_btns.keys():
		var b: Button = online_mode_btns[k]
		var col: Color = BLUE if k == m else GRAY
		b.add_theme_stylebox_override("normal", sbox(col, 18, col.lightened(0.35), 3, 6))
	if code_row != null:
		code_row.visible = m == "lan"
	if cur == "online":
		_online_start()


func _online_start() -> void:
	if _keep_search:
		return
	if in_lobby():
		# no lobby nada procura sozinho: o líder escolhe e aperta PROCURAR ou JOGAR AGORA
		_online_btn_refresh()
		if not lobby_leader():
			return
		game.net.world_send({"t": "lset", "game": game.net_game, "four": game.net_team})
		return
	game.net.stop_search()
	game.net.world_cancel()
	if game.net.active:
		game.net.close()
	online_code.text = ""
	if online_mode == "world":
		game.net.world_search(game.net_game)
	else:
		game.net.start_search()
	_online_btn_refresh()


func _online_busy() -> bool:
	if in_lobby():
		return bool(lobby.get("searching", false))
	return game.net.searching or game.net.pending_queue != ""


func _online_toggle_search() -> void:
	if in_lobby() and not lobby_leader():
		_lobby_leave()
		return
	if in_lobby() and not game.net_team:
		game.net.world_send({"t": "lstart"})
		online_status("Começando o 1x1...")
		return
	if in_lobby():
		if _online_busy():
			game.net.world_send({"t": "unqueue"})
		else:
			game.net.world_send({"t": "queue", "game": game.net_game + "4"})
		return
	if _online_busy():
		game.net.stop_search()
		game.net.world_cancel()
		game.net.close()
		online_status("Busca cancelada.")
	else:
		_online_start()
	_online_btn_refresh()


func _online_btn_refresh() -> void:
	if search_btn == null:
		return
	if start_btn != null:
		var lead4: bool = lobby_leader() and game.net_team
		start_btn.visible = lead4
		var nm: int = (lobby.get("members", []) as Array).size()
		start_btn.disabled = nm < 2
		start_btn.text = "JOGAR AGORA  ▶" if nm >= 2 else "CHAME 1 AMIGO"
	if lobby_btn != null:
		lobby_btn.visible = not in_lobby()
	if in_lobby() and not lobby_leader():
		search_btn.text = "SAIR DO LOBBY"
		search_btn.add_theme_stylebox_override("normal", sbox(GRAY, 20, GRAY.lightened(0.35), 3, 8))
		return
	if in_lobby() and not game.net_team:
		search_btn.text = "JOGAR 1x1"
		search_btn.add_theme_stylebox_override("normal", sbox(GREEN, 20, GREEN.lightened(0.35), 3, 8))
		return
	if in_lobby() and not _online_busy():
		search_btn.text = "PROCURAR ADVERSÁRIOS"
		search_btn.add_theme_stylebox_override("normal", sbox(GREEN, 20, GREEN.lightened(0.35), 3, 8))
		return
	if _online_busy():
		search_btn.text = "CANCELAR BUSCA"
		search_btn.add_theme_stylebox_override("normal", sbox(RED, 20, RED.lightened(0.35), 3, 8))
	else:
		search_btn.text = "PROCURAR OPONENTE"
		search_btn.add_theme_stylebox_override("normal", sbox(GREEN, 20, GREEN.lightened(0.35), 3, 8))


func _online_reset() -> void:
	if _keep_search:
		_online_paint_opts()
		_lobby_paint()
		return
	wait_have = 1
	wait_left = -1.0
	if online_bg_truco != null:
		online_bg_truco.visible = game.net_game == "truco"
	_team_paint()
	for k in online_game_btns.keys():
		var b: Button = online_game_btns[k]
		var col: Color = (GREEN if k == "sinuca" else Color("b8323a")) if k == game.net_game else GRAY
		b.add_theme_stylebox_override("normal", sbox(col, 20, col.lightened(0.35), 3, 8))
	_online_mode(online_mode)
	_online_start()


func online_status(t: String) -> void:
	if online_lbl != null:
		online_lbl.text = t


func _online_host() -> void:
	if not game.net.start_host():
		_online_btn_refresh()
		online_status("Não consegui criar a sala. Tente de novo.")
		return
	var ip: String = game.net.local_ip()
	var code: String = game.net.code_for_ip(ip)
	if ip == "":
		online_code.text = "sem Wi-Fi"
		online_status("Não encontrei sua rede. Conecte ao Wi-Fi e tente de novo.")
	elif code != "":
		online_code.text = code
		online_status("Sala criada! Passe o código %s ao amigo (ou o IP %s). Aguardando o adversário..." % [code, ip])
	else:
		online_code.text = ip
		online_status("Sala criada! Passe o IP %s ao amigo. Aguardando o adversário..." % ip)


func _online_join() -> void:
	var addr: String = game.net.ip_for_code(online_edit.text)
	if addr == "":
		online_status("Digite o código da sala (números) ou o IP do amigo.")
		return
	if game.net.start_join(addr):
		_online_btn_refresh()
		online_status("Conectando em %s ..." % addr)
	else:
		online_status("Endereço inválido.")


func _online_back() -> void:
	if in_lobby():
		_lobby_leave()
	game.net.stop_search()
	game.net.world_cancel()
	if game.net != null and game.net.active:
		game.net.close()
	show_screen(online_from)


# ---------------------------------------------------------------- amigos
func _build_amigos() -> void:
	var v := mk_screen("amigos", 10)
	add_bg("amigos", "res://assets/menu_bg.jpg", 0.25)
	var hd := Control.new()
	hd.custom_minimum_size = Vector2(700, 60)
	hd.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		hd.draw_string_outline(f, Vector2(0, 48), "AMIGOS", HORIZONTAL_ALIGNMENT_CENTER, hd.size.x, 50, 10, Color("3a2402"))
		hd.draw_string(f, Vector2(0, 48), "AMIGOS", HORIZONTAL_ALIGNMENT_CENTER, hd.size.x, 50, Color("f7c33a")))
	v.add_child(hd)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(body)
	# ---- coluna esquerda: seu código e adicionar amigo
	var lp := PanelContainer.new()
	lp.custom_minimum_size = Vector2(360, 470)
	lp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.88), 26, Color(1, 1, 1, 0.18), 2, 12))
	body.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lp.add_child(margin(lv, 18))
	lv.add_child(_section("SEU CÓDIGO"))
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", sbox(Color(0.12, 0.09, 0.02, 0.9), 18, Color("f4c542"), 2, 6))
	lv.add_child(cp)
	var cl := mk_lbl("", 30, Color("ffe066"), 3)
	cl.name = "MyCode"
	cp.add_child(margin(cl, 10))
	lv.add_child(mk_lbl("Mande esse código para seus amigos te acharem.", 15, Color(1, 1, 1, 0.6), 2))
	lv.add_child(_section("ADICIONAR AMIGO"))
	friend_edit = LineEdit.new()
	friend_edit.placeholder_text = "nome ou código"
	friend_edit.max_length = 16
	friend_edit.custom_minimum_size = Vector2(320, 56)
	friend_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	friend_edit.add_theme_font_size_override("font_size", 24)
	friend_edit.add_theme_stylebox_override("normal", sbox(Color(0.02, 0.05, 0.09, 0.95), 14, Color(1, 1, 1, 0.35), 2, 0))
	friend_edit.add_theme_stylebox_override("focus", sbox(Color(0.02, 0.05, 0.09, 0.95), 14, Color("5aa9ff"), 3, 0))
	lv.add_child(friend_edit)
	friend_edit.text_submitted.connect(func(_t): _friend_search())
	var sb := mk_btn("BUSCAR PELO NOME", 320, 54, BLUE, 20)
	sb.pressed.connect(_friend_search)
	lv.add_child(sb)
	var ab := mk_btn("PEDIR PELO CÓDIGO", 320, 54, GREEN, 20)
	ab.pressed.connect(_friend_add)
	lv.add_child(ab)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp)
	var back := mk_btn("◀  VOLTAR", 320, 56, GRAY, 24)
	back.pressed.connect(func(): show_screen("online" if _came_from_online else "main"))
	lv.add_child(back)
	# ---- coluna direita: resultados da busca + lista de amigos (rola com o dedo)
	var rp := PanelContainer.new()
	rp.custom_minimum_size = Vector2(780, 470)
	rp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.88), 26, Color(1, 1, 1, 0.18), 2, 12))
	body.add_child(rp)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	rp.add_child(margin(sc, 14))
	friends_scroll = sc
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	search_box = VBoxContainer.new()
	search_box.add_theme_constant_override("separation", 6)
	inner.add_child(search_box)
	friends_box = VBoxContainer.new()
	friends_box.add_theme_constant_override("separation", 8)
	friends_box.custom_minimum_size = Vector2(740, 0)
	inner.add_child(friends_box)
	# convite (aparece por cima de qualquer tela)
	invite_panel = PanelContainer.new()
	invite_panel.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.09, 0.96), 24, Color("f4c542"), 3, 16))
	invite_panel.visible = false
	root.add_child(invite_panel)
	invite_box = VBoxContainer.new()
	invite_box.add_theme_constant_override("separation", 12)
	invite_panel.add_child(margin(invite_box, 20))


var _came_from_online := false
var cur_prev := ""


func _amigos_open() -> void:
	var cl: Label = screens["amigos"].find_child("MyCode", true, false)
	if cl != null:
		cl.text = game.my_code()
	game.net.connect_server()
	_friends_render([])
	if search_box != null:
		for ch in search_box.get_children():
			ch.queue_free()
	friends_refresh()


func _friend_search() -> void:
	var q := friend_edit.text.strip_edges()
	if q.length() < 2:
		say("Digite pelo menos 2 letras do nome.")
		return
	if not game.net.server_ok:
		game.net.connect_server()
		say("Conectando ao servidor... tente de novo em alguns segundos.")
		return
	game.net.world_send({"t": "search", "q": q})


func search_results(q: String, list: Array) -> void:
	if search_box == null:
		return
	for c in search_box.get_children():
		c.queue_free()
	if list.is_empty():
		search_box.add_child(mk_lbl("Ninguém encontrado com o nome \"%s\". O amigo precisa ter aberto o jogo pelo menos uma vez (ou use o código dele)." % q, 16, Color(1, 1, 1, 0.7), 2))
		return
	search_box.add_child(mk_lbl("Jogadores encontrados:", 15, Color("f4c542"), 2))
	for p in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		search_box.add_child(row)
		var pon: bool = bool(p.get("online", false))
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(20, 30)
		var dcol: Color = Color("3ddc84") if pon else Color(0.5, 0.5, 0.55)
		dot.draw.connect(func(): dot.draw_circle(Vector2(10, 15), 7, dcol))
		row.add_child(dot)
		var nl := mk_lbl("%s   (%s)  •  %s" % [str(p.name), str(p.code), "ONLINE" if pon else "offline"], 20, Color.WHITE if pon else Color(1, 1, 1, 0.75), 2)
		nl.custom_minimum_size = Vector2(420, 0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(nl)
		var already := _has("friends", str(p.code))
		var sent := _has("f_out", str(p.code))
		var b := mk_btn("JÁ É AMIGO" if already else ("PEDIDO ENVIADO" if sent else "PEDIR AMIZADE"), 200, 46, GRAY if (already or sent) else GREEN, 17)
		b.disabled = already or sent
		b.pressed.connect(_friend_add_code.bind(str(p.code), str(p.name)))
		row.add_child(b)


func _friend_add_code(c: String, nm: String) -> void:
	_friend_request(c, nm)
	for ch in search_box.get_children():
		ch.queue_free()
	friend_edit.text = ""
	friends_refresh()


func _friend_add() -> void:
	var c := friend_edit.text.strip_edges().to_upper()
	if c.length() < 4:
		say("Digite o código do seu amigo.")
		return
	_friend_request(c, "")
	friend_edit.text = ""


func _has(list_key: String, c: String) -> bool:
	for f in game.save.get(list_key, []):
		if str(f.code) == c:
			return true
	return false


func _drop(list_key: String, c: String) -> void:
	var l: Array = game.save.get(list_key, [])
	for i in range(l.size() - 1, -1, -1):
		if str(l[i].code) == c:
			l.remove_at(i)


func _friend_request(c: String, nm: String) -> void:
	if c == game.my_code():
		say("Esse é o seu código!")
		return
	if _has("friends", c):
		say("Vocês já são amigos.")
		return
	if _has("f_in", c):
		_friend_accept(c, nm)
		return
	if _has("f_out", c):
		say("Pedido já enviado. Esperando aceitar.")
		return
	game.save.f_out.append({"code": c, "name": nm if nm != "" else c})
	var dl: Array = game.save.f_dec
	dl.erase(c)
	game.write_save()
	game.net.connect_server()
	game.net.world_send({"t": "fsend", "kind": "req", "to": c})
	say("Pedido de amizade enviado!")
	friends_refresh()


func friend_sent_offline(_c: String) -> void:
	pass


func _friend_accept(c: String, nm: String) -> void:
	var nm2 := nm
	for f in game.save.f_in:
		if str(f.code) == c:
			nm2 = str(f.name)
	_drop("f_in", c)
	_drop("f_out", c)
	if not _has("friends", c):
		game.save.friends.append({"code": c, "name": nm2 if nm2 != "" else c})
	game.write_save()
	game.net.world_send({"t": "fsend", "kind": "acc", "to": c})
	say("Agora vocês são amigos!")
	refresh_top()
	friends_refresh()


func _friend_decline(c: String) -> void:
	_drop("f_in", c)
	var dl: Array = game.save.f_dec
	if not dl.has(c):
		dl.append(c)
	game.write_save()
	game.net.world_send({"t": "fsend", "kind": "dec", "to": c})
	refresh_top()
	friends_refresh()


func _friend_cancel(c: String) -> void:
	_drop("f_out", c)
	game.write_save()
	friends_refresh()


# mensagens de amizade vindas de outro jogador
# ---------------------------------------------------------------- conversa com amigos
const PM_QUICK := ["Bora jogar?", "Entra no lobby!", "Já vou!", "Agora não dá", "Kkkkkk", "Boa partida!"]
var pm_code := ""
var pm_name := ""
var pm_list: VBoxContainer
var pm_scroll: ScrollContainer
var pm_edit: LineEdit


func unread_total() -> int:
	var tot := 0
	for k in game.save.get("chat_unread", {}).keys():
		tot += int(game.save.chat_unread[k])
	return tot


func _pm_store(code: String, me: bool, txt: String, ts: int) -> void:
	if not game.save.has("chats"):
		game.save.chats = {}
	var arr: Array = game.save.chats.get(code, [])
	arr.append({"me": me, "txt": txt, "ts": ts})
	while arr.size() > 60:
		arr.pop_front()
	game.save.chats[code] = arr


func got_pm(code: String, nm: String, txt: String, ts: int) -> void:
	_pm_store(code, false, txt, ts)
	if pm_code == code and has_modal():
		_pm_render()
	else:
		if not game.save.has("chat_unread"):
			game.save.chat_unread = {}
		game.save.chat_unread[code] = int(game.save.chat_unread.get(code, 0)) + 1
		say("Mensagem de %s: %s" % [nm, txt])
		if cur == "amigos":
			friends_refresh()
	game.write_save()
	refresh_top()


func open_pm(code: String, nm: String) -> void:
	close_modal()
	pm_code = code
	pm_name = nm
	if game.save.has("chat_unread"):
		game.save.chat_unread.erase(code)
		game.write_save()
		refresh_top()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.6)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.05, 0.1, 0.97), 26, Color("2f7fd6"), 3, 20))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(margin(vb, 18))
	var hr := HBoxContainer.new()
	vb.add_child(hr)
	var tl := mk_lbl("Conversa com " + nm, 28, Color("f4c542"), 4)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hr.add_child(tl)
	var xb := mk_btn("FECHAR", 130, 48, GRAY, 18)
	xb.pressed.connect(func():
		pm_code = ""
		close_modal()
		if cur == "amigos":
			friends_refresh())
	hr.add_child(xb)
	pm_scroll = ScrollContainer.new()
	pm_scroll.custom_minimum_size = Vector2(760, 300)
	pm_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pm_scroll.add_theme_stylebox_override("panel", sbox(Color(0, 0, 0, 0.3), 16))
	vb.add_child(pm_scroll)
	pm_list = VBoxContainer.new()
	pm_list.add_theme_constant_override("separation", 6)
	pm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pm_scroll.add_child(pm_list)
	var qr := HBoxContainer.new()
	qr.add_theme_constant_override("separation", 6)
	vb.add_child(qr)
	for q in PM_QUICK:
		var qb := mk_btn(q, 0, 40, Color("24304a"), 15)
		qb.pressed.connect(func(): _pm_send(q))
		qr.add_child(qb)
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 8)
	vb.add_child(er)
	pm_edit = LineEdit.new()
	pm_edit.placeholder_text = "escreva uma mensagem..."
	pm_edit.max_length = 120
	pm_edit.custom_minimum_size = Vector2(620, 52)
	pm_edit.add_theme_font_size_override("font_size", 20)
	pm_edit.text_submitted.connect(func(_t): _pm_send(pm_edit.text))
	er.add_child(pm_edit)
	var sb := mk_btn("ENVIAR", 130, 52, GREEN, 20)
	sb.pressed.connect(func(): _pm_send(pm_edit.text))
	er.add_child(sb)
	_pm_render()


func _pm_send(txt: String) -> void:
	txt = txt.strip_edges().left(120)
	if txt == "" or pm_code == "":
		return
	if not game.net.server_ok:
		say("Sem conexão com o servidor agora.")
		return
	game.net.world_send({"t": "pm", "to": pm_code, "txt": txt})
	_pm_store(pm_code, true, txt, int(Time.get_unix_time_from_system() * 1000))
	game.write_save()
	if pm_edit != null and is_instance_valid(pm_edit):
		pm_edit.text = ""
	_pm_render()


func _pm_render() -> void:
	if pm_list == null or not is_instance_valid(pm_list):
		return
	for ch in pm_list.get_children():
		ch.queue_free()
	var arr: Array = game.save.get("chats", {}).get(pm_code, [])
	if arr.is_empty():
		pm_list.add_child(mk_lbl("Nenhuma mensagem ainda. Mande um oi!", 18, Color(1, 1, 1, 0.5), 2))
	for msg in arr:
		var me: bool = bool(msg.me)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if me else BoxContainer.ALIGNMENT_BEGIN
		pm_list.add_child(row)
		var bub := PanelContainer.new()
		bub.add_theme_stylebox_override("panel", sbox(Color("1d6b45") if me else Color("2a3346"), 14))
		var l := mk_lbl(str(msg.txt), 19, Color.WHITE, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(minf(520.0, 30.0 + str(msg.txt).length() * 11.0), 0)
		bub.add_child(margin(l, 8))
		row.add_child(bub)
	await get_tree().process_frame
	if pm_scroll != null and is_instance_valid(pm_scroll):
		pm_scroll.scroll_vertical = 100000


func friend_msg(kind: String, c: String, nm: String) -> void:
	match kind:
		"req":
			if _has("friends", c):
				game.net.world_send({"t": "fsend", "kind": "acc", "to": c})
				return
			if game.save.f_dec.has(c):
				game.net.world_send({"t": "fsend", "kind": "dec", "to": c})
				return
			if _has("f_out", c):
				# os dois pediram ao mesmo tempo: vira amizade
				_friend_accept(c, nm)
				return
			if not _has("f_in", c):
				game.save.f_in.append({"code": c, "name": nm})
				game.write_save()
				say("%s te mandou um pedido de amizade!" % nm)
		"acc":
			var was := _has("f_out", c)
			_drop("f_out", c)
			if not _has("friends", c):
				game.save.friends.append({"code": c, "name": nm})
				if was:
					say("%s aceitou seu pedido de amizade!" % nm)
			game.write_save()
		"dec":
			_drop("f_out", c)
			game.write_save()
		"rem":
			_drop("friends", c)
			_drop("f_out", c)
			game.write_save()
	refresh_top()
	friends_refresh()


func _friend_remove(c: String) -> void:
	_drop("friends", c)
	game.write_save()
	game.net.world_send({"t": "fsend", "kind": "rem", "to": c})
	friends_refresh()


func friends_refresh() -> void:
	var codes := []
	for f in game.save.friends:
		codes.append(str(f.code))
	if codes.is_empty():
		_friends_render([])
		return
	if game.net.server_ok:
		game.net.world_send({"t": "friends", "codes": codes})
	else:
		_friends_render([])


func friends_offline() -> void:
	friends_online = 0
	_friends_badge()
	if cur == "amigos":
		_friends_render([])


func friends_update(list: Array) -> void:
	var fl: Array = game.save.friends
	var changed := false
	for p in list:
		if bool(p.get("online", false)):
			for f in fl:
				if str(f.code) == str(p.code) and str(f.name) != str(p.name):
					f.name = str(p.name)
					changed = true
	if changed:
		game.write_save()
	var on := 0
	for p in list:
		if bool(p.get("online", false)):
			on += 1
	friends_online = on
	_friends_badge()
	if cur == "amigos":
		_friends_render(list)


func _friends_render(list: Array) -> void:
	if friends_box == null:
		return
	for c in friends_box.get_children():
		c.queue_free()
	var st := {}
	for p in list:
		st[str(p.code)] = p
	var fin: Array = game.save.get("f_in", [])
	if not fin.is_empty():
		friends_box.add_child(mk_lbl("PEDIDOS DE AMIZADE RECEBIDOS", 17, Color("f4c542"), 2))
		for q in fin:
			var rq := PanelContainer.new()
			rq.add_theme_stylebox_override("panel", sbox(Color(0.12, 0.09, 0.02, 0.92), 18, Color("f4c542"), 2, 4))
			friends_box.add_child(rq)
			var qh := HBoxContainer.new()
			qh.add_theme_constant_override("separation", 12)
			rq.add_child(margin(qh, 10))
			var ql := mk_lbl("%s  (%s) quer ser seu amigo" % [str(q.name), str(q.code)], 20, Color.WHITE, 2)
			ql.custom_minimum_size = Vector2(500, 0)
			ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			qh.add_child(ql)
			var qa := mk_btn("ACEITAR", 150, 46, GREEN, 18)
			qa.pressed.connect(_friend_accept.bind(str(q.code), str(q.name)))
			qh.add_child(qa)
			var qr := mk_btn("RECUSAR", 150, 46, GRAY, 18)
			qr.pressed.connect(_friend_decline.bind(str(q.code)))
			qh.add_child(qr)
	var fout: Array = game.save.get("f_out", [])
	var fl: Array = game.save.friends
	if fl.is_empty() and fout.is_empty() and fin.is_empty():
		friends_box.add_child(mk_lbl("Você ainda não tem amigos na lista.\nBusque o amigo pelo nome (ele precisa estar online) ou peça pelo código dele.", 20, Color(1, 1, 1, 0.75), 3))
		return
	if not game.net.server_ok:
		friends_box.add_child(mk_lbl("Conectando ao servidor para ver quem está online...", 18, Color(1, 1, 1, 0.6), 2))
	var on_list := []
	var off_list := []
	for f in fl:
		var p: Dictionary = st.get(str(f.code), {})
		if bool(p.get("online", false)):
			on_list.append([f, p])
		else:
			off_list.append([f, p])
	if not on_list.is_empty():
		friends_box.add_child(_flist_head("ONLINE  •  %d" % on_list.size(), Color("3ddc84")))
	for k in on_list.size() + off_list.size():
		if k == on_list.size() and not off_list.is_empty():
			friends_box.add_child(_flist_head("OFFLINE  •  %d" % off_list.size(), Color(1, 1, 1, 0.5)))
		var pair: Array = on_list[k] if k < on_list.size() else off_list[k - on_list.size()]
		var f: Dictionary = pair[0]
		var p: Dictionary = pair[1]
		var online := bool(p.get("online", false))
		var status := str(p.get("status", "offline")) if online else "offline"
		var dc := Color("3ddc84") if online else Color(0.5, 0.5, 0.55)
		if status == "jogando":
			dc = Color("ffb020")
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", sbox(Color(0.05, 0.09, 0.15, 0.95) if online else Color(0.03, 0.05, 0.08, 0.85), 18, dc if online else Color(1, 1, 1, 0.1), 2, 4))
		friends_box.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(margin(hb, 8))
		# avatar com a inicial e a bolinha de status
		var av := Control.new()
		av.custom_minimum_size = Vector2(52, 52)
		var nm := str(f.name)
		var hue := float(hash(str(f.code)) % 360) / 360.0
		var acol := Color.from_hsv(hue, 0.55, 0.75 if online else 0.4)
		av.draw.connect(func():
			av.draw_circle(Vector2(26, 26), 24, acol)
			av.draw_arc(Vector2(26, 26), 24, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
			var fnt: Font = ThemeDB.fallback_font
			av.draw_string(fnt, Vector2(0, 36), nm.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 52, 28, Color.WHITE)
			av.draw_circle(Vector2(44, 44), 8, Color(0.03, 0.05, 0.08))
			av.draw_circle(Vector2(44, 44), 6, dc))
		hb.add_child(av)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", -2)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_child(nv)
		var nl := mk_lbl(nm, 22, Color.WHITE if online else Color(1, 1, 1, 0.7), 2)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nv.add_child(nl)
		var sl := mk_lbl("%s  •  %s" % [{"online": "ONLINE", "procurando": "PROCURANDO PARTIDA", "jogando": "JOGANDO AGORA"}.get(status, "OFFLINE"), str(f.code)], 14, dc)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nv.add_child(sl)
		var can := online and status != "jogando"
		if can:
			for g in [["sinuca", "x1 SINUCA", GREEN], ["truco", "x1 TRUCO", Color("b8323a")]]:
				var ib := mk_btn(g[1], 118, 46, g[2], 15)
				ib.pressed.connect(_invite.bind(str(f.code), g[0], false))
				hb.add_child(ib)
			var inl := false
			for o in lobby.get("members", []):
				if str(o.code) == str(f.code):
					inl = true
			var lb := mk_btn("NO LOBBY ✓" if inl else "LOBBY +", 118, 46, GRAY if inl else Color("8e44ad"), 15)
			lb.disabled = inl
			lb.pressed.connect(_invite.bind(str(f.code), "", true))
			hb.add_child(lb)
		elif status == "jogando":
			hb.add_child(mk_lbl("em partida...", 15, Color("ffb020"), 2))
		# conversa (funciona até com o amigo offline: ele recebe quando entrar)
		var un: int = int(game.save.get("chat_unread", {}).get(str(f.code), 0))
		var mb := mk_btn("MSG" + (" (%d)" % un if un > 0 else ""), 86 if un == 0 else 104, 46, Color("e67e22") if un > 0 else Color("2f7fd6"), 15)
		var fc2 := str(f.code)
		var fn2 := nm
		mb.pressed.connect(func(): open_pm(fc2, fn2))
		hb.add_child(mb)
		var rb := mk_btn("✕", 46, 46, Color("4a2228"), 18)
		var fcode := str(f.code)
		rb.pressed.connect(func(): confirm("REMOVER AMIGO?", "Tirar %s da sua lista de amigos?" % nm, "REMOVER", _friend_remove.bind(fcode), "CANCELAR", func(): pass))
		hb.add_child(rb)
	if not fout.is_empty():
		friends_box.add_child(mk_lbl("PEDIDOS ENVIADOS (esperando aceitar)", 15, Color(1, 1, 1, 0.6), 2))
		for o in fout:
			var oh := HBoxContainer.new()
			oh.add_theme_constant_override("separation", 12)
			oh.alignment = BoxContainer.ALIGNMENT_CENTER
			friends_box.add_child(oh)
			var ol := mk_lbl("%s  (%s)" % [str(o.name), str(o.code)], 18, Color(1, 1, 1, 0.75), 2)
			ol.custom_minimum_size = Vector2(500, 0)
			ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			oh.add_child(ol)
			var oc := mk_btn("CANCELAR", 150, 42, GRAY, 16)
			oc.pressed.connect(_friend_cancel.bind(str(o.code)))
			oh.add_child(oc)


func _flist_head(t: String, col: Color) -> Label:
	var l := mk_lbl(t, 15, col, 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _invite(code: String, g: String, to_lobby: bool) -> void:
	if to_lobby and not in_lobby():
		lobby_create_ask(code)
		return
	if to_lobby:
		g = game.net_game
	else:
		game.net_game = g
	game.net.world_send({"t": "invite", "code": code, "game": g, "lobby": to_lobby})
	say("Enviando convite...")


func show_invite(from: String, nm: String, g: String, to_lobby := false) -> void:
	for c in invite_box.get_children():
		c.queue_free()
	invite_box.add_child(mk_lbl("CONVITE!", 34, Color("f4c542"), 6))
	if to_lobby:
		invite_box.add_child(mk_lbl("%s te chamou para o LOBBY de %s" % [nm, "TRUCO" if g == "truco" else "SINUCA"], 22, Color.WHITE, 3))
		invite_box.add_child(mk_lbl("Vocês procuram mesa juntos, no mesmo time (2 contra 2).", 17, Color(1, 1, 1, 0.75), 2))
	else:
		invite_box.add_child(mk_lbl("%s te chamou para um x1 de %s" % [nm, "TRUCO" if g == "truco" else "SINUCA"], 22, Color.WHITE, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	invite_box.add_child(row)
	var ac := mk_btn("ACEITAR", 180, 60, GREEN, 24)
	ac.pressed.connect(func():
		invite_panel.visible = false
		if truco_node != null and is_instance_valid(truco_node):
			say("Termine a partida atual antes.")
			return
		game.net_game = g
		game.net.world_send({"t": "accept", "from": from, "game": g, "lobby": to_lobby}))
	row.add_child(ac)
	var rc := mk_btn("RECUSAR", 180, 60, GRAY, 24)
	rc.pressed.connect(func():
		invite_panel.visible = false
		game.net.world_send({"t": "decline", "from": from}))
	row.add_child(rc)
	if to_lobby and OS.get_cmdline_user_args().has("--autolobby"):
		get_tree().create_timer(1.0).timeout.connect(func(): ac.pressed.emit())
	invite_panel.visible = true
	invite_panel.reset_size()
	await get_tree().process_frame
	invite_panel.position = (root.size - invite_panel.size) / 2.0
	root.move_child(invite_panel, root.get_child_count() - 1)


func _build_truco_menu() -> void:
	var v := mk_screen("truco", 14)
	var scr: Control = screens["truco"]
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mesa: Texture2D = load("res://cards/mesa.jpg")
	var faces := [load("res://cards/face_6_2.png"), load("res://cards/face_4_1.png"), load("res://cards/face_5_0.png"), load("res://cards/face_6_3.png"), load("res://cards/face_4_2.png"), load("res://cards/face_5_3.png")]
	var bgf := func():
		var w := bg.size.x
		var h := bg.size.y
		bg.draw_texture_rect(mesa, Rect2(0, 0, w, h), false)
		bg.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.25))
		for side in [-1, 1]:
			for k in 3:
				var ang: float = (float(k) - 1.0) * 0.26 + side * 0.18
				var base: Vector2 = Vector2(w / 2.0 + side * (w / 2.0 - 165.0), h - 30.0)
				bg.draw_set_transform(base, ang, Vector2.ONE)
				var cr := Rect2(-62, -250, 124, 178)
				bg.draw_style_box(sbox(Color(0, 0, 0, 0.35), 12), Rect2(cr.position + Vector2(4, 6), cr.size))
				bg.draw_style_box(sbox(Color("fbfaf4"), 12, Color(0.2, 0.2, 0.2, 0.6), 1), cr)
				var tx: Texture2D = faces[k + (0 if side < 0 else 3)]
				bg.draw_texture_rect(tx, Rect2(cr.position.x + 12, cr.position.y + 8, cr.size.x - 24, cr.size.y - 16), false)
		bg.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	bg.draw.connect(bgf)
	scr.add_child(bg)
	scr.move_child(bg, 0)
	v.add_child(mk_lbl("TRUCO PAULISTA", 52, Color("f4c542"), 10))
	v.add_child(mk_lbl("◆   CONTRA A IA GOSCRIPTS   ◆", 18, Color(1, 1, 1, 0.7), 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var c1 := mode_card("1 CONTRA 1", "Você contra a IA", "tr1", Color("b8323a"), "VITÓRIA +50")
	c1.pressed.connect(open_truco.bind(2))
	var c2 := mode_card("2 CONTRA 2", "Você e um parceiro IA", "tr2", BLUE, "VITÓRIA +70")
	c2.pressed.connect(open_truco.bind(4))
	row.add_child(c1)
	row.add_child(c2)
	var ob := mk_btn("JOGAR ONLINE  •  1x1 OU 2x2", 560, 56, BLUE, 22)
	ob.pressed.connect(func():
		game.net_game = "truco"
		online_from = "truco"
		show_screen("online"))
	v.add_child(ob)
	var rl := mk_lbl("Manilhas: a carta seguinte à vira  •  Zap > Copas > Espada > Ouros\nTRUCO 3 → SEIS → NOVE → DOZE  •  Jogo até 12 tentos  •  Mão de 11 e mão de ferro", 16, Color(1, 1, 1, 0.75), 3)
	v.add_child(rl)
	var back := mk_btn("◀  VOLTAR", 240, 58, GRAY, 26)
	back.pressed.connect(show_screen.bind("main"))
	v.add_child(back)


func open_truco(players: int) -> void:
	show_screen("")
	dim.visible = false
	game.paused = true
	if truco_node != null and is_instance_valid(truco_node):
		truco_node.queue_free()
	truco_node = load("res://truco.gd").new()
	root.add_child(truco_node)
	root.move_child(truco_node, root.get_child_count() - 1)
	truco_node.setup(game, players)


func open_truco_net(role: String, info) -> void:
	if not (info is Dictionary):
		info = {"names": [game.my_name(), str(info)], "peers": {1: 2}} if role == "host" else {}
	show_screen("")
	dim.visible = false
	game.paused = true
	if truco_node != null and is_instance_valid(truco_node):
		truco_node.queue_free()
	truco_node = load("res://truco.gd").new()
	root.add_child(truco_node)
	root.move_child(truco_node, root.get_child_count() - 1)
	var np := 2
	if info is Dictionary and info.has("names"):
		np = info.names.size()
	truco_node.setup(game, np, false, role, info)


func close_truco() -> void:
	if truco_node != null and is_instance_valid(truco_node):
		truco_node.queue_free()
	truco_node = null
	game.paused = false
	if in_lobby():
		back_to_lobby()
	else:
		show_screen("truco")


func _set_diff(i: int) -> void:
	diff_sel = i
	var cols := [GREEN, GOLD, RED]
	var descs := ["Erra mais  •  vitória +50", "Equilibrada  •  vitória +75", "Precisa e com efeito  •  vitória +100"]
	for k in diff_btns.size():
		var b: Button = diff_btns[k]
		var col: Color = cols[k] if k == i else Color(0.13, 0.17, 0.24)
		var bc: Color = Color.WHITE if k == i else Color(1, 1, 1, 0.2)
		b.add_theme_stylebox_override("normal", sbox(col, 20, bc, 3 if k == i else 2, 8 if k == i else 0))
		b.add_theme_stylebox_override("hover", sbox(col.lightened(0.12), 20, Color.WHITE, 3, 8))
	if diff_desc != null:
		diff_desc.text = descs[i]


func _start(m: int) -> void:
	show_screen("")
	game.start_game(m, diff_sel)


# ---------------------------------------------------------------- roleta diária
func _build_roleta() -> void:
	var v := mk_screen("roleta", 10)
	v.add_child(mk_lbl("ROLETA DIÁRIA", 50, Color("f4c542"), 10))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(440, 440)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(holder)
	wheel = Control.new()
	wheel.size = Vector2(420, 420)
	wheel.position = Vector2(10, 18)
	wheel.pivot_offset = Vector2(210, 210)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel.draw.connect(_draw_wheel)
	holder.add_child(wheel)
	var ptr := Control.new()
	ptr.set_anchors_preset(Control.PRESET_FULL_RECT)
	ptr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pf := func():
		var c := Vector2(220, 18)
		ptr.draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -14), c + Vector2(20, -14), c + Vector2(0, 26)]), Color("c0392b"))
		ptr.draw_polyline(PackedVector2Array([c + Vector2(-20, -14), c + Vector2(20, -14), c + Vector2(0, 26), c + Vector2(-20, -14)]), Color.WHITE, 3.0)
		var hc := Vector2(220, 228)
		ptr.draw_circle(hc, 44, Color("1b1e2b"))
		ptr.draw_arc(hc, 44, 0, TAU, 40, Color("f4c542"), 4.0)
		ptr.draw_string(ThemeDB.fallback_font, hc + Vector2(-44, 9), "GIRE", HORIZONTAL_ALIGNMENT_CENTER, 88, 24, Color("f4c542"))
	ptr.draw.connect(pf)
	holder.add_child(ptr)
	spin_lbl = mk_lbl("", 20, Color(1, 1, 1, 0.85), 3)
	v.add_child(spin_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	spin_btn = mk_btn("GIRAR", 260, 64, GREEN, 30)
	spin_btn.pressed.connect(_spin)
	row.add_child(spin_btn)
	var back := mk_btn("◀  VOLTAR", 220, 64, GRAY, 26)
	back.pressed.connect(func():
		if not spinning:
			show_screen("main"))
	row.add_child(back)


func _draw_wheel() -> void:
	var c := Vector2(210, 210)
	var n: int = game.WHEEL.size()
	var step := TAU / float(n)
	var f: Font = ThemeDB.fallback_font
	wheel.draw_circle(c + Vector2(0, 6), 206, Color(0, 0, 0, 0.4))
	wheel.draw_circle(c, 206, Color("f4c542"))
	wheel.draw_circle(c, 196, Color("7a4a0c"))
	var cols := [Color("2f7fd6"), Color("1fa85a"), Color("c94444"), Color("e3a928"), Color("8e44ad"), Color("16897f"), Color("d35400"), Color("f1c40f")]
	for i in n:
		var a0 := float(i) * step - PI / 2.0
		var pts := PackedVector2Array([c])
		for k in 13:
			pts.append(c + Vector2.from_angle(a0 + step * float(k) / 12.0) * 190.0)
		var w: Array = game.WHEEL[i]
		var col: Color = cols[i % cols.size()]
		if w[0] == "g":
			col = Color("6a1fb0")
		elif int(w[1]) >= 1000:
			col = Color("111111")
		wheel.draw_colored_polygon(pts, col)
		wheel.draw_line(c, c + Vector2.from_angle(a0) * 190.0, Color(1, 1, 1, 0.55), 2.0)
		var mid := a0 + step / 2.0
		wheel.draw_set_transform(c, mid + PI / 2.0, Vector2.ONE)
		var txt: String = str(int(w[1]))
		var tc := Color.WHITE
		if w[0] == "g":
			txt = "%d ◆" % int(w[1])
			tc = Color("f0dcff")
		elif int(w[1]) >= 1000:
			tc = Color("f4c542")
		wheel.draw_string_outline(f, Vector2(-60, -132), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, 6, Color(0, 0, 0, 0.6))
		wheel.draw_string(f, Vector2(-60, -132), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, tc)
		wheel.draw_string(f, Vector2(-60, -102), "GRANA" if w[0] == "g" else "moedas", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 1, 1, 0.8))
		wheel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 24:
		var p := c + Vector2.from_angle(float(i) * TAU / 24.0) * 201.0
		wheel.draw_circle(p, 4.0, Color("fff6c8") if i % 2 == 0 else Color("ffcf4a"))


func _roleta_refresh() -> void:
	var ex: int = int(game.save.get("spins", 0))
	if game.can_spin():
		var daily: bool = str(game.save.spin_day) != game.today_str()
		spin_lbl.text = ("Giro grátis de hoje disponível!" if daily else "Usando giro extra do Passe.") + ("   •   Giros extras: %d" % ex if ex > 0 else "")
		spin_btn.disabled = false
		spin_btn.text = "GIRAR"
	else:
		spin_lbl.text = "Você já girou hoje. Volte amanhã para girar de novo!"
		spin_btn.disabled = true
		spin_btn.text = "AMANHÃ"


func _spin() -> void:
	if spinning or not game.can_spin():
		return
	spinning = true
	spin_btn.disabled = true
	var i: int = game.spin_pick()
	var txt: String = game.spin_award(i)
	var step := TAU / float(game.WHEEL.size())
	var jitter := randf_range(-0.32, 0.32) * step
	wheel.rotation = fposmod(wheel.rotation, TAU)
	var target := -(float(i) * step + step / 2.0) - TAU * 6.0 + jitter
	var tw := create_tween()
	tw.tween_property(wheel, "rotation", target, 4.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		spinning = false
		var wv: Array = game.WHEEL[i]
		var rw: Dictionary = {"grana": int(wv[1])} if wv[0] == "g" else {"coins": int(wv[1])}
		show_reward("Prêmio da Roleta", txt.trim_suffix("!").to_upper(), rw)
		refresh_top()
		_roleta_refresh())


# ---------------------------------------------------------------- passe de nível
func _build_passe() -> void:
	var v := mk_screen("passe", 10)
	v.add_child(mk_lbl("PASSE DE NÍVEL", 50, Color("f4c542"), 10))
	pass_head = mk_lbl("", 20, Color(1, 1, 1, 0.85), 3)
	v.add_child(pass_head)
	pass_bar = ProgressBar.new()
	pass_bar.custom_minimum_size = Vector2(520, 14)
	pass_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pass_bar.show_percentage = false
	pass_bar.add_theme_stylebox_override("background", sbox(Color(0, 0, 0, 0.55), 7))
	pass_bar.add_theme_stylebox_override("fill", sbox(GOLD, 7))
	v.add_child(pass_bar)
	pass_scroll = ScrollContainer.new()
	pass_scroll.custom_minimum_size = Vector2(1120, 330)
	pass_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(pass_scroll)
	pass_row = HBoxContainer.new()
	pass_row.add_theme_constant_override("separation", 12)
	pass_scroll.add_child(pass_row)
	v.add_child(mk_lbl("Ganhe XP jogando: vitória +35  •  derrota +15  •  a cada 100 XP você sobe um nível", 16, Color(1, 1, 1, 0.6)))
	var back := mk_btn("◀  VOLTAR", 240, 58, GRAY, 26)
	back.pressed.connect(show_screen.bind("main"))
	v.add_child(back)


func _pass_refresh() -> void:
	for c in pass_row.get_children():
		c.queue_free()
	var lvl: int = game.player_level()
	pass_head.text = "Seu nível: %d   •   %d/100 XP para o próximo" % [lvl, game.xp() % 100]
	pass_bar.value = game.xp() % 100
	var first := -1
	for lv in range(2, game.PASS_MAX + 1):
		var r: Dictionary = game.pass_reward(lv)
		var got: bool = game.save.pass_got.has(lv)
		var open: bool = lv <= lvl
		if first == -1 and open and not got:
			first = lv
		var big: bool = r.has("item")
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(170 if big else 150, 316)
		var bc: Color = GOLD if (open and not got) else (Color(1, 1, 1, 0.18) if not big else Color("a24cff"))
		card.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.06, 0.1, 0.92) if open else Color(0.02, 0.03, 0.05, 0.85), 20, bc, 3, 8))
		pass_row.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(margin(vb, 10))
		vb.add_child(mk_lbl("NÍVEL %d" % lv, 22, Color("f4c542") if open else Color(1, 1, 1, 0.45), 4))
		var ic: Control
		if r.has("item"):
			var item: Dictionary = {}
			for it in game.FELTS + game.CUES:
				if it.id == r.item:
					item = it
			ic = Control.new()
			ic.custom_minimum_size = Vector2(130, 90)
			ic.clip_contents = true
			if item.has("shaft"):
				_cue_preview(ic, item, Vector2(56, 52), 120.0, -30.0, 16.0, 0.6, fx_nodes)
			else:
				var fr := ColorRect.new()
				fr.position = Vector2(8, 12)
				fr.size = Vector2(114, 66)
				var fm := ShaderMaterial.new()
				fm.shader = load("res://shaders/felt.gdshader")
				fm.set_shader_parameter("c_light", item.light)
				fm.set_shader_parameter("c_dark", item.dark)
				fm.set_shader_parameter("pat", int(item.pat))
				fm.set_shader_parameter("accent", item.get("accent", Color.WHITE))
				fm.set_shader_parameter("accent2", item.get("accent2", Color.WHITE))
				fr.material = fm
				ic.add_child(fr)
		elif r.has("spins"):
			ic = Control.new()
			ic.custom_minimum_size = Vector2(64, 64)
			var icn: Control = ic
			var sf := func():
				var cc := [Color("2f7fd6"), Color("1fa85a"), Color("c94444"), Color("e3a928"), Color("8e44ad"), Color("16897f")]
				for k in 6:
					var pts := PackedVector2Array([Vector2(32, 32)])
					for j in 7:
						pts.append(Vector2(32, 32) + Vector2.from_angle(float(k) * TAU / 6.0 + float(j) * TAU / 36.0) * 28.0)
					icn.draw_colored_polygon(pts, cc[k])
				icn.draw_arc(Vector2(32, 32), 29, 0, TAU, 32, Color("f4c542"), 3.0)
				icn.draw_circle(Vector2(32, 32), 7, Color("1b1e2b"))
				icn.draw_colored_polygon(PackedVector2Array([Vector2(25, 0), Vector2(39, 0), Vector2(32, 12)]), Color("c0392b"))
			ic.draw.connect(sf)
		elif r.has("grana"):
			ic = grana_icon(64)
		else:
			ic = coin_icon(64)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not open:
			ic.modulate = Color(1, 1, 1, 0.35)
		vb.add_child(ic)
		var lb := mk_lbl(r.txt, 17, Color.WHITE if open else Color(1, 1, 1, 0.5), 3)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(130, 48)
		vb.add_child(lb)
		var b: Button
		if got:
			b = mk_btn("✓ PEGO", 130, 50, Color(0.12, 0.3, 0.2), 20)
			b.disabled = true
		elif open:
			b = mk_btn("PEGAR", 130, 50, GREEN, 22)
			b.pressed.connect(_pass_claim.bind(lv))
		else:
			b = mk_btn("BLOQUEADO", 130, 50, GRAY, 16)
			b.disabled = true
		vb.add_child(b)
	var target := first if first != -1 else mini(lvl, game.PASS_MAX)
	get_tree().create_timer(0.05).timeout.connect(func(): pass_scroll.scroll_horizontal = maxi(0, (target - 2) * 162 - 320))


func _pass_claim(lv: int) -> void:
	if game.pass_claim(lv):
		var r: Dictionary = game.pass_reward(lv)
		show_reward("Passe de Nível  •  Nível %d" % lv, str(r.txt).to_upper(), r)
		refresh_top()
		_pass_refresh()


# ---------------------------------------------------------------- loja
func _build_shop() -> void:
	var v := mk_screen("shop", 12)
	shop_title = mk_lbl("LOJA", 52, Color("f4c542"), 10)
	v.add_child(shop_title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs)
	for k in [["felt", "MESAS"], ["cue", "TACOS"], ["deck", "BARALHOS"]]:
		var b := mk_btn(k[1], 220, 54, GRAY, 26)
		b.pressed.connect(_shop_tab.bind(k[0]))
		tab_btns[k[0]] = b
		tabs.add_child(b)
	for k in [["cue", "TACOS"], ["felt", "MESAS"], ["deck", "BARALHOS"]]:
		var sb := mk_btn(k[1], 220, 54, GRAY, 26)
		sb.pressed.connect(_inv_sub.bind(k[0]))
		inv_btns[k[0]] = sb
		tabs.add_child(sb)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(srow)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1120, 416)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	srow.add_child(sc)
	shop_scroll = sc
	shop_row = HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 16)
	sc.add_child(shop_row)
	var back := mk_btn("VOLTAR", 240, 58, GRAY, 28)
	back.pressed.connect(show_screen.bind("main"))
	v.add_child(back)
	_shop_tab("felt")


func _cue_preview(pv: Control, it: Dictionary, center: Vector2, clen: float, ang_deg: float, thick: float, fxs: float, store: Array) -> void:
	var mythic: bool = it.has("theme")
	if mythic:
		thick *= 2.2
	var cr := ColorRect.new()
	cr.size = Vector2(clen, thick)
	cr.position = center - cr.size / 2.0
	cr.pivot_offset = cr.size / 2.0
	cr.rotation_degrees = ang_deg
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/cue.gdshader")
	if mythic:
		cm.shader = load("res://shaders/cue_mythic.gdshader")
		cm.set_shader_parameter("theme", int(it.theme))
		cm.set_shader_parameter("glow", it.glow)
		cm.set_shader_parameter("pad", 2.2)
		cm.set_shader_parameter("ulen", clen / (thick / 2.2 / 2.0))
	cm.set_shader_parameter("shaft", it.shaft)
	cm.set_shader_parameter("butt", it.butt)
	cm.set_shader_parameter("accent", it.accent)
	cm.set_shader_parameter("ring", it.ring)
	cm.set_shader_parameter("wrap", it.wrap)
	cm.set_shader_parameter("pat", int(it.pat))
	cm.set_shader_parameter("shine", int(it.get("shine", 0)))
	cm.set_shader_parameter("butt2", it.get("butt2", it.butt))
	cr.material = cm
	pv.add_child(cr)
	var kind: String = it.get("fx", "")
	if kind == "":
		return
	var fxn := Control.new()
	fxn.set_anchors_preset(Control.PRESET_FULL_RECT)
	fxn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fxa := Control.new()
	fxa.set_anchors_preset(Control.PRESET_FULL_RECT)
	fxa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fxa.material = am
	var ang := deg_to_rad(ang_deg)
	var butt := center + Vector2.from_angle(ang) * (clen / 2.0)
	var fdn := func():
		var sn := FxScript.Sink.new()
		sn.t = fxn
		fxn.draw_set_transform(butt)
		FxScript.draw(sn, FxScript.Sink.new(), kind, fx_t, ang, fxs)
	var fda := func():
		var sa := FxScript.Sink.new()
		sa.t = fxa
		fxa.draw_set_transform(butt)
		FxScript.draw(FxScript.Sink.new(), sa, kind, fx_t, ang, fxs)
	fxn.draw.connect(fdn)
	fxa.draw.connect(fda)
	pv.add_child(fxn)
	pv.add_child(fxa)
	store.append(fxn)
	store.append(fxa)


func _month_refresh() -> void:
	if month_box == null:
		return
	month_fx.clear()
	for c in month_box.get_children():
		c.queue_free()
	var it: Dictionary = game.month_cue()
	var owned: bool = game.save.owned.has(it.id)
	var rc := Color("ffb21a") if it.rare == "LENDÁRIO" else (Color("c070ff") if it.rare == "MÍTICO" else Color("4fc3ff"))
	month_box.add_child(mk_lbl("★ TACO DE %s ★" % game.month_name().to_upper(), 23, Color("f4c542"), 6))
	var pv := Control.new()
	pv.custom_minimum_size = Vector2(348, 168)
	pv.clip_contents = true
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgf := func():
		bg.draw_rect(Rect2(0, 0, 348, 168), Color(0.01, 0.02, 0.05, 0.75), true)
		bg.draw_circle(Vector2(230, 60), 120, Color(rc.r, rc.g, rc.b, 0.10))
		bg.draw_circle(Vector2(230, 60), 70, Color(rc.r, rc.g, rc.b, 0.10))
		bg.draw_rect(Rect2(1, 1, 346, 166), Color(rc.r, rc.g, rc.b, 0.5), false, 2.0)
	bg.draw.connect(bgf)
	pv.add_child(bg)
	_cue_preview(pv, it, Vector2(92, 120), 250.0, -10.0, 28.0, 0.85, month_fx)
	var tag := mk_lbl(it.rare, 15, rc, 4)
	tag.position = Vector2(10, 6)
	pv.add_child(tag)
	var ob := PanelContainer.new()
	ob.add_theme_stylebox_override("panel", sbox(RED, 14, Color.WHITE, 2, 4))
	ob.add_child(margin(mk_lbl("-30%", 22, Color.WHITE, 5), 4))
	ob.position = Vector2(270, 8)
	pv.add_child(ob)
	month_box.add_child(pv)
	month_box.add_child(mk_lbl(it.name, 28, Color.WHITE, 5))
	month_box.add_child(_stat_row("Mira", int(it.aim)))
	month_box.add_child(_stat_row("Força", int(it.pow)))
	month_box.add_child(_stat_row("Precisão", int(it.prec)))
	month_box.add_child(_stat_row("Efeito", int(it.spin)))
	var promo: int = game.month_price(it)
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_theme_constant_override("separation", 10)
	month_box.add_child(pr)
	var old := mk_lbl(str(int(it.price)), 20, Color(1, 1, 1, 0.5))
	var oldf := func():
		old.draw_line(Vector2(0, old.size.y * 0.55), Vector2(old.size.x, old.size.y * 0.55), Color(1, 0.4, 0.4, 0.9), 2.0)
	old.draw.connect(oldf)
	pr.add_child(old)
	pr.add_child(mk_lbl("➜  %d" % promo, 26, Color("ffd35a"), 5))
	var dl: int = game.month_days_left()
	month_box.add_child(mk_lbl("Oferta termina em %d dia%s" % [dl, "" if dl == 1 else "s"], 15, Color(1, 1, 1, 0.6)))
	var btn: Button
	if game.save.cue == it.id:
		btn = mk_btn("EM USO", 330, 54, GREEN, 24)
		btn.disabled = true
	elif owned:
		btn = mk_btn("USAR", 330, 54, BLUE, 26)
		btn.pressed.connect(_month_equip.bind(it.id))
	else:
		var hbx := HBoxContainer.new()
		hbx.add_theme_constant_override("separation", 8)
		hbx.alignment = BoxContainer.ALIGNMENT_CENTER
		month_box.add_child(hbx)
		btn = mk_btn("COMPRAR  %d" % promo, 228, 54, GOLD if game.save.coins >= promo else RED, 22)
		btn.pressed.connect(_month_buy.bind(it.id, promo))
		hbx.add_child(btn)
		var gp: int = game.grana_price(it, true)
		var gb := mk_btn("◆ %d" % gp, 94, 54, PURPLE if int(game.save.grana) >= gp else GRAY, 22)
		gb.pressed.connect(_buy_grana.bind(it.id, gp, true))
		hbx.add_child(gb)
		return
	month_box.add_child(btn)


func _month_equip(id: String) -> void:
	game.save.cue = id
	game.write_save()
	_month_refresh()


func _month_buy(id: String, price: int) -> void:
	if game.save.coins < price:
		say("Moedas insuficientes! Vença partidas para ganhar mais.")
		return
	game.save.coins -= price
	game.save.owned.append(id)
	game.write_save()
	refresh_top()
	_month_equip(id)
	say("Taco do mês comprado!")


func _shop_nudge(dir: int) -> void:
	var tw := create_tween()
	tw.tween_property(shop_scroll, "scroll_horizontal", clampi(shop_scroll.scroll_horizontal + dir * 460, 0, 100000), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if upd_req != null and upd_bar != null and is_instance_valid(upd_bar):
		var tot := upd_req.get_body_size()
		if tot > 0:
			upd_bar.value = 100.0 * float(upd_req.get_downloaded_bytes()) / float(tot)
			upd_lbl.text = "Baixando...  %.1f de %.1f MB" % [upd_req.get_downloaded_bytes() / 1048576.0, tot / 1048576.0]
	presence_t += delta
	if presence_t > 15.0:
		presence_t = 0.0
		if cur != "amigos":
			presence_poll()
	if cur == "amigos":
		friends_t += delta
		if friends_t > 5.0:
			friends_t = 0.0
			friends_refresh()
	if cur == "online" and radar != null:
		if wait_left > 0.0:
			wait_left = maxf(0.0, wait_left - delta)
		fx_t += delta
		radar.queue_redraw()
		var bz: bool = _online_busy()
		if bz != _last_busy:
			_last_busy = bz
			_online_btn_refresh()
	if cur == "main":
		for hn in hero_nodes:
			hn.queue_redraw()
		fx_t += delta
		for n in month_fx:
			if is_instance_valid(n):
				n.queue_redraw()
	if (cur == "shop" or cur == "inv") and shop_tab != "felt":
		fx_t += delta
		for n in fx_nodes:
			if is_instance_valid(n):
				n.queue_redraw()


var friends_scroll: ScrollContainer
var hear_btn: Button
var micb_btn: Button
var _synth_release := false


# arrastar o dedo em cima dos botões rola a lista (e não aperta o botão)
func _input(e: InputEvent) -> void:
	var sv: ScrollContainer = shop_scroll if (cur == "shop" or cur == "inv") else (pass_scroll if cur == "passe" else null)
	var vert := false
	if cur == "amigos" and not has_modal():
		sv = friends_scroll
		vert = true
	if sv == null:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var r := Rect2(sv.global_position, sv.size)
			drag_id = e.index if r.has_point(e.position) else -1
			drag_moved = 0.0
		elif e.index == drag_id:
			drag_id = -1
			if drag_moved > 14.0:
				swallow_click = true
	elif e is InputEventScreenDrag and e.index == drag_id:
		var was := drag_moved
		if vert:
			drag_moved += absf(e.relative.y) + absf(e.relative.x) * 0.3
			sv.scroll_vertical -= int(e.relative.y)
		else:
			drag_moved += absf(e.relative.x) + absf(e.relative.y) * 0.3
			sv.scroll_horizontal -= int(e.relative.x)
		if was <= 14.0 and drag_moved > 14.0:
			# virou rolagem: solta o botão que o dedo apertou, longe dele, para ele não disparar
			# o botão só desiste se o "mouse" sair de cima dele antes de soltar
			var mv := InputEventMouseMotion.new()
			mv.position = Vector2(-5000, -5000)
			mv.global_position = mv.position
			mv.button_mask = MOUSE_BUTTON_MASK_LEFT
			_synth_release = true
			get_viewport().push_input(mv)
			_synth_release = false
			var rel := InputEventMouseButton.new()
			rel.button_index = MOUSE_BUTTON_LEFT
			rel.pressed = false
			rel.position = Vector2(-5000, -5000)
			rel.global_position = rel.position
			_synth_release = true
			get_viewport().push_input(rel)
			_synth_release = false
			swallow_click = true
		if drag_moved > 14.0:
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and not e.pressed and swallow_click and not _synth_release:
		swallow_click = false
		get_viewport().set_input_as_handled()


func _inv_sub(s: String) -> void:
	inv_sub = s
	shop_scroll.scroll_horizontal = 0
	_shop_tab("inv")


func _shop_tab(t: String) -> void:
	shop_tab = t
	for k in inv_btns.keys():
		var sb: Button = inv_btns[k]
		sb.visible = t == "inv"
		var sc: Color = Color("16897f") if k == inv_sub else GRAY
		sb.add_theme_stylebox_override("normal", sbox(sc, 20, sc.lightened(0.35), 3, 8))
	for k in tab_btns.keys():
		var tb: Button = tab_btns[k]
		tb.visible = t != "inv"
	if shop_title != null:
		shop_title.text = "INVENTÁRIO" if t == "inv" else "LOJA"
	for k in tab_btns.keys():
		var b: Button = tab_btns[k]
		var col: Color = GOLD if k == t else GRAY
		b.add_theme_stylebox_override("normal", sbox(col, 20, col.lightened(0.35), 3, 8))
	_shop_refresh()


func _stat_row(label: String, val: int) -> Control:
	# barra contínua + porcentagem (cada ponto do taco = 20%)
	var c := Control.new()
	c.custom_minimum_size = Vector2(212, 20)
	var f: Font = ThemeDB.fallback_font
	var pct: int = clampi(val, 0, 5) * 20
	var fn := func():
		c.draw_string(f, Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, 74, 14, Color(1, 1, 1, 0.85))
		var bx := 76.0
		var bw := 92.0
		c.draw_rect(Rect2(bx, 5, bw, 11), Color(1, 1, 1, 0.12), true)
		var col := Color("4cd37b") if pct >= 60 else (Color("f4c542") if pct >= 40 else Color("e0733a"))
		if pct > 0:
			c.draw_rect(Rect2(bx, 5, bw * float(pct) / 100.0, 11), col, true)
		for k in range(1, 5):
			c.draw_line(Vector2(bx + bw * k / 5.0, 5), Vector2(bx + bw * k / 5.0, 16), Color(0, 0, 0, 0.35), 1.0)
		c.draw_string(f, Vector2(bx + bw + 6, 15), "%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, 40, 14, Color.WHITE)
	c.draw.connect(fn)
	return c


func _shop_refresh() -> void:
	fx_nodes.clear()
	for c in shop_row.get_children():
		c.queue_free()
	var items: Array = []
	var owned_l: Array = game.save.owned
	if shop_tab == "inv":
		var src: Array = game.CUES + game.MONTHLY if inv_sub == "cue" else (game.DECKS if inv_sub == "deck" else game.FELTS)
		for it in src:
			if owned_l.has(it.id) or it.id == "dk_classico":
				items.append(it)
	else:
		var src2: Array = game.FELTS if shop_tab == "felt" else (game.DECKS if shop_tab == "deck" else game.CUES)
		for it in src2:
			if not owned_l.has(it.id) and it.id != "dk_classico":
				items.append(it)
	if items.is_empty():
		var el := mk_lbl("Você já tem todos os itens desta aba!\nVeja tudo em INVENTÁRIO.", 26, Color(1, 1, 1, 0.8), 4)
		el.custom_minimum_size = Vector2(1100, 380)
		el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shop_row.add_child(el)
		return
	for it in items:
		var is_cue: bool = it.has("shaft")
		var is_deck: bool = it.has("deck")
		var equipped: String = game.save.cue if is_cue else ("dk_" + str(game.save.get("deck", "classico")) if is_deck else game.save.felt)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(212, 404)
		card.add_theme_stylebox_override("panel", sbox(NAVY, 22, Color(1, 1, 1, 0.22) if it.id != equipped else GOLD, 3 if it.id != equipped else 5, 10))
		shop_row.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		card.add_child(margin(vb, 14))
		var pv := Control.new()
		pv.custom_minimum_size = Vector2(184, 150)
		pv.clip_contents = true
		if is_cue:
			_cue_preview(pv, it, Vector2(60, 100), 140.0, -40.0, 22.0, 0.85, fx_nodes)
		elif is_deck:
			_deck_preview(pv, str(it.deck))
		else:
			var wood := ColorRect.new()
			wood.color = Color("5b3a1e")
			wood.position = Vector2(0, 8)
			wood.size = Vector2(184, 112)
			pv.add_child(wood)
			var fr := ColorRect.new()
			fr.position = Vector2(8, 16)
			fr.size = Vector2(168, 96)
			var fm := ShaderMaterial.new()
			fm.shader = load("res://shaders/felt.gdshader")
			fm.set_shader_parameter("c_light", it.light)
			fm.set_shader_parameter("c_dark", it.dark)
			fm.set_shader_parameter("pat", int(it.pat))
			fm.set_shader_parameter("accent", it.get("accent", Color.WHITE))
			fm.set_shader_parameter("accent2", it.get("accent2", Color.WHITE))
			fr.material = fm
			pv.add_child(fr)
			var top := Control.new()
			top.set_anchors_preset(Control.PRESET_FULL_RECT)
			top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fnt := func():
				for p in [Vector2(8, 16), Vector2(176, 16), Vector2(8, 112), Vector2(176, 112), Vector2(92, 16), Vector2(92, 112)]:
					top.draw_circle(p, 7, Color("050505"))
				top.draw_circle(Vector2(52, 66), 8, Color("f4f4ee"))
				top.draw_circle(Vector2(112, 58), 8, Color("d12a1e"))
				top.draw_circle(Vector2(129, 70), 8, Color("1a4fb4"))
				top.draw_circle(Vector2(109, 55), 2.5, Color(1, 1, 1, 0.5))
			top.draw.connect(fnt)
			pv.add_child(top)
		vb.add_child(pv)
		vb.add_child(mk_lbl(it.name, 24, Color.WHITE, 4))
		if is_cue:
			vb.add_child(_stat_row("Mira", int(it.aim)))
			vb.add_child(_stat_row("Força", int(it.pow)))
			vb.add_child(_stat_row("Precisão", int(it.prec)))
			vb.add_child(_stat_row("Efeito", int(it.spin)))
		else:
			var tg := mk_lbl(it.tag, 16, Color(1, 1, 1, 0.65))
			tg.custom_minimum_size = Vector2(184, 0)
			tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(tg)
		var owned: bool = game.save.owned.has(it.id) or it.id == "dk_classico"
		var btn: Button
		if it.id == equipped:
			btn = mk_btn("EM USO", 184, 56, GREEN, 24)
			btn.disabled = true
		elif owned:
			btn = mk_btn("USAR", 184, 56, BLUE, 26)
			btn.pressed.connect(_equip.bind(it.id))
		elif it.has("pass"):
			btn = mk_btn("PASSE • NÍVEL %d" % int(it.pass), 184, 56, GRAY, 18)
			btn.disabled = true
		else:
			var gp: int = game.grana_price(it)
			if gp > 0:
				var hbx := HBoxContainer.new()
				hbx.add_theme_constant_override("separation", 6)
				vb.add_child(hbx)
				btn = mk_btn("%d" % it.price, 110, 56, GOLD if game.save.coins >= it.price else RED, 22)
				btn.pressed.connect(_buy.bind(it.id, it.price))
				hbx.add_child(btn)
				var gb := mk_btn("◆ %d" % gp, 68, 56, PURPLE if int(game.save.grana) >= gp else GRAY, 20)
				gb.pressed.connect(_buy_grana.bind(it.id, gp, false))
				hbx.add_child(gb)
				continue
			btn = mk_btn("COMPRAR  %d" % it.price, 184, 56, GOLD if game.save.coins >= it.price else RED, 22)
			btn.pressed.connect(_buy.bind(it.id, it.price))
		vb.add_child(btn)


func _deck_preview(pv: Control, style_id: String) -> void:
	var CARDS = load("res://cards.gd")
	var st: Dictionary = CARDS.style(style_id)
	var dc := Control.new()
	dc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dc.draw.connect(func():
		dc.draw_set_transform(Vector2(62, 78), -0.18, Vector2.ONE)
		CARDS.draw_back(dc, Rect2(-36, -52, 72, 104), st)
		dc.draw_set_transform(Vector2(120, 78), 0.16, Vector2.ONE)
		CARDS.draw_face(dc, Rect2(-36, -52, 72, 104), {"r": 6, "s": 2}, st, false, false)
		dc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	pv.add_child(dc)


func _equip(id: String) -> void:
	if id.begins_with("dk_"):
		game.save.deck = id.substr(3)
		game.write_save()
		_shop_refresh()
		return
	var is_felt := false
	for f in game.FELTS:
		if f.id == id:
			is_felt = true
	if is_felt:
		game.save.felt = id
		game.apply_felt()
	else:
		game.save.cue = id
	game.write_save()
	_shop_refresh()


func _buy_grana(id: String, gp: int, month: bool) -> void:
	if int(game.save.grana) < gp:
		say("Grana insuficiente! Ganhe Grana no Passe e na Roleta.")
		return
	game.save.grana = int(game.save.grana) - gp
	game.save.owned.append(id)
	game.write_save()
	refresh_top()
	if month:
		_month_equip(id)
	else:
		_equip(id)
	say("Comprado com Grana! Está no seu INVENTÁRIO.")


func _buy(id: String, price: int) -> void:
	if game.save.coins < price:
		say("Moedas insuficientes! Vença partidas para ganhar mais.")
		return
	game.save.coins -= price
	game.save.owned.append(id)
	game.write_save()
	refresh_top()
	_equip(id)
	say("Comprado! Está no seu INVENTÁRIO.")


# ---------------------------------------------------------------- estatísticas / ajustes
func _build_stats() -> void:
	var v := mk_screen("stats", 16)
	v.add_child(mk_lbl("ESTATÍSTICAS", 60, Color("f4c542"), 12))
	var p := panel(560, 330)
	v.add_child(p)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 12)
	p.add_child(margin(stats_box, 26))
	var back := mk_btn("VOLTAR", 240, 64, GRAY, 28)
	back.pressed.connect(show_screen.bind("main"))
	v.add_child(back)


func _stats_refresh() -> void:
	for c in stats_box.get_children():
		c.queue_free()
	var s: Dictionary = game.save
	var rate := 0
	if s.wins + s.losses > 0:
		rate = int(100.0 * s.wins / (s.wins + s.losses))
	var rows := [["Partidas jogadas", str(s.played)], ["Vitórias", str(s.wins)], ["Derrotas", str(s.losses)], ["Aproveitamento", "%d%%" % rate], ["Moedas", str(s.coins)]]
	for r in rows:
		var hb := HBoxContainer.new()
		var a := mk_lbl(r[0], 26, Color(1, 1, 1, 0.85))
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := mk_lbl(r[1], 28, Color("ffe066"), 4)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hb.add_child(a)
		hb.add_child(b)
		stats_box.add_child(hb)


func _build_settings() -> void:
	var v := mk_screen("settings", 16)
	v.add_child(mk_lbl("AJUSTES", 60, Color("f4c542"), 12))
	sfx_btn = mk_btn("", 420, 76, GREEN, 30)
	sfx_btn.pressed.connect(_toggle.bind("sfx"))
	vib_btn = mk_btn("", 420, 76, GREEN, 30)
	vib_btn.pressed.connect(_toggle.bind("vib"))
	hear_btn = mk_btn("", 300, 64, GREEN, 22)
	hear_btn.pressed.connect(_toggle.bind("voice_hear"))
	micb_btn = mk_btn("", 300, 64, GREEN, 22)
	micb_btn.pressed.connect(_toggle.bind("voice_mic"))
	var acc := PanelContainer.new()
	acc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	acc.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.09, 0.86), 24, Color(1, 1, 1, 0.22), 2, 8))
	v.add_child(acc)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 10)
	acc.add_child(margin(av, 16))
	av.add_child(mk_lbl("CONTA", 26, Color("f4c542"), 4))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 10)
	av.add_child(nr)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Seu nome (até 15 letras)"
	name_edit.max_length = 15
	name_edit.custom_minimum_size = Vector2(300, 60)
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_size_override("font_size", 28)
	name_edit.add_theme_stylebox_override("normal", sbox(Color(0.02, 0.05, 0.09, 0.95), 16, Color(1, 1, 1, 0.35), 2, 0))
	name_edit.add_theme_stylebox_override("focus", sbox(Color(0.02, 0.05, 0.09, 0.95), 16, Color("5aa9ff"), 3, 0))
	nr.add_child(name_edit)
	var sv := mk_btn("SALVAR", 130, 60, GREEN, 24)
	sv.pressed.connect(_save_name)
	nr.add_child(sv)
	var gg := mk_btn("G   CONECTAR CONTA GOOGLE", 440, 60, Color("ffffff"), 22)
	gg.add_theme_color_override("font_color", Color("3c4043"))
	gg.add_theme_color_override("font_hover_color", Color("1a73e8"))
	gg.add_theme_constant_override("outline_size", 0)
	gg.pressed.connect(func(): say("Login com Google chega em breve (precisa configurar no Google Play)."))
	av.add_child(gg)
	var tg := HBoxContainer.new()
	tg.add_theme_constant_override("separation", 16)
	tg.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tg)
	sfx_btn.custom_minimum_size = Vector2(300, 64)
	vib_btn.custom_minimum_size = Vector2(300, 64)
	sfx_btn.add_theme_font_size_override("font_size", 24)
	vib_btn.add_theme_font_size_override("font_size", 24)
	tg.add_child(sfx_btn)
	tg.add_child(vib_btn)
	var tg2 := HBoxContainer.new()
	tg2.add_theme_constant_override("separation", 16)
	tg2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tg2)
	tg2.add_child(hear_btn)
	tg2.add_child(micb_btn)
	var back := mk_btn("VOLTAR", 240, 64, GRAY, 28)
	back.pressed.connect(show_screen.bind("main"))
	v.add_child(back)
	_settings_refresh()


func _save_name() -> void:
	var n := name_edit.text.strip_edges().left(15)
	game.save.name = n
	game.write_save()
	game.net.send_hello()
	refresh_top()
	say("Nome salvo: " + game.my_name())


func _cycle_timer() -> void:
	var opts := [20, 30, 45, 0]
	var i := opts.find(int(game.save.timer))
	game.save.timer = opts[(i + 1) % opts.size()]
	game.write_save()
	_settings_refresh()


func _toggle(k: String) -> void:
	game.save[k] = not bool(game.save.get(k, true))
	game.write_save()
	_settings_refresh()


func _settings_refresh() -> void:
	if name_edit != null:
		name_edit.text = str(game.save.get("name", ""))
	sfx_btn.text = "SOM: " + ("LIGADO" if game.save.sfx else "DESLIGADO")
	vib_btn.text = "VIBRAÇÃO: " + ("LIGADA" if game.save.vib else "DESLIGADA")
	hear_btn.text = "OUVIR VOZ: " + ("SIM" if game.save.get("voice_hear", true) else "NÃO")
	micb_btn.text = "MEU MICROFONE: " + ("SIM" if game.save.get("voice_mic", true) else "NÃO")
	for pair in [[sfx_btn, game.save.sfx], [vib_btn, game.save.vib], [hear_btn, game.save.get("voice_hear", true)], [micb_btn, game.save.get("voice_mic", true)]]:
		var b: Button = pair[0]
		var col: Color = GREEN if pair[1] else GRAY
		b.add_theme_stylebox_override("normal", sbox(col, 20, col.lightened(0.35), 3, 8))
		b.add_theme_stylebox_override("hover", sbox(col.lightened(0.12), 20, Color.WHITE, 3, 8))


# ---------------------------------------------------------------- pausa / fim
func _build_pause() -> void:
	var v := mk_screen("pause", 14)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.95), 30, Color(0.96, 0.77, 0.26, 0.85), 3, 20))
	v.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(margin(vb, 26))
	var hd := Control.new()
	hd.custom_minimum_size = Vector2(420, 86)
	hd.draw.connect(func():
		var c := Vector2(210, 40)
		hd.draw_circle(c, 34, Color("f4c542"))
		hd.draw_circle(c, 29, Color("1b1e2b"))
		hd.draw_rect(Rect2(c.x - 13, c.y - 15, 9, 30), Color("f4c542"))
		hd.draw_rect(Rect2(c.x + 4, c.y - 15, 9, 30), Color("f4c542")))
	vb.add_child(hd)
	vb.add_child(mk_lbl("JOGO PAUSADO", 40, Color("f4c542"), 8))
	pause_info = mk_lbl("", 18, Color(1, 1, 1, 0.75), 2)
	vb.add_child(pause_info)
	var b1 := mk_btn("▶  CONTINUAR", 400, 72, GREEN, 30)
	b1.pressed.connect(_resume)
	vb.add_child(b1)
	pause_sfx = mk_btn("", 400, 56, GRAY, 22)
	pause_sfx.pressed.connect(func():
		_toggle("sfx")
		_pause_refresh())
	vb.add_child(pause_sfx)
	var b2 := mk_btn("SAIR DA PARTIDA", 400, 56, Color("8a2a2a"), 22)
	b2.pressed.connect(func():
		confirm("SAIR DA PARTIDA?", "A partida atual será perdida.", "SAIR", _to_menu, "VOLTAR AO JOGO", func(): pass))
	vb.add_child(b2)
	vb.add_child(mk_lbl("Dica: o botão VOLTAR do celular só pausa, não fecha o jogo.", 14, Color(1, 1, 1, 0.5), 1))


func _pause_refresh() -> void:
	if pause_sfx == null:
		return
	pause_sfx.text = "SOM: " + ("LIGADO" if game.save.sfx else "DESLIGADO")
	var mt := {0: "Contra a IA", 1: "2 Jogadores", 2: "Treino", 3: "Online"}
	pause_info.text = "%s   •   vez de %s" % [mt.get(int(game.mode), ""), str(game.players[game.turn])]
	if int(game.mode) == 3:
		pause_info.text += "\n(online não pausa: o tempo continua correndo)"


# ---------------------------------------------------------------- janela de confirmação
var modal_layer: Control
var pause_info: Label
var pause_sfx: Button


func has_modal() -> bool:
	return modal_layer != null and is_instance_valid(modal_layer)


func close_modal() -> void:
	if has_modal():
		modal_layer.queue_free()
	modal_layer = null


# ícone grande do prêmio (moedas, Grana, giro ou o item: taco/mesa)
func reward_icon(r: Dictionary, sz: float) -> Control:
	if r.has("item"):
		var item: Dictionary = {}
		for it in game.FELTS + game.CUES:
			if it.id == r.item:
				item = it
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(sz * 2.2, sz * 1.3)
		if item.has("shaft"):
			_cue_preview(ic, item, Vector2(sz * 1.1, sz * 0.65), sz * 2.0, -24.0, sz * 0.22, 1.0, fx_nodes)
		elif not item.is_empty():
			var fr := ColorRect.new()
			fr.position = Vector2(sz * 0.1, sz * 0.1)
			fr.size = Vector2(sz * 2.0, sz * 1.1)
			var fm := ShaderMaterial.new()
			fm.shader = load("res://shaders/felt.gdshader")
			fm.set_shader_parameter("c_light", item.light)
			fm.set_shader_parameter("c_dark", item.dark)
			fm.set_shader_parameter("pat", int(item.pat))
			fm.set_shader_parameter("accent", item.get("accent", Color.WHITE))
			fm.set_shader_parameter("accent2", item.get("accent2", Color.WHITE))
			fr.material = fm
			var fb := Panel.new()
			fb.position = fr.position - Vector2(8, 8)
			fb.size = fr.size + Vector2(16, 16)
			fb.add_theme_stylebox_override("panel", sbox(Color("5a3418"), 14, Color("8a5a2a"), 3, 8))
			ic.add_child(fb)
			ic.add_child(fr)
		return ic
	if r.has("spins"):
		var w := Control.new()
		w.custom_minimum_size = Vector2(sz, sz)
		w.draw.connect(func():
			var c := Vector2(sz, sz) / 2.0
			var rr := sz * 0.45
			var cc := [Color("2f7fd6"), Color("1fa85a"), Color("c94444"), Color("e3a928"), Color("8e44ad"), Color("16897f")]
			for k in 6:
				var pts := PackedVector2Array([c])
				for j in 7:
					pts.append(c + Vector2.from_angle(float(k) * TAU / 6.0 + float(j) * TAU / 36.0) * rr)
				w.draw_colored_polygon(pts, cc[k])
			w.draw_arc(c, rr, 0, TAU, 48, Color("f4c542"), sz * 0.05)
			w.draw_circle(c, sz * 0.1, Color("1b1e2b")))
		return w
	if r.has("grana") and not r.has("coins"):
		return grana_icon(sz)
	return coin_icon(sz)


# janela de prêmio: raios girando, brilhos e o que você ganhou
func show_reward(head: String, big: String, r: Dictionary) -> void:
	close_modal()
	game.play("win")
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.72)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dimr)
	var rays := Control.new()
	rays.size = Vector2(900, 900)
	rays.pivot_offset = Vector2(450, 450)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.draw.connect(func():
		var c := Vector2(450, 450)
		for k in 16:
			var a0 := float(k) * TAU / 16.0
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a0 - 0.09) * 450.0, c + Vector2.from_angle(a0 + 0.09) * 450.0])
			rays.draw_colored_polygon(pts, Color(1.0, 0.85, 0.35, 0.07))
		for k in 6:
			rays.draw_circle(c, 60.0 + k * 34.0, Color(1.0, 0.8, 0.3, 0.035)))
	modal_layer.add_child(rays)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.05, 0.1, 0.97), 30, Color("f4c542"), 4, 30))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(margin(vb, 26))
	vb.add_child(mk_lbl(head, 20, Color(1, 1, 1, 0.75), 2))
	vb.add_child(mk_lbl("VOCÊ GANHOU!", 46, Color("f4c542"), 10))
	var ic := reward_icon(r, 110.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var bl := mk_lbl(big, 30, Color.WHITE, 6)
	bl.custom_minimum_size = Vector2(460, 0)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(bl)
	var ok := mk_btn("PEGAR!", 260, 66, GREEN, 28)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(close_modal)
	vb.add_child(ok)
	# brilhos subindo
	for k in 14:
		var sp := Label.new()
		sp.text = "✦"
		sp.add_theme_font_size_override("font_size", randi_range(18, 34))
		sp.add_theme_color_override("font_color", [Color("ffe066"), Color.WHITE, Color("7fe3ff")][k % 3])
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modal_layer.add_child(sp)
		var vs: Vector2 = root.size
		var x0 := vs.x * 0.5 + randf_range(-380, 380)
		sp.position = Vector2(x0, vs.y * 0.5 + randf_range(40, 260))
		sp.modulate.a = 0.0
		var tw := sp.create_tween().set_loops()
		tw.tween_interval(randf_range(0.0, 1.4))
		tw.tween_property(sp, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(sp, "position:y", sp.position.y - randf_range(160, 300), 1.6).from(sp.position.y)
		tw.tween_property(sp, "modulate:a", 0.0, 0.4)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	rays.position = root.size / 2.0 - rays.size / 2.0
	var rt := rays.create_tween().set_loops()
	rt.tween_property(rays, "rotation", TAU, 14.0).from(0.0)
	p.pivot_offset = p.size / 2.0
	p.scale = Vector2(0.5, 0.5)
	p.modulate.a = 0.0
	var pt := p.create_tween().set_parallel()
	pt.tween_property(p, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(p, "modulate:a", 1.0, 0.2)


func confirm(title: String, msg: String, yes: String, yes_cb: Callable, no: String, no_cb: Callable) -> void:
	close_modal()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.6)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.97), 26, Color("f4c542"), 3, 20))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	p.add_child(margin(vb, 24))
	vb.add_child(mk_lbl(title, 34, Color("f4c542"), 6))
	vb.add_child(mk_lbl(msg, 20, Color(1, 1, 1, 0.85), 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var by := mk_btn(yes, 220, 62, GREEN if yes != "SAIR" else RED, 22)
	by.pressed.connect(func():
		close_modal()
		yes_cb.call())
	row.add_child(by)
	var bn := mk_btn(no, 220, 62, GRAY, 20)
	bn.pressed.connect(func():
		close_modal()
		no_cb.call())
	row.add_child(bn)


# botão voltar do celular nos menus
func menu_back() -> void:
	match cur:
		"main", "":
			confirm("SAIR DO JOGO?", "Quer mesmo fechar o jogo?", "SAIR", func(): get_tree().quit(), "FICAR", func(): pass)
		"online":
			_online_back()
		"amigos":
			show_screen("online" if _came_from_online else "main")
		"over":
			_to_menu()
		_:
			show_screen("main")


func _resume() -> void:
	game.paused = false
	show_screen("")


func _to_menu() -> void:
	game.go_menu()


func _build_over() -> void:
	var v := mk_screen("over", 16)
	var p := panel(560, 420)
	v.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(margin(vb, 28))
	over_title = mk_lbl("VITÓRIA!", 64, Color("f4c542"), 12)
	vb.add_child(over_title)
	over_sub = mk_lbl("", 30, Color.WHITE, 5)
	vb.add_child(over_sub)
	over_reward = mk_lbl("", 32, Color("ffe066"), 6)
	vb.add_child(over_reward)
	var b1 := mk_btn("REVANCHE", 400, 74, GREEN, 30)
	over_rematch = b1
	b1.pressed.connect(_rematch)
	var b2 := mk_btn("MENU PRINCIPAL", 400, 74, GRAY, 28)
	b2.pressed.connect(_to_menu)
	vb.add_child(b1)
	vb.add_child(b2)


func _rematch() -> void:
	show_screen("")
	game.start_game(game.mode, game.diff)


func show_over() -> void:
	var w: int = game.winner
	if game.mode == game.Mode.AI:
		over_title.text = "VITÓRIA!" if w == 0 else "DERROTA"
		over_title.add_theme_color_override("font_color", Color("f4c542") if w == 0 else Color("e06666"))
		over_sub.text = "Você venceu a IA GoScripts!" if w == 0 else "A IA GoScripts venceu desta vez."
	elif game.mode == game.Mode.ONLINE:
		# vencedor é o TIME (0 ou 1); no 2x2 os assentos 0 e 2 são um time, 1 e 3 o outro
		var won: bool = w == game.net_seat % 2
		over_title.text = "VITÓRIA!" if won else "DERROTA"
		over_title.add_theme_color_override("font_color", Color("f4c542") if won else Color("e06666"))
		if game.net4:
			over_sub.text = "Sua dupla venceu a partida!" if won else "A dupla adversária venceu desta vez."
		else:
			over_sub.text = "Você venceu a partida online!" if won else "Seu adversário venceu desta vez."
	else:
		over_title.text = "FIM DE JOGO"
		over_title.add_theme_color_override("font_color", Color("f4c542"))
		over_sub.text = "%s venceu!" % game.players[w]
	over_reward.text = game.reward_txt
	over_rematch.visible = game.mode != game.Mode.ONLINE
	refresh_top()
	show_screen("over")


# ---------------------------------------------------------------- navegação
func show_screen(sname: String) -> void:
	cur_prev = cur
	cur = sname
	var real := "shop" if sname == "inv" else sname
	for k in screens.keys():
		var s: Control = screens[k]
		s.visible = k == real
		if k == real:
			s.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(s, "modulate:a", 1.0, 0.18)
	var menus := ["main", "play", "online", "shop", "inv", "stats", "settings", "roleta", "passe", "truco", "amigos"]
	topbar.visible = menus.has(sname)
	dim.visible = sname != ""
	dim.color = Color(0.01, 0.05, 0.04, 0.62 if menus.has(sname) else 0.5)
	if top_center != null:
		top_center.visible = false
	if sname == "amigos":
		_came_from_online = cur_prev == "online"
		_amigos_open()
	if sname == "online" and cur_prev != "amigos":
		_online_reset()
	elif sname == "roleta":
		_roleta_refresh()
	elif sname == "passe":
		_pass_refresh()
	if sname == "pause":
		_pause_refresh()
	if sname == "main":
		_month_refresh()
	elif sname == "shop":
		if shop_tab == "inv":
			shop_tab = "felt"
		_shop_tab(shop_tab)
	elif sname == "inv":
		_shop_tab("inv")
	elif sname == "stats":
		_stats_refresh()
	elif sname == "settings":
		_settings_refresh()
	refresh_top()
