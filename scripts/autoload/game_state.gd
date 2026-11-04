extends Node
## Estado global del juego (Autoload: GameState)
## Equivale a tu Store global (Redux / Zustand / Pinia) en desarrollo web.

signal currencies_updated
signal stamina_changed(current: float, maximum: float)
signal day_changed(current_day: int, bill_due_day: int)

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

# --- Divisas de Turistas ---
var currencies: Dictionary = {
	"EUR": 0.0,
	"USD": 0.0,
	"GBP": 0.0,
	"PEN": 0.0 # Soles
}

# Tasa de cambio base a Euros (mejorable en la Rama 4)
var base_exchange_rates: Dictionary = {
	"USD": 0.85,
	"GBP": 1.15,
	"PEN": 0.25
}

# --- Niveles del Árbol de Habilidades ---
var upgrades: Dictionary = {
	# Rama 1: Herramientas y Críticos
	"shovel_damage": 0,
	"shovel_radius": 0,
	"crit_chance": 0,
	"multi_hit_bonus": 0,
	"unlock_bucket": 0,
	"rake_magnet": 0,
	# Rama 2: Playa y Tractor
	"crab_spawn_rate": 0,
	"unlock_tractor": 0,
	"tractor_cooldown": 0,
	# Rama 3: Helados y Stamina
	"max_stamina": 0,
	"ice_cream_foot": 0,    # Pie Helado: probabilidad de recuperar stamina
	"ice_cream_rocket": 0,  # Cohete Tricolor: probabilidad de golpe explosivo
	# Rama 4: Turismo y Divisas
	"tourist_currencies": 0,
	"exchange_rate_boost": 0
}

# --- Estadísticas Calculadas Dinámicamente ---

func get_shovel_damage() -> float:
	return 10.0 + (upgrades["shovel_damage"] * 5.0)

func get_shovel_radius() -> float:
	return 42.0 + (upgrades["shovel_radius"] * 8.0)

func get_crit_chance() -> float:
	return 0.05 + (upgrades["crit_chance"] * 0.05)

func get_multi_hit_multiplier(targets_hit: int) -> float:
	if targets_hit <= 1 or upgrades["multi_hit_bonus"] == 0:
		return 1.0
	# Bonificación cuando golpeas a varios cangrejos juntos
	return 1.0 + (targets_hit - 1) * (0.25 * upgrades["multi_hit_bonus"])

func get_rake_radius() -> float:
	return 48.0 + (upgrades["rake_magnet"] * 22.0)

func get_max_stamina() -> float:
	return 100.0 + (upgrades["max_stamina"] * 25.0)

func get_foot_ice_cream_chance() -> float:
	return upgrades["ice_cream_foot"] * 0.12

func get_current_bill() -> Dictionary:
	var idx: int = mini(current_bill_index, bills.size() - 1)
	return bills[idx]

func get_effective_exchange_rate(code: String) -> float:
	var bonus_mult: float = 1.0 + (upgrades["exchange_rate_boost"] * 0.15)
	return snappedf(base_exchange_rates.get(code, 1.0) * bonus_mult, 0.01)

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
	currencies_updated.emit()
	return true

func reset_run() -> void:
	current_day = 1
	current_bill_index = 0
	for code in currencies.keys():
		currencies[code] = 0.0
	for upg in upgrades.keys():
		upgrades[upg] = 0
	currencies_updated.emit()

func add_currency(code: String, amount: float) -> void:
	if not currencies.has(code):
		currencies[code] = 0.0
	currencies[code] += amount
	currencies_updated.emit()

func exchange_all_to_eur() -> float:
	var bonus_mult: float = 1.0 + (upgrades["exchange_rate_boost"] * 0.15)
	var gained_eur: float = 0.0
	for code in ["USD", "GBP", "PEN"]:
		var amount: float = currencies.get(code, 0.0)
		if amount > 0.0:
			gained_eur += amount * base_exchange_rates[code] * bonus_mult
			currencies[code] = 0.0
	currencies["EUR"] += snappedf(gained_eur, 0.1)
	currencies_updated.emit()
	return gained_eur
