extends Node
# Segurança dos jogadores: filtro de palavrões, bloquear, denunciar, excluir conta
# (exigências do Google Play para jogos com chat entre usuários).

const OWNER_CODE := "LP34RB"
const REASONS := ["Ofensas ou xingamentos", "Nome ofensivo", "Trapaça", "Golpe na negociação", "Spam ou propaganda", "Outro motivo"]
const BAD := ["porra","caralho","carai","krl","crl","buceta","boceta","bct","xoxota","xereca","piroca","pica","cacete","foder","foda","fode","fodase","fudido","fdp","filhodaputa","puta","putinha","puto","viado","viadinho","veado","bicha","baitola","traveco","arrombado","arrombada","arombado","cu","cuzao","bosta","merda","otario","otaria","babaca","corno","corna","vagabunda","vagabundo","vadia","safada","safado","punheta","punheteiro","siririca","boquete","chupa","xupa","piru","pinto","rapariga","quenga","escroto","escrota","desgracado","retardado","mongol","macaco","negrinho","nazista","hitler","estupro","estuprador","pedofilo","suicida","vtnc","vsf","pqp","tnc","fds"]

var game: Node
var ui
var bad := {}
var chat_log := {}   # code -> últimas falas (vai junto na denúncia)
var _rx := RegEx.new()


func setup(g: Node) -> void:
	game = g
	ui = g.ui
	_rx.compile("[\\p{L}\\p{N}@$]+")
	for w in BAD:
		bad[_collapse(w)] = true
	if not game.save.has("blocked"):
		game.save["blocked"] = []


# ---------------------------------------------------------------- filtro
func _collapse(s: String) -> String:
	var o := ""
	for ch in s:
		if o == "" or o[o.length() - 1] != ch:
			o += ch
	return o


func _fold(w: String) -> String:
	var s := w.to_lower()
	var from := "áàâãäéèêëíìîïóòôõöúùûüç"
	var to := "aaaaaeeeeiiiiooooouuuuc"
	var o := ""
	for ch in s:
		var i := from.find(ch)
		if i >= 0:
			o += to[i]
		elif ch == "4" or ch == "@":
			o += "a"
		elif ch == "3":
			o += "e"
		elif ch == "1" or ch == "!":
			o += "i"
		elif ch == "0":
			o += "o"
		elif ch == "5" or ch == "$":
			o += "s"
		elif ch == "7":
			o += "t"
		elif ch >= "a" and ch <= "z":
			o += ch
	return _collapse(o)


func _is_bad(w: String) -> bool:
	var f := _fold(w)
	if f.length() < 2:
		return false
	if bad.has(f):
		return true
	if f.ends_with("s") and bad.has(f.left(f.length() - 1)):
		return true
	for suf in ["inho", "inha", "ao", "oes"]:
		if f.ends_with(suf) and bad.has(f.left(f.length() - suf.length())):
			return true
	return false


func clean(t: String) -> String:
	var out := ""
	var last := 0
	for m in _rx.search_all(t):
		var w := m.get_string()
		out += t.substr(last, m.get_start() - last)
		out += "*".repeat(mini(6, w.length())) if _is_bad(w) else w
		last = m.get_end()
	out += t.substr(last)
	return out


# ---------------------------------------------------------------- bloqueio
func blocked_codes() -> Array:
	var out: Array = []
	for b in game.save.get("blocked", []):
		out.append(str(b.get("code", "")) if b is Dictionary else str(b))
	return out


func is_blocked(code: String) -> bool:
	return code != "" and blocked_codes().has(code.to_upper())


func code_of_peer(peer: int) -> String:
	if game.net == null:
		return ""
	for p in game.net.room_players:
		if int(p.get("peer", 0)) == peer:
			return str(p.get("code", "")).to_upper()
	return ""


