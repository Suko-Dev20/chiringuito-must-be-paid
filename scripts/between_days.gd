extends Node2D
## Escena Entre Rondas ("El Paseo Marítimo"):
## 1. Caseta de Cambio con Mercado Dinámico (ALZA / BAJA) y venta individual por divisa (Issue #18)
## 2. Árbol de Habilidades Visual (Grafo 2D de Nodos conectados por líneas con Pan/Arrastre y Tooltips - Issue #19)
## 3. Tienda Permanente de Prestigio y Álbum de Postales + Estadísticas Globales (Issue #25 & #27)

var bill_paid_today: bool = false
var bankruptcy_state: bool = false
var status_message: String = ""
var status_color: Color = Color.GOLD

# 0 = Grafo Visual de Nodos (Issue #19), 1 = Tienda Permanente de Prestigio, 2 = Álbum de Postales y Estadísticas (Issue #27)
var view_mode: int = 0

# Notificación Toast de Postal Desbloqueada (Issue #25)
var toast_timer: float = 0.0
var toast_title: String = ""
var toast_desc: String = ""

# Pan / Arrastre del Grafo Visual
var pan_offset := Vector2(35, -15)
var is_panning: bool = false
var pan_start_mouse := Vector2.ZERO
var drag_accum: float = 0.0
var hovered_node_id: String = ""

var graph_panel_rect := Rect2(385, 105, 875, 600)
var tab_graph_rect := Rect2(395, 112, 265, 40)
var tab_prestige_rect := Rect2(668, 112, 225, 40)
var tab_postcards_rect := Rect2(901, 112, 200, 40)
var btn_center_graph_rect := Rect2(1109, 112, 138, 40)

var btn_exchange_rect := Rect2(30, 520, 330, 50)
var btn_pay_bill_rect := Rect2(30, 585, 330, 50)
var btn_next_day_rect := Rect2(30, 645, 330, 54)
var btn_wipe_save_rect := Rect2(955, 625, 280, 44)

var upgrade_card_rects: Array[Dictionary] = []
var single_exchange_rects: Array[Dictionary] = []
var graph_node_Screen_positions: Dictionary = {}

# Posiciones 2D relativas al centro del grafo para los 17 nodos (4 cuadrantes por rama)
var node_graph_coords: Dictionary = {
	# Cuadrante Arriba-Izquierda: Rama 1 (Herramientas y Críticos)
	"shovel_damage": Vector2(-115, -60),
	"shovel_radius": Vector2(-235, -130),
	"unlock_bucket": Vector2(-355, -165),
	"crit_chance": Vector2(-235, -35),
	"multi_hit_bonus": Vector2(-360, -35),
	"rake_magnet": Vector2(-115, 25),

	# Cuadrante Arriba-Derecha: Rama 2 (Playa, Tractor y Automatización)
	"crab_spawn_rate": Vector2(115, -60),
	"unlock_tractor": Vector2(240, -140),
	"tractor_cooldown": Vector2(360, -165),
	"auto_nephew": Vector2(245, -50),
	"crab_trap": Vector2(365, -50),
	"auto_seagull": Vector2(245, 30),

	# Cuadrante Abajo-Izquierda: Rama 3 (Kiosco de Helados y Suerte)
	"max_stamina": Vector2(-115, 105),
	"global_luck": Vector2(-240, 95),
	"ice_cream_magnum": Vector2(-365, 95),
	"ice_cream_foot": Vector2(-225, 175),
	"ice_cream_rocket": Vector2(-345, 170),
	"ice_cream_shark": Vector2(-460, 170),
	"ice_cream_vampire": Vector2(-345, 240),

	# Cuadrante Abajo-Derecha: Rama 4 (Turismo y Divisas)
	"tourist_currencies": Vector2(115, 105),
	"exchange_rate_boost": Vector2(250, 155)
}

func _ready() -> void:
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)
	GameState.save_game()
	bill_paid_today = not GameState.is_bill_due_today()
	bankruptcy_state = false
	if GameState.is_bill_due_today():
		status_message = "⚠️ ¡HOY VENCE EL TICKET DEL CHIRINGUITO! Cambia divisas y paga la cuenta. (💾 Autoguardado)"
		status_color = Color.ORANGE_RED
	else:
		status_message = "🕸️ Explora el Árbol Visual de Nodos o revisa tu Álbum de Postales y Estadísticas."
		status_color = Color.AQUAMARINE

