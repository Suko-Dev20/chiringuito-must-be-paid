extends Node
## Estado global del juego (Autoload: GameState)
## Incluye Store Global, Guardado/Carga, Audio Procedural + Radio Cassette Chiptune (Issue #31), Mercado, Logros y Estadísticas.

signal currencies_updated
signal stamina_changed(current: float, maximum: float)
signal day_changed(current_day: int, bill_due_day: int)
signal achievement_unlocked(title: String, desc: String)

const SAVE_PATH: String = "user://savegame.json"

# --- Opciones de Audio, Radio Cassette y Pantalla (Issue #20 & #31) ---
var master_volume_pct: int = 100
var is_fullscreen: bool = false
var radio_station: int = 1 # 0 = Apagada, 1 = Chiringuito FM, 2 = Costa Tropical, 3 = Olas Chill

# --- Pool de Audio Procedural y Reproductor de Radio (Issue #8 & #31) ---
var sfx_streams: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var radio_streams: Dictionary = {}
var music_player: AudioStreamPlayer = null

# --- Ciclo y Facturas del Chiringuito ---
var current_day: int = 1
var days_per_bill: int = 3
var current_bill_index: int = 0

var bills: Array[Dictionary] = [
	{"title": "2 Cañas y unas Aceitunas", "amount": 25.0},
	{"title": "Ración de Calamares y Tinto de Verano", "amount": 120.0},
	{"title": "Hidropedal y Helados para los niños", "amount": 600.0},
	{"title": "Paella de Marisco para el Cuñado y Sangría", "amount": 3000.0}
]

# --- Divisas de Turistas y Bolsa Diaria (Issue #18) ---
var currencies: Dictionary = {
	"EUR": 0.0,
	"USD": 0.0,
	"GBP": 0.0,
	"PEN": 0.0
}

var base_exchange_rates: Dictionary = {
	"USD": 0.85,
	"GBP": 1.15,
	"PEN": 0.25
}

var market_multipliers: Dictionary = {
	"USD": 1.0,
	"GBP": 1.25,
	"PEN": 0.90
}

# --- Prestigio Permanente: Conchas Doradas (Issue #6) ---
var golden_shells: int = 0

var prestige_upgrades: Dictionary = {
	"sunscreen_stamina": 0,
	"starting_euros": 0,
	"permanent_damage": 0,
	"waiter_discount": 0
}

var prestige_catalog: Array[Dictionary] = [
	{"id": "sunscreen_stamina", "title": "🧴 Crema Solar Factor 50", "desc": "+20 Stamina máxima PERMANENTE en todos los veraneos", "base_cost": 1, "cost_step": 1, "max_lvl": 10},
	{"id": "starting_euros", "title": "💶 Paga de los Abuelos", "desc": "Empiezas cada nuevo veraneo con +15 € en la cartera", "base_cost": 1, "cost_step": 1, "max_lvl": 10},
	{"id": "permanent_damage", "title": "💪 Brazo de Socorrista", "desc": "+25% Multiplicador de Daño PERMANENTE con Pala y Cubo", "base_cost": 2, "cost_step": 1, "max_lvl": 8},
	{"id": "waiter_discount", "title": "🍹 Amigo del Camarero", "desc": "-10% de descuento PERMANENTE en todas las cuentas del Chiringuito", "base_cost": 2, "cost_step": 2, "max_lvl": 5}
]

# --- Sistema de Logros: Postales de Veraneo y Estadísticas Globales (Issue #25 & #27) ---
var unlocked_achievements: Dictionary = {}

var lifetime_stats: Dictionary = {
	"total_crabs_caught": 0,
	"total_eur_earned": 0.0,
	"total_bills_paid": 0,
	"max_day_reached": 1,
	"best_combo": 1
}

