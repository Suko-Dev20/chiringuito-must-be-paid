extends Node2D
## Escena principal de la ronda en la playa ("La Orilla")
## Incluye: Herramientas, Fauna Marina, Olas, Helados, Game Feel, Automatización y Logros (Issue #25).

var current_stamina: float = 100.0
var max_stamina: float = 100.0
var round_active: bool = true

# Cooldowns
var bucket_cooldown: float = 0.0
var bucket_max_cooldown: float = 3.0
var tractor_cooldown: float = 0.0
var tractor_max_cooldown: float = 12.0
var magnum_timer: float = 1.0

# Contenedores en memoria de los bichos, monedas y efectos ("Juice" - Issue #8)
var crabs: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []

# Screen Shake y Animación del Cursor
var shake_strength: float = 0.0
var cursor_swing_anim: float = 0.0

# Animación del Tractor Limpia-Playas
var tractor_active: bool = false
var tractor_x: float = -150.0

# --- Automatización Playera (Issue #17: Sobrino, Gaviota y Nasas) ---
var nephew_pos := Vector2(640, 360)
var nephew_hit_timer: float = 0.0
var seagull_pos := Vector2(320, 220)
var trap_positions: Array[Vector2] = [
	Vector2(640, 480),
	Vector2(360, 460),
	Vector2(920, 460)
]

var spawn_timer: float = 0.0
var wave_time: float = 0.0

# --- Sistema de Olas Dinámicas (Issue #4) ---
var tide_timer: float = 9.0
var tide_interval: float = 10.0
var surge_active: bool = false
var surge_progress: float = 0.0
var surge_spawned_fauna: bool = false
var current_wave_y: float = 610.0
var wet_sand_alpha: float = 0.0

# --- Notificación Toast de Postal / Logro Desbloqueado (Issue #25) ---
var toast_timer: float = 0.0
var toast_title: String = ""
var toast_desc: String = ""

func _ready() -> void:
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)
	start_new_round()

func _on_achievement_unlocked(title: String, desc: String) -> void:
	toast_title = title
	toast_desc = desc
	toast_timer = 3.8
	_add_screen_shake(5.5)

func start_new_round() -> void:
	max_stamina = GameState.get_max_stamina()
	current_stamina = max_stamina
	round_active = true
	crabs.clear()
	coins.clear()
	floating_texts.clear()
	particles.clear()
	shockwaves.clear()
	shake_strength = 0.0
	tide_timer = 8.5
	surge_active = false
	surge_progress = 0.0
	wet_sand_alpha = 0.0
	magnum_timer = 1.0
	nephew_pos = Vector2(640, 360)
	seagull_pos = Vector2(320, 220)
	for i in range(4):
		spawn_crab("crab")
	spawn_crab("clam")

