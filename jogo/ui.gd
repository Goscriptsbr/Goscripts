extends CanvasLayer
const AV = preload("res://avatars.gd")
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
var top_av: Control
var anim_t := 0.0
var pf_box: VBoxContainer
var pf_tab := "perfil"
var rk_box: VBoxContainer
var rk_head: Control
var rk_tab := "todos"
var rk_data := {}
var friend_av := {}
var fr_head: Control
var page_scroll: ScrollContainer
var mis_btn: Button
var mis_box: VBoxContainer
var mis_head: Label
var stake_btns := {}
var bet_hint_on: Label
var bet_hint_ai: Label
var bet_hint_tr: Label
var pass_top_btn: Button
var wheel: Control
var wheel_rim: Control
var wheel_rays: Control
var wheel_tick := 0.0
var wheel_last_seg := -1
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
	_build_missoes()
	_build_perfil()
	_build_ranking()
	_build_torneio()
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
	c.draw.connect(func(): draw_coin(c, Vector2(sz / 2, sz / 2), sz / 2 - 1))
	return c


# moeda de ouro: borda serrilhada, face com degradê, estrela em relevo e brilho
func draw_coin(c: CanvasItem, ctr: Vector2, r: float) -> void:
	c.draw_circle(ctr + Vector2(0, r * 0.1), r, Color(0, 0, 0, 0.3))
	c.draw_circle(ctr + Vector2(0, r * 0.06), r, Color("8a5208"))
	c.draw_circle(ctr, r, Color("d18f12"))
	# serrilhado da borda
	if r > 9.0:
		for i in 28:
			var a := float(i) / 28.0 * TAU
			c.draw_line(ctr + Vector2.from_angle(a) * r * 0.86, ctr + Vector2.from_angle(a) * r * 0.98, Color("a86d0c"), maxf(1.0, r * 0.06))
	# face: do centro claro até a borda mais escura
	var steps := 6
	for k in steps:
		var t := float(k) / float(steps - 1)
		c.draw_circle(ctr, r * (0.84 - 0.5 * t), Color("f0b324").lerp(Color("ffe27a"), t))
	c.draw_arc(ctr, r * 0.66, 0, TAU, 32, Color("c98a12"), maxf(1.0, r * 0.07))
	c.draw_arc(ctr, r * 0.72, PI * 1.05, PI * 1.6, 16, Color(1, 1, 1, 0.55), maxf(1.0, r * 0.06))
	# estrela em relevo
	var st := PackedVector2Array()
	var st2 := PackedVector2Array()
	for i in 10:
		var rr := r * (0.42 if i % 2 == 0 else 0.18)
		var a2 := -PI / 2.0 + float(i) * PI / 5.0
		st.append(ctr + Vector2.from_angle(a2) * rr + Vector2(0, r * 0.05))
		st2.append(ctr + Vector2.from_angle(a2) * rr)
	c.draw_colored_polygon(st, Color("b0700a"))
	c.draw_colored_polygon(st2, Color("fff1b0"))
	# brilho
	c.draw_circle(ctr + Vector2(-r * 0.42, -r * 0.42), r * 0.13, Color(1, 1, 1, 0.7))
	c.draw_circle(ctr + Vector2(-r * 0.42, -r * 0.42), r * 0.25, Color(1, 1, 1, 0.12))


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
		AV.draw(av, Vector2(27, 27), 27, str(game.save.get("av", "b8")), str(game.save.get("frame", "simples")), anim_t)
	av.draw.connect(avf)
	top_av = av
	# tocar no seu nome abre o perfil
	var pbtn := Button.new()
	pbtn.flat = true
	pbtn.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		pbtn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	pbtn.set_anchors_preset(Control.PRESET_FULL_RECT)
	pbtn.pressed.connect(func():
		if cur != "" and cur != "pause" and cur != "over":
			show_screen("perfil"))
	pf.add_child(pbtn)
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
	if top_av != null:
		top_av.queue_redraw()
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
	elif kind == "target":
		c.draw_circle(p, 15, Color.WHITE)
		c.draw_circle(p, 11, Color("e53935"))
		c.draw_circle(p, 7, Color.WHITE)
		c.draw_circle(p, 3.5, Color("e53935"))
		c.draw_line(p + Vector2(16, -16), p + Vector2(2, -2), Color("f4c542"), 3.0)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(16, -16), p + Vector2(20, -10), p + Vector2(10, -20)]), Color("f4c542"))
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
	elif kind == "person":
		c.draw_circle(p + Vector2(0, -8), 12, Color("8fd3ff"))
		c.draw_colored_polygon(_arcpoly(p + Vector2(0, 24), 22), Color("8fd3ff"))
		c.draw_circle(p + Vector2(-4, -12), 4, Color(1, 1, 1, 0.6))
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


var tut_refs := {}   # partes do menu que o tutorial aponta


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
	tut_refs["sinuca"] = h1
	var h2 := hero_btn("TRUCO", "paulista  •  1x1, 2x2 e online", "res://assets/hero_truco.png", Color("ff7a7a"))
	h2.pressed.connect(show_screen.bind("truco"))
	hr.add_child(h2)
	tut_refs["truco"] = h2
	hr.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	hr.offset_left += shift
	hr.offset_right += shift
	hr.offset_top += 18
	hr.offset_bottom += 18
	# trilho da esquerda: roleta, passe, amigos
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 14)
	s.add_child(rail)
	tut_refs["rail"] = rail
	rail.add_theme_constant_override("separation", 10)
	spin_top_btn = rail_btn("ROLETA", "wheel", PURPLE)
	spin_top_btn.pressed.connect(show_screen.bind("roleta"))
	rail.add_child(spin_top_btn)
	pass_top_btn = rail_btn("PASSE", "ticket", Color("16897f"))
	pass_top_btn.pressed.connect(show_screen.bind("passe"))
	rail.add_child(pass_top_btn)
	fr_btn = rail_btn("AMIGOS", "people", BLUE)
	fr_btn.pressed.connect(show_screen.bind("amigos"))
	rail.add_child(fr_btn)
	mis_btn = rail_btn("MISSÕES", "target", Color("d35400"))
	mis_btn.pressed.connect(show_screen.bind("missoes"))
	rail.add_child(mis_btn)
	# ordem do trilho: amigos, roleta, passe e missões
	rail.move_child(fr_btn, 0)
	rail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 22)
	rail.offset_top -= 10
	rail.offset_bottom -= 10
	# taco do mês (direita)
	var mc := PanelContainer.new()
	mc.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.82), 26, Color(0.96, 0.77, 0.26, 0.75), 2, 16))
	s.add_child(mc)
	tut_refs["month"] = mc
	month_box = VBoxContainer.new()
	month_box.add_theme_constant_override("separation", 3)
	mc.add_child(margin(month_box, 12))
	mc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
	mc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mc.grow_vertical = Control.GROW_DIRECTION_BOTH
	mc.offset_top -= 10
	mc.offset_bottom -= 10
	# barra de baixo
	# faixa escura suave atrás da doca
	var shade := Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -96
	shade.draw.connect(func():
		var w := shade.size.x
		for k in 12:
			shade.draw_rect(Rect2(0, k * 8, w, 8), Color(0, 0, 0, 0.05 * k)))
	# doca flutuante com os botões
	var nav := PanelContainer.new()
	nav.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.06, 0.1, 0.92), 26, Color(1, 1, 1, 0.14), 2, 14))
	s.add_child(nav)
	tut_refs["nav"] = nav
	nav.anchor_left = 0.5
	nav.anchor_right = 0.5
	nav.anchor_top = 1.0
	nav.anchor_bottom = 1.0
	nav.grow_horizontal = Control.GROW_DIRECTION_BOTH
	nav.grow_vertical = Control.GROW_DIRECTION_BEGIN
	nav.offset_bottom = -8
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 4)
	nh.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_child(margin(nh, 4))
	for it in [["LOJA", "shop", "shop"], ["INVENTÁRIO", "inv", "inv"], ["PERFIL", "person", "perfil"], ["RANKING", "stats", "ranking"], ["AJUSTES", "gear", "settings"]]:
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
	var cols := {"shop": [Color("f6c945"), Color("c98a12")], "inv": [Color("ff9a4a"), Color("c2541a")], "person": [Color("5aa9ff"), Color("1f5fc0")], "stats": [Color("c084ff"), Color("7a2fc0")], "gear": [Color("9aa8bc"), Color("4f5d72")]}
	var cc: Array = cols.get(kind, [GRAY, GRAY])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 74)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", sbox(Color(1, 1, 1, 0.06), 18))
	b.add_theme_stylebox_override("pressed", sbox(Color(1, 1, 1, 0.12), 18))
	var ic := Control.new()
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func():
		var c := Vector2(56, 28)
		# bloco colorido com brilho em cima e o desenho branco
		ic.draw_style_box(sbox(Color(0, 0, 0, 0.35), 14), Rect2(c - Vector2(22, 19), Vector2(44, 44)))
		ic.draw_style_box(sbox(cc[1], 14), Rect2(c - Vector2(22, 22), Vector2(44, 44)))
		ic.draw_style_box(sbox(cc[0], 14), Rect2(c - Vector2(22, 22), Vector2(44, 34)))
		ic.draw_style_box(sbox(Color(1, 1, 1, 0.22), 10), Rect2(c - Vector2(18, 19), Vector2(36, 10)))
		_glyph(ic, kind, c)
		ic.draw_string(ThemeDB.fallback_font, Vector2(0, 68), text, HORIZONTAL_ALIGNMENT_CENTER, 112, 13, Color(1, 1, 1, 0.92)))
	b.add_child(ic)
	b.pressed.connect(game.play.bind("click", 0.6))
	return b


# desenhos brancos simples (barra de baixo e botões redondos)
func _glyph(c: Control, kind: String, p: Vector2, col: Color = Color.WHITE, k: float = 1.0) -> void:
	var sh := Color(0, 0, 0, 0.25)
	match kind:
		"shop":
			c.draw_style_box(sbox(col, 4), Rect2(p + Vector2(-12, -6) * k, Vector2(24, 18) * k))
			c.draw_arc(p + Vector2(0, -6) * k, 7 * k, PI, TAU, 14, col, 3.0 * k)
			c.draw_circle(p + Vector2(0, 3) * k, 4 * k, sh)
		"inv":
			c.draw_style_box(sbox(col, 3), Rect2(p + Vector2(-13, -2) * k, Vector2(26, 14) * k))
			c.draw_style_box(sbox(col, 8), Rect2(p + Vector2(-13, -12) * k, Vector2(26, 9) * k))
			c.draw_rect(Rect2(p + Vector2(-3, -5) * k, Vector2(6, 7) * k), sh)
		"person":
			c.draw_circle(p + Vector2(0, -6) * k, 6.5 * k, col)
			c.draw_colored_polygon(_arcpoly(p + Vector2(0, 13) * k, 12 * k), col)
		"stats":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -12) * k, p + Vector2(10, -12) * k, p + Vector2(7, 0) * k, p + Vector2(0, 4) * k, p + Vector2(-7, 0) * k]), col)
			c.draw_arc(p + Vector2(-10, -6) * k, 5 * k, PI * 0.5, PI * 1.5, 10, col, 2.5 * k)
			c.draw_arc(p + Vector2(10, -6) * k, 5 * k, -PI * 0.5, PI * 0.5, 10, col, 2.5 * k)
			c.draw_rect(Rect2(p + Vector2(-2, 3) * k, Vector2(4, 6) * k), col)
			c.draw_style_box(sbox(col, 2), Rect2(p + Vector2(-8, 9) * k, Vector2(16, 4) * k))
		"gear":
			var teeth := PackedVector2Array()
			for i in 32:
				var a := float(i) / 32.0 * TAU
				teeth.append(p + Vector2.from_angle(a) * (13.0 if (i / 2) % 2 == 0 else 9.5) * k)
			c.draw_colored_polygon(teeth, col)
			c.draw_circle(p, 4.5 * k, sh.lightened(0.0) if col == Color.WHITE else Color(0, 0, 0, 0.4))
		"ball":
			c.draw_circle(p, 13 * k, Color("141414"))
			c.draw_circle(p, 6.5 * k, Color.WHITE)
			c.draw_string(ThemeDB.fallback_font, p + Vector2(-6, 4.5) * k, "8", HORIZONTAL_ALIGNMENT_CENTER, 12 * k, int(12 * k), Color("141414"))
		"cards":
			for j in 2:
				c.draw_set_transform(p + Vector2(-4 + j * 8, 1) * k, -0.25 + j * 0.5, Vector2.ONE)
				c.draw_style_box(sbox(Color.WHITE, 3, Color(0, 0, 0, 0.3), 1), Rect2(Vector2(-7, -10) * k, Vector2(14, 20) * k))
				c.draw_string(ThemeDB.fallback_font, Vector2(-6, 2) * k, "A" if j == 1 else "7", HORIZONTAL_ALIGNMENT_CENTER, 12 * k, int(11 * k), Color("c0303a") if j == 1 else Color("141414"))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"lobby":
			c.draw_circle(p + Vector2(-4, -5) * k, 5.5 * k, col)
			c.draw_colored_polygon(_arcpoly(p + Vector2(-4, 11) * k, 10 * k), col)
			c.draw_rect(Rect2(p + Vector2(7, -4) * k, Vector2(3, 12) * k), col)
			c.draw_rect(Rect2(p + Vector2(2.5, 0.5) * k, Vector2(12, 3) * k), col)
		"chat":
			c.draw_style_box(sbox(col, 8), Rect2(p + Vector2(-12, -10) * k, Vector2(24, 17) * k))
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 6) * k, p + Vector2(0, 6) * k, p + Vector2(-8, 13) * k]), col)
			for j in 3:
				c.draw_circle(p + Vector2(-6 + j * 6, -1.5) * k, 1.8 * k, Color(0, 0, 0, 0.35))
		"x":
			c.draw_line(p + Vector2(-6, -6) * k, p + Vector2(6, 6) * k, col, 3.0 * k)
			c.draw_line(p + Vector2(6, -6) * k, p + Vector2(-6, 6) * k, col, 3.0 * k)
		"check":
			c.draw_polyline(PackedVector2Array([p + Vector2(-8, 0) * k, p + Vector2(-2, 6) * k, p + Vector2(9, -7) * k]), col, 3.5 * k)
		"copy":
			c.draw_style_box(sbox(Color(0, 0, 0, 0), 3, col, 2), Rect2(p + Vector2(-8, -6) * k, Vector2(12, 14) * k))
			c.draw_style_box(sbox(Color(0, 0, 0, 0), 3, col, 2), Rect2(p + Vector2(-3, -10) * k, Vector2(12, 14) * k))
		"trade":
			c.draw_line(p + Vector2(-10, -5) * k, p + Vector2(8, -5) * k, col, 3.0 * k)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(12, -5) * k, p + Vector2(5, -11) * k, p + Vector2(5, 1) * k]), col)
			c.draw_line(p + Vector2(10, 6) * k, p + Vector2(-8, 6) * k, col, 3.0 * k)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 6) * k, p + Vector2(-5, 0) * k, p + Vector2(-5, 12) * k]), col)
		"search":
			c.draw_arc(p + Vector2(-2, -2) * k, 7 * k, 0, TAU, 20, col, 2.5 * k)
			c.draw_line(p + Vector2(3, 3) * k, p + Vector2(9, 9) * k, col, 3.0 * k)