var achievement_catalog: Array[Dictionary] = [
	{"id": "first_catch", "title": "🦀 ¡Primer Cacho!", "desc": "Atrapa tu primer bicho marino en la orilla."},
	{"id": "combo_master", "title": "💥 ¡Golpe Maestro!", "desc": "Consigue un Combo x3 o superior en un solo golpe."},
	{"id": "octopus_hunter", "title": "🐙 Pulpo a la Gallega", "desc": "Atrapa a un Pulpo Turista en la playa."},
	{"id": "golden_lobster", "title": "🦞 El Dorado del Mar", "desc": "Atrapa una escurridiza Langosta Dorada antes de que escape."},
	{"id": "wall_beach_wolf", "title": "📈 Lobo de Wall Beach", "desc": "Vende una divisa extranjera cuando esté en fuerte ALZA (+20% o más)."},
	{"id": "first_bill_paid", "title": "🍹 Cliente de Confianza", "desc": "Paga tu primera comanda del Chiringuito a tiempo."},
	{"id": "ice_cream_lover", "title": "🍦 Fiebre del Helado", "desc": "Ten al menos 3 tipos distintos de Helados activos en tu Nevera."},
	{"id": "beach_automation", "title": "🤖 Vacaciones de Verdad", "desc": "Desbloquea al Sobrino, la Gaviota y la Nasa en la misma partida."}
]

# --- Niveles del Árbol de Habilidades (Por Run) ---
var upgrades: Dictionary = {
	"shovel_damage": 0,
	"shovel_radius": 0,
	"crit_chance": 0,
	"multi_hit_bonus": 0,
	"unlock_bucket": 0,
	"rake_magnet": 0,
	"crab_spawn_rate": 0,
	"unlock_tractor": 0,
	"tractor_cooldown": 0,
	"auto_nephew": 0,
	"auto_seagull": 0,
	"crab_trap": 0,
	"max_stamina": 0,
	"global_luck": 0,
	"ice_cream_foot": 0,
	"ice_cream_rocket": 0,
	"ice_cream_vampire": 0,
	"ice_cream_magnum": 0,
	"ice_cream_shark": 0,
	"tourist_currencies": 0,
	"exchange_rate_boost": 0
}

