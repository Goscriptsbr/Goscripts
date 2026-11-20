extends Node
# REPLAY: grava sempre os últimos 30 segundos da partida (imagens pequenas, 8 por segundo) e, quando o
# jogador toca em SALVAR, monta um GIF animado e guarda na galeria do celular (Imagens/Sinucou).
#
# Como fica leve:
#  - a tela é reduzida e convertida para 128 cores por um shader na placa de vídeo; as 128 cores são
#    escolhidas a partir da própria tela (a cada 5s), então o pano, a borda e as bolas ficam com as cores
#    certas; o celular só lê 1 byte por pixel;
#  - o GIF é gravado "sem compressão LZW" (cada pixel = 1 byte e um código de limpeza a cada 120),
#    então montar o arquivo é só juntar pedaços de memória, sem conta pixel a pixel.

const W := 480
const FPS := 12.0
const MAX_SAVED := 10
const SECS := 30.0
const MAX_FRAMES := int(FPS * SECS)

var game: Node
var H := 216   # altura segue o formato da tela do celular (sem achatar a mesa)
var frames: Array = []        # cada item: PackedByteArray comprimido (índices de cor)
var raw_sizes: Array = []
var frame_pals: Array = []    # paleta (128 cores, 384 bytes) de cada quadro
var cur_pal := PackedByteArray()
var pal_req := PackedByteArray()
var sv2: SubViewport          # amostra pequena em cores de verdade, para escolher a paleta
var sample_pending := false
var pal_t := 99.0
var last_pals: Array = []
var last_w := W
var last_h := 216
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
	sv2 = SubViewport.new()
	sv2.size = Vector2i(96, 54)
	sv2.disable_3d = true
	sv2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(sv2)
	var tr2 := TextureRect.new()
	tr2.size = Vector2(96, 54)
	tr2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr2.stretch_mode = TextureRect.STRETCH_SCALE
	tr2.texture = get_tree().root.get_texture()
	sv2.add_child(tr2)
	_set_pal(cube_palette())


# mesma proporção da tela (celulares 20:9 ficavam com a mesa espremida)
func _fit_size() -> void:
	var rs2: Vector2 = get_tree().root.get_visible_rect().size
	if rs2.x < 10.0:
		return
	H = clampi(int(round(float(W) * rs2.y / rs2.x / 2.0)) * 2, 150, 360)
	sv.size = Vector2i(W, H)
	tr.size = Vector2(W, H)


func _set_pal(p: PackedByteArray) -> void:
	cur_pal = p
	var arr := PackedVector3Array()
	for i in 128:
		arr.append(Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]) / 255.0)
	(tr.material as ShaderMaterial).set_shader_parameter("pal", arr)


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
		if open_after != "":
			var path := open_after
			open_after = ""
			var fo := FileAccess.open(path, FileAccess.WRITE)
			if fo != null:
				fo.store_buffer(bytes)
				fo.close()
				if OS.shell_open(path) != OK:
					game.ui.say("Não consegui abrir o replay neste celular.")
		else:
			_write_file(bytes)
	var want: bool = game.rec_active()
	if not want:
		if recording:
			recording = false
		return
	if not recording:
		recording = true
		_fit_size()
		frames.clear()
		raw_sizes.clear()
		frame_pals.clear()
		acc = 0.0
		pal_t = 99.0
	if pending:
		pending = false
		var img: Image = sv.get_texture().get_image()
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_R8)
			var d := img.get_data()
			raw_sizes.append(d.size())
			frames.append(d.compress(FileAccess.COMPRESSION_FASTLZ))
			frame_pals.append(pal_req)
			while frames.size() > MAX_FRAMES:
				frames.pop_front()
				raw_sizes.pop_front()
				frame_pals.pop_front()
	# paleta: a cada 5s olha a tela em cores de verdade e escolhe as 128 cores que mais aparecem
	if sample_pending:
		sample_pending = false
		var si: Image = sv2.get_texture().get_image()
		if si != null and not si.is_empty():
			_set_pal(make_palette(si))
	pal_t += delta
	if pal_t >= 5.0:
		pal_t = 0.0
		sv2.render_target_update_mode = SubViewport.UPDATE_ONCE
		sample_pending = true
		return
	acc += delta
	if acc >= 1.0 / FPS:
		acc = fmod(acc, 1.0 / FPS)
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		pal_req = cur_pal
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
	var fr := frames.duplicate()
	var rs := raw_sizes.duplicate()
	var ps := frame_pals.duplicate()
	last_frames = fr
	last_rs = rs
	last_pals = ps
	last_w = W
	last_h = H
	game.ui.say("Salvando os últimos %ds..." % int(ceil(float(fr.size()) / FPS)))
	thread = Thread.new()
	thread.start(_worker.bind(fr, rs, ps, W, H))


func _worker(fr: Array, rs: Array, ps: Array, w: int, h: int) -> PackedByteArray:
	# só monta o GIF aqui (em segundo plano); gravar no armazenamento do Android fica na linha principal
	return build_gif(fr, rs, ps, w, h, int(round(100.0 / FPS)))


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
	# guarda só os quadros (o GIF é montado de novo quando for abrir/enviar): ocupa bem menos espaço
	var ud := local_dir()
	DirAccess.make_dir_recursive_absolute(ud)
	var f2 := FileAccess.open(ud + "/" + fname.get_basename() + ".rpl", FileAccess.WRITE)
	if f2 != null:
		f2.store_var({"w": last_w, "h": last_h, "fps": FPS, "frames": last_frames, "rs": last_rs, "pals": last_pals})
		f2.close()


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


