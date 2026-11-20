extends Node
# REPLAY: grava sempre os últimos 30 segundos da partida (imagens pequenas, 8 por segundo) e, quando o
# jogador toca em SALVAR, monta um GIF animado e guarda na galeria do celular (Imagens/Sinucou).
#
# Como fica leve:
#  - a tela é reduzida e convertida para 128 cores (com pontilhado) por um shader na placa de vídeo;
#    o celular só lê 1 byte por pixel de uma imagem pequena;
#  - o GIF é gravado "sem compressão LZW" (cada pixel = 1 byte e um código de limpeza a cada 120),
#    então montar o arquivo é só juntar pedaços de memória, sem conta pixel a pixel.

const W := 360
const H := 202
const FPS := 8.0
const SECS := 30.0
const MAX_FRAMES := int(FPS * SECS)

var game: Node
var frames: Array = []        # cada item: PackedByteArray comprimido (índices de cor)
var raw_sizes: Array = []
var sv: SubViewport
var tr: TextureRect
var acc := 0.0
var pending := false
var recording := false
var busy := false
var thread: Thread
var result_path := ""
var result_err := ""
var last_frames: Array = []
var last_rs: Array = []


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
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/gif_quant.gdshader")
	tr.material = m
	sv.add_child(tr)


func _process(delta: float) -> void:
	if game == null:
		return
	if play_tex != null and not play_fr.is_empty():
		if not is_instance_valid(play_tex) or not play_tex.is_visible_in_tree():
			stop_play()
		else:
			play_t += delta
			if play_t >= 1.0 / FPS:
				play_t = fmod(play_t, 1.0 / FPS)
				play_i = (play_i + 1) % play_fr.size()
				_show_frame()
	if busy and thread != null and not thread.is_alive():
		var bytes: PackedByteArray = thread.wait_to_finish()
		thread = null
		busy = false
		_write_file(bytes)
	var want: bool = game.rec_active()
	if not want:
		if recording:
			recording = false
		return
	if not recording:
		recording = true
		frames.clear()
		raw_sizes.clear()
		acc = 0.0
	if pending:
		pending = false
		var img: Image = sv.get_texture().get_image()
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_R8)
			var d := img.get_data()
			raw_sizes.append(d.size())
			frames.append(d.compress(FileAccess.COMPRESSION_FASTLZ))
			while frames.size() > MAX_FRAMES:
				frames.pop_front()
				raw_sizes.pop_front()
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
	if OS.get_name() == "Android":
		OS.request_permissions()
	busy = true
	result_err = ""
	var fr := frames.duplicate()
	var rs := raw_sizes.duplicate()
	last_frames = fr
	last_rs = rs
	game.ui.say("Salvando os últimos %ds..." % int(ceil(float(fr.size()) / FPS)))
	thread = Thread.new()
	thread.start(_worker.bind(fr, rs))


func _worker(fr: Array, rs: Array) -> PackedByteArray:
	# só monta o GIF aqui (em segundo plano); gravar no armazenamento do Android fica na linha principal
	return build_gif(fr, rs, W, H, int(round(100.0 / FPS)))


# grava o GIF onde a galeria mostra. Ordem: DCIM/Camera (aparece junto das fotos), DCIM, Imagens, Downloads.
func _write_file(bytes: PackedByteArray) -> void:
	if bytes.size() < 100:
		_done(false, "Não consegui montar o replay.")
		return
	if OS.get_name() == "Android":
		OS.request_permission("android.permission.WRITE_EXTERNAL_STORAGE")
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var fname := "Sinucou_%s.gif" % stamp
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
	_store_local(fname, bytes)
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
	result_path = local_dir() + "/" + fname
	_done(false, "O celular não deixou o jogo gravar na galeria (erro %s).\n\nO replay ficou guardado em AJUSTES > MEUS REPLAYS:\nlá você toca em ABRIR e salva ou manda no WhatsApp." % ",".join(errs))


# cópia dentro do jogo (sempre): o GIF e os quadros crus (para assistir aqui mesmo). Guarda os 10 últimos.
static func local_dir() -> String:
	return OS.get_user_data_dir() + "/replays"