var upgrade_catalog: Array[Dictionary] = [
	# Rama 1: Herramientas y Críticos (branch = 0)
	{"id": "shovel_damage", "branch": 0, "title": "🏖️ Pala Reforzada", "desc": "+5 Daño base con la pala", "base_cost": 8.0, "cost_mult": 1.5, "max_lvl": 10, "req": ""},
	{"id": "shovel_radius", "branch": 0, "title": "⭕ Pala Ancha", "desc": "+8 px de radio de golpe", "base_cost": 12.0, "cost_mult": 1.6, "max_lvl": 6, "req": "shovel_damage"},
	{"id": "crit_chance", "branch": 0, "title": "⚡ Filo Playero (Crítico)", "desc": "+5% Probabilidad de Crítico (x2)", "base_cost": 15.0, "cost_mult": 1.6, "max_lvl": 8, "req": "shovel_damage"},
	{"id": "multi_hit_bonus", "branch": 0, "title": "💥 Golpe en Manada", "desc": "+25% Daño extra por cada cangrejo adicional en el mismo golpe", "base_cost": 22.0, "cost_mult": 1.7, "max_lvl": 5, "req": "crit_chance"},
	{"id": "unlock_bucket", "branch": 0, "title": "🪣 Cubo Pesado (Clic Der)", "desc": "Desbloquea/mejora el Cubazo en área (+Daño y -Cooldown)", "base_cost": 18.0, "cost_mult": 1.7, "max_lvl": 5, "req": "shovel_radius"},
	{"id": "rake_magnet", "branch": 0, "title": "🧹 Rastrillo Imantado", "desc": "+22 px de radio para recoger monedas al mover el ratón", "base_cost": 10.0, "cost_mult": 1.5, "max_lvl": 6, "req": ""},

	# Rama 2: Playa, Tractor y Automatización Playera (branch = 1)
	{"id": "crab_spawn_rate", "branch": 1, "title": "🦀 Cebo Playero", "desc": "Aparecen más bichos marinos y más rápido en la orilla", "base_cost": 10.0, "cost_mult": 1.5, "max_lvl": 8, "req": ""},
	{"id": "auto_nephew", "branch": 1, "title": "👦 Sobrino con Cubo (Auto)", "desc": "Persigue bichos por la arena y los golpea solo SIN gastar tu Stamina", "base_cost": 18.0, "cost_mult": 1.65, "max_lvl": 5, "req": "crab_spawn_rate"},
	{"id": "auto_seagull", "branch": 1, "title": "🐦 Gaviota Amaestrada (Auto)", "desc": "Vuela hacia las monedas sueltas (salvándolas de la ola) y las recoge", "base_cost": 20.0, "cost_mult": 1.65, "max_lvl": 5, "req": "crab_spawn_rate"},
	{"id": "crab_trap", "branch": 1, "title": "🕸️ Nasa de Cangrejos (Auto)", "desc": "Coloca redes en la orilla que ralentizan un 50% y dañan por segundo", "base_cost": 24.0, "cost_mult": 1.7, "max_lvl": 5, "req": "auto_nephew"},
	{"id": "unlock_tractor", "branch": 1, "title": "🚜 Tractor Limpia-Playas", "desc": "Mejora el Tractor [ESPACIO] y su velocidad de barrido", "base_cost": 25.0, "cost_mult": 1.8, "max_lvl": 5, "req": "crab_spawn_rate"},
	{"id": "tractor_cooldown", "branch": 1, "title": "⛽ Motor Turbo Tractor", "desc": "-1.8s al tiempo de recarga del Tractor", "base_cost": 30.0, "cost_mult": 1.7, "max_lvl": 5, "req": "unlock_tractor"},

	# Rama 3: Kiosco de Helados y Resistencia (branch = 2)
	{"id": "max_stamina", "branch": 2, "title": "⛱️ Sombrilla y Crema", "desc": "+25 Stamina máxima para aguantar más al sol", "base_cost": 10.0, "cost_mult": 1.45, "max_lvl": 10, "req": ""},
	{"id": "global_luck", "branch": 2, "title": "🍀 Pulsera de la Suerte", "desc": "+20% a la probabilidad de activación de TODOS tus Helados", "base_cost": 14.0, "cost_mult": 1.6, "max_lvl": 6, "req": "max_stamina"},
	{"id": "ice_cream_foot", "branch": 2, "title": "🦶 Helado: Pie Helado", "desc": "Prob. al atrapar bicho de refrescarte (+7 Stamina)", "base_cost": 15.0, "cost_mult": 1.6, "max_lvl": 5, "req": "max_stamina"},
	{"id": "ice_cream_rocket", "branch": 2, "title": "🚀 Helado: Cohete Tricolor", "desc": "Prob. al golpear de lanzar onda expansiva (+60% radio)", "base_cost": 22.0, "cost_mult": 1.7, "max_lvl": 5, "req": "ice_cream_foot"},
	{"id": "ice_cream_vampire", "branch": 2, "title": "🧛 Helado: Conde Colmillos", "desc": "Prob. en Golpe Crítico de robar +5 Stamina y duplicar monedas", "base_cost": 26.0, "cost_mult": 1.75, "max_lvl": 5, "req": "ice_cream_foot"},
	{"id": "ice_cream_magnum", "branch": 2, "title": "🍫 Helado: Bombón Magnético", "desc": "Prob. cada segundo de absorber una moneda sola con valor DOBLE", "base_cost": 28.0, "cost_mult": 1.75, "max_lvl": 5, "req": "global_luck"},
	{"id": "ice_cream_shark", "branch": 2, "title": "🦈 Helado: Tiburón Azul", "desc": "Prob. al golpear de reducir -2.5s la recarga del Tractor", "base_cost": 30.0, "cost_mult": 1.75, "max_lvl": 5, "req": "ice_cream_rocket"},

	# Rama 4: Turismo y Divisas (branch = 3)
	{"id": "tourist_currencies", "branch": 3, "title": "✈️ Playa Internacional", "desc": "Los bichos sueltan más monedas por captura y divisas valiosas", "base_cost": 14.0, "cost_mult": 1.6, "max_lvl": 6, "req": ""},
	{"id": "exchange_rate_boost", "branch": 3, "title": "💱 Caseta Sin Comisiones", "desc": "+15% al valor en Euros (€) al cambiar USD, GBP y PEN", "base_cost": 20.0, "cost_mult": 1.65, "max_lvl": 6, "req": "tourist_currencies"}
]

func _ready() -> void:
	_init_procedural_audio()
	if not load_game():
		roll_daily_market()
	_update_radio_playback()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		elif event.keycode == KEY_R:
			cycle_radio_station()
			var current_scene: Node = get_tree().current_scene
			if current_scene and current_scene.has_method("queue_redraw"):
				current_scene.queue_redraw()
		elif event.keycode == KEY_ESCAPE:
			var current_scene: Node = get_tree().current_scene
			if current_scene and current_scene.name != "MainMenu":
				save_game()
				get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