func _on_achievement_unlocked(title: String, desc: String) -> void:
	toast_title = title
	toast_desc = desc
	toast_timer = 4.0
	queue_redraw()

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - delta)
		if toast_timer == 0.0:
			queue_redraw()

	if view_mode == 0:
		var mpos: Vector2 = get_viewport().get_mouse_position()
		var new_hover: String = ""
		if graph_panel_rect.has_point(mpos):
			for id in graph_node_Screen_positions.keys():
				if mpos.distance_to(graph_node_Screen_positions[id]) <= 30.0:
					new_hover = id
					break
		if new_hover != hovered_node_id:
			hovered_node_id = new_hover
			queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_panning and view_mode == 0:
		pan_offset += event.relative
		pan_offset.x = clampf(pan_offset.x, -260.0, 280.0)
		pan_offset.y = clampf(pan_offset.y, -210.0, 210.0)
		drag_accum += event.relative.length()
		queue_redraw()
		return

	if event is InputEventMouseButton:
		var mpos: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_RIGHT and graph_panel_rect.has_point(mpos):
			is_panning = event.pressed
			drag_accum = 0.0
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Pestañas superiores del panel derecho
				if tab_graph_rect.has_point(mpos):
					view_mode = 0
					queue_redraw()
					return
				elif tab_prestige_rect.has_point(mpos):
					view_mode = 1
					queue_redraw()
					return
				elif tab_postcards_rect.has_point(mpos):
					view_mode = 2
					queue_redraw()
					return
				elif btn_center_graph_rect.has_point(mpos) and view_mode == 0:
					pan_offset = Vector2(35, -15)
					queue_redraw()
					return

				# Botones individuales de venta por divisa
				for sbtn in single_exchange_rects:
					if sbtn["rect"].has_point(mpos):
						_on_single_exchange_pressed(sbtn["code"])
						return

				if view_mode == 1 and btn_wipe_save_rect.has_point(mpos):
					GameState.delete_save_and_reset_all()
					status_message = "🗑️ Partida guardada borrada por completo. Todo reiniciado desde cero."
					status_color = Color.ORANGE
					queue_redraw()
					return

				if view_mode == 1:
					for card in upgrade_card_rects:
						if card["rect"].has_point(mpos):
							_on_prestige_clicked(card["id"])
							return

				if btn_exchange_rect.has_point(mpos):
					_on_exchange_pressed()
					return
				elif btn_pay_bill_rect.has_point(mpos) and GameState.is_bill_due_today() and not bill_paid_today:
					_on_pay_bill_pressed()
					return
				elif btn_next_day_rect.has_point(mpos):
					_on_next_action_pressed()
					return

				# Iniciar arrastre o clic en el grafo visual
				if view_mode == 0 and graph_panel_rect.has_point(mpos):
					is_panning = true
					drag_accum = 0.0
					pan_start_mouse = mpos
			else:
				# Al soltar el botón izquierdo en el grafo: si no arrastró, comprobar clic en nodo
				if is_panning and view_mode == 0:
					is_panning = false
					if drag_accum < 8.0:
						for id in graph_node_Screen_positions.keys():
							if mpos.distance_to(graph_node_Screen_positions[id]) <= 30.0:
								_on_upgrade_clicked(id)
								return

func _on_single_exchange_pressed(code: String) -> void:
	var gained: float = GameState.exchange_single_currency_to_eur(code)
	if gained <= 0.0:
		status_message = "💱 No tienes %s para vender hoy." % code
		status_color = Color.LIGHT_GRAY
	else:
		status_message = "💱 ¡Vendidos tus %s por +%.1f € a la cotización de hoy (%s)!" % [code, gained, GameState.get_market_trend_text(code)]
		status_color = Color.GREEN_YELLOW
	queue_redraw()

