extends Node2D
# Sinuca (bola 8): lisas (1-7) x listradas (9-15) + preta (8).
# Quem derruba a primeira bola define o grupo. A preta só no final.

const UIScript := preload("res://ui.gd")
const FxScript := preload("res://fx.gd")

const R := 13.0
const HW := 500.0
const HH := 250.0
var splash_node: Node = null
const APP_VERSION := 55  # sobe a cada APK novo (igual ao versao.json do servidor)
const DT := 1.0 / 240.0
const MAXV := 1750.0
const BLACK := 8
const PR_CORNER := 23.0
const HOLE_C := 25.0
const HOLE_S := 21.0
const PR_SIDE := 19.0
const PAD := 1.45

enum St { MENU, AIM, STRIKE, ROLL, OVER }
enum Mode { AI, TWO, TRAIN, ONLINE }

const BALL_COL := {
	1: Color("f2c200"), 2: Color("1a4fb4"), 3: Color("d12a1e"), 4: Color("5a2a82"),
	5: Color("f26a1b"), 6: Color("12823f"), 7: Color("7a1d1d"), 8: Color("0b0b0b"),
}

const FELTS := [
	{"id": "verde", "name": "Verde Clássico", "price": 0, "light": Color("22a553"), "dark": Color("06512b"), "pat": 0, "tag": "Liso"},
	{"id": "azul", "name": "Azul Royal", "price": 250, "light": Color("3a7bd5"), "dark": Color("0d2f6b"), "pat": 0, "tag": "Liso"},
	{"id": "vinho", "name": "Vinho", "price": 250, "light": Color("b8405a"), "dark": Color("5a1226"), "pat": 0, "tag": "Liso"},
	{"id": "grafite", "name": "Grafite", "price": 400, "light": Color("6f7a88"), "dark": Color("23282f"), "pat": 0, "tag": "Liso"},
	{"id": "camuflagem", "name": "Camuflada", "price": 450, "light": Color("5b6b3a"), "dark": Color("2e3a1e"), "pat": 4, "accent": Color("8a7a4a"), "accent2": Color("1f2a14"), "tag": "Estampa militar"},
	{"id": "brasil", "name": "Brasil", "price": 500, "light": Color("22a553"), "dark": Color("06512b"), "pat": 3, "accent": Color("f2c200"), "accent2": Color("1a4fb4"), "tag": "Losango e esfera"},
	{"id": "neon", "name": "Neon Cyber", "price": 600, "light": Color("1c2f5e"), "dark": Color("050918"), "pat": 1, "accent": Color("18e6ff"), "accent2": Color("ffffff"), "tag": "Grade luminosa"},
	{"id": "gelo", "name": "Gelo Polar", "price": 700, "light": Color("86d3f2"), "dark": Color("2a6fa0"), "pat": 6, "accent": Color("effcff"), "accent2": Color("ffffff"), "tag": "Cristais de gelo"},
	{"id": "galaxia", "name": "Galáxia", "price": 750, "light": Color("34196a"), "dark": Color("090519"), "pat": 2, "accent": Color("b06bff"), "accent2": Color("3de0ff"), "tag": "Nebulosa e estrelas"},
	{"id": "fogo", "name": "Inferno", "price": 800, "light": Color("5a1208"), "dark": Color("1a0605"), "pat": 5, "accent": Color("ffa31a"), "accent2": Color("c4200c"), "tag": "Chamas nas bordas"},
	{"id": "campeao", "name": "Campeão", "price": 0, "pass": 10, "light": Color("16323a"), "dark": Color("04090c"), "pat": 7, "accent": Color("37e0ff"), "accent2": Color("ffd34a"), "tag": "Exclusiva do Passe"},
	{"id": "esmeralda", "name": "Esmeralda", "price": 0, "pass": 40, "light": Color("0f5a3c"), "dark": Color("03170f"), "pat": 7, "accent": Color("d4af37"), "accent2": Color("ffffff"), "tag": "Exclusiva do Passe"},
	{"id": "ametista", "name": "Cristal Ametista", "price": 0, "pass": 70, "light": Color("8a63e0"), "dark": Color("2a1260"), "pat": 6, "accent": Color("f3e8ff"), "accent2": Color("ffd6ff"), "tag": "Exclusiva do Passe"},
	{"id": "pordosol", "name": "Pôr do Sol", "price": 850, "light": Color("3a1a3c"), "dark": Color("140818"), "pat": 8, "accent": Color("ff8a3d"), "accent2": Color("7b2f7a"), "tag": "Céu laranja e sol na água"},
	{"id": "oceano_m", "name": "Oceano Profundo", "price": 900, "light": Color("0d5f86"), "dark": Color("031a2e"), "pat": 9, "accent": Color("9ff6ff"), "accent2": Color("0a3f66"), "tag": "Luz dançando na água"},
	{"id": "carbono_m", "name": "Fibra de Carbono", "price": 650, "light": Color("3a3f47"), "dark": Color("101216"), "pat": 10, "accent": Color("e63946"), "accent2": Color("ffffff"), "tag": "Trama de carbono e borda vermelha"},
	{"id": "arcoiris", "name": "Arco-Íris Neon", "price": 1500, "light": Color("1c1236"), "dark": Color("06040f"), "pat": 1, "accent": Color("ff4fd8"), "accent2": Color("ffffff"), "edge": "rainbow", "tag": "Luzes animadas nas bordas"},
	{"id": "royal", "name": "Ouro Real", "price": 1200, "light": Color("2a1540"), "dark": Color("0b0614"), "pat": 7, "accent": Color("e3b341"), "accent2": Color("ffffff"), "tag": "Treliça dourada"},
]
# aim = tamanho da projeção da mira | pow = força máxima | prec = precisão | spin = controle de efeito
const CUES := [
	{"id": "classico", "name": "Clássico", "price": 0, "shaft": Color("ecd29c"), "butt": Color("5a2e14"), "accent": Color("eadbb0"), "ring": Color("c9a24a"), "wrap": Color("1b1410"), "pat": 0, "aim": 1, "pow": 1, "prec": 1, "spin": 1},
	{"id": "ebano", "name": "Ébano", "price": 200, "shaft": Color("d9c7a3"), "butt": Color("17171b"), "accent": Color("d0d0d8"), "ring": Color("b8b8c4"), "wrap": Color("0d0d0f"), "pat": 0, "aim": 2, "pow": 1, "prec": 2, "spin": 1},
	{"id": "rubi", "name": "Rubi", "price": 300, "shaft": Color("ecd29c"), "butt": Color("a31c26"), "accent": Color("f2d27a"), "ring": Color("d4b24a"), "wrap": Color("140a0a"), "pat": 0, "aim": 2, "pow": 2, "prec": 2, "spin": 2},
	{"id": "oceano", "name": "Oceano", "price": 350, "shaft": Color("e9d6a8"), "butt": Color("1d4f9e"), "accent": Color("f2f6ff"), "ring": Color("c0c8d6"), "wrap": Color("0c1626"), "pat": 0, "aim": 3, "pow": 2, "prec": 3, "spin": 2},
	{"id": "ouro", "name": "Dourado", "price": 500, "shaft": Color("f4e3b5"), "butt": Color("d9a521"), "accent": Color("2a1c08"), "ring": Color("8a5a10"), "wrap": Color("1a1206"), "pat": 0, "aim": 3, "pow": 3, "prec": 3, "spin": 3},
	{"id": "tigre", "name": "Tigre", "price": 650, "shaft": Color("f0dcae"), "butt": Color("f2701b"), "butt2": Color("111111"), "accent": Color("141414"), "ring": Color("d9d9d9"), "wrap": Color("120d08"), "pat": 1, "aim": 3, "pow": 4, "prec": 3, "spin": 3, "fx": "eyes"},
	{"id": "carbono", "name": "Carbono Pro", "price": 800, "shaft": Color("e8e8ea"), "butt": Color("141519"), "butt2": Color("565a63"), "accent": Color("ffffff"), "ring": Color("9aa0ab"), "wrap": Color("0b0b0d"), "pat": 3, "aim": 4, "pow": 3, "prec": 5, "spin": 3, "fx": "arc"},
	{"id": "dragao", "name": "Dragão", "price": 1000, "shaft": Color("f0d9a8"), "butt": Color("4a0808"), "butt2": Color("ff3d1f"), "accent": Color("ffd26a"), "ring": Color("d6a93c"), "wrap": Color("1a0808"), "pat": 2, "aim": 4, "pow": 5, "prec": 4, "spin": 4, "fx": "dragon"},
	{"id": "cristal", "name": "Cristal", "price": 1300, "shaft": Color("f6f6f2"), "butt": Color("2a8fd6"), "butt2": Color("eafaff"), "accent": Color("9fe3ff"), "ring": Color("dff6ff"), "wrap": Color("0c1c2a"), "pat": 2, "aim": 5, "pow": 4, "prec": 5, "spin": 4, "fx": "ice"},
	{"id": "lenda", "name": "Raio Dourado", "price": 0, "pass": 30, "shaft": Color("fbf1d0"), "butt": Color("1a1206"), "butt2": Color("ffcf3a"), "accent": Color("fff2a6"), "ring": Color("ffd34a"), "wrap": Color("120c04"), "pat": 5, "shine": 1, "aim": 4, "pow": 3, "prec": 3, "spin": 3, "fx": "storm"},
	{"id": "cometa", "name": "Cometa", "price": 0, "pass": 50, "theme": 9, "glow": Color("5fb4ff"), "shaft": Color("eef4ff"), "butt": Color("0a1c3a"), "butt2": Color("3de0ff"), "accent": Color("ffffff"), "ring": Color("bfe9ff"), "wrap": Color("06101e"), "pat": 2, "shine": 1, "aim": 5, "pow": 4, "prec": 5, "spin": 5, "fx": "comet", "rare": "LENDÁRIO"},
	{"id": "imperador", "name": "Imperador", "price": 0, "pass": 100, "theme": 10, "glow": Color("ffc93c"), "shaft": Color("fbf3dc"), "butt": Color("2a0a3a"), "butt2": Color("e3b341"), "accent": Color("fff2a6"), "ring": Color("ffd34a"), "wrap": Color("140620"), "pat": 5, "shine": 1, "aim": 5, "pow": 5, "prec": 5, "spin": 5, "fx": "crown", "rare": "MÍTICO"},
	{"id": "pedro", "name": "Taco do Pedro", "price": 900, "theme": 8, "glow": Color("3df0ff"), "shaft": Color("f3efe2"), "butt": Color("0d2a24"), "accent": Color("ffffff"), "ring": Color("ffd34a"), "wrap": Color("0d2a24"), "pat": 0, "aim": 3, "pow": 3, "prec": 3, "spin": 3, "fx": "math", "impact": "math"},
	{"id": "galaxia_taco", "name": "Galáxia", "price": 2000, "shaft": Color("f2eef8"), "butt": Color("1a0b3a"), "butt2": Color("8f3dff"), "accent": Color("ffffff"), "ring": Color("c9a8ff"), "wrap": Color("0a0618"), "pat": 4, "aim": 4, "pow": 4, "prec": 4, "spin": 4, "fx": "galaxy"},
]

# Tacos raros: um por mês (rodízio automático), com 30% de desconto durante o mês.
const MONTHLY := [
	{"id": "m_fenix", "theme": 0, "glow": Color("ff7a1a"), "name": "Fênix", "price": 4200, "shaft": Color("f6e3b0"), "butt": Color("7a0c05"), "butt2": Color("ffb21a"), "accent": Color("ffe08a"), "ring": Color("ffcf5a"), "wrap": Color("1a0805"), "pat": 2, "shine": 1, "fx": "phoenix", "aim": 5, "pow": 5, "prec": 4, "spin": 5, "rare": "LENDÁRIO"},
	{"id": "m_trovao", "theme": 1, "glow": Color("6f8cff"), "name": "Trovão", "price": 4500, "shaft": Color("e9ecff"), "butt": Color("1b1a52"), "butt2": Color("6c7bff"), "accent": Color("fff2a6"), "ring": Color("d9c25a"), "wrap": Color("0b0a22"), "pat": 5, "shine": 1, "fx": "storm", "aim": 5, "pow": 5, "prec": 5, "spin": 4, "rare": "LENDÁRIO"},
	{"id": "m_samurai", "theme": 2, "glow": Color("ff5a8a"), "name": "Primavera", "price": 3800, "shaft": Color("f1e2c0"), "butt": Color("8a0a16"), "butt2": Color("0c0c0c"), "accent": Color("0c0c0c"), "ring": Color("cfa63a"), "wrap": Color("100606"), "pat": 1, "shine": 1, "fx": "blade", "aim": 4, "pow": 4, "prec": 5, "spin": 4, "rare": "ÉPICO"},
	{"id": "m_lobo", "theme": 3, "glow": Color("9fc0ff"), "name": "Lobo da Lua", "price": 4000, "shaft": Color("eaf0ff"), "butt": Color("0e1a3d"), "butt2": Color("9fb4e6"), "accent": Color("ffffff"), "ring": Color("c0cde8"), "wrap": Color("080c1c"), "pat": 4, "shine": 1, "fx": "moon", "aim": 5, "pow": 4, "prec": 4, "spin": 5, "rare": "ÉPICO"},
	{"id": "m_tsunami", "theme": 4, "glow": Color("3ad8ff"), "name": "Tsunami", "price": 3600, "shaft": Color("e8fbff"), "butt": Color("0a4a8a"), "butt2": Color("33d6e0"), "accent": Color("ffffff"), "ring": Color("bdeaf2"), "wrap": Color("06202e"), "pat": 5, "shine": 1, "fx": "wave", "aim": 4, "pow": 5, "prec": 4, "spin": 4, "rare": "ÉPICO"},
	{"id": "m_esmeralda", "theme": 5, "glow": Color("3dff9a"), "name": "Esmeralda Real", "price": 5000, "shaft": Color("f3f0d8"), "butt": Color("0b5a35"), "butt2": Color("d4af37"), "accent": Color("f6e27a"), "ring": Color("d4af37"), "wrap": Color("06180e"), "pat": 6, "shine": 1, "fx": "gems", "aim": 5, "pow": 5, "prec": 5, "spin": 4, "rare": "LENDÁRIO"},
	{"id": "m_vulcao", "theme": 6, "glow": Color("ff5a10"), "name": "Vulcão", "price": 4800, "shaft": Color("eadfce"), "butt": Color("160805"), "butt2": Color("ff6a00"), "accent": Color("ffd24a"), "ring": Color("8a3a10"), "wrap": Color("0d0503"), "pat": 7, "shine": 0, "fx": "lava", "aim": 4, "pow": 5, "prec": 4, "spin": 5, "rare": "LENDÁRIO"},
	{"id": "m_aurora", "theme": 7, "glow": Color("7affd0"), "name": "Aurora Boreal", "price": 6000, "shaft": Color("f4f7ff"), "butt": Color("12203f"), "butt2": Color("2ee6a6"), "accent": Color("ffffff"), "ring": Color("d8c8ff"), "wrap": Color("080b1a"), "pat": 8, "shine": 1, "fx": "aurora", "aim": 5, "pow": 5, "prec": 5, "spin": 5, "rare": "MÍTICO"},
]
const MONTH_NAMES := ["JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO", "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO"]

var POCK: Array = [
	Vector2(-505, -255), Vector2(505, -255), Vector2(-505, 255), Vector2(505, 255),
	Vector2(0, -268), Vector2(0, 268),
]
var dial_rot := 0.0
var ccd_on := true
var music_p: AudioStreamPlayer
var music_ok := false
var music_db := -60.0
var cue_fx_n: Node2D
var cue_fx_a: Node2D
var fx_t := 0.0
var spin := Vector2.ZERO
var duel := false
var turn_left := 20.0
var banner_turn := -1
var banner_ms := -10000
const TURN_TIME := 20
var tick_last := -1
var eval_budget := 1
var hard_cands: Array = []
var hard_i := 0
var hard_best := {}
var hard_sb: Array = []
var cue_layer: Node2D
var cue_s: Sprite2D
var cue_sh: Sprite2D
var cue_applied := ""
var strike_t := 0.0
var strike_dur := 0.1
var strike_pull := 0.0
var strike_pw := 0.0
var wrong_first := false
var AIMP: Array = [
	Vector2(-488, -238), Vector2(488, -238), Vector2(-488, 238), Vector2(488, 238),
	Vector2(0, -252), Vector2(0, 252),
]

var st := St.MENU
var mode := Mode.AI
var diff := 1
var paused := false
var balls: Array = []
var turn := 0
var groups := [-1, -1]  # 0 = lisas, 1 = listradas
var ai := [false, false]
var ball_in_hand := false
var break_shot := true
var aim_angle := 0.0
var power := 0.0
var msg := ""
var msg_t := 0.0
var winner := -1
var sim_t := 0.0
var first_hit := -1
var pocketed: Array = []
var cue_pocketed := false
var rem_before := 0
var shot_by := 0
var cue_ids: Array = ["", ""]
var felt_override := ""
var net_peer_cue := "classico"
var net_peer_name := "Adversário"
var net_game := "sinuca"
var net_team := false            # online 2x2
var net4 := false                # partida online de sinuca com 4 jogadores
var seat_names: Array = []
var bot_seats: Array = []
var tm_member := [1, 1]
var last_team := -1
var net: Node
var net_seat := 0
var net_wait := false
var net_shot_q := {}
var shot_ang := 0.0
var shot_spv := Vector2.ZERO
var net_pending: Dictionary = {}
var net_aim_t := 0.0
var net_auto := false
var net_auto_t := 0.0
var net_tgt: Dictionary = {}
var impacts: Array = []
var shot_pow := 3
var shot_spin := 3
var touches := {}
var vw := 1280.0
var hud: Control
var font: Font
var snd := {}
var players: Array = ["Jogador 1", "Jogador 2"]
var ai_phase := 0
var ai_t := 0.0
var ai_plan := {}
var bot := false
var bot_shots := 0
var acc := 0.0
var pool: Array = []
var pool_i := 0
var reward_txt := ""
var rot_count := 0