# botão redondo com desenho e legenda (lista de amigos)
func round_btn(kind: String, col: Color, caption: String, badge: int = 0, w: float = 66.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 64)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", sbox(Color(1, 1, 1, 0.06), 16))
	b.add_theme_stylebox_override("pressed", sbox(Color(1, 1, 1, 0.12), 16))
	var ic := Control.new()
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func():
		var c := Vector2(w / 2.0, 23)
		ic.draw_circle(c + Vector2(0, 3), 21, Color(0, 0, 0, 0.35))
		ic.draw_circle(c, 21, col.darkened(0.25))
		ic.draw_circle(c + Vector2(0, -2), 19, col)
		ic.draw_arc(c, 21, PI * 1.15, PI * 1.85, 12, Color(1, 1, 1, 0.35), 2.0)
		_glyph(ic, kind, c + Vector2(0, -1), Color.WHITE, 0.9)
		if badge > 0:
			ic.draw_circle(c + Vector2(16, -15), 10, Color("e53935"))
			ic.draw_string(ThemeDB.fallback_font, c + Vector2(6, -10), str(badge), HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Color.WHITE)
		if caption != "":
			ic.draw_string(ThemeDB.fallback_font, Vector2(0, 60), caption, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(1, 1, 1, 0.8)))
	b.add_child(ic)
	b.pressed.connect(game.play.bind("click", 0.5))
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
	var sp2 := PanelContainer.new()
	sp2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sp2.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.85), 28, Color(0.96, 0.77, 0.26, 0.45), 2, 10))
	v.add_child(sp2)
	var shh := HBoxContainer.new()
	shh.add_theme_constant_override("separation", 10)
	sp2.add_child(margin(shh, 8))
	var sl := mk_lbl("APOSTA:", 18, Color("f4c542"), 2)
	shh.add_child(sl)
	shh.add_child(stake_row("bet_ai", game.AI_STAKES))
	bet_hint_ai = mk_lbl("", 15, Color("ffe066"), 2)
	bet_hint_ai.custom_minimum_size = Vector2(300, 0)
	shh.add_child(bet_hint_ai)
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
		var gb := mk_btn(k[1], 190, 50, GRAY, 22)
		gb.pressed.connect(_online_game.bind(k[0]))
		online_game_btns[k[0]] = gb
		gs.add_child(gb)
	lv.add_child(_section("MESA"))
	var ts := HBoxContainer.new()
	ts.add_theme_constant_override("separation", 10)
	lv.add_child(ts)
	for k in [[false, "1 CONTRA 1"], [true, "2 CONTRA 2"]]:
		var tb := mk_btn(k[1], 190, 50, GRAY, 20)
		tb.pressed.connect(_online_team.bind(k[0]))
		team_btns[k[0]] = tb
		ts.add_child(tb)
	lv.add_child(_section("CONEXÃO"))
	var cs := HBoxContainer.new()
	cs.add_theme_constant_override("separation", 10)
	lv.add_child(cs)
	for k in [["world", "INTERNET"], ["lan", "MESMO WI-FI"]]:
		var mb := mk_btn(k[1], 190, 50, GRAY, 19)
		mb.pressed.connect(_online_mode.bind(k[0]))
		online_mode_btns[k[0]] = mb
		cs.add_child(mb)
	var lbr := HBoxContainer.new()
	lbr.add_theme_constant_override("separation", 10)
	lv.add_child(lbr)
	lobby_btn = mk_btn("CRIAR LOBBY", 190, 52, Color("8e44ad"), 19)
	lobby_btn.pressed.connect(func(): lobby_create_ask(""))
	lbr.add_child(lobby_btn)
	tour_btn = mk_btn("CRIAR TORNEIO", 190, 52, Color("c0392b"), 19)
	tour_btn.pressed.connect(tour_create_ask)
	lbr.add_child(tour_btn)
	var fb := icon_btn("AMIGOS  •  CONVIDAR", "people", Color("16897f"), 390)
	fb.custom_minimum_size = Vector2(390, 52)
	fb.pressed.connect(show_screen.bind("amigos"))
	lv.add_child(fb)
	lv.add_child(_section("APOSTA (MOEDAS)"))
	lv.add_child(stake_row("bet_on", game.STAKES))
	bet_hint_on = mk_lbl("", 15, Color("ffe066"), 2)
	bet_hint_on.custom_minimum_size = Vector2(390, 0)
	bet_hint_on.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(bet_hint_on)
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
		online_status("Sorteando a chave do torneio..." if bool(lobby.get("tour", false)) else "Montando a mesa com seu lobby..."))
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
var tour_btn: Button
var tour_canvas: Control
var tour_info: Label
var tour_leave_btn: Button
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
		game.net.world_send({"t": "lcreate", "game": sel.g, "four": sel.four, "stake": int(game.save.get("bet_on", 0))}))
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
	if game.tour_active() or cur == "torneio":
		return
	# no meio de uma partida: só guarda o lobby (volta para ele quando a partida acabar)
	if game.net.active or (truco_node != null and is_instance_valid(truco_node)) or (game.mode == game.Mode.ONLINE and game.st != game.St.MENU):
		return
	game.net_game = str(m.get("game", "sinuca"))
	game.net_team = bool(m.get("four", true))
	_stake_paint("bet_on")
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
	if bool(m.get("tour", false)):
		var nm: int = (m.members as Array).size()
		var fee := int(m.get("stake", 0))
		var ft := "sem inscrição" if fee <= 0 else "inscrição %d  •  o campeão leva %d + bônus" % [fee, fee * nm]
		if lobby_leader():
			online_status("TORNEIO de %s: %d de 8 jogadores (mínimo 3)  •  %s. Chame em AMIGOS • LOBBY +." % ["TRUCO" if game.net_game == "truco" else "SINUCA", nm, ft])
		else:
			online_status("Você está no TORNEIO de %s (%d jogadores)  •  %s. Esperando o dono começar." % [_lobby_name(str(m.leader)), nm, ft])
		_online_btn_refresh()
		return
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
	# baixa direto do GitHub (não gasta o tráfego do servidor); o servidor fica de reserva
	upd_alt = str(info.url)
	show_update(nv, str(info.get("apk", info.url)), str(info.get("notas", "")))


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
var upd_alt := ""


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
				# GitHub falhou: tenta pelo servidor do jogo
				var nxt := url
				if upd_alt != "" and upd_alt != url:
					nxt = upd_alt
				upd_lbl.text = "Tentando de novo (%d/3)..." % upd_try
				get_tree().create_timer(2.0).timeout.connect(func(): _update_download(nxt))
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
	var is_t: bool = bool(lobby.get("tour", false))
	lobby_row.add_child(mk_lbl(("TORNEIO %s:" % ("TRUCO" if str(lobby.get("game", "")) == "truco" else "SINUCA")) if is_t else ("LOBBY %s %s:" % ["TRUCO" if str(lobby.get("game", "")) == "truco" else "SINUCA", "2x2" if bool(lobby.get("four", true)) else "1x1"]), 16, Color("ffe066"), 2))
	for o in lobby.members:
		var lead: bool = str(o.code) == str(lobby.leader)
		var me: bool = str(o.code) == game.my_code()
		var nm := str(o.name)
		var mx := 6 if is_t and (lobby.members as Array).size() > 4 else 12
		if nm.length() > mx:
			nm = nm.substr(0, mx - 1) + "…"
		var four_l: bool = bool(lobby.get("four", true)) and not is_t
		var my_t := 0
		for o2 in lobby.members:
			if str(o2.code) == game.my_code():
				my_t = int(o2.get("team", 0))
		var same: bool = int(o.get("team", 0)) == my_t
		var ccol: Color = (Color("1d5c9e") if same else Color("a83232")) if four_l else Color("16897f")
		var txt: String = ("♛ " if lead else "") + (nm + " (você)" if me else nm)
		var oc := str(o.code)
		var onm := str(o.name)
		var fr_mark: String = "" if me or _has("friends", oc) or mx < 12 else "  +"
		if me:
			var chip := PanelContainer.new()
			chip.add_theme_stylebox_override("panel", sbox(ccol, 14, Color("ffe066") if lead else Color(1, 1, 1, 0.3), 2, 0))
			chip.add_child(margin(mk_lbl(txt, 15, Color.WHITE, 2), 6))
			lobby_row.add_child(chip)
		else:
			# tocar no nome abre o perfil (estatísticas) e dá para pedir amizade
			var nb := mk_btn(txt + fr_mark, 0, 36, ccol, 15)
			nb.add_theme_stylebox_override("normal", sbox(ccol, 14, Color("ffe066") if lead else Color(1, 1, 1, 0.3), 2, 6))
			nb.pressed.connect(func(): open_player(oc, onm))
			lobby_row.add_child(nb)
		if lobby_leader() and four_l and not lead:
			# o dono toca no ⇄ para mudar o amigo de time
			var cb := mk_btn("⇄", 44, 36, ccol.darkened(0.25), 17)
			cb.pressed.connect(func(): game.net.world_send({"t": "lteam", "code": oc}))
			lobby_row.add_child(cb)
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
		game.net.world_send({"t": "lset", "game": game.net_game, "four": game.net_team, "stake": int(game.save.get("bet_on", 0))})
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
	if in_lobby() and bool(lobby.get("tour", false)):
		_lobby_leave()
		return
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
	var tourl: bool = in_lobby() and bool(lobby.get("tour", false))
	if tour_btn != null:
		tour_btn.visible = not in_lobby()
	if tourl and start_btn != null:
		var nt: int = (lobby.get("members", []) as Array).size()
		start_btn.visible = lobby_leader()
		start_btn.disabled = nt < 3
		start_btn.text = ("COMEÇAR TORNEIO (%d)" % nt) if nt >= 3 else "CHAME MAIS AMIGOS (%d/3)" % nt
		if lobby_btn != null:
			lobby_btn.visible = false
		search_btn.text = "CANCELAR TORNEIO" if lobby_leader() else "SAIR DO TORNEIO"
		search_btn.add_theme_stylebox_override("normal", sbox(GRAY, 20, GRAY.lightened(0.35), 3, 8))
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
	# cartão com o seu avatar, nome e código
	var me := Control.new()
	me.custom_minimum_size = Vector2(324, 150)
	me.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		me.draw_style_box(sbox(Color(0.1, 0.16, 0.28, 0.95), 20, Color(1, 1, 1, 0.12), 1), Rect2(0, 0, 324, 150))
		me.draw_style_box(sbox(Color(0.18, 0.3, 0.55, 0.55), 20), Rect2(0, 0, 324, 56))
		AV.draw(me, Vector2(52, 62), 38, str(game.save.get("av", "b8")), str(game.save.get("frame", "simples")), anim_t)
		me.draw_string(f, Vector2(102, 52), game.my_name(), HORIZONTAL_ALIGNMENT_LEFT, 214, 24, Color.WHITE)
		var ti: Dictionary = AV.find(AV.TITLES, str(game.save.get("title", "novato")))
		me.draw_string(f, Vector2(102, 76), str(ti.name), HORIZONTAL_ALIGNMENT_LEFT, 214, 15, Color("f4c542"))
		me.draw_string(f, Vector2(16, 112), "SEU CÓDIGO", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(1, 1, 1, 0.55))
		me.draw_string(f, Vector2(16, 138), game.my_code(), HORIZONTAL_ALIGNMENT_LEFT, 200, 22, Color("ffe066")))
	lv.add_child(me)
	var cl := Label.new()
	cl.name = "MyCode"
	cl.visible = false
	lv.add_child(cl)
	var cpb := round_btn("copy", Color("16897f"), "")
	cpb.custom_minimum_size = Vector2(56, 48)
	cpb.position = Vector2(258, 100)
	cpb.pressed.connect(func():
		DisplayServer.clipboard_set(game.my_code())
		say("Código copiado! Mande para seus amigos."))
	me.add_child(cpb)
	lv.add_child(_section("ADICIONAR AMIGO"))
	friend_edit = LineEdit.new()
	friend_edit.placeholder_text = "nome ou código"
	friend_edit.max_length = 16
	friend_edit.custom_minimum_size = Vector2(320, 52)
	friend_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	friend_edit.add_theme_font_size_override("font_size", 22)
	friend_edit.add_theme_stylebox_override("normal", sbox(Color(0.02, 0.05, 0.09, 0.95), 14, Color(1, 1, 1, 0.35), 2, 0))
	friend_edit.add_theme_stylebox_override("focus", sbox(Color(0.02, 0.05, 0.09, 0.95), 14, Color("5aa9ff"), 3, 0))
	lv.add_child(friend_edit)
	friend_edit.text_submitted.connect(func(_t): _friend_search())
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	lv.add_child(brow)
	var sb := mk_btn("BUSCAR NOME", 156, 50, BLUE, 17)
	sb.pressed.connect(_friend_search)
	brow.add_child(sb)
	var ab := mk_btn("PEDIR CÓDIGO", 156, 50, GREEN, 17)
	ab.pressed.connect(_friend_add)
	brow.add_child(ab)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp)
	var back := mk_btn("◀  VOLTAR", 320, 54, GRAY, 22)
	back.pressed.connect(func(): show_screen("online" if _came_from_online else "main"))
	lv.add_child(back)
	# ---- coluna direita: resultados da busca + lista de amigos (rola com o dedo)
	var rp := PanelContainer.new()
	rp.custom_minimum_size = Vector2(780, 470)
	rp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.88), 26, Color(1, 1, 1, 0.18), 2, 12))
	body.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rp.add_child(margin(rv, 14))
	fr_head = Control.new()
	fr_head.custom_minimum_size = Vector2(740, 40)
	fr_head.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		fr_head.draw_string(f, Vector2(4, 30), "MEUS AMIGOS", HORIZONTAL_ALIGNMENT_LEFT, 300, 24, Color("f4c542"))
		var tot: int = (game.save.friends as Array).size()
		var pill := "● %d online" % friends_online
		fr_head.draw_style_box(sbox(Color(0.12, 0.4, 0.22, 0.9), 14), Rect2(210, 8, 120, 28))
		fr_head.draw_string(f, Vector2(210, 28), pill, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color("b8ffcf"))
		fr_head.draw_string(f, Vector2(0, 28), "%d amigos" % tot, HORIZONTAL_ALIGNMENT_RIGHT, 736, 15, Color(1, 1, 1, 0.55))
		fr_head.draw_line(Vector2(0, 39), Vector2(740, 39), Color(1, 1, 1, 0.1), 1.0))
	rv.add_child(fr_head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(sc)
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
	for p0 in list:
		if p0.has("av"):
			friend_av[str(p0.code)] = [str(p0.av), str(p0.get("fr", "simples"))]
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
	if fr_head != null:
		fr_head.queue_redraw()
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
		friends_box.add_child(_flist_head("PEDIDOS DE AMIZADE  •  %d" % fin.size(), Color("f4c542")))
		for q in fin:
			var rq := PanelContainer.new()
			rq.add_theme_stylebox_override("panel", sbox(Color(0.12, 0.09, 0.02, 0.92), 18, Color("f4c542"), 2, 4))
			friends_box.add_child(rq)
			var qh := HBoxContainer.new()
			qh.add_theme_constant_override("separation", 12)
			rq.add_child(margin(qh, 10))
			var ql := mk_lbl("%s  quer ser seu amigo" % str(q.name), 20, Color.WHITE, 2)
			ql.custom_minimum_size = Vector2(520, 0)
			ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			qh.add_child(ql)
			var qa := round_btn("check", GREEN, "ACEITAR", 0, 78)
			qa.pressed.connect(_friend_accept.bind(str(q.code), str(q.name)))
			qh.add_child(qa)
			var qr := round_btn("x", Color("6a3038"), "RECUSAR", 0, 78)
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
		row.add_theme_stylebox_override("panel", sbox(Color(0.06, 0.1, 0.17, 0.96) if online else Color(0.035, 0.05, 0.08, 0.88), 20, Color(dc.r, dc.g, dc.b, 0.55) if online else Color(1, 1, 1, 0.07), 2, 6))
		friends_box.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		row.add_child(margin(hb, 8))
		# avatar com a inicial e a bolinha de status
		var av := Control.new()
		av.custom_minimum_size = Vector2(58, 58)
		var nm := str(f.name)
		var hue := float(hash(str(f.code)) % 360) / 360.0
		var acol := Color.from_hsv(hue, 0.55, 0.75 if online else 0.4)
		var avcode := str(f.code)
		av.draw.connect(func():
			if friend_av.has(avcode):
				AV.draw(av, Vector2(29, 29), 28, str(friend_av[avcode][0]), str(friend_av[avcode][1]))
				if not online:
					av.draw_circle(Vector2(29, 29), 28, Color(0, 0, 0, 0.45))
			else:
				av.draw_circle(Vector2(29, 29), 27, acol)
				av.draw_arc(Vector2(29, 29), 27, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
				var fnt: Font = ThemeDB.fallback_font
				av.draw_string(fnt, Vector2(0, 40), nm.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 58, 30, Color.WHITE)
			av.draw_circle(Vector2(49, 49), 9, Color(0.03, 0.05, 0.08))
			av.draw_circle(Vector2(49, 49), 6.5, dc))
		# tocar no avatar abre o perfil do amigo
		var avb := Button.new()
		avb.flat = true
		avb.focus_mode = Control.FOCUS_NONE
		for st2 in ["normal", "hover", "pressed", "focus"]:
			avb.add_theme_stylebox_override(st2, StyleBoxEmpty.new())
		avb.set_anchors_preset(Control.PRESET_FULL_RECT)
		avb.pressed.connect(func():
			game.net.world_send({"t": "prof", "code": avcode})
			say("Abrindo perfil..."))
		av.add_child(avb)
		hb.add_child(av)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", -2)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_child(nv)
		var nl := mk_lbl(nm, 22, Color.WHITE if online else Color(1, 1, 1, 0.7), 2)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nv.add_child(nl)
		# selo de status
		var stt: String = {"online": "ONLINE", "procurando": "PROCURANDO", "jogando": "JOGANDO"}.get(status, "OFFLINE")
		var pill := Control.new()
		pill.custom_minimum_size = Vector2(240, 22)
		pill.draw.connect(func():
			var f2: Font = ThemeDB.fallback_font
			var tw: float = f2.get_string_size(stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 26.0
			pill.draw_style_box(sbox(Color(dc.r, dc.g, dc.b, 0.2), 10, Color(dc.r, dc.g, dc.b, 0.6), 1), Rect2(0, 2, tw, 19))
			pill.draw_circle(Vector2(10, 11.5), 4, dc)
			pill.draw_string(f2, Vector2(18, 16), stt, HORIZONTAL_ALIGNMENT_LEFT, 200, 12, dc.lightened(0.3)))
		nv.add_child(pill)
		var can := online and status != "jogando"
		if can:
			hb.add_child(_fr_btn(round_btn("ball", Color("1b8f4c"), "SINUCA"), _invite.bind(str(f.code), "sinuca", false)))
			hb.add_child(_fr_btn(round_btn("cards", Color("b8323a"), "TRUCO"), _invite.bind(str(f.code), "truco", false)))
			var inl := false
			for o in lobby.get("members", []):
				if str(o.code) == str(f.code):
					inl = true
			var lb := round_btn("check" if inl else "lobby", GRAY if inl else Color("8e44ad"), "NO LOBBY" if inl else "LOBBY")
			lb.disabled = inl
			hb.add_child(_fr_btn(lb, _invite.bind(str(f.code), "", true)))
			var tcode := str(f.code)
			var tnm := nm
			hb.add_child(_fr_btn(round_btn("trade", Color("d68a10"), "NEGOCIAR"), func(): game.trade.start_with(tcode, tnm)))
		elif status == "jogando":
			hb.add_child(mk_lbl("em partida...", 15, Color("ffb020"), 2))
		# conversa (funciona até com o amigo offline: ele recebe quando entrar)
		var un: int = int(game.save.get("chat_unread", {}).get(str(f.code), 0))
		var fc2 := str(f.code)
		var fn2 := nm
		hb.add_child(_fr_btn(round_btn("chat", Color("e67e22") if un > 0 else Color("2f7fd6"), "MSG", un), func(): open_pm(fc2, fn2)))
		var rb := round_btn("x", Color("3a2a30"), "", 0, 50)
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
	var stk := 0 if to_lobby else int(game.save.get("bet_on", 0))
	game.net.world_send({"t": "invite", "code": code, "game": g, "lobby": to_lobby, "stake": stk})
	say("Enviando convite..." if stk <= 0 else "Enviando convite (valendo %d moedas)..." % stk)


func show_invite(from: String, nm: String, g: String, to_lobby := false, stake := 0, is_tour := false) -> void:
	for c in invite_box.get_children():
		c.queue_free()
	invite_box.add_child(mk_lbl("CONVITE!", 34, Color("f4c542"), 6))
	if to_lobby and is_tour:
		invite_box.add_child(mk_lbl("%s te chamou para um TORNEIO de %s" % [nm, "TRUCO" if g == "truco" else "SINUCA"], 22, Color.WHITE, 3))
		invite_box.add_child(mk_lbl("Mata-mata 1x1 até sair o campeão." + ("" if stake <= 0 else "  Inscrição: %d moedas." % stake), 17, Color("ffe066"), 2))
	elif to_lobby:
		invite_box.add_child(mk_lbl("%s te chamou para o LOBBY de %s" % [nm, "TRUCO" if g == "truco" else "SINUCA"], 22, Color.WHITE, 3))
		invite_box.add_child(mk_lbl("Vocês procuram mesa juntos, no mesmo time (2 contra 2).", 17, Color(1, 1, 1, 0.75), 2))
	else:
		invite_box.add_child(mk_lbl("%s te chamou para um x1 de %s" % [nm, "TRUCO" if g == "truco" else "SINUCA"], 22, Color.WHITE, 3))
		if stake > 0:
			invite_box.add_child(mk_lbl("APOSTA: %d moedas cada  •  quem ganhar leva %d" % [stake, stake * 2], 19, Color("ffe066"), 3))
			if int(game.save.coins) < stake:
				invite_box.add_child(mk_lbl("Você não tem moedas suficientes para essa aposta.", 16, Color("ff8a80"), 2))
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
		game.net.world_send({"t": "accept", "from": from, "game": g, "lobby": to_lobby, "stake": stake, "coins": int(game.save.coins)}))
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
	var tsp := PanelContainer.new()
	tsp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tsp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.85), 28, Color(0.96, 0.77, 0.26, 0.45), 2, 10))
	v.add_child(tsp)
	var tsh := HBoxContainer.new()
	tsh.add_theme_constant_override("separation", 10)
	tsp.add_child(margin(tsh, 8))
	tsh.add_child(mk_lbl("APOSTA CONTRA A IA:", 17, Color("f4c542"), 2))
	tsh.add_child(stake_row("bet_tr", [0, 50, 100]))
	bet_hint_tr = mk_lbl("", 15, Color("ffe066"), 2)
	bet_hint_tr.custom_minimum_size = Vector2(250, 0)
	tsh.add_child(bet_hint_tr)
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


