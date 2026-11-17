extends CanvasLayer
# Chat da partida online (sinuca e truco): frases rápidas, texto e voz (segurar o microfone).
# Os balões aparecem em cima da placa com o nome de quem falou.

const EMOTES := ["riso", "bravo", "oculos", "choro", "uau", "piscada", "fogo", "coracao"]
var emotes: Array = []
const QUICK := ["Tempo...", "Boa jogada!", "Vai logo!", "Kkkkkk", "Que sorte!", "Foi mal!", "Obrigado!", "Calma aí...", "Bora!", "Boa partida!"]
const QUICK_TRUCO := ["TRUCO NELE!", "Tô forte!", "Vai correr?", "Confia, parceiro!"]
const VOICE_RATE := 8000

var game: Node2D
var root: Control
var draw_c: Control
var chat_btn: Button
var mic_btn: Button
var panel: PanelContainer
var quick_box: GridContainer
var edit: LineEdit
var bubbles: Array = []  # {abs, name, txt, t, voice}
var last_send := -10.0
var clock := 0.0
var active := false
var test_t := 0.0
var test_done := false

# voz
var talking := false
var mic_player: AudioStreamPlayer
var capture: AudioEffectCapture
var mic_bus := -1
var voice_buf := PackedByteArray()
var voice_send_t := 0.0
var listeners := {}  # peer -> {player, playback}
var talk_t0 := 0.0
var mic_idle_t := 0.0
var mic_peak := 0.0
var mic_level := 0.0
var mic_gain := 2.0
var mic_frac := 0.0
var mic_testing := false
var test_rec := PackedByteArray()
var hint_txt := ""
var hint_t := 0.0


func setup(g: Node2D) -> void:
	game = g
	layer = 25
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	draw_c = Control.new()
	draw_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_c.draw.connect(_draw_bubbles)
	root.add_child(draw_c)
	chat_btn = _round_btn("CHAT", Color("2f7fd6"))
	chat_btn.pressed.connect(_toggle_panel)
	root.add_child(chat_btn)
	mic_btn = _round_btn("VOZ", Color("16897f"))
	mic_btn.button_down.connect(_talk_start)
	mic_btn.button_up.connect(_talk_stop)
	root.add_child(mic_btn)
	_build_panel()
	_set_active(false)