var ui: CanvasLayer
var save := {
	"coins": 150, "wins": 0, "losses": 0, "played": 0, "sfx": true, "vib": true,
	"felt": "verde", "cue": "classico", "owned": ["verde", "classico"], "timer": 20, "grana": 0, "spin_day": "", "pass_got": [], "spins": 0, "name": "", "truco_wins": 0, "truco_losses": 0, "pcode": "", "friends": [], "f_out": [], "f_in": [], "f_dec": [],
}
var white_tex: ImageTexture
var atlas_vp: SubViewport
var atlas_ctrl: Control
var wood_s: Sprite2D
var felt_s: Sprite2D
var felt_vp: SubViewport
var felt_rect: ColorRect
var rails: Node2D
var ball_layer: Node2D
var overlay: Node2D
var ball_shader: Shader


func _ready() -> void:
	randomize()
	get_tree().quit_on_go_back = false
	DisplayServer.screen_set_keep_on(true)
	font = ThemeDB.fallback_font
	bot = OS.get_cmdline_user_args().has("--bot")
	duel = OS.get_cmdline_user_args().has("--duel")
	load_save()
	net = load("res://net.gd").new()
	net.name = "Net"
	net.game = self
	add_child(net)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white_tex = ImageTexture.create_from_image(img)
	ball_shader = load("res://shaders/ball.gdshader")
	_make_atlas()
	_make_sounds()
	wood_s = Sprite2D.new()
	wood_s.texture = white_tex
	wood_s.scale = Vector2(1104.0 / 64.0, 604.0 / 64.0)
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/wood.gdshader")
	wood_s.material = wm
	add_child(wood_s)
	# o pano é desenhado uma vez numa textura (2x) e só refeito quando troca a mesa:
	# fica nítido e não pesa no celular
	felt_vp = SubViewport.new()
	felt_vp.size = Vector2i(2024, 1024)
	felt_vp.disable_3d = true
	felt_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(felt_vp)
	felt_rect = ColorRect.new()
	felt_rect.size = Vector2(2024, 1024)
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/felt.gdshader")
	felt_rect.material = fm
	felt_vp.add_child(felt_rect)
	felt_s = Sprite2D.new()
	felt_s.texture = felt_vp.get_texture()
	felt_s.scale = Vector2(0.5, 0.5)
	add_child(felt_s)
	rails = Node2D.new()
	add_child(rails)
	rails.draw.connect(_draw_rails)
	ball_layer = Node2D.new()
	add_child(ball_layer)
	overlay = Node2D.new()
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	cue_layer = Node2D.new()
	add_child(cue_layer)
	var cshader: Shader = load("res://shaders/cue.gdshader")
	cue_sh = Sprite2D.new()
	cue_s = Sprite2D.new()
	for sp in [cue_sh, cue_s]:
		sp.texture = white_tex
		sp.centered = false
		sp.offset = Vector2(0, -32)
		sp.scale = Vector2(560.0 / 64.0, 17.0 / 64.0)
		sp.visible = false
		var cm := ShaderMaterial.new()
		cm.shader = cshader
		sp.material = cm
		cue_layer.add_child(sp)
	(cue_sh.material as ShaderMaterial).set_shader_parameter("shadow", 1.0)
	cue_fx_n = Node2D.new()
	cue_fx_a = Node2D.new()
	var fxm := CanvasItemMaterial.new()
	fxm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cue_fx_a.material = fxm
	cue_layer.add_child(cue_fx_n)
	cue_layer.add_child(cue_fx_a)
	cue_fx_n.draw.connect(_draw_cue_fx.bind(false))
	cue_fx_a.draw.connect(_draw_cue_fx.bind(true))
	apply_felt()
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(hud)
	hud.draw.connect(_draw_hud)
	ui = UIScript.new()
	ui.game = self
	add_child(ui)
	ui.build()
	rack()
	attract_kick()
	var args := OS.get_cmdline_user_args()
	if bot:
		start_game(Mode.AI, 2 if (args.has("--hard") or args.has("--duel")) else 1)
		ai = [true, true]
		ui.show_screen("")
	elif args.has("--worldtest"):
		net_auto = true
		net_game = "truco" if args.has("--truco") else "sinuca"
		net_team = args.has("--team")
		if args.has("--b"):
			save.name = "Amigo"
			save.pcode = "BBBBBB"
			save.name = "Pedro"
			save.cue = "dragao"
		else:
			save.pcode = "AAAAAA"
		for a2 in args:
			if a2.begins_with("--code="):
				save.pcode = a2.substr(7)
				save.name = "J" + a2.substr(7, 1)
		ui.show_screen("")
		if args.has("--lobbycreate"):
			net.connect_server()
			get_tree().create_timer(2.0).timeout.connect(func(): net.world_send({"t": "lcreate", "game": net_game, "four": net_team}))
			if not args.has("--nostart"):
				get_tree().create_timer(9.0).timeout.connect(func(): net.world_send({"t": "lstart"}))
		elif not args.has("--autolobby") or not args.has("--idle"):
			net.world_search(net_game)
		if args.has("--idle"):
			net.connect_server()
		for a3 in args:
			if a3.begins_with("--lobbyinvite="):
				var lt := a3.substr(14)
				get_tree().create_timer(3.0).timeout.connect(func(): ui._invite(lt, "", true))
	elif args.has("--tnethost") or args.has("--tnetjoin"):
		net_game = "truco"
		net_auto = true
		if args.has("--tnetjoin"):
			save.name = "Amigo"
			net.start_join("127.0.0.1")
		else:
			net.start_host()
		ui.show_screen("")
	elif args.has("--netsearch"):
		net_auto = true
		if args.has("--b"):
			save.cue = "dragao"
			save.name = "Amigo"
		net.start_search()
		ui.show_screen("")
	elif args.has("--nethost") or args.has("--netjoin"):
		net_auto = true
		if args.has("--nethost"):
			print("NET host start ", net.start_host())
		else:
			save.cue = "dragao"
			save.name = "Amigo"
			save.felt = "neon"
			print("NET join start ", net.start_join("127.0.0.1"))
		ui.show_screen("")
	elif args.has("--pockettest"):
		start_game(Mode.TRAIN, 1)
		ui.show_screen("")
		pocket_test()
		get_tree().quit()
	elif args.has("--aimtest"):
		start_game(Mode.TRAIN, 1)
		ui.show_screen("")
		var miss := 0
		var tot := 0
		var ex := []
		for spd in [400.0, 1000.0, 1750.0, 2050.0]:
			for k in 60:
				var o := -25.8 + k * (51.6 / 59.0)
				for dy in [0.0, 0.37, 0.71]:
					for bb in balls:
						bb.on = false
					var cb := get_ball(0)
					var ob := get_ball(1)
					cb.on = true
					ob.on = true
					cb.pos = Vector2(-300, dy)
					ob.pos = Vector2(100, o + dy)
					cb.vel = Vector2.ZERO
					ob.vel = Vector2.ZERO
					aim_angle = randf_range(-0.0, 0.0)
					var h := ray_hit(cb.pos, Vector2.from_angle(aim_angle))
					cb.vel = Vector2.from_angle(aim_angle) * spd
					cb.top = 0.0
					cb.side = 1.3 if args.has("--side") else 0.0
					first_hit = -1
					st = St.ROLL
					var steps := 0
					while steps < 400 and cb.on and cb.pos.x < 140.0:
						for b2 in balls:
							if b2.on:
								b2["pp"] = b2.pos
						move_balls()
						steps += 1
						if first_hit != -1:
							break
					st = St.AIM
					if h.ball != null:
						tot += 1
						if first_hit != 1:
							miss += 1
							ex.append([spd, snappedf(o, 0.01)])
		print("AIMTEST previstos=", tot, " erros=", miss, " exemplos=", ex.slice(0, 12))
		get_tree().quit()
	elif args.has("--trucotest"):
		var stats := {"games": 0, "hands": 0, "w0": 0, "w1": 0, "truco": 0, "ferro": 0, "onze": 0, "bad": 0}
		for nn in [2, 4]:
			for g in (int(OS.get_environment("TG")) if OS.get_environment("TG") != "" else 60):
				var tr: Control = load("res://truco.gd").new()
				printerr("game ", nn, " ", g)
				tr.setup(self, nn, true)
				var hands_seen := 0
				var qprev := 0
				var guard := 0
				while tr.phase != "over" and guard < 2000:
					var before: Array = tr.score.duplicate()
					var q0: int = tr.queue.size()
					if q0 == 0:
						break
					var f: Callable = tr.queue.pop_front()
					if OS.get_environment("TV") != "":
						printerr("  call ", f.get_method(), " phase=", tr.phase, " turn=", tr.turn, " score=", tr.score, " res=", tr.results)
					f.call()
					if tr.phase == "respond":
						stats.truco += 1
					if tr.ferro and tr.results.is_empty() and tr.plays.is_empty():
						stats.ferro += 1
					if tr.onze != -1 and tr.results.is_empty() and tr.plays.is_empty():
						stats.onze += 1
					var qsum: int = tr.quedas[0] + tr.quedas[1]
					if qsum == qprev and (tr.score[0] < before[0] or tr.score[1] < before[1]) and not (tr.score == [0, 0] and tr.phase != "over"):
						stats.bad += 1
					if tr.score[0] > 12 or tr.score[1] > 12:
						stats.bad += 1
					qprev = qsum
					guard += 1
				stats.games += 1
				if tr.phase != "over":
					stats.bad += 1
				elif tr.quedas[tr.winner] != 2 or tr.quedas[1 - tr.winner] > 1:
					stats.bad += 1
				elif tr.winner == 0:
					stats.w0 += 1
				else:
					stats.w1 += 1
				tr.free()
		var tc: Control = load("res://truco.gd").new()
		tc.sim = true
		tc.n = 2
		tc.vira = {"r": 3, "s": 0}
		var errs := []
		# vira 7 -> manilha Q ; zap (Q paus) > Q copas > Q espadas > Q ouros > 3 > 2 > A > K > J > 7...
		var ordem := [{"r": 4, "s": 3}, {"r": 4, "s": 2}, {"r": 4, "s": 1}, {"r": 4, "s": 0}, {"r": 9, "s": 0}, {"r": 8, "s": 1}, {"r": 7, "s": 2}, {"r": 6, "s": 3}, {"r": 5, "s": 0}, {"r": 3, "s": 1}, {"r": 0, "s": 2}]
		for i in ordem.size() - 1:
			if tc.power(ordem[i]) <= tc.power(ordem[i + 1]):
				errs.append("ordem %d" % i)
		var casos := [[[0, 0], 0], [[0, 1], -2], [[0, 1, 1], 1], [[0, 1, -1], 0], [[-1, 1], 1], [[-1, -1], -2], [[-1, -1, 0], 0], [[-1, -1, -1], -1], [[1, -1], 1], [[0, -1], 0]]
		for cs in casos:
			tc.results = cs[0]
			if tc.hand_winner() != cs[1]:
				errs.append("vazas %s deu %d" % [str(cs[0]), tc.hand_winner()])
		tc.free()
		print("TRUCORULES erros=", errs)
		print("TRUCOTEST ", stats)
		get_tree().quit()
	elif args.has("--breaktest"):
		start_game(Mode.TRAIN, 1)
		ui.show_screen("")
		var cnt := [0, 0, 0, 0, 0, 0]
		var tot := 0
		var N := 60
		for k in N:
			rack()
			var cue := get_ball(0)
			cue.pos = Vector2(-250, 0)
			pocketed = []
			cue.vel = Vector2.from_angle(randf_range(-0.004, 0.004) if args.has("--jit") else 0.0) * MAXV
			st = St.ROLL
			var steps := 0
			while st == St.ROLL and steps < 40000:
				phys_step()
				steps += 1
			for bb in balls:
				if not bb.on and bb.n != 0:
					tot += 1
					var bi := 0
					for q in POCK.size():
						if bb.dpos.distance_to(POCK[q]) < bb.dpos.distance_to(POCK[bi]):
							bi = q
					cnt[bi] += 1
		print("BREAK N=", N, " bolas/quebra=", float(tot) / N, " por caçapa [TL,TR,BL,BR,TM,BM]=", cnt)
		get_tree().quit()
	elif args.has("--timeouttest"):
		start_game(Mode.TWO, 1)
		ui.show_screen("")
		turn_left = 0.005
		for i in 10:
			phys_step()
		print("TIMEOUTTEST turn=", turn, " hand=", ball_in_hand, " msg=", msg)
		get_tree().quit()
	elif args.has("--ruletest"):
		start_game(Mode.TWO, 1)
		ui.show_screen("")
		groups = [0, 1]
		break_shot = false
		first_hit = 9
		shot_by = 0
		rem_before = 7
		pocketed = []
		resolve_shot()
		var gone := []
		for b in balls:
			if not b.on:
				gone.append(b.n)
		print("RULETEST turn=", turn, " hand=", ball_in_hand, " fora=", gone, " msg=", msg)
		get_tree().quit()
	elif args.has("--rulecmp"):
		# mesmas jogadas resolvidas contra a IA, online 1x1 e online 2x2: o resultado tem que ser igual
		var cases := [
			{"nome": "matou a sua bola", "g": [0, 1], "bs": false, "fh": 3, "rb": 7, "pk": [3], "cp": false},
			{"nome": "errou tudo", "g": [0, 1], "bs": false, "fh": -1, "rb": 7, "pk": [], "cp": false},
			{"nome": "branca caiu", "g": [0, 1], "bs": false, "fh": 3, "rb": 7, "pk": [], "cp": true},
			{"nome": "bateu na do adversário", "g": [0, 1], "bs": false, "fh": 9, "rb": 7, "pk": [], "cp": false},
			{"nome": "8 antes da hora", "g": [0, 1], "bs": false, "fh": 8, "rb": 7, "pk": [8], "cp": false},
			{"nome": "8 certa no fim", "g": [0, 1], "bs": false, "fh": 8, "rb": 0, "pk": [8], "cp": false},
			{"nome": "8 certa mas branca caiu", "g": [0, 1], "bs": false, "fh": 8, "rb": 0, "pk": [8], "cp": true},
			{"nome": "8 na saída", "g": [-1, -1], "bs": true, "fh": 1, "rb": 99, "pk": [8], "cp": false},
			{"nome": "mesa aberta matou lisa", "g": [-1, -1], "bs": false, "fh": 2, "rb": 99, "pk": [2], "cp": false},
			{"nome": "mesa aberta bateu na 8", "g": [-1, -1], "bs": false, "fh": 8, "rb": 99, "pk": [], "cp": false},
			{"nome": "errou sem falta", "g": [0, 1], "bs": false, "fh": 3, "rb": 7, "pk": [], "cp": false},
		]
		var bad := 0
		for cs in cases:
			var outs := []
			for md in ["ia", "on1", "on2"]:
				start_game(Mode.AI if md == "ia" else Mode.ONLINE, 2 if md == "on2" else 1)
				net4 = md == "on2"
				bot_seats = []
				tm_member = [0, 0]
				last_team = 0
				ui.show_screen("")
				turn = 0
				groups = (cs.g as Array).duplicate()
				break_shot = bool(cs.bs)
				first_hit = int(cs.fh)
				shot_by = 0
				rem_before = int(cs.rb)
				pocketed = (cs.pk as Array).duplicate()
				cue_pocketed = bool(cs.cp)
				for n2 in pocketed:
					get_ball(int(n2)).on = false
				if cue_pocketed:
					get_ball(0).on = false
				st = St.ROLL
				_resolve_core()
				var gone := []
				for b in balls:
					if not b.on and b.n != 0:
						gone.append(b.n)
				outs.append("vez=%d mão=%s grupos=%s fim=%s vencedor=%d fora=%s" % [turn, ball_in_hand, groups, st == St.OVER, winner if st == St.OVER else -1, gone])
			var same: bool = outs[0] == outs[1] and outs[1] == outs[2]
			if not same:
				bad += 1
			print("RULECMP %-26s %s  %s" % [cs.nome, "IGUAL" if same else "DIFERENTE", outs[0] if same else str(outs)])
		print("RULECMP diferentes=", bad)
		get_tree().quit()
	elif args.has("--cuttest"):
		ccd_on = not args.has("--noccd")
		var miss := 0
		var total := 0
		for off in [0.5, 0.8, 0.9, 0.95, 0.98]:
			for pw in [0.6, 1.0]:
				start_game(Mode.TRAIN, 1)
				ui.show_screen("")
				for b in balls:
					if b.n != 0 and b.n != 1:
						b.on = false
				get_ball(0).pos = Vector2(-300, 0)
				get_ball(1).pos = Vector2(0, 0)
				var yo: float = 2.0 * R * off
				aim_angle = (Vector2(0, -yo) - Vector2(-300, 0) + Vector2(0, 0)).angle() * 0.0
				# mira para a bola alvo deslocada: ponto de contato fantasma
				var ghost := Vector2(0, 0) + Vector2(0, -1) * 0.0
				aim_angle = atan2(yo * 0.0 - 0.0, 1.0)
				# aponta para o ponto (0, yo) em relacao ao centro: o centro da branca passa a yo do centro da alvo
				aim_angle = (Vector2(0, yo) - Vector2(-300, 0)).angle()
				shoot(pw)
				var hit := false
				var guard := 0
				while st == St.STRIKE or st == St.ROLL:
					phys_step()
					if first_hit == 1:
						hit = true
						break
					guard += 1
					if guard > 240 * 6:
						break
				total += 1
				if not hit:
					miss += 1
				print("CUT off=", off, " pw=", pw, " hit=", hit)
		print("CUTTEST misses=", miss, "/", total)
		get_tree().quit()
	elif args.has("--spintest"):
		for sp_try in [Vector2(0, 0), Vector2(0, -1), Vector2(0, 1)]:
			start_game(Mode.TRAIN, 1)
			ui.show_screen("")
			for b in balls:
				if b.n != 0 and b.n != 1:
					b.on = false
			get_ball(0).pos = Vector2(-200, 0)
			get_ball(1).pos = Vector2(0, 0)
			aim_angle = 0.0
			spin = sp_try
			save.cue = "galaxia_taco"
			shoot(0.6)
			var n_after := -1
			while st == St.STRIKE or st == St.ROLL:
				phys_step()
				if first_hit != -1 and n_after < 0:
					n_after = 6
				if n_after > 0:
					n_after -= 1
				if n_after == 0:
					break
			print("SPIN ", sp_try, " cue vel after hit=", get_ball(0).vel, " obj vel=", get_ball(1).vel)
		for sp_try in [Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0)]:
			start_game(Mode.TRAIN, 1)
			ui.show_screen("")
			for b in balls:
				if b.n != 0:
					b.on = false
			get_ball(0).pos = Vector2(-100, 100)
			aim_angle = -0.6
			spin = sp_try
			save.cue = "galaxia_taco"
			shoot(0.6)
			var seen := false
			var cnt := 0
			while st == St.STRIKE or st == St.ROLL:
				phys_step()
				var cv: Vector2 = get_ball(0).vel
				if st == St.ROLL and not seen and cv.y > 0.0:
					seen = true
				if seen:
					cnt += 1
					if cnt == 3:
						break
			print("RAIL ", sp_try, " cue vel after rail=", get_ball(0).vel)
		get_tree().quit()
	elif args.has("--demo"):
		start_game(Mode.TWO, 1)
		ui.show_screen("")
		for a in args:
			if a.begins_with("--felt="):
				save.felt = a.substr(7)
				apply_felt()
			if a.begins_with("--cue="):
				save.cue = a.substr(6)
			if a.begins_with("--aim="):
				aim_angle = float(a.substr(6))
			if a.begins_with("--spin="):
				var pr := a.substr(7).split(",")
				spin = Vector2(float(pr[0]), float(pr[1]))
		aim_angle = 0.25
		power = 0.3
		for a in args:
			if a.begins_with("--aim="):
				aim_angle = float(a.substr(6))
		if args.has("--backtest"):
			get_tree().create_timer(0.5).timeout.connect(func(): on_back())
		if args.has("--groups"):
			groups = [0, 1]
			turn = 0
			begin_turn()
		if args.has("--fire"):
			aim_angle = 0.0
			shoot(0.8)
	else:
		ui.show_screen("main")
		var has_screen := false
		for a in args:
			if a.begins_with("--screen="):
				has_screen = true
		if not has_screen and not args.has("--nosplash"):
			var sp: CanvasLayer = load("res://splash.gd").new()
			add_child(sp)
			sp.start(self)
			splash_node = sp
		if not has_screen and FileAccess.file_exists(MATCH_FILE):
			get_tree().create_timer(4.4 if not args.has("--nosplash") else 0.3).timeout.connect(_offer_resume)
		for a in args:
			if a.begins_with("--screen="):
				ui.show_screen(a.substr(9))
			if a.begins_with("--truco="):
				ui.open_truco(int(a.substr(8)))
			if a == "--showtest":
				ui.open_truco(2)
				var ts: Control = ui.truco_node
				get_tree().create_timer(0.3).timeout.connect(func():
					ts.plays = [{"seat": 0, "c": {"r": 9, "s": 2}, "hid": false, "show": true}, {"seat": 1, "c": {"r": 5, "s": 0}, "hid": false, "show": true}]
					ts.phase = "resolve"
					ts._resolve_round())
			if a == "--teamui":
				net_team = true
			if a == "--trucoui":
				net_game = "truco"
			if a == "--backtest":
				get_tree().create_timer(0.5).timeout.connect(func(): on_back())
			if a == "--savetest":
				start_game(Mode.AI, 1)
				ui.show_screen("")
				get_ball(3).on = false
				get_ball(0).pos = Vector2(-100, 50)
				groups = [0, 1]
				break_shot = false
				save_match()
				print("SAVED ", FileAccess.file_exists(MATCH_FILE))
				get_tree().quit()
			if a == "--ferrotest":
				ui.open_truco(2)
				var tf: Control = ui.truco_node
				tf.score = [11, 11]
				tf.dealer = 0
				tf.new_hand()
			if a == "--facetest":
				ui.open_truco(2)
				var tn2: Control = ui.truco_node
				tn2.hands[0] = [{"r": 5, "s": 2}, {"r": 4, "s": 3}, {"r": 6, "s": 0}]
				tn2.vira = {"r": 3, "s": 1}
			if a.begins_with("--trucomodal="):
				ui.open_truco(4)
				var tn: Control = ui.truco_node
				var kind := a.substr(13)
				get_tree().create_timer(0.3).timeout.connect(func():
					tn.phase = "respond"
					tn.asker = 1
					tn.pending = 3
					if kind == "onze":
						tn._show_onze()
					elif kind == "over":
						tn.winner = 0
						tn.score = [12, 7]
						tn._show_over()
					else:
						tn._show_respond())
			if a.begins_with("--as="):
				save.pcode = a.substr(5)
				save.name = "Italo"
			if a.begins_with("--freq="):
				var tgt := a.substr(7)
				get_tree().create_timer(3.0).timeout.connect(func(): ui._friend_request(tgt, ""))
			if a == "--autoaccept":
				get_tree().create_timer(6.0).timeout.connect(func():
					for q in save.f_in.duplicate():
						ui._friend_accept(str(q.code), str(q.name)))
			if a == "--dumpfriends":
				get_tree().create_timer(10.0).timeout.connect(func():
					print("FRIENDS ", save.pcode, " friends=", save.friends, " in=", save.f_in, " out=", save.f_out)
					get_tree().quit())
			if a == "--clearfriends":
				save.friends = []
				save.f_in = []
				save.f_out = []
				save.f_dec = []
			if a.begins_with("--searchtest="):
				var qq := a.substr(13)
				get_tree().create_timer(2.5).timeout.connect(func():
					ui.friend_edit.text = qq
					ui._friend_search())
			if a == "--fakefriends":
				save.friends = [{"code": "BBBBBB", "name": "Pedro"}, {"code": "CCCCCC", "name": "Lucas"}, {"code": "DDDDDD", "name": "Ana"}, {"code": "EEEEEE", "name": "Bruna"}, {"code": "FFFFFF", "name": "Carlos"}, {"code": "GGGGGG", "name": "Duda"}, {"code": "HHHHHH", "name": "Rafa"}, {"code": "JJJJJJ", "name": "Tio Zé"}]
			if a.begins_with("--overtest="):
				var pr := a.substr(11).split(",")
				mode = Mode.ONLINE
				net4 = true
				net_seat = int(pr[0])
				winner = int(pr[1])
				ui.show_over()
				print("OVERTEST seat=", net_seat, " time_vencedor=", winner, " -> ", ui.over_title.text)
				get_tree().quit()
			if a == "--scrolltest" or a == "--taptest":
				var steps := 12 if a == "--scrolltest" else 0
				get_tree().create_timer(1.5).timeout.connect(func():
					var p0 := Vector2(1348, 520)
					var ev := InputEventScreenTouch.new()
					ev.index = 0
					ev.position = p0
					ev.pressed = true
					Input.parse_input_event(ev)
					for k in steps:
						await get_tree().process_frame
						var dr := InputEventScreenDrag.new()
						dr.index = 0
						dr.relative = Vector2(0, -15)
						dr.position = p0 + Vector2(0, -15 * (k + 1))
						Input.parse_input_event(dr)
					await get_tree().process_frame
					var up := InputEventScreenTouch.new()
					up.index = 0
					up.position = p0 + Vector2(0, -15 * steps)
					up.pressed = false
					Input.parse_input_event(up)
					await get_tree().create_timer(0.5).timeout
					print("SCROLLTEST rolou=", ui.friends_scroll.scroll_vertical, " modal=", ui.has_modal(), " amigos=", save.friends.size())
					get_tree().quit())
			if a == "--updtest":
				get_tree().create_timer(0.5).timeout.connect(func():
					ui.show_update(99, "http://127.0.0.1:18080/raw", "teste")
					ui._update_download("http://127.0.0.1:18080/raw"))
				get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit())
			if a == "--lobbyask":
				get_tree().create_timer(0.3).timeout.connect(func(): ui.lobby_create_ask(""))
			if a.begins_with("--rewardtest="):
				var rk := a.substr(13)
				get_tree().create_timer(0.3).timeout.connect(func():
					if rk == "roleta":
						ui.show_reward("Prêmio da Roleta", "+250 MOEDAS", {"coins": 250})
					else:
						var lvx := int(rk)
						ui.show_reward("Passe de Nível  •  Nível %d" % lvx, str(pass_reward(lvx).txt).to_upper(), pass_reward(lvx)))
			if a.begins_with("--fakewins="):
				save.wins = int(a.substr(11))
				save.grana = 25
				ui.refresh_top()
			if a.begins_with("--tab="):
				ui._shop_tab(a.substr(6))
			if a.begins_with("--scroll="):
				var sv := int(a.substr(9))
				get_tree().create_timer(0.4).timeout.connect(func(): ui.shop_scroll.scroll_horizontal = sv)


