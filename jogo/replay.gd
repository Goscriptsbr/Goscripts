extends Node
# REPLAY: grava sempre os últimos 30 segundos da partida de sinuca e, quando o jogador toca em
# SALVAR, guarda no jogo (AJUSTES > MEUS REPLAYS). De lá ele assiste em tela cheia e salva na galeria.
#
# Leve: durante a partida NÃO se grava imagem nenhuma (isso pesava nos celulares fracos). Grava-se só
# o "estado" da mesa 30 vezes por segundo: onde está cada bola, como está girando e o taco. Para
# assistir, o jogo redesenha a mesa com esses dados (qualidade máxima). Para a galeria, o replay é
# tocado e fotografado quadro a quadro só na hora de salvar, e vira um WebP animado.

const W := 960               # largura do arquivo salvo na galeria
const REC_HZ := 30.0         # amostras por segundo da gravação (estado da mesa)
const OUT_FPS := 15.0        # quadros por segundo do arquivo da galeria
const SECS := 30.0
const MAX_FRAMES := int(REC_HZ * SECS)
const MAX_SAVED := 10
const QUALITY := 0.75
const NB := 16               # bolas 0..15
const FPB := 10              # números por bola: x, y, on, drop, dx, dy, qx, qy, qz, qw

var game: Node
var H := 432
var rec: Array = []          # quadros gravados (dicionários pequenos)
var rec_felt := ""
var rec_t := 0.0
var recording := false
var pend_shot: Array = []
var busy := false
var result_path := ""
var result_err := ""

# fotografar para a galeria (só na hora de salvar)
var sv: SubViewport
var tr: TextureRect
var enc_thread: Thread
var enc_sem := Semaphore.new()
var enc_mx := Mutex.new()
var enc_queue: Array = []    # [ordem, Image]
var enc_out: Array = []      # [ordem, PackedByteArray]
var enc_quit := false


func setup(g: Node) -> void:
	game = g
	sv = SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.disable_3d = true
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(sv)
	tr = TextureRect.new()
	tr.size = Vector2(W, H)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture = get_tree().root.get_texture()
	sv.add_child(tr)
	enc_thread = Thread.new()
	enc_thread.start(_enc_loop)


func _exit_tree() -> void:
	enc_quit = true
	enc_sem.post()
	if enc_thread != null and enc_thread.is_started():
		enc_thread.wait_to_finish()


func _enc_loop() -> void:
	while true:
		enc_sem.wait()
		if enc_quit:
			return
		enc_mx.lock()
		var job: Array = enc_queue.pop_front() if not enc_queue.is_empty() else []
		enc_mx.unlock()
		if job.is_empty():
			continue
		var img: Image = job[1]
		img.convert(Image.FORMAT_RGB8)
		var bytes := img.save_webp_to_buffer(true, QUALITY)
		enc_mx.lock()
		enc_out.append([job[0], bytes])
		enc_mx.unlock()


func _fit_size() -> void:
	var rs2: Vector2 = get_tree().root.get_visible_rect().size
	if rs2.x < 10.0:
		return
	H = clampi(int(round(float(W) * rs2.y / rs2.x / 2.0)) * 2, 300, 720)
	sv.size = Vector2i(W, H)
	tr.size = Vector2(W, H)


# o jogo avisa quando sai uma tacada (para o replay mostrar o efeito do taco ELITE na hora certa)
func note_shot(imp: String, p: Vector2, ang: float, pw: float) -> void:
	if recording and imp != "":
		pend_shot.append([imp, p.x, p.y, ang, pw])


func _snap() -> Dictionary:
	var f := PackedFloat32Array()
	f.resize(NB * FPB)
	for b in game.balls:
		var n := int(b.n)
		if n < 0 or n >= NB:
			continue
		var o := n * FPB
		var p: Vector2 = b.pos
		var dp: Vector2 = b.get("dpos", p)
		var q := Quaternion((b.basis as Basis).orthonormalized())
		f[o] = p.x
		f[o + 1] = p.y
		f[o + 2] = 1.0 if bool(b.on) else 0.0
		f[o + 3] = float(b.get("drop", -1.0))
		f[o + 4] = dp.x
		f[o + 5] = dp.y
		f[o + 6] = q.x
		f[o + 7] = q.y
		f[o + 8] = q.z
		f[o + 9] = q.w
	var d := {"f": f, "a": game.aim_angle, "pl": game.cur_pull(), "sx": (game.spin as Vector2).x,
		"cv": (game.st == game.St.AIM or game.st == game.St.STRIKE), "c": str(game.turn_cue_def().get("id", ""))}
	if not pend_shot.is_empty():
		d["imp"] = pend_shot.duplicate()
		pend_shot.clear()
	return d