func _process(delta: float) -> void:
	wave_time += delta
	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - delta)
	if round_active:
		_update_dynamic_waves(delta)
		_update_spawner(delta)
		_update_crabs(delta)
		_update_automation_helpers(delta)
		_update_coins_and_rake(delta)
		_update_magnum_ice_cream(delta)
		_update_cooldowns(delta)
	_update_tractor(delta)
	_update_juice_effects(delta)
	_update_floating_texts(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not round_active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			_on_next_day_pressed()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_use_shovel(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_use_bucket(event.position)

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_use_tractor()

# --- Automatización Playera: Sobrino, Gaviota y Nasas (Issue #17) ---

func _get_active_traps() -> Array[Vector2]:
	var lvl: int = GameState.upgrades["crab_trap"]
	if lvl <= 0:
		return []
	var count: int = mini(3, 1 + int(lvl / 2.0))
	return trap_positions.slice(0, count)

func _update_automation_helpers(delta: float) -> void:
	# 1. 👦 Sobrino con Cubo (persigue al bicho más cercano y da golpes gratis sin gastar Stamina)
	var nephew_lvl: int = GameState.upgrades["auto_nephew"]
	if nephew_lvl > 0:
		nephew_hit_timer = maxf(0.0, nephew_hit_timer - delta)
		if not crabs.is_empty():
			var nearest_idx: int = 0
			var best_dist: float = 99999.0
			for i in range(crabs.size()):
				var d: float = nephew_pos.distance_to(crabs[i]["pos"])
				if d < best_dist:
					best_dist = d
					nearest_idx = i
			var target_pos: Vector2 = crabs[nearest_idx]["pos"]
			var move_spd: float = 165.0 + (nephew_lvl * 30.0)
			nephew_pos = nephew_pos.move_toward(target_pos, move_spd * delta)
			if best_dist <= 42.0 and nephew_hit_timer <= 0.0:
				nephew_hit_timer = maxf(0.45, 1.55 - (nephew_lvl * 0.22))
				GameState.play_sfx("hit", 1.05, 1.28)
				var auto_dmg: float = GameState.get_shovel_damage() * (0.6 + nephew_lvl * 0.25)
				_perform_strike(nephew_pos, 48.0, auto_dmg, 0.0, false)

	# 2. 🐦 Gaviota Amaestrada (vuela hacia las monedas sueltas priorizando las cercanas a la ola)
	var gull_lvl: int = GameState.upgrades["auto_seagull"]
	if gull_lvl > 0:
		if not coins.is_empty():
			var priority_idx: int = 0
			var best_score: float = -99999.0
			for i in range(coins.size()):
				var score: float = coins[i]["pos"].y * 1.5 - seagull_pos.distance_to(coins[i]["pos"]) * 0.4
				if score > best_score:
					best_score = score
					priority_idx = i
			var c_pos: Vector2 = coins[priority_idx]["pos"]
			var gull_spd: float = 230.0 + (gull_lvl * 75.0)
			seagull_pos = seagull_pos.move_toward(c_pos, gull_spd * delta)
			if seagull_pos.distance_to(c_pos) <= 20.0:
				_collect_coin(coins[priority_idx])
				coins.remove_at(priority_idx)
		else:
			var patrol_target := Vector2(640.0 + cos(wave_time * 1.5) * 260.0, 260.0 + sin(wave_time * 2.0) * 60.0)
			seagull_pos = seagull_pos.move_toward(patrol_target, 140.0 * delta)

# --- Efectos de Game Feel ("Juice": Screen Shake, Partículas y Ondas - Issue #8) ---

func _add_screen_shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)

func _spawn_particles(pos: Vector2, count: int, col: Color, speed: float = 160.0) -> void:
	for i in range(count):
		var angle: float = randf() * TAU
		var spd: float = randf_range(speed * 0.35, speed)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * spd + Vector2(0, -60.0),
			"col": col,
			"size": randf_range(3.0, 6.5),
			"ttl": randf_range(0.28, 0.55),
			"max_ttl": 0.55
		})

func _spawn_shockwave(pos: Vector2, max_r: float, col: Color) -> void:
	shockwaves.append({
		"pos": pos,
		"r": 10.0,
		"max_r": max_r,
		"col": col,
		"alpha": 0.9
	})

func _update_juice_effects(delta: float) -> void:
	if cursor_swing_anim > 0.0:
		cursor_swing_anim = maxf(0.0, cursor_swing_anim - delta * 6.0)

	if shake_strength > 0.0:
		shake_strength = maxf(0.0, shake_strength - delta * 28.0)
		position = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	else:
		position = Vector2.ZERO

	for i in range(particles.size() - 1, -1, -1):
		var pt: Dictionary = particles[i]
		pt["vel"].y += 380.0 * delta
		pt["pos"] += pt["vel"] * delta
		pt["ttl"] -= delta
		if pt["ttl"] <= 0.0:
			particles.remove_at(i)

	for i in range(shockwaves.size() - 1, -1, -1):
		var sw: Dictionary = shockwaves[i]
		sw["r"] = lerpf(sw["r"], sw["max_r"], delta * 14.0)
		sw["alpha"] -= delta * 3.2
		if sw["alpha"] <= 0.0:
			shockwaves.remove_at(i)

# --- Sistema de Olas Dinámicas (Issue #4) ---

func _update_dynamic_waves(delta: float) -> void:
	if wet_sand_alpha > 0.0 and not surge_active:
		wet_sand_alpha = maxf(0.0, wet_sand_alpha - delta * 0.18)

	if not surge_active:
		current_wave_y = 610.0 + sin(wave_time * 2.2) * 16.0
		tide_timer -= delta
		if tide_timer <= 0.0:
			surge_active = true
			surge_progress = 0.0
			surge_spawned_fauna = false
			wet_sand_alpha = 0.65
			_spawn_text(Vector2(540, 290), "🌊 ¡SUBE LA MAREA!", Color.AQUA)
	else:
		surge_progress += delta * 1.35
		var s: float = sin(minf(surge_progress, PI))
		current_wave_y = 610.0 - (s * 270.0)

		var washed_count: int = 0
		for i in range(coins.size() - 1, -1, -1):
			if coins[i]["pos"].y >= current_wave_y + 8.0:
				coins[i]["pos"].y += 220.0 * delta
				if surge_progress > PI * 0.55 or coins[i]["pos"].y > 650.0:
					_spawn_particles(coins[i]["pos"], 5, Color.AQUA, 90.0)
					coins.remove_at(i)
					washed_count += 1
		if washed_count > 0:
			_spawn_text(Vector2(560, current_wave_y - 20.0), "🌊 ¡La ola se llevó %d moneda(s)!" % washed_count, Color.ORANGE_RED)

		if not surge_spawned_fauna and surge_progress >= PI * 0.5:
			surge_spawned_fauna = true
			spawn_crab("clam")
			spawn_crab("clam")
			spawn_crab()
			_spawn_text(Vector2(500, 380), "🐚 ¡La ola trajo nuevas Coquinas a la arena!", Color.AQUAMARINE)

		if surge_progress >= PI:
			surge_active = false
			tide_timer = tide_interval