func _round_btn(t: String, col: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(84, 58)
	b.size = Vector2(84, 58)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	b.add_theme_stylebox_override("normal", game.ui.sbox(col, 29, col.lightened(0.35), 3, 6))
	b.add_theme_stylebox_override("hover", game.ui.sbox(col.lightened(0.1), 29, Color.WHITE, 3, 6))
	b.add_theme_stylebox_override("pressed", game.ui.sbox(col.darkened(0.2), 29, Color.WHITE, 3, 6))
	b.focus_mode = Control.FOCUS_NONE
	return b


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", game.ui.sbox(Color(0.03, 0.05, 0.1, 0.96), 22, Color(1, 1, 1, 0.25), 2, 12))
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(game.ui.margin(vb, 12))
	vb.add_child(game.ui.mk_lbl("EMOJIS", 18, Color("f4c542"), 3))
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 6)
	vb.add_child(er)
	for i in EMOTES.size():
		var eb := Button.new()
		eb.focus_mode = Control.FOCUS_NONE
		eb.custom_minimum_size = Vector2(42, 46)
		eb.add_theme_stylebox_override("normal", game.ui.sbox(Color("24304a"), 12))
		eb.add_theme_stylebox_override("hover", game.ui.sbox(Color("31405f"), 12))
		eb.add_theme_stylebox_override("pressed", game.ui.sbox(Color("18202f"), 12))
		var ec := Control.new()
		ec.set_anchors_preset(Control.PRESET_FULL_RECT)
		ec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var eid: String = EMOTES[i]
		ec.draw.connect(func(): draw_emote(ec, Vector2(21, 23), 16.0, eid, 0.0))
		eb.add_child(ec)
		eb.pressed.connect(func():
			send(":e:" + eid)
			panel.visible = false)
		er.add_child(eb)
	vb.add_child(game.ui.mk_lbl("CHAT RÁPIDO", 20, Color("f4c542"), 3))
	quick_box = GridContainer.new()
	quick_box.columns = 2
	quick_box.add_theme_constant_override("h_separation", 8)
	quick_box.add_theme_constant_override("v_separation", 8)
	vb.add_child(quick_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	edit = LineEdit.new()
	edit.placeholder_text = "escreva..."
	edit.max_length = 40
	edit.custom_minimum_size = Vector2(250, 50)
	edit.add_theme_font_size_override("font_size", 20)
	edit.text_submitted.connect(func(_t): _send_text())
	row.add_child(edit)
	var sb: Button = game.ui.mk_btn("ENVIAR", 110, 50, game.ui.GREEN, 18)
	sb.pressed.connect(_send_text)
	row.add_child(sb)
	panel.visible = false


func _fill_quick() -> void:
	for c in quick_box.get_children():
		c.queue_free()
	var list: Array = QUICK.duplicate()
	if _truco() != null:
		list = QUICK_TRUCO + list.slice(0, 8)
	for q in list:
		var b: Button = game.ui.mk_btn(q, 180, 44, Color("24304a"), 16)
		b.pressed.connect(func():
			send(q)
			panel.visible = false)
		quick_box.add_child(b)


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_fill_quick()


func _truco():
	var t = game.ui.truco_node
	if t != null and is_instance_valid(t) and str(t.netmode) != "":
		return t
	return null


func _in_match() -> bool:
	if _truco() != null:
		return true
	return game.mode == game.Mode.ONLINE and game.st != game.St.MENU and game.st != game.St.OVER and game.net.active


func _set_active(on: bool) -> void:
	active = on
	chat_btn.visible = on
	mic_btn.visible = on and bool(game.save.get("voice_mic", true))
	if not on:
		panel.visible = false
		if talking:
			_talk_stop()


func _process(delta: float) -> void:
	clock += delta
	var on := _in_match()
	if on != active:
		_set_active(on)
	if active:
		# botões no canto esquerdo (a direita já tem mensagens e o botão de TRUCO)
		var y0 := 150.0 if _truco() == null else 230.0
		chat_btn.position = Vector2(16, y0)
		mic_btn.position = Vector2(16, y0 + 70)
		mic_btn.visible = bool(game.save.get("voice_mic", true))
		panel.reset_size()
		panel.position = Vector2(112, y0 - 10)
		# primeira vez que o botão de voz aparece: explica que é segurar
		if mic_btn.visible and not bool(game.save.get("voice_tip", false)):
			game.save["voice_tip"] = true
			game.write_save()
			_hint("Segure o botão VOZ enquanto fala.\nSolte para parar.", 6.0)
	if hint_t > 0.0:
		hint_t -= delta
	for i in range(bubbles.size() - 1, -1, -1):
		bubbles[i].t += delta
		if bubbles[i].t > (1.2 if bubbles[i].voice else 3.5):
			bubbles.remove_at(i)
	for i in range(emotes.size() - 1, -1, -1):
		emotes[i].t += delta
		if emotes[i].t > 2.6:
			emotes.remove_at(i)
	if talking:
		_voice_pump(delta)
	elif mic_testing:
		test_rec.append_array(_read_mic())
		if test_rec.size() > VOICE_RATE * 10:
			mic_test_stop()
	elif mic_player != null and mic_player.playing:
		mic_idle_t += delta
		if mic_idle_t > 8.0:
			mic_player.stop()
	if active and game.net_auto and OS.get_cmdline_user_args().has("--chattest"):
		test_t += delta
		if test_t > 3.0 and not test_done:
			test_done = true
			send("Tempo...")
			if OS.get_cmdline_user_args().has("--chatpanel"):
				_toggle_panel()
			var fake := PackedByteArray()
			for i in 800:
				fake.append(_mulaw(sin(i * 0.3) * 0.5))
			game.net.send_voice(fake)
		if test_t > 5.0 and test_done and emotes.is_empty() and not get_meta("emo_sent", false):
			set_meta("emo_sent", true)
			send(":e:riso")
	draw_c.queue_redraw()


# ---------------------------------------------------------------- texto
func _send_text() -> void:
	var t := edit.text.strip_edges()
	if t == "":
		return
	edit.text = ""
	panel.visible = false
	send(t)


func send(txt: String) -> void:
	if clock - last_send < 1.2:
		return
	last_send = clock
	txt = txt.left(40)
	game.net.send_chat(txt)
	add(multiplayer.get_unique_id(), txt, false)


# peer -> lugar "absoluto" na mesa
func abs_seat(peer: int) -> int:
	var tr = _truco()
	var four: bool = (tr != null and int(tr.n) == 4) or (tr == null and game.net4)
	if four:
		return peer - 1
	return 0 if peer == 1 else 1


func add(peer: int, txt: String, voice: bool) -> void:
	var a := abs_seat(peer)
	if txt.begins_with(":e:"):
		var eid := txt.substr(3)
		if EMOTES.has(eid):
			for e in emotes:
				if int(e.abs) == a:
					emotes.erase(e)
					break
			emotes.append({"abs": a, "id": eid, "t": 0.0})
			if game.net_auto:
				print("EMOTE de=", peer, " id=", eid)
		return
	if game.net_auto:
		print("CHATRX de=", peer, " lugar=", a, " nome=", _name_of(a), " txt=", txt, " voz=", voice)
	for b in bubbles:
		if b.abs == a and b.voice == voice:
			b.txt = txt
			b.t = 0.0 if not voice else b.t * 0.0
			return
	bubbles.append({"abs": a, "txt": txt, "t": 0.0, "voice": voice, "name": _name_of(a)})


func _name_of(a: int) -> String:
	var tr = _truco()
	if tr != null:
		return tr.seat_name(_view_of(a, tr))
	if game.net4 and a < game.seat_names.size():
		return str(game.seat_names[a])
	return str(game.players[a % 2]) if a < 2 else ""


func _view_of(a: int, tr) -> int:
	var me := abs_seat(multiplayer.get_unique_id())
	var nn: int = int(tr.n)
	return (a - me + nn) % nn


# onde fica a placa do jogador na tela
func _anchor(a: int) -> Vector2:
	var tr = _truco()
	if tr != null:
		return tr.plate_anchor(_view_of(a, tr))
	var team := a % 2
	return Vector2(90.0 + team * 430.0 + 205.0, 92.0)


func _draw_bubbles() -> void:
	var f: Font = ThemeDB.fallback_font
	if active and (talking or hint_t > 0.0) and mic_btn.visible:
		var ht: String = "GRAVANDO... solte para parar" if talking else hint_txt
		var lines := ht.split("\n")
		var hw := 0.0
		for ln in lines:
			hw = maxf(hw, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x)
		var hr := Rect2(mic_btn.position + Vector2(98, 29 - 16 - 13 * lines.size()), Vector2(hw + 32, 18 + 26 * lines.size()))
		var ha := 1.0 if talking else clampf(hint_t / 0.4, 0.0, 1.0)
		var hc := Color(0.75, 0.12, 0.12, 0.95 * ha) if talking else Color(0.98, 0.78, 0.2, 0.97 * ha)
		var mid := mic_btn.position + Vector2(84, 29)
		draw_c.draw_colored_polygon(PackedVector2Array([mid + Vector2(2, 0), hr.position + Vector2(1, hr.size.y / 2 - 10), hr.position + Vector2(1, hr.size.y / 2 + 10)]), hc)
		draw_c.draw_style_box(game.ui.sbox(hc, 14, Color(0, 0, 0, 0.3 * ha), 2, 4), hr)
		var tcol := Color(1, 1, 1, ha) if talking else Color(0.12, 0.08, 0, ha)
		for i in lines.size():
			draw_c.draw_string(f, hr.position + Vector2(16, 34 + 26 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, tcol)
		if talking:
			# medidor do microfone: se não mexe, o celular não está captando a voz
			var lv := clampf(sqrt(mic_level * 4.0), 0.0, 1.0)
			var mr := Rect2(hr.position + Vector2(16, hr.size.y + 6), Vector2(hw, 8))
			draw_c.draw_rect(mr, Color(0, 0, 0, 0.55))
			draw_c.draw_rect(Rect2(mr.position, Vector2(hw * lv, 8)), Color("3ddc84"))
	for b in bubbles:
		var p := _anchor(int(b.abs))
		var pop := 1.0 + 0.2 * maxf(0.0, 1.0 - float(b.t) * 6.0)
		if _truco() == null:
			pop = 1.0
		var fade := clampf((3.5 - float(b.t)) / 0.4, 0.0, 1.0) if not b.voice else 1.0
		var txt: String = ("FALANDO..." if b.voice else str(b.txt))
		var fs := int(22 * pop)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw := maxf(tw + 36.0, 120.0)
		var bh := 64.0 * pop
		var vs := get_viewport().get_visible_rect().size
		var up: bool = p.y > vs.y * 0.6  # placa embaixo: balão em cima dela
		var r := Rect2(p + (Vector2(-bw / 2.0, -14 - bh) if up else Vector2(-bw / 2.0, 14)), Vector2(bw, bh))
		var flat: bool = _truco() == null
		if flat:
			# sinuca: o balão fica em cima da própria placa do time (no alto da tela), sem cobrir a mesa e as caçapas
			bw = minf(bw, 400.0)
			bh = 60.0
			r = Rect2(Vector2(p.x - bw / 2.0, 9), Vector2(bw, bh))
		r.position.x = clampf(r.position.x, 8, vs.x - bw - 8)
		var bg := Color(1, 1, 1, 0.97 * fade) if not b.voice else Color(0.08, 0.55, 0.45, 0.95)
		if flat:
			pass
		elif up:
			draw_c.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -16), p + Vector2(10, -16), p + Vector2(0, -2)]), bg)
		else:
			draw_c.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 16), p + Vector2(10, 16), p + Vector2(0, 2)]), bg)
		draw_c.draw_style_box(game.ui.sbox(bg, 18, Color(0, 0, 0, 0.25 * fade), 2, 6), r)
		var tc := Color(0.1, 0.1, 0.12, fade) if not b.voice else Color.WHITE
		draw_c.draw_string(f, r.position + Vector2(0, 22 * pop), str(b.name).left(14), HORIZONTAL_ALIGNMENT_CENTER, bw, int(13 * pop), Color(0.35, 0.35, 0.4, fade) if not b.voice else Color(1, 1, 1, 0.8))
		draw_c.draw_string(f, r.position + Vector2(0, 50 * pop), txt, HORIZONTAL_ALIGNMENT_CENTER, bw, fs, tc)
	for e in emotes:
		var t: float = e.t
		var p2 := _anchor(int(e.abs))
		var vs2 := get_viewport().get_visible_rect().size
		var base: Vector2
		if _truco() == null:
			base = Vector2(p2.x + 160.0, 60.0)
		else:
			base = p2 + (Vector2(0, -90) if p2.y > vs2.y * 0.6 else Vector2(0, 90))
		base.x = clampf(base.x, 60, vs2.x - 60)
		var sc := minf(1.0, t * 6.0) * (1.0 + 0.25 * maxf(0.0, 1.0 - absf(t - 0.25) * 6.0))
		var a := clampf((2.6 - t) / 0.4, 0.0, 1.0)
		var ctr := base + Vector2(0, -t * 18.0 + sin(t * 7.0) * 3.0)
		draw_c.draw_circle(ctr, 44.0 * sc, Color(0, 0, 0, 0.25 * a))
		draw_emote(draw_c, ctr, 38.0 * sc, str(e.id), t, a)