func _process(delta: float) -> void:
	if game == null:
		return
	_play_tick(delta)
	_old_play_tick(delta)
	var want: bool = game.rec_active() and not game.paused
	if not want:
		if recording and not game.rec_active():
			recording = false
		return
	if not recording:
		recording = true
		rec.clear()
		rec_t = 0.0
		pend_shot.clear()
		rec_felt = game.felt_override if game.felt_override != "" else game.my_felt_tag()
	rec_t += delta
	var step := 1.0 / REC_HZ
	if rec_t >= step:
		rec_t = fmod(rec_t, step)
		rec.append(_snap())
		while rec.size() > MAX_FRAMES:
			rec.pop_front()


func can_save() -> bool:
	return rec.size() >= int(REC_HZ) and not busy


# botão ● 30s: guarda os últimos 30s no jogo (instantâneo, quase nada de espaço)
func save_clip() -> void:
	if busy:
		game.ui.say("Espere terminar o replay que está sendo salvo...")
		return
	if rec.size() < int(REC_HZ):
		game.ui.say("Ainda não tem jogada gravada para salvar.")
		return
	if list_local().size() >= MAX_SAVED:
		game.ui.confirm("REPLAYS CHEIOS", "Você já tem %d replays guardados (o máximo).\nApague algum em AJUSTES > MEUS REPLAYS para salvar outro." % MAX_SAVED, "OK", func(): pass, "", Callable())
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var nm := "Sinucou_%s" % stamp
	var ud := local_dir()
	DirAccess.make_dir_recursive_absolute(ud)
	var f := FileAccess.open(ud + "/" + nm + ".rpl", FileAccess.WRITE)
	if f == null:
		game.ui.say("Não consegui salvar o replay (sem espaço?).")
		return
	f.store_var({"fmt": "state", "hz": REC_HZ, "felt": rec_felt, "frames": rec.duplicate()})
	f.close()
	game.ui.say("Replay salvo! Veja e mande para a galeria em AJUSTES > MEUS REPLAYS.")


# grava onde a galeria mostra. Ordem: DCIM/Camera (aparece junto das fotos), DCIM, Imagens, Downloads.
func _write_gallery(fname: String, bytes: PackedByteArray) -> void:
	if OS.get_name() == "Android":
		OS.request_permission("android.permission.WRITE_EXTERNAL_STORAGE")
	var dcim := OS.get_system_dir(OS.SYSTEM_DIR_DCIM)
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var tries: Array = []
	if dcim != "":
		tries.append([dcim + "/Camera", "Galeria > Câmera"])
		tries.append([dcim, "Galeria > DCIM"])
	if pics != "":
		tries.append([pics, "Galeria > Imagens (Pictures)"])
	if dl != "":
		tries.append([dl, "pasta Downloads"])
	var errs: Array = []
	for tr2 in tries:
		var d: String = tr2[0]
		if not DirAccess.dir_exists_absolute(d):
			DirAccess.make_dir_recursive_absolute(d)
		var path := d + "/" + fname
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			errs.append(str(FileAccess.get_open_error()))
			continue
		f.store_buffer(bytes)
		f.close()
		if FileAccess.file_exists(path):
			result_path = path
			_done(true, "Replay salvo em:\n%s" % tr2[1])
			return
		errs.append("x")
	_done(false, "O celular não deixou o jogo gravar na galeria (erro %s).\nUse o botão ENVIAR: ele abre o replay no app de fotos, e de lá você salva ou manda no WhatsApp." % ",".join(errs))


func _done(ok: bool, msg: String) -> void:
	result_err = "" if ok else msg
	print("REPLAY salvo=", ok, " ", result_path)
	game.ui.confirm("REPLAY SALVO!" if ok else "REPLAY", msg, "OK", func(): pass, "", Callable())


# ---------------------------------------------------------------- replays guardados no jogo
static func local_dir() -> String:
	return OS.get_user_data_dir() + "/replays"