func open_truco(players: int, tut: bool = false) -> void:
	show_screen("")
	dim.visible = false
	game.paused = true
	if truco_node != null and is_instance_valid(truco_node):
		truco_node.queue_free()
	truco_node = load("res://truco.gd").new()
	truco_node.tut = tut
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
	call_deferred("_stake_paint", "bet_ai")
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
	var scr := mk_screen("roleta", 6)
	add_bg("roleta", "res://assets/menu_bg.jpg", 0.35)
	var row0 := HBoxContainer.new()
	row0.add_theme_constant_override("separation", 30)
	row0.alignment = BoxContainer.ALIGNMENT_CENTER
	scr.add_child(row0)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(520, 560)
	row0.add_child(holder)
	# raios de luz girando atrás da roleta
	wheel_rays = Control.new()
	wheel_rays.size = Vector2(700, 700)
	wheel_rays.position = Vector2(260 - 350, 300 - 350)
	wheel_rays.pivot_offset = Vector2(350, 350)
	wheel_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_rays.draw.connect(func():
		var c := Vector2(350, 350)
		for k in 18:
			var a0 := float(k) * TAU / 18.0
			wheel_rays.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0 - 0.08) * 350.0, c + Vector2.from_angle(a0 + 0.08) * 350.0]), Color(1.0, 0.85, 0.4, 0.05))
		for k in 5:
			wheel_rays.draw_circle(c, 120.0 + k * 45.0, Color(1.0, 0.8, 0.3, 0.025)))
	holder.add_child(wheel_rays)
	# base (pé) da roleta
	var base := Control.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.draw.connect(func():
		var bc := Vector2(260, 520)
		base.draw_colored_polygon(PackedVector2Array([bc + Vector2(-70, -60), bc + Vector2(70, -60), bc + Vector2(110, 26), bc + Vector2(-110, 26)]), Color("5a3a12"))
		base.draw_colored_polygon(PackedVector2Array([bc + Vector2(-60, -60), bc + Vector2(60, -60), bc + Vector2(92, 18), bc + Vector2(-92, 18)]), Color("8a5a1c"))
		base.draw_style_box(sbox(Color("f4c542"), 8, Color("8a5a10"), 2), Rect2(bc + Vector2(-120, 18), Vector2(240, 18))))
	holder.add_child(base)
	wheel = Control.new()
	wheel.size = Vector2(440, 440)
	wheel.position = Vector2(40, 80)
	wheel.pivot_offset = Vector2(220, 220)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel.draw.connect(_draw_wheel)
	holder.add_child(wheel)
	# aro dourado com luzes piscando, ponteiro e o botão do meio (não giram)
	wheel_rim = Control.new()
	wheel_rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_rim.draw.connect(_draw_wheel_rim)
	holder.add_child(wheel_rim)
	var hub := Button.new()
	hub.flat = true
	hub.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		hub.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hub.position = Vector2(260 - 58, 300 - 58)
	hub.size = Vector2(116, 116)
	hub.pressed.connect(_spin)
	holder.add_child(hub)
	# ---- painel da direita
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.05, 0.1, 0.92), 28, Color(0.96, 0.77, 0.26, 0.6), 2, 16))
	row0.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	rv.custom_minimum_size = Vector2(430, 0)
	rp.add_child(margin(rv, 22))
	var tt := Control.new()
	tt.custom_minimum_size = Vector2(430, 70)
	tt.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		tt.draw_string_outline(f, Vector2(0, 44), "ROLETA DIÁRIA", HORIZONTAL_ALIGNMENT_CENTER, 430, 40, 8, Color("3a2402"))
		tt.draw_string(f, Vector2(0, 44), "ROLETA DIÁRIA", HORIZONTAL_ALIGNMENT_CENTER, 430, 40, Color("f7c33a"))
		tt.draw_string(f, Vector2(0, 66), "1 giro grátis por dia  •  giros extras no Passe", HORIZONTAL_ALIGNMENT_CENTER, 430, 15, Color(1, 1, 1, 0.6)))
	rv.add_child(tt)
	rv.add_child(_section("PRÊMIOS POSSÍVEIS"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	rv.add_child(grid)
	var tot := 0
	for w in game.WHEEL:
		tot += int(w[2])
	var order := range(game.WHEEL.size())
	order.sort_custom(func(a, b): return (int(game.WHEEL[a][1]) * (40 if game.WHEEL[a][0] == "g" else 1)) > (int(game.WHEEL[b][1]) * (40 if game.WHEEL[b][0] == "g" else 1)))
	for i in order:
		var w: Array = game.WHEEL[i]
		var chance := float(w[2]) / float(tot)
		var rar := "LENDÁRIO" if chance <= 0.03 else ("ÉPICO" if chance <= 0.07 else ("RARO" if chance <= 0.13 else "COMUM"))
		var rc: Color = {"LENDÁRIO": Color("ffd34a"), "ÉPICO": Color("c084ff"), "RARO": Color("5aa9ff"), "COMUM": Color(1, 1, 1, 0.6)}[rar]
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(210, 44)
		var isg: bool = w[0] == "g"
		var val := int(w[1])
		cell.draw.connect(func():
			var f: Font = ThemeDB.fallback_font
			cell.draw_style_box(sbox(Color(1, 1, 1, 0.05), 12, Color(rc.r, rc.g, rc.b, 0.4), 1), Rect2(0, 0, 210, 44))
			if isg:
				_gem(cell, Vector2(24, 22), 12)
			else:
				_coin(cell, Vector2(24, 22), 12)
			cell.draw_string(f, Vector2(44, 21), ("%d GRANA" % val) if isg else ("%d moedas" % val), HORIZONTAL_ALIGNMENT_LEFT, 160, 17, Color.WHITE)
			cell.draw_string(f, Vector2(44, 38), rar, HORIZONTAL_ALIGNMENT_LEFT, 160, 11, rc))
		grid.add_child(cell)
	spin_lbl = mk_lbl("", 17, Color(1, 1, 1, 0.85), 3)
	spin_lbl.custom_minimum_size = Vector2(430, 48)
	spin_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(spin_lbl)
	spin_btn = mk_btn("GIRAR", 430, 66, GREEN, 30)
	spin_btn.pressed.connect(_spin)
	rv.add_child(spin_btn)
	var back := mk_btn("◀  VOLTAR", 430, 54, GRAY, 22)
	back.pressed.connect(func():
		if not spinning:
			show_screen("main"))
	rv.add_child(back)


func _coin(c: CanvasItem, p: Vector2, r: float) -> void:
	draw_coin(c, p, r)


func _gem(c: CanvasItem, p: Vector2, r: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-r, -r * 0.3), p + Vector2(-r * 0.5, -r * 0.85), p + Vector2(r * 0.5, -r * 0.85), p + Vector2(r, -r * 0.3), p + Vector2(0, r)])
	c.draw_colored_polygon(pts, Color("a463ff"))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.5, -r * 0.85), p + Vector2(r * 0.5, -r * 0.85), p + Vector2(r * 0.25, -r * 0.3), p + Vector2(-r * 0.25, -r * 0.3)]), Color("e2c4ff"))
	c.draw_line(p + Vector2(-r, -r * 0.3), p + Vector2(r, -r * 0.3), Color(1, 1, 1, 0.5), 1.0)


func _draw_wheel() -> void:
	var c := Vector2(220, 220)
	var n: int = game.WHEEL.size()
	var step := TAU / float(n)
	var f: Font = ThemeDB.fallback_font
	var R := 196.0
	var pal := [[Color("2f7fd6"), Color("16407a")], [Color("1fa85a"), Color("0d5a30")], [Color("e05050"), Color("7a1c1c")], [Color("f2a91f"), Color("8a5208")], [Color("ff8a3d"), Color("8a3a0a")], [Color("17a3a3"), Color("0a4f55")]]
	for i in n:
		var a0 := float(i) * step - PI / 2.0
		var w: Array = game.WHEEL[i]
		var cc: Array = pal[i % pal.size()]
		if w[0] == "g":
			cc = [Color("9b4dff"), Color("3d1478")]
		elif int(w[1]) >= 1000:
			cc = [Color("2b2b33"), Color("09090c")]
		# fatia com degradê: escura no meio, clara na borda
		for ring in 6:
			var r0 := R * float(ring) / 6.0
			var r1 := R * float(ring + 1) / 6.0
			var col: Color = (cc[1] as Color).lerp(cc[0], float(ring) / 5.0)
			var pts := PackedVector2Array()
			for k in 11:
				pts.append(c + Vector2.from_angle(a0 + step * float(k) / 10.0) * r1)
			for k in 11:
				pts.append(c + Vector2.from_angle(a0 + step * float(10 - k) / 10.0) * r0)
			wheel.draw_colored_polygon(pts, col)
		wheel.draw_line(c, c + Vector2.from_angle(a0) * R, Color(1, 0.9, 0.6, 0.85), 3.0)
		var mid := a0 + step / 2.0
		wheel.draw_set_transform(c, mid + PI / 2.0, Vector2.ONE)
		var big: bool = int(w[1]) >= 1000 and w[0] != "g"
		if w[0] == "g":
			_gem(wheel, Vector2(0, -150), 17)
		else:
			_coin(wheel, Vector2(0, -150), 16 if not big else 19)
		var txt: String = str(int(w[1])) if not big else "1K"
		var tc := Color.WHITE if not big else Color("ffd34a")
		wheel.draw_string_outline(f, Vector2(-60, -100), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, 7, Color(0, 0, 0, 0.55))
		wheel.draw_string(f, Vector2(-60, -100), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, tc)
		wheel.draw_string(f, Vector2(-60, -80), "GRANA" if w[0] == "g" else "MOEDAS", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 1, 1, 0.75))
		wheel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# brilho de vidro por cima
	wheel.draw_arc(c, R * 0.82, PI * 1.08, PI * 1.62, 30, Color(1, 1, 1, 0.08), R * 0.3)


func _draw_wheel_rim() -> void:
	var c := Vector2(260, 300)
	var rc := wheel_rim
	var t := anim_t
	rc.draw_arc(c + Vector2(0, 8), 214, 0, TAU, 80, Color(0, 0, 0, 0.35), 26)
	rc.draw_arc(c, 212, 0, TAU, 80, Color("8a5a10"), 26)
	rc.draw_arc(c, 214, 0, TAU, 80, Color("f4c542"), 20)
	rc.draw_arc(c, 223, 0, TAU, 80, Color("fff0b0"), 2)
	rc.draw_arc(c, 204, 0, TAU, 80, Color("b07d12"), 3)
	# lâmpadas piscando (mais rápido enquanto gira)
	var sp := 9.0 if spinning else 3.0
	for i in 24:
		var p := c + Vector2.from_angle(float(i) * TAU / 24.0 - PI / 2.0) * 214.0
		var on := (int(t * sp) + i) % 2 == 0
		rc.draw_circle(p, 8.5, Color(0, 0, 0, 0.3))
		rc.draw_circle(p, 6.5, Color("fff6c8") if on else Color("c98a12"))
		if on:
			rc.draw_circle(p, 11, Color(1, 0.95, 0.6, 0.25))
	# ponteiro
	var pc := c + Vector2(0, -222)
	var tilt := wheel_tick * 0.45
	rc.draw_set_transform(pc, tilt, Vector2.ONE)
	rc.draw_colored_polygon(PackedVector2Array([Vector2(-24, -22), Vector2(24, -22), Vector2(0, 34)]), Color(0, 0, 0, 0.35))
	rc.draw_colored_polygon(PackedVector2Array([Vector2(-22, -26), Vector2(22, -26), Vector2(0, 30)]), Color("c0392b"))
	rc.draw_colored_polygon(PackedVector2Array([Vector2(-22, -26), Vector2(0, -26), Vector2(0, 30)]), Color("e74c3c"))
	rc.draw_polyline(PackedVector2Array([Vector2(-22, -26), Vector2(22, -26), Vector2(0, 30), Vector2(-22, -26)]), Color("fff0b0"), 3.0)
	rc.draw_circle(Vector2(0, -14), 7, Color("f4c542"))
	rc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# botão do meio
	var can: bool = game.can_spin() and not spinning
	var pulse := 1.0 + (0.05 * sin(t * 5.0) if can else 0.0)
	rc.draw_circle(c + Vector2(0, 5), 60 * pulse, Color(0, 0, 0, 0.4))
	rc.draw_circle(c, 60 * pulse, Color("8a5a10"))
	rc.draw_circle(c, 55 * pulse, Color("f4c542"))
	rc.draw_circle(c, 46 * pulse, Color("1fa85a") if can else Color("3b4556"))
	rc.draw_arc(c, 46 * pulse, PI * 1.1, PI * 1.9, 20, Color(1, 1, 1, 0.3), 4)
	var f: Font = ThemeDB.fallback_font
	rc.draw_string_outline(f, c + Vector2(-50, 9), "GIRAR" if can else ("..." if spinning else "AMANHÃ"), HORIZONTAL_ALIGNMENT_CENTER, 100, 22 if can or spinning else 17, 5, Color(0, 0, 0, 0.45))
	rc.draw_string(f, c + Vector2(-50, 9), "GIRAR" if can else ("..." if spinning else "AMANHÃ"), HORIZONTAL_ALIGNMENT_CENTER, 100, 22 if can or spinning else 17, Color.WHITE)


func _roleta_refresh() -> void:
	var ex: int = int(game.save.get("spins", 0))
	if game.can_spin():
		var daily: bool = str(game.save.spin_day) != game.today_str()
		spin_lbl.text = ("Giro grátis de hoje disponível!" if daily else "Usando giro extra do Passe.") + ("   •   Giros extras: %d" % ex if ex > 0 else "")
		spin_btn.disabled = false
		spin_btn.text = "GIRAR"
	else:
		var tm := Time.get_time_dict_from_system()
		var left := (23 - int(tm.hour)) * 3600 + (59 - int(tm.minute)) * 60 + (60 - int(tm.second))
		spin_lbl.text = "Você já girou hoje. Próximo giro grátis em %dh %02dmin." % [left / 3600, (left % 3600) / 60]
		spin_btn.disabled = true
		spin_btn.text = "AMANHÃ"


func _spin() -> void:
	if spinning or not game.can_spin():
		return
	spinning = true
	spin_btn.disabled = true
	var i: int = game.spin_pick()
	var txt: String = game.spin_award(i)
	game.mission_event("spin", 1)
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
	for k in [["felt", "MESAS"], ["rail", "BORDAS"], ["cue", "TACOS"], ["elite", "★ ELITE"], ["deck", "BARALHOS"], ["wfx", "EFEITOS"], ["pack", "PACOTES"]]:
		var b := mk_btn(k[1], 152, 54, GRAY, 20)
		b.pressed.connect(_shop_tab.bind(k[0]))
		tab_btns[k[0]] = b
		tabs.add_child(b)
	for k in [["cue", "TACOS"], ["felt", "MESAS"], ["rail", "BORDAS"], ["deck", "BARALHOS"], ["wfx", "EFEITOS"]]:
		var sb := mk_btn(k[1], 190, 54, GRAY, 22)
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
	var rc := rare_color(str(it.rare))
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
	month_box.add_child(_stat_row("Mira", float(it.aim)))
	month_box.add_child(_stat_row("Força", float(it.pow)))
	month_box.add_child(_stat_row("Precisão", float(it.prec)))
	month_box.add_child(_stat_row("Efeito", float(it.spin)))
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
	game.eco(-price, 0, "compra")
	game.save.owned.append(id)
	game.write_save()
	refresh_top()
	_month_equip(id)
	say("Taco do mês comprado!")