# ---------------------------------------------------------------- voz (segurar para falar)
const MIC_PERM := "android.permission.RECORD_AUDIO"


func _mic_allowed() -> bool:
	if OS.get_name() != "Android":
		return true
	if OS.get_granted_permissions().has(MIC_PERM):
		return true
	# pede a permissão (a janela do Android aparece); quem negou precisa liberar nas configurações
	OS.request_permission(MIC_PERM)
	_hint("Permita o MICROFONE para o Sinucou\ne depois segure o botão de novo.", 5.0)
	return false


func _ensure_mic() -> bool:
	if capture == null:
		mic_bus = AudioServer.get_bus_index("VozMic")
		if mic_bus < 0:
			AudioServer.add_bus()
			mic_bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(mic_bus, "VozMic")
			AudioServer.set_bus_send(mic_bus, "Master")
			AudioServer.set_bus_mute(mic_bus, true)
			var cap := AudioEffectCapture.new()
			cap.buffer_length = 0.5
			AudioServer.add_bus_effect(mic_bus, cap)
		capture = AudioServer.get_bus_effect(mic_bus, 0)
	if mic_player == null:
		mic_player = AudioStreamPlayer.new()
		mic_player.stream = AudioStreamMicrophone.new()
		mic_player.bus = "VozMic"
		add_child(mic_player)
	# o microfone fica ligado uns segundos depois de soltar (ligar e desligar toda hora falha em alguns celulares)
	if not mic_player.playing:
		mic_player.play()
	mic_idle_t = 0.0
	return true