# nomes (sem extensão), do mais novo para o mais velho
static func list_local() -> Array:
	var out: Array = []
	var da := DirAccess.open(local_dir())
	if da == null:
		return out
	for fn in da.get_files():
		if (fn.ends_with(".rpl") or fn.ends_with(".gif")) and not fn.begins_with("_") and not out.has(fn.get_basename()):
			out.append(fn.get_basename())
	out.sort_custom(func(a, b): return str(a).to_lower() > str(b).to_lower())
	return out


static func delete_local(nm: String) -> void:
	DirAccess.remove_absolute(local_dir() + "/" + nm + ".gif")
	DirAccess.remove_absolute(local_dir() + "/" + nm + ".rpl")


func _load_rpl(nm: String) -> Dictionary:
	var f := FileAccess.open(local_dir() + "/" + nm + ".rpl", FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	f.close()
	return d if d is Dictionary else {}


# ABRIR / ENVIAR: monta o arquivo animado e abre no app de fotos do celular
func open_local(nm: String) -> void:
	var gif := local_dir() + "/" + nm + ".gif"
	if FileAccess.file_exists(gif):
		OS.shell_open(gif)
		return
	var d := _load_rpl(nm)
	if d.is_empty():
		game.ui.say("Replay não encontrado.")
		return
	if str(d.get("fmt", "")) == "state":
		export_state(d, "open")
		return
	var path := ""
	var bytes := PackedByteArray()
	if str(d.get("fmt", "")) == "webp":
		path = local_dir() + "/_envio.webp"
		bytes = build_webp(d.frames, int(d.w), int(d.h), int(round(1000.0 / float(d.get("fps", 12.0)))))
	else:
		path = local_dir() + "/_envio.gif"
		bytes = build_gif(d.frames, d.rs, d.get("pals", []), int(d.w), int(d.h), int(round(100.0 / float(d.get("fps", 8.0)))))
	DirAccess.remove_absolute(local_dir() + "/_envio.webp")
	DirAccess.remove_absolute(local_dir() + "/_envio.gif")
	var fo := FileAccess.open(path, FileAccess.WRITE)
	if fo == null:
		game.ui.say("Não consegui preparar o replay.")
		return
	fo.store_buffer(bytes)
	fo.close()
	if OS.shell_open(path) != OK:
		game.ui.say("Não consegui abrir o replay neste celular.")


# ---------------------------------------------------------------- assistir dentro do jogo
var play_tex: TextureRect = null
var play_mat: Material = null
var play_d: Dictionary = {}
var play_i := 0
var play_t := 0.0


func is_state(nm: String) -> bool:
	return str(_load_rpl(nm).get("fmt", "")) == "state"


func play_local(nm: String, target: TextureRect) -> bool:
	var d := _load_rpl(nm)
	if d.is_empty() or not d.has("frames") or (d.frames as Array).is_empty() or str(d.get("fmt", "")) == "state":
		return false
	if play_mat == null:
		play_mat = target.material
	play_d = d
	play_i = 0
	play_t = 0.0
	play_tex = target
	target.texture = null
	# quadros WebP já têm as cores; os replays antigos (128 cores) usam o shader de paleta
	var is_webp := str(d.get("fmt", "")) == "webp"
	target.material = null if is_webp else play_mat
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if is_webp else CanvasItem.TEXTURE_FILTER_NEAREST
	_show_frame()
	return true


func stop_play() -> void:
	play_tex = null
	play_d = {}


func _old_play_tick(delta: float) -> void:
	if play_tex == null or play_d.is_empty():
		return
	if not is_instance_valid(play_tex) or not play_tex.is_visible_in_tree():
		stop_play()
		return
	var fps := float(play_d.get("fps", 12.0))
	play_t += delta
	if play_t >= 1.0 / fps:
		play_t = fmod(play_t, 1.0 / fps)
		play_i = (play_i + 1) % (play_d.frames as Array).size()
		_show_frame()


func _show_frame() -> void:
	if play_tex == null or play_d.is_empty() or not is_instance_valid(play_tex):
		return
	var img: Image
	var w := int(play_d.w)
	var h := int(play_d.h)
	if str(play_d.get("fmt", "")) == "webp":
		img = Image.new()
		if img.load_webp_from_buffer(play_d.frames[play_i]) != OK:
			return
	else:
		var raw: PackedByteArray = (play_d.frames[play_i] as PackedByteArray).decompress(int(play_d.rs[play_i]), FileAccess.COMPRESSION_FASTLZ)
		if raw.size() != w * h:
			return
		var ps: Array = play_d.get("pals", [])
		var pal: PackedByteArray = ps[play_i] if play_i < ps.size() else cube_palette()
		var arr := PackedVector3Array()
		for i in 128:
			arr.append(Vector3(pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2]) / 255.0)
		if play_tex.material is ShaderMaterial:
			(play_tex.material as ShaderMaterial).set_shader_parameter("pal", arr)
		img = Image.create_from_data(w, h, false, Image.FORMAT_R8, raw)
	var tex := play_tex.texture as ImageTexture
	if tex == null or tex.get_width() != img.get_width() or tex.get_height() != img.get_height() or tex.get_format() != img.get_format():
		play_tex.texture = ImageTexture.create_from_image(img)
	else:
		tex.update(img)