# --- Mecánicas de Herramientas y Helados por Suerte (Issue #5 & #8) ---

func _use_shovel(pos: Vector2) -> void:
	cursor_swing_anim = 1.0
	GameState.play_sfx("hit", 0.90, 1.15)
	var radius: float = GameState.get_shovel_radius()
	_perform_strike(pos, radius, GameState.get_shovel_damage(), 4.5, false)

func _use_bucket(pos: Vector2) -> void:
	if bucket_cooldown > 0.0:
		_spawn_text(pos, "¡Cubo recargando!", Color.ORANGE)
		return
	cursor_swing_anim = 1.0
	GameState.play_sfx("bucket", 0.85, 1.08)
	_add_screen_shake(9.5)
	bucket_cooldown = maxf(0.8, bucket_max_cooldown - (GameState.upgrades["unlock_bucket"] * 0.4))
	var radius: float = GameState.get_shovel_radius() * (1.9 + GameState.upgrades["unlock_bucket"] * 0.15)
	var dmg_mult: float = 1.6 + (GameState.upgrades["unlock_bucket"] * 0.35)
	_perform_strike(pos, radius, GameState.get_shovel_damage() * dmg_mult, 9.0, true)

func _perform_strike(pos: Vector2, radius: float, base_dmg: float, stamina_cost: float, is_bucket: bool) -> void:
	current_stamina = maxf(0.0, current_stamina - stamina_cost)
	
	var actual_radius: float = radius
	var rocket_proc: bool = randf() < GameState.get_rocket_ice_cream_chance()
	if rocket_proc:
		actual_radius *= 1.6
		_add_screen_shake(8.0)
		_spawn_text(pos + Vector2(0, -55), "🚀 ¡COHETE TRICOLOR! Onda Expansiva", Color.DEEP_PINK)

	var ring_col: Color = Color.DEEP_PINK if rocket_proc else (Color.CYAN if is_bucket else Color(1.0, 0.85, 0.3))
	_spawn_shockwave(pos, actual_radius, ring_col)
	_spawn_particles(pos, 10 if is_bucket else 5, Color("#e9c46a"), 130.0)

	if tractor_cooldown > 0.0 and randf() < GameState.get_shark_ice_cream_chance():
		tractor_cooldown = maxf(0.0, tractor_cooldown - 2.5)
		_spawn_text(pos + Vector2(0, -72), "🦈 ¡TIBURÓN AZUL! -2.5s Tractor", Color.DODGER_BLUE)

	var hit_indices: Array[int] = []
	for i in range(crabs.size()):
		if crabs[i]["pos"].distance_to(pos) <= actual_radius + crabs[i]["radius"]:
			hit_indices.append(i)

	var multi_mult: float = GameState.get_multi_hit_multiplier(hit_indices.size())
	var is_crit: bool = randf() < GameState.get_crit_chance() or (hit_indices.size() >= 3)
	var final_dmg: float = base_dmg * multi_mult * (2.0 if is_crit else 1.0)

	if is_crit and not hit_indices.is_empty():
		GameState.play_sfx("crit", 0.92, 1.18)
		_add_screen_shake(6.5)

	var vampire_proc: bool = false
	if is_crit and not hit_indices.is_empty() and randf() < GameState.get_vampire_ice_cream_chance():
		vampire_proc = true
		current_stamina = minf(max_stamina, current_stamina + 5.0)
		_spawn_text(pos + Vector2(0, -90), "🧛 ¡CONDE COLMILLOS! +5 Stamina & Botín x2", Color.CRIMSON)

	if hit_indices.size() >= 2:
		_spawn_text(pos + Vector2(0, -35), "¡COMBO x%d!" % hit_indices.size(), Color.CYAN)
	if hit_indices.size() >= 3:
		GameState.unlock_achievement("combo_master")

	hit_indices.reverse()
	for idx in hit_indices:
		var crab: Dictionary = crabs[idx]
		crab["hp"] -= final_dmg
		crab["hit_flash"] = 0.15
		_spawn_particles(crab["pos"], 6, Color.CORAL, 140.0)
		var dmg_text: String = "%d%s" % [int(final_dmg), " ¡CRIT!" if is_crit else ""]
		_spawn_text(crab["pos"] + Vector2(randf_range(-15, 15), -20), dmg_text, Color.YELLOW if is_crit else Color.WHITE)
		
		if crab["hp"] <= 0.0:
			_on_crab_caught(crab, 2 if vampire_proc else 1)
			crabs.remove_at(idx)

	if current_stamina <= 0.0:
		round_active = false
		_spawn_text(Vector2(640, 320), "¡AGOTADO POR EL SOL! Fin del Día", Color.ORANGE_RED)

