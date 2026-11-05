extends Node2D
## Escena Entre Rondas ("El Paseo Marítimo"):
## 1. Caseta de Cambio de Divisas (USD, GBP, PEN -> EUR)
## 2. El Ticket del Chiringuito (Cobro obligatorio cada 3 días o Fin de Veraneo)
## 3. Botón para avanzar al siguiente Día de Playa

var bill_paid_today: bool = false
var bankruptcy_state: bool = false
var status_message: String = ""
var status_color: Color = Color.GOLD

# Áreas clicables (botones dibujados por código para mantener estilo limpio sin dependencias)
var btn_exchange_rect := Rect2(80, 490, 480, 56)
var btn_pay_bill_rect := Rect2(700, 420, 480, 56)
var btn_next_day_rect := Rect2(700, 510, 480, 64)

func _ready() -> void:
	bill_paid_today = not GameState.is_bill_due_today()
	bankruptcy_state = false
	if GameState.is_bill_due_today():
		status_message = "⚠️ ¡HOY VENCE EL TICKET DEL CHIRINGUITO! Cambia tus divisas y paga la cuenta."
		status_color = Color.ORANGE_RED
	else:
		var days_left: int = GameState.days_per_bill - (GameState.current_day % GameState.days_per_bill)
		status_message = "🏖️ Paseo Marítimo — Faltan %d día(s) para que venga el camarero con la cuenta." % days_left
		status_color = Color.AQUAMARINE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
		if btn_exchange_rect.has_point(mpos):
			_on_exchange_pressed()
		elif btn_pay_bill_rect.has_point(mpos) and GameState.is_bill_due_today() and not bill_paid_today:
			_on_pay_bill_pressed()
		elif btn_next_day_rect.has_point(mpos):
			_on_next_action_pressed()

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
	# Si aún tiene divisas sin cambiar y no le llega en EUR, avisar
	var bill: Dictionary = GameState.get_current_bill()
	if GameState.currencies["EUR"] < bill["amount"] and GameState.get_pending_foreign_eur_value() > 0.0:
		status_message = "💡 ¡Cambia primero tus divisas extranjeras a Euros en el panel izquierdo!"
		status_color = Color.GOLD
		queue_redraw()
		return

	if GameState.pay_current_bill():
		bill_paid_today = true
		status_message = "✅ ¡Cuenta del Chiringuito pagada! Tu familia sigue de vacaciones."
		status_color = Color.LIME_GREEN
	else:
		bankruptcy_state = true
		status_message = "❌ ¡NO TIENES SUFICIENTES EUROS! El camarero os ha echado de la playa (Fin de la Run)."
		status_color = Color.RED
	queue_redraw()