# ---------------------------------------------------------------- assistir em tela cheia (estado)
# A mesa de verdade do jogo vira a "televisão": as bolas e o taco são colocados nas posições
# gravadas (com movimento suave entre uma amostra e outra).
var sp_d: Dictionary = {}
var sp_t := 0.0
var sp_speed := 1.0
var sp_play := false
var sp_last_i := -1
var sp_ui: CanvasLayer = null
var sp_bar: Control = null
var sp_btn_play: Button = null
var sp_btn_speed: Button = null
var sp_name := ""
var exporting := false


func start_watch(nm: String) -> void:
	var d := _load_rpl(nm)
	if str(d.get("fmt", "")) != "state" or (d.frames as Array).size() < 2:
		game.ui.say("Não consegui abrir esse replay.")
		return
	sp_name = nm
	game.go_menu()
	game.ui.close_modal()
	game.ui.show_screen("")
	game.felt_override = str(d.get("felt", ""))
	game.apply_felt()
	game.st = game.St.REPLAY
	game.paused = false
	sp_d = d
	sp_t = 0.0
	sp_speed = 1.0
	sp_play = true
	sp_last_i = -1
	_apply_state(0.0)
	_build_watch_ui()


func stop_watch() -> void:
	sp_play = false
	sp_d = {}
	if sp_ui != null and is_instance_valid(sp_ui):
		sp_ui.queue_free()
	sp_ui = null
	game.rp_cue_vis = false
	if game.st == game.St.REPLAY:
		game.st = game.St.MENU
	game.go_menu()
	game.ui.open_replays()


func _sp_len() -> float:
	return float((sp_d.frames as Array).size() - 1) / float(sp_d.get("hz", REC_HZ))


func _play_tick(delta: float) -> void:
	if sp_d.is_empty() or exporting:
		return
	if sp_play:
		sp_t += delta * sp_speed
		if sp_t >= _sp_len():
			sp_t = _sp_len()
			sp_play = false
			if sp_btn_play != null:
				sp_btn_play.text = "↻ DE NOVO"
		_apply_state(sp_t)
	if sp_bar != null:
		sp_bar.queue_redraw()


func _ball_by_n() -> Dictionary:
	var m := {}
	for b in game.balls:
		m[int(b.n)] = b
	return m


