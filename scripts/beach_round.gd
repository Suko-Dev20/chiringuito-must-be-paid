extends Node2D
## Escena principal de la ronda en la playa ("La Orilla")
## Controla: Pala (Clic Izq), Cubo (Clic Der), Rastrillo (Imán al mover ratón), Tractor y Fauna Marina.

var current_stamina: float = 100.0
var max_stamina: float = 100.0
var round_active: bool = true

# Cooldowns
var bucket_cooldown: float = 0.0
var bucket_max_cooldown: float = 3.0
var tractor_cooldown: float = 0.0
var tractor_max_cooldown: float = 12.0

# Contenedores en memoria de los bichos y monedas activos en la arena
var crabs: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []

# Animación del Tractor Limpia-Playas
var tractor_active: bool = false
var tractor_x: float = -150.0

var spawn_timer: float = 0.0
var wave_time: float = 0.0

func _ready() -> void:
	start_new_round()

func start_new_round() -> void:
	max_stamina = GameState.get_max_stamina()
	current_stamina = max_stamina
	round_active = true
	crabs.clear()
	coins.clear()
	floating_texts.clear()
	# Spawnear primeros bichos al empezar el día
	for i in range(4):
		spawn_crab("crab")
	spawn_crab("clam")

func _process(delta: float) -> void:
	wave_time += delta
	if round_active:
		_update_spawner(delta)
		_update_crabs(delta)
		_update_coins_and_rake(delta)
		_update_cooldowns(delta)
	_update_tractor(delta)
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

# --- Mecánicas de Herramientas ---

func _use_shovel(pos: Vector2) -> void:
	var radius: float = GameState.get_shovel_radius()
	_perform_strike(pos, radius, GameState.get_shovel_damage(), 4.5, "Pala")

func _use_bucket(pos: Vector2) -> void:
	if bucket_cooldown > 0.0:
		_spawn_text(pos, "¡Cubo recargando!", Color.ORANGE)
		return
	bucket_cooldown = maxf(0.8, bucket_max_cooldown - (GameState.upgrades["unlock_bucket"] * 0.4))
	var radius: float = GameState.get_shovel_radius() * (1.9 + GameState.upgrades["unlock_bucket"] * 0.15)
	var dmg_mult: float = 1.6 + (GameState.upgrades["unlock_bucket"] * 0.35)
	_perform_strike(pos, radius, GameState.get_shovel_damage() * dmg_mult, 9.0, "¡CUBAZO!")

func _perform_strike(pos: Vector2, radius: float, base_dmg: float, stamina_cost: float, _label: String) -> void:
	current_stamina = maxf(0.0, current_stamina - stamina_cost)
	
	# Pasivo por Suerte: "Cohete Tricolor" (onda expansiva gratis con +60% de radio)
	var actual_radius: float = radius
	var rocket_proc: bool = randf() < (GameState.upgrades["ice_cream_rocket"] * 0.10)
	if rocket_proc:
		actual_radius *= 1.6
		_spawn_text(pos + Vector2(0, -55), "🚀 ¡COHETE TRICOLOR! Onda Expansiva", Color.DEEP_PINK)

	# Buscar cuántos bichos hay dentro del golpe (para la subrama de Multigolpe)
	var hit_indices: Array[int] = []
	for i in range(crabs.size()):
		if crabs[i]["pos"].distance_to(pos) <= actual_radius + crabs[i]["radius"]:
			hit_indices.append(i)

	var multi_mult: float = GameState.get_multi_hit_multiplier(hit_indices.size())
	var is_crit: bool = randf() < GameState.get_crit_chance() or (hit_indices.size() >= 3)
	var final_dmg: float = base_dmg * multi_mult * (2.0 if is_crit else 1.0)

	if hit_indices.size() >= 2:
		_spawn_text(pos + Vector2(0, -35), "¡COMBO x%d!" % hit_indices.size(), Color.CYAN)

	# Aplicar daño de atrás hacia adelante por si mueren y los borramos del array
	hit_indices.reverse()
	for idx in hit_indices:
		var crab: Dictionary = crabs[idx]
		crab["hp"] -= final_dmg
		crab["hit_flash"] = 0.15
		var dmg_text: String = "%d%s" % [int(final_dmg), " ¡CRIT!" if is_crit else ""]
		_spawn_text(crab["pos"] + Vector2(randf_range(-15, 15), -20), dmg_text, Color.YELLOW if is_crit else Color.WHITE)
		
		if crab["hp"] <= 0.0:
			_on_crab_caught(crab)
			crabs.remove_at(idx)

	if current_stamina <= 0.0:
		round_active = false
		_spawn_text(Vector2(640, 320), "¡AGOTADO POR EL SOL! Fin del Día", Color.ORANGE_RED)