func _on_crab_caught(crab: Dictionary, coin_mult: int = 1) -> void:
	var extra_drops: int = GameState.upgrades["tourist_currencies"]
	var kind: String = crab.get("kind", "crab")
	var base_min: int = 2
	var base_max: int = 4
	var kind_val_mult: float = 1.0
	var spread: float = 38.0

	GameState.unlock_achievement("first_catch")
	_spawn_particles(crab["pos"], 14, Color.GOLD if kind == "lobster" else Color.AQUAMARINE, 210.0)

	if kind == "clam":
		base_min = 3
		base_max = 5
		kind_val_mult = 1.6
		_spawn_text(crab["pos"] + Vector2(0, -32), "🐚 ¡Coquina desenterrada!", Color.AQUA)
	elif kind == "octopus":
		base_min = 7
		base_max = 10
		kind_val_mult = 1.4
		spread = 68.0
		_add_screen_shake(7.5)
		GameState.unlock_achievement("octopus_hunter")
		_spawn_text(crab["pos"] + Vector2(0, -45), "🐙 ¡EXPLOSIÓN DE DIVISAS TURISTAS!", Color.VIOLET)
	elif kind == "lobster":
		base_min = 5
		base_max = 7
		kind_val_mult = 3.0
		spread = 52.0
		_add_screen_shake(8.0)
		GameState.unlock_achievement("golden_lobster")
		_spawn_text(crab["pos"] + Vector2(0, -45), "🦞 ¡LANGOSTA DORADA! Botín x3", Color.GOLD)

	var drops: int = (randi_range(base_min, base_max) + int(extra_drops / 2.0)) * coin_mult
	var val_boost: float = (1.0 + (extra_drops * 0.25)) * kind_val_mult
	for i in range(drops):
		var currency_options: Array[String] = ["EUR", "USD", "GBP", "PEN"]
		var chosen_code: String = currency_options.pick_random()
		coins.append({
			"pos": crab["pos"] + Vector2(randf_range(-spread, spread), randf_range(-spread * 0.7, spread * 0.7)),
			"code": chosen_code,
			"value": randf_range(1.0, 3.0) * val_boost,
			"pop": 1.0
		})

	if randf() < GameState.get_foot_ice_cream_chance():
		current_stamina = minf(max_stamina, current_stamina + 7.0)
		_spawn_text(crab["pos"] + Vector2(0, -40), "🦶 ¡Pie Helado! +7 Stamina", Color.AQUAMARINE)

func _update_magnum_ice_cream(delta: float) -> void:
	if GameState.upgrades["ice_cream_magnum"] <= 0 or coins.is_empty():
		return
	magnum_timer -= delta
	if magnum_timer <= 0.0:
		magnum_timer = 1.0
		if randf() < GameState.get_magnum_ice_cream_chance():
			var idx: int = randi() % coins.size()
			var c: Dictionary = coins[idx]
			c["value"] *= 2.0
			_spawn_particles(c["pos"], 8, Color.GOLD, 120.0)
			_spawn_text(c["pos"] + Vector2(0, -18), "🍫 ¡Bombón Magnético x2!", Color.GOLD)
			_collect_coin(c)
			coins.remove_at(idx)

# --- Rastrillo (Recogida al mover el ratón) y Tractor ---

func _update_coins_and_rake(delta: float) -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var rake_r: float = GameState.get_rake_radius()
	for i in range(coins.size() - 1, -1, -1):
		var c: Dictionary = coins[i]
		if c.get("pop", 0.0) > 0.0:
			c["pop"] = maxf(0.0, c["pop"] - delta * 3.5)
		var dist: float = c["pos"].distance_to(mouse_pos)
		if dist <= rake_r:
			c["pos"] = c["pos"].move_toward(mouse_pos, 440.0 * delta)
			if dist <= 18.0:
				_collect_coin(c)
				coins.remove_at(i)