# --- Radio Cassette Playera: Emisoras Chiptune Procedurales (Issue #31) ---

func get_radio_station_name() -> String:
	match radio_station:
		1: return "📻 Chiringuito FM"
		2: return "🌴 Costa Tropical"
		3: return "🌊 Olas Chill"
		_: return "🔇 Radio OFF"

func cycle_radio_station() -> void:
	radio_station = (radio_station + 1) % 4
	play_sfx("buy", 1.1, 1.3)
	_update_radio_playback()
	save_game()

func _update_radio_playback() -> void:
	if not music_player:
		return
	if master_volume_pct <= 0 or radio_station <= 0 or not radio_streams.has(radio_station):
		music_player.stop()
		return
	var target_stream: AudioStreamWAV = radio_streams[radio_station]
	if music_player.stream != target_stream or not music_player.playing:
		music_player.stream = target_stream
		music_player.play()

# --- Sistema de Logros y Estadísticas Globales (Issue #25 & #27) ---

func record_catch() -> void:
	lifetime_stats["total_crabs_caught"] = int(lifetime_stats.get("total_crabs_caught", 0)) + 1

func record_combo(combo_size: int) -> void:
	if combo_size > int(lifetime_stats.get("best_combo", 1)):
		lifetime_stats["best_combo"] = combo_size

func record_day_reached(day_num: int) -> void:
	if day_num > int(lifetime_stats.get("max_day_reached", 1)):
		lifetime_stats["max_day_reached"] = day_num

func unlock_achievement(id: String) -> bool:
	if unlocked_achievements.get(id, false):
		return false
	for item in achievement_catalog:
		if item["id"] == id:
			unlocked_achievements[id] = true
			golden_shells += 1
			play_sfx("crit", 1.12, 1.32)
			save_game()
			achievement_unlocked.emit(item["title"], item["desc"])
			return true
	return false

func get_unlocked_achievements_count() -> int:
	return unlocked_achievements.size()

func _check_upgrade_achievements() -> void:
	var ice_types: int = 0
	for k in ["ice_cream_foot", "ice_cream_rocket", "ice_cream_vampire", "ice_cream_magnum", "ice_cream_shark"]:
		if upgrades.get(k, 0) > 0:
			ice_types += 1
	if ice_types >= 3:
		unlock_achievement("ice_cream_lover")

	if upgrades.get("auto_nephew", 0) > 0 and upgrades.get("auto_seagull", 0) > 0 and upgrades.get("crab_trap", 0) > 0:
		unlock_achievement("beach_automation")

# --- Opciones de Volumen y Pantalla Completa (Issue #20) ---

func cycle_volume() -> void:
	if master_volume_pct == 100:
		master_volume_pct = 50
	elif master_volume_pct == 50:
		master_volume_pct = 0
	else:
		master_volume_pct = 100
	_apply_audio_volume()
	play_sfx("buy")
	save_game()

func _apply_audio_volume() -> void:
	var db: float = -80.0
	var music_db: float = -80.0
	if master_volume_pct == 100:
		db = -6.0
		music_db = -14.5
	elif master_volume_pct == 50:
		db = -15.0
		music_db = -23.0
	for p in sfx_players:
		p.volume_db = db
	if music_player:
		music_player.volume_db = music_db
	_update_radio_playback()

func toggle_fullscreen() -> void:
	is_fullscreen = not is_fullscreen
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# --- Mercado de Divisas Dinámico (Issue #18) ---

func roll_daily_market() -> void:
	var codes: Array[String] = ["USD", "GBP", "PEN"]
	for c in codes:
		market_multipliers[c] = snappedf(randf_range(0.80, 1.35), 0.05)
	var hot_code: String = codes.pick_random()
	market_multipliers[hot_code] = snappedf(randf_range(1.25, 1.45), 0.05)

func get_market_trend_text(code: String) -> String:
	var m: float = market_multipliers.get(code, 1.0)
	var pct: int = int(round((m - 1.0) * 100.0))
	if pct >= 5:
		return "📈 +%d%%" % pct
	elif pct <= -5:
		return "📉 %d%%" % pct
	return "➖ 0%"