func set_blocked(code: String, nm: String, on: bool) -> void:
	code = code.to_upper()
	var list: Array = game.save.get("blocked", [])
	var keep: Array = []
	for b in list:
		var c := str(b.get("code", "")) if b is Dictionary else str(b)
		if c != code:
			keep.append(b)
	if on:
		keep.append({"code": code, "name": nm})
		# quem é bloqueado deixa de ser amigo
		var fr: Array = game.save.get("friends", [])
		for f in fr.duplicate():
			if str(f.get("code", "")).to_upper() == code:
				fr.erase(f)
	game.save["blocked"] = keep
	game.write_save()
	if game.net != null:
		game.net.world_send({"t": "block", "code": code, "on": on})


func toggle_block(code: String, nm: String) -> void:
	if is_blocked(code):
		set_blocked(code, nm, false)
		ui.say("%s foi desbloqueado." % nm)
		return
	ui.confirm("BLOQUEAR %s?" % nm.to_upper(), "Você não vai mais ver as mensagens dele, nem ouvir a voz dele nas partidas.\nEle também não vai conseguir te convidar, te mandar mensagem nem negociar com você.", "BLOQUEAR", func():
		set_blocked(code, nm, true)
		ui.say("%s foi bloqueado." % nm), "CANCELAR", Callable())


func log_chat(code: String, txt: String) -> void:
	if code == "":
		return
	var l: Array = chat_log.get(code, [])
	l.append(txt.left(140))
	while l.size() > 10:
		l.pop_front()
	chat_log[code] = l


