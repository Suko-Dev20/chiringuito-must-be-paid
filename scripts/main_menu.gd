extends Node2D
## Escena de Menú Principal "Cozy Beach" con Lluvia Interactiva de Monedas 2.5D ("Chiringuito Must Be Paid" - Issue #33)

var wave_time: float = 0.0
var hovered_btn: int = -1
var show_album_modal: bool = false
var bg_crabs: Array[Dictionary] = []
var menu_coins: Array[Dictionary] = []
var rain_timer: float = 0.4

var btn_rects: Array[Rect2] = [
	Rect2(420, 218, 440, 46), # 0: Continuar / Jugar
	Rect2(420, 272, 440, 44), # 1: Nueva Run (Día 1)
	Rect2(420, 324, 440, 44), # 2: Álbum de Postales y Récords (Issue #27)
	Rect2(420, 376, 440, 44), # 3: Radio Cassette Playera [R] (Issue #31)
	Rect2(420, 428, 440, 44), # 4: Volumen Master
	Rect2(420, 480, 440, 44), # 5: Pantalla Completa (F11)
	Rect2(420, 532, 440, 44)  # 6: Salir al Escritorio
]

var btn_close_album_rect := Rect2(500, 610, 280, 46)

func _ready() -> void:
	for i in range(6):
		bg_crabs.append({
			"pos": Vector2(randf_range(90, 1190), randf_range(190, 555)),
			"vel": Vector2(randf_range(-65, 65), randf_range(-25, 25))
		})
	for i in range(10):
		_spawn_menu_coin(Vector2(randf_range(70, 1210), randf_range(180, 560)), true)

func _spawn_menu_coin(ground_pos: Vector2, from_sky: bool) -> void:
	var codes: Array[String] = ["EUR", "USD", "GBP", "PEN"]
	var angle: float = randf() * TAU
	var spd: float = randf_range(30.0, 85.0) if from_sky else randf_range(80.0, 210.0)
	menu_coins.append({
		"pos": ground_pos,
		"vel": Vector2(cos(angle), sin(angle) * 0.7) * spd,
		"z": randf_range(360.0, 620.0) if from_sky else randf_range(16.0, 30.0),
		"vz": randf_range(-20.0, 30.0) if from_sky else randf_range(220.0, 360.0),
		"spin": randf() * TAU,
		"spin_speed": randf_range(9.0, 15.0),
		"bounces": 0,
		"ttl": randf_range(5.5, 8.5),
		"code": codes.pick_random()
	})

func _process(delta: float) -> void:
	wave_time += delta
	rain_timer -= delta
	if rain_timer <= 0.0 and menu_coins.size() < 26:
		rain_timer = 0.55
		# Lluvia suave de monedas a ambos lados de la playa en el menú
		var side_x: float = randf_range(60.0, 315.0) if randf() < 0.5 else randf_range(965.0, 1220.0)
		_spawn_menu_coin(Vector2(side_x, randf_range(170.0, 560.0)), true)

	for i in range(menu_coins.size() - 1, -1, -1):
		var mc: Dictionary = menu_coins[i]
		mc["ttl"] -= delta
		if mc["ttl"] <= 0.0:
			menu_coins.remove_at(i)
			continue
		var z: float = float(mc["z"])
		var vz: float = float(mc["vz"])
		if z > 0.0 or vz > 0.0:
			vz -= 880.0 * delta
			z += vz * delta
			mc["pos"] += mc["vel"] * delta
			mc["spin"] += float(mc["spin_speed"]) * delta
			if z <= 0.0:
				z = 0.0
				if vz < -60.0 and int(mc["bounces"]) < 3:
					vz = -vz * 0.54
					mc["vel"] *= 0.65
					mc["bounces"] = int(mc["bounces"]) + 1
				else:
					vz = 0.0
					mc["vel"] = Vector2.ZERO
		else:
			mc["spin"] += delta * 2.5
		mc["z"] = z
		mc["vz"] = vz

	for c in bg_crabs:
		c["pos"] += c["vel"] * delta
		if c["pos"].x < 80.0 or c["pos"].x > 1200.0:
			c["vel"].x *= -1.0
		if c["pos"].y < 160.0 or c["pos"].y > 580.0:
			c["vel"].y *= -1.0

	var mpos: Vector2 = get_viewport().get_mouse_position()
	hovered_btn = -1
	if not show_album_modal:
		for i in range(btn_rects.size()):
			if btn_rects[i].has_point(mpos):
				hovered_btn = i
				break
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and show_album_modal:
		show_album_modal = false
		queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
		if show_album_modal:
			if btn_close_album_rect.has_point(mpos):
				GameState.play_sfx("buy")
				show_album_modal = false
				queue_redraw()
			return

		for i in range(btn_rects.size()):
			if btn_rects[i].has_point(mpos):
				_on_button_pressed(i)
				return

		# Si haces clic en la arena fuera de los botones, ¡explota una fuente jugosa de monedas con física!
		GameState.play_sfx("coin", 0.95, 1.25)
		for k in range(6):
			_spawn_menu_coin(mpos, false)