# ---------------------------------------------------------------- save
func load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") == OK:
		for k in save.keys():
			save[k] = cf.get_value("s", k, save[k])
	# presente: Taco do Pedro para todo mundo
	# antes taco e mesa Galáxia tinham o mesmo código: quem tinha um fica com os dois
	if save.owned.has("galaxia") and not save.owned.has("galaxia_taco"):
		save.owned.append("galaxia_taco")
	if str(save.cue) == "galaxia":
		save.cue = "galaxia_taco"


func write_save() -> void:
	if bot:
		return
	var cf := ConfigFile.new()
	for k in save.keys():
		cf.set_value("s", k, save[k])
	cf.save("user://save.cfg")


func felt_def() -> Dictionary:
	var fid: String = felt_override if felt_override != "" else str(save.felt)
	for f in FELTS:
		if f.id == fid:
			return f
	return FELTS[0]


func cue_def() -> Dictionary:
	return cue_by_id(str(save.cue))


func shooter() -> int:
	if net4:
		return turn + 2 * int(tm_member[turn])
	return turn


func cur_ai() -> bool:
	if net4:
		return net.is_host and bot_seats.has(shooter())
	return bool(ai[turn])


func my_code() -> String:
	var c := str(save.get("pcode", ""))
	if c.length() < 6:
		var abc := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
		c = ""
		for i in 6:
			c += abc[randi() % abc.length()]
		save.pcode = c
		write_save()
	return c


func my_name() -> String:
	var n := str(save.get("name", "")).strip_edges().left(15)
	return n if n != "" else "Jogador"


func cue_by_id(id: String) -> Dictionary:
	for c in CUES:
		if c.id == id:
			return c
	for c in MONTHLY:
		if c.id == id:
			return c
	return CUES[0]


# taco de quem está jogando agora (cada um usa o seu)
func turn_cue_def() -> Dictionary:
	var cs := shooter()
	if (mode == Mode.AI or mode == Mode.ONLINE) and cs < cue_ids.size() and str(cue_ids[cs]) != "":
		return cue_by_id(str(cue_ids[cs]))
	return cue_def()


func random_ai_cue() -> String:
	var pool: Array = []
	for c in CUES + MONTHLY:
		pool.append(c.id)
	return pool[randi() % pool.size()]


# ---------------------------------------------------------------- economia: nível, passe, roleta, grana
func xp() -> int:
	var tw := int(save.get("truco_wins", 0))
	var tl := int(save.get("truco_losses", 0))
	return int(save.wins) * 30 + int(save.losses) * 10 + int(save.played) * 5 + tw * 35 + tl * 15


func player_level() -> int:
	return 1 + xp() / 100


const PASS_MAX := 100


func pass_reward(lv: int) -> Dictionary:
	if lv == 10:
		return {"grana": 10, "item": "campeao", "txt": "Mesa Campeão + 10 Grana"}
	if lv == 20:
		return {"grana": 15, "txt": "15 Grana"}
	if lv == 30:
		return {"grana": 20, "item": "lenda", "txt": "Taco Raio Dourado + 20 Grana"}
	if lv == 40:
		return {"grana": 20, "item": "esmeralda", "txt": "Mesa Esmeralda + 20 Grana"}
	if lv == 50:
		return {"grana": 25, "item": "cometa", "txt": "Taco Cometa + 25 Grana"}
	if lv == 60:
		return {"grana": 25, "item": "neon", "txt": "Mesa Neon Cyber + 25 Grana"}
	if lv == 70:
		return {"grana": 30, "item": "ametista", "txt": "Mesa Cristal Ametista + 30 Grana"}
	if lv == 80:
		return {"grana": 30, "item": "cristal", "txt": "Taco Cristal + 30 Grana"}
	if lv == 90:
		return {"grana": 35, "item": "galaxia_taco", "txt": "Taco Galáxia + 35 Grana"}
	if lv == 100:
		return {"grana": 50, "item": "imperador", "txt": "Taco Imperador + 50 Grana"}
	if lv % 25 == 0:
		return {"grana": 20, "txt": "20 Grana"}
	if lv % 10 == 0:
		return {"grana": 12, "txt": "12 Grana"}
	if lv % 5 == 0:
		return {"grana": 5, "txt": "5 Grana"}
	if lv % 3 == 0:
		return {"spins": 1, "txt": "1 giro na Roleta"}
	var cn: int = 40 + 5 * mini(lv, 60)
	return {"coins": cn, "txt": "%d moedas" % cn}


func pass_claim(lv: int) -> bool:
	if lv > player_level() or save.pass_got.has(lv):
		return false
	var r := pass_reward(lv)
	save.coins += int(r.get("coins", 0))
	save.grana += int(r.get("grana", 0))
	save.spins = int(save.get("spins", 0)) + int(r.get("spins", 0))
	if r.has("item"):
		if save.owned.has(r.item):
			save.grana += 15 # já tinha comprado: vira Grana extra
		else:
			save.owned.append(r.item)
	save.pass_got.append(lv)
	write_save()
	return true


func pass_pending() -> int:
	var c := 0
	for lv in range(2, mini(player_level(), PASS_MAX) + 1):
		if not save.pass_got.has(lv):
			c += 1
	return c


func today_str() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func can_spin() -> bool:
	return str(save.spin_day) != today_str() or int(save.get("spins", 0)) > 0


# fatias da roleta: [tipo, valor, peso]
const WHEEL := [["c", 50, 22], ["c", 100, 20], ["c", 150, 16], ["c", 250, 12], ["g", 2, 6], ["c", 400, 8], ["c", 75, 14], ["c", 1000, 2]]


func spin_pick() -> int:
	var tot := 0
	for w in WHEEL:
		tot += int(w[2])
	var r := randi() % tot
	for i in WHEEL.size():
		r -= int(WHEEL[i][2])
		if r < 0:
			return i
	return 0


func spin_award(i: int) -> String:
	var w: Array = WHEEL[i]
	if str(save.spin_day) != today_str():
		save.spin_day = today_str()
	else:
		save.spins = maxi(0, int(save.spins) - 1)
	if w[0] == "g":
		save.grana += int(w[1])
		write_save()
		return "+%d Grana!" % int(w[1])
	save.coins += int(w[1])
	write_save()
	return "+%d moedas!" % int(w[1])


# Grana compra os itens caros por bem menos (mas Grana é rara)
func grana_price(it: Dictionary, promo: bool = false) -> int:
	var p: int = int(it.price)
	if promo:
		p = month_price(it)
	if p < 1000:
		return 0
	return int(ceil(float(p) / 150.0))


func month_cue() -> Dictionary:
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("--month="):
			return MONTHLY[int(ar.substr(8)) % MONTHLY.size()]
	var d := Time.get_date_dict_from_system()
	return MONTHLY[(int(d.year) * 12 + int(d.month) - 1) % MONTHLY.size()]


func month_name() -> String:
	return MONTH_NAMES[int(Time.get_date_dict_from_system().month) - 1]


func month_days_left() -> int:
	var d := Time.get_date_dict_from_system()
	var y := int(d.year)
	var mo := int(d.month)
	var dim: int = [31, 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][mo - 1]
	return dim - int(d.day) + 1


func month_price(c: Dictionary) -> int:
	return int(round(float(c.price) * 0.7 / 50.0)) * 50


