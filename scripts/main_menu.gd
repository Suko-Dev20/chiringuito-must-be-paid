extends Node2D
## Escena de Menú Principal y Opciones ("Chiringuito Must Be Paid" - Issue #20)

var wave_time: float = 0.0
var hovered_btn: int = -1
var bg_crabs: Array[Dictionary] = []

var btn_rects: Array[Rect2] = [
	Rect2(420, 270, 440, 56), # 0: Continuar / Jugar
	Rect2(420, 342, 440, 52), # 1: Nueva Run (Día 1)
	Rect2(420, 410, 440, 52), # 2: Volumen Master
	Rect2(420, 478, 440, 52), # 3: Pantalla Completa (F11)
	Rect2(420, 546, 440, 52)  # 4: Salir al Escritorio
]

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
	for i in range(btn_rects.size()):
		if btn_rects[i].has_point(mpos):
			hovered_btn = i
			break
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
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
			GameState.cycle_volume()
		3:
			GameState.toggle_fullscreen()
		4:
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

	# 3. Panel Central del Menú Principal
	draw_rect(Rect2(340, 65, 600, 575), Color(0.06, 0.11, 0.17, 0.94))
	draw_rect(Rect2(340, 65, 600, 575), Color.GOLD, false, 3.0)

	draw_string(font, Vector2(395, 130), "🏖️ CHIRINGUITO MUST BE PAID", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.GOLD)
	draw_string(font, Vector2(405, 168), "Incremental Playero de Cangrejos, Helados y Divisas", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.AQUAMARINE)
	draw_string(font, Vector2(430, 215), "💶 Cartera: %.1f €   |   🐚 Conchas Doradas: %d" % [GameState.currencies["EUR"], GameState.golden_shells], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

	var labels: Array[String] = [
		"▶️ CONTINUAR VERANEO (Día %d)" % GameState.current_day if GameState.has_saved_progress() else "▶️ EMPEZAR VERANEO (Día 1)",
		"🌞 NUEVA RUN (Reiniciar al Día 1 conservando 🐚)",
		"🔊 VOLUMEN DE SONIDO: %s" % ("MUTE" if GameState.master_volume_pct == 0 else "%d%%" % GameState.master_volume_pct),
		"🖥️ MODO DE PANTALLA (F11): %s" % ("PANTALLA COMPLETA" if GameState.is_fullscreen else "VENTANA"),
		"🚪 GUARDAR Y SALIR AL ESCRITORIO"
	]

	for i in range(btn_rects.size()):
		var r: Rect2 = btn_rects[i]
		var is_hov: bool = (i == hovered_btn)
		var base_col: Color = Color("#2a9d8f") if i == 0 else (Color("#e76f51") if i == 4 else Color("#1d3557"))
		if is_hov:
			base_col = base_col.lightened(0.18)
		draw_rect(r, base_col)
		draw_rect(r, Color.GOLD if is_hov else Color("#415a77"), false, 2.0)
		draw_string(font, r.position + Vector2(24, 33), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	draw_string(font, Vector2(435, 622), "💡 Pulsa [ESC] en cualquier momento para volver a este menú", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.LIGHT_GRAY)