func _store_local(fname: String, bytes: PackedByteArray) -> void:
	var ud := local_dir()
	DirAccess.make_dir_recursive_absolute(ud)
	var f := FileAccess.open(ud + "/" + fname, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
	var f2 := FileAccess.open(ud + "/" + fname.get_basename() + ".rpl", FileAccess.WRITE)
	if f2 != null:
		f2.store_var({"w": W, "h": H, "fps": FPS, "frames": last_frames, "rs": last_rs})
		f2.close()
	var lst := list_local()
	while lst.size() > 10:
		delete_local(str(lst.pop_back()))


# nomes (sem extensão), do mais novo para o mais velho
static func list_local() -> Array:
	var out: Array = []
	var da := DirAccess.open(local_dir())
	if da == null:
		return out
	for fn in da.get_files():
		if fn.ends_with(".gif"):
			out.append(fn.get_basename())
	out.sort_custom(func(a, b): return str(a).to_lower() > str(b).to_lower())
	return out


static func delete_local(nm: String) -> void:
	DirAccess.remove_absolute(local_dir() + "/" + nm + ".gif")
	DirAccess.remove_absolute(local_dir() + "/" + nm + ".rpl")


# assistir dentro do jogo: carrega os quadros e vai trocando a imagem (cores pelo shader)
var play_tex: TextureRect = null
var play_fr: Array = []
var play_rs: Array = []
var play_i := 0
var play_t := 0.0
var play_w := W
var play_h := H


func play_local(nm: String, target: TextureRect) -> bool:
	var f := FileAccess.open(local_dir() + "/" + nm + ".rpl", FileAccess.READ)
	if f == null:
		return false
	var d = f.get_var()
	f.close()
	if not (d is Dictionary) or not d.has("frames"):
		return false
	play_fr = d.frames
	play_rs = d.rs
	play_w = int(d.w)
	play_h = int(d.h)
	play_i = 0
	play_t = 0.0
	play_tex = target
	_show_frame()
	return true


func stop_play() -> void:
	play_tex = null
	play_fr = []


func _show_frame() -> void:
	if play_tex == null or play_fr.is_empty() or not is_instance_valid(play_tex):
		return
	var raw: PackedByteArray = (play_fr[play_i] as PackedByteArray).decompress(int(play_rs[play_i]), FileAccess.COMPRESSION_FASTLZ)
	if raw.size() != play_w * play_h:
		return
	var img := Image.create_from_data(play_w, play_h, false, Image.FORMAT_R8, raw)
	var tex := play_tex.texture as ImageTexture
	if tex == null or tex.get_width() != play_w:
		play_tex.texture = ImageTexture.create_from_image(img)
	else:
		tex.update(img)


func _done(ok: bool, msg: String) -> void:
	result_err = "" if ok else msg
	print("REPLAY salvo=", ok, " ", result_path)
	game.ui.confirm("REPLAY SALVO!" if ok else "REPLAY", msg, "OK", func(): pass, "", Callable())


# ---------------------------------------------------------------- GIF
static func palette() -> PackedByteArray:
	var p := PackedByteArray()
	for i in 128:
		p.append(int(round(float((i >> 5) & 3) * 255.0 / 3.0)))
		p.append(int(round(float((i >> 2) & 7) * 255.0 / 7.0)))
		p.append(int(round(float(i & 3) * 255.0 / 3.0)))
	return p


static func _u16(b: PackedByteArray, v: int) -> void:
	b.append(v & 255)
	b.append((v >> 8) & 255)


static func build_gif(fr: Array, rs: Array, w: int, h: int, delay_cs: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array("GIF89a".to_ascii_buffer())
	_u16(out, w)
	_u16(out, h)
	out.append(0xE6)  # tabela de cores global com 128 cores
	out.append(0)
	out.append(0)
	out.append_array(palette())
	# repetir para sempre
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
		out.append(0)
		out.append(7)  # tamanho mínimo do código LZW: 7 bits -> códigos de 8 bits (1 byte)
		# fluxo "sem compressão": limpa o dicionário a cada 120 pixels para o código continuar com 8 bits
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