# ABRIR / ENVIAR: monta o GIF do replay guardado e abre no app de fotos do celular
func open_local(nm: String) -> void:
	var gif := local_dir() + "/" + nm + ".gif"
	if FileAccess.file_exists(gif):
		OS.shell_open(gif)
		return
	if busy:
		game.ui.say("Espere terminar o replay que está salvando...")
		return
	var f := FileAccess.open(local_dir() + "/" + nm + ".rpl", FileAccess.READ)
	if f == null:
		game.ui.say("Replay não encontrado.")
		return
	var d = f.get_var()
	f.close()
	if not (d is Dictionary):
		return
	busy = true
	open_after = local_dir() + "/_envio.gif"
	game.ui.say("Preparando o replay...")
	thread = Thread.new()
	thread.start(_worker.bind(d.frames, d.rs, d.get("pals", []), int(d.w), int(d.h)))


var open_after := ""


# assistir dentro do jogo: carrega os quadros e vai trocando a imagem (cores pelo shader)
var play_tex: TextureRect = null
var play_fr: Array = []
var play_rs: Array = []
var play_i := 0
var play_t := 0.0
var play_w := W
var play_h := H
var play_ps: Array = []


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
	play_ps = d.get("pals", [])
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
	var pal: PackedByteArray = play_ps[play_i] if play_i < play_ps.size() else cube_palette()
	var arr := PackedVector3Array()
	for i in 128:
		arr.append(Vector3(pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2]) / 255.0)
	if play_tex.material is ShaderMaterial:
		(play_tex.material as ShaderMaterial).set_shader_parameter("pal", arr)
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
# cores que sempre entram na paleta (bolas, branco, preto, dourado da interface)
const FIXED := ["000000", "ffffff", "f4f4ee", "141414", "f4c51e", "1f5fd1", "d8262c", "6a2aa8", "f07a12", "12904a", "8a1f1f", "f4c542", "ffe066", "808080", "404040", "c0c0c0"]


# 112 cores escolhidas da tela (corte pela mediana num histograma de 15 bits) + 16 fixas
static func make_palette(img: Image) -> PackedByteArray:
	img.convert(Image.FORMAT_RGB8)
	var d := img.get_data()
	var hist := {}
	for i in range(0, d.size() - 2, 3):
		var key: int = ((d[i] >> 3) << 10) | ((d[i + 1] >> 3) << 5) | (d[i + 2] >> 3)
		hist[key] = int(hist.get(key, 0)) + 1
	var items: Array = []
	for k in hist.keys():
		var kk: int = k
		items.append([float(((kk >> 10) & 31) * 8 + 4), float(((kk >> 5) & 31) * 8 + 4), float((kk & 31) * 8 + 4), sqrt(float(hist[kk]))])
	var boxes: Array = [items]
	while boxes.size() < 112:
		var best := -1
		var bscore := -1.0
		var bch := 0
		for bi in boxes.size():
			var box: Array = boxes[bi]
			if box.size() < 2:
				continue
			var mn := [255.0, 255.0, 255.0]
			var mx := [0.0, 0.0, 0.0]
			var wsum := 0.0
			for it in box:
				for c in 3:
					mn[c] = minf(mn[c], it[c])
					mx[c] = maxf(mx[c], it[c])
				wsum += float(it[3])
			for c in 3:
				var sc: float = (float(mx[c]) - float(mn[c])) * sqrt(wsum)
				if sc > bscore:
					bscore = sc
					best = bi
					bch = c
		if best < 0 or bscore <= 0.0:
			break
		var bx: Array = boxes[best]
		var ch := bch
		bx.sort_custom(func(a, b): return float(a[ch]) < float(b[ch]))
		var tot := 0.0
		for it in bx:
			tot += float(it[3])
		var acc2 := 0.0
		var cut := 1
		for i in bx.size():
			acc2 += float(bx[i][3])
			if acc2 >= tot * 0.5:
				cut = clampi(i + 1, 1, bx.size() - 1)
				break
		boxes[best] = bx.slice(0, cut)
		boxes.append(bx.slice(cut))
	var p := PackedByteArray()
	for box in boxes:
		var r := 0.0
		var g := 0.0
		var b := 0.0
		var w := 0.0
		for it in box:
			r += float(it[0]) * float(it[3])
			g += float(it[1]) * float(it[3])
			b += float(it[2]) * float(it[3])
			w += float(it[3])
		w = maxf(w, 0.0001)
		p.append(clampi(int(round(r / w)), 0, 255))
		p.append(clampi(int(round(g / w)), 0, 255))
		p.append(clampi(int(round(b / w)), 0, 255))
	for hx in FIXED:
		var cc := Color(hx)
		p.append(cc.r8)
		p.append(cc.g8)
		p.append(cc.b8)
	while p.size() < 384:
		p.append(0)
	return p.slice(0, 384)


# paleta antiga (cubo 4x8x4), usada antes da primeira amostra e em replays velhos
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
	out.append(0xE6)  # tabela de cores global com 128 cores
	out.append(0)
	out.append(0)
	out.append_array(ps[0] if ps.size() > 0 else cube_palette())
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
		# cada quadro leva a sua tabela de 128 cores (a paleta muda a cada 5s)
		out.append(0x86)
		out.append_array(ps[k] if k < ps.size() else cube_palette())
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