func _on_crab_caught(crab: Dictionary) -> void:
	# Soltar monedas de turistas en la arena según el tipo de fauna marina y "Playa Internacional"
	var extra_drops: int = GameState.upgrades["tourist_currencies"]
	var kind: String = crab.get("kind", "crab")
	var base_min: int = 2
	var base_max: int = 4
	var kind_val_mult: float = 1.0
	var spread: float = 35.0

	if kind == "clam":
		base_min = 3
		base_max = 5
		kind_val_mult = 1.6
		_spawn_text(crab["pos"] + Vector2(0, -32), "🐚 ¡Coquina desenterrada!", Color.AQUA)
	elif kind == "octopus":
		base_min = 7
		base_max = 10
		kind_val_mult = 1.4
		spread = 65.0
		_spawn_text(crab["pos"] + Vector2(0, -45), "🐙 ¡EXPLOSIÓN DE DIVISAS TURISTAS!", Color.VIOLET)
	elif kind == "lobster":
		base_min = 5
		base_max = 7
		kind_val_mult = 3.0
		spread = 50.0
		_spawn_text(crab["pos"] + Vector2(0, -45), "🦞 ¡LANGOSTA DORADA! Botín x3", Color.GOLD)

	var drops: int = randi_range(base_min, base_max) + int(extra_drops / 2.0)
	var val_boost: float = (1.0 + (extra_drops * 0.25)) * kind_val_mult
	for i in range(drops):
		var currency_options: Array[String] = ["EUR", "USD", "GBP", "PEN"]
		var chosen_code: String = currency_options.pick_random()
		coins.append({
			"pos": crab["pos"] + Vector2(randf_range(-spread, spread), randf_range(-spread * 0.7, spread * 0.7)),
			"code": chosen_code,
			"value": randf_range(1.0, 3.0) * val_boost
		})

	# Pasivo de Helado por Suerte ("Pie Helado")
	if randf() < GameState.get_foot_ice_cream_chance() + 0.15: # 15% base de muestra en el prototipo
		current_stamina = minf(max_stamina, current_stamina + 6.0)
		_spawn_text(crab["pos"] + Vector2(0, -40), "🦶 ¡Pie Helado! +6 Stamina", Color.AQUAMARINE)

# --- Rastrillo (Recogida al mover el ratón) y Tractor ---

func _update_coins_and_rake(delta: float) -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var rake_r: float = GameState.get_rake_radius()
	for i in range(coins.size() - 1, -1, -1):
		var c: Dictionary = coins[i]
		var dist: float = c["pos"].distance_to(mouse_pos)
		if dist <= rake_r:
			# El rastrillo atrae la moneda hacia el cursor
			c["pos"] = c["pos"].move_toward(mouse_pos, 420.0 * delta)
			if dist <= 18.0:
				_collect_coin(c)
				coins.remove_at(i)

func _use_tractor() -> void:
	if tractor_cooldown > 0.0 or tractor_active:
		return
	tractor_active = true
	tractor_x = -120.0
	tractor_cooldown = maxf(3.0, tractor_max_cooldown - (GameState.upgrades["tractor_cooldown"] * 1.8))
	_spawn_text(Vector2(640, 260), "🚜 ¡TRACTOR LIMPIA-PLAYAS EN MARCHA!", Color.GOLD)

func _update_tractor(delta: float) -> void:
	if not tractor_active:
		return
	tractor_x += 900.0 * delta
	for i in range(coins.size() - 1, -1, -1):
		if coins[i]["pos"].x <= tractor_x + 60.0:
			_collect_coin(coins[i])
			coins.remove_at(i)
	if tractor_x > 1400.0:
		tractor_active = false

