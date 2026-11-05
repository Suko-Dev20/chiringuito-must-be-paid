extends Node2D
## Escena Entre Rondas ("El Paseo Marítimo"):
## 1. Caseta de Cambio de Divisas (USD, GBP, PEN -> EUR)
## 2. Árbol de Habilidades Interactivo (4 Ramas + 5ª Pestaña de Prestigio Permanente)
## 3. El Ticket del Chiringuito y Sistema de Bancarrota / Fin de Veraneo (Conchas Doradas)

var bill_paid_today: bool = false
var bankruptcy_state: bool = false
var status_message: String = ""
var status_color: Color = Color.GOLD

var selected_branch: int = 0
var branch_titles: Array[String] = [
	"🏖️ 1. Herramientas",
	"🚜 2. Playa/Tractor",
	"🍦 3. Helados/Suerte",
	"💱 4. Divisas",
	"🐚 5. Prestigio"
]

# Áreas clicables dinámicas
var btn_exchange_rect := Rect2(30, 520, 330, 50)
var btn_pay_bill_rect := Rect2(30, 585, 330, 50)
var btn_next_day_rect := Rect2(30, 645, 330, 54)
var tab_rects: Array[Rect2] = []
var upgrade_card_rects: Array[Dictionary] = []

func _ready() -> void:
	bill_paid_today = not GameState.is_bill_due_today()
	bankruptcy_state = false
	for i in range(5):
		tab_rects.append(Rect2(392 + i * 172, 110, 166, 44))
	if GameState.is_bill_due_today():
		status_message = "⚠️ ¡HOY VENCE EL TICKET DEL CHIRINGUITO! Cambia divisas y paga la cuenta antes de ir al siguiente día."
		status_color = Color.ORANGE_RED
	else:
		var days_left: int = GameState.days_per_bill - (GameState.current_day % GameState.days_per_bill)
		status_message = "🏖️ Paseo Marítimo — Compra mejoras o Helados. Faltan %d día(s) para la cuenta." % days_left
		status_color = Color.AQUAMARINE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
		for i in range(tab_rects.size()):
			if tab_rects[i].has_point(mpos):
				selected_branch = i
				queue_redraw()
				return
		for card in upgrade_card_rects:
			if card["rect"].has_point(mpos):
				if selected_branch == 4:
					_on_prestige_clicked(card["id"])
				else:
					_on_upgrade_clicked(card["id"])
				return
		if btn_exchange_rect.has_point(mpos):
			_on_exchange_pressed()
		elif btn_pay_bill_rect.has_point(mpos) and GameState.is_bill_due_today() and not bill_paid_today:
			_on_pay_bill_pressed()
		elif btn_next_day_rect.has_point(mpos):
			_on_next_action_pressed()

func _on_upgrade_clicked(id: String) -> void:
	if not GameState.is_upgrade_unlocked(id):
		status_message = "🔒 Mejora bloqueada: compra primero el nodo anterior de la rama."
		status_color = Color.ORANGE
		queue_redraw()
		return
	var cost: float = GameState.get_upgrade_cost(id)
	if GameState.buy_upgrade(id):
		status_message = "✨ ¡Mejora comprada por %.1f €! Nevera activa: %s" % [cost, GameState.get_fridge_summary()]
		status_color = Color.LIME_GREEN
	else:
		status_message = "❌ No tienes suficientes Euros (%.1f € requeridos) o ya está al nivel máximo." % cost
		status_color = Color.SALMON
	queue_redraw()

func _on_prestige_clicked(id: String) -> void:
	var cost: int = GameState.get_prestige_cost(id)
	if GameState.buy_prestige_upgrade(id):
		status_message = "🐚 ¡Mejora PERMANENTE de Prestigio adquirida por %d Concha(s) Dorada(s)!" % cost
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
		status_message = "💱 ¡Cambio realizado! Has recibido +%.1f € en la Caseta de Cambio." % gained
		status_color = Color.GREEN_YELLOW
	queue_redraw()