# põe a mesa no instante t (segundos) do replay
func _apply_state(t: float) -> void:
	var fr: Array = sp_d.frames
	var hz := float(sp_d.get("hz", REC_HZ))
	var x := clampf(t * hz, 0.0, float(fr.size() - 1))
	var i0 := int(floor(x))
	var i1 := mini(i0 + 1, fr.size() - 1)
	var k := x - float(i0)
	var a: Dictionary = fr[i0]
	var b: Dictionary = fr[i1]
	var fa: PackedFloat32Array = a.f
	var fb: PackedFloat32Array = b.f
	var bm := _ball_by_n()
	for n in NB:
		if not bm.has(n):
			continue
		var bl: Dictionary = bm[n]
		var o := n * FPB
		var on_a := fa[o + 2] > 0.5
		var on_b := fb[o + 2] > 0.5
		var pa := Vector2(fa[o], fa[o + 1])
		var pb := Vector2(fb[o], fb[o + 1])
		bl.on = on_a
		bl.vel = Vector2.ZERO
		bl.pos = pa.lerp(pb, k) if on_a and on_b else pa
		bl.drop = lerpf(fa[o + 3], fb[o + 3], k) if not on_a and fa[o + 3] >= 0.0 and fb[o + 3] >= 0.0 else fa[o + 3]
		bl.dpos = Vector2(fa[o + 4], fa[o + 5])
		var qa := Quaternion(fa[o + 6], fa[o + 7], fa[o + 8], fa[o + 9])
		var qb := Quaternion(fb[o + 6], fb[o + 7], fb[o + 8], fb[o + 9])
		if qa.is_normalized() and qb.is_normalized():
			bl.basis = Basis(qa.slerp(qb, k))
	game.aim_angle = lerp_angle(float(a.a), float(b.a), k)
	game.rp_pull = lerpf(float(a.pl), float(b.pl), k)
	game.rp_cue_vis = bool(a.cv)
	game.rp_cue_id = str(a.c)
	game.spin = Vector2(float(a.sx), 0.0)
	# efeitos de taco ELITE: dispara quando passa pelo quadro da tacada
	if i0 != sp_last_i:
		if sp_last_i >= 0 and i0 > sp_last_i:
			for j in range(sp_last_i + 1, i0 + 1):
				var fj: Dictionary = fr[j]
				for e in fj.get("imp", []):
					game.spawn_impact(str(e[0]), Vector2(e[1], e[2]), float(e[3]), float(e[4]))
		sp_last_i = i0


func _build_watch_ui() -> void:
	if sp_ui != null and is_instance_valid(sp_ui):
		sp_ui.queue_free()
	var ui = game.ui
	sp_ui = CanvasLayer.new()
	sp_ui.layer = 60
	add_child(sp_ui)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.position = Vector2(16, 12)
	sp_ui.add_child(top)
	var bx: Button = ui.mk_btn("◀ SAIR", 150, 56, Color("4a5568"), 20)
	bx.pressed.connect(stop_watch)
	top.add_child(bx)
	sp_btn_play = ui.mk_btn("❚❚ PAUSAR", 170, 56, Color("2b6cb0"), 20)
	sp_btn_play.pressed.connect(func():
		if not sp_play and sp_t >= _sp_len() - 0.01:
			sp_t = 0.0
			sp_last_i = -1
		sp_play = not sp_play
		sp_btn_play.text = "❚❚ PAUSAR" if sp_play else "▶ PLAY")
	top.add_child(sp_btn_play)
	sp_btn_speed = ui.mk_btn("VELOCIDADE 1x", 210, 56, Color("6b46c1"), 19)
	sp_btn_speed.pressed.connect(func():
		sp_speed = 0.5 if sp_speed == 1.0 else (0.25 if sp_speed == 0.5 else 1.0)
		sp_btn_speed.text = "VELOCIDADE " + ("1x" if sp_speed == 1.0 else ("0.5x" if sp_speed == 0.5 else "0.25x")))
	top.add_child(sp_btn_speed)
	var bg: Button = ui.mk_btn("⬇ SALVAR NA GALERIA", 290, 56, Color("1fa85a"), 19)
	bg.pressed.connect(func(): export_state(sp_d, "gallery"))
	top.add_child(bg)
	var bs: Button = ui.mk_btn("ENVIAR", 140, 56, Color("c05621"), 19)
	bs.pressed.connect(func(): export_state(sp_d, "open"))
	top.add_child(bs)
	# barra do tempo (toque para pular)
	sp_bar = Control.new()
	sp_bar.position = Vector2(40, 676)
	sp_bar.size = Vector2(1200, 30)
	sp_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	sp_ui.add_child(sp_bar)
	sp_bar.draw.connect(func():
		var w := sp_bar.size.x
		sp_bar.draw_rect(Rect2(0, 11, w, 8), Color(1, 1, 1, 0.2))
		var kk := 0.0 if _sp_len() <= 0.0 else sp_t / _sp_len()
		sp_bar.draw_rect(Rect2(0, 11, w * kk, 8), Color("f4c542"))
		sp_bar.draw_circle(Vector2(w * kk, 15), 11, Color.WHITE)
		sp_bar.draw_string(ThemeDB.fallback_font, Vector2(w - 120, 6), "%.1fs / %.1fs" % [sp_t, _sp_len()], HORIZONTAL_ALIGNMENT_RIGHT, 120, 15, Color(1, 1, 1, 0.8)))
	sp_bar.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventMouseMotion and ev.button_mask != 0) or ev is InputEventScreenDrag or (ev is InputEventScreenTouch and ev.pressed):
			var kk2 := clampf(ev.position.x / sp_bar.size.x, 0.0, 1.0)
			sp_t = kk2 * _sp_len()
			sp_last_i = -1
			_apply_state(sp_t))