func _shop_nudge(dir: int) -> void:
	var tw := create_tween()
	tw.tween_property(shop_scroll, "scroll_horizontal", clampi(shop_scroll.scroll_horizontal + dir * 460, 0, 100000), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	anim_t += delta
	if cur == "roleta" and wheel_rim != null:
		wheel_rays.rotation += delta * 0.15
		# ponteiro bate em cada divisão da roleta
		var n: int = game.WHEEL.size()
		var seg := int(floor(fposmod(-wheel.rotation, TAU) / (TAU / float(n)) + 0.5))
		if spinning and seg != wheel_last_seg:
			wheel_tick = 1.0
			game.play("click", 0.35)
		wheel_last_seg = seg
		wheel_tick = maxf(0.0, wheel_tick - delta * 8.0)
		wheel_rim.queue_redraw()
	if top_av != null and topbar.visible:
		var fr := str(game.save.get("frame", ""))
		if fr == "mestre" or fr == "fogo" or str(game.save.get("av", "")) == "fire":
			top_av.queue_redraw()
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
var tfx_btn: Button
var micb_btn: Button
var _synth_release := false


# arrastar o dedo em cima dos botões rola a lista (e não aperta o botão)
func _input(e: InputEvent) -> void:
	var sv: ScrollContainer = shop_scroll if (cur == "shop" or cur == "inv") else (pass_scroll if cur == "passe" else null)
	var vert := false
	if cur == "amigos" and not has_modal():
		sv = friends_scroll
		vert = true
	elif (cur == "perfil" or cur == "ranking") and not has_modal() and page_scroll != null and is_instance_valid(page_scroll) and page_scroll.is_visible_in_tree():
		sv = page_scroll
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


func rare_color(r: String) -> Color:
	match r:
		"LENDÁRIO":
			return Color("ffb21a")
		"MÍTICO":
			return Color("c070ff")
		"DIVINO":
			return Color("ff6af0")
	return Color("4fc3ff")


func _stat_row(label: String, val: float) -> Control:
	# barra contínua + porcentagem (cada ponto do taco = 20%; tacos ELITE passam de 100%, até 150%)
	var c := Control.new()
	c.custom_minimum_size = Vector2(212, 20)
	var f: Font = ThemeDB.fallback_font
	var pct: int = int(round(clampf(val, 0.0, 7.5) * 20.0))
	var fn := func():
		c.draw_string(f, Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, 74, 14, Color(1, 1, 1, 0.85))
		var bx := 76.0
		var bw := 92.0
		c.draw_rect(Rect2(bx, 5, bw, 11), Color(1, 1, 1, 0.12), true)
		var col := Color("4cd37b") if pct >= 60 else (Color("f4c542") if pct >= 40 else Color("e0733a"))
		if pct > 0:
			c.draw_rect(Rect2(bx, 5, bw * minf(float(pct), 100.0) / 100.0, 11), col, true)
		if pct > 100:
			# parte acima de 100%: faixa dourada/rosa por cima, com um brilho andando
			var ex := float(pct - 100) / 50.0
			c.draw_rect(Rect2(bx, 5, bw * ex, 11), Color("ffcf3a"), true)
			c.draw_rect(Rect2(bx, 5, bw * ex, 4), Color(1, 1, 1, 0.45), true)
		for k in range(1, 5):
			c.draw_line(Vector2(bx + bw * k / 5.0, 5), Vector2(bx + bw * k / 5.0, 16), Color(0, 0, 0, 0.35), 1.0)
		c.draw_string(f, Vector2(bx + bw + 6, 15), "%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, 44, 14, Color("ffcf3a") if pct > 100 else Color.WHITE)
	c.draw.connect(fn)
	return c


func _shop_refresh() -> void:
	fx_nodes.clear()
	for c in shop_row.get_children():
		c.queue_free()
	var items: Array = []
	var owned_l: Array = game.save.owned
	if shop_tab == "pack":
		_packs_render()
		return
	var srcmap := {"cue": game.CUES + game.MONTHLY + game.ELITE, "elite": game.ELITE, "rail": game.RAILS, "deck": game.DECKS, "felt": game.FELTS, "wfx": game.WFX}
	if shop_tab == "inv":
		var src: Array = srcmap.get(inv_sub, game.FELTS)
		for it in src:
			if owned_l.has(it.id) or int(it.get("price", 1)) == 0 and (str(it.id).begins_with("dk_") or str(it.id).begins_with("wf_") or str(it.id).begins_with("rb_")):
				items.append(it)
	else:
		var src2: Array = game.CUES if shop_tab == "cue" else srcmap.get(shop_tab, game.FELTS)
		for it in src2:
			if not owned_l.has(it.id) and it.id != "dk_classico" and it.id != "wf_confete" and it.id != "rb_padrao":
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
		var is_wfx: bool = it.has("wfx")
		var is_rail: bool = str(it.id).begins_with("rb_")
		var equipped: String = game.save.cue if is_cue else ("dk_" + str(game.save.get("deck", "classico")) if is_deck else (str(game.save.get("wfx", "wf_confete")) if is_wfx else (str(game.save.get("rail", "rb_padrao")) if is_rail else game.save.felt)))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(212, 404)
		card.add_theme_stylebox_override("panel", sbox(NAVY, 22, Color(1, 1, 1, 0.22) if it.id != equipped else GOLD, 3 if it.id != equipped else 5, 10))
		if is_cue and it.has("rare") and str(it.id).begins_with("e_"):
			var rcol: Color = rare_color(str(it.rare))
			card.add_theme_stylebox_override("panel", sbox(Color(0.04, 0.03, 0.09), 22, GOLD if it.id == equipped else rcol, 5 if it.id == equipped else 3, 10))
		shop_row.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		card.add_child(margin(vb, 14))
		var pv := Control.new()
		pv.custom_minimum_size = Vector2(184, 150)
		pv.clip_contents = true
		if is_cue:
			_cue_preview(pv, it, Vector2(60, 100), 140.0, -40.0, 22.0, 0.85, fx_nodes)
			if it.has("rare"):
				var rt := mk_lbl(str(it.rare), 14, rare_color(str(it.rare)), 4)
				rt.position = Vector2(4, 2)
				pv.add_child(rt)
		elif is_deck:
			_deck_preview(pv, str(it.deck))
		elif is_wfx:
			_wfx_preview(pv, str(it.wfx))
		elif is_rail:
			_rail_preview(pv, it, game.felt_def())
		else:
			_rail_preview(pv, game.rail_for(str(it.get("rail", ""))), it)
		vb.add_child(pv)
		vb.add_child(mk_lbl(it.name, 24, Color.WHITE, 4))
		if is_cue:
			vb.add_child(_stat_row("Mira", float(it.aim)))
			vb.add_child(_stat_row("Força", float(it.pow)))
			vb.add_child(_stat_row("Precisão", float(it.prec)))
			vb.add_child(_stat_row("Efeito", float(it.spin)))
		else:
			var tg := mk_lbl(it.tag, 16, Color(1, 1, 1, 0.65))
			tg.custom_minimum_size = Vector2(184, 0)
			tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(tg)
		var owned: bool = game.save.owned.has(it.id) or it.id == "dk_classico" or it.id == "wf_confete" or it.id == "rb_padrao"
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


# miniatura de mesa com a borda (madeira/laca/metal/carbono) e luz animada se tiver
func _rail_preview(pv: Control, rd: Dictionary, felt: Dictionary) -> void:
	var wood := ColorRect.new()
	wood.position = Vector2(0, 8)
	wood.size = Vector2(184, 112)
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/wood.gdshader")
	wm.set_shader_parameter("size", Vector2(184, 112) * 2.6)
	wm.set_shader_parameter("c1", rd.get("c1", Color(0.45, 0.25, 0.1)))
	wm.set_shader_parameter("c2", rd.get("c2", Color(0.2, 0.1, 0.04)))
	wm.set_shader_parameter("trim", rd.get("trim", Color(0.86, 0.68, 0.32)))
	wm.set_shader_parameter("mat", int(rd.get("mat", 0)))
	wood.material = wm
	pv.add_child(wood)
	var fr := ColorRect.new()
	fr.position = Vector2(8, 16)
	fr.size = Vector2(168, 96)
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/felt.gdshader")
	fm.set_shader_parameter("c_light", felt.light)
	fm.set_shader_parameter("c_dark", felt.dark)
	fm.set_shader_parameter("pat", int(felt.pat))
	fm.set_shader_parameter("accent", felt.get("accent", Color.WHITE))
	fm.set_shader_parameter("accent2", felt.get("accent2", Color.WHITE))
	fr.material = fm
	pv.add_child(fr)
	var edge := str(rd.get("edge", ""))
	if edge == "":
		edge = str(felt.get("edge", ""))
	var anim := str(felt.get("anim", ""))
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fnt := func():
		var t := fx_t
		if anim != "":
			for i in 10:
				var hx := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
				var hy := fposmod(sin(float(i) * 78.233) * 43758.5453, 1.0)
				var a := 0.5 + 0.5 * sin(t * 2.0 + float(i) * 1.7)
				var col: Color = {"stars": Color(1, 0.95, 0.8), "aurora": Color(0.4, 1, 0.75), "matrix": Color(0.2, 1, 0.45), "lava": Color(1, 0.55, 0.15), "sakura": Color(1, 0.85, 0.9), "sea": Color(0.8, 1, 1), "storm": Color(0.75, 0.85, 1), "glints": Color(1, 1, 1)}.get(anim, Color.WHITE)
				var p := Vector2(14 + hx * 156, 22 + fposmod(hy + (t * 0.08 if anim in ["matrix", "sakura", "storm"] else (-t * 0.06 if anim in ["lava", "sea"] else 0.0)), 1.0) * 84)
				top.draw_circle(p, 1.2 + a * 1.2, Color(col.r, col.g, col.b, 0.35 + 0.5 * a))
		for p in [Vector2(8, 16), Vector2(176, 16), Vector2(8, 112), Vector2(176, 112), Vector2(92, 16), Vector2(92, 112)]:
			top.draw_circle(p, 7, Color("050505"))
		if edge != "":
			var per := [Vector2(14, 19), Vector2(170, 19), Vector2(173, 22), Vector2(173, 106), Vector2(170, 109), Vector2(14, 109), Vector2(11, 106), Vector2(11, 22)]
			for k in 4:
				var a0: Vector2 = per[k * 2]
				var a1: Vector2 = per[k * 2 + 1]
				for j in 8:
					var q0 := a0.lerp(a1, float(j) / 8.0)
					var q1 := a0.lerp(a1, float(j + 1) / 8.0)
					var ph := float(k * 8 + j) / 32.0
					var col2 := Color.WHITE
					match edge:
						"rainbow":
							col2 = Color.from_hsv(fposmod(ph - t * 0.25, 1.0), 0.8, 1.0)
						"fire":
							col2 = Color(1.0, 0.4 + 0.4 * (0.5 + 0.5 * sin(ph * 40.0 + t * 8.0)), 0.05)
						"ice":
							col2 = Color(0.7, 0.95, 1.0, 0.6 + 0.4 * sin(ph * 20.0 - t * 3.0))
						"gold":
							col2 = Color(1.0, 0.82, 0.3, 0.3 + 0.7 * smoothstep(0.7, 1.0, fposmod(ph * 4.0 - t * 1.5, 1.0)))
						"electric":
							col2 = Color(0.45, 0.85, 1.0, 1.0 if fposmod(sin(floor(ph * 8.0) + floor(t * 12.0) * 7.7) * 43758.5, 1.0) > 0.7 else 0.25)
					top.draw_line(q0, q1, Color(col2.r, col2.g, col2.b, col2.a * 0.35), 6.0)
					top.draw_line(q0, q1, col2, 2.0)
		top.draw_circle(Vector2(52, 66), 8, Color("f4f4ee"))
		top.draw_circle(Vector2(112, 58), 8, Color("d12a1e"))
		top.draw_circle(Vector2(129, 70), 8, Color("1a4fb4"))
		top.draw_circle(Vector2(109, 55), 2.5, Color(1, 1, 1, 0.5))
	top.draw.connect(fnt)
	pv.add_child(top)
	if anim != "" or edge != "":
		fx_nodes.append(top)


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
	if id.begins_with("rb_"):
		game.save["rail"] = id
		game.write_save()
		game.apply_felt()
		game.net.send_hello()
		_shop_refresh()
		return
	if id.begins_with("wf_"):
		game.save["wfx"] = id
		game.write_save()
		_shop_refresh()
		game.play_victory()
		return
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
		game.net.send_hello()
	else:
		game.save.cue = id
	game.write_save()
	_shop_refresh()


func _buy_grana(id: String, gp: int, month: bool) -> void:
	if int(game.save.grana) < gp:
		say("Grana insuficiente! Ganhe Grana no Passe e na Roleta.")
		return
	game.save.grana = int(game.save.grana) - gp
	game.eco(0, -gp, "compra")
	game.save.owned.append(id)
	game.write_save()
	refresh_top()
	if month:
		_month_equip(id)
	else:
		_equip(id)
	game.check_achs()
	say("Comprado com Grana! Está no seu INVENTÁRIO.")


func _buy(id: String, price: int) -> void:
	if game.save.coins < price:
		say("Moedas insuficientes! Vença partidas para ganhar mais.")
		return
	game.save.coins -= price
	game.eco(-price, 0, "compra")
	game.save.owned.append(id)
	game.write_save()
	refresh_top()
	_equip(id)
	game.check_achs()
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
	var gg := mk_btn("☁  BACKUP NA NUVEM / SENHA", 440, 60, BLUE, 22)
	gg.pressed.connect(open_cloud)
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
	tfx_btn = mk_btn("", 330, 64, GREEN, 22)
	tfx_btn.pressed.connect(_toggle.bind("table_fx"))
	tg.add_child(tfx_btn)
	var tg2 := HBoxContainer.new()
	tg2.add_theme_constant_override("separation", 16)
	tg2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tg2)
	tg2.add_child(hear_btn)
	tg2.add_child(micb_btn)
	var mt := mk_btn("TESTAR MIC", 230, 64, Color("16897f"), 20)
	mt.button_down.connect(func():
		if game.chat.mic_test_start():
			mt.text = "GRAVANDO..."
		else:
			say("Permita o MICROFONE para o Sinucou e tente de novo."))
	mt.button_up.connect(func():
		var pk: float = game.chat.mic_test_stop()
		mt.text = "TESTAR MIC"
		if pk < 0.0:
			return
		if pk < 0.003:
			say("O microfone não captou som. Confira a permissão de MICROFONE do Sinucou nas configurações do Android.")
		else:
			say("Microfone OK! Você deve ouvir sua voz agora."))
	tg2.add_child(mt)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 16)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(brow)
	var tub := mk_btn("? COMO JOGAR", 260, 64, Color("1fa85a"), 24)
	tub.pressed.connect(open_tutorial_menu)
	brow.add_child(tub)
	var rpb := mk_btn("● MEUS REPLAYS", 300, 64, Color("b8323a"), 24)
	rpb.pressed.connect(open_replays)
	brow.add_child(rpb)
	var back := mk_btn("VOLTAR", 240, 64, GRAY, 28)
	back.pressed.connect(show_screen.bind("main"))
	brow.add_child(back)
	_settings_refresh()


# ---------------------------------------------------------------- tutorial
func open_tutorial_menu() -> void:
	var vb := _modal_box("COMO JOGAR")
	vb.add_child(mk_lbl("O Oitão te ensina! Escolha o que quer aprender:", 20, Color(1, 1, 1, 0.85), 2))
	for it in [["TUDO (menu, sinuca e truco)", "full", Color("1fa85a")], ["SÓ A SINUCA", "sinuca", BLUE], ["SÓ O TRUCO", "truco", Color("c0392b")]]:
		var b := mk_btn(it[0], 420, 60, it[2], 22)
		var k: String = it[1]
		b.pressed.connect(func():
			close_modal()
			show_screen("main")
			if k == "full":
				game.tutorial.start_full()
			elif k == "sinuca":
				game.tutorial.start_sinuca()
			else:
				game.tutorial.start_truco())
		vb.add_child(b)
	var c := mk_btn("FECHAR", 200, 50, GRAY, 20)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.pressed.connect(close_modal)
	vb.add_child(c)


# ---------------------------------------------------------------- backup na nuvem e recuperar conta
var cloud_box: VBoxContainer = null


func _edit(ph: String, secret: bool, maxl: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.secret = secret
	e.max_length = maxl
	e.custom_minimum_size = Vector2(360, 58)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_size_override("font_size", 26)
	e.add_theme_stylebox_override("normal", sbox(Color(0.02, 0.05, 0.09, 0.95), 16, Color(1, 1, 1, 0.35), 2, 0))
	e.add_theme_stylebox_override("focus", sbox(Color(0.02, 0.05, 0.09, 0.95), 16, Color("5aa9ff"), 3, 0))
	return e


func _modal_box(title: String) -> VBoxContainer:
	close_modal()
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
	p.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.97), 26, Color("5aa9ff"), 3, 20))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(margin(vb, 22))
	vb.add_child(mk_lbl(title, 32, Color("8fd0ff"), 6))
	return vb


func open_cloud() -> void:
	game.net.connect_server()
	cloud_box = _modal_box("☁  BACKUP NA NUVEM")
	cloud_refresh()


