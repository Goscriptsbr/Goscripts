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
	if busy and thread != null and not thread.is_alive():
		thread.wait_to_finish()
		thread = null
		busy = false
		if result_err == "":
			game.ui.say("Replay salvo na galeria! (%s)" % result_path.get_file())
		else:
			game.ui.say(result_err)
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
	game.ui.say("Salvando os últimos %ds..." % int(ceil(float(fr.size()) / FPS)))
	thread = Thread.new()
	thread.start(_worker.bind(fr, rs))


func _worker(fr: Array, rs: Array) -> void:
	var bytes := build_gif(fr, rs, W, H, int(round(100.0 / FPS)))
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var name := "sinucou_%s.gif" % stamp
	var dirs: Array = []
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "":
		dirs.append(pics + "/Sinucou")
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl != "":
		dirs.append(dl)
	dirs.append(OS.get_user_data_dir() + "/replays")
	for d in dirs:
		DirAccess.make_dir_recursive_absolute(d)
		var f := FileAccess.open(d + "/" + name, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bytes)
			f.close()
			result_path = d + "/" + name
			if d.ends_with("/replays"):
				result_err = "Sem permissão para a galeria: replay guardado dentro do jogo."
			return
	result_err = "Não consegui salvar o replay (sem espaço ou sem permissão)."


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