func _use_tractor() -> void:
	if tractor_cooldown > 0.0 or tractor_active:
		return
	tractor_active = true
	tractor_x = -120.0
	tractor_cooldown = maxf(3.0, tractor_max_cooldown - (GameState.upgrades["tractor_cooldown"] * 1.8))
	GameState.play_sfx("tractor", 0.9, 1.05)
	_add_screen_shake(6.0)
	_spawn_text(Vector2(640, 260), "🚜 ¡TRACTOR LIMPIA-PLAYAS EN MARCHA!", Color.GOLD)

func _update_tractor(delta: float) -> void:
	if not tractor_active:
		return
	_add_screen_shake(2.2)
	var speed_bonus: float = 1.0 + (GameState.upgrades["unlock_tractor"] * 0.15)
	tractor_x += 900.0 * speed_bonus * delta
	for i in range(coins.size() - 1, -1, -1):
		if coins[i]["pos"].x <= tractor_x + 60.0:
			_collect_coin(coins[i])
			coins.remove_at(i)
	if tractor_x > 1400.0:
		tractor_active = false

func _collect_coin(c: Dictionary) -> void:
	GameState.play_sfx("coin", 0.88, 1.24)
	_spawn_particles(c["pos"], 5, Color.GOLD, 95.0)
	GameState.add_currency(c["code"], snappedf(c["value"], 0.5))
	_spawn_text(c["pos"], "+%.1f %s" % [c["value"], c["code"]], Color.GREEN_YELLOW)

# --- Spawner y Comportamientos de Fauna Marina (Issue #3 & #17) ---

func _update_spawner(delta: float) -> void:
	spawn_timer -= delta
	var interval: float = maxf(0.35, 1.35 - (GameState.upgrades["crab_spawn_rate"] * 0.14))
	if spawn_timer <= 0.0 and crabs.size() < 20:
		spawn_crab()
		spawn_timer = interval

func spawn_crab(forced_kind: String = "") -> void:
	var kind: String = forced_kind
	if kind == "":
		var roll: float = randf()
		if roll < 0.08:
			kind = "lobster"
		elif roll < 0.22:
			kind = "octopus"
		elif roll < 0.45:
			kind = "clam"
		else:
			kind = "crab"

	if kind == "clam":
		crabs.append({
			"kind": "clam",
			"pos": Vector2(randf_range(120, 1160), randf_range(380, 565)),
			"vel": Vector2.ZERO,
			"hp": 22.0,
			"max_hp": 22.0,
			"radius": 20.0,
			"hit_flash": 0.0,
			"bury_timer": 3.8,
			"max_bury": 3.8
		})
	elif kind == "octopus":
		crabs.append({
			"kind": "octopus",
			"pos": Vector2(randf_range(150, 1130), randf_range(180, 500)),
			"vel": Vector2(randf_range(-42, 42), randf_range(-28, 28)),
			"hp": 75.0,
			"max_hp": 75.0,
			"radius": 38.0,
			"hit_flash": 0.0
		})
	elif kind == "lobster":
		var from_left: bool = randf() < 0.5
		var start_x: float = 95.0 if from_left else 1185.0
		var dir_x: float = 1.0 if from_left else -1.0
		crabs.append({
			"kind": "lobster",
			"pos": Vector2(start_x, randf_range(170, 520)),
			"vel": Vector2(235.0 * dir_x, randf_range(-25, 25)),
			"hp": 30.0,
			"max_hp": 30.0,
			"radius": 26.0,
			"hit_flash": 0.0
		})
	else:
		crabs.append({
			"kind": "crab",
			"pos": Vector2(randf_range(120, 1160), randf_range(160, 560)),
			"vel": Vector2(randf_range(-95, 95), randf_range(-40, 40)),
			"hp": 20.0,
			"max_hp": 20.0,
			"radius": 24.0,
			"hit_flash": 0.0
		})