func _on_next_action_pressed() -> void:
	if bankruptcy_state:
		GameState.reset_run()
		get_tree().change_scene_to_file("res://scenes/main/beach_round.tscn")
		return

	if not bill_paid_today:
		status_message = "⚠️ ¡No puedes irte a dormir sin pagar el Ticket del Chiringuito de hoy!"
		status_color = Color.ORANGE_RED
		queue_redraw()
		return

	GameState.current_day += 1
	get_tree().change_scene_to_file("res://scenes/main/beach_round.tscn")

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# Fondo nocturno/atardecer del Paseo Marítimo
	draw_rect(Rect2(0, 0, 1280, 720), Color("#1b263b"))
	draw_rect(Rect2(0, 0, 1280, 90), Color("#0d1b2a"))

	# Cabecera
	draw_string(font, Vector2(40, 42), "🌅 FIN DEL DÍA %d — PASEO MARÍTIMO" % GameState.current_day, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(font, Vector2(40, 72), status_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, status_color)
	draw_string(font, Vector2(960, 52), "💶 CARTERA: %.1f €" % GameState.currencies["EUR"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.GOLD)

	# --- PANEL IZQUIERDO: CASETA DE CAMBIO ---
	draw_rect(Rect2(50, 120, 540, 460), Color("#0d1b2a"))
	draw_rect(Rect2(50, 120, 540, 460), Color("#415a77"), false, 2.0)
	draw_string(font, Vector2(80, 165), "💱 CASETA DE CAMBIO (TOURIST EXCHANGE)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.GOLD)
	draw_string(font, Vector2(80, 195), "Convierte las monedas perdidas por turistas en Euros (€):", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.LIGHT_GRAY)

	var y_offset: float = 245.0
	var rows: Array[Dictionary] = [
		{"code": "USD", "label": "💵 Dólares (USD)"},
		{"code": "GBP", "label": "💷 Libras (GBP)"},
		{"code": "PEN", "label": "🪙 Soles (PEN)"}
	]
	for r in rows:
		var code: String = r["code"]
		var amount: float = GameState.currencies.get(code, 0.0)
		var rate: float = GameState.get_effective_exchange_rate(code)
		var eur_val: float = amount * rate
		draw_rect(Rect2(80, y_offset - 28, 480, 52), Color(1, 1, 1, 0.05))
		draw_string(font, Vector2(95, y_offset + 4), "%s:  %.1f" % [r["label"], amount], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		draw_string(font, Vector2(310, y_offset + 4), "(Tasa: %.2f)  ->  +%.1f €" % [rate, eur_val], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GREEN_YELLOW)
		y_offset += 70.0

	# Botón Cambiar Todo
	var pending_eur: float = GameState.get_pending_foreign_eur_value()
	var ex_col: Color = Color("#2a9d8f") if pending_eur > 0.0 else Color("#415a77")
	draw_rect(btn_exchange_rect, ex_col)
	draw_string(font, btn_exchange_rect.position + Vector2(65, 35), "💱 CAMBIAR TODO A EUROS (+%.1f €)" % pending_eur, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# --- PANEL DERECHO: EL CHIRINGUITO ---
	draw_rect(Rect2(670, 120, 540, 480), Color("#0d1b2a"))
	draw_rect(Rect2(670, 120, 540, 480), Color("#e76f51"), false, 2.0)
	draw_string(font, Vector2(700, 165), "🍹 LA CUENTA DEL CHIRINGUITO", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.SALMON)

	var bill: Dictionary = GameState.get_current_bill()
	draw_rect(Rect2(700, 195, 480, 190), Color(0.95, 0.93, 0.85))
	draw_string(font, Vector2(725, 235), "🧾 TICKET DE COMANDA #%d" % (GameState.current_bill_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)
	draw_string(font, Vector2(725, 275), "Concepto: %s" % bill["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#333333"))
	draw_string(font, Vector2(725, 315), "TOTAL A PAGAR: %.0f €" % bill["amount"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#d62828"))

	var due_text: String = "¡VENCE HOY MISMO!" if GameState.is_bill_due_today() else "Vence en el Día %d (Día actual: %d)" % [((GameState.current_bill_index + 1) * GameState.days_per_bill), GameState.current_day]
	draw_string(font, Vector2(725, 360), due_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d62828") if GameState.is_bill_due_today() else Color("#1d3557"))

	# Botón de Pagar Factura (solo activo cuando toca pagar)
	if GameState.is_bill_due_today() and not bill_paid_today:
		var can_afford: bool = GameState.currencies["EUR"] >= bill["amount"]
		var pay_btn_col: Color = Color("#e63946") if not can_afford else Color("#2b9348")
		draw_rect(btn_pay_bill_rect, pay_btn_col)
		var pay_label: String = "🧾 PAGAR CUENTA (%.0f €)" % bill["amount"] if can_afford else "❌ NO ALCANZA (Declarar Fin de Veraneo)"
		draw_string(font, btn_pay_bill_rect.position + Vector2(55, 35), pay_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# Botón Siguiente Día / Reiniciar Run
	var next_col: Color = Color("#e76f51") if bankruptcy_state else (Color("#f4a261") if bill_paid_today else Color("#415a77"))
	draw_rect(btn_next_day_rect, next_col)
	var next_label: String = "🔄 EMPEZAR NUEVO VERANEO (Día 1)" if bankruptcy_state else "🏖️ IR AL DÍA %d DE PLAYA ->" % (GameState.current_day + 1)
	draw_string(font, btn_next_day_rect.position + Vector2(85, 38), next_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.BLACK if bill_paid_today else Color.WHITE)