# ---------------------------------------------------------------- salvar na galeria / enviar
# toca o replay quadro a quadro e fotografa cada um (sem os botões na tela), depois junta num WebP animado
func export_state(d: Dictionary, target: String) -> void:
	if exporting or busy:
		return
	if OS.get_name() == "Android" and target == "gallery":
		OS.request_permissions()
	var watching := not sp_d.is_empty()
	var keep_t := sp_t
	var keep_play := sp_play
	if not watching:
		# veio do botão ENVIAR da lista: monta a mesa por baixo
		game.go_menu()
		game.ui.close_modal()
		game.ui.show_screen("")
		game.felt_override = str(d.get("felt", ""))
		game.apply_felt()
		game.st = game.St.REPLAY
		sp_d = d
	exporting = true
	busy = true
	_fit_size()
	if sp_ui != null:
		sp_ui.visible = false
	# o texto de progresso some na hora de cada foto; a marca SINUCOU entra no vídeo
	var prog := CanvasLayer.new()
	prog.layer = 61
	add_child(prog)
	var pl := Label.new()
	pl.add_theme_font_size_override("font_size", 22)
	pl.add_theme_color_override("font_color", Color.WHITE)
	pl.add_theme_constant_override("outline_size", 6)
	pl.add_theme_color_override("font_outline_color", Color.BLACK)
	pl.position = Vector2(20, 690)
	prog.add_child(pl)
	var wm := Label.new()
	wm.text = "SINUCOU"
	wm.add_theme_font_size_override("font_size", 26)
	wm.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 0.85))
	wm.add_theme_constant_override("outline_size", 6)
	wm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	wm.position = Vector2(20, 14)
	prog.add_child(wm)
	var total := int(floor(_sp_len() * OUT_FPS)) + 1
	var outs: Array = []
	outs.resize(total)
	var got := 0
	sp_last_i = -1
	for k in total:
		var t := float(k) / OUT_FPS
		_apply_state(t)
		pl.text = "Preparando o replay... %d%%" % int(100.0 * float(k) / float(total))
		pl.visible = false
		await get_tree().process_frame
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img: Image = sv.get_texture().get_image()
		pl.visible = true
		if img != null and not img.is_empty():
			enc_mx.lock()
			enc_queue.append([k, img])
			enc_mx.unlock()
			enc_sem.post()
		# não deixa a fila crescer demais em celular fraco
		while true:
			enc_mx.lock()
			var ql := enc_queue.size()
			for o in enc_out:
				outs[int(o[0])] = o[1]
				got += 1
			enc_out.clear()
			enc_mx.unlock()
			if ql < 4:
				break
			await get_tree().process_frame
	while got < total:
		await get_tree().process_frame
		enc_mx.lock()
		for o in enc_out:
			outs[int(o[0])] = o[1]
			got += 1
		enc_out.clear()
		var left := enc_queue.size()
		enc_mx.unlock()
		pl.text = "Finalizando... %d%%" % int(100.0 * float(got) / float(total))
		if left == 0 and got < total and enc_out.is_empty():
			await get_tree().create_timer(0.05).timeout
	var good: Array = []
	for o in outs:
		if o is PackedByteArray and (o as PackedByteArray).size() > 0:
			good.append(o)
	var bytes := build_webp(good, W, H, int(round(1000.0 / OUT_FPS)))
	prog.queue_free()
	exporting = false
	busy = false
	if watching:
		if sp_ui != null:
			sp_ui.visible = true
		sp_t = keep_t
		sp_play = keep_play
		_apply_state(sp_t)
	else:
		sp_d = {}
		game.st = game.St.MENU
		game.go_menu()
		game.ui.open_replays()
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	if target == "gallery":
		_write_gallery("Sinucou_%s.webp" % stamp, bytes)
	else:
		var path := local_dir() + "/_envio.webp"
		var fo := FileAccess.open(path, FileAccess.WRITE)
		if fo != null:
			fo.store_buffer(bytes)
			fo.close()
			if OS.shell_open(path) != OK:
				game.ui.say("Não consegui abrir o replay neste celular.")