func _talk_start() -> void:
	if not bool(game.save.get("voice_mic", true)) or mic_testing:
		return
	if not _mic_allowed():
		return
	_ensure_mic()
	capture.clear_buffer()
	talking = true
	talk_t0 = clock
	hint_t = 0.0
	mic_peak = 0.0
	voice_buf.clear()
	add(multiplayer.get_unique_id(), "", true)


func _talk_stop() -> void:
	if not talking:
		return
	talking = false
	_flush_voice()
	var held := clock - talk_t0
	# só tocou rápido: avisa que precisa segurar
	if held < 0.4:
		for i in range(bubbles.size() - 1, -1, -1):
			if bubbles[i].voice and int(bubbles[i].abs) == abs_seat(multiplayer.get_unique_id()):
				bubbles.remove_at(i)
		_hint("Para falar, SEGURE o botão VOZ\nenquanto fala e solte no fim.", 4.0)
	elif held > 1.5 and mic_peak < 0.003:
		_hint("O microfone não captou som.\nConfira a permissão de MICROFONE do Sinucou.", 5.0)


func _hint(t: String, dur: float) -> void:
	hint_txt = t
	hint_t = dur


# lê o que o microfone gravou e devolve em 8 kHz (com ganho automático para a voz não sair baixinha)
func _read_mic() -> PackedByteArray:
	var out := PackedByteArray()
	if capture == null:
		return out
	var avail := capture.get_frames_available()
	if avail <= 0:
		return out
	var frames: PackedVector2Array = capture.get_buffer(avail)
	var step: float = AudioServer.get_mix_rate() / float(VOICE_RATE)
	var peak := 0.0
	for v in frames:
		peak = maxf(peak, absf((v.x + v.y) * 0.5))
	mic_peak = maxf(mic_peak, peak)
	mic_level = maxf(peak, mic_level * 0.85)
	var want := clampf(0.6 / maxf(peak, 0.01), 1.0, 6.0)
	mic_gain = lerpf(mic_gain, want, 0.3) if want < mic_gain else lerpf(mic_gain, want, 0.05)
	# média de cada bloco (filtra o chiado) em vez de pegar uma amostra solta
	var pos := mic_frac
	while pos + step <= float(frames.size()):
		var a := int(pos)
		var b := int(pos + step)
		var acc := 0.0
		for i in range(a, b):
			acc += (frames[i].x + frames[i].y) * 0.5
		out.append(_mulaw(acc / float(maxi(1, b - a)) * mic_gain))
		pos += step
	mic_frac = pos - float(frames.size())
	if mic_frac < 0.0:
		mic_frac = 0.0
	return out