func _update_crabs(delta: float) -> void:
	var active_traps: Array[Vector2] = _get_active_traps()
	var trap_lvl: int = GameState.upgrades["crab_trap"]
	var trap_r: float = 65.0 + trap_lvl * 8.0
	var trap_dps: float = 10.0 + trap_lvl * 8.0

	for i in range(crabs.size() - 1, -1, -1):
		var c: Dictionary = crabs[i]
		var kind: String = c.get("kind", "crab")

		var in_trap: bool = false
		for tpos in active_traps:
			if c["pos"].distance_to(tpos) <= trap_r + c["radius"]:
				in_trap = true
				break

		var speed_mult: float = 0.45 if in_trap else 1.0
		c["pos"] += c["vel"] * speed_mult * delta

		if in_trap:
			c["hp"] -= trap_dps * delta
			if c["hp"] <= 0.0:
				_on_crab_caught(c, 1)
				crabs.remove_at(i)
				continue

		if c["hit_flash"] > 0.0:
			c["hit_flash"] = maxf(0.0, c["hit_flash"] - delta)

		if kind == "clam":
			c["bury_timer"] -= delta * speed_mult
			if c["bury_timer"] <= 0.0:
				_spawn_text(c["pos"], "🐚 ¡Se enterró!", Color.LIGHT_SKY_BLUE)
				crabs.remove_at(i)
				continue

		if kind == "lobster":
			if c["pos"].x < 70.0 or c["pos"].x > 1210.0:
				_spawn_text(c["pos"].clamp(Vector2(100, 150), Vector2(1180, 560)), "🦞 ¡La Langosta escapó!", Color.ORANGE)
				crabs.remove_at(i)
				continue
			if c["pos"].y < 140.0 or c["pos"].y > 580.0:
				c["vel"].y *= -1.0
		else:
			if c["pos"].x < 90.0 or c["pos"].x > 1190.0:
				c["vel"].x *= -1.0
			if c["pos"].y < 140.0 or c["pos"].y > 580.0:
				c["vel"].y *= -1.0

func _update_cooldowns(delta: float) -> void:
	bucket_cooldown = maxf(0.0, bucket_cooldown - delta)
	tractor_cooldown = maxf(0.0, tractor_cooldown - delta)

func _update_floating_texts(delta: float) -> void:
	for i in range(floating_texts.size() - 1, -1, -1):
		floating_texts[i]["pos"].y -= 45.0 * delta
		floating_texts[i]["ttl"] -= delta
		if floating_texts[i]["ttl"] <= 0.0:
			floating_texts.remove_at(i)

func _spawn_text(pos: Vector2, text: String, col: Color) -> void:
	floating_texts.append({"pos": pos, "text": text, "color": col, "ttl": 0.85})

func _on_next_day_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/main/between_days.tscn")