func _collect_coin(c: Dictionary) -> void:
	GameState.add_currency(c["code"], snappedf(c["value"], 0.5))
	_spawn_text(c["pos"], "+%.1f %s" % [c["value"], c["code"]], Color.GREEN_YELLOW)

# --- Spawner y Comportamientos de Fauna Marina (Issue #3) ---

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
			kind = "lobster"  # 8% Langosta Dorada (rara y veloz)
		elif roll < 0.22:
			kind = "octopus"  # 14% Pulpo Turista (tanque ideal para el Cubo)
		elif roll < 0.45:
			kind = "clam"     # 23% Almeja / Coquina (se entierra rápido)
		else:
			kind = "crab"     # 55% Cangrejo Común

	if kind == "clam":
		crabs.append({
			"kind": "clam",
			"pos": Vector2(randf_range(120, 1160), randf_range(430, 565)),
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
	for i in range(crabs.size() - 1, -1, -1):
		var c: Dictionary = crabs[i]
		var kind: String = c.get("kind", "crab")
		c["pos"] += c["vel"] * delta

		if c["hit_flash"] > 0.0:
			c["hit_flash"] = maxf(0.0, c["hit_flash"] - delta)

		# Comportamiento específico de Almeja / Coquina (se entierra en la arena)
		if kind == "clam":
			c["bury_timer"] -= delta
			if c["bury_timer"] <= 0.0:
				_spawn_text(c["pos"], "🐚 ¡Se enterró!", Color.LIGHT_SKY_BLUE)
				crabs.remove_at(i)
				continue

		# Comportamiento de Langosta Dorada (cruza la playa y escapa si llega al otro borde)
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
	# Pasamos a la escena Entre Rondas (Caseta de Cambio + Chiringuito + Mejoras)
	get_tree().change_scene_to_file("res://scenes/main/between_days.tscn")

# --- Renderizado Visual (Prototipo sin depender de imágenes externas) ---

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# 1. Arena de la playa y Orilla con ola animada
	draw_rect(Rect2(0, 0, 1280, 720), Color("#f4d58d"))
	var wave_y: float = 610.0 + sin(wave_time * 2.2) * 18.0
	draw_rect(Rect2(0, wave_y, 1280, 720 - wave_y), Color("#2ec4b6"))
	draw_line(Vector2(0, wave_y), Vector2(1280, wave_y), Color.WHITE, 4.0)

	# 2. Monedas en la arena
	for c in coins:
		var col: Color = Color.GOLD if c["code"] == "EUR" else Color.LIGHT_GREEN
		draw_circle(c["pos"], 11.0, col)
		draw_string(font, c["pos"] + Vector2(-12, 4), c["code"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)

	# 3. Fauna Marina (Cangrejos, Almejas, Pulpos Turistas y Langostas Doradas)
	for crab in crabs:
		var p: Vector2 = crab["pos"]
		var kind: String = crab.get("kind", "crab")
		var flash: bool = crab["hit_flash"] > 0.0

		if kind == "clam":
			var col: Color = Color.WHITE if flash else Color("#48cae4")
			draw_circle(p, crab["radius"], col)
			draw_arc(p, crab["radius"], PI, TAU, 16, Color("#0077b6"), 3.0)
			# Barra de tiempo antes de que se entierre
			var bury_ratio: float = clampf(crab["bury_timer"] / crab["max_bury"], 0.0, 1.0)
			draw_rect(Rect2(p.x - 20, p.y + 22, 40, 5), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(p.x - 20, p.y + 22, 40 * bury_ratio, 5), Color.ORANGE)
		elif kind == "octopus":
			var col: Color = Color.WHITE if flash else Color("#9b5de5")
			# Tentáculos animados alrededor del Pulpo Turista
			for t in range(6):
				var angle: float = (TAU / 6.0) * t + sin(wave_time * 3.5 + t) * 0.25
				var t_pos: Vector2 = p + Vector2(cos(angle), sin(angle)) * 34.0
				draw_circle(t_pos, 10.0, col)
			draw_circle(p, crab["radius"], col)
			draw_string(font, p + Vector2(-14, 6), "🐙", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		elif kind == "lobster":
			var col: Color = Color.WHITE if flash else Color("#ffb703")
			draw_circle(p + Vector2(-14, 0), 16.0, col)
			draw_circle(p + Vector2(14, 0), 16.0, col)
			draw_circle(p, crab["radius"], col)
			draw_arc(p, crab["radius"] + 3.0, 0, TAU, 24, Color.GOLD, 2.0)
		else:
			var body_col: Color = Color.WHITE if flash else Color("#e63946")
			draw_circle(p + Vector2(-20, -14), 8.0, body_col)
			draw_circle(p + Vector2(20, -14), 8.0, body_col)
			draw_circle(p, crab["radius"], body_col)

		# Barra de vida
		var hp_ratio: float = clampf(crab["hp"] / crab["max_hp"], 0.0, 1.0)
		var bar_w: float = crab["radius"] * 1.8
		draw_rect(Rect2(p.x - bar_w * 0.5, p.y - crab["radius"] - 14, bar_w, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p.x - bar_w * 0.5, p.y - crab["radius"] - 14, bar_w * hp_ratio, 6), Color.LIME_GREEN)

	# 4. Tractor Limpia-Playas
	if tractor_active:
		draw_rect(Rect2(tractor_x, 120, 70, 480), Color(0.95, 0.75, 0.1, 0.85))
		draw_string(font, Vector2(tractor_x + 8, 360), "🚜 TRACTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)

	# 5. Círculo del cursor (Pala + Radio del Rastrillo)
	var mpos: Vector2 = get_viewport().get_mouse_position()
	draw_arc(mpos, GameState.get_shovel_radius(), 0, TAU, 32, Color(1, 0.2, 0.2, 0.7), 2.5)
	draw_arc(mpos, GameState.get_rake_radius(), 0, TAU, 32, Color(1, 0.9, 0.2, 0.35), 1.5)

	# 6. HUD Superior (Stamina, Divisas y Ticket del Chiringuito)
	draw_rect(Rect2(0, 0, 1280, 95), Color(0.08, 0.12, 0.18, 0.9))
	var stam_ratio: float = clampf(current_stamina / max_stamina, 0.0, 1.0)
	draw_rect(Rect2(24, 20, 280, 26), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(24, 20, 280 * stam_ratio, 26), Color("#ff9f1c"))
	draw_string(font, Vector2(34, 39), "☀️ STAMINA: %d / %d" % [int(current_stamina), int(max_stamina)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(24, 72), "Clic Izq: Pala | Clic Der: Cubo (%.1fs) | Espacio: Tractor (%.1fs) | Mover ratón: Rastrillo" % [bucket_cooldown, tractor_cooldown], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.LIGHT_GRAY)

	var c_text: String = "💶 %.1f EUR  |  💵 %.1f USD  |  💷 %.1f GBP  |  🪙 %.1f PEN" % [
		GameState.currencies["EUR"], GameState.currencies["USD"], GameState.currencies["GBP"], GameState.currencies["PEN"]
	]
	draw_string(font, Vector2(460, 38), c_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.GOLD)

	var bill: Dictionary = GameState.get_current_bill()
	draw_string(font, Vector2(900, 36), "🧾 CHIRINGUITO (Día %d/%d):" % [GameState.current_day, GameState.days_per_bill], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(900, 64), "%s -> %.0f €" % [bill["title"], bill["amount"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.SALMON)

	# 7. Textos flotantes de daño / combos / helados
	for ft in floating_texts:
		draw_string(font, ft["pos"], ft["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ft["color"])

	# 8. Cartel de Fin de Ronda
	if not round_active:
		draw_rect(Rect2(340, 240, 600, 180), Color(0.05, 0.08, 0.12, 0.92))
		draw_string(font, Vector2(420, 305), "🏖️ ¡DÍA TERMINADO! Te has quedado sin Stamina.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(font, Vector2(400, 355), "Pulsa [ESPACIO] para ir al Paseo Marítimo (Cambio y Chiringuito)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD)