func _voice_pump(delta: float) -> void:
	voice_buf.append_array(_read_mic())
	voice_send_t += delta
	if voice_send_t >= 0.12:
		voice_send_t = 0.0
		_flush_voice()
	# meu balão de "falando" fica aceso enquanto seguro o botão
	for b in bubbles:
		if b.voice and b.abs == abs_seat(multiplayer.get_unique_id()):
			b.t = 0.0


# ---- teste do microfone nos Ajustes: segura para gravar, solta para ouvir
func mic_test_start() -> bool:
	if talking or not _mic_allowed():
		return false
	_ensure_mic()
	capture.clear_buffer()
	mic_testing = true
	mic_peak = 0.0
	test_rec = PackedByteArray()
	return true


func mic_test_stop() -> float:
	if not mic_testing:
		return -1.0
	mic_testing = false
	test_rec.append_array(_read_mic())
	_play_local(test_rec)
	return mic_peak


func _play_local(data: PackedByteArray) -> void:
	if data.is_empty():
		return
	var pl := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = VOICE_RATE
	gen.buffer_length = float(data.size()) / VOICE_RATE + 0.3
	pl.stream = gen
	pl.volume_db = 4.0
	add_child(pl)
	pl.play()
	var pb: AudioStreamGeneratorPlayback = pl.get_stream_playback()
	var out := PackedVector2Array()
	out.resize(mini(data.size(), pb.get_frames_available()))
	for i in out.size():
		var sm := _unmulaw(data[i])
		out[i] = Vector2(sm, sm)
	pb.push_buffer(out)
	get_tree().create_timer(gen.buffer_length + 0.5).timeout.connect(pl.queue_free)