func exchange_single_currency_to_eur(code: String) -> float:
	var amount: float = currencies.get(code, 0.0)
	if amount <= 0.0:
		return 0.0
	var rate: float = get_effective_exchange_rate(code)
	var gained: float = snappedf(amount * rate, 0.1)
	currencies[code] = 0.0
	currencies["EUR"] += gained
	lifetime_stats["total_eur_earned"] = float(lifetime_stats.get("total_eur_earned", 0.0)) + gained
	if market_multipliers.get(code, 1.0) >= 1.20:
		unlock_achievement("wall_beach_wolf")
	currencies_updated.emit()
	play_sfx("coin", 0.92, 1.18)
	save_game()
	return gained

# --- Sintetizador de Sonidos y Música Chiptune Procedural (Issue #8 & #31) ---

func _init_procedural_audio() -> void:
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		sfx_players.append(p)

	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -14.5
	add_child(music_player)

	sfx_streams["hit"] = _make_tone(190.0, 75.0, 0.08, 0.35)
	sfx_streams["bucket"] = _make_tone(130.0, 42.0, 0.18, 0.55)
	sfx_streams["crit"] = _make_tone(520.0, 880.0, 0.12, 0.2)
	sfx_streams["coin"] = _make_tone(780.0, 1180.0, 0.07, 0.05)
	sfx_streams["buy"] = _make_tone(440.0, 660.0, 0.14, 0.1)
	sfx_streams["tractor"] = _make_tone(95.0, 110.0, 0.32, 0.6)

	# Emisora 1: Chiringuito FM (Rumba Veraniega 8-Bit)
	radio_streams[1] = _make_radio_loop(
		[523.25, 659.25, 783.99, 880.00, 783.99, 659.25, 587.33, 523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25, 493.88, 523.25],
		[130.81, 196.00, 130.81, 196.00, 174.61, 220.00, 146.83, 196.00, 130.81, 196.00, 164.81, 220.00, 146.83, 196.00, 123.47, 130.81],
		0.21, 0.12
	)
	# Emisora 2: Costa Tropical (Calipso Isleño)
	radio_streams[2] = _make_radio_loop(
		[698.46, 880.00, 1046.50, 880.00, 783.99, 659.25, 523.25, 587.33, 698.46, 880.00, 987.77, 880.00, 783.99, 659.25, 587.33, 523.25],
		[174.61, 261.63, 174.61, 261.63, 196.00, 293.66, 130.81, 196.00, 174.61, 261.63, 196.00, 246.94, 130.81, 196.00, 146.83, 130.81],
		0.19, 0.08
	)
	# Emisora 3: Olas Chill (Atardecer Suave)
	radio_streams[3] = _make_radio_loop(
		[440.00, 523.25, 659.25, 523.25, 392.00, 493.88, 587.33, 493.88, 349.23, 440.00, 523.25, 440.00, 329.63, 392.00, 493.88, 392.00],
		[110.00, 110.00, 164.81, 164.81, 98.00, 98.00, 146.83, 146.83, 87.31, 87.31, 130.81, 130.81, 82.41, 82.41, 123.47, 123.47],
		0.30, 0.03
	)

func _make_radio_loop(melody: Array, bass: Array, step_dur: float, perc_mix: float) -> AudioStreamWAV:
	var rate: int = 11025
	var step_samples: int = int(rate * step_dur)
	var total_steps: int = melody.size()
	var total_samples: int = step_samples * total_steps
	var data := PackedByteArray()
	data.resize(total_samples)

	var phase_m: float = 0.0
	var phase_b: float = 0.0
	for s in range(total_steps):
		var fm: float = float(melody[s])
		var fb: float = float(bass[s])
		var offset: int = s * step_samples
		for i in range(step_samples):
			var t: float = float(i) / float(step_samples)
			var env_m: float = pow(1.0 - t * 0.75, 1.3)
			var env_b: float = 1.0 - t * 0.45
			phase_m += TAU * fm / float(rate)
			phase_b += TAU * fb / float(rate)
			# Onda melodía suave + armónico + bajo + maraca rítmica en los primeros instantes del pulso
			var lead: float = (sin(phase_m) * 0.7 + sin(phase_m * 2.0) * 0.3) * env_m
			var sub: float = sin(phase_b) * env_b
			var shaker: float = (randf_range(-1.0, 1.0) * perc_mix) if (t < 0.18 and s % 2 == 1) else 0.0
			var mix_val: float = lead * 0.50 + sub * 0.40 + shaker
			var sample_int: int = int(clampf(mix_val * 85.0, -115.0, 115.0))
			data[offset + i] = sample_int & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	stream.data = data
	return stream