func apply_felt() -> void:
	var f := felt_def()
	var m: ShaderMaterial = felt_rect.material
	m.set_shader_parameter("c_light", f.light)
	m.set_shader_parameter("c_dark", f.dark)
	m.set_shader_parameter("pat", int(f.pat))
	m.set_shader_parameter("accent", f.get("accent", Color.WHITE))
	m.set_shader_parameter("accent2", f.get("accent2", Color.WHITE))
	felt_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if rails != null:
		rails.queue_redraw()


# ---------------------------------------------------------------- atlas dos números
func _make_atlas() -> void:
	atlas_vp = SubViewport.new()
	atlas_vp.size = Vector2i(512, 512)
	atlas_vp.transparent_bg = true
	atlas_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(atlas_vp)
	atlas_ctrl = Control.new()
	atlas_ctrl.size = Vector2(512, 512)
	atlas_vp.add_child(atlas_ctrl)
	atlas_ctrl.draw.connect(_atlas_draw)


func _atlas_draw() -> void:
	for n in range(1, 16):
		var cell := Vector2((n % 4) * 128, int(n / 4) * 128)
		atlas_ctrl.draw_string(font, cell + Vector2(0, 90), str(n), HORIZONTAL_ALIGNMENT_CENTER, 128, 88, Color(0.05, 0.05, 0.05, 1))