func _flush_voice() -> void:
	if voice_buf.is_empty():
		return
	game.net.send_voice(voice_buf)
	voice_buf = PackedByteArray()


func got_voice(peer: int, data: PackedByteArray) -> void:
	if not bool(game.save.get("voice_hear", true)):
		return
	add(peer, "", true)
	if not listeners.has(peer):
		var pl := AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = VOICE_RATE
		gen.buffer_length = 0.6
		pl.stream = gen
		pl.volume_db = 4.0
		add_child(pl)
		pl.play()
		listeners[peer] = {"player": pl, "pb": pl.get_stream_playback()}
	var pb: AudioStreamGeneratorPlayback = listeners[peer].pb
	var n := mini(data.size(), pb.get_frames_available())
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var s := _unmulaw(data[i])
		out[i] = Vector2(s, s)
	pb.push_buffer(out)


# compressão µ-law: 1 byte por amostra (voz a 8 kHz = 8 KB/s só enquanto fala)
static func _mulaw(x: float) -> int:
	x = clampf(x, -1.0, 1.0)
	var mu := 255.0
	var y := signf(x) * log(1.0 + mu * absf(x)) / log(1.0 + mu)
	return clampi(int(round((y + 1.0) * 127.5)), 0, 255)


static func _unmulaw(b: int) -> float:
	var y := float(b) / 127.5 - 1.0
	var mu := 255.0
	return signf(y) * (pow(1.0 + mu, absf(y)) - 1.0) / mu