func cloud_refresh() -> void:
	if cloud_box == null or not is_instance_valid(cloud_box) or not has_modal():
		return
	while cloud_box.get_child_count() > 1:
		var ch := cloud_box.get_child(1)
		cloud_box.remove_child(ch)
		ch.queue_free()
	var n = game.net
	var st := "✓ Seu progresso está guardado na nuvem (último: %s)" % n.cloud_last if n.cloud_ok else ("⚠ Esta conta está sendo usada em outro celular." if n.cloud_fail else "Conectando ao servidor...")
	cloud_box.add_child(mk_lbl("Seu código:  %s" % game.my_code(), 26, Color("f4c542"), 4))
	cloud_box.add_child(mk_lbl(st, 18, Color("7dffa8") if n.cloud_ok else Color(1, 0.85, 0.5), 2))
	cloud_box.add_child(mk_lbl("Senha: " + ("criada ✓ (você pode entrar em outro celular)" if n.cloud_pass else "ainda não criada — crie uma para não perder a conta"), 18, Color(1, 1, 1, 0.85), 2))
	var pe := _edit("Nova senha (4 a 20 letras/números)", true, 20)
	cloud_box.add_child(pe)
	var b1 := mk_btn("TROCAR SENHA" if n.cloud_pass else "CRIAR SENHA", 360, 58, GREEN, 22)
	b1.pressed.connect(func():
		var pw := pe.text.strip_edges()
		if pw.length() < 4:
			say("A senha precisa ter pelo menos 4 caracteres.")
			return
		game.net.send_setpass(pw)
		say("Salvando senha..."))
	cloud_box.add_child(b1)
	cloud_box.add_child(mk_lbl("— Celular novo? Entre na sua conta antiga —", 18, Color(1, 1, 1, 0.6), 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	cloud_box.add_child(row)
	var ce := _edit("Código", false, 8)
	ce.custom_minimum_size = Vector2(170, 58)
	row.add_child(ce)
	var cpe := _edit("Senha", true, 20)
	cpe.custom_minimum_size = Vector2(190, 58)
	row.add_child(cpe)
	var b2 := mk_btn("ENTRAR NA CONTA", 360, 58, BLUE, 22)
	b2.pressed.connect(func():
		var cd := ce.text.strip_edges().to_upper()
		var pw2 := cpe.text
		if cd.length() < 4 or pw2.length() < 4:
			say("Digite o código e a senha da conta.")
			return
		if cd == game.my_code():
			say("Esse já é o código deste celular.")
			return
		game.net.send_recover(cd, pw2)
		say("Procurando a conta..."))
	cloud_box.add_child(b2)
	var b3 := mk_btn("FECHAR", 200, 52, GRAY, 20)
	b3.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b3.pressed.connect(close_modal)
	cloud_box.add_child(b3)


func cloud_recover_result(m: Dictionary) -> void:
	if not bool(m.get("ok", false)):
		say(str(m.get("msg", "Não deu certo.")))
		return
	var cd := str(m.get("code", ""))
	var sv = m.get("save", {})
	var coins := int(float((sv as Dictionary).get("coins", 0))) if sv is Dictionary else 0
	var ed = m.get("eco", null)
	if ed is Dictionary:
		coins = int(float(ed.get("coins", coins)))
	confirm("ENTRAR NA CONTA %s?" % cd, "Conta encontrada (%d moedas).\nO progresso DESTE celular será trocado pelo da conta %s." % [coins, cd], "ENTRAR", func():
		game.apply_recovered(cd, str(m.get("tok", "")), sv if sv is Dictionary else {}, m.get("eco", null))
		show_screen("main")
		say("Pronto! Você entrou na conta %s." % cd), "CANCELAR", func(): pass)


# ---------------------------------------------------------------- replays salvos dentro do jogo
var rp_list: VBoxContainer
var rp_view: TextureRect
var rp_cur := ""
var rp_title: Label
var rp_hint: Label


func _build_replays() -> void:
	var v := mk_screen("replays", 12)
	rp_title = mk_lbl("MEUS REPLAYS", 48, Color("f4c542"), 10)
	v.add_child(rp_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.09, 0.9), 20, Color(1, 1, 1, 0.2), 2, 10))
	row.add_child(left)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(420, 430)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	rp_list = VBoxContainer.new()
	rp_list.add_theme_constant_override("separation", 10)
	rp_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rp_list)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", sbox(Color(0, 0, 0, 0.85), 20, Color("f4c542"), 2, 8))
	row.add_child(right)
	rp_view = TextureRect.new()
	rp_view.custom_minimum_size = Vector2(612, 344)
	rp_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rp_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rp_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/gif_pal.gdshader")
	rp_view.material = pm
	right.add_child(rp_view)
	rp_hint = mk_lbl("Toque em ▶ VER para assistir\nem tela cheia, com câmera lenta.\n\nLá você também salva na\nGALERIA ou ENVIA no WhatsApp.", 24, Color(1, 1, 1, 0.85), 3)
	rp_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	right.add_child(rp_hint)
	var back := mk_btn("◀  VOLTAR", 260, 60, GRAY, 26)
	back.pressed.connect(func():
		game.replay.stop_play()
		show_screen("settings"))
	v.add_child(back)


func open_replays() -> void:
	if not screens.has("replays"):
		_build_replays()
	show_screen("replays")
	_replays_refresh()


func _replays_refresh() -> void:
	for c in rp_list.get_children():
		c.queue_free()
	var lst: Array = game.replay.list_local()
	rp_title.text = "MEUS REPLAYS  (%d/%d)" % [lst.size(), game.replay.MAX_SAVED]
	if lst.is_empty():
		var el := mk_lbl("Nenhum replay ainda.\n\nNa partida, toque no botão\n● 30s (embaixo do pause)\npara salvar a jogada.", 22, Color(1, 1, 1, 0.75), 3)
		el.custom_minimum_size = Vector2(400, 300)
		rp_list.add_child(el)
		rp_view.texture = null
		return
	if rp_cur == "" or not lst.has(rp_cur):
		rp_cur = str(lst[0])
	rp_hint.visible = false
	if game.replay.is_state(rp_cur):
		rp_view.texture = null
		rp_hint.visible = true
	elif not game.replay.play_local(rp_cur, rp_view):
		rp_view.texture = null
	for nm in lst:
		var n: String = nm
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", sbox(Color(0.08, 0.12, 0.2) if n != rp_cur else Color(0.2, 0.15, 0.04), 14, GOLD if n == rp_cur else Color(1, 1, 1, 0.15), 2, 8))
		rp_list.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)
		# Sinucou_20261119_211704 -> 19/11 21:17
		var ds := n.get_slice("_", 1)
		var ts := n.get_slice("_", 2)
		var label := "Replay  %s/%s  %s:%s" % [ds.substr(6, 2), ds.substr(4, 2), ts.substr(0, 2), ts.substr(2, 2)] if ds.length() >= 8 and ts.length() >= 4 else n
		vb.add_child(mk_lbl(label, 20, Color.WHITE, 3))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(hb)
		var bv := mk_btn("▶ VER", 110, 46, BLUE, 18)
		bv.pressed.connect(func():
			rp_cur = n
			if game.replay.is_state(n):
				game.replay.start_watch(n)
			else:
				_replays_refresh())
		hb.add_child(bv)
		var bo := mk_btn("ENVIAR", 170, 46, GREEN, 18)
		bo.pressed.connect(func(): game.replay.open_local(n))
		hb.add_child(bo)
		var bd := mk_btn("APAGAR", 96, 46, RED, 16)
		bd.pressed.connect(func():
			confirm("APAGAR REPLAY", "Apagar este replay?", "APAGAR", func():
				game.replay.delete_local(n)
				_replays_refresh(), "CANCELAR", func(): pass))
		hb.add_child(bd)


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
	tfx_btn.text = "ANIMAÇÃO DA MESA: " + ("SIM" if game.save.get("table_fx", true) else "NÃO")
	for pair in [[tfx_btn, game.save.get("table_fx", true)], [sfx_btn, game.save.sfx], [vib_btn, game.save.vib], [hear_btn, game.save.get("voice_hear", true)], [micb_btn, game.save.get("voice_mic", true)]]:
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
		for it in game.FELTS + game.CUES + game.ELITE + game.DECKS + game.WFX:
			if it.id == r.item:
				item = it
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(sz * 2.2, sz * 1.3)
		if item.has("deck") or item.has("wfx"):
			ic.custom_minimum_size = Vector2(184, 150)
			if item.has("deck"):
				_deck_preview(ic, str(item.deck))
			else:
				_wfx_preview(ic, str(item.wfx))
			return ic
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
	dimr.color = Color(0.0, 0.01, 0.03, 0.82)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dimr)
	# dois feixes de luz girando em sentidos opostos
	var rays := Control.new()
	rays.size = Vector2(1000, 1000)
	rays.pivot_offset = Vector2(500, 500)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.draw.connect(func():
		var c := Vector2(500, 500)
		for k in 12:
			var a0 := float(k) * TAU / 12.0
			rays.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0 - 0.11) * 500.0, c + Vector2.from_angle(a0 + 0.11) * 500.0]), Color(1.0, 0.82, 0.3, 0.08))
		for k in 8:
			rays.draw_circle(c, 40.0 + k * 30.0, Color(1.0, 0.78, 0.25, 0.04)))
	modal_layer.add_child(rays)
	var rays2 := Control.new()
	rays2.size = Vector2(800, 800)
	rays2.pivot_offset = Vector2(400, 400)
	rays2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays2.draw.connect(func():
		var c := Vector2(400, 400)
		for k in 16:
			var a0 := float(k) * TAU / 16.0 + 0.1
			rays2.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0 - 0.04) * 400.0, c + Vector2.from_angle(a0 + 0.04) * 400.0]), Color(1, 1, 1, 0.05)))
	modal_layer.add_child(rays2)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(cc)
	var p := PanelContainer.new()
	var psb := sbox(Color(0.05, 0.07, 0.13, 0.98), 30, Color("f4c542"), 3, 30)
	psb.shadow_color = Color(1.0, 0.75, 0.2, 0.25)
	psb.shadow_size = 26
	p.add_theme_stylebox_override("panel", psb)
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.custom_minimum_size = Vector2(480, 0)
	p.add_child(margin(vb, 22))
	# faixa vermelha com o título do prêmio
	var rib := Control.new()
	rib.custom_minimum_size = Vector2(480, 54)
	rib.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		var w := 440.0
		var x0 := 20.0
		rib.draw_colored_polygon(PackedVector2Array([Vector2(x0 - 18, 14), Vector2(x0 + 10, 14), Vector2(x0 + 10, 48), Vector2(x0 - 18, 48), Vector2(x0 - 6, 31)]), Color("8a1c24"))
		rib.draw_colored_polygon(PackedVector2Array([Vector2(x0 + w + 18, 14), Vector2(x0 + w - 10, 14), Vector2(x0 + w - 10, 48), Vector2(x0 + w + 18, 48), Vector2(x0 + w + 6, 31)]), Color("8a1c24"))
		rib.draw_style_box(sbox(Color("d23a44"), 8, Color("ffd34a"), 2), Rect2(x0, 6, w, 38))
		rib.draw_style_box(sbox(Color(1, 1, 1, 0.12), 6), Rect2(x0 + 6, 9, w - 12, 12))
		var ht := head.to_upper()
		var fs := 20 if ht.length() < 34 else 15
		rib.draw_string(f, Vector2(x0, 32), ht, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color.WHITE))
	vb.add_child(rib)
	var ttl := Control.new()
	ttl.custom_minimum_size = Vector2(480, 64)
	ttl.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		ttl.draw_string_outline(f, Vector2(0, 52), "VOCÊ GANHOU!", HORIZONTAL_ALIGNMENT_CENTER, 480, 50, 12, Color("3a2402"))
		ttl.draw_string_outline(f, Vector2(0, 52), "VOCÊ GANHOU!", HORIZONTAL_ALIGNMENT_CENTER, 480, 50, 4, Color("fff0b0"))
		ttl.draw_string(f, Vector2(0, 52), "VOCÊ GANHOU!", HORIZONTAL_ALIGNMENT_CENTER, 480, 50, Color("f7c33a")))
	vb.add_child(ttl)
	# ícone grande sobre um brilho redondo
	var glow := Control.new()
	glow.custom_minimum_size = Vector2(480, 170)
	glow.draw.connect(func():
		var c := Vector2(240, 85)
		for k in 6:
			glow.draw_circle(c, 80.0 - k * 10.0, Color(1.0, 0.8, 0.3, 0.05 + k * 0.025)))
	vb.add_child(glow)
	var ic := reward_icon(r, 120.0)
	glow.add_child(ic)
	ic.position = Vector2(240, 85) - ic.custom_minimum_size / 2.0
	var bl := mk_lbl(big, 34, Color.WHITE, 6)
	bl.custom_minimum_size = Vector2(460, 0)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(bl)
	var amount := int(r.get("coins", 0)) if r.has("coins") and not r.has("item") else 0
	if amount > 0:
		# número subindo até o valor ganho
		var nt := bl.create_tween()
		nt.tween_method(func(v: float): bl.text = big.replace(str(amount), str(int(v))), 0.0, float(amount), 0.9).set_delay(0.35)
	var ok := mk_btn("PEGAR!", 300, 70, GOLD, 30)
	for stn in ["normal", "hover", "pressed"]:
		var sbb := sbox(Color("f4b923") if stn != "pressed" else Color("d99a10"), 22, Color("fff0b0") if stn == "normal" else Color.WHITE, 3, 10 if stn != "pressed" else 2)
		ok.add_theme_stylebox_override(stn, sbb)
	ok.add_theme_color_override("font_color", Color("3a2402"))
	ok.add_theme_color_override("font_hover_color", Color("3a2402"))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		if amount > 0:
			_fly_coins(ic.get_global_rect().get_center(), amount)
		close_modal())
	vb.add_child(ok)
	# brilhos subindo
	for k in 16:
		var sp := Label.new()
		sp.text = "✦"
		sp.add_theme_font_size_override("font_size", randi_range(16, 32))
		sp.add_theme_color_override("font_color", [Color("ffe066"), Color.WHITE, Color("ffcf6a")][k % 3])
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modal_layer.add_child(sp)
		var vs: Vector2 = root.size
		var x0 := vs.x * 0.5 + randf_range(-420, 420)
		sp.position = Vector2(x0, vs.y * 0.5 + randf_range(40, 280))
		sp.modulate.a = 0.0
		var tw := sp.create_tween().set_loops()
		tw.tween_interval(randf_range(0.0, 1.6))
		tw.tween_property(sp, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(sp, "position:y", sp.position.y - randf_range(180, 320), 1.7).from(sp.position.y)
		tw.tween_property(sp, "modulate:a", 0.0, 0.4)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	rays.position = root.size / 2.0 - rays.size / 2.0
	rays2.position = root.size / 2.0 - rays2.size / 2.0
	var rt := rays.create_tween().set_loops()
	rt.tween_property(rays, "rotation", TAU, 18.0).from(0.0)
	var rt2 := rays2.create_tween().set_loops()
	rt2.tween_property(rays2, "rotation", -TAU, 26.0).from(0.0)
	p.pivot_offset = p.size / 2.0
	p.scale = Vector2(0.4, 0.4)
	p.modulate.a = 0.0
	var pt := p.create_tween().set_parallel()
	pt.tween_property(p, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(p, "modulate:a", 1.0, 0.2)
	ic.pivot_offset = ic.custom_minimum_size / 2.0
	var it := ic.create_tween().set_loops()
	it.tween_property(ic, "position:y", ic.position.y - 8, 0.9).set_trans(Tween.TRANS_SINE)
	it.tween_property(ic, "position:y", ic.position.y, 0.9).set_trans(Tween.TRANS_SINE)


# ao pegar o prêmio: moedas voam até o contador lá em cima, que vai subindo
func _fly_coins(from: Vector2, amount: int) -> void:
	if coin_lbl == null or not topbar.visible:
		refresh_top()
		return
	var to := coin_lbl.get_global_rect().get_center() + Vector2(-40, 0)
	var final := int(game.save.coins)
	var start := final - amount
	coin_lbl.text = str(start)
	var n := 10
	for i in n:
		var cn := Control.new()
		cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cn.size = Vector2(36, 36)
		cn.draw.connect(func(): draw_coin(cn, Vector2(18, 18), 16))
		root.add_child(cn)
		cn.position = from - Vector2(18, 18) + Vector2(randf_range(-50, 50), randf_range(-30, 30))
		var mid := cn.position.lerp(to, 0.5) + Vector2(randf_range(-120, 120), -120)
		var tw := cn.create_tween()
		tw.tween_interval(i * 0.06)
		var p0 := cn.position
		tw.tween_method(func(t: float):
			var a := p0.lerp(mid, t)
			var b := mid.lerp(to - Vector2(18, 18), t)
			cn.position = a.lerp(b, t)
			cn.scale = Vector2.ONE * (1.0 - 0.4 * t), 0.0, 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var idx := i
		tw.tween_callback(func():
			cn.queue_free()
			game.play("click", 0.4)
			coin_lbl.text = str(start + int(float(amount) * float(idx + 1) / float(n)))
			if idx == n - 1:
				coin_lbl.text = str(final)
				var bt := coin_lbl.create_tween()
				coin_lbl.pivot_offset = coin_lbl.size / 2.0
				bt.tween_property(coin_lbl, "scale", Vector2(1.25, 1.25), 0.08)
				bt.tween_property(coin_lbl, "scale", Vector2.ONE, 0.15))


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
		if no_cb.is_valid():
			no_cb.call())
	bn.visible = no != ""
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
	var p := panel(560, 490)
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
	var b3 := mk_btn("● SALVAR REPLAY (30s)", 400, 56, Color("b8323a"), 22)
	b3.pressed.connect(func(): game.replay.save_clip())
	vb.add_child(b3)


func _rematch() -> void:
	if game.mode == game.Mode.ONLINE:
		game.net.ask_rematch()
		over_rematch.disabled = true
		over_rematch.text = "ESPERANDO..."
		say("Revanche pedida! Esperando o adversário aceitar...")
		return
	show_screen("")
	game.start_game(game.mode, game.diff)


# o adversário pediu revanche (sinuca na tela de fim, ou truco no quadro de fim)
func rematch_req(nm: String) -> void:
	if truco_node != null and is_instance_valid(truco_node):
		truco_node.say("%s quer REVANCHE! Toque em REVANCHE para jogar de novo." % nm)
		return
	if cur == "over" and over_rematch != null:
		over_sub.text = "%s quer REVANCHE!" % nm
		say("%s quer revanche! Toque em REVANCHE." % nm)


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
	over_rematch.visible = game.mode != game.Mode.ONLINE or (not game.net4 and not in_lobby() and not game.tour_active())
	over_rematch.disabled = false
	over_rematch.text = "REVANCHE"
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
	var menus := ["main", "play", "online", "shop", "inv", "stats", "settings", "roleta", "passe", "truco", "amigos", "missoes"]
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
	elif sname == "missoes":
		_missoes_refresh()
	elif sname == "perfil":
		_perfil_refresh()
	elif sname == "ranking":
		_ranking_refresh()
	elif sname == "torneio":
		_tour_paint()
	if sname == "online" or sname == "play" or sname == "truco":
		for k in ["bet_on", "bet_ai", "bet_tr"]:
			_stake_paint(k)
	if sname == "pause":
		_pause_refresh()
	if sname == "main":
		_month_refresh()
		missions_badge()
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



# ---------------------------------------------------------------- apostas: seletor de valor
func stake_row(key: String, opts: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var arr := []
	for v in opts:
		var b := mk_btn("SEM" if int(v) == 0 else game.stake_txt(int(v)), 74, 44, GRAY, 17)
		b.pressed.connect(_stake_pick.bind(key, int(v)))
		b.set_meta("v", int(v))
		h.add_child(b)
		arr.append(b)
	stake_btns[key] = arr
	return h


func _stake_max(key: String) -> int:
	if key == "bet_ai":
		return game.ai_stake_max(diff_sel)
	if key == "bet_tr":
		return 100
	return 1000


func _stake_pick(key: String, v: int) -> void:
	if key == "bet_on" and in_lobby() and not lobby_leader():
		say("Só o dono do lobby escolhe a aposta.")
		return
	if v > int(game.save.coins):
		say("Você não tem moedas suficientes para apostar %d." % v)
		return
	if v > _stake_max(key):
		say("Contra a IA nessa dificuldade a aposta vai até %d moedas." % _stake_max(key))
		return
	game.save[key] = v
	game.write_save()
	_stake_paint(key)
	if key == "bet_on":
		if in_lobby():
			if lobby_leader():
				game.net.world_send({"t": "lset", "game": game.net_game, "four": game.net_team, "stake": v})
		elif _online_busy():
			_online_start()


func _stake_paint(key: String) -> void:
	if not stake_btns.has(key):
		return
	var sel := int(game.save.get(key, 0))
	if key == "bet_on" and in_lobby():
		sel = int(lobby.get("stake", 0))
	var mx := _stake_max(key)
	if key != "bet_on" or not in_lobby():
		# valor guardado maior do que dá agora (moedas ou dificuldade): mostra o maior possível
		while sel > 0 and (sel > int(game.save.coins) or sel > mx):
			var opts: Array = []
			for b in stake_btns[key]:
				opts.append(int(b.get_meta("v")))
			var i := opts.find(sel)
			sel = int(opts[i - 1]) if i > 0 else 0
		if sel != int(game.save.get(key, 0)):
			game.save[key] = sel
	for b in stake_btns[key]:
		var v := int(b.get_meta("v"))
		var on := v == sel
		var can := v <= int(game.save.coins) and v <= mx
		var col: Color = GOLD if on else (Color(0.09, 0.12, 0.17, 0.95) if can else Color(0.22, 0.08, 0.08, 0.9))
		b.add_theme_stylebox_override("normal", sbox(col, 16, Color.WHITE if on else Color(1, 1, 1, 0.18), 3 if on else 2, 6 if on else 0))
		b.add_theme_color_override("font_color", Color("2a1a00") if on else (Color.WHITE if can else Color(1, 1, 1, 0.4)))
	var hint := "Sem aposta: vitória +60  •  derrota +15" if sel == 0 else "Cada um aposta %d  •  quem ganhar leva %d" % [sel, sel * 2]
	if key == "bet_on" and bet_hint_on != null:
		bet_hint_on.text = hint
	elif key == "bet_ai" and bet_hint_ai != null:
		bet_hint_ai.text = "Sem aposta" if sel == 0 else "Ganhou: +%d  •  Perdeu: -%d" % [sel, sel]
	elif key == "bet_tr" and bet_hint_tr != null:
		bet_hint_tr.text = "Sem aposta" if sel == 0 else "Ganhou: +%d  •  Perdeu: -%d" % [sel, sel]


# ---------------------------------------------------------------- missões diárias
func _build_missoes() -> void:
	var v := mk_screen("missoes", 12)
	add_bg("missoes", "res://assets/menu_bg.jpg", 0.2)
	v.add_child(mk_lbl("MISSÕES DO DIA", 50, Color("f4c542"), 10))
	mis_head = mk_lbl("", 18, Color(1, 1, 1, 0.8), 3)
	v.add_child(mis_head)
	mis_box = VBoxContainer.new()
	mis_box.add_theme_constant_override("separation", 12)
	mis_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(mis_box)
	var back := mk_btn("◀  VOLTAR", 240, 58, GRAY, 26)
	back.pressed.connect(show_screen.bind("main"))
	v.add_child(back)


func _missoes_refresh() -> void:
	for c in mis_box.get_children():
		c.queue_free()
	var t := Time.get_time_dict_from_system()
	var left_h := 23 - int(t.hour)
	var left_m := 59 - int(t.minute)
	mis_head.text = "Novas missões em %dh %02dmin  •  Dias seguidos jogando: %d" % [left_h, left_m, int(game.save.get("daily_streak", 0))]
	for m in game.missions():
		var row := PanelContainer.new()
		var done: bool = int(m.prog) >= int(m.n)
		var claimed: bool = bool(m.claimed)
		row.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.9), 22, GOLD if done and not claimed else Color(1, 1, 1, 0.18), 3 if done and not claimed else 2, 10))
		mis_box.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		row.add_child(margin(h, 14))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.custom_minimum_size = Vector2(560, 0)
		h.add_child(col)
		var tl := mk_lbl(str(m.txt), 24, Color.WHITE, 3)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(tl)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(560, 16)
		pb.show_percentage = false
		pb.max_value = int(m.n)
		pb.value = int(m.prog)
		pb.add_theme_stylebox_override("background", sbox(Color(0, 0, 0, 0.55), 8))
		pb.add_theme_stylebox_override("fill", sbox(GREEN if done else BLUE, 8))
		col.add_child(pb)
		var pl := mk_lbl("%d / %d" % [int(m.prog), int(m.n)], 16, Color(1, 1, 1, 0.7))
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(pl)
		var rw := HBoxContainer.new()
		rw.add_theme_constant_override("separation", 6)
		rw.alignment = BoxContainer.ALIGNMENT_CENTER
		rw.custom_minimum_size = Vector2(130, 0)
		rw.add_child(coin_icon(30))
		rw.add_child(mk_lbl("+%d" % int(m.r), 26, Color("ffe066"), 4))
		h.add_child(rw)
		var b: Button
		if claimed:
			b = mk_btn("FEITO ✓", 190, 60, GRAY, 22)
			b.disabled = true
		elif done:
			b = mk_btn("COLETAR", 190, 60, GREEN, 24)
			var mid := str(m.id)
			b.pressed.connect(func():
				game.mission_claim(mid)
				_missoes_refresh())
		else:
			b = mk_btn("EM ANDAMENTO", 190, 60, Color(0.12, 0.16, 0.22), 18)
			b.disabled = true
		h.add_child(b)


