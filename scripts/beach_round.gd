extends Node2D
## Escena principal de la ronda en la playa ("La Orilla")
## Controla: Pala (Clic Izq), Cubo (Clic Der), Rastrillo (Imán al mover ratón) y Tractor.

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
	# Spawnear primeros cangrejos al empezar el día
	for i in range(4):
		spawn_crab()

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
	bucket_cooldown = bucket_max_cooldown
	var radius: float = GameState.get_shovel_radius() * 2.1
	_perform_strike(pos, radius, GameState.get_shovel_damage() * 1.8, 9.0, "¡CUBAZO!")

func _perform_strike(pos: Vector2, radius: float, base_dmg: float, stamina_cost: float, _label: String) -> void:
	current_stamina = maxf(0.0, current_stamina - stamina_cost)
	
	# Buscar cuántos cangrejos hay dentro del golpe (para la subrama de Multigolpe)
	var hit_indices: Array[int] = []
	for i in range(crabs.size()):
		if crabs[i]["pos"].distance_to(pos) <= radius + crabs[i]["radius"]:
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
	# Soltar monedas de turistas en la arena
	var drops: int = randi_range(2, 4)
	for i in range(drops):
		var currency_options: Array[String] = ["EUR", "USD", "GBP", "PEN"]
		var chosen_code: String = currency_options.pick_random()
		coins.append({
			"pos": crab["pos"] + Vector2(randf_range(-35, 35), randf_range(-25, 25)),
			"code": chosen_code,
			"value": randf_range(1.0, 3.0)
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
	tractor_cooldown = tractor_max_cooldown
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

# --- Spawner y Movimiento de Cangrejos ---

func _update_spawner(delta: float) -> void:
	spawn_timer -= delta
	var interval: float = maxf(0.35, 1.4 - (GameState.upgrades["crab_spawn_rate"] * 0.15))
	if spawn_timer <= 0.0 and crabs.size() < 18:
		spawn_crab()
		spawn_timer = interval

func spawn_crab() -> void:
	crabs.append({
		"pos": Vector2(randf_range(120, 1160), randf_range(160, 560)),
		"vel": Vector2(randf_range(-95, 95), randf_range(-40, 40)),
		"hp": 20.0,
		"max_hp": 20.0,
		"radius": 24.0,
		"hit_flash": 0.0
	})

func _update_crabs(delta: float) -> void:
	for c in crabs:
		c["pos"] += c["vel"] * delta
		if c["pos"].x < 90.0 or c["pos"].x > 1190.0:
			c["vel"].x *= -1.0
		if c["pos"].y < 140.0 or c["pos"].y > 580.0:
			c["vel"].y *= -1.0
		if c["hit_flash"] > 0.0:
			c["hit_flash"] = maxf(0.0, c["hit_flash"] - delta)

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
	# Convertimos automáticamente divisas extranjeras en la caseta y avanzamos de día
	var gained: float = GameState.exchange_all_to_eur()
	GameState.current_day += 1
	start_new_round()
	if gained > 0.0:
		_spawn_text(Vector2(640, 300), "💱 Caseta de Cambio: +%.1f €" % gained, Color.GOLD)

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

	# 3. Cangrejos
	for crab in crabs:
		var p: Vector2 = crab["pos"]
		var body_col: Color = Color.WHITE if crab["hit_flash"] > 0.0 else Color("#e63946")
		# Pinzas y cuerpo
		draw_circle(p + Vector2(-20, -14), 8.0, body_col)
		draw_circle(p + Vector2(20, -14), 8.0, body_col)
		draw_circle(p, crab["radius"], body_col)
		# Barra de vida del cangrejo
		var hp_ratio: float = clampf(crab["hp"] / crab["max_hp"], 0.0, 1.0)
		draw_rect(Rect2(p.x - 22, p.y - 36, 44, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p.x - 22, p.y - 36, 44 * hp_ratio, 6), Color.LIME_GREEN)

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
		draw_string(font, Vector2(395, 355), "Pulsa [ESPACIO] para cambiar divisas a € y empezar el siguiente día", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD)