func _on_upgrade_clicked(id: String) -> void:
	if not GameState.is_upgrade_unlocked(id):
		status_message = "🔒 Nodo bloqueado: compra primero al menos 1 nivel del nodo padre conectado."
		status_color = Color.ORANGE
		queue_redraw()
		return
	var cost: float = GameState.get_upgrade_cost(id)
	if GameState.buy_upgrade(id):
		status_message = "✨ ¡Nodo mejorado por %.1f €! Nevera: %s" % [cost, GameState.get_fridge_summary()]
		status_color = Color.LIME_GREEN
	else:
		status_message = "❌ No tienes suficientes Euros (%.1f € requeridos) o ya está al nivel máximo." % cost
		status_color = Color.SALMON
	queue_redraw()

func _on_prestige_clicked(id: String) -> void:
	var cost: int = GameState.get_prestige_cost(id)
	if GameState.buy_prestige_upgrade(id):
		status_message = "🐚 ¡Mejora PERMANENTE adquirida y guardada por %d Concha(s) Dorada(s)!" % cost
		status_color = Color.GOLD
	else:
		status_message = "❌ Necesitas %d 🐚 Conchas Doradas (o ya alcanzaste el nivel máximo)." % cost
		status_color = Color.SALMON
	queue_redraw()

func _on_exchange_pressed() -> void:
	var pending: float = GameState.get_pending_foreign_eur_value()
	if pending <= 0.0:
		status_message = "💱 No tienes divisas extranjeras pendientes de cambiar."
		status_color = Color.LIGHT_GRAY
	else:
		var gained: float = GameState.exchange_all_to_eur()
		status_message = "💱 ¡Cambio total realizado! Has recibido +%.1f € en la Caseta." % gained
		status_color = Color.GREEN_YELLOW
	queue_redraw()

func _on_pay_bill_pressed() -> void:
	var bill: Dictionary = GameState.get_current_bill()
	if GameState.currencies["EUR"] < bill["amount"] and GameState.get_pending_foreign_eur_value() > 0.0:
		status_message = "💡 ¡Vende primero tus divisas extranjeras a Euros en la Caseta!"
		status_color = Color.GOLD
		queue_redraw()
		return

	if GameState.pay_current_bill():
		bill_paid_today = true
		status_message = "✅ ¡Cuenta pagada! +1 🐚 Concha Dorada de prestigio (💾 Progreso guardado)."
		status_color = Color.LIME_GREEN
	else:
		bankruptcy_state = true
		var earned_shells: int = GameState.award_bankruptcy_shells()
		view_mode = 1
		status_message = "🐚 ¡FIN DE VERANEO! Has ganado +%d Concha(s) Dorada(s) (💾 Guardado)." % earned_shells
		status_color = Color.GOLD
	queue_redraw()

func _on_next_action_pressed() -> void:
	if bankruptcy_state:
		GameState.reset_run()
		get_tree().change_scene_to_file("res://scenes/main/beach_round.tscn")
		return

	if not bill_paid_today:
		status_message = "⚠️ ¡No puedes ir al siguiente día sin pagar el Ticket del Chiringuito de hoy!"
		status_color = Color.ORANGE_RED
		queue_redraw()
		return

	GameState.current_day += 1
	GameState.roll_daily_market()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/main/beach_round.tscn")