# --- Renderizado Visual con Arte 2D Estilizado y Efectos ("Juice" + Automatización + Logros) ---

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# 1. Arena de la playa + Arena húmeda + Orilla con olas dinámicas
	draw_rect(Rect2(0, 0, 1280, 720), Color("#f4d58d"))
	if wet_sand_alpha > 0.0:
		draw_rect(Rect2(0, 340, 1280, 380), Color(0.76, 0.62, 0.35, wet_sand_alpha * 0.55))

	# 1b. 🕸️ Nasas / Trampas de Cangrejos en la orilla (Issue #17)
	var trap_lvl: int = GameState.upgrades["crab_trap"]
	if trap_lvl > 0:
		var trap_r: float = 65.0 + trap_lvl * 8.0
		for tpos in _get_active_traps():
			draw_circle(tpos, trap_r, Color(0.2, 0.35, 0.25, 0.28))
			draw_arc(tpos, trap_r, 0, TAU, 28, Color("#2b9348"), 2.5)
			draw_string(font, tpos + Vector2(-28, 6), "🕸️ NASA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	if not surge_active and tide_timer <= 2.5 and round_active:
		draw_line(Vector2(0, 340), Vector2(1280, 340), Color(0.18, 0.77, 0.71, 0.55), 2.0)
		draw_string(font, Vector2(450, 332), "🌊 ¡ALERTA DE MAREA EN %.1fs! (Arrastrará monedas hasta esta línea)" % tide_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#005f73"))

	draw_rect(Rect2(0, current_wave_y, 1280, 720 - current_wave_y), Color("#2ec4b6"))
	draw_line(Vector2(0, current_wave_y), Vector2(1280, current_wave_y), Color.WHITE, 5.0)
	draw_line(Vector2(0, current_wave_y + 12), Vector2(1280, current_wave_y + 12), Color(1, 1, 1, 0.45), 2.5)

	# 2. Anillos de impacto (Shockwaves)
	for sw in shockwaves:
		var c_sw: Color = sw["col"]
		c_sw.a = clampf(sw["alpha"], 0.0, 1.0)
		draw_arc(sw["pos"], sw["r"], 0, TAU, 36, c_sw, 3.5)

	# 3. Monedas en la arena (con sombra y animación de salto al caer)
	for c in coins:
		var jump_y: float = sin(c.get("pop", 0.0) * PI) * -18.0
		var cpos: Vector2 = c["pos"] + Vector2(0, jump_y)
		draw_circle(c["pos"] + Vector2(0, 4), 10.0, Color(0, 0, 0, 0.22))
		var col: Color = Color.GOLD if c["code"] == "EUR" else Color.LIGHT_GREEN
		draw_circle(cpos, 11.5, col)
		draw_arc(cpos, 11.5, 0, TAU, 16, Color.WHITE, 1.5)
		draw_string(font, cpos + Vector2(-12, 4), c["code"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)

	# 4. Fauna Marina con Sombras, Ojos y Detalles 2D
	for crab in crabs:
		var p: Vector2 = crab["pos"]
		var kind: String = crab.get("kind", "crab")
		var flash: bool = crab["hit_flash"] > 0.0
		draw_circle(p + Vector2(0, crab["radius"] * 0.45), crab["radius"] * 0.9, Color(0, 0, 0, 0.22))

		if kind == "clam":
			var col: Color = Color.WHITE if flash else Color("#48cae4")
			draw_circle(p, crab["radius"], col)
			draw_arc(p, crab["radius"], PI, TAU, 16, Color("#0077b6"), 3.0)
			var bury_ratio: float = clampf(crab["bury_timer"] / crab["max_bury"], 0.0, 1.0)
			draw_rect(Rect2(p.x - 20, p.y + 22, 40, 5), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(p.x - 20, p.y + 22, 40 * bury_ratio, 5), Color.ORANGE)
		elif kind == "octopus":
			var col: Color = Color.WHITE if flash else Color("#9b5de5")
			for t in range(6):
				var angle: float = (TAU / 6.0) * t + sin(wave_time * 3.5 + t) * 0.25
				var t_pos: Vector2 = p + Vector2(cos(angle), sin(angle)) * 34.0
				draw_circle(t_pos, 10.0, col)
			draw_circle(p, crab["radius"], col)
			draw_circle(p + Vector2(-10, -6), 6.0, Color.WHITE)
			draw_circle(p + Vector2(10, -6), 6.0, Color.WHITE)
			draw_circle(p + Vector2(-10, -6), 3.0, Color.BLACK)
			draw_circle(p + Vector2(10, -6), 3.0, Color.BLACK)
		elif kind == "lobster":
			var col: Color = Color.WHITE if flash else Color("#ffb703")
			draw_circle(p + Vector2(-14, 0), 16.0, col)
			draw_circle(p + Vector2(14, 0), 16.0, col)
			draw_circle(p, crab["radius"], col)
			draw_arc(p, crab["radius"] + 3.0, 0, TAU, 24, Color.GOLD, 2.0)
			draw_circle(p + Vector2(-7, -7), 4.5, Color.WHITE)
			draw_circle(p + Vector2(7, -7), 4.5, Color.WHITE)
			draw_circle(p + Vector2(-7, -7), 2.0, Color.BLACK)
			draw_circle(p + Vector2(7, -7), 2.0, Color.BLACK)
		else:
			var body_col: Color = Color.WHITE if flash else Color("#e63946")
			draw_circle(p + Vector2(-20, -14), 8.0, body_col)
			draw_circle(p + Vector2(20, -14), 8.0, body_col)
			draw_circle(p, crab["radius"], body_col)
			draw_circle(p + Vector2(-8, -8), 4.5, Color.WHITE)
			draw_circle(p + Vector2(8, -8), 4.5, Color.WHITE)
			draw_circle(p + Vector2(-8, -8), 2.0, Color.BLACK)
			draw_circle(p + Vector2(8, -8), 2.0, Color.BLACK)

		var hp_ratio: float = clampf(crab["hp"] / crab["max_hp"], 0.0, 1.0)
		var bar_w: float = crab["radius"] * 1.8
		draw_rect(Rect2(p.x - bar_w * 0.5, p.y - crab["radius"] - 14, bar_w, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p.x - bar_w * 0.5, p.y - crab["radius"] - 14, bar_w * hp_ratio, 6), Color.LIME_GREEN)

	# 4b. Ayudantes Autónomos: 👦 Sobrino con Cubo y 🐦 Gaviota Amaestrada (Issue #17)
	if GameState.upgrades["auto_nephew"] > 0:
		draw_circle(nephew_pos + Vector2(0, 10), 16.0, Color(0, 0, 0, 0.25))
		draw_circle(nephew_pos, 18.0, Color("#3a86ff"))
		draw_string(font, nephew_pos + Vector2(-28, -24), "👦 Sobrino", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)

	if GameState.upgrades["auto_seagull"] > 0:
		draw_circle(seagull_pos + Vector2(0, 22), 12.0, Color(0, 0, 0, 0.18))
		draw_circle(seagull_pos, 14.0, Color.WHITE)
		draw_arc(seagull_pos, 14.0, 0, TAU, 16, Color("#0077b6"), 2.0)
		draw_string(font, seagull_pos + Vector2(-28, -18), "🐦 Gaviota", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)

	# 5. Partículas 2D de arena, agua y chispas
	for pt in particles:
		var pcol: Color = pt["col"]
		pcol.a = clampf(pt["ttl"] / pt["max_ttl"], 0.0, 1.0)
		draw_circle(pt["pos"], pt["size"], pcol)

	# 6. Tractor Limpia-Playas
	if tractor_active:
		draw_rect(Rect2(tractor_x, 120, 70, 480), Color(0.95, 0.75, 0.1, 0.85))
		draw_string(font, Vector2(tractor_x + 8, 360), "🚜 TRACTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)

	# 7. Círculo del cursor (Pala + Radio del Rastrillo + Animación de golpe)
	var mpos: Vector2 = get_viewport().get_mouse_position()
	var swing_scale: float = 1.0 - (cursor_swing_anim * 0.18)
	draw_arc(mpos, GameState.get_shovel_radius() * swing_scale, 0, TAU, 32, Color(1, 0.2, 0.2, 0.8), 2.8)
	draw_arc(mpos, GameState.get_rake_radius(), 0, TAU, 32, Color(1, 0.9, 0.2, 0.35), 1.5)

	# 8. HUD Superior (Stamina, Divisas, Nevera de Helados y Ticket del Chiringuito)
	draw_rect(Rect2(0, 0, 1280, 95), Color(0.08, 0.12, 0.18, 0.92))
	var stam_ratio: float = clampf(current_stamina / max_stamina, 0.0, 1.0)
	draw_rect(Rect2(24, 20, 280, 26), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(24, 20, 280 * stam_ratio, 26), Color("#ff9f1c"))
	draw_string(font, Vector2(34, 39), "☀️ STAMINA: %d / %d" % [int(current_stamina), int(max_stamina)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(24, 72), "Clic Izq: Pala | Clic Der: Cubo (%.1fs) | Espacio: Tractor (%.1fs) | Ola: %.1fs" % [bucket_cooldown, tractor_cooldown, tide_timer if not surge_active else 0.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.LIGHT_GRAY)

	var c_text: String = "💶 %.1f EUR  |  💵 %.1f USD  |  💷 %.1f GBP  |  🪙 %.1f PEN" % [
		GameState.currencies["EUR"], GameState.currencies["USD"], GameState.currencies["GBP"], GameState.currencies["PEN"]
	]
	draw_string(font, Vector2(440, 34), c_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.GOLD)
	var fridge_text: String = "🍦 Nevera: %s  |  🍀 Suerte: x%.1f  |  🏅 %d/%d" % [GameState.get_fridge_summary(), GameState.get_luck_multiplier(), GameState.get_unlocked_achievements_count(), GameState.achievement_catalog.size()]
	draw_string(font, Vector2(440, 68), fridge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.AQUAMARINE)

	var bill: Dictionary = GameState.get_current_bill()
	draw_string(font, Vector2(910, 36), "🧾 CHIRINGUITO (Día %d/%d):" % [GameState.current_day, GameState.days_per_bill], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(910, 64), "%s -> %.0f €" % [bill["title"], bill["amount"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.SALMON)

	# 9. Textos flotantes de daño / combos / helados
	for ft in floating_texts:
		draw_string(font, ft["pos"], ft["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ft["color"])

	# 10. Cartel de Fin de Ronda
	if not round_active:
		draw_rect(Rect2(340, 240, 600, 180), Color(0.05, 0.08, 0.12, 0.92))
		draw_string(font, Vector2(420, 305), "🏖️ ¡DÍA TERMINADO! Te has quedado sin Stamina.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(font, Vector2(400, 355), "Pulsa [ESPACIO] para ir al Paseo Marítimo (Cambio y Chiringuito)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD)

	# 11. Banner Toast de Postal / Logro Desbloqueado (Issue #25)
	if toast_timer > 0.0:
		var t_rect := Rect2(380, 108, 520, 74)
		draw_rect(t_rect, Color(0.09, 0.14, 0.22, 0.96))
		draw_rect(t_rect, Color.GOLD, false, 3.0)
		draw_string(font, t_rect.position + Vector2(18, 28), "🏅 ¡POSTAL DESBLOQUEADA! (%s)  +1 🐚" % toast_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.GOLD)
		draw_string(font, t_rect.position + Vector2(18, 56), toast_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