# ---------------------------------------------------------------- WebP animado
static func _u24(b: PackedByteArray, v: int) -> void:
	b.append(v & 255)
	b.append((v >> 8) & 255)
	b.append((v >> 16) & 255)


static func _u32(b: PackedByteArray, v: int) -> void:
	b.append(v & 255)
	b.append((v >> 8) & 255)
	b.append((v >> 16) & 255)
	b.append((v >> 24) & 255)


static func _chunk(b: PackedByteArray, tag: String, data: PackedByteArray) -> void:
	b.append_array(tag.to_ascii_buffer())
	_u32(b, data.size())
	b.append_array(data)
	if data.size() % 2 == 1:
		b.append(0)


# junta WebPs prontos (um por quadro) num WebP animado: VP8X + ANIM + um ANMF por quadro
static func build_webp(fr: Array, w: int, h: int, dur_ms: int) -> PackedByteArray:
	var body := PackedByteArray()
	body.append_array("WEBP".to_ascii_buffer())
	var vp8x := PackedByteArray([0x02, 0, 0, 0])   # bit de animação
	_u24(vp8x, w - 1)
	_u24(vp8x, h - 1)
	_chunk(body, "VP8X", vp8x)
	_chunk(body, "ANIM", PackedByteArray([0, 0, 0, 255, 0, 0]))  # fundo preto, repetir para sempre
	for k in fr.size():
		var still: PackedByteArray = fr[k]
		if still.size() < 20 or still.slice(0, 4).get_string_from_ascii() != "RIFF":
			continue
		# dentro do WebP parado: "RIFF" tamanho "WEBP" e depois os blocos da imagem (VP8 ...)
		var an := PackedByteArray()
		_u24(an, 0)
		_u24(an, 0)
		_u24(an, w - 1)
		_u24(an, h - 1)
		_u24(an, dur_ms if k < fr.size() - 1 else 1500)
		an.append(0x02)  # não mistura com o quadro anterior
		an.append_array(still.slice(12))
		_chunk(body, "ANMF", an)
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	_u32(out, body.size())
	out.append_array(body)
	return out


# ---------------------------------------------------------------- replays antigos (GIF de 128 cores)
static func cube_palette() -> PackedByteArray:
	var p := PackedByteArray()
	for i in 128:
		p.append(int(round(float((i >> 5) & 3) * 255.0 / 3.0)))
		p.append(int(round(float((i >> 2) & 7) * 255.0 / 7.0)))
		p.append(int(round(float(i & 3) * 255.0 / 3.0)))
	return p


static func _u16(b: PackedByteArray, v: int) -> void:
	b.append(v & 255)
	b.append((v >> 8) & 255)


static func build_gif(fr: Array, rs: Array, ps: Array, w: int, h: int, delay_cs: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array("GIF89a".to_ascii_buffer())
	_u16(out, w)
	_u16(out, h)
	out.append(0xE6)
	out.append(0)
	out.append(0)
	out.append_array(ps[0] if ps.size() > 0 else cube_palette())
	out.append_array(PackedByteArray([0x21, 0xFF, 0x0B]))
	out.append_array("NETSCAPE2.0".to_ascii_buffer())
	out.append_array(PackedByteArray([3, 1, 0, 0, 0]))
	var n := w * h
	for k in fr.size():
		var idx: PackedByteArray = (fr[k] as PackedByteArray).decompress(int(rs[k]), FileAccess.COMPRESSION_FASTLZ)
		if idx.size() != n:
			continue
		var dl := delay_cs if k < fr.size() - 1 else 150
		out.append_array(PackedByteArray([0x21, 0xF9, 0x04, 0x00, dl & 255, (dl >> 8) & 255, 0x00, 0x00]))
		out.append(0x2C)
		_u16(out, 0)
		_u16(out, 0)
		_u16(out, w)
		_u16(out, h)
		out.append(0x86)
		out.append_array(ps[k] if k < ps.size() else cube_palette())
		out.append(7)
		var st := PackedByteArray()
		var i := 0
		while i < n:
			st.append(0x80)
			st.append_array(idx.slice(i, mini(i + 120, n)))
			i += 120
		st.append(0x81)
		var j := 0
		var sl := st.size()
		while j < sl:
			var m := mini(255, sl - j)
			out.append(m)
			out.append_array(st.slice(j, j + m))
			j += m
		out.append(0)
	out.append(0x3B)
	return out