# emojis desenhados (a fonte do jogo não tem emoji)
static func draw_emote(c: CanvasItem, p: Vector2, r: float, id: String, t: float, a: float = 1.0) -> void:
	if r < 1.0:
		return
	var yel := Color(1.0, 0.82, 0.2, a)
	var dark := Color(0.25, 0.14, 0.04, a)
	if id == "fogo":
		var fl := sin(t * 10.0) * 0.08
		for k in 3:
			var s := 1.0 - k * 0.3
			var col: Color = [Color(1, 0.25, 0.1, a), Color(1, 0.6, 0.1, a), Color(1, 0.92, 0.45, a)][k]
			var pts := PackedVector2Array([p + Vector2(fl * r * 2.0, -r * 1.05 * s)])
			for j in 15:
				var an := PI * 0.0 + float(j) / 14.0 * PI
				pts.append(p + Vector2(cos(an) * r * 0.75 * s, r * 0.25 + sin(an) * r * 0.65 * s))
			c.draw_colored_polygon(pts, col)
		return
	if id == "coracao":
		var b := 1.0 + 0.1 * sin(t * 12.0)
		var pts2 := PackedVector2Array()
		for k in 40:
			var tt := float(k) / 40.0 * TAU
			var x := 16.0 * pow(sin(tt), 3)
			var y := -(13.0 * cos(tt) - 5.0 * cos(2 * tt) - 2.0 * cos(3 * tt) - cos(4 * tt))
			pts2.append(p + Vector2(x, y) * r / 17.0 * b)
		c.draw_colored_polygon(pts2, Color(0.9, 0.12, 0.25, a))
		c.draw_circle(p + Vector2(-r * 0.4, -r * 0.35), r * 0.15, Color(1, 1, 1, 0.5 * a))
		return
	var face := yel
	if id == "bravo":
		face = Color(0.95, 0.3, 0.2, a)
	c.draw_circle(p, r, face)
	c.draw_arc(p, r, 0, TAU, 32, Color(0.6, 0.35, 0.0, a), maxf(1.5, r * 0.06))
	var ex := r * 0.36
	var ey := -r * 0.18
	match id:
		"riso":
			c.draw_arc(p + Vector2(-ex, ey), r * 0.16, PI, TAU, 10, dark, r * 0.08)
			c.draw_arc(p + Vector2(ex, ey), r * 0.16, PI, TAU, 10, dark, r * 0.08)
			var m := PackedVector2Array([p + Vector2(-r * 0.55, r * 0.1)])
			for j in 11:
				var an := float(j) / 10.0 * PI
				m.append(p + Vector2(-cos(an) * r * 0.55, r * 0.1 + sin(an) * r * 0.5))
			c.draw_colored_polygon(m, dark)
			c.draw_circle(p + Vector2(0, r * 0.45), r * 0.18, Color(0.95, 0.4, 0.45, a))
			var drop := 0.5 + 0.5 * sin(t * 6.0)
			c.draw_circle(p + Vector2(-r * 0.75, ey + r * 0.2 + drop * r * 0.2), r * 0.12, Color(0.4, 0.75, 1.0, a))
			c.draw_circle(p + Vector2(r * 0.75, ey + r * 0.2 + drop * r * 0.2), r * 0.12, Color(0.4, 0.75, 1.0, a))
		"bravo":
			c.draw_line(p + Vector2(-ex - r * 0.2, ey - r * 0.25), p + Vector2(-ex + r * 0.15, ey - r * 0.08), dark, r * 0.1)
			c.draw_line(p + Vector2(ex + r * 0.2, ey - r * 0.25), p + Vector2(ex - r * 0.15, ey - r * 0.08), dark, r * 0.1)
			c.draw_circle(p + Vector2(-ex, ey + r * 0.05), r * 0.1, dark)
			c.draw_circle(p + Vector2(ex, ey + r * 0.05), r * 0.1, dark)
			c.draw_arc(p + Vector2(0, r * 0.55), r * 0.32, PI * 1.15, PI * 1.85, 12, dark, r * 0.09)
		"oculos":
			c.draw_rect(Rect2(p + Vector2(-r * 0.75, ey - r * 0.15), Vector2(r * 0.62, r * 0.32)), Color(0.08, 0.08, 0.1, a))
			c.draw_rect(Rect2(p + Vector2(r * 0.13, ey - r * 0.15), Vector2(r * 0.62, r * 0.32)), Color(0.08, 0.08, 0.1, a))
			c.draw_line(p + Vector2(-r * 0.15, ey - r * 0.05), p + Vector2(r * 0.15, ey - r * 0.05), Color(0.08, 0.08, 0.1, a), r * 0.08)
			c.draw_line(p + Vector2(-r * 0.6, ey - r * 0.08), p + Vector2(-r * 0.4, ey + r * 0.05), Color(1, 1, 1, 0.5 * a), r * 0.05)
			c.draw_arc(p + Vector2(0, r * 0.1), r * 0.45, PI * 0.2, PI * 0.8, 12, dark, r * 0.08)
		"choro":
			c.draw_arc(p + Vector2(-ex, ey), r * 0.14, 0, PI, 10, dark, r * 0.08)
			c.draw_arc(p + Vector2(ex, ey), r * 0.14, 0, PI, 10, dark, r * 0.08)
			c.draw_arc(p + Vector2(0, r * 0.6), r * 0.3, PI * 1.15, PI * 1.85, 12, dark, r * 0.08)
			var fall := fmod(t * 1.6, 1.0)
			for sx in [-1.0, 1.0]:
				c.draw_rect(Rect2(p + Vector2(sx * ex - r * 0.08, ey + r * 0.12), Vector2(r * 0.16, r * 0.7 * fall + r * 0.1)), Color(0.4, 0.75, 1.0, 0.9 * a))
		"uau":
			c.draw_circle(p + Vector2(-ex, ey), r * 0.13, dark)
			c.draw_circle(p + Vector2(ex, ey), r * 0.13, dark)
			c.draw_arc(p + Vector2(-ex, ey - r * 0.28), r * 0.14, PI * 1.2, PI * 1.8, 8, dark, r * 0.06)
			c.draw_arc(p + Vector2(ex, ey - r * 0.28), r * 0.14, PI * 1.2, PI * 1.8, 8, dark, r * 0.06)
			c.draw_circle(p + Vector2(0, r * 0.4), r * 0.2 * (1.0 + 0.1 * sin(t * 8.0)), dark)
		"piscada":
			c.draw_circle(p + Vector2(-ex, ey), r * 0.12, dark)
			c.draw_line(p + Vector2(ex - r * 0.18, ey), p + Vector2(ex + r * 0.18, ey), dark, r * 0.08)
			c.draw_arc(p + Vector2(0, r * 0.1), r * 0.45, PI * 0.15, PI * 0.85, 12, dark, r * 0.08)
			c.draw_circle(p + Vector2(r * 0.25, r * 0.55), r * 0.13, Color(0.95, 0.4, 0.45, a))
