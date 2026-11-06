extends Node2D
## Escena de Menú Principal, Opciones, Radio Cassette y Álbum de Postales ("Chiringuito Must Be Paid" - Issue #20, #27 & #31)

var wave_time: float = 0.0
var hovered_btn: int = -1
var show_album_modal: bool = false
var bg_crabs: Array[Dictionary] = []

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
			"pos": Vector2(randf_range(100, 1180), randf_range(200, 560)),
			"vel": Vector2(randf_range(-70, 70), randf_range(-25, 25))
		})

func _process(delta: float) -> void:
	wave_time += delta
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

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# 1. Arena soleada y olas de fondo
	draw_rect(Rect2(0, 0, 1280, 720), Color("#f4d58d"))
	var wave_y: float = 605.0 + sin(wave_time * 2.0) * 18.0
	draw_rect(Rect2(0, wave_y, 1280, 720 - wave_y), Color("#2ec4b6"))
	draw_line(Vector2(0, wave_y), Vector2(1280, wave_y), Color.WHITE, 5.0)

	# 2. Cangrejos decorativos paseando por la playa
	for c in bg_crabs:
		var p: Vector2 = c["pos"]
		draw_circle(p + Vector2(0, 8), 20.0, Color(0, 0, 0, 0.2))
		draw_circle(p + Vector2(-18, -12), 7.0, Color("#e63946"))
		draw_circle(p + Vector2(18, -12), 7.0, Color("#e63946"))
		draw_circle(p, 21.0, Color("#e63946"))
		draw_circle(p + Vector2(-7, -7), 4.0, Color.WHITE)
		draw_circle(p + Vector2(7, -7), 4.0, Color.WHITE)
		draw_circle(p + Vector2(-7, -7), 2.0, Color.BLACK)
		draw_circle(p + Vector2(7, -7), 2.0, Color.BLACK)

	if show_album_modal:
		_draw_album_modal(font)
		return

	# 3. Panel Central del Menú Principal
	draw_rect(Rect2(340, 48, 600, 600), Color(0.06, 0.11, 0.17, 0.94))
	draw_rect(Rect2(340, 48, 600, 600), Color.GOLD, false, 3.0)

	draw_string(font, Vector2(395, 108), "🏖️ CHIRINGUITO MUST BE PAID", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.GOLD)
	draw_string(font, Vector2(405, 144), "Incremental Playero de Cangrejos, Helados y Divisas", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.AQUAMARINE)
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
		draw_rect(r, base_col)
		draw_rect(r, Color.GOLD if is_hov else Color("#415a77"), false, 2.0)
		draw_string(font, r.position + Vector2(22, 28), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	draw_string(font, Vector2(385, 622), "💡 Pulsa [R] para cambiar de emisora de radio o [ESC] para volver al menú", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.LIGHT_GRAY)

func _draw_album_modal(font: Font) -> void:
	draw_rect(Rect2(190, 45, 900, 630), Color(0.06, 0.11, 0.17, 0.96))
	draw_rect(Rect2(190, 45, 900, 630), Color.GOLD, false, 3.0)

	draw_string(font, Vector2(360, 92), "🏅 ÁLBUM DE POSTALES Y RÉCORDS DEL VERANEO", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.GOLD)

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
		draw_rect(crect, Color.GOLD if is_unlk else Color("#33415c"), false, 2.0 if is_unlk else 1.5)
		draw_string(font, crect.position + Vector2(14, 28), ach["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD if is_unlk else Color.LIGHT_GRAY)
		draw_string(font, crect.position + Vector2(310, 28), "✅ +1 🐚" if is_unlk else "🔒 Pendiente", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.LIME_GREEN if is_unlk else Color.DARK_GRAY)
		draw_string(font, crect.position + Vector2(14, 56), ach["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE if is_unlk else Color.GRAY)

	draw_rect(btn_close_album_rect, Color("#2a9d8f"))
	draw_rect(btn_close_album_rect, Color.GOLD, false, 2.0)
	draw_string(font, btn_close_album_rect.position + Vector2(42, 30), "⬅️ VOLVER AL MENÚ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