func _make_tone(f_start: float, f_end: float, duration: float, noise_mix: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate * duration)
	var data := PackedByteArray()
	data.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = pow(1.0 - t, 1.4)
		var freq: float = lerpf(f_start, f_end, t)
		phase += TAU * freq / float(rate)
		var wave_val: float = sin(phase) * (1.0 - noise_mix) + randf_range(-1.0, 1.0) * noise_mix
		var sample_int: int = int(clampf(wave_val * env * 95.0, -120.0, 120.0))
		data[i] = sample_int & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func play_sfx(kind: String, min_pitch: float = 0.88, max_pitch: float = 1.16) -> void:
	if master_volume_pct <= 0 or not sfx_streams.has(kind):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx_streams[kind]
			p.pitch_scale = randf_range(min_pitch, max_pitch)
			p.play()
			return

# --- Sistema de Guardado y Carga Automática (Issue #7) ---

func has_saved_progress() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and (current_day > 1 or golden_shells > 0 or currencies["EUR"] > 0.0 or unlocked_achievements.size() > 0)

func save_game() -> void:
	record_day_reached(current_day)
	var data: Dictionary = {
		"version": 1,
		"current_day": current_day,
		"current_bill_index": current_bill_index,
		"master_volume_pct": master_volume_pct,
		"radio_station": radio_station,
		"currencies": currencies,
		"market_multipliers": market_multipliers,
		"upgrades": upgrades,
		"golden_shells": golden_shells,
		"prestige_upgrades": prestige_upgrades,
		"unlocked_achievements": unlocked_achievements,
		"lifetime_stats": lifetime_stats
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var raw_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	var data: Dictionary = parsed
	current_day = int(data.get("current_day", 1))
	current_bill_index = int(data.get("current_bill_index", 0))
	golden_shells = int(data.get("golden_shells", 0))
	master_volume_pct = int(data.get("master_volume_pct", 100))
	radio_station = int(data.get("radio_station", 1))
	_apply_audio_volume()

	if data.has("currencies") and typeof(data["currencies"]) == TYPE_DICTIONARY:
		for k in currencies.keys():
			if data["currencies"].has(k):
				currencies[k] = float(data["currencies"][k])

	if data.has("market_multipliers") and typeof(data["market_multipliers"]) == TYPE_DICTIONARY:
		for k in market_multipliers.keys():
			if data["market_multipliers"].has(k):
				market_multipliers[k] = float(data["market_multipliers"][k])

	if data.has("upgrades") and typeof(data["upgrades"]) == TYPE_DICTIONARY:
		for k in upgrades.keys():
			if data["upgrades"].has(k):
				upgrades[k] = int(data["upgrades"][k])

	if data.has("prestige_upgrades") and typeof(data["prestige_upgrades"]) == TYPE_DICTIONARY:
		for k in prestige_upgrades.keys():
			if data["prestige_upgrades"].has(k):
				prestige_upgrades[k] = int(data["prestige_upgrades"][k])

	if data.has("unlocked_achievements") and typeof(data["unlocked_achievements"]) == TYPE_DICTIONARY:
		unlocked_achievements = data["unlocked_achievements"].duplicate()

	if data.has("lifetime_stats") and typeof(data["lifetime_stats"]) == TYPE_DICTIONARY:
		for k in lifetime_stats.keys():
			if data["lifetime_stats"].has(k):
				lifetime_stats[k] = data["lifetime_stats"][k]

	return true

func delete_save_and_reset_all() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	golden_shells = 0
	unlocked_achievements.clear()
	lifetime_stats = {
		"total_crabs_caught": 0,
		"total_eur_earned": 0.0,
		"total_bills_paid": 0,
		"max_day_reached": 1,
		"best_combo": 1
	}
	for k in prestige_upgrades.keys():
		prestige_upgrades[k] = 0
	reset_run()

# --- Compras del Árbol de Habilidades ---

func get_upgrade_cost(id: String) -> float:
	for item in upgrade_catalog:
		if item["id"] == id:
			var lvl: int = upgrades.get(id, 0)
			return snappedf(item["base_cost"] * pow(item["cost_mult"], lvl), 0.5)
	return 9999.0

func is_upgrade_unlocked(id: String) -> bool:
	for item in upgrade_catalog:
		if item["id"] == id:
			var req: String = item["req"]
			return req == "" or upgrades.get(req, 0) > 0
	return false

func buy_upgrade(id: String) -> bool:
	for item in upgrade_catalog:
		if item["id"] == id:
			var lvl: int = upgrades.get(id, 0)
			if lvl >= item["max_lvl"] or not is_upgrade_unlocked(id):
				return false
			var cost: float = get_upgrade_cost(id)
			if currencies["EUR"] < cost:
				return false
			currencies["EUR"] = snappedf(currencies["EUR"] - cost, 0.1)
			upgrades[id] = lvl + 1
			_check_upgrade_achievements()
			currencies_updated.emit()
			play_sfx("buy")
			save_game()
			return true
	return false

# --- Funciones de Prestigio Permanente (Issue #6) ---

func get_prestige_cost(id: String) -> int:
	for item in prestige_catalog:
		if item["id"] == id:
			var lvl: int = prestige_upgrades.get(id, 0)
			return item["base_cost"] + (lvl * item["cost_step"])
	return 999

func buy_prestige_upgrade(id: String) -> bool:
	for item in prestige_catalog:
		if item["id"] == id:
			var lvl: int = prestige_upgrades.get(id, 0)
			if lvl >= item["max_lvl"]:
				return false
			var cost: int = get_prestige_cost(id)
			if golden_shells < cost:
				return false
			golden_shells -= cost
			prestige_upgrades[id] = lvl + 1
			play_sfx("buy", 0.95, 1.25)
			save_game()
			return true
	return false

func calculate_prestige_reward() -> int:
	return maxi(1, current_bill_index * 2 + int(current_day / 3.0))

func award_bankruptcy_shells() -> int:
	var earned: int = calculate_prestige_reward()
	golden_shells += earned
	save_game()
	return earned

# --- Estadísticas Calculadas Dinámicamente ---

func get_shovel_damage() -> float:
	var base: float = 10.0 + (upgrades["shovel_damage"] * 5.0)
	var perm_mult: float = 1.0 + (prestige_upgrades["permanent_damage"] * 0.25)
	return base * perm_mult

func get_shovel_radius() -> float:
	return 42.0 + (upgrades["shovel_radius"] * 8.0)

func get_crit_chance() -> float:
	return 0.05 + (upgrades["crit_chance"] * 0.05)

func get_multi_hit_multiplier(targets_hit: int) -> float:
	if targets_hit <= 1 or upgrades["multi_hit_bonus"] == 0:
		return 1.0
	return 1.0 + (targets_hit - 1) * (0.25 * upgrades["multi_hit_bonus"])

func get_rake_radius() -> float:
	return 48.0 + (upgrades["rake_magnet"] * 22.0)

func get_max_stamina() -> float:
	return 100.0 + (upgrades["max_stamina"] * 25.0) + (prestige_upgrades["sunscreen_stamina"] * 20.0)

func get_luck_multiplier() -> float:
	return 1.0 + (upgrades["global_luck"] * 0.20)

func get_foot_ice_cream_chance() -> float:
	return (0.10 + upgrades["ice_cream_foot"] * 0.10) * get_luck_multiplier()

func get_rocket_ice_cream_chance() -> float:
	return (upgrades["ice_cream_rocket"] * 0.10) * get_luck_multiplier()

func get_vampire_ice_cream_chance() -> float:
	return (upgrades["ice_cream_vampire"] * 0.18) * get_luck_multiplier()

func get_magnum_ice_cream_chance() -> float:
	return (upgrades["ice_cream_magnum"] * 0.16) * get_luck_multiplier()

func get_shark_ice_cream_chance() -> float:
	return (upgrades["ice_cream_shark"] * 0.12) * get_luck_multiplier()

func get_fridge_summary() -> String:
	var icons: Array[String] = []
	if upgrades["ice_cream_foot"] > 0:
		icons.append("🦶x%d" % upgrades["ice_cream_foot"])
	if upgrades["ice_cream_rocket"] > 0:
		icons.append("🚀x%d" % upgrades["ice_cream_rocket"])
	if upgrades["ice_cream_vampire"] > 0:
		icons.append("🧛x%d" % upgrades["ice_cream_vampire"])
	if upgrades["ice_cream_magnum"] > 0:
		icons.append("🍫x%d" % upgrades["ice_cream_magnum"])
	if upgrades["ice_cream_shark"] > 0:
		icons.append("🦈x%d" % upgrades["ice_cream_shark"])
	if icons.is_empty():
		return "🦶(Muestra)"
	return " ".join(icons)

func get_current_bill() -> Dictionary:
	var discount: float = clampf(1.0 - (prestige_upgrades["waiter_discount"] * 0.10), 0.4, 1.0)
	if current_bill_index < bills.size():
		var raw_bill: Dictionary = bills[current_bill_index]
		return {
			"title": raw_bill["title"],
			"amount": snappedf(raw_bill["amount"] * discount, 1.0)
		}
	var extra_cycles: int = current_bill_index - bills.size() + 1
	var endless_amount: float = 3000.0 * pow(2.4, extra_cycles)
	return {
		"title": "🍹 Reserva VIP Chiringuito #%d" % (current_bill_index + 1),
		"amount": snappedf(endless_amount * discount, 1.0)
	}

func get_effective_exchange_rate(code: String) -> float:
	var bonus_mult: float = 1.0 + (upgrades["exchange_rate_boost"] * 0.15)
	var market_mult: float = market_multipliers.get(code, 1.0)
	return snappedf(base_exchange_rates.get(code, 1.0) * bonus_mult * market_mult, 0.01)

func get_pending_foreign_eur_value() -> float:
	var total: float = 0.0
	for code in ["USD", "GBP", "PEN"]:
		total += currencies.get(code, 0.0) * get_effective_exchange_rate(code)
	return snappedf(total, 0.1)

func is_bill_due_today() -> bool:
	return current_day % days_per_bill == 0

func pay_current_bill() -> bool:
	var bill: Dictionary = get_current_bill()
	var cost: float = bill["amount"]
	if currencies["EUR"] < cost:
		return false
	currencies["EUR"] = snappedf(currencies["EUR"] - cost, 0.1)
	current_bill_index += 1
	lifetime_stats["total_bills_paid"] = int(lifetime_stats.get("total_bills_paid", 0)) + 1
	if current_bill_index == bills.size():
		golden_shells += 5
	else:
		golden_shells += 1
	unlock_achievement("first_bill_paid")
	currencies_updated.emit()
	play_sfx("buy", 1.05, 1.25)
	save_game()
	return true

func reset_run() -> void:
	current_day = 1
	current_bill_index = 0
	for code in currencies.keys():
		currencies[code] = 0.0
	currencies["EUR"] = prestige_upgrades["starting_euros"] * 15.0
	for upg in upgrades.keys():
		upgrades[upg] = 0
	roll_daily_market()
	currencies_updated.emit()
	save_game()

func add_currency(code: String, amount: float) -> void:
	if not currencies.has(code):
		currencies[code] = 0.0
	currencies[code] += amount
	if code == "EUR" and amount > 0.0:
		lifetime_stats["total_eur_earned"] = float(lifetime_stats.get("total_eur_earned", 0.0)) + amount
	currencies_updated.emit()

func exchange_all_to_eur() -> float:
	var gained_eur: float = 0.0
	for code in ["USD", "GBP", "PEN"]:
		var amount: float = currencies.get(code, 0.0)
		if amount > 0.0:
			if market_multipliers.get(code, 1.0) >= 1.20:
				unlock_achievement("wall_beach_wolf")
			gained_eur += amount * get_effective_exchange_rate(code)
			currencies[code] = 0.0
	var rounded_gain: float = snappedf(gained_eur, 0.1)
	currencies["EUR"] += rounded_gain
	lifetime_stats["total_eur_earned"] = float(lifetime_stats.get("total_eur_earned", 0.0)) + rounded_gain
	currencies_updated.emit()
	play_sfx("coin", 0.9, 1.1)
	save_game()
	return gained_eur
