extends Node
# REPLAY: grava sempre os últimos 30 segundos da partida e, quando o jogador toca em SALVAR,
# guarda o replay no jogo (AJUSTES > MEUS REPLAYS) e tenta pôr uma cópia na galeria do celular.
#
# Qualidade: cada quadro é a tela reduzida para 960 px de largura (na proporção do celular), com as
# cores de verdade, comprimido em WebP pelo próprio Godot (rápido, numa linha separada). O arquivo
# final é um WebP ANIMADO: é só juntar os quadros prontos num envelope (sem recomprimir nada).

const W := 960
const FPS := 12.0
const SECS := 30.0
const MAX_FRAMES := int(FPS * SECS)
const MAX_SAVED := 10
const QUALITY := 0.72

var game: Node
var H := 432                 # altura segue o formato da tela do celular (sem achatar a mesa)
var frames: Array = []       # cada item: PackedByteArray (um WebP pronto)
var sv: SubViewport
var tr: TextureRect
var acc := 0.0
var pending := false
var recording := false
var busy := false
var result_path := ""
var result_err := ""
var save_w := W
var save_h := 432

# compressão dos quadros numa linha separada (para não travar o jogo)
var enc_thread: Thread
var enc_sem := Semaphore.new()
var enc_mx := Mutex.new()
var enc_queue: Array = []    # [gen, Image]
var enc_out: Array = []      # [gen, PackedByteArray]
var enc_quit := false
var gen := 0                 # muda quando a gravação recomeça (descarta quadros velhos)


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


# mesma proporção da tela (celulares 20:9 ficavam com a mesa espremida)
func _fit_size() -> void:
	var rs2: Vector2 = get_tree().root.get_visible_rect().size
	if rs2.x < 10.0:
		return
	H = clampi(int(round(float(W) * rs2.y / rs2.x / 2.0)) * 2, 300, 720)
	sv.size = Vector2i(W, H)
	tr.size = Vector2(W, H)


func _process(delta: float) -> void:
	if game == null:
		return
	_play_tick(delta)
	# quadros que a outra linha já comprimiu
	enc_mx.lock()
	var outs := enc_out
	enc_out = []
	enc_mx.unlock()
	for o in outs:
		if int(o[0]) == gen:
			frames.append(o[1])
	while frames.size() > MAX_FRAMES:
		frames.pop_front()
	var want: bool = game.rec_active()
	if not want:
		if recording:
			recording = false
		return
	if not recording:
		recording = true
		gen += 1
		_fit_size()
		frames.clear()
		acc = 0.0
	if pending:
		pending = false
		var img: Image = sv.get_texture().get_image()
		if img != null and not img.is_empty():
			enc_mx.lock()
			var lag := enc_queue.size()
			if lag < 6:
				enc_queue.append([gen, img])
			enc_mx.unlock()
			if lag < 6:
				enc_sem.post()
	acc += delta
	if acc >= 1.0 / FPS:
		acc = fmod(acc, 1.0 / FPS)
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		pending = true


func can_save() -> bool:
	return frames.size() >= 8 and not busy


func save_clip() -> void:
	if busy:
		game.ui.say("Ainda salvando o replay anterior...")
		return
	if frames.size() < 8:
		game.ui.say("Ainda não tem jogada gravada para salvar.")
		return
	if list_local().size() >= MAX_SAVED:
		game.ui.confirm("REPLAYS CHEIOS", "Você já tem %d replays guardados (o máximo).\nApague algum em AJUSTES > MEUS REPLAYS para salvar outro." % MAX_SAVED, "OK", func(): pass, "", Callable())
		return
	if OS.get_name() == "Android":
		OS.request_permissions()
	busy = true
	result_err = ""
	save_w = W
	save_h = H
	var fr := frames.duplicate()
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var fname := "Sinucou_%s" % stamp
	# guarda no jogo (os quadros prontos) e monta o WebP animado: só junta bytes, é rápido
	_store_local(fname, fr, save_w, save_h)
	var bytes := build_webp(fr, save_w, save_h, int(round(1000.0 / FPS)))
	busy = false
	_write_gallery(fname + ".webp", bytes)


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
			_done(true, "Replay salvo em:\n%s\n\nTambém fica em AJUSTES > MEUS REPLAYS." % tr2[1])
			return
		errs.append("x")
	_done(false, "O celular não deixou o jogo gravar na galeria (erro %s).\n\nO replay ficou guardado em AJUSTES > MEUS REPLAYS:\nlá você toca em ABRIR e salva ou manda no WhatsApp." % ",".join(errs))


func _done(ok: bool, msg: String) -> void:
	result_err = "" if ok else msg
	print("REPLAY salvo=", ok, " ", result_path)
	game.ui.confirm("REPLAY SALVO!" if ok else "REPLAY", msg, "OK", func(): pass, "", Callable())


# ---------------------------------------------------------------- replays guardados no jogo
static func local_dir() -> String:
	return OS.get_user_data_dir() + "/replays"


func _store_local(nm: String, fr: Array, w: int, h: int) -> void:
	var ud := local_dir()
	DirAccess.make_dir_recursive_absolute(ud)
	var f := FileAccess.open(ud + "/" + nm + ".rpl", FileAccess.WRITE)
	if f != null:
		f.store_var({"fmt": "webp", "w": w, "h": h, "fps": FPS, "frames": fr})
		f.close()


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
	var path := ""
	var bytes := PackedByteArray()
	if str(d.get("fmt", "")) == "webp":
		path = local_dir() + "/_envio.webp"
		bytes = build_webp(d.frames, int(d.w), int(d.h), int(round(1000.0 / float(d.get("fps", FPS)))))
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


func play_local(nm: String, target: TextureRect) -> bool:
	var d := _load_rpl(nm)
	if d.is_empty() or not d.has("frames") or (d.frames as Array).is_empty():
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


func _play_tick(delta: float) -> void:
	if play_tex == null or play_d.is_empty():
		return
	if not is_instance_valid(play_tex) or not play_tex.is_visible_in_tree():
		stop_play()
		return
	var fps := float(play_d.get("fps", FPS))
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