func _on_button_pressed(idx: int) -> void:
	GameState.play_sfx("buy")
	match idx:
		0:
			get_tree().change_scene_to_file("res://scenes/main/beach_round.tscn")
		1:
			GameState.reset_run()
			get_tree().change_scene_to_file("res://scenes/main/beach_round.tscn")
		2:
			show_album_modal = true
		3:
			GameState.cycle_radio_station()
		4:
			GameState.cycle_volume()
		5:
			GameState.toggle_fullscreen()
		6:
			GameState.save_game()
			get_tree().quit()

func _draw_cozy_umbrella(center: Vector2, radius: float, col_a: Color, col_b: Color) -> void:
	var sway: Vector2 = Vector2(sin(wave_time * 1.6 + center.x * 0.01) * 3.0, 0.0)
	var u_pos: Vector2 = center + sway
	draw_circle(center + Vector2(8, 12), radius * 0.95, Color(0, 0, 0, 0.16))
	draw_circle(u_pos, radius, col_a)
	var segments: int = 8
	for s in range(segments):
		var a1: float = (TAU / segments) * s
		var a2: float = (TAU / segments) * (s + 1)
		var c_seg: Color = col_a if s % 2 == 0 else col_b
		var pts := PackedVector2Array([
			u_pos,
			u_pos + Vector2(cos(a1), sin(a1)) * radius,
			u_pos + Vector2(cos((a1 + a2) * 0.5), sin((a1 + a2) * 0.5)) * radius,
			u_pos + Vector2(cos(a2), sin(a2)) * radius
		])
		draw_colored_polygon(pts, c_seg)
	draw_arc(u_pos, radius, 0, TAU, 32, Color.WHITE, 2.0)
	draw_circle(u_pos, 5.0, Color("#fff8e7"))

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# 1. Arena Cálida Cozy y Olas con Espuma Ondulada
	draw_rect(Rect2(0, 0, 1280, 720), Color("#f6dca0"))
	draw_rect(Rect2(0, 0, 1280, 180), Color("#fbe9be"))
	draw_rect(Rect2(0, 460, 1280, 260), Color("#ebca84"))

	# Sombrillas y Toallas Cozy a los lados del menú
	draw_rect(Rect2(130, 160, 78, 42), Color("#ffcad4"))
	draw_rect(Rect2(144, 160, 16, 42), Color("#ff8fab"))
	draw_rect(Rect2(176, 160, 16, 42), Color("#ff8fab"))
	_draw_cozy_umbrella(Vector2(115, 175), 42.0, Color("#ff6b6b"), Color("#fff8e7"))

	draw_rect(Rect2(1070, 160, 78, 42), Color("#caf0f8"))
	draw_rect(Rect2(1084, 160, 16, 42), Color("#48cae4"))
	draw_rect(Rect2(1116, 160, 16, 42), Color("#48cae4"))
	_draw_cozy_umbrella(Vector2(1165, 175), 42.0, Color("#2ec4b6"), Color("#fff8e7"))

	var wave_y: float = 605.0 + sin(wave_time * 2.0) * 16.0
	draw_rect(Rect2(0, wave_y, 1280, 720 - wave_y), Color("#48cae4"))
	draw_rect(Rect2(0, wave_y + 26, 1280, 720 - wave_y), Color("#0096c7"))
	for wx in range(0, 1320, 40):
		var foam_y: float = wave_y + sin(wave_time * 3.0 + wx * 0.05) * 4.5
		draw_circle(Vector2(wx, foam_y), 24.0, Color(1, 1, 1, 0.88))

	# 2. Cangrejos Cozy paseando por la playa
	for c in bg_crabs:
		var p: Vector2 = c["pos"]
		draw_circle(p + Vector2(0, 8), 20.0, Color(0, 0, 0, 0.18))
		draw_circle(p + Vector2(-18, -12), 7.5, Color("#ef476f"))
		draw_circle(p + Vector2(18, -12), 7.5, Color("#ef476f"))
		draw_circle(p, 21.0, Color("#ef476f"))
		draw_circle(p + Vector2(-11, 2), 3.8, Color(1, 0.75, 0.8, 0.65))
		draw_circle(p + Vector2(11, 2), 3.8, Color(1, 0.75, 0.8, 0.65))
		draw_circle(p + Vector2(-7, -7), 4.5, Color.WHITE)
		draw_circle(p + Vector2(7, -7), 4.5, Color.WHITE)
		draw_circle(p + Vector2(-7, -7), 2.0, Color.BLACK)
		draw_circle(p + Vector2(7, -7), 2.0, Color.BLACK)

	# 2b. Monedas 2.5D cayendo y rebotando por la arena
	for mc in menu_coins:
		var gp: Vector2 = mc["pos"]
		var mz: float = float(mc["z"])
		var sh_scale: float = clampf(1.0 - (mz / 520.0), 0.3, 1.0)
		draw_circle(gp + Vector2(0, 4), 11.0 * sh_scale, Color(0, 0, 0, 0.22 * sh_scale))
		var cpos: Vector2 = gp + Vector2(0, -mz)
		var col: Color = Color("#ffd166") if mc["code"] == "EUR" else (Color("#52b788") if mc["code"] == "USD" else Color("#f4a261"))
		var spin_w: float = 0.45 + 0.55 * absf(cos(float(mc["spin"])))
		draw_circle(cpos, 12.0 * (0.85 + 0.15 * spin_w), col)
		draw_arc(cpos, 12.0 * (0.85 + 0.15 * spin_w), 0, TAU, 16, Color.WHITE, 1.6)
		draw_string(font, cpos + Vector2(-10, 4), mc["code"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#1d2d44"))

	if show_album_modal:
		_draw_album_modal(font)
		return

	# 3. Panel Central del Menú Principal con Toldo de Chiringuito Cozy
	draw_rect(Rect2(348, 56, 600, 600), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(340, 48, 600, 600), Color(0.09, 0.15, 0.23, 0.95))
	draw_rect(Rect2(340, 48, 600, 600), Color("#ffd166"), false, 3.0)
	for bx in range(340, 940, 30):
		var st_col: Color = Color("#e76f51") if ((bx - 340) / 30) % 2 == 0 else Color("#fff8e7")
		draw_rect(Rect2(bx, 48, 30, 10), st_col)

	draw_string(font, Vector2(395, 112), "🏖️ CHIRINGUITO MUST BE PAID", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#ffd166"))
	draw_string(font, Vector2(400, 146), "✨ Edición Cozy Beach — Cangrejos, Helados y Divisas ✨", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.AQUAMARINE)
	draw_string(font, Vector2(385, 188), "💶 Cartera: %.1f €  |  🐚 Conchas: %d  |  🏅 Postales: %d/%d" % [GameState.currencies["EUR"], GameState.golden_shells, GameState.get_unlocked_achievements_count(), GameState.achievement_catalog.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	var labels: Array[String] = [
		"▶️ CONTINUAR VERANEO (Día %d)" % GameState.current_day if GameState.has_saved_progress() else "▶️ EMPEZAR VERANEO (Día 1)",
		"🌞 NUEVA RUN (Reiniciar al Día 1 conservando 🐚)",
		"🏅 ÁLBUM DE POSTALES Y RÉCORDS (%d/%d)" % [GameState.get_unlocked_achievements_count(), GameState.achievement_catalog.size()],
		"🎵 RADIO CASSETTE [R]: %s" % GameState.get_radio_station_name(),
		"🔊 VOLUMEN GENERAL: %s" % ("MUTE" if GameState.master_volume_pct == 0 else "%d%%" % GameState.master_volume_pct),
		"🖥️ MODO DE PANTALLA (F11): %s" % ("PANTALLA COMPLETA" if GameState.is_fullscreen else "VENTANA"),
		"🚪 GUARDAR Y SALIR AL ESCRITORIO"
	]

	for i in range(btn_rects.size()):
		var r: Rect2 = btn_rects[i]
		var is_hov: bool = (i == hovered_btn)
		var base_col: Color = Color("#2a9d8f") if i == 0 else (Color("#b56576") if i == 2 else (Color("#3d5a80") if i == 3 else (Color("#e76f51") if i == 6 else Color("#1d3557"))))
		if is_hov:
			base_col = base_col.lightened(0.18)
		draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.25))
		draw_rect(r, base_col)
		draw_rect(r, Color("#ffd166") if is_hov else Color("#415a77"), false, 2.0)
		draw_string(font, r.position + Vector2(22, 28), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	draw_string(font, Vector2(368, 622), "💡 Haz clic en la arena para lanzar monedas | [R] Radio | [ESC] Menú", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e0e1dd"))

func _draw_album_modal(font: Font) -> void:
	draw_rect(Rect2(190, 45, 900, 630), Color(0.08, 0.14, 0.22, 0.97))
	draw_rect(Rect2(190, 45, 900, 630), Color("#ffd166"), false, 3.0)

	draw_string(font, Vector2(360, 92), "🏅 ÁLBUM DE POSTALES Y RÉCORDS DEL VERANEO", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#ffd166"))

	var st: Dictionary = GameState.lifetime_stats
	var stats_rect := Rect2(225, 112, 830, 82)
	draw_rect(stats_rect, Color("#14213d"))
	draw_rect(stats_rect, Color("#2ec4b6"), false, 1.5)
	draw_string(font, stats_rect.position + Vector2(18, 30), "🦀 Bichos Atrapados: %d   |   💶 Euros Históricos: %.1f €   |   🧾 Tickets Pagados: %d" % [
		int(st.get("total_crabs_caught", 0)), float(st.get("total_eur_earned", 0.0)), int(st.get("total_bills_paid", 0))
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(font, stats_rect.position + Vector2(18, 60), "🌞 Récord de Día: Día %d   |   💥 Mejor Combo: x%d   |   🐚 Conchas Doradas Actuales: %d" % [
		int(st.get("max_day_reached", 1)), int(st.get("best_combo", 1)), GameState.golden_shells
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.AQUAMARINE)

	for i in range(GameState.achievement_catalog.size()):
		var ach: Dictionary = GameState.achievement_catalog[i]
		var is_unlk: bool = GameState.unlocked_achievements.get(ach["id"], false)
		var col_idx: int = i % 2
		var row_idx: int = int(i / 2.0)
		var crect := Rect2(225.0 + col_idx * 422.0, 212.0 + row_idx * 94.0, 408, 82)

		draw_rect(crect, Color("#1d4e5f") if is_unlk else Color("#121c29"))
		draw_rect(crect, Color("#ffd166") if is_unlk else Color("#33415c"), false, 2.0 if is_unlk else 1.5)
		draw_string(font, crect.position + Vector2(14, 28), ach["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffd166") if is_unlk else Color.LIGHT_GRAY)
		draw_string(font, crect.position + Vector2(310, 28), "✅ +1 🐚" if is_unlk else "🔒 Pendiente", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.LIME_GREEN if is_unlk else Color.DARK_GRAY)
		draw_string(font, crect.position + Vector2(14, 56), ach["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE if is_unlk else Color.GRAY)

	draw_rect(btn_close_album_rect, Color("#2a9d8f"))
	draw_rect(btn_close_album_rect, Color("#ffd166"), false, 2.0)
	draw_string(font, btn_close_album_rect.position + Vector2(42, 30), "⬅️ VOLVER AL MENÚ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