func _get_branch_color(branch: int) -> Color:
	match branch:
		0: return Color("#ff6b6b") # Herramientas / Críticos
		1: return Color("#2ec4b6") # Playa / Tractor / Automatización
		2: return Color("#c77dff") # Helados / Suerte
		_: return Color("#ffd166") # Turismo / Divisas

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	upgrade_card_rects.clear()
	single_exchange_rects.clear()
	graph_node_Screen_positions.clear()

	# Fondo general del Paseo Marítimo
	draw_rect(Rect2(0, 0, 1280, 720), Color("#1b263b"))
	draw_rect(Rect2(0, 0, 1280, 88), Color("#0d1b2a"))

	# Cabecera
	draw_string(font, Vector2(30, 38), "🌅 FIN DEL DÍA %d — PASEO MARÍTIMO & ÁRBOL VISUAL DE NODOS" % GameState.current_day, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	draw_string(font, Vector2(30, 68), status_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, status_color)
	draw_string(font, Vector2(735, 50), "💶 %.1f €  |  🐚 %d Conchas  |  🏅 %d/%d Postales" % [GameState.currencies["EUR"], GameState.golden_shells, GameState.get_unlocked_achievements_count(), GameState.achievement_catalog.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.GOLD)

	# --- COLUMNA IZQUIERDA: CASETA DE CAMBIO CON MERCADO DINÁMICO ---
	draw_rect(Rect2(20, 105, 350, 600), Color("#0d1b2a"))
	draw_rect(Rect2(20, 105, 350, 600), Color("#415a77"), false, 2.0)

	draw_string(font, Vector2(30, 134), "💱 BOLSA TURÍSTICA (Cotización Hoy)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD)
	var y_ex: float = 152.0
	for code in ["USD", "GBP", "PEN"]:
		var amt: float = GameState.currencies.get(code, 0.0)
		var rate: float = GameState.get_effective_exchange_rate(code)
		var eur_val: float = snappedf(amt * rate, 0.1)
		var mult: float = GameState.market_multipliers.get(code, 1.0)
		var trend_str: String = GameState.get_market_trend_text(code)
		var trend_col: Color = Color.LIME_GREEN if mult >= 1.05 else (Color.SALMON if mult <= 0.95 else Color.LIGHT_GRAY)

		draw_rect(Rect2(28, y_ex, 334, 34), Color(1, 1, 1, 0.05))
		draw_string(font, Vector2(34, y_ex + 22), "%s: %.1f" % [code, amt], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(font, Vector2(120, y_ex + 22), "%s (%.2f€)" % [trend_str, rate], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, trend_col)

		var srect := Rect2(248, y_ex + 3, 110, 28)
		single_exchange_rects.append({"code": code, "rect": srect})
		draw_rect(srect, Color("#2a9d8f") if amt > 0.0 else Color("#2b3a4a"))
		draw_string(font, srect.position + Vector2(8, 19), "Vender (+%.1f€)" % eur_val, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE if amt > 0.0 else Color.GRAY)
		y_ex += 39.0

	# Ticket del Chiringuito compacto a la izquierda
	var bill: Dictionary = GameState.get_current_bill()
	draw_rect(Rect2(30, 275, 330, 228), Color(0.95, 0.93, 0.85))
	draw_string(font, Vector2(45, 305), "🧾 CHIRINGUITO — TICKET #%d" % (GameState.current_bill_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	draw_string(font, Vector2(45, 336), bill["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#333333"))
	draw_string(font, Vector2(45, 376), "IMPORTE: %.0f €" % bill["amount"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#d62828"))
	var due_str: String = "¡VENCE HOY MISMO!" if GameState.is_bill_due_today() else "Vence Día %d (Hoy: Día %d)" % [((GameState.current_bill_index + 1) * GameState.days_per_bill), GameState.current_day]
	draw_string(font, Vector2(45, 416), due_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d62828") if GameState.is_bill_due_today() else Color("#1d3557"))
	draw_string(font, Vector2(45, 466), "🍦 Nevera: %s (🍀 x%.1f)" % [GameState.get_fridge_summary(), GameState.get_luck_multiplier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#005f73"))

	# Botones Izquierda
	var pending_eur: float = GameState.get_pending_foreign_eur_value()
	draw_rect(btn_exchange_rect, Color("#2a9d8f") if pending_eur > 0.0 else Color("#415a77"))
	draw_string(font, btn_exchange_rect.position + Vector2(20, 31), "💱 VENDER TODAS (+%.1f €)" % pending_eur, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	if GameState.is_bill_due_today() and not bill_paid_today and not bankruptcy_state:
		var can_afford: bool = GameState.currencies["EUR"] >= bill["amount"]
		draw_rect(btn_pay_bill_rect, Color("#2b9348") if can_afford else Color("#e63946"))
		var pay_txt: String = "🧾 PAGAR CUENTA (%.0f €)" % bill["amount"] if can_afford else "🐚 FIN DE VERANEO (+%d Conchas)" % GameState.calculate_prestige_reward()
		draw_string(font, btn_pay_bill_rect.position + Vector2(18, 31), pay_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	var next_col: Color = Color("#e76f51") if bankruptcy_state else (Color("#f4a261") if bill_paid_today else Color("#415a77"))
	draw_rect(btn_next_day_rect, next_col)
	var next_txt: String = "🔄 NUEVO VERANEO (Día 1)" if bankruptcy_state else "🏖️ IR AL DÍA %d DE PLAYA ->" % (GameState.current_day + 1)
	draw_string(font, btn_next_day_rect.position + Vector2(35, 33), next_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.BLACK if (bill_paid_today or bankruptcy_state) else Color.WHITE)

	# --- PANEL DERECHO: GRAFO VISUAL DE NODOS (0) + PRESTIGIO (1) + POSTALES Y ESTADÍSTICAS (2) ---
	draw_rect(graph_panel_rect, Color("#09131c"))
	var border_panel_col: Color = Color("#2ec4b6") if view_mode == 0 else (Color.GOLD if view_mode == 1 else Color("#f4a261"))
	draw_rect(graph_panel_rect, border_panel_col, false, 2.0)

	# 3 Pestañas superiores
	draw_rect(tab_graph_rect, Color("#2ec4b6") if view_mode == 0 else Color("#1b263b"))
	draw_string(font, tab_graph_rect.position + Vector2(12, 26), "🕸️ ÁRBOL DE NODOS (2D)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK if view_mode == 0 else Color.WHITE)

	draw_rect(tab_prestige_rect, Color.GOLD if view_mode == 1 else Color("#1b263b"))
	draw_string(font, tab_prestige_rect.position + Vector2(12, 26), "🐚 PRESTIGIO (%d)" % GameState.golden_shells, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK if view_mode == 1 else Color.WHITE)

	draw_rect(tab_postcards_rect, Color("#f4a261") if view_mode == 2 else Color("#1b263b"))
	draw_string(font, tab_postcards_rect.position + Vector2(12, 26), "🏅 POSTALES (%d/%d)" % [GameState.get_unlocked_achievements_count(), GameState.achievement_catalog.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK if view_mode == 2 else Color.WHITE)

	if view_mode == 1:
		_draw_prestige_shop(font)
		_draw_toast_banner(font)
		return
	elif view_mode == 2:
		_draw_postcards_and_stats(font)
		_draw_toast_banner(font)
		return

	draw_rect(btn_center_graph_rect, Color("#264653"))
	draw_string(font, btn_center_graph_rect.position + Vector2(12, 25), "🎯 Centrar", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# Centro del Grafo Visual
	var hub_pos: Vector2 = Vector2(825, 365) + pan_offset

	var item_by_id: Dictionary = {}
	for item in GameState.upgrade_catalog:
		var id: String = item["id"]
		item_by_id[id] = item
		var rel: Vector2 = node_graph_coords.get(id, Vector2.ZERO)
		var sp: Vector2 = hub_pos + rel
		sp.x = clampf(sp.x, 425.0, 1225.0)
		sp.y = clampf(sp.y, 185.0, 585.0)
		graph_node_Screen_positions[id] = sp

	# 1. Dibujar líneas de conexión entre nodos padres e hijos
	for item in GameState.upgrade_catalog:
		var id: String = item["id"]
		var req: String = item["req"]
		var to_pos: Vector2 = graph_node_Screen_positions[id]
		var from_pos: Vector2 = hub_pos if req == "" else graph_node_Screen_positions.get(req, hub_pos)
		var unlocked: bool = GameState.is_upgrade_unlocked(id)
		var b_col: Color = _get_branch_color(item["branch"])
		var line_col: Color = b_col if unlocked else Color(0.25, 0.32, 0.4, 0.55)
		draw_line(from_pos, to_pos, line_col, 3.5 if unlocked else 2.0)

	# 2. Dibujar Nodo Central ("PLAYA")
	draw_circle(hub_pos, 28.0, Color("#f4a261"))
	draw_arc(hub_pos, 28.0, 0, TAU, 28, Color.WHITE, 2.5)
	draw_string(font, hub_pos + Vector2(-22, 5), "🏖️ PLAYA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)

	# 3. Dibujar los 17 Nodos del Árbol
	for item in GameState.upgrade_catalog:
		var id: String = item["id"]
		var npos: Vector2 = graph_node_Screen_positions[id]
		var lvl: int = GameState.upgrades.get(id, 0)
		var max_lvl: int = item["max_lvl"]
		var unlocked: bool = GameState.is_upgrade_unlocked(id)
		var cost: float = GameState.get_upgrade_cost(id)
		var can_buy: bool = unlocked and lvl < max_lvl and GameState.currencies["EUR"] >= cost
		var is_hovered: bool = (id == hovered_node_id)
		var b_col: Color = _get_branch_color(item["branch"])

		var node_r: float = 31.0 if is_hovered else 27.0
		var fill_col: Color = Color("#16222f")
		if lvl >= max_lvl:
			fill_col = Color("#2b9348")
		elif can_buy:
			fill_col = Color("#1d4e5f")
		elif unlocked:
			fill_col = Color("#1d3557")

		draw_circle(npos + Vector2(0, 4), node_r, Color(0, 0, 0, 0.4))
		draw_circle(npos, node_r, fill_col)
		var border_col: Color = Color.WHITE if is_hovered else (Color.GOLD if can_buy else (b_col if unlocked else Color("#33415c")))
		draw_arc(npos, node_r, 0, TAU, 28, border_col, 3.2 if (can_buy or is_hovered) else 2.0)

		var icon_str: String = item["title"].split(" ")[0]
		draw_string(font, npos + Vector2(-10, -2), icon_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE if unlocked else Color.DARK_GRAY)
		draw_string(font, npos + Vector2(-15, 16), "%d/%d" % [lvl, max_lvl], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.GOLD if lvl > 0 else Color.LIGHT_GRAY)

	# 4. Barra Inferior de Inspector / Tooltip dentro del Grafo
	var tip_rect := Rect2(400, 615, 845, 78)
	draw_rect(tip_rect, Color("#14213d"))
	draw_rect(tip_rect, Color("#415a77"), false, 1.5)

	if hovered_node_id != "" and item_by_id.has(hovered_node_id):
		var hitem: Dictionary = item_by_id[hovered_node_id]
		var hlvl: int = GameState.upgrades.get(hovered_node_id, 0)
		var hmax: int = hitem["max_lvl"]
		var hunlocked: bool = GameState.is_upgrade_unlocked(hovered_node_id)
		var hcost: float = GameState.get_upgrade_cost(hovered_node_id)
		draw_string(font, tip_rect.position + Vector2(16, 26), "%s   [Nivel %d / %d]" % [hitem["title"], hlvl, hmax], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.GOLD)
		draw_string(font, tip_rect.position + Vector2(16, 54), hitem["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		var hstatus: String = "✅ NIVEL MÁXIMO" if hlvl >= hmax else ("🔒 Requiere nodo anterior" if not hunlocked else "🖱️ Clic para mejorar: %.1f €" % hcost)
		draw_string(font, tip_rect.position + Vector2(580, 42), hstatus, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.LIME_GREEN if hunlocked else Color.SALMON)
	else:
		draw_string(font, tip_rect.position + Vector2(18, 32), "💡 Pasa el ratón sobre cualquier nodo del árbol para ver sus detalles y haz clic izquierdo para comprarlo.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.LIGHT_GRAY)
		draw_string(font, tip_rect.position + Vector2(18, 58), "🎨 Colores de Rama:  🔴 Herramientas/Críticos   |   🟢 Playa/Tractor/Auto   |   🟣 Helados/Suerte   |   🟡 Turismo/Divisas", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.AQUAMARINE)

	_draw_toast_banner(font)

func _draw_toast_banner(font: Font) -> void:
	if toast_timer > 0.0:
		var t_rect := Rect2(380, 18, 520, 68)
		draw_rect(t_rect, Color(0.09, 0.14, 0.22, 0.98))
		draw_rect(t_rect, Color.GOLD, false, 3.0)
		draw_string(font, t_rect.position + Vector2(16, 26), "🏅 ¡POSTAL DESBLOQUEADA! (%s)  +1 🐚" % toast_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD)
		draw_string(font, t_rect.position + Vector2(16, 50), toast_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw_prestige_shop(font: Font) -> void:
	draw_string(font, Vector2(410, 190), "🐚 TIENDA DE VERANEO PERMANENTE (Guardado automático en user://savegame.json):", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.GOLD)
	var card_y: float = 210.0
	for pitem in GameState.prestige_catalog:
		var pid: String = pitem["id"]
		var plvl: int = GameState.prestige_upgrades.get(pid, 0)
		var pmax: int = pitem["max_lvl"]
		var pcost: int = GameState.get_prestige_cost(pid)
		var pcan_buy: bool = plvl < pmax and GameState.golden_shells >= pcost

		var prect := Rect2(410, card_y, 825, 84)
		upgrade_card_rects.append({"id": pid, "rect": prect})

		var pbg: Color = Color("#2b9348") if plvl >= pmax else (Color("#3d2c8d") if pcan_buy else Color("#1d3557"))
		draw_rect(prect, pbg)
		draw_rect(prect, Color.GOLD if pcan_buy else Color("#415a77"), false, 2.0)

		draw_string(font, prect.position + Vector2(18, 30), "%s   [Nivel %d / %d]" % [pitem["title"], plvl, pmax], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		draw_string(font, prect.position + Vector2(18, 60), pitem["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.LIGHT_GRAY)

		var pprice: String = "✅ MÁXIMO" if plvl >= pmax else "Comprar: %d 🐚" % pcost
		draw_string(font, prect.position + Vector2(650, 48), pprice, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.GOLD if pcan_buy else Color.SALMON)
		card_y += 98.0

	draw_rect(btn_wipe_save_rect, Color("#6a040f"))
	draw_string(font, btn_wipe_save_rect.position + Vector2(18, 28), "🗑️ Borrar Partida Guardada", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func _draw_postcards_and_stats(font: Font) -> void:
	# 1. Bloque de Estadísticas Históricas Globales
	var stats_rect := Rect2(405, 168, 835, 92)
	draw_rect(stats_rect, Color("#14213d"))
	draw_rect(stats_rect, Color("#f4a261"), false, 2.0)
	draw_string(font, stats_rect.position + Vector2(16, 26), "📊 RÉCORDS Y ESTADÍSTICAS GLOBALES DEL VERANEANTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD)

	var st: Dictionary = GameState.lifetime_stats
	var line1: String = "🦀 Bichos Atrapados: %d   |   💶 Euros Ganados Totales: %.1f €   |   🧾 Cuentas Pagadas: %d" % [
		int(st.get("total_crabs_caught", 0)), float(st.get("total_eur_earned", 0.0)), int(st.get("total_bills_paid", 0))
	]
	var line2: String = "🌞 Récord de Día Alcanzado: Día %d   |   💥 Mejor Combo en un Golpe: x%d   |   🏅 Postales: %d / %d" % [
		int(st.get("max_day_reached", 1)), int(st.get("best_combo", 1)), GameState.get_unlocked_achievements_count(), GameState.achievement_catalog.size()
	]
	draw_string(font, stats_rect.position + Vector2(16, 54), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(font, stats_rect.position + Vector2(16, 78), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.AQUAMARINE)

	# 2. Cuadrícula 2x4 del Álbum de Postales de Veraneo
	draw_string(font, Vector2(405, 286), "🏅 ÁLBUM DE POSTALES DE VERANEO (Cada postal desbloqueada otorga +1 🐚 Concha Dorada):", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.GOLD)

	for i in range(GameState.achievement_catalog.size()):
		var ach: Dictionary = GameState.achievement_catalog[i]
		var aid: String = ach["id"]
		var is_unlk: bool = GameState.unlocked_achievements.get(aid, false)
		var col_idx: int = i % 2
		var row_idx: int = int(i / 2.0)
		var cx: float = 405.0 + col_idx * 422.0
		var cy: float = 300.0 + row_idx * 96.0
		var crect := Rect2(cx, cy, 410, 84)

		draw_rect(crect, Color("#1d4e5f") if is_unlk else Color("#121c29"))
		draw_rect(crect, Color.GOLD if is_unlk else Color("#33415c"), false, 2.2 if is_unlk else 1.5)

		draw_string(font, crect.position + Vector2(14, 28), ach["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD if is_unlk else Color.LIGHT_GRAY)
		var badge: String = "✅ +1 🐚" if is_unlk else "🔒 Pendiente"
		draw_string(font, crect.position + Vector2(312, 28), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.LIME_GREEN if is_unlk else Color.DARK_GRAY)
		draw_string(font, crect.position + Vector2(14, 58), ach["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE if is_unlk else Color.GRAY)