func _on_pay_bill_pressed() -> void:
	var bill: Dictionary = GameState.get_current_bill()
	if GameState.currencies["EUR"] < bill["amount"] and GameState.get_pending_foreign_eur_value() > 0.0:
		status_message = "💡 ¡Cambia primero tus divisas extranjeras a Euros en la Caseta!"
		status_color = Color.GOLD
		queue_redraw()
		return

	if GameState.pay_current_bill():
		bill_paid_today = true
		status_message = "✅ ¡Cuenta pagada! Has ganado +1 🐚 Concha Dorada de prestigio por superar el ciclo."
		status_color = Color.LIME_GREEN
	else:
		bankruptcy_state = true
		var earned_shells: int = GameState.award_bankruptcy_shells()
		selected_branch = 4 # Abrir automáticamente la pestaña de Prestigio Permanente
		status_message = "🐚 ¡FIN DE VERANEO! Has ganado +%d Concha(s) Dorada(s). Gástalas en mejoras PERMANENTES antes de reiniciar." % earned_shells
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
	get_tree().change_scene_to_file("res://scenes/main/beach_round.tscn")

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	upgrade_card_rects.clear()

	# Fondo general del Paseo Marítimo
	draw_rect(Rect2(0, 0, 1280, 720), Color("#1b263b"))
	draw_rect(Rect2(0, 0, 1280, 88), Color("#0d1b2a"))

	# Cabecera
	draw_string(font, Vector2(30, 38), "🌅 FIN DEL DÍA %d — PASEO MARÍTIMO & TIENDA DE PRESTIGIO" % GameState.current_day, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	draw_string(font, Vector2(30, 68), status_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, status_color)
	draw_string(font, Vector2(790, 50), "💶 %.1f €   |   🐚 %d Conchas Doradas" % [GameState.currencies["EUR"], GameState.golden_shells], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.GOLD)

	# --- COLUMNA IZQUIERDA: CASETA DE CAMBIO + CHIRINGUITO ---
	draw_rect(Rect2(20, 105, 350, 600), Color("#0d1b2a"))
	draw_rect(Rect2(20, 105, 350, 600), Color("#415a77"), false, 2.0)

	draw_string(font, Vector2(35, 138), "💱 CASETA DE CAMBIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.GOLD)
	var y_ex: float = 172.0
	for code in ["USD", "GBP", "PEN"]:
		var amt: float = GameState.currencies.get(code, 0.0)
		var rate: float = GameState.get_effective_exchange_rate(code)
		draw_string(font, Vector2(35, y_ex), "%s: %.1f (x%.2f) -> +%.1f €" % [code, amt, rate, amt * rate], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		y_ex += 28.0

	# Ticket del Chiringuito compacto a la izquierda
	var bill: Dictionary = GameState.get_current_bill()
	draw_rect(Rect2(30, 270, 330, 230), Color(0.95, 0.93, 0.85))
	draw_string(font, Vector2(45, 302), "🧾 CHIRINGUITO — TICKET #%d" % (GameState.current_bill_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	draw_string(font, Vector2(45, 335), bill["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#333333"))
	draw_string(font, Vector2(45, 375), "IMPORTE: %.0f €" % bill["amount"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#d62828"))
	var due_str: String = "¡VENCE HOY MISMO!" if GameState.is_bill_due_today() else "Vence Día %d (Hoy: Día %d)" % [((GameState.current_bill_index + 1) * GameState.days_per_bill), GameState.current_day]
	draw_string(font, Vector2(45, 415), due_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d62828") if GameState.is_bill_due_today() else Color("#1d3557"))
	draw_string(font, Vector2(45, 465), "🍦 Nevera: %s (🍀 x%.1f)" % [GameState.get_fridge_summary(), GameState.get_luck_multiplier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#005f73"))

	# Botones Izquierda
	var pending_eur: float = GameState.get_pending_foreign_eur_value()
	draw_rect(btn_exchange_rect, Color("#2a9d8f") if pending_eur > 0.0 else Color("#415a77"))
	draw_string(font, btn_exchange_rect.position + Vector2(20, 31), "💱 CAMBIAR DIVISAS (+%.1f €)" % pending_eur, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	if GameState.is_bill_due_today() and not bill_paid_today and not bankruptcy_state:
		var can_afford: bool = GameState.currencies["EUR"] >= bill["amount"]
		draw_rect(btn_pay_bill_rect, Color("#2b9348") if can_afford else Color("#e63946"))
		var pay_txt: String = "🧾 PAGAR CUENTA (%.0f €)" % bill["amount"] if can_afford else "🐚 FIN DE VERANEO (+%d Conchas)" % GameState.calculate_prestige_reward()
		draw_string(font, btn_pay_bill_rect.position + Vector2(18, 31), pay_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	var next_col: Color = Color("#e76f51") if bankruptcy_state else (Color("#f4a261") if bill_paid_today else Color("#415a77"))
	draw_rect(btn_next_day_rect, next_col)
	var next_txt: String = "🔄 NUEVO VERANEO (Día 1)" if bankruptcy_state else "🏖️ IR AL DÍA %d DE PLAYA ->" % (GameState.current_day + 1)
	draw_string(font, btn_next_day_rect.position + Vector2(35, 33), next_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.BLACK if (bill_paid_today or bankruptcy_state) else Color.WHITE)

	# --- PANEL DERECHO: ÁRBOL DE HABILIDADES (4 RAMAS + PRESTIGIO PERMANENTE) ---
	draw_rect(Rect2(385, 105, 875, 600), Color("#0d1b2a"))
	draw_rect(Rect2(385, 105, 875, 600), Color.GOLD if selected_branch == 4 else Color("#2ec4b6"), false, 2.0)

	# Pestañas (4 Ramas + 5ª Pestaña de Prestigio)
	for i in range(5):
		var trect: Rect2 = tab_rects[i]
		var is_sel: bool = (i == selected_branch)
		var tab_col: Color = (Color.GOLD if i == 4 else Color("#2ec4b6")) if is_sel else Color("#1b263b")
		draw_rect(trect, tab_col)
		draw_string(font, trect.position + Vector2(8, 28), branch_titles[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK if is_sel else Color.WHITE)

	var card_y: float = 170.0
	if selected_branch == 4:
		# Renderizar Tienda Permanente de Prestigio (Conchas Doradas)
		draw_string(font, Vector2(410, 190), "🐚 TIENDA DE VERANEO PERMANENTE (Tus mejoras aquí NUNCA se pierden al reiniciar):", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.GOLD)
		card_y = 210.0
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
		return

	# Nodos de las 4 ramas normales
	for item in GameState.upgrade_catalog:
		if item["branch"] != selected_branch:
			continue
		var id: String = item["id"]
		var lvl: int = GameState.upgrades.get(id, 0)
		var max_lvl: int = item["max_lvl"]
		var unlocked: bool = GameState.is_upgrade_unlocked(id)
		var cost: float = GameState.get_upgrade_cost(id)
		var can_buy: bool = unlocked and lvl < max_lvl and GameState.currencies["EUR"] >= cost

		var crect := Rect2(410, card_y, 825, 66)
		upgrade_card_rects.append({"id": id, "rect": crect})

		var bg_col: Color = Color("#1d3557") if unlocked else Color(0.1, 0.1, 0.15, 0.7)
		if lvl >= max_lvl:
			bg_col = Color("#2b9348")
		elif can_buy:
			bg_col = Color("#264653")

		draw_rect(crect, bg_col)
		draw_rect(crect, Color.GOLD if can_buy else Color("#415a77"), false, 2.0)

		var title_str: String = "%s   [Nivel %d / %d]" % [item["title"], lvl, max_lvl]
		draw_string(font, crect.position + Vector2(18, 25), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE if unlocked else Color.GRAY)
		draw_string(font, crect.position + Vector2(18, 50), item["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.LIGHT_GRAY)

		var price_str: String = "✅ MÁXIMO" if lvl >= max_lvl else ("🔒 Req: %s" % item["req"] if not unlocked else "Comprar: %.1f €" % cost)
		var price_col: Color = Color.LIME_GREEN if lvl >= max_lvl else (Color.GOLD if can_buy else Color.SALMON)
		draw_string(font, crect.position + Vector2(630, 38), price_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, price_col)

		card_y += 74.0