func open_blocked() -> void:
	var vb: VBoxContainer = ui._modal_box("JOGADORES BLOQUEADOS")
	var list: Array = game.save.get("blocked", [])
	if list.is_empty():
		vb.add_child(ui.mk_lbl("Você não bloqueou ninguém.", 20, Color(1, 1, 1, 0.7), 2))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, mini(360, 70 * list.size()))
	vb.add_child(sc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	sc.add_child(lv)
	for b in list:
		var code := str(b.get("code", "")) if b is Dictionary else str(b)
		var nm := str(b.get("name", code)) if b is Dictionary else code
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l: Label = ui.mk_lbl("%s  (%s)" % [nm, code], 20, Color.WHITE, 2)
		l.custom_minimum_size = Vector2(360, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(l)
		var ub: Button = ui.mk_btn("DESBLOQUEAR", 180, 50, Color("1b8f4c"), 18)
		ub.pressed.connect(func():
			set_blocked(code, nm, false)
			open_blocked())
		row.add_child(ub)
		lv.add_child(row)
	var ok: Button = ui.mk_btn("FECHAR", 220, 56, ui.GRAY, 22)
	ok.pressed.connect(ui.close_modal)
	vb.add_child(ok)


# ---------------------------------------------------------------- denúncia
func open_report(code: String, nm: String) -> void:
	var vb: VBoxContainer = ui._modal_box("DENUNCIAR %s" % nm.to_upper())
	vb.add_child(ui.mk_lbl("Por que você está denunciando?", 20, Color(1, 1, 1, 0.85), 2))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)
	var pick := {"r": ""}
	var btns: Array = []
	for r in REASONS:
		var b: Button = ui.mk_btn(r, 300, 54, Color("23364f"), 18)
		var rr := str(r)
		b.pressed.connect(func():
			pick.r = rr
			for x in btns:
				var on: bool = (x as Button).text == rr
				var col := Color("c94444") if on else Color("23364f")
				(x as Button).add_theme_stylebox_override("normal", ui.sbox(col, 20, col.lightened(0.3), 3, 6))
				(x as Button).add_theme_stylebox_override("hover", ui.sbox(col.lightened(0.1), 20, col.lightened(0.3), 3, 6)))
		btns.append(b)
		grid.add_child(b)
	var note: LineEdit = ui._edit("Conte o que aconteceu (opcional)", false, 200)
	note.custom_minimum_size = Vector2(620, 54)
	vb.add_child(note)
	var blk := CheckBox.new()
	blk.text = "  Bloquear também"
	blk.button_pressed = true
	blk.add_theme_font_size_override("font_size", 20)
	vb.add_child(blk)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var cb: Button = ui.mk_btn("CANCELAR", 200, 58, ui.GRAY, 20)
	cb.pressed.connect(ui.close_modal)
	row.add_child(cb)
	var sb: Button = ui.mk_btn("ENVIAR DENÚNCIA", 280, 58, Color("c94444"), 20)
	sb.pressed.connect(func():
		if str(pick.r) == "":
			ui.say("Escolha um motivo.")
			return
		if game.net == null or not game.net.server_ok:
			ui.say("Sem conexão com o servidor.")
			return
		game.net.world_send({"t": "report", "code": code, "name": nm, "reason": pick.r, "note": note.text.strip_edges(), "ctx": chat_log.get(code, [])})
		if blk.button_pressed and not is_blocked(code):
			set_blocked(code, nm, true)
		ui.close_modal()
		ui.confirm("DENÚNCIA ENVIADA", "Obrigado! A equipe do Sinucou vai analisar.\nQuem descumpre as regras pode perder itens ou ter a conta suspensa.", "OK", func(): pass, "", Callable()))
	row.add_child(sb)


# ---------------------------------------------------------------- excluir conta
func delete_flow() -> void:
	ui.confirm("EXCLUIR MINHA CONTA", "Isso apaga para sempre a sua conta do Sinucou:\nmoedas, itens, nível, ranking, amigos e o backup na nuvem (e a ligação com o Google).\n\nNão dá para desfazer.", "CONTINUAR", func():
		ui.confirm("TEM CERTEZA?", "Última confirmação: tudo será apagado agora e o jogo vai recomeçar do zero.", "EXCLUIR TUDO", _delete_now, "VOLTAR", Callable()), "CANCELAR", Callable())


func _delete_now() -> void:
	if game.net == null or not game.net.server_ok:
		ui.confirm("SEM CONEXÃO", "Conecte na internet para excluir a conta.\nTambém dá para pedir pelo site: goscripts.com.br/sinucou/excluir-conta", "OK", func(): pass, "", Callable())
		return
	game.net.world_send({"t": "delete_acc", "tok": game.my_tok()})
	ui.say("Excluindo a conta...")


func _wipe_local() -> void:
	game.bot = true  # não grava mais nada por cima
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	var d := DirAccess.open("user://replays")
	if d != null:
		for f in d.get_files():
			d.remove(f)
	ui.confirm("CONTA EXCLUÍDA", "Sua conta e seus dados foram apagados.\nO jogo vai recomeçar como um jogador novo.", "OK", func():
		get_tree().quit(), "", Callable())


# ---------------------------------------------------------------- denúncias (só o dono)
func is_owner() -> bool:
	return game.my_code() == OWNER_CODE


func open_reports(clear := false) -> void:
	game.net.world_send({"t": "reports_get", "tok": game.my_tok(), "clear": clear})
	ui.say("Carregando denúncias...")


func _show_reports(m: Dictionary) -> void:
	var vb: VBoxContainer = ui._modal_box("DENÚNCIAS")
	var list: Array = m.get("list", [])
	if str(m.get("err", "")) != "":
		vb.add_child(ui.mk_lbl(str(m.err), 18, Color("ff8a6a"), 2))
	if list.is_empty():
		vb.add_child(ui.mk_lbl("Nenhuma denúncia.", 20, Color(1, 1, 1, 0.7), 2))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	for r in list:
		var t := Time.get_datetime_string_from_unix_time(int(r.get("at", 0)) / 1000 - 3 * 3600).replace("T", " ").left(16)
		var txt := "%s  •  %s (%s) denunciou %s (%s)\nMotivo: %s" % [t, r.get("fromName", ""), r.get("from", ""), r.get("name", ""), r.get("code", ""), r.get("reason", "")]
		if str(r.get("note", "")) != "":
			txt += "\nObs: " + str(r.note)
		var ctx: Array = r.get("ctx", [])
		if not ctx.is_empty():
			txt += "\nÚltimas falas: " + " | ".join(ctx)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", ui.sbox(Color(1, 1, 1, 0.05), 12))
		var l: Label = ui.mk_lbl(txt, 16, Color.WHITE, 1)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(860, 0)
		p.add_child(ui.margin(l, 10))
		lv.add_child(p)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	if not list.is_empty():
		var cl: Button = ui.mk_btn("LIMPAR TODAS", 220, 54, Color("c94444"), 18)
		cl.pressed.connect(func(): open_reports(true))
		row.add_child(cl)
	var ok: Button = ui.mk_btn("FECHAR", 220, 54, ui.GRAY, 20)
	ok.pressed.connect(ui.close_modal)
	row.add_child(ok)


func on_msg(m: Dictionary) -> void:
	match str(m.t):
		"reports":
			_show_reports(m)
		"delete_r":
			if bool(m.get("ok", false)):
				_wipe_local()
			else:
				ui.say(str(m.get("msg", "Não deu certo.")))
		"report_ok":
			if bool(m.get("dup", false)):
				ui.say("Espere um pouco para mandar outra denúncia.")


# ---------------------------------------------------------------- sair da conta (trocar de conta)
var _logout_wait := false


func logout_flow() -> void:
	var n = game.net
	if n == null or not n.server_ok:
		ui.confirm("SEM CONEXÃO", "Conecte na internet para sair da conta.\nAssim o jogo guarda tudo na nuvem antes.", "OK", func(): pass, "", Callable())
		return
	if n.g_mail == "" and not n.cloud_pass:
		ui.confirm("CONECTE O GOOGLE ANTES", "Esta conta ainda não está ligada ao Google e não tem senha.\nSe sair agora, você NÃO vai conseguir voltar pra ela (moedas e itens).\n\nConecte com o Google primeiro, aqui mesmo nesta tela.", "ENTENDI", func(): pass, "", Callable())
		return
	var como: String = ("o Google " + n.g_mail) if n.g_mail != "" else ("o código %s e a sua senha" % game.my_code())
	ui.confirm("SAIR DA CONTA", "Suas moedas e itens ficam guardados na nuvem.\nPara voltar depois, é só entrar com " + como + ".\n\nO jogo vai fechar. Ao abrir de novo, escolha ENTRAR COM GOOGLE (outra conta) ou SOU NOVO.", "SAIR", _logout_now, "CANCELAR", Callable())


func _logout_now() -> void:
	var q: Array = game.save.get("eco_q", [])
	if not q.is_empty():
		ui.say("Sincronizando moedas... tente de novo em alguns segundos.")
		return
	_logout_wait = true
	game.net.send_csave()
	ui.say("Guardando tudo na nuvem...")
	get_tree().create_timer(12.0).timeout.connect(func():
		if _logout_wait:
			_logout_wait = false
			ui.confirm("NÃO DEU", "Não consegui confirmar o backup agora.\nVerifique a internet e tente de novo.", "OK", func(): pass, "", Callable()))


func on_csave_ok(ok: bool) -> void:
	if not _logout_wait:
		return
	_logout_wait = false
	if not ok:
		ui.confirm("NÃO DEU", "O backup não foi aceito (a conta pode estar em outro celular).\nNada foi apagado.", "OK", func(): pass, "", Callable())
		return
	game.bot = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	var d := DirAccess.open("user://replays")
	if d != null:
		for f in d.get_files():
			d.remove(f)
	ui.confirm("VOCÊ SAIU DA CONTA", "Tudo ficou guardado na nuvem.\nAbra o jogo de novo para entrar com outra conta Google ou começar do zero.", "OK", func():
		get_tree().quit(), "", Callable())