func missions_badge() -> void:
	if mis_btn != null:
		var k: int = game.missions_ready()
		_set_badge(mis_btn, str(k) if k > 0 else "")


# ---------------------------------------------------------------- prêmio por dias seguidos
func show_daily(streak: int, coins: int, gems: int) -> void:
	show_reward("DIA %d SEGUIDO JOGANDO!" % streak, ("+%d MOEDAS" % coins) + ("  +%d GRANA" % gems if gems > 0 else ""), {"coins": coins})
	if modal_layer == null:
		return
	# fileira dos 7 dias embaixo do prêmio
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(7 * 74, 92)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		for i in 7:
			var r := Rect2(i * 74 + 3, 4, 66, 84)
			var got := i < streak
			var today := i == streak - 1
			strip.draw_style_box(sbox(GOLD if today else (Color("1fa85a") if got else Color(0.1, 0.13, 0.19)), 12, Color.WHITE if today else Color(1, 1, 1, 0.2), 3 if today else 1), r)
			var tc := Color("2a1a00") if today else Color.WHITE
			strip.draw_string(f, Vector2(r.position.x, r.position.y + 24), "DIA %d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, tc)
			strip.draw_string(f, Vector2(r.position.x, r.position.y + 54), str(game.STREAK_REWARDS[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, tc)
			strip.draw_string(f, Vector2(r.position.x, r.position.y + 74), "+5 GRANA" if i == 6 else ("✓" if got else ""), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, tc))
	var pc: PanelContainer = modal_layer.find_children("*", "PanelContainer", true, false)[0]
	var vb: VBoxContainer = pc.get_child(0).get_child(0)
	vb.add_child(strip)
	vb.move_child(strip, vb.get_child_count() - 2)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER



# ---------------------------------------------------------------- perfil do jogador
func _build_perfil() -> void:
	var v := mk_screen("perfil", 10)
	add_bg("perfil", "res://assets/menu_bg.jpg", 0.2)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs)
	for k in [["perfil", "MEU PERFIL"], ["conq", "CONQUISTAS"], ["visual", "AVATAR E TÍTULO"]]:
		var b := mk_btn(k[1], 250, 54, GRAY, 20)
		b.pressed.connect(func():
			pf_tab = k[0]
			_perfil_refresh())
		b.set_meta("tab", k[0])
		tabs.add_child(b)
	tabs.name = "Tabs"
	pf_box = VBoxContainer.new()
	pf_box.add_theme_constant_override("separation", 10)
	pf_box.custom_minimum_size = Vector2(1100, 470)
	v.add_child(pf_box)
	var back := mk_btn("◀  VOLTAR", 220, 54, GRAY, 24)
	back.pressed.connect(show_screen.bind("main"))
	v.add_child(back)


func _perfil_refresh() -> void:
	for c in pf_box.get_children():
		c.queue_free()
	var tabs: HBoxContainer = screens["perfil"].find_child("Tabs", true, false)
	for b in tabs.get_children():
		var on: bool = str(b.get_meta("tab")) == pf_tab
		b.add_theme_stylebox_override("normal", sbox(BLUE if on else Color(0.09, 0.12, 0.17, 0.95), 20, Color.WHITE if on else Color(1, 1, 1, 0.18), 3 if on else 2, 6))
	if pf_tab == "conq":
		_perfil_conq()
	elif pf_tab == "visual":
		_perfil_visual()
	else:
		_perfil_main()


func _div_badge(c: Control, ctr: Vector2, r: float, dv: int) -> void:
	var col: Color = game.DIVS[dv].col
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(ctr + Vector2.from_angle(-PI / 2.0 + float(k) * TAU / 6.0) * r)
	c.draw_colored_polygon(pts, col.darkened(0.45))
	var pts2 := PackedVector2Array()
	for k in 6:
		pts2.append(ctr + Vector2.from_angle(-PI / 2.0 + float(k) * TAU / 6.0) * r * 0.78)
	c.draw_colored_polygon(pts2, col)
	c.draw_colored_polygon(_star(ctr, r * 0.42, r * 0.18), Color(1, 1, 1, 0.9))
	for k in dv:
		c.draw_circle(ctr + Vector2((k - (dv - 1) / 2.0) * r * 0.32, r * 0.62), r * 0.08, Color.WHITE)


func _perfil_main() -> void:
	var d: Dictionary = game.profile_data()
	var lg: Dictionary = game.league()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pf_box.add_child(row)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.9), 26, Color(1, 1, 1, 0.2), 2, 12))
	row.add_child(card)
	var cv := Control.new()
	cv.custom_minimum_size = Vector2(400, 440)
	card.add_child(cv)
	cv.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		AV.draw(cv, Vector2(200, 100), 80, str(d.av), str(d.fr), anim_t)
		cv.draw_string(f, Vector2(0, 222), game.my_name(), HORIZONTAL_ALIGNMENT_CENTER, 400, 34, Color.WHITE)
		var ti: Dictionary = AV.find(AV.TITLES, str(d.ti))
		cv.draw_string(f, Vector2(0, 254), str(ti.name), HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Color("f4c542"))
		cv.draw_string(f, Vector2(0, 284), "Nível %d   •   código %s" % [int(d.lvl), game.my_code()], HORIZONTAL_ALIGNMENT_CENTER, 400, 17, Color(1, 1, 1, 0.65))
		var dv := int(d.div)
		_div_badge(cv, Vector2(110, 360), 42, dv)
		cv.draw_string(f, Vector2(165, 350), "LIGA DA SEMANA", HORIZONTAL_ALIGNMENT_LEFT, 230, 15, Color(1, 1, 1, 0.6))
		cv.draw_string(f, Vector2(165, 378), str(game.DIVS[dv].name), HORIZONTAL_ALIGNMENT_LEFT, 230, 26, game.DIVS[dv].col)
		cv.draw_string(f, Vector2(165, 404), "%d pontos" % int(lg.pts), HORIZONTAL_ALIGNMENT_LEFT, 230, 18, Color.WHITE))
	var tick := create_tween().set_loops()
	tick.tween_callback(cv.queue_redraw).set_delay(0.05)
	cv.tree_exiting.connect(tick.kill)
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.9), 26, Color(1, 1, 1, 0.2), 2, 12))
	row.add_child(sp)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 10)
	sp.add_child(margin(g, 18))
	var s: Dictionary = game.save
	var played: int = int(s.played) + int(s.get("truco_wins", 0)) + int(s.get("truco_losses", 0))
	var wins: int = int(s.wins) + int(s.get("truco_wins", 0))
	var rate: int = int(round(100.0 * wins / maxf(1.0, float(played))))
	var cd: Dictionary = game.cue_by_id(str(s.cue)) if game.has_method("cue_by_id") else {}
	var items := [
		["Partidas jogadas", str(played)], ["Vitórias", str(wins)], ["Aproveitamento", "%d%%" % rate],
		["Vitórias na sinuca", str(s.wins)], ["Vitórias no truco", str(int(s.get("truco_wins", 0)))],
		["Sequência atual", str(game.stat("streak"))], ["Maior sequência", str(game.stat("best_streak"))],
		["Bolas encaçapadas", str(game.stat("pockets"))], ["Apostas ganhas", str(game.stat("bets_won"))],
		["Conquistas", "%d / %d" % [(s.get("achs", []) as Array).size(), game.ACHS.size()]],
		["Taco favorito", str(cd.get("name", s.cue))], ["Dias seguidos", str(int(s.get("daily_streak", 0)))],
	]
	for it in items:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", sbox(Color(1, 1, 1, 0.05), 14))
		var hv := VBoxContainer.new()
		hv.add_theme_constant_override("separation", 0)
		hv.custom_minimum_size = Vector2(270, 0)
		box.add_child(margin(hv, 8))
		var l1 := mk_lbl(str(it[0]), 15, Color(1, 1, 1, 0.6))
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hv.add_child(l1)
		var l2 := mk_lbl(str(it[1]), 24, Color.WHITE, 2)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hv.add_child(l2)
		g.add_child(box)


func _perfil_conq() -> void:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1100, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pf_box.add_child(sc)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	sc.add_child(g)
	page_scroll = sc
	var got: Array = game.save.get("achs", [])
	for a in game.ACHS:
		var done := got.has(str(a.id))
		var val: int = mini(game.ach_val(str(a.k)), int(a.n))
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.92), 18, GOLD if done else Color(1, 1, 1, 0.14), 3 if done else 2, 6))
		g.add_child(box)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.custom_minimum_size = Vector2(345, 0)
		box.add_child(margin(h, 10))
		var md := Control.new()
		md.custom_minimum_size = Vector2(60, 60)
		md.draw.connect(func():
			var col := Color("ffd34a") if done else Color(0.3, 0.33, 0.4)
			md.draw_colored_polygon(PackedVector2Array([Vector2(18, 0), Vector2(26, 0), Vector2(30, 18), Vector2(22, 22)]), Color("c0303a") if done else Color(0.25, 0.25, 0.3))
			md.draw_colored_polygon(PackedVector2Array([Vector2(42, 0), Vector2(34, 0), Vector2(30, 18), Vector2(38, 22)]), Color("2f7fd6") if done else Color(0.25, 0.25, 0.3))
			md.draw_circle(Vector2(30, 38), 21, col.darkened(0.35))
			md.draw_circle(Vector2(30, 38), 17, col)
			md.draw_colored_polygon(_star(Vector2(30, 38), 11, 5), Color(1, 1, 1, 0.85) if done else Color(1, 1, 1, 0.25)))
		h.add_child(md)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		var n1 := mk_lbl(str(a.name), 19, Color.WHITE if done else Color(1, 1, 1, 0.75), 2)
		n1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tv.add_child(n1)
		var n2 := mk_lbl(str(a.desc), 14, Color(1, 1, 1, 0.6))
		n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tv.add_child(n2)
		var n3 := mk_lbl(("✓ FEITA  •  +%d moedas" % int(a.r)) if done else ("%d / %d  •  prêmio %d" % [val, int(a.n), int(a.r)]), 14, Color("3ddc84") if done else Color("ffe066"))
		n3.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tv.add_child(n3)