# ---------------------------------------------------------------- áudio
func _wav(freq: float, dur: float, vol: float, slide: float, noise: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var env := pow(1.0 - float(i) / n, 2.0)
		var f := freq + slide * (float(i) / rate)
		ph += TAU * f / rate
		var v := sin(ph) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		data.encode_s16(i * 2, int(clampf(v * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _make_sounds() -> void:
	var groups_f := {
		"hit": ["s_hit1", "s_hit2", "s_hit3", "s_hit4", "s_hit5", "s_hit6", "s_hit7", "s_hit8"],
		"rail": ["s_rail1", "s_rail2", "s_rail3"],
		"pocket": ["s_pocket"],
		"shot": ["s_shot"],
		"click": ["s_click"],
	}
	for k in groups_f.keys():
		var arr: Array = []
		for f in groups_f[k]:
			arr.append(load("res://sounds/%s.wav" % f))
		snd[k] = arr
	snd["intro"] = load("res://sounds/intro.wav")
	snd["win"] = _wav(660.0, 0.5, 0.6, 500.0, 0.0)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_p = AudioStreamPlayer.new()
	var ms: AudioStream = load("res://sounds/menu_music.ogg")
	if "loop" in ms:
		ms.loop = true
	music_p.stream = ms
	music_p.volume_db = -60.0
	add_child(music_p)


func play(sname: String, vol: float = 1.0) -> void:
	if bot or not save.sfx:
		return
	if st == St.MENU and sname != "click":
		return
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	var sv: Variant = snd[sname]
	if sv is Array:
		p.stream = sv[randi() % sv.size()]
		p.pitch_scale = randf_range(0.97, 1.03)
	else:
		p.stream = sv
		p.pitch_scale = 1.0
	p.volume_db = linear_to_db(clampf(vol, 0.05, 1.0))
	p.play()


func music_update(delta: float) -> void:
	if bot or music_p == null:
		return
	var want: bool = music_ok and st == St.MENU and save.sfx
	var tgt := -8.0 if want else -60.0
	music_db = move_toward(music_db, tgt, delta * (14.0 if want else 80.0))
	if want and not music_p.playing:
		music_p.play()
	elif not want and music_p.playing and music_db <= -55.0:
		music_p.stop()
	music_p.volume_db = music_db


func vibrate(ms: int) -> void:
	if not bot and save.vib:
		Input.vibrate_handheld(ms)


# ---------------------------------------------------------------- jogo
func group_of(n: int) -> int:
	if n == BLACK:
		return 2
	return 0 if n < 8 else 1


func gname(g: int) -> String:
	return "LISAS" if g == 0 else "LISTRADAS"


func new_ball(n: int, p: Vector2) -> Dictionary:
	var q := Quaternion(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized(), randf() * TAU)
	var spr := Sprite2D.new()
	spr.texture = white_tex
	spr.scale = Vector2.ONE * (2.0 * R * PAD / 64.0)
	var m := ShaderMaterial.new()
	m.shader = ball_shader
	var col := Color("f4f4ee")
	if n != 0:
		col = BALL_COL[n if n <= 8 else n - 8]
	m.set_shader_parameter("base_color", col)
	m.set_shader_parameter("striped", 1.0 if n > 8 else 0.0)
	m.set_shader_parameter("is_cue", 1.0 if n == 0 else 0.0)
	m.set_shader_parameter("number", float(n))
	m.set_shader_parameter("atlas", atlas_vp.get_texture())
	spr.material = m
	ball_layer.add_child(spr)
	return {"n": n, "pos": p, "vel": Vector2.ZERO, "on": true, "basis": Basis(q), "spr": spr, "drop": -1.0, "dpos": Vector2.ZERO, "top": 0.0, "side": 0.0}


func get_ball(n: int) -> Dictionary:
	for b in balls:
		if b.n == n:
			return b
	return {}


func start_game(m: Mode, d: int = 1, names: Array = []) -> void:
	mode = m
	diff = d
	paused = false
	net_shot_q = {}
	ai = [false, m == Mode.AI]
	if m == Mode.AI:
		players = [my_name(), "IA GoScripts"]
	elif names.size() == 2:
		players = [str(names[0]), str(names[1])]
	else:
		players = ["Jogador 1", "Jogador 2"]
	rack()
	cue_ids = [str(save.cue), random_ai_cue() if m == Mode.AI else str(save.cue)]
	var a := OS.get_cmdline_user_args()
	turn = 0 if (m == Mode.TRAIN or a.has("--ruletest") or a.has("--timeouttest") or a.has("--breaktest")) else randi() % 2
	banner_turn = turn
	banner_ms = Time.get_ticks_msec()
	groups = [-1, -1]
	break_shot = true
	ball_in_hand = false
	winner = -1
	reward_txt = ""
	bot_shots = 0
	if m == Mode.TRAIN:
		say("Quebre o triângulo!", 3.0)
	else:
		say("%s começa! Quebre o triângulo." % players[turn], 3.5)
	begin_turn()


func go_menu() -> void:
	clear_match()
	paused = false
	net4 = false
	if felt_override != "":
		felt_override = ""
		apply_felt()
	net_wait = false
	net_pending = {}
	if net != null:
		net.stop_search()
		if net.active:
			net.close()
	st = St.MENU
	rack()
	attract_kick()
	if ui.in_lobby():
		ui.back_to_lobby()
	else:
		ui.show_screen("main")


func rack() -> void:
	for b in balls:
		if b.has("spr"):
			b.spr.queue_free()
	balls.clear()
	balls.append(new_ball(0, Vector2(-250, 0)))
	var pos: Array = []
	var dx := 2.0 * R * 0.866 + 0.6
	for row in 5:
		for j in row + 1:
			# pequenas imperfeições no triângulo, como numa mesa de verdade: cada quebra sai diferente
			pos.append(Vector2(250.0 + row * dx + randf_range(-0.3, 0.3), (j - row / 2.0) * (2.0 * R + 0.4) + randf_range(-0.3, 0.3)))
	var solids: Array = [1, 2, 3, 4, 5, 6, 7]
	var stripes: Array = [9, 10, 11, 12, 13, 14, 15]
	solids.shuffle()
	stripes.shuffle()
	var c1: int = solids.pop_back()
	var c2: int = stripes.pop_back()
	var corners: Array = [c1, c2]
	corners.shuffle()
	var rest: Array = solids + stripes
	rest.shuffle()
	var assign := {}
	assign[10] = corners[0]
	assign[14] = corners[1]
	assign[4] = BLACK
	var k := 0
	for i in 15:
		if not assign.has(i):
			assign[i] = rest[k]
			k += 1
	for i in 15:
		balls.append(new_ball(assign[i], pos[i]))
	# ordem de processamento aleatória: evita que a física resolva os choques sempre para o mesmo lado
	balls.shuffle()
	update_visuals(0.0)


func attract_kick() -> void:
	var cue := get_ball(0)
	if cue.on:
		cue.vel = Vector2.from_angle(randf() * TAU) * 1100.0
	var k := 0
	for b in balls:
		if b.on and b.n != 0 and randf() < 0.3 and k < 4:
			k += 1
			b.vel = Vector2.from_angle(randf() * TAU) * randf_range(200.0, 520.0)


func say(s: String, t: float) -> void:
	msg = s
	msg_t = t


func target_balls() -> Array:
	var res: Array = []
	var g: int = groups[turn]
	if mode == Mode.TRAIN or g == -1:
		for b in balls:
			if b.on and b.n != 0 and b.n != BLACK:
				res.append(b)
		if res.is_empty():
			res.append(get_ball(BLACK))
		return res
	for b in balls:
		if b.on and b.n != 0 and group_of(b.n) == g:
			res.append(b)
	if res.is_empty():
		var bk := get_ball(BLACK)
		if bk.on:
			res.append(bk)
	return res


func remaining(g: int) -> int:
	var c := 0
	for b in balls:
		if b.on and b.n != 0 and group_of(b.n) == g:
			c += 1
	return c


func begin_turn() -> void:
	st = St.AIM
	_save_soon = true
	net_tgt = {}
	if net4 and turn != last_team:
		tm_member[turn] = 1 - int(tm_member[turn])
		last_team = turn
	var bkey := shooter() if net4 else turn
	if mode != Mode.TRAIN and bkey != banner_turn:
		banner_turn = bkey
		banner_ms = Time.get_ticks_msec()
	turn_left = float(TURN_TIME)
	tick_last = -1
	hard_cands = []
	hard_i = 0
	ai_phase = 0
	ai_t = 0.0
	power = 0.0
	spin = Vector2.ZERO
	touches.clear()
	var cue := get_ball(0)
	var tg := target_balls()
	if cue.on and not tg.is_empty():
		var avg := Vector2.ZERO
		for b in tg:
			avg += b.pos
		avg /= tg.size()
		aim_angle = (avg - cue.pos).angle()


func shoot(pw: float, remote: bool = false) -> void:
	if mode == Mode.ONLINE and not remote:
		var c0 := get_ball(0)
		net.send_shot({"a": aim_angle, "pw": pw, "p": power, "sp": spin, "cp": c0.pos, "h": ball_in_hand, "sps": int(cue_def().pow), "sss": int(cue_def().spin)})
	if not remote:
		shot_pow = int(cue_def().pow)
		shot_spin = int(cue_def().spin)
	# a tacada fica "congelada" aqui: mira e efeito não mudam durante a animação do taco
	shot_ang = aim_angle
	shot_spv = spin
	first_hit = -1
	pocketed = []
	cue_pocketed = false
	shot_by = turn
	var g: int = groups[turn]
	rem_before = remaining(g) if g != -1 else 99
	ball_in_hand = false
	bot_shots += 1
	strike_pw = pw
	strike_pull = power * 130.0
	strike_t = 0.0
	strike_dur = 0.13 - 0.06 * pw
	power = 0.0
	if bot:
		launch()
	else:
		st = St.STRIKE


func launch() -> void:
	var cue := get_ball(0)
	# no 2x2 online todos os celulares precisam saber que a tacada é da IA (senão a força/efeito
	# muda só no anfitrião e as bolas andam diferente em cada aparelho)
	var is_bot: bool = bot_seats.has(shooter()) if net4 else cur_ai()
	var human: bool = mode == Mode.TRAIN or not is_bot
	var ang := shot_ang
	aim_angle = shot_ang
	spin = shot_spv
	var maxv := MAXV
	cue.top = 0.0
	cue.side = 0.0
	if human and not bot:
		maxv = MAXV * (0.92 + 0.05 * float(shot_pow))
		var sm := 0.55 + 0.15 * float(shot_spin)
		cue.top = -spin.y * sm
		cue.side = spin.x * sm
	cue.vel = Vector2.from_angle(ang) * (150.0 + pow(strike_pw, 1.5) * (maxv - 150.0))
	if str(turn_cue_def().get("impact", "")) == "math" and not bot:
		spawn_math(cue.pos, ang, strike_pw)
	st = St.ROLL
	play("shot", 0.4 + strike_pw * 0.6)
	vibrate(15)


# ---------------------------------------------------------------- física
func phys_step() -> void:
	sim_t += DT
	if msg_t > 0.0:
		msg_t -= DT
	if st == St.ROLL or st == St.MENU:
		move_balls()
	elif st == St.AIM:
		ai_update()
		timer_update()
	elif st == St.STRIKE:
		strike_t += DT
		if strike_t >= strike_dur:
			launch()


func timer_active() -> bool:
	return st == St.AIM and not paused and mode != Mode.TRAIN and not cur_ai()


func timer_update() -> void:
	if not timer_active():
		return
	turn_left -= DT
	var sec := int(ceil(turn_left))
	if sec <= 5 and sec != tick_last and sec > 0:
		tick_last = sec
		play("click", 0.8)
		vibrate(10)
	if turn_left <= 0.0:
		if mode == Mode.ONLINE and not net.is_host:
			turn_left = 0.01
			return
		touches.clear()
		power = 0.0
		var who: String = players[turn]
		turn = 1 - turn
		ball_in_hand = true
		begin_turn()
		say("Tempo esgotado para %s! Bola na mão para %s." % [who, players[turn]], 3.5)
		if mode == Mode.ONLINE:
			net_send_state()


func move_balls() -> void:
	rot_count += 1
	for b in balls:
		if b.on:
			b["pp"] = b.pos
	for b in balls:
		if not b.on:
			continue
		var v: Vector2 = b.vel
		if v == Vector2.ZERO:
			continue
		var p: Vector2 = b.pos + v * DT
		var sp := v.length()
		b.basis = Basis(Vector3(-v.y, v.x, 0.0) / sp, sp * DT / R) * b.basis
		if rot_count % 120 == 0:
			b.basis = b.basis.orthonormalized()
		if b.n == 0 and (absf(b.top) > 0.01 or absf(b.side) > 0.01):
			var dv: Vector2 = v / sp
			b.basis = Basis(Vector3(-dv.y, dv.x, 0.0), b.top * 9.0 * DT) * b.basis
			b.basis = Basis(Vector3(0.0, 0.0, 1.0), -b.side * 10.0 * DT) * b.basis
			v += Vector2(-dv.y, dv.x) * b.side * 14.0 * minf(1.0, sp / 500.0) * DT
			b.top *= 1.0 - 1.8 * DT
			b.side *= 1.0 - 0.7 * DT
		var ns := maxf(0.0, sp - (110.0 + sp * 0.32) * DT)
		if ns < 4.0:
			v = Vector2.ZERO
			b.top = 0.0
			b.side = 0.0
		else:
			v *= ns / sp
		var ch := cushion_hit(b, p, v, true)
		p = ch[0]
		v = ch[1]
		b.pos = p
		b.vel = v
		var caught := -1
		for k in POCK.size():
			var dd: float = p.distance_to(POCK[k])
			var pr: float = PR_CORNER if k < 4 else PR_SIDE
			if dd < pr:
				caught = k
				break
		if caught == -1 and (absf(p.x) > HW + 40.0 or absf(p.y) > HH + 40.0):
			caught = 0
			var bd := 1e9
			for k in POCK.size():
				var dd: float = p.distance_to(POCK[k])
				if dd < bd:
					bd = dd
					caught = k
		if caught != -1:
			pocket_ball(b, POCK[caught])
	var n := balls.size()
	for i in n:
		var a: Dictionary = balls[i]
		if not a.on:
			continue
		for j in range(i + 1, n):
			var b: Dictionary = balls[j]
			if not b.on:
				continue
			if a.vel == Vector2.ZERO and b.vel == Vector2.ZERO:
				continue
			var d: Vector2 = b.pos - a.pos
			var d2 := d.length_squared()
			var ccd_rem := 0.0
			if ccd_on and d2 >= 4.0 * R * R and a.has("pp") and b.has("pp"):
				# colisão contínua: evita a bola "atravessar" numa batida fina em alta velocidade
				var r0: Vector2 = b.pp - a.pp
				var da: Vector2 = a.pos - a.pp
				var db: Vector2 = b.pos - b.pp
				var rv: Vector2 = db - da
				var qa := rv.length_squared()
				var qc := r0.length_squared() - 4.0 * R * R
				if qa > 0.0001 and qc > 0.0:
					var qb := r0.dot(rv)
					var disc := qb * qb - qa * qc
					if disc >= 0.0:
						var sc := (-qb - sqrt(disc)) / qa
						if sc >= 0.0 and sc <= 1.0:
							sc = minf(sc + 0.003, 1.0)
							a.pos = a.pp + da * sc
							b.pos = b.pp + db * sc
							ccd_rem = 1.0 - sc
							d = b.pos - a.pos
							d2 = d.length_squared()
			if d2 < 4.0 * R * R and d2 > 0.0001:
				var dist := sqrt(d2)
				var nrm := d / dist
				var ov := 2.0 * R - dist
				a.pos -= nrm * ov * 0.5
				b.pos += nrm * ov * 0.5
				var vn: float = (b.vel - a.vel).dot(nrm)
				if vn < 0.0:
					var cb: Dictionary = a if a.n == 0 else (b if b.n == 0 else {})
					var vpre: Vector2 = cb.vel if not cb.is_empty() else Vector2.ZERO
					var jj := -(1.0 + 0.96) * vn / 2.0
					a.vel -= nrm * jj
					b.vel += nrm * jj
					if not cb.is_empty() and (absf(cb.top) > 0.01 or absf(cb.side) > 0.01) and vpre.length() > 20.0:
						var dp := vpre.normalized()
						var spd := minf(vpre.length(), 1100.0)
						cb.vel += dp * cb.top * 0.42 * spd
						cb.vel += Vector2(-dp.y, dp.x) * cb.side * 0.16 * spd
						cb.top *= 0.2
						cb.side *= 0.75
					play("hit", 0.15 + absf(vn) / 700.0)
					if first_hit == -1 and st == St.ROLL:
						if a.n == 0:
							first_hit = b.n
						elif b.n == 0:
							first_hit = a.n
				if ccd_rem > 0.0:
					a.pos += a.vel * DT * ccd_rem
					b.pos += b.vel * DT * ccd_rem
	for b in balls:
		if b.on and b.vel != Vector2.ZERO:
			return
	if st == St.MENU:
		attract_kick()
	elif st == St.ROLL:
		if mode == Mode.ONLINE and not net.is_host:
			if not net_wait:
				net_wait = true
				if not net_pending.is_empty():
					var sn := net_pending
					net_pending = {}
					net_apply(sn)
			return
		resolve_shot()


# tabelas: [início, fim, normal p/ fora, recuo do bico no início, recuo no fim] (mesmas do desenho)
func pt_run(p0: Vector2, v0: Vector2) -> Dictionary:
	for bb in balls:
		bb.on = false
	var b := get_ball(1)
	b.on = true
	b.pos = p0
	b.vel = v0
	b.top = 0.0
	b.side = 0.0
	st = St.AIM
	var worst := 0.0
	var hits := 0
	var steps := 0
	while b.on and b.vel != Vector2.ZERO and steps < 6000:
		var pp: Vector2 = b.pos
		var sp: float = b.vel.length()
		move_balls()
		if b.on:
			var jump: float = (b.pos - pp).length() - sp * DT
			worst = maxf(worst, jump)
		steps += 1
	var k := -1
	if not b.on:
		for q in POCK.size():
			if b.dpos == POCK[q]:
				k = q
	return {"in": not b.on, "k": k, "jump": worst}


func pocket_test() -> void:
	var worst := 0.0
	print("== CANTO (caçapa sup. esquerda): faixa de desvio lateral (px) que entra; bola tem diâmetro 26")
	var C: Vector2 = POCK[0]
	for spd in [350.0, 800.0, 1400.0]:
		var line := "vel %4d:" % int(spd)
		for ang in [8.0, 20.0, 35.0, 45.0, 55.0, 70.0, 82.0]:
			var u := Vector2.from_angle(PI + deg_to_rad(ang))
			var perp := u.orthogonal()
			var lo := 999.0
			var hi := -999.0
			var n_in := 0
			var wrong := 0
			var e := -30.0
			while e <= 30.0:
				var s: Vector2 = C - u * 240.0 + perp * e
				s.x = clampf(s.x, -HW + R + 1.0, HW - R - 1.0)
				s.y = clampf(s.y, -HH + R + 1.0, HH - R - 1.0)
				var r := pt_run(s, (C + perp * e - s).normalized() * spd)
				worst = maxf(worst, r.jump)
				if r.in and r.k == 0:
					n_in += 1
					lo = minf(lo, e)
					hi = maxf(hi, e)
				elif r.in:
					wrong += 1
				e += 1.0
			line += "  %2d°:[%+.0f,%+.0f]" % [int(ang), lo, hi] if n_in > 0 else "  %2d°:nenhuma" % int(ang)
		print(line)
	print("== MEIO (caçapa sup. do meio)")
	var M: Vector2 = POCK[4]
	for spd in [350.0, 800.0, 1400.0]:
		var line := "vel %4d:" % int(spd)
		for ang in [90.0, 70.0, 55.0, 40.0, 30.0]:
			var u := Vector2.from_angle(-deg_to_rad(ang))
			if ang != 90.0:
				u = Vector2(-cos(deg_to_rad(ang)), -sin(deg_to_rad(ang)))
			else:
				u = Vector2(0, -1)
			var perp := u.orthogonal()
			var lo := 999.0
			var hi := -999.0
			var n_in := 0
			var e := -30.0
			while e <= 30.0:
				var s: Vector2 = M - u * 220.0 + perp * e
				s.x = clampf(s.x, -HW + R + 1.0, HW - R - 1.0)
				s.y = clampf(s.y, -HH + R + 1.0, HH - R - 1.0)
				var r := pt_run(s, (M + perp * e - s).normalized() * spd)
				worst = maxf(worst, r.jump)
				if r.in and r.k == 4:
					n_in += 1
					lo = minf(lo, e)
					hi = maxf(hi, e)
				e += 1.0
			line += "  %2d°:[%+.0f,%+.0f]" % [int(ang), lo, hi] if n_in > 0 else "  %2d°:nenhuma" % int(ang)
		print(line)
	print("== ROLANDO COLADA NA TABELA")
	for spd in [250.0, 600.0, 1200.0]:
		var r1 := pt_run(Vector2(-300, -HH + R + 0.5), Vector2(-spd, 0))
		var r2 := pt_run(Vector2(250, -HH + R + 0.5), Vector2(-spd, 0))
		var r3 := pt_run(Vector2(250, -HH + R + 4.0), Vector2(-spd, -spd * 0.02))
		worst = maxf(worst, maxf(r1.jump, maxf(r2.jump, r3.jump)))
		print("vel %4d: rumo ao canto=%s  passando pela do meio=%s (k=%d)  quase colada=%s (k=%d)" % [int(spd), "ENTRA" if r1.in else "fica", "ENTRA" if r2.in else "passa", r2.k, "ENTRA" if r3.in else "passa", r3.k])
	print("== BICO: bola batendo direto na ponta da tabela perto da caçapa")
	var nb := 0
	var ni := 0
	for spd in [400.0, 900.0, 1500.0]:
		for off in [-14.0, -10.0, 10.0, 14.0]:
			var tip := Vector2(-HW + 26.0, -HH)
			var target := tip + Vector2(off, 13.0)
			var s := target + Vector2(120, 160)
			var r := pt_run(s, (target - s).normalized() * spd)
			worst = maxf(worst, r.jump)
			nb += 1
			if r.in:
				ni += 1
	print("batidas na ponta do bico: %d, caíram: %d" % [nb, ni])
	print("== MAIOR SALTO ANORMAL ENTRE PASSOS (teletransporte): %.2f px" % worst)


const MATH_TXT := ["π", "+1", "×2", "2+2=4", "√9=3", "7", "3,14", "=", "÷", "10", "x²", "∞", "5×5", "1+1"]


func spawn_math(p: Vector2, ang: float, pw: float) -> void:
	var n := 7 + int(pw * 6.0)
	for i in n:
		var a := ang + PI + randf_range(-1.6, 1.6)
		impacts.append({"p": p, "v": Vector2.from_angle(a) * randf_range(60.0, 170.0) * (0.7 + pw), "t": 0.0, "life": randf_range(0.9, 1.5), "txt": MATH_TXT[randi() % MATH_TXT.size()], "c": [Color("3df0ff"), Color("ffd34a"), Color("ffffff"), Color("ff6b8a")][randi() % 4], "s": randi_range(16, 26)})


# ---------------------------------------------------------------- proteção: voltar / sair do app sem querer
const MATCH_FILE := "user://partida.json"
var _save_soon := false


func in_match() -> bool:
	return st != St.MENU and st != St.OVER


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		on_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# saiu do app (botão home, ligação, notificação): pausa e guarda a partida
		if in_match() and not bot:
			save_match()
			if mode != Mode.ONLINE and not paused:
				paused = true
				touches.clear()
				ui.show_screen("pause")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if in_match():
			save_match()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# voltou para o app: reconecta logo ao servidor se a conexão caiu
		if net != null and net.keep_online:
			net.retry_wait = 0.5


func on_back() -> void:
	if ui.has_modal():
		ui.close_modal()
		return
	var tn = ui.truco_node
	if tn != null and is_instance_valid(tn):
		tn.on_back()
		return
	if in_match():
		if ui.cur == "pause":
			ui._resume()
		else:
			paused = mode != Mode.ONLINE
			touches.clear()
			ui.show_screen("pause")
		return
	ui.menu_back()


func save_match() -> void:
	if mode == Mode.ONLINE or not in_match() or st == St.ROLL or st == St.STRIKE:
		return
	var bl := []
	for b in balls:
		bl.append([b.n, b.on, b.pos.x, b.pos.y])
	var d := {"mode": int(mode), "diff": diff, "players": players, "turn": turn, "groups": groups, "hand": ball_in_hand,
		"brk": break_shot, "cues": cue_ids, "balls": bl}
	var f := FileAccess.open(MATCH_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


func clear_match() -> void:
	if FileAccess.file_exists(MATCH_FILE):
		DirAccess.remove_absolute(MATCH_FILE)


func _offer_resume() -> void:
	if splash_node != null and is_instance_valid(splash_node):
		get_tree().create_timer(0.5).timeout.connect(_offer_resume)
		return
	if in_match() or not FileAccess.file_exists(MATCH_FILE):
		return
	if ui.truco_node != null and is_instance_valid(ui.truco_node):
		return
	ui.confirm("PARTIDA EM ANDAMENTO", "Você saiu no meio de uma partida de sinuca.\nQuer continuar de onde parou?", "CONTINUAR", resume_match, "DESCARTAR", clear_match)


func resume_match() -> void:
	var txt := FileAccess.get_file_as_string(MATCH_FILE)
	var d = JSON.parse_string(txt)
	if not (d is Dictionary):
		clear_match()
		return
	ui.show_screen("")
	start_game(int(d.mode) as Mode, int(d.diff), d.players if int(d.mode) == Mode.TWO else [])
	players = d.players
	turn = int(d.turn)
	groups = [int(d.groups[0]), int(d.groups[1])]
	ball_in_hand = bool(d.hand)
	break_shot = bool(d.brk)
	cue_ids = d.cues
	for e in d.balls:
		var b := get_ball(int(e[0]))
		if b.is_empty():
			continue
		b.on = bool(e[1])
		b.pos = Vector2(float(e[2]), float(e[3]))
		b.vel = Vector2.ZERO
		b.drop = -1.0
	banner_turn = -1
	begin_turn()
	say("Partida retomada!", 2.5)


func cushion_specs() -> Array:
	return [
		[Vector2(-HW + 26, -HH), Vector2(-21, -HH), Vector2(0, -1), 19.0, 2.0],
		[Vector2(21, -HH), Vector2(HW - 26, -HH), Vector2(0, -1), 2.0, 19.0],
		[Vector2(-HW + 26, HH), Vector2(-21, HH), Vector2(0, 1), 19.0, 2.0],
		[Vector2(21, HH), Vector2(HW - 26, HH), Vector2(0, 1), 2.0, 19.0],
		[Vector2(-HW, -HH + 26), Vector2(-HW, HH - 26), Vector2(-1, 0), 19.0, 19.0],
		[Vector2(HW, -HH + 26), Vector2(HW, HH - 26), Vector2(1, 0), 19.0, 19.0],
	]


var segs: Array = []


func build_segs() -> void:
	segs = []
	for c in cushion_specs():
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		var nrm: Vector2 = c[2]
		var d := (b - a).normalized()
		var ab := a + nrm * 27.0 - d * float(c[3])
		var bb := b + nrm * 27.0 + d * float(c[4])
		segs.append([ab, a])
		segs.append([a, b])
		segs.append([b, bb])


# colisão com tabelas e bicos das caçapas (segmentos com pontas arredondadas)
func cushion_hit(b: Dictionary, p: Vector2, v: Vector2, real: bool) -> Array:
	if absf(p.x) < HW - R - 2.0 and absf(p.y) < HH - R - 2.0:
		return [p, v]
	if segs.is_empty():
		build_segs()
	for s in segs:
		var a: Vector2 = s[0]
		var ab: Vector2 = s[1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q: Vector2 = a + ab * t
		var dv: Vector2 = p - q
		var dl := dv.length()
		if dl < R and dl > 0.0001:
			var n: Vector2 = dv / dl
			p = q + n * R
			var vn := v.dot(n)
			if vn < 0.0:
				var vn0 := -vn
				var vt: Vector2 = v - n * vn
				v = vt * 0.98 - n * vn * 0.8
				if real:
					play("rail", vn0 / 900.0)
					v = rail_spin(b, v, -n, vn0)
	return [p, v]


func rail_spin(b: Dictionary, v: Vector2, n: Vector2, vn: float) -> Vector2:
	if b.n != 0:
		return v
	if absf(b.side) > 0.01:
		v += -n.orthogonal() * b.side * 0.32 * vn
		b.side *= 0.55
	if absf(b.top) > 0.01:
		v *= clampf(1.0 + 0.14 * b.top, 0.8, 1.2)
		b.top *= 0.5
	return v


func pocket_ball(b: Dictionary, pk: Vector2) -> void:
	if st == St.MENU:
		for k in 30:
			var p := Vector2(randf_range(-HW + 2 * R, HW - 2 * R), randf_range(-HH + 2 * R, HH - 2 * R))
			if free_spot(p, b.n):
				b.pos = p
				b.vel = Vector2.from_angle(randf() * TAU) * randf_range(250.0, 700.0)
				return
		b.pos = Vector2.ZERO
		return
	if OS.get_cmdline_user_args().has("--dbgpocket"):
		print("POCKET n=", b.n, " pos=", b.pos, " vel=", b.vel, " t=", sim_t)
	b.on = false
	b.vel = Vector2.ZERO
	b.drop = 0.0
	b.dpos = pk
	if b.n == 0:
		cue_pocketed = true
	else:
		pocketed.append(b.n)
	play("pocket")
	vibrate(25)


func free_spot(p: Vector2, ignore: int = 0) -> bool:
	if absf(p.x) > HW - R or absf(p.y) > HH - R:
		return false
	for b in balls:
		if b.on and b.n != ignore and b.pos.distance_to(p) < 2.0 * R + 1.0:
			return false
	return true


func end_game(win_idx: int) -> void:
	clear_match()
	winner = win_idx
	st = St.OVER
	play("win")
	save.played += 1
	if mode == Mode.AI:
		if win_idx == 0:
			var r: int = 50 + diff * 25
			save.coins += r
			save.wins += 1
			reward_txt = "+%d moedas" % r
		else:
			save.coins += 10
			save.losses += 1
			reward_txt = "+10 moedas"
	if mode == Mode.ONLINE:
		if win_idx == net_seat % 2:
			save.wins += 1
			save.coins += 60
			reward_txt = "+60 moedas"
		else:
			save.losses += 1
			save.coins += 15
			reward_txt = "+15 moedas"
	write_save()
	if not bot:
		ui.show_over()


func resolve_shot() -> void:
	if mode == Mode.ONLINE:
		# zera giros que sobraram nas bolas paradas: os outros celulares recebem as bolas sem giro
		for b in balls:
			b.top = 0.0
			b.side = 0.0
			b.vel = Vector2.ZERO
	_resolve_core()
	if mode == Mode.ONLINE:
		net_send_state()


func _resolve_core() -> void:
	var cue := get_ball(0)
	if mode == Mode.TRAIN:
		if cue_pocketed:
			cue.on = true
			cue.drop = -1.0
			cue.pos = Vector2(-250, 0)
		var left := 0
		for b in balls:
			if b.on and b.n != 0:
				left += 1
		if left == 0:
			rack()
		begin_turn()
		return
	var me := shot_by
	var g: int = groups[me]
	var foul := false
	var wrong := false
	var why := ""
	if cue_pocketed:
		foul = true
		why = "Branca caiu!"
	elif first_hit == -1:
		foul = true
		why = "Não tocou em nenhuma bola!"
	elif g == -1:
		if first_hit == BLACK:
			foul = true
			why = "Bateu na 8 com a mesa aberta!"
	else:
		var need_black := rem_before == 0
		if need_black and first_hit != BLACK:
			foul = true
			wrong = true
			why = "Agora é só a preta!"
		elif not need_black and first_hit == BLACK:
			foul = true
			wrong = true
			why = "Bateu na 8 antes da hora!"
		elif not need_black and group_of(first_hit) != g:
			foul = true
			wrong = true
			why = "Bateu primeiro na bola do adversário!"
	if pocketed.has(BLACK):
		if break_shot:
			var bk := get_ball(BLACK)
			bk.on = true
			bk.drop = -1.0
			bk.pos = Vector2(250, 0)
			for o in balls:
				if o.on and o.n != BLACK and o.pos.distance_to(bk.pos) < 2.0 * R:
					bk.pos.x += 2.0 * R
			pocketed.erase(BLACK)
		else:
			var legal := g != -1 and rem_before == 0 and not foul
			end_game(me if legal else 1 - me)
			return
	if g == -1 and not foul:
		for n in pocketed:
			if n != BLACK:
				groups[me] = group_of(n)
				groups[1 - me] = 1 - group_of(n)
				g = groups[me]
				say("%s joga com as %s!" % [players[me], gname(g)], 3.0)
				break
	var scored := false
	for n in pocketed:
		if n != BLACK and (g == -1 or group_of(n) == g):
			scored = true
	break_shot = false
	if cue_pocketed:
		cue.on = true
		cue.drop = -1.0
		cue.pos = Vector2(-250, 0)
		cue.vel = Vector2.ZERO
	if foul:
		turn = 1 - me
		var extra := ""
		if cue_pocketed or not wrong:
			ball_in_hand = true
			extra = " Bola na mão para %s." % players[turn]
		if wrong:
			var opp: int = 1 - int(groups[me])
			var low: Dictionary = {}
			for b in balls:
				if b.on and b.n != 0 and group_of(b.n) == opp:
					if low.is_empty() or b.n < low.n:
						low = b
			if not low.is_empty():
				var bp: Vector2 = POCK[0]
				for k in POCK:
					if low.pos.distance_to(k) < low.pos.distance_to(bp):
						bp = k
				low.on = false
				low.drop = 0.0
				low.dpos = bp
				extra += " Sai a bola %d de %s." % [low.n, players[turn]]
		say("Falta: %s%s" % [why, extra], 4.5)
	elif scored:
		if msg_t <= 0.0:
			say("Boa! Joga de novo", 2.0)
	else:
		turn = 1 - me
	if net_auto and net4:
		print("RES4 shooter=", shooter(), " bot=", bot_seats.has(shooter()), " team=", me, " g=", g, " pk=", pocketed, " first=", first_hit, " foul=", foul, " scored=", scored, " -> turn=", turn)
	begin_turn()


# ---------------------------------------------------------------- online
func net_snapshot() -> Dictionary:
	var arr := []
	for b in balls:
		arr.append([b.n, b.on, b.pos, b.drop, b.dpos])
	return {"b": arr, "turn": turn, "g": groups, "h": ball_in_hand, "bs": break_shot, "msg": msg if msg_t > 0.0 else "", "mt": msg_t, "over": st == St.OVER, "w": winner,
		"mem": tm_member, "lt": last_team, "cues": cue_ids, "sn": seat_names, "bots": bot_seats}


func net_checksum() -> float:
	var s := 0.0
	for b in balls:
		s += (b.pos.x * 7.0 + b.pos.y * 13.0 + float(b.n)) * (1.0 if b.on else 0.0) + (0.5 if b.on else 0.0)
	return snappedf(s, 0.01)


func net_send_state() -> void:
	net.send_state(net_snapshot())
	if net_auto:
		print("NET host snap turn=", turn, " sum=", net_checksum(), " over=", st == St.OVER)


func net_apply(s: Dictionary) -> void:
	var pre := net_checksum()
	# mesma ordem de bolas do anfitrião (a física depende da ordem)
	var ordered: Array = []
	for e in s.b:
		var bo := get_ball(int(e[0]))
		if not bo.is_empty():
			ordered.append(bo)
	if ordered.size() == balls.size():
		balls = ordered
	for e in s.b:
		var b := get_ball(int(e[0]))
		if b.is_empty():
			continue
		var on: bool = e[1]
		if on:
			if not b.on:
				b.drop = -1.0
			b.on = true
		else:
			if b.on:
				b.drop = 0.0
				b.dpos = e[4]
			b.on = false
		b.pos = e[2]
		b.vel = Vector2.ZERO
		b.top = 0.0
		b.side = 0.0
	turn = int(s.turn)
	groups = s.g
	ball_in_hand = s.h
	break_shot = s.bs
	net_wait = false
	net_pending = {}
	if str(s.msg) != "":
		say(str(s.msg), float(s.mt))
	if net_auto:
		print("NET join snap turn=", turn, " sum=", net_checksum(), " pre=", pre, " over=", s.over)
	if s.has("cues"):
		cue_ids = s.cues
	if s.has("sn") and not (s.sn as Array).is_empty():
		seat_names = s.sn
		bot_seats = s.get("bots", [])
	if s.over:
		end_game(int(s.w))
	else:
		begin_turn()
		if s.has("mem"):
			tm_member = s.mem
			last_team = int(s.lt)
		if net_auto and net4:
			print("GUEST4 turn=", turn, " shooter=", shooter(), " seat=", net_seat)
		if not net_shot_q.is_empty():
			var q := net_shot_q
			net_shot_q = {}
			net_remote_shot(q)


# ---- online 2x2 (4 jogadores). Assento = peer - 1; times: assentos pares x ímpares
func net_start4(is_host: bool, plist: Array, my_peer: int) -> void:
	seat_names = ["IA GoScripts", "IA GoScripts", "IA GoScripts", "IA GoScripts"]
	bot_seats = [0, 1, 2, 3]
	var peers := {}
	for p in plist:
		var s := int(p.peer) - 1
		if s >= 0 and s < 4:
			seat_names[s] = str(p.name)
			bot_seats.erase(s)
			if int(p.peer) != 1:
				peers[s] = int(p.peer)
	net_seat = my_peer - 1
	if net_auto:
		print("START4 ", save.pcode, " seat=", net_seat, " names=", seat_names, " bots=", bot_seats)
	if net_game == "truco":
		if is_host:
			ui.open_truco_net("host", {"names": seat_names.duplicate(), "peers": peers})
		else:
			ui.open_truco_net("guest", {})
		return
	if not is_host:
		ui.online_status("Mesa montada! Esperando o anfitrião...")
		return
	net4 = true
	ui.show_screen("")
	felt_override = ""
	apply_felt()
	start_game(Mode.ONLINE, 2, ["%s & %s" % [seat_names[0], seat_names[2]], "%s & %s" % [seat_names[1], seat_names[3]]])
	cue_ids = [str(save.cue), random_ai_cue(), random_ai_cue(), random_ai_cue()]
	tm_member = [1, 1]
	last_team = -1
	begin_turn()
	var sn := net_snapshot()
	sn["names"] = players
	sn["felt"] = str(save.felt)
	sn["n4"] = true
	net.send_start(sn)


func net_hello4(peer: int, d: Dictionary) -> void:
	var s := peer - 1
	if net4 and s >= 0 and s < cue_ids.size():
		cue_ids[s] = cue_by_id(str(d.get("cue", "classico"))).id


func net_peer_dropped(peer: int) -> void:
	var s := peer - 1
	var tn = ui.truco_node
	if tn != null and is_instance_valid(tn) and tn.netmode == "host":
		tn.seat_dropped(peer)
		return
	if net4 and s >= 0 and s < 4 and not bot_seats.has(s):
		bot_seats.append(s)
		say("%s saiu. A IA GoScripts assume o lugar." % str(seat_names[s]), 3.0)
		seat_names[s] = "IA GoScripts"
		if net.is_host:
			net_send_state()


func net_start_match() -> void:
	if net_game == "truco":
		ui.open_truco_net("host", net_peer_name)
		net.send_tstart({"name": my_name()})
		return
	net_seat = 0
	ui.show_screen("")
	felt_override = ""
	apply_felt()
	start_game(Mode.ONLINE, 1, [my_name(), net_peer_name])
	cue_ids = [str(save.cue), net_peer_cue]
	var sn := net_snapshot()
	sn["names"] = players
	sn["cues"] = cue_ids
	sn["felt"] = str(save.felt)
	net.send_start(sn)


func net_client_start(s: Dictionary) -> void:
	net_seat = 1
	net4 = bool(s.get("n4", false))
	if net4:
		net_seat = net.my_peer - 1
	ui.show_screen("")
	felt_override = str(s.get("felt", ""))
	var ok := false
	for f in FELTS:
		if f.id == felt_override:
			ok = true
	if not ok:
		felt_override = ""
	apply_felt()
	start_game(Mode.ONLINE, 1, s.get("names", []))
	var cs: Array = s.get("cues", [])
	if cs.size() == 2:
		cue_ids = [cue_by_id(str(cs[0])).id, cue_by_id(str(cs[1])).id]
	if net_auto:
		print("NET join cues=", cue_ids, " felt=", felt_def().id, " players=", players, " turn=", s.turn)
	net_apply(s)


func net_receive_state(s: Dictionary) -> void:
	if mode != Mode.ONLINE or st == St.MENU:
		return
	if st == St.ROLL and net_wait:
		net_apply(s)
	elif st == St.ROLL or st == St.STRIKE:
		net_pending = s
	else:
		net_apply(s)


func net_remote_shot(d: Dictionary) -> void:
	if mode == Mode.ONLINE and (st == St.ROLL or st == St.STRIKE):
		# ainda terminando a tacada anterior aqui: guarda e joga assim que chegar o estado do anfitrião
		net_shot_q = d
		return
	if mode != Mode.ONLINE or st != St.AIM or shooter() == net_seat:
		if net_auto:
			print("SHOT IGNORADO st=", st, " shooter=", shooter(), " seat=", net_seat)
		return
	net_tgt = {}
	var cue := get_ball(0)
	aim_angle = float(d.a)
	power = float(d.p)
	spin = d.sp
	# a posição da branca vem sempre de quem tacou (bola na mão, saída etc.)
	cue.pos = d.cp
	touches.clear()
	shoot(float(d.pw), true)
	shot_pow = int(d.sps)
	shot_spin = int(d.sss)


func net_remote_aim(d: Dictionary) -> void:
	if mode != Mode.ONLINE or st != St.AIM or shooter() == net_seat:
		return
	# guarda o alvo; o movimento é suavizado a cada quadro em net_tick
	net_tgt = d


func net_lost() -> void:
	var tn = ui.truco_node if ui != null else null
	if tn != null and is_instance_valid(tn) and tn.netmode != "":
		var was_over: bool = tn.phase == "over"
		if not was_over:
			ui.close_truco()
			ui.say("O adversário saiu da partida.")
		return
	if mode == Mode.ONLINE and st != St.MENU:
		var was_over := st == St.OVER
		go_menu()
		if not was_over:
			ui.say("O adversário saiu da partida.")
	elif ui != null:
		ui.online_status("Conexão encerrada.")
	if net_auto:
		print("NET connection lost")
		get_tree().quit()


func net_tick(delta: float) -> void:
	if mode != Mode.ONLINE or net == null or not net.active:
		return
	if st == St.AIM and shooter() != net_seat and not net_tgt.is_empty():
		var k := 1.0 - exp(-delta * 16.0)
		aim_angle = lerp_angle(aim_angle, float(net_tgt.a), k)
		power = lerpf(power, float(net_tgt.p), k)
		spin = spin.lerp(net_tgt.sp, k)
		if bool(net_tgt.h) and ball_in_hand:
			var cb := get_ball(0)
			cb.pos = cb.pos.lerp(net_tgt.cp, k)
	if human_turn():
		net_aim_t += delta
		if net_aim_t > 0.033:
			net_aim_t = 0.0
			net.send_aim({"a": aim_angle, "p": power, "sp": spin, "cp": get_ball(0).pos, "h": ball_in_hand})
		if net_auto:
			net_auto_t += delta
			if net_auto_t > 0.8:
				net_auto_t = 0.0
				var tg := target_balls()
				var cue := get_ball(0)
				if not tg.is_empty():
					var t: Dictionary = tg[randi() % tg.size()]
					aim_angle = (t.pos - cue.pos).angle() + randf_range(-0.08, 0.08)
				power = 0.55
				shoot(0.6)
	if net_auto and net.snaps >= 8 and st == St.AIM:
		net_auto_t += delta
		if net_auto_t > 1.5:
			print("NET done snaps=", net.snaps)
			get_tree().quit()


# ---------------------------------------------------------------- IA
func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func path_clear_on(sb: Array, a: Vector2, b: Vector2, ignore: Array) -> bool:
	for o in sb:
		if o.on and not ignore.has(o.n):
			if seg_dist(o.pos, a, b) < 2.0 * R * 0.97:
				return false
	return true


func targets_on(sb: Array, grp: int) -> Array:
	var res: Array = []
	for b in sb:
		if b.on and b.n != 0 and b.n != BLACK:
			if grp == -1 or group_of(b.n) == grp:
				res.append(b)
	if res.is_empty():
		for b in sb:
			if b.n == BLACK and b.on:
				res.append(b)
	return res


func candidates_on(sb: Array, cpos: Vector2, grp: int) -> Array:
	var out: Array = []
	for tb in targets_on(sb, grp):
		for pk in AIMP:
			var dbp: Vector2 = pk - tb.pos
			var d_bp := dbp.length()
			if d_bp < 1.0:
				continue
			dbp /= d_bp
			var ghost: Vector2 = tb.pos - dbp * (2.0 * R)
			if absf(ghost.x) > HW - R or absf(ghost.y) > HH - R:
				continue
			var cg := ghost - cpos
			var d_cg := cg.length()
			if d_cg < 1.0:
				continue
			var dcg := cg / d_cg
			var cut := dcg.dot(dbp)
			if cut < 0.3:
				continue
			if not path_clear_on(sb, cpos, ghost, [0, tb.n]):
				continue
			if not path_clear_on(sb, tb.pos, pk, [0, tb.n]):
				continue
			out.append({
				"score": d_cg + d_bp * 1.2 + (1.0 - cut) * 600.0,
				"angle": dcg.angle(),
				"power": clampf(0.22 + (d_cg + d_bp) / 1900.0, 0.3, 0.95),
			})
	out.sort_custom(func(x, y): return x.score < y.score)
	return out


func best_shot_on(sb: Array, cpos: Vector2, grp: int) -> Dictionary:
	var c := candidates_on(sb, cpos, grp)
	if not c.is_empty():
		return c[0]
	var tgs := targets_on(sb, grp)
	if tgs.is_empty():
		return {"score": 5000.0, "angle": 0.0, "power": 0.5}
	var nearest: Dictionary = tgs[0]
	for tb in tgs:
		if tb.pos.distance_to(cpos) < nearest.pos.distance_to(cpos):
			nearest = tb
	return {"score": 5000.0, "angle": (nearest.pos - cpos).angle(), "power": 0.5}


func best_shot(cpos: Vector2) -> Dictionary:
	var grp: int = -1 if mode == Mode.TRAIN else int(groups[turn])
	return best_shot_on(balls, cpos, grp)


# ---- simulação (IA difícil): roda a física numa cópia da mesa
func sim_copy() -> Array:
	var out: Array = []
	for b in balls:
		out.append({"n": b.n, "pos": b.pos, "vel": Vector2.ZERO, "on": b.on})
	return out


func sim_run(sb: Array, angle: float, pw: float) -> Dictionary:
	var cue: Dictionary = {}
	for b in sb:
		if b.n == 0:
			cue = b
	cue.vel = Vector2.from_angle(angle) * (150.0 + pow(pw, 1.5) * (MAXV - 150.0))
	var first := -1
	var pk_list: Array = []
	var cue_in := false
	var dt := 1.0 / 150.0
	var n := sb.size()
	for step in 150 * 6:
		var any := false
		for b in sb:
			if not b.on:
				continue
			var v: Vector2 = b.vel
			if v == Vector2.ZERO:
				continue
			any = true
			var p: Vector2 = b.pos + v * dt
			var sp := v.length()
			var ns := maxf(0.0, sp - (110.0 + sp * 0.32) * dt)
			if ns < 4.0:
				v = Vector2.ZERO
			else:
				v *= ns / sp
			var ch := cushion_hit(b, p, v, false)
			p = ch[0]
			v = ch[1]
			b.pos = p
			b.vel = v
			var caught := false
			for k in POCK.size():
				var dd: float = p.distance_to(POCK[k])
				var pr: float = PR_CORNER if k < 4 else PR_SIDE
				if dd < pr:
					caught = true
					break
			if not caught and (absf(p.x) > HW + 40.0 or absf(p.y) > HH + 40.0):
				caught = true
			if caught:
				b.on = false
				b.vel = Vector2.ZERO
				if b.n == 0:
					cue_in = true
				else:
					pk_list.append(b.n)
		if not any:
			break
		for i in n:
			var a: Dictionary = sb[i]
			if not a.on:
				continue
			for j in range(i + 1, n):
				var b: Dictionary = sb[j]
				if not b.on:
					continue
				if a.vel == Vector2.ZERO and b.vel == Vector2.ZERO:
					continue
				var d: Vector2 = b.pos - a.pos
				var d2 := d.length_squared()
				if d2 < 4.0 * R * R and d2 > 0.0001:
					var dist := sqrt(d2)
					var nrm := d / dist
					var ov := 2.0 * R - dist
					a.pos -= nrm * ov * 0.5
					b.pos += nrm * ov * 0.5
					var vn: float = (b.vel - a.vel).dot(nrm)
					if vn < 0.0:
						var jj := -(1.0 + 0.96) * vn / 2.0
						a.vel -= nrm * jj
						b.vel += nrm * jj
						if first == -1:
							if a.n == 0:
								first = b.n
							elif b.n == 0:
								first = a.n
	return {"pocketed": pk_list, "cue_in": cue_in, "first": first}


func eval_outcome(res: Dictionary, sb: Array) -> float:
	var g: int = groups[turn]
	var need_black := g != -1 and remaining(g) == 0
	var own := 0
	var opp := 0
	var black_in := false
	var g_after := g
	for n in res.pocketed:
		if n == BLACK:
			black_in = true
		elif g == -1:
			own += 1
			if g_after == -1:
				g_after = group_of(n)
		elif group_of(n) == g:
			own += 1
		else:
			opp += 1
	var fh: int = res.first
	var foul := false
	if res.cue_in or fh == -1:
		foul = true
	elif g == -1:
		if fh == BLACK:
			foul = true
	elif need_black:
		if fh != BLACK:
			foul = true
	elif group_of(fh) != g:
		foul = true
	if black_in:
		if need_black and not foul:
			return 20000.0
		return -20000.0
	if foul:
		return -1100.0 - (300.0 if res.cue_in else 0.0) - opp * 100.0
	var score := own * 380.0 - opp * 200.0
	var cue_pos := Vector2.ZERO
	for b in sb:
		if b.n == 0 and b.on:
			cue_pos = b.pos
	if own > 0:
		var nxt := best_shot_on(sb, cue_pos, g_after)
		score += clampf(700.0 - float(nxt.score) * 0.4, 0.0, 450.0)
	else:
		var og := (1 - g_after) if g_after != -1 else -1
		var nxt2 := best_shot_on(sb, cue_pos, og)
		score -= clampf(700.0 - float(nxt2.score) * 0.4, 0.0, 450.0) * 0.8
	return score


func hard_prepare() -> void:
	var g: int = groups[turn]
	var cue := get_ball(0)
	var cands := candidates_on(balls, cue.pos, g)
	hard_cands = []
	var top := mini(cands.size(), 6)
	for i in top:
		var c: Dictionary = cands[i]
		hard_cands.append({"angle": c.angle, "power": c.power})
		if i < 3:
			hard_cands.append({"angle": c.angle, "power": minf(1.0, c.power + 0.22)})
			hard_cands.append({"angle": c.angle, "power": maxf(0.25, c.power - 0.12)})
	var tgs := targets_on(balls, g)
	tgs.sort_custom(func(x, y): return x.pos.distance_to(cue.pos) < y.pos.distance_to(cue.pos))
	for i in mini(tgs.size(), 2):
		var tb: Dictionary = tgs[i]
		hard_cands.append({"angle": (tb.pos - cue.pos).angle(), "power": 0.3})
	hard_best = {"score": -1e9, "angle": 0.0, "power": 0.5}
	hard_i = 0


func hard_eval_one() -> void:
	var cand: Dictionary = hard_cands[hard_i]
	hard_i += 1
	var sb := sim_copy()
	var res := sim_run(sb, cand.angle, cand.power)
	var sc := eval_outcome(res, sb)
	if sc > hard_best.score:
		hard_best = {"score": sc, "angle": cand.angle, "power": cand.power}


func cur_diff() -> int:
	if bot and duel and turn == 0:
		return 1
	return diff


func ai_update() -> void:
	if mode == Mode.TRAIN or not cur_ai() or paused:
		return
	ai_t += DT
	var diff := cur_diff()
	match ai_phase:
		0:
			if ai_t > 0.5:
				var cue := get_ball(0)
				if break_shot:
					ai_plan = {"angle": randfn(0.0, 0.02), "power": 0.97 if diff < 2 else 1.0}
					ai_phase = 1
					ai_t = 0.0
					return
				if ball_in_hand:
					var bp: Vector2 = cue.pos
					var bs := 1e9
					var tries := 160 if diff == 2 else 60
					for k in tries:
						var p := Vector2(randf_range(-HW + 2 * R, HW - 2 * R), randf_range(-HH + 2 * R, HH - 2 * R))
						if not free_spot(p, 0):
							continue
						var s := best_shot(p)
						if s.score < bs:
							bs = s.score
							bp = p
					cue.pos = bp
					ball_in_hand = false
				if diff == 2:
					hard_prepare()
					ai_phase = 3
				else:
					ai_plan = best_shot(cue.pos)
					var noise: float = [0.05, 0.02][diff]
					ai_plan.angle += randfn(0.0, noise)
					ai_plan.power = clampf(ai_plan.power + randfn(0.0, 0.03 + 0.03 * (1 - diff)), 0.2, 1.0)
					if diff == 0 and randf() < 0.2:
						ai_plan.angle += randfn(0.0, 0.2)
					ai_phase = 1
				ai_t = 0.0
		3:
			if eval_budget > 0:
				eval_budget -= 1
				if hard_i < hard_cands.size():
					hard_eval_one()
				if hard_i >= hard_cands.size():
					if hard_cands.is_empty():
						ai_plan = best_shot(get_ball(0).pos)
					else:
						ai_plan = {
							"angle": hard_best.angle + randfn(0.0, 0.0025),
							"power": clampf(hard_best.power + randfn(0.0, 0.012), 0.2, 1.0),
						}
					ai_phase = 1
					ai_t = 0.0
		1:
			var df := angle_difference(aim_angle, ai_plan.angle)
			var step := 2.2 * DT
			if absf(df) <= step:
				aim_angle = ai_plan.angle
				if ai_t > 0.35:
					ai_phase = 2
					ai_t = 0.0
			else:
				aim_angle += signf(df) * step
		2:
			power = minf(ai_plan.power, ai_t * 1.5)
			if power >= ai_plan.power:
				shoot(power)


# ---------------------------------------------------------------- entrada
func _input(e) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			touch_down(e.index, e.position)
		else:
			touch_up(e.index, e.position)
	elif e is InputEventScreenDrag:
		touch_move(e.index, e.position)


func bar_rect() -> Rect2:
	return Rect2(vw - 90.0, 150.0, 56.0, 450.0)


func spin_center() -> Vector2:
	return Vector2(vw - 62.0, 76.0)


func dial_center() -> Vector2:
	return Vector2(vw - 62.0, 662.0)


func pause_rect() -> Rect2:
	return Rect2(8, 8, 60, 60)


func human_turn() -> bool:
	if mode == Mode.ONLINE and shooter() != net_seat:
		return false
	return st == St.AIM and not paused and not (mode != Mode.TRAIN and cur_ai())


func touch_down(i: int, p: Vector2) -> void:
	if st == St.MENU or st == St.OVER or paused:
		return
	if pause_rect().has_point(p):
		paused = mode != Mode.ONLINE
		touches.clear()
		ui.show_screen("pause")
		return
	if not human_turn():
		return
	if p.distance_to(spin_center()) < 56.0:
		touches[i] = {"m": "spin"}
		touch_move(i, p)
		return
	if p.distance_to(dial_center()) < 55.0:
		touches[i] = {"m": "dial", "last": (p - dial_center()).angle()}
		return
	if bar_rect().grow(20).has_point(p):
		touches[i] = {"m": "power"}
		touch_move(i, p)
		return
	var lp := to_local(p)
	var cue := get_ball(0)
	if ball_in_hand and lp.distance_to(cue.pos) < 75.0:
		touches[i] = {"m": "place"}
	else:
		touches[i] = {"m": "aim", "last": lp}


func touch_move(i: int, p: Vector2) -> void:
	if not touches.has(i) or not human_turn():
		return
	var t: Dictionary = touches[i]
	var cue := get_ball(0)
	var lp := to_local(p)
	if t.m == "power":
		var br := bar_rect()
		power = clampf((p.y - br.position.y) / br.size.y, 0.0, 1.0)
	elif t.m == "place":
		cue.pos = Vector2(clampf(lp.x, -HW + R, HW - R), clampf(lp.y, -HH + R, HH - R))
	elif t.m == "spin":
		var sd := (p - spin_center()) / 32.0
		if sd.length() > 1.0:
			sd = sd.normalized()
		spin = sd
	elif t.m == "dial":
		var a: float = (p - dial_center()).angle()
		var da: float = angle_difference(t.last, a)
		aim_angle += da * 0.1 * (1.0 - 0.07 * float(int(cue_def().prec) - 1))
		dial_rot += da
		t.last = a
	elif t.m == "aim":
		var old: Vector2 = t.last - cue.pos
		var cur: Vector2 = lp - cue.pos
		if old.length() > 20.0 and cur.length() > 20.0:
			var da := old.angle_to(cur)
			aim_angle += da * clampf(cur.length() / 200.0, 0.12, 1.0) * 0.55 * (1.0 - 0.06 * float(int(cue_def().prec) - 1))
		t.last = lp


func touch_up(i: int, _p: Vector2) -> void:
	if not touches.has(i):
		return
	var t: Dictionary = touches[i]
	touches.erase(i)
	if not human_turn():
		return
	var cue := get_ball(0)
	if t.m == "power":
		if power > 0.06:
			shoot(power)
		else:
			power = 0.0
	elif t.m == "place":
		var p: Vector2 = cue.pos
		for o in balls:
			if o.on and o.n != 0:
				var d: Vector2 = p - o.pos
				if d.length() < 2.0 * R + 1.0:
					p = o.pos + (d.normalized() if d.length() > 0.01 else Vector2.RIGHT) * (2.0 * R + 2.0)
		cue.pos = Vector2(clampf(p.x, -HW + R, HW - R), clampf(p.y, -HH + R, HH - R))


# ---------------------------------------------------------------- loop
func update_visuals(delta: float) -> void:
	for i in range(impacts.size() - 1, -1, -1):
		var f: Dictionary = impacts[i]
		f.t += delta
		f.p += f.v * delta
		f.v *= 1.0 - 2.2 * delta
		if f.t >= f.life:
			impacts.remove_at(i)
	for b in balls:
		var spr: Sprite2D = b.spr
		var m: ShaderMaterial = spr.material
		var bs: Basis = b.basis
		m.set_shader_parameter("rx", bs.x)
		m.set_shader_parameter("ry", bs.y)
		m.set_shader_parameter("rz", bs.z)
		if b.on:
			spr.visible = true
			var ex: Vector2 = Vector2.ZERO
			if (st == St.ROLL or st == St.MENU) and not paused:
				ex = (b.vel as Vector2) * acc
			spr.position = (b.pos as Vector2) + ex
			spr.scale = Vector2.ONE * (2.0 * R * PAD / 64.0)
			spr.modulate = Color.WHITE
		elif b.drop >= 0.0:
			b.drop += delta
			var k := clampf(b.drop / 0.22, 0.0, 1.0)
			spr.visible = k < 1.0
			spr.position = b.pos.lerp(b.dpos, k)
			spr.scale = Vector2.ONE * (2.0 * R * PAD / 64.0) * (1.0 - k * 0.7)
			spr.modulate = Color(1.0 - k * 0.6, 1.0 - k * 0.6, 1.0 - k * 0.6, 1.0 - k)
		else:
			spr.visible = false


func _process(delta: float) -> void:
	vw = get_viewport_rect().size.x
	var s := minf(1.0, (vw - 130.0) / 1100.0)
	scale = Vector2(s, s)
	position = Vector2(vw / 2.0 if st == St.MENU else (vw - 110.0) / 2.0, 390.0)
	if bot:
		for k in 960:
			eval_budget = 1 if k % 120 == 0 else eval_budget
			phys_step()
		for b in balls:
			if b.on and (absf(b.pos.x) > HW + 1.0 or absf(b.pos.y) > HH + 1.0):
				print("ESCAPOU: ", b.n, " ", b.pos)
		if st == St.OVER or bot_shots > 120:
			var rest := []
			for b in balls:
				if b.on and b.n != 0:
					rest.append(b.n)
			print("FIM bot: vencedor=", winner, " tacadas=", bot_shots, " sobraram=", rest, " grupos=", groups)
			get_tree().quit()
		return
	eval_budget = 1
	if _save_soon and st == St.AIM:
		_save_soon = false
		save_match()
	net_tick(delta)
	fx_t += delta
	music_update(delta)
	if not paused:
		acc += minf(delta, 0.025 if st == St.MENU else 0.05)
		while acc >= DT:
			phys_step()
			acc -= DT
	update_visuals(delta)
	update_cue()
	overlay.queue_redraw()
	hud.queue_redraw()


# ---------------------------------------------------------------- desenho
func ray_hit(origin: Vector2, dir: Vector2) -> Dictionary:
	var best_t := 1e9
	var hit: Variant = null
	for b in balls:
		if b.on and b.n != 0:
			var oc: Vector2 = origin - b.pos
			var bq := oc.dot(dir)
			var c := oc.dot(oc) - 4.0 * R * R
			var disc := bq * bq - c
			if disc >= 0.0:
				var t := -bq - sqrt(disc)
				if t > 0.0 and t < best_t:
					best_t = t
					hit = b
	var tw := 1e9
	if dir.x > 0.001:
		tw = minf(tw, (HW - R - origin.x) / dir.x)
	elif dir.x < -0.001:
		tw = minf(tw, (-HW + R - origin.x) / dir.x)
	if dir.y > 0.001:
		tw = minf(tw, (HH - R - origin.y) / dir.y)
	elif dir.y < -0.001:
		tw = minf(tw, (-HH + R - origin.y) / dir.y)
	if best_t <= tw:
		return {"t": best_t, "ball": hit}
	return {"t": tw, "ball": null}


func cushion(a: Vector2, b: Vector2, nrm: Vector2, ea: float = 12.0, eb: float = 12.0) -> void:
	var d := (b - a).normalized()
	var pts := PackedVector2Array([a, b, b + nrm * 27.0 + d * eb, a + nrm * 27.0 - d * ea])
	var f := felt_def()
	var base: Color = f.dark.lerp(f.light, 0.2).darkened(0.1)
	rails.draw_line(a - nrm * 3.0, b - nrm * 3.0, Color(0, 0, 0, 0.28), 8.0)
	rails.draw_colored_polygon(pts, base)
	var pts2 := PackedVector2Array([a, b, b + nrm * 9.0 + d * eb * 0.25, a + nrm * 9.0 - d * ea * 0.25])
	rails.draw_colored_polygon(pts2, base.lightened(0.18))
	rails.draw_line(a, b, base.lightened(0.45), 2.0)


func _draw_rails() -> void:
	for sy in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var n1 := Vector2(sx * (HW - 26.0), sy * HH)
			var n2 := Vector2(sx * HW, sy * (HH - 26.0))
			var b1 := n1 + Vector2(sx * -19.0 * -1.0, sy * 27.0)
			var b2 := n2 + Vector2(sx * 27.0, sy * 19.0)
			rails.draw_colored_polygon(PackedVector2Array([n1, b1, b2, n2]), Color(0.0, 0.0, 0.0, 0.55))
		rails.draw_colored_polygon(PackedVector2Array([Vector2(-21, sy * HH), Vector2(-19, sy * (HH + 27.0)), Vector2(19, sy * (HH + 27.0)), Vector2(21, sy * HH)]), Color(0.0, 0.0, 0.0, 0.55))
	cushion(Vector2(-HW + 26, -HH), Vector2(-21, -HH), Vector2(0, -1), 19.0, 2.0)
	cushion(Vector2(21, -HH), Vector2(HW - 26, -HH), Vector2(0, -1), 2.0, 19.0)
	cushion(Vector2(-HW + 26, HH), Vector2(-21, HH), Vector2(0, 1), 19.0, 2.0)
	cushion(Vector2(21, HH), Vector2(HW - 26, HH), Vector2(0, 1), 2.0, 19.0)
	cushion(Vector2(-HW, -HH + 26), Vector2(-HW, HH - 26), Vector2(-1, 0), 19.0, 19.0)
	cushion(Vector2(HW, -HH + 26), Vector2(HW, HH - 26), Vector2(1, 0), 19.0, 19.0)
	for i in [-3, -2, -1, 1, 2, 3]:
		for sy in [-1.0, 1.0]:
			_diamond(Vector2(i * 125.0, sy * 289.0))
	for i in [-1, 0, 1]:
		for sx in [-1.0, 1.0]:
			_diamond(Vector2(sx * 539.0, i * 125.0))
	rails.draw_line(Vector2(-250, -HH + 6), Vector2(-250, HH - 6), Color(1, 1, 1, 0.1), 1.5)
	rails.draw_arc(Vector2(-250, 0), 62.0, PI / 2.0, PI * 1.5, 40, Color(1, 1, 1, 0.1), 1.5)
	rails.draw_circle(Vector2(250, 0), 2.5, Color(1, 1, 1, 0.3))
	rails.draw_circle(Vector2(-250, 0), 2.5, Color(1, 1, 1, 0.3))
	for pi in POCK.size():
		var pk: Vector2 = POCK[pi]
		var rr := 25.0 if pi < 4 else 21.0
		rails.draw_circle(pk, rr + 2.0, Color("2a1c11"))
		rails.draw_circle(pk, rr, Color("0d0a08"))
		rails.draw_circle(pk, rr - 5.0, Color("050403"))
		rails.draw_circle(pk, rr - 11.0, Color("010101"))
		rails.draw_arc(pk, rr + 3.0, 0, TAU, 40, Color(1, 1, 1, 0.08), 1.5)


func _diamond(c: Vector2) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)])
	rails.draw_colored_polygon(pts, Color("efe8d6"))
	rails.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.35, 0.25, 0.1, 0.8), 1.2)


func quad(a: Vector2, b: Vector2, wa: float, wb: float, col: Color, off: Vector2 = Vector2.ZERO) -> void:
	var n := (b - a).orthogonal().normalized()
	var pts := PackedVector2Array([a + n * wa / 2.0 + off, b + n * wb / 2.0 + off, b - n * wb / 2.0 + off, a - n * wa / 2.0 + off])
	overlay.draw_colored_polygon(pts, col)


func _draw_overlay() -> void:
	_draw_edge_fx()
	if st == St.AIM and mode != Mode.TRAIN and human_turn() and groups[turn] != -1:
		# destaca as bolas que o jogador da vez pode acertar
		var pul := 0.5 + 0.5 * sin(sim_t * 5.0)
		for tb in target_balls():
			overlay.draw_arc(tb.pos, R + 4.0 + pul * 2.0, 0, TAU, 28, Color(1.0, 0.95, 0.4, 0.55 + 0.35 * pul), 2.5)
	for f in impacts:
		var k: float = f.t / f.life
		var col: Color = f.c
		col.a = 1.0 - k * k
		var pos: Vector2 = f.p
		overlay.draw_string_outline(font, pos + Vector2(-40, 0), f.txt, HORIZONTAL_ALIGNMENT_CENTER, 80, int(f.s), 5, Color(0, 0, 0, 0.5 * col.a))
		overlay.draw_string(font, pos + Vector2(-40, 0), f.txt, HORIZONTAL_ALIGNMENT_CENTER, 80, int(f.s), col)
	if st != St.AIM and st != St.STRIKE:
		return
	var cue := get_ball(0)
	if not cue.on:
		return
	var dir := Vector2.from_angle(aim_angle)
	if st == St.AIM:
		var h := ray_hit(cue.pos, dir)
		var endp: Vector2 = cue.pos + dir * float(h.t)
		overlay.draw_dashed_line(cue.pos + dir * R, endp, Color(1, 1, 1, 0.75), 2.0, 9.0)
		overlay.draw_arc(endp, R, 0, TAU, 28, Color(1, 1, 1, 0.9), 2.0)
		if h.ball != null:
			var tdir: Vector2 = (h.ball.pos - endp).normalized()
			# linha amarela do caminho da bola: proporcional à MIRA do taco (20% = curtinha, 100% = longa)
			# a mira mostrada é sempre a do taco de quem está jogando (igual para quem assiste)
			var ast := float(turn_cue_def().aim)
			overlay.draw_line(h.ball.pos, h.ball.pos + tdir * (34.0 * ast), Color("ffe066"), 2.5)
			var cd := dir - tdir * dir.dot(tdir)
			if cd.length() > 0.05:
				overlay.draw_line(endp, endp + cd.normalized() * (14.0 * ast), Color(1, 1, 1, 0.5), 2.0)
	if ball_in_hand:
		var pul := 0.5 + 0.5 * sin(sim_t * 6.0 * 1.0)
		overlay.draw_arc(cue.pos, R + 10.0 + pul * 6.0, 0, TAU, 32, Color(1.0, 0.88, 0.4, 0.9), 3.0)
		overlay.draw_arc(cue.pos, R + 22.0 + pul * 6.0, 0, TAU, 32, Color(1.0, 0.88, 0.4, 0.35), 2.0)


# mesa decorativa: faixa de luz colorida correndo pelas bordas (desviando das caçapas)
func _draw_edge_fx() -> void:
	if str(felt_def().get("edge", "")) != "rainbow":
		return
	var e := 7.0
	var segs := [
		[Vector2(-HW + 44, -HH + e), Vector2(-34, -HH + e)], [Vector2(34, -HH + e), Vector2(HW - 44, -HH + e)],
		[Vector2(HW - e, -HH + 44), Vector2(HW - e, HH - 44)],
		[Vector2(HW - 44, HH - e), Vector2(34, HH - e)], [Vector2(-34, HH - e), Vector2(-HW + 44, HH - e)],
		[Vector2(-HW + e, HH - 44), Vector2(-HW + e, -HH + 44)],
	]
	var dist := 0.0
	for sg in segs:
		var a0: Vector2 = sg[0]
		var a1: Vector2 = sg[1]
		var ln := a0.distance_to(a1)
		var n := int(ln / 12.0)
		for k in n:
			var p0 := a0.lerp(a1, float(k) / n)
			var p1 := a0.lerp(a1, float(k + 1) / n)
			var s := dist + ln * float(k) / n
			var hue := fposmod(s / 520.0 - fx_t * 0.22, 1.0)
			var pulse := 0.55 + 0.45 * sin(s * 0.035 - fx_t * 6.0)
			var c := Color.from_hsv(hue, 0.85, 1.0, 0.85 * pulse)
			overlay.draw_line(p0, p1, Color(c.r, c.g, c.b, 0.22 * pulse), 16.0)
			overlay.draw_line(p0, p1, Color(c.r, c.g, c.b, 0.4 * pulse), 8.0)
			overlay.draw_line(p0, p1, c.lightened(0.3), 3.5)
		dist += ln


func _draw_cue_fx(additive: bool) -> void:
	var kind: String = turn_cue_def().get("fx", "")
	if kind == "":
		return
	var sn := FxScript.Sink.new()
	var sa := FxScript.Sink.new()
	if additive:
		sa.t = cue_fx_a
	else:
		sn.t = cue_fx_n
	FxScript.draw(sn, sa, kind, fx_t, cue_s.rotation, 1.0)


func update_cue() -> void:
	var cue := get_ball(0)
	var show: bool = (st == St.AIM or st == St.STRIKE) and not cue.is_empty() and bool(cue.on)
	cue_s.visible = show
	cue_sh.visible = show
	var has_fx: bool = show and turn_cue_def().get("fx", "") != ""
	cue_fx_n.visible = has_fx
	cue_fx_a.visible = has_fx
	if not show:
		return
	var cs := turn_cue_def()
	if cue_applied != cs.id:
		cue_applied = cs.id
		var mythic: bool = cs.has("theme")
		var nm := ShaderMaterial.new()
		nm.shader = load("res://shaders/cue_mythic.gdshader") if mythic else load("res://shaders/cue.gdshader")
		cue_s.material = nm
		cue_s.scale = Vector2(560.0 / 64.0, (17.0 * (2.2 if mythic else 1.0)) / 64.0)
		if mythic:
			nm.set_shader_parameter("theme", int(cs.theme))
			nm.set_shader_parameter("glow", cs.glow)
			nm.set_shader_parameter("shaft", cs.shaft)
			nm.set_shader_parameter("ring", cs.ring)
			nm.set_shader_parameter("pad", 2.2)
			nm.set_shader_parameter("ulen", 560.0 / 8.5)
		for sp in ([] if mythic else [cue_s]):
			var m: ShaderMaterial = sp.material
			m.set_shader_parameter("shaft", cs.shaft)
			m.set_shader_parameter("butt", cs.butt)
			m.set_shader_parameter("accent", cs.accent)
			m.set_shader_parameter("ring", cs.ring)
			m.set_shader_parameter("wrap", cs.wrap)
			m.set_shader_parameter("pat", int(cs.pat))
			m.set_shader_parameter("shine", int(cs.get("shine", 0)))
			m.set_shader_parameter("butt2", cs.get("butt2", cs.butt))
	var dir := Vector2.from_angle(aim_angle)
	var pull := power * 130.0
	if st == St.STRIKE:
		var k := clampf(strike_t / strike_dur, 0.0, 1.0)
		pull = strike_pull * (1.0 - k * k)
	var tip: Vector2 = cue.pos - dir * (R + 4.0 + pull) + Vector2(-dir.y, dir.x) * spin.x * R * 0.6
	cue_s.position = tip
	cue_s.rotation = aim_angle + PI
	cue_sh.position = tip + Vector2(5, 9)
	cue_sh.rotation = aim_angle + PI
	if has_fx:
		var butt: Vector2 = tip + Vector2.from_angle(aim_angle + PI) * 560.0
		cue_fx_n.position = butt
		cue_fx_a.position = butt
		cue_fx_n.queue_redraw()
		cue_fx_a.queue_redraw()


func ctext(s: String, cx: float, y: float, size: int, col: Color) -> void:
	hud.draw_string_outline(font, Vector2(cx - 600.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, 1200, size, 6, Color(0, 0, 0, 0.7))
	hud.draw_string(font, Vector2(cx - 600.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, 1200, size, col)


func mini_ball(c: Vector2, n: int, alpha: float) -> void:
	var col: Color = BALL_COL[n if n <= 8 else n - 8]
	col.a = alpha
	var white := Color(0.96, 0.95, 0.9, alpha)
	if n > 8:
		hud.draw_circle(c, 10, white)
		hud.draw_rect(Rect2(c.x - 9, c.y - 4, 18, 8), col, true)
	else:
		hud.draw_circle(c, 10, col)
	hud.draw_arc(c, 10, 0, TAU, 20, Color(0, 0, 0, 0.5 * alpha), 1.5)
	hud.draw_circle(c + Vector2(-3, -3), 3, Color(1, 1, 1, 0.35 * alpha))


func _draw_hud() -> void:
	if st == St.MENU:
		return
	var cx := (vw - 110.0) / 2.0
	hud.draw_rect(pause_rect(), Color(0, 0, 0, 0.5), true)
	hud.draw_rect(pause_rect(), Color(1, 1, 1, 0.45), false, 2.0)
	hud.draw_rect(Rect2(26, 24, 8, 28), Color.WHITE, true)
	hud.draw_rect(Rect2(42, 24, 8, 28), Color.WHITE, true)
	if mode != Mode.TRAIN:
		for i in 2:
			var x := 90.0 + i * 430.0
			var active := i == turn and st != St.OVER
			var g: int = groups[i]
			hud.draw_rect(Rect2(x, 8, 410, 62), Color("ffe066") if active else Color(0, 0, 0, 0.5), true)
			hud.draw_rect(Rect2(x, 8, 410, 62), Color(1, 1, 1, 0.35), false, 2.0)
			var tc := Color("222222") if active else Color.WHITE
			if active:
				var pl := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
				hud.draw_rect(Rect2(x - 3, 5, 416, 68), Color(1, 0.55 + 0.3 * pl, 0.1, 0.9), false, 4.0)
				var lab := "PENSANDO..." if (mode == Mode.AI and ai[i]) else "◀ JOGANDO"
				if mode == Mode.ONLINE:
					lab = ("SUA VEZ" if shooter() == net_seat else ("PARCEIRO" if net4 else "")) if i == net_seat % 2 else ("ADVERSÁRIO" if not net4 else str(seat_names[shooter()]).left(10))
				elif mode != Mode.AI:
					lab = "SUA VEZ"
				hud.draw_string(font, Vector2(x + 210, 32), lab, HORIZONTAL_ALIGNMENT_RIGHT, 120, 13, Color("7a1a00"))
			else:
				hud.draw_rect(Rect2(x, 8, 410, 62), Color(0, 0, 0, 0.35), true)
			var pname: String = players[i]
			if mode == Mode.ONLINE and i == net_seat % 2:
				pname += "  (você)"
			hud.draw_string(font, Vector2(x + 12, 32), pname, HORIZONTAL_ALIGNMENT_LEFT, 380, 22, tc)
			if active and timer_active():
				var fr := clampf(turn_left / float(TURN_TIME), 0.0, 1.0)
				var tcol := Color("3ddc84") if fr > 0.5 else (Color("ffb020") if fr > 0.25 else Color("ff4040"))
				hud.draw_rect(Rect2(x, 70, 410, 8), Color(0, 0, 0, 0.55), true)
				hud.draw_rect(Rect2(x, 70, 410 * fr, 8), tcol, true)
				hud.draw_string(font, Vector2(x + 340, 32), "%ds" % int(ceil(turn_left)), HORIZONTAL_ALIGNMENT_RIGHT, 60, 26, Color("b00000") if fr <= 0.25 else tc)
			if g != -1:
				var gtxt := "LISAS (1-7)" if g == 0 else "LISTRADAS (9-15)"
				if remaining(g) == 0:
					gtxt = "AGORA É A 8!"
				var gcol := Color("1a4fb4") if g == 0 else Color("b8323a")
				if remaining(g) == 0:
					gcol = Color("111111")
				var gw := 150.0
				hud.draw_rect(Rect2(x + 410 - gw - 8, 40, gw, 24), gcol, true)
				hud.draw_rect(Rect2(x + 410 - gw - 8, 40, gw, 24), Color(1, 1, 1, 0.7), false, 1.5)
				hud.draw_string(font, Vector2(x + 410 - gw - 8, 58), gtxt, HORIZONTAL_ALIGNMENT_CENTER, gw, 15, Color.WHITE)
			if g == -1:
				hud.draw_string(font, Vector2(x + 12, 58), "mesa aberta • qualquer bola menos a 8", HORIZONTAL_ALIGNMENT_LEFT, 380, 16, tc)
			else:
				var lst: Array = [1, 2, 3, 4, 5, 6, 7] if g == 0 else [9, 10, 11, 12, 13, 14, 15]
				for k in lst.size():
					var bb := get_ball(lst[k])
					mini_ball(Vector2(x + 22 + k * 25, 52), lst[k], 1.0 if bb.on else 0.22)
				if remaining(g) == 0:
					mini_ball(Vector2(x + 22 + 7 * 25 + 8, 52), BLACK, 1.0)
	else:
		ctext("Treino livre", cx, 44, 28, Color.WHITE)
	if mode != Mode.TRAIN and st != St.OVER:
		var el := float(Time.get_ticks_msec() - banner_ms) / 1000.0
		if el >= 0.0 and el < 1.9:
			var al := clampf(minf(el * 5.0, (1.9 - el) * 2.5), 0.0, 1.0)
			var bw := 760.0
			hud.draw_rect(Rect2(cx - bw / 2.0, 150, bw, 84), Color(0, 0, 0, 0.62 * al), true)
			hud.draw_rect(Rect2(cx - bw / 2.0, 150, bw, 5), Color(1, 0.85, 0.2, al), true)
			hud.draw_rect(Rect2(cx - bw / 2.0, 229, bw, 5), Color(1, 0.85, 0.2, al), true)
			if mode == Mode.ONLINE:
				var vtxt := "SUA VEZ" if shooter() == net_seat else "VEZ DO ADVERSÁRIO"
				if net4 and shooter() != net_seat:
					vtxt = ("VEZ DO PARCEIRO: " if shooter() % 2 == net_seat % 2 else "VEZ DE ") + str(seat_names[shooter()]).to_upper()
				ctext(vtxt, cx, 210, 44 if net4 else 54, Color(1, 0.9, 0.35, al))
			elif cur_ai() or (net4 and bot_seats.has(shooter())):
				ctext("VEZ DA IA GOSCRIPTS", cx, 210, 54, Color(1, 0.9, 0.35, al))
			elif mode == Mode.TWO:
				ctext("SUA VEZ", cx, 196, 50, Color(1, 0.9, 0.35, al))
				ctext(String(players[turn]), cx, 224, 22, Color(1, 1, 1, al))
			else:
				ctext("SUA VEZ", cx, 210, 54, Color(1, 0.9, 0.35, al))
	if msg_t > 0.0 and st != St.OVER:
		ctext(msg, cx, 108, 30, Color("ffe066"))
	if human_turn():
		var br := bar_rect()
		hud.draw_rect(br.grow(5), Color(0, 0, 0, 0.55), true)
		hud.draw_rect(br, Color(0.08, 0.1, 0.12, 0.9), true)
		var fh := br.size.y * power
		hud.draw_rect(Rect2(br.position.x, br.position.y, br.size.x, fh), Color(1.0, 0.85 - 0.6 * power, 0.15), true)
		for k in range(1, 10):
			hud.draw_line(Vector2(br.position.x, br.position.y + br.size.y * k / 10.0), Vector2(br.position.x + 14, br.position.y + br.size.y * k / 10.0), Color(1, 1, 1, 0.5), 2.0)
		hud.draw_rect(br, Color.WHITE, false, 3.0)
		hud.draw_string(font, Vector2(br.position.x - 20, br.position.y - 14), "FORÇA", HORIZONTAL_ALIGNMENT_CENTER, br.size.x + 40, 20, Color.WHITE)
		hud.draw_string(font, Vector2(br.position.x - 20, br.end.y + 18), "puxe e solte", HORIZONTAL_ALIGNMENT_CENTER, br.size.x + 40, 14, Color(1, 1, 1, 0.7))
		var dc := dial_center()
		hud.draw_circle(dc + Vector2(0, 3), 36, Color(0, 0, 0, 0.35))
		hud.draw_circle(dc, 34, Color(0.08, 0.1, 0.12, 0.92))
		for k in 12:
			var ang := dial_rot + k * TAU / 12.0
			hud.draw_line(dc + Vector2.from_angle(ang) * 24.0, dc + Vector2.from_angle(ang) * 32.0, Color(1, 1, 1, 0.8 if k == 0 else 0.45), 3.0 if k == 0 else 2.0)
		hud.draw_circle(dc, 9, Color("ffe066"))
		hud.draw_arc(dc, 34, 0, TAU, 40, Color.WHITE, 2.5)
		hud.draw_string(font, Vector2(dc.x - 40, dc.y + 54), "AJUSTE FINO", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1, 1, 1, 0.75))
		var sc := spin_center()
		hud.draw_circle(sc + Vector2(0, 3), 40, Color(0, 0, 0, 0.4))
		hud.draw_circle(sc, 38, Color("f2f2ec"))
		hud.draw_circle(sc + Vector2(-8, -10), 26, Color(1, 1, 1, 0.55))
		hud.draw_arc(sc, 38, 0, TAU, 48, Color(0.1, 0.1, 0.1, 0.9), 3.0)
		hud.draw_line(sc + Vector2(-34, 0), sc + Vector2(34, 0), Color(0, 0, 0, 0.22), 1.5)
		hud.draw_line(sc + Vector2(0, -34), sc + Vector2(0, 34), Color(0, 0, 0, 0.22), 1.5)
		hud.draw_arc(sc, 20, 0, TAU, 32, Color(0, 0, 0, 0.15), 1.5)
		var sdot := sc + spin * 32.0
		hud.draw_circle(sdot, 8, Color("d4202a"))
		hud.draw_arc(sdot, 8, 0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
		hud.draw_string(font, Vector2(sc.x - 50, 20), "EFEITO", HORIZONTAL_ALIGNMENT_CENTER, 100, 16, Color(1, 1, 1, 0.85))
		if ball_in_hand:
			ctext("BOLA NA MÃO: arraste a bola branca para onde quiser", cx, 690, 26, Color("ffe066"))
		else:
			hud.draw_string(font, Vector2(20, 706), "Arraste na mesa para mirar  •  EFEITO: toque na bola branca (canto superior)", HORIZONTAL_ALIGNMENT_LEFT, 900, 18, Color(1, 1, 1, 0.6))