func _perfil_visual() -> void:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1100, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pf_box.add_child(sc)
	page_scroll = sc
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	vb.add_child(_section("AVATAR"))
	var ga := HFlowContainer.new()
	ga.add_theme_constant_override("h_separation", 10)
	ga.add_theme_constant_override("v_separation", 10)
	ga.custom_minimum_size = Vector2(1080, 0)
	vb.add_child(ga)
	for it in AV.AVATARS:
		ga.add_child(_pick_tile(it, "av"))
	vb.add_child(_section("MOLDURA"))
	var gf := HFlowContainer.new()
	gf.add_theme_constant_override("h_separation", 10)
	gf.add_theme_constant_override("v_separation", 10)
	gf.custom_minimum_size = Vector2(1080, 0)
	vb.add_child(gf)
	for it in AV.FRAMES:
		gf.add_child(_pick_tile(it, "frame"))
	vb.add_child(_section("TÍTULO (aparece embaixo do seu nome)"))
	var gt := HFlowContainer.new()
	gt.add_theme_constant_override("h_separation", 10)
	gt.add_theme_constant_override("v_separation", 10)
	gt.custom_minimum_size = Vector2(1080, 0)
	vb.add_child(gt)
	for it in AV.TITLES:
		var ok: bool = game.unlocked(str(it.need))
		var on: bool = str(game.save.get("title", "novato")) == str(it.id)
		var b := mk_btn(str(it.name) if ok else "🔒 " + str(it.name), 250, 50, GOLD if on else (BLUE if ok else Color(0.15, 0.17, 0.22)), 17)
		if not ok:
			b.text = str(it.name)
			b.modulate = Color(1, 1, 1, 0.5)
		var iid := str(it.id)
		var need := str(it.need)
		b.pressed.connect(func():
			if not game.unlocked(need):
				say("Bloqueado: " + game.need_txt(need))
				return
			game.save["title"] = iid
			game.write_save()
			game.net.send_profile()
			_perfil_refresh())
		gt.add_child(b)


func _pick_tile(it: Dictionary, key: String) -> Control:
	var ok: bool = game.unlocked(str(it.need))
	var on: bool = str(game.save.get(key, "b8" if key == "av" else "simples")) == str(it.id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(124, 140)
	b.add_theme_stylebox_override("normal", sbox(Color(0.03, 0.06, 0.1, 0.95), 18, GOLD if on else Color(1, 1, 1, 0.15), 4 if on else 2, 4))
	b.add_theme_stylebox_override("hover", sbox(Color(0.05, 0.09, 0.15, 0.95), 18, Color.WHITE, 3, 4))
	b.add_theme_stylebox_override("pressed", sbox(Color(0.02, 0.04, 0.07, 0.95), 18, GOLD, 3, 2))
	var dc := Control.new()
	dc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var iid := str(it.id)
	dc.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		if key == "av":
			AV.draw(dc, Vector2(62, 56), 42, iid, str(game.save.get("frame", "simples")), anim_t)
		else:
			AV.draw(dc, Vector2(62, 56), 42, str(game.save.get("av", "b8")), iid, anim_t)
		if not ok:
			dc.draw_circle(Vector2(62, 56), 42, Color(0, 0, 0, 0.6))
			dc.draw_style_box(sbox(Color(0.85, 0.85, 0.9), 4), Rect2(52, 52, 20, 16))
			dc.draw_arc(Vector2(62, 52), 7, PI, TAU, 12, Color(0.85, 0.85, 0.9), 3.0)
		dc.draw_string(f, Vector2(0, 118), str(it.name), HORIZONTAL_ALIGNMENT_CENTER, 124, 14, Color.WHITE if ok else Color(1, 1, 1, 0.5))
		if not ok:
			dc.draw_string(f, Vector2(0, 134), game.need_txt(str(it.need)).left(22), HORIZONTAL_ALIGNMENT_CENTER, 124, 10, Color("ffb3a0")))
	b.add_child(dc)
	var need := str(it.need)
	b.pressed.connect(func():
		if not game.unlocked(need):
			say("Bloqueado: " + game.need_txt(need))
			return
		game.save[key] = iid
		game.write_save()
		game.net.send_profile()
		refresh_top()
		_perfil_refresh())
	return b


# perfil de um amigo (chega do servidor)
var prof_hint := {}


# abre o perfil de qualquer jogador (lobby, ranking...) pelo código
func open_player(code: String, nm: String) -> void:
	prof_hint[code.to_upper()] = nm
	game.net.connect_server()
	game.net.world_send({"t": "prof", "code": code})
	say("Abrindo perfil...")


# botão de amizade do perfil (some se já forem amigos)
func _prof_friend_btn(code: String, nm: String) -> Button:
	if code == "" or code == game.my_code().to_upper() or _has("friends", code):
		return null
	var b: Button
	if _has("f_in", code):
		b = mk_btn("ACEITAR AMIZADE", 260, 58, GREEN, 20)
	elif _has("f_out", code):
		b = mk_btn("PEDIDO ENVIADO", 260, 58, GRAY, 20)
		b.disabled = true
		return b
	else:
		b = mk_btn("+ PEDIR AMIZADE", 260, 58, GREEN, 20)
	b.pressed.connect(func():
		_friend_request(code, nm)
		close_modal())
	return b


func profile_remote(m: Dictionary) -> void:
	var d = m.get("data", null)
	var pcode := str(m.get("code", "")).to_upper()
	var pnm := str(m.get("name", "?"))
	if (pnm == "?" or pnm == "") and prof_hint.has(pcode):
		pnm = str(prof_hint[pcode])
		m["name"] = pnm
	if not (d is Dictionary):
		var fb0 := _prof_friend_btn(pcode, pnm)
		if fb0 != null and not fb0.disabled:
			confirm(pnm, "Esse jogador ainda não tem perfil (precisa atualizar o jogo).\nQuer pedir amizade?", "PEDIR AMIZADE", func(): _friend_request(pcode, pnm), "FECHAR", func(): pass)
		else:
			say("%s ainda não tem perfil (precisa atualizar o jogo)." % pnm)
		return
	close_modal()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.7)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dimr)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.05, 0.1, 0.97), 28, Color("5aa9ff"), 3, 24))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(margin(vb, 22))
	var cv := Control.new()
	cv.custom_minimum_size = Vector2(520, 300)
	vb.add_child(cv)
	var nm := str(m.get("name", "?"))
	var online := bool(m.get("online", false))
	cv.draw.connect(func():
		var f: Font = ThemeDB.fallback_font
		AV.draw(cv, Vector2(260, 78), 68, str(d.get("av", "b8")), str(d.get("fr", "simples")), anim_t)
		cv.draw_circle(Vector2(312, 130), 11, Color(0.03, 0.05, 0.08))
		cv.draw_circle(Vector2(312, 130), 8, Color("3ddc84") if online else Color(0.5, 0.5, 0.55))
		cv.draw_string(f, Vector2(0, 184), nm, HORIZONTAL_ALIGNMENT_CENTER, 520, 32, Color.WHITE)
		var ti: Dictionary = AV.find(AV.TITLES, str(d.get("ti", "novato")))
		cv.draw_string(f, Vector2(0, 212), str(ti.name) + "   •   Nível %d" % int(d.get("lvl", 1)), HORIZONTAL_ALIGNMENT_CENTER, 520, 18, Color("f4c542"))
		var dv := clampi(int(d.get("div", 0)), 0, 4)
		_div_badge(cv, Vector2(70, 268), 26, dv)
		cv.draw_string(f, Vector2(104, 264), "%s  •  %d pts" % [game.DIVS[dv].name, int(d.get("pts", 0))], HORIZONTAL_ALIGNMENT_LEFT, 200, 16, game.DIVS[dv].col)
		cv.draw_string(f, Vector2(104, 286), "liga da semana", HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color(1, 1, 1, 0.5))
		var pl := maxi(1, int(d.get("played", 0)))
		cv.draw_string(f, Vector2(300, 254), "Vitórias: %d (%d%%)" % [int(d.get("wins", 0)), int(round(100.0 * int(d.get("wins", 0)) / pl))], HORIZONTAL_ALIGNMENT_LEFT, 220, 16, Color.WHITE)
		cv.draw_string(f, Vector2(300, 276), "Maior sequência: %d" % int(d.get("best", 0)), HORIZONTAL_ALIGNMENT_LEFT, 220, 16, Color.WHITE)
		cv.draw_string(f, Vector2(300, 298), "Conquistas: %d / %d" % [int(d.get("achs", 0)), game.ACHS.size()], HORIZONTAL_ALIGNMENT_LEFT, 220, 16, Color.WHITE))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 14)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(brow)
	var fb := _prof_friend_btn(pcode, nm)
	if fb != null:
		brow.add_child(fb)
	if online and _has("friends", pcode):
		var tb := mk_btn("⇄ NEGOCIAR", 220, 58, Color("d68a10"), 22)
		tb.pressed.connect(func():
			close_modal()
			game.trade.start_with(pcode, nm))
		brow.add_child(tb)
	var ok := mk_btn("FECHAR", 220, 58, GRAY, 22)
	ok.pressed.connect(close_modal)
	brow.add_child(ok)


# conquista nova: aviso que desce do topo
func ach_toast(nm: String, coins: int) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(0.05, 0.07, 0.12, 0.97), 22, GOLD, 3, 16))
	root.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(margin(h, 12))
	var md := Control.new()
	md.custom_minimum_size = Vector2(50, 50)
	md.draw.connect(func():
		md.draw_circle(Vector2(25, 25), 22, Color("8a5a10"))
		md.draw_circle(Vector2(25, 25), 18, Color("ffd34a"))
		md.draw_colored_polygon(_star(Vector2(25, 25), 12, 5), Color.WHITE))
	h.add_child(md)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	h.add_child(tv)
	var l1 := mk_lbl("CONQUISTA DESBLOQUEADA!", 15, Color("f4c542"), 2)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(l1)
	var l2 := mk_lbl("%s   +%d moedas" % [nm, coins], 22, Color.WHITE, 3)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(l2)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var k := get_tree().get_nodes_in_group("ach_toast").size()
	p.add_to_group("ach_toast")
	p.position = Vector2((root.size.x - p.size.x) / 2.0, -120)
	game.play("win", 0.5)
	var tw := p.create_tween()
	tw.tween_interval(0.6 * k)
	tw.tween_property(p, "position:y", 100.0 + 0.0 * k, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	refresh_top()


# ---------------------------------------------------------------- ranking (liga semanal)
func _build_ranking() -> void:
	var v := mk_screen("ranking", 10)
	add_bg("ranking", "res://assets/menu_bg.jpg", 0.2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.9), 26, Color(1, 1, 1, 0.2), 2, 12))
	row.add_child(lp)
	rk_head = Control.new()
	rk_head.custom_minimum_size = Vector2(380, 500)
	lp.add_child(rk_head)
	rk_head.draw.connect(_rank_head_draw)
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", sbox(Color(0.02, 0.05, 0.08, 0.9), 26, Color("5aa9ff"), 3, 12))
	row.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rp.add_child(margin(rv, 12))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.name = "RkTabs"
	rv.add_child(tabs)
	for k in [["todos", "TOP 50"], ["amigos", "AMIGOS"]]:
		var b := mk_btn(k[1], 200, 48, GRAY, 19)
		b.set_meta("tab", k[0])
		b.pressed.connect(func():
			rk_tab = k[0]
			_rank_render())
		tabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(640, 430)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.name = "RkScroll"
	rv.add_child(sc)
	rk_box = VBoxContainer.new()
	rk_box.add_theme_constant_override("separation", 6)
	rk_box.custom_minimum_size = Vector2(620, 0)
	sc.add_child(rk_box)
	var back := mk_btn("◀  VOLTAR", 220, 54, GRAY, 24)
	back.pressed.connect(show_screen.bind("main"))
	v.add_child(back)


func _rank_head_draw() -> void:
	var c := rk_head
	var f: Font = ThemeDB.fallback_font
	var lg: Dictionary = game.league()
	var pts := int(lg.pts)
	var dv: int = game.div_of(pts)
	c.draw_string(f, Vector2(0, 40), "LIGA DA SEMANA", HORIZONTAL_ALIGNMENT_CENTER, 380, 30, Color("f4c542"))
	c.draw_string(f, Vector2(0, 66), "termina em " + game.week_left_txt(), HORIZONTAL_ALIGNMENT_CENTER, 380, 16, Color(1, 1, 1, 0.6))
	_div_badge(c, Vector2(190, 140), 56, dv)
	c.draw_string(f, Vector2(0, 236), str(game.DIVS[dv].name), HORIZONTAL_ALIGNMENT_CENTER, 380, 32, game.DIVS[dv].col)
	c.draw_string(f, Vector2(0, 268), "%d pontos" % pts, HORIZONTAL_ALIGNMENT_CENTER, 380, 22, Color.WHITE)
	var me := int(rk_data.get("me", 0))
	c.draw_string(f, Vector2(0, 296), ("%dº lugar de %d" % [me, int(rk_data.get("total", 0))]) if me > 0 else "Jogue online para entrar no ranking", HORIZONTAL_ALIGNMENT_CENTER, 380, 17, Color(1, 1, 1, 0.75))
	if dv < 4:
		var nx: int = int(game.DIVS[dv + 1].min)
		var lo: int = int(game.DIVS[dv].min)
		var fr := clampf(float(pts - lo) / float(nx - lo), 0.0, 1.0)
		c.draw_style_box(sbox(Color(0, 0, 0, 0.5), 7), Rect2(40, 312, 300, 14))
		c.draw_style_box(sbox(game.DIVS[dv + 1].col, 7), Rect2(40, 312, maxf(14.0, 300.0 * fr), 14))
		c.draw_string(f, Vector2(0, 346), "faltam %d para %s" % [nx - pts, game.DIVS[dv + 1].name], HORIZONTAL_ALIGNMENT_CENTER, 380, 15, Color(1, 1, 1, 0.65))
	c.draw_string(f, Vector2(0, 384), "Vitória online: +20 (+1 a cada 50 apostadas)", HORIZONTAL_ALIGNMENT_CENTER, 380, 14, Color(1, 1, 1, 0.6))
	c.draw_string(f, Vector2(0, 404), "Derrota online: -8", HORIZONTAL_ALIGNMENT_CENTER, 380, 14, Color(1, 1, 1, 0.6))
	c.draw_string(f, Vector2(0, 436), "PRÊMIO NO FIM DA SEMANA", HORIZONTAL_ALIGNMENT_CENTER, 380, 15, Color("f4c542"))
	var x0 := 14.0
	for i in game.DIVS.size():
		var dd: Dictionary = game.DIVS[i]
		var cx: float = x0 + i * 71.0 + 35.0
		c.draw_string(f, Vector2(cx - 36, 462), str(dd.name).left(4), HORIZONTAL_ALIGNMENT_CENTER, 72, 13, dd.col)
		c.draw_string(f, Vector2(cx - 36, 484), str(dd.prize), HORIZONTAL_ALIGNMENT_CENTER, 72, 17, Color.WHITE if i == dv else Color(1, 1, 1, 0.6))


func _ranking_refresh() -> void:
	page_scroll = screens["ranking"].find_child("RkScroll", true, false)
	rk_head.queue_redraw()
	if not game.net.server_ok:
		game.net.connect_server()
		rk_data = {}
		_rank_render()
		_rank_msg("Conectando ao servidor... (se estiver dormindo, pode levar até 1 minuto)")
		get_tree().create_timer(3.0).timeout.connect(func():
			if cur == "ranking" and game.net.server_ok:
				game.net.ask_rank())
		return
	_rank_msg("Carregando ranking...")
	game.net.ask_rank()


func _rank_msg(t: String) -> void:
	for c in rk_box.get_children():
		c.queue_free()
	var l := mk_lbl(t, 18, Color(1, 1, 1, 0.7), 2)
	l.custom_minimum_size = Vector2(600, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rk_box.add_child(l)


func rank_update(m: Dictionary) -> void:
	rk_data = m
	if cur == "ranking":
		rk_head.queue_redraw()
		_rank_render()


func _rank_render() -> void:
	var tabs: HBoxContainer = screens["ranking"].find_child("RkTabs", true, false)
	for b in tabs.get_children():
		var on: bool = str(b.get_meta("tab")) == rk_tab
		b.add_theme_stylebox_override("normal", sbox(BLUE if on else Color(0.09, 0.12, 0.17, 0.95), 18, Color.WHITE if on else Color(1, 1, 1, 0.18), 3 if on else 2, 4))
	if rk_data.is_empty():
		return
	for c in rk_box.get_children():
		c.queue_free()
	var list: Array = rk_data.get("top", []) if rk_tab == "todos" else rk_data.get("friends", [])
	if list.is_empty():
		_rank_msg("Ninguém pontuou ainda nesta semana. Jogue online e seja o primeiro!" if rk_tab == "todos" else "Nenhum amigo pontuou ainda nesta semana.")
		return
	for e in list:
		var mine: bool = str(e.code) == game.my_code().to_upper()
		var pos := int(e.pos)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", sbox(Color(0.12, 0.2, 0.32, 0.95) if mine else Color(0.04, 0.07, 0.11, 0.92), 14, GOLD if mine else Color(1, 1, 1, 0.08), 2, 2))
		rk_box.add_child(row)
		var dc := Control.new()
		dc.custom_minimum_size = Vector2(610, 54)
		row.add_child(dc)
		var dv: int = game.div_of(int(e.pts))
		var nm := str(e.name)
		var av := str(e.get("av", "b8"))
		var fr := str(e.get("fr", "simples"))
		dc.draw.connect(func():
			var f: Font = ThemeDB.fallback_font
			var pc := [Color("ffd34a"), Color("d6dde5"), Color("d08a4a")]
			if pos <= 3:
				dc.draw_circle(Vector2(34, 27), 19, pc[pos - 1])
				dc.draw_string(f, Vector2(15, 35), str(pos), HORIZONTAL_ALIGNMENT_CENTER, 38, 20, Color("2a1a00"))
			else:
				dc.draw_string(f, Vector2(4, 35), "%dº" % pos, HORIZONTAL_ALIGNMENT_CENTER, 60, 19, Color(1, 1, 1, 0.8))
			AV.draw(dc, Vector2(92, 27), 22, av, fr)
			dc.draw_string(f, Vector2(126, 35), nm + ("  (você)" if mine else ""), HORIZONTAL_ALIGNMENT_LEFT, 280, 21, Color.WHITE)
			_div_badge(dc, Vector2(452, 27), 17, dv)
			dc.draw_string(f, Vector2(476, 33), str(game.DIVS[dv].name).left(4), HORIZONTAL_ALIGNMENT_LEFT, 60, 13, game.DIVS[dv].col)
			dc.draw_string(f, Vector2(500, 35), str(int(e.pts)), HORIZONTAL_ALIGNMENT_RIGHT, 100, 22, Color("ffe066")))



# prévia animada do efeito de vitória na loja
func _wfx_preview(pv: Control, kind: String) -> void:
	var VF = load("res://victory_fx.gd")
	var st := {"ps": [], "t": 0.0}
	var rng := RandomNumberGenerator.new()
	var dc := Control.new()
	dc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dc.clip_contents = true
	dc.draw.connect(func():
		dc.draw_style_box(sbox(Color(0.02, 0.04, 0.08), 14), Rect2(Vector2.ZERO, Vector2(184, 150)))
		VF.draw_fx(dc, Vector2(184, 150), st.ps, st.t, kind)
		dc.draw_string(ThemeDB.fallback_font, Vector2(0, 84), "VITÓRIA!", HORIZONTAL_ALIGNMENT_CENTER, 184, 26, Color("f4c542")))
	pv.add_child(dc)
	var tw := dc.create_tween().set_loops()
	tw.tween_callback(func():
		st.t = float(st.t) + 0.033
		VF.spawn(st.ps, Vector2(184, 150), kind, 0.033 * 0.35, rng)
		VF.step(st.ps, 0.033, kind)
		dc.queue_redraw()).set_delay(0.033)


func _packs_render() -> void:
	for pk in game.PACKS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(300, 404)
		var col: Color = pk.col
		card.add_theme_stylebox_override("panel", sbox(NAVY, 22, col, 3, 10))
		shop_row.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		card.add_child(margin(vb, 16))
		var pv := Control.new()
		pv.custom_minimum_size = Vector2(268, 190)
		pv.draw.connect(func(): _draw_pack(pv, Vector2(134, 100), 1.0, col, 0.0))
		vb.add_child(pv)
		vb.add_child(mk_lbl(str(pk.name), 28, Color.WHITE, 4))
		var tg := mk_lbl(str(pk.tag), 17, Color(1, 1, 1, 0.7))
		tg.custom_minimum_size = Vector2(268, 0)
		tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(tg)
		var pid := str(pk.id)
		var b: Button
		if int(pk.grana) > 0:
			b = mk_btn("ABRIR  ◆ %d" % int(pk.grana), 268, 60, PURPLE if int(game.save.grana) >= int(pk.grana) else GRAY, 24)
		else:
			b = mk_btn("ABRIR  %d" % int(pk.price), 268, 60, GOLD if int(game.save.coins) >= int(pk.price) else RED, 24)
		b.pressed.connect(_pack_buy.bind(pid))
		vb.add_child(b)


func _draw_pack(c: Control, ctr: Vector2, sc: float, col: Color, shake: float) -> void:
	c.draw_set_transform(ctr, sin(shake * 40.0) * 0.08 * minf(shake, 1.0), Vector2(sc, sc))
	var r := Rect2(-70, -50, 140, 110)
	c.draw_style_box(sbox(Color(0, 0, 0, 0.35), 14), Rect2(r.position + Vector2(5, 8), r.size))
	c.draw_style_box(sbox(col.darkened(0.25), 14, col.lightened(0.3), 3), r)
	c.draw_style_box(sbox(col, 10, col.lightened(0.4), 3), Rect2(-78, -70, 156, 34))
	c.draw_rect(Rect2(-12, -70, 24, 130), Color("c0303a"))
	c.draw_rect(Rect2(-78, -58, 156, 12), Color("c0303a"))
	c.draw_circle(Vector2(-16, -76), 14, Color("e0404a"))
	c.draw_circle(Vector2(16, -76), 14, Color("e0404a"))
	c.draw_string(ThemeDB.fallback_font, Vector2(-70, 34), "?", HORIZONTAL_ALIGNMENT_CENTER, 140, 54, Color(1, 1, 1, 0.85))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pack_buy(id: String) -> void:
	var pk: Dictionary = {}
	for p in game.PACKS:
		if str(p.id) == id:
			pk = p
	if game.pack_items(int(pk.tier)).is_empty() and int(pk.tier) < 2:
		say("Você já tem todos os itens deste pacote! Experimente outro pacote.")
		return
	if int(pk.grana) > 0:
		if int(game.save.grana) < int(pk.grana):
			say("Grana insuficiente! Ganhe Grana no Passe, na Roleta e no prêmio do 7º dia.")
			return
		game.save.grana = int(game.save.grana) - int(pk.grana)
		game.eco(0, -int(pk.grana), "pacote")
	else:
		if int(game.save.coins) < int(pk.price):
			say("Moedas insuficientes!")
			return
		game.save.coins -= int(pk.price)
		game.eco(-int(pk.price), 0, "pacote")
	game.write_save()
	refresh_top()
	var res: Dictionary = game.open_pack(id)
	# animação: o pacote treme e abre
	close_modal()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.75)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dimr)
	var box := Control.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.add_child(box)
	var st := {"t": 0.0}
	var col: Color = pk.col
	box.draw.connect(func():
		var sc := 1.6 + float(st.t) * 0.3
		_draw_pack(box, box.size / 2.0, sc, col, float(st.t)))
	game.play("click", 0.8)
	var tw := box.create_tween()
	tw.tween_method(func(v: float):
		st.t = v
		box.queue_redraw(), 0.0, 1.4, 1.4)
	tw.tween_callback(func():
		game.play("pocket")
		var r := {"coins": int(res.coins)} if res.has("coins") else {"item": str(res.item)}
		show_reward(str(pk.name) + " aberto!", str(res.txt), r)
		_shop_refresh())



# ---------------------------------------------------------------- torneio
func tour_create_ask() -> void:
	close_modal()
	var sel := {"g": game.net_game, "fee": 0}
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
	p.add_theme_stylebox_override("panel", sbox(Color(0.03, 0.05, 0.1, 0.97), 28, Color("ff7a6a"), 3, 24))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(margin(vb, 26))
	vb.add_child(mk_lbl("CRIAR TORNEIO", 34, Color("f4c542"), 6))
	vb.add_child(mk_lbl("De 3 a 8 amigos, mata-mata 1 contra 1. O campeão leva tudo!", 18, Color(1, 1, 1, 0.75), 2))
	vb.add_child(_section("QUAL JOGO?"))
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", 12)
	gr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(gr)
	var gb := []
	for k in [["sinuca", "SINUCA"], ["truco", "TRUCO"]]:
		var b := mk_btn(k[1], 220, 60, GRAY, 26)
		gr.add_child(b)
		gb.append(b)
	vb.add_child(_section("INSCRIÇÃO (cada jogador paga; o campeão leva tudo + bônus)"))
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 10)
	fr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(fr)
	var fb := []
	var fees := [0, 50, 100, 500]
	for v in fees:
		var b2 := mk_btn("GRÁTIS" if v == 0 else str(v), 106, 54, GRAY, 20)
		fr.add_child(b2)
		fb.append(b2)
	var paint := func():
		_seg_paint(gb, 0 if sel.g == "sinuca" else 1, [GREEN, Color("b8323a")])
		_seg_paint(fb, fees.find(int(sel.fee)), [GOLD])
	for i in 2:
		gb[i].pressed.connect(func():
			sel.g = "sinuca" if i == 0 else "truco"
			paint.call())
	for i in fees.size():
		fb[i].pressed.connect(func():
			if int(fees[i]) > int(game.save.coins):
				say("Você não tem moedas para essa inscrição.")
				return
			sel.fee = fees[i]
			paint.call())
	paint.call()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var ok := mk_btn("CRIAR TORNEIO", 260, 64, Color("c0392b"), 24)
	ok.pressed.connect(func():
		close_modal()
		if not game.net.server_ok:
			game.net.connect_server()
			say("Conectando ao servidor... tente de novo em alguns segundos.")
			return
		game.net.stop_search()
		game.net.world_cancel()
		game.net_game = str(sel.g)
		game.net_team = false
		online_mode = "world"
		game.save["bet_on"] = int(sel.fee)
		game.net.world_send({"t": "tcreate", "game": sel.g, "stake": int(sel.fee)}))
	row.add_child(ok)
	var no := mk_btn("CANCELAR", 200, 64, GRAY, 22)
	no.pressed.connect(close_modal)
	row.add_child(no)


func _build_torneio() -> void:
	var v := mk_screen("torneio", 8)
	add_bg("torneio", "res://assets/menu_bg.jpg", 0.25)
	v.add_child(mk_lbl("TORNEIO", 44, Color("f4c542"), 8))
	tour_canvas = Control.new()
	tour_canvas.custom_minimum_size = Vector2(1180, 470)
	tour_canvas.draw.connect(_tour_draw)
	v.add_child(tour_canvas)
	tour_info = mk_lbl("", 19, Color.WHITE, 3)
	tour_info.custom_minimum_size = Vector2(1100, 0)
	tour_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tour_info)
	tour_leave_btn = mk_btn("SAIR DO TORNEIO", 300, 54, GRAY, 22)
	tour_leave_btn.pressed.connect(func():
		if game.tour_active():
			confirm("SAIR DO TORNEIO?", "Se sair agora, você é eliminado e perde a inscrição.", "SAIR", func():
				game.net.world_send({"t": "tleave"})
				game.tour = {}
				back_to_lobby() if in_lobby() else show_screen("online"), "CONTINUAR", close_modal)
		else:
			game.tour = {}
			back_to_lobby() if in_lobby() else show_screen("online"))
	v.add_child(tour_leave_btn)


func _tname(code) -> String:
	if code == null or str(code) == "" or str(code) == "<null>":
		return ""
	var nm: Dictionary = game.tour.get("names", {})
	return str(nm.get(str(code), "?"))


func _tour_draw() -> void:
	var t: Dictionary = game.tour
	if t.is_empty():
		return
	var c := tour_canvas
	var f: Font = ThemeDB.fallback_font
	var rounds: Array = t.rounds
	var size0: int = (rounds[0] as Array).size() * 2
	var nr := 1
	while (1 << nr) < size0:
		nr += 1
	var W := c.size.x
	var H := c.size.y
	var colw := (W - 200.0) / float(nr)
	var bw := minf(colw - 40.0, 230.0)
	var me: String = game.my_code().to_upper()
	var names_r := ["FINAL", "SEMIFINAL", "QUARTAS"]
	for r in nr:
		var cnt: int = size0 >> (r + 1)
		var x := 10.0 + r * colw
		var lbl: String = names_r[nr - 1 - r] if nr - 1 - r < names_r.size() else "RODADA %d" % (r + 1)
		c.draw_string(f, Vector2(x, 18), lbl, HORIZONTAL_ALIGNMENT_CENTER, bw, 15, Color("f4c542"))
		for i in cnt:
			var mt: Dictionary = {}
			if r < rounds.size() and i < (rounds[r] as Array).size():
				mt = rounds[r][i]
			var slot_h := (H - 30.0) / float(cnt)
			var cy := 30.0 + slot_h * (i + 0.5)
			var bh := 58.0
			var rr := Rect2(x, cy - bh / 2.0, bw, bh)
			var live: bool = bool(mt.get("live", false))
			var mine: bool = str(mt.get("a", "")) == me or str(mt.get("b", "")) == me
			c.draw_style_box(sbox(Color(0.03, 0.06, 0.1, 0.95), 12, Color("ff5a5a") if live else (GOLD if mine else Color(1, 1, 1, 0.18)), 3 if live or mine else 1, 4), rr)
			var w = mt.get("w", null)
			for k in 2:
				var code = mt.get("a" if k == 0 else "b", null)
				var nm := _tname(code)
				var y := rr.position.y + 22.0 + k * 26.0
				var won: bool = w != null and str(w) == str(code) and nm != ""
				var lost: bool = w != null and str(w) != str(code) and nm != ""
				var col := Color("3ddc84") if won else (Color(1, 1, 1, 0.35) if lost else Color.WHITE)
				var shown: String = nm if nm != "" else ("—" if mt.is_empty() else "(passa direto)")
				if str(code) == me:
					shown += " (você)"
				c.draw_string(f, Vector2(rr.position.x + 10, y), shown.left(22), HORIZONTAL_ALIGNMENT_LEFT, bw - 20, 17, col)
				if won:
					c.draw_string(f, Vector2(rr.position.x, y), "✓", HORIZONTAL_ALIGNMENT_RIGHT, bw - 10, 17, col)
			if live:
				c.draw_style_box(sbox(Color("e53935"), 6), Rect2(rr.position + Vector2(bw - 70, -10), Vector2(64, 18)))
				c.draw_string(f, rr.position + Vector2(bw - 70, 4), "AO VIVO", HORIZONTAL_ALIGNMENT_CENTER, 64, 12, Color.WHITE)
			# linha até a próxima rodada
			var nx := x + colw
			var ny := 30.0 + ((H - 30.0) / float(maxi(1, cnt >> 1))) * (i / 2 + 0.5) if cnt > 1 else cy
			c.draw_line(Vector2(rr.end.x, cy), Vector2(rr.end.x + 18, cy), Color(1, 1, 1, 0.3), 2.0)
			c.draw_line(Vector2(rr.end.x + 18, cy), Vector2(rr.end.x + 18, ny), Color(1, 1, 1, 0.3), 2.0)
			c.draw_line(Vector2(rr.end.x + 18, ny), Vector2(nx if r < nr - 1 else W - 180.0, ny), Color(1, 1, 1, 0.3), 2.0)
	# campeão
	var ch := Rect2(W - 180.0, H / 2.0 - 70.0, 170.0, 140.0)
	var champ = t.get("champ", null)
	c.draw_style_box(sbox(Color(0.12, 0.09, 0.02, 0.95), 18, GOLD, 3, 10), ch)
	var crown := ch.position + Vector2(85, 40)
	c.draw_colored_polygon(PackedVector2Array([crown + Vector2(-30, 14), crown + Vector2(-30, -10), crown + Vector2(-15, 2), crown + Vector2(0, -20), crown + Vector2(15, 2), crown + Vector2(30, -10), crown + Vector2(30, 14)]), Color("ffd34a"))
	c.draw_string(f, ch.position + Vector2(0, 84), "CAMPEÃO", HORIZONTAL_ALIGNMENT_CENTER, 170, 16, Color("f4c542"))
	c.draw_string(f, ch.position + Vector2(0, 114), _tname(champ) if champ != null else "?", HORIZONTAL_ALIGNMENT_CENTER, 170, 22, Color.WHITE)


func _tour_paint() -> void:
	if tour_canvas == null:
		return
	tour_canvas.queue_redraw()
	var t: Dictionary = game.tour
	if t.is_empty():
		tour_info.text = "Nenhum torneio agora."
		return
	var me: String = game.my_code().to_upper()
	var out: Array = t.get("out", [])
	var fee := int(t.fee)
	var prize := int(t.pot) + 50 * int(t.n)
	var head := "%s  •  %d jogadores  •  %s  •  prêmio do campeão: %d moedas" % ["TRUCO" if str(t.game) == "truco" else "SINUCA", int(t.n), "grátis" if fee <= 0 else "inscrição %d" % fee, prize]
	var st := ""
	if bool(t.done):
		st = "VOCÊ É O CAMPEÃO! 🏆" if str(t.get("champ", "")) == me else "Torneio encerrado. Campeão: %s" % _tname(t.get("champ", ""))
		st = st.replace(" 🏆", "")
		tour_leave_btn.text = "VOLTAR AO LOBBY"
	elif out.has(me):
		st = "Você foi eliminado. Acompanhe a chave até o fim."
		tour_leave_btn.text = "SAIR"
	else:
		st = "Você está na disputa! Sua próxima partida começa assim que a rodada estiver pronta."
		tour_leave_btn.text = "SAIR DO TORNEIO"
	tour_info.text = head + "\n" + st


func tour_refresh() -> void:
	var t: Dictionary = game.tour
	if cur == "torneio":
		_tour_paint()
	var playing: bool = (game.mode == game.Mode.ONLINE and game.st != game.St.MENU and game.st != game.St.OVER) or (truco_node != null and is_instance_valid(truco_node) and truco_node.phase != "over")
	if playing:
		return
	var in_over: bool = cur == "over" or (truco_node != null and is_instance_valid(truco_node))
	if in_over:
		# deixa ver o resultado da partida e depois volta para a chave
		get_tree().create_timer(3.5).timeout.connect(func():
			var still_over: bool = cur == "over" or (truco_node != null and is_instance_valid(truco_node) and truco_node.phase == "over")
			if not still_over or game.tour.is_empty():
				return
			if truco_node != null and is_instance_valid(truco_node):
				truco_node.queue_free()
				truco_node = null
				game.paused = false
			if game.mode == game.Mode.ONLINE and game.st == game.St.OVER:
				game.go_menu()
			show_screen("torneio"))
		return
	if cur in ["online", "main", "torneio", "amigos", "play", "truco"] or str(t.get("phase", "")) == "start":
		show_screen("torneio")



func _fr_btn(b: Button, cb: Callable) -> Button:
	b.pressed.connect(cb)
	return b
