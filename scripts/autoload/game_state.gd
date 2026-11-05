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
	# Rama 3: Kiosco de Helados y Resistencia (Issue #5)
	"max_stamina": 0,
	"global_luck": 0,       # Multiplicador global de suerte para helados
	"ice_cream_foot": 0,    # 🦶 Pie Helado: prob. de recuperar stamina al atrapar
	"ice_cream_rocket": 0,  # 🚀 Cohete Tricolor: prob. de onda expansiva al golpear
	"ice_cream_vampire": 0, # 🧛 Conde Colmillos: prob. en crítico de curar stamina y x2 monedas
	"ice_cream_magnum": 0,  # 🍫 Bombón Magnético: prob. cada seg. de auto-recoger moneda x2 valor
	"ice_cream_shark": 0,   # 🦈 Tiburón Azul: prob. al golpear de reducir -2.5s cooldown del Tractor
	# Rama 4: Turismo y Divisas
	"tourist_currencies": 0,
	"exchange_rate_boost": 0
}

# Catálogo de mejoras del Árbol de Habilidades (4 Ramas + Subrama Críticos + Kiosco Helados)
var upgrade_catalog: Array[Dictionary] = [
	# Rama 1: Herramientas y Críticos (branch = 0)
	{"id": "shovel_damage", "branch": 0, "title": "🏖️ Pala Reforzada", "desc": "+5 Daño base con la pala", "base_cost": 8.0, "cost_mult": 1.5, "max_lvl": 10, "req": ""},
	{"id": "shovel_radius", "branch": 0, "title": "⭕ Pala Ancha", "desc": "+8 px de radio de golpe", "base_cost": 12.0, "cost_mult": 1.6, "max_lvl": 6, "req": "shovel_damage"},
	{"id": "crit_chance", "branch": 0, "title": "⚡ Filo Playero (Crítico)", "desc": "+5% Probabilidad de Crítico (x2)", "base_cost": 15.0, "cost_mult": 1.6, "max_lvl": 8, "req": "shovel_damage"},
	{"id": "multi_hit_bonus", "branch": 0, "title": "💥 Golpe en Manada", "desc": "+25% Daño extra por cada cangrejo adicional en el mismo golpe", "base_cost": 22.0, "cost_mult": 1.7, "max_lvl": 5, "req": "crit_chance"},
	{"id": "unlock_bucket", "branch": 0, "title": "🪣 Cubo Pesado (Clic Der)", "desc": "Desbloquea/mejora el Cubazo en área (+Daño y -Cooldown)", "base_cost": 18.0, "cost_mult": 1.7, "max_lvl": 5, "req": "shovel_radius"},
	{"id": "rake_magnet", "branch": 0, "title": "🧹 Rastrillo Imantado", "desc": "+22 px de radio para recoger monedas al mover el ratón", "base_cost": 10.0, "cost_mult": 1.5, "max_lvl": 6, "req": ""},

	# Rama 2: Playa y Tractor (branch = 1)
	{"id": "crab_spawn_rate", "branch": 1, "title": "🦀 Cebo Playero", "desc": "Aparecen más bichos marinos y más rápido en la orilla", "base_cost": 10.0, "cost_mult": 1.5, "max_lvl": 8, "req": ""},
	{"id": "unlock_tractor", "branch": 1, "title": "🚜 Tractor Limpia-Playas", "desc": "Mejora el Tractor [ESPACIO] y su velocidad de barrido", "base_cost": 25.0, "cost_mult": 1.8, "max_lvl": 5, "req": "crab_spawn_rate"},
	{"id": "tractor_cooldown", "branch": 1, "title": "⛽ Motor Turbo Tractor", "desc": "-1.8s al tiempo de recarga del Tractor", "base_cost": 30.0, "cost_mult": 1.7, "max_lvl": 5, "req": "unlock_tractor"},

	# Rama 3: Kiosco de Helados y Resistencia (branch = 2)
	{"id": "max_stamina", "branch": 2, "title": "⛱️ Sombrilla y Crema", "desc": "+25 Stamina máxima para aguantar más al sol", "base_cost": 10.0, "cost_mult": 1.45, "max_lvl": 10, "req": ""},
	{"id": "global_luck", "branch": 2, "title": "🍀 Pulsera de la Suerte", "desc": "+20% a la probabilidad de activación de TODOS tus Helados", "base_cost": 14.0, "cost_mult": 1.6, "max_lvl": 6, "req": "max_stamina"},
	{"id": "ice_cream_foot", "branch": 2, "title": "🦶 Helado: Pie Helado", "desc": "Prob. al atrapar bicho de refrescarte (+7 Stamina)", "base_cost": 15.0, "cost_mult": 1.6, "max_lvl": 5, "req": "max_stamina"},
	{"id": "ice_cream_rocket", "branch": 2, "title": "🚀 Helado: Cohete Tricolor", "desc": "Prob. al golpear de lanzar onda expansiva (+60% radio)", "base_cost": 22.0, "cost_mult": 1.7, "max_lvl": 5, "req": "ice_cream_foot"},
	{"id": "ice_cream_vampire", "branch": 2, "title": "🧛 Helado: Conde Colmillos", "desc": "Prob. en Golpe Crítico de robar +5 Stamina y duplicar monedas", "base_cost": 26.0, "cost_mult": 1.75, "max_lvl": 5, "req": "ice_cream_foot"},
	{"id": "ice_cream_magnum", "branch": 2, "title": "🍫 Helado: Bombón Magnético", "desc": "Prob. cada segundo de absorber una moneda sola con valor DOBLE", "base_cost": 28.0, "cost_mult": 1.75, "max_lvl": 5, "req": "global_luck"},
	{"id": "ice_cream_shark", "branch": 2, "title": "🦈 Helado: Tiburón Azul", "desc": "Prob. al golpear de reducir -2.5s la recarga del Tractor", "base_cost": 30.0, "cost_mult": 1.75, "max_lvl": 5, "req": "ice_cream_rocket"},

	# Rama 4: Turismo y Divisas (branch = 3)
	{"id": "tourist_currencies", "branch": 3, "title": "✈️ Playa Internacional", "desc": "Los bichos sueltan más monedas por captura y divisas valiosas", "base_cost": 14.0, "cost_mult": 1.6, "max_lvl": 6, "req": ""},
	{"id": "exchange_rate_boost", "branch": 3, "title": "💱 Caseta Sin Comisiones", "desc": "+15% al valor en Euros (€) al cambiar USD, GBP y PEN", "base_cost": 20.0, "cost_mult": 1.65, "max_lvl": 6, "req": "tourist_currencies"}
]

func get_upgrade_cost(id: String) -> float:
	for item in upgrade_catalog:
		if item["id"] == id:
			var lvl: int = upgrades.get(id, 0)
			return snappedf(item["base_cost"] * pow(item["cost_mult"], lvl), 0.5)
	return 9999.0

func is_upgrade_unlocked(id: String) -> bool:
	for item in upgrade_catalog:
		if item["id"] == id:
			var req: String = item["req"]
			return req == "" or upgrades.get(req, 0) > 0
	return false

func buy_upgrade(id: String) -> bool:
	for item in upgrade_catalog:
		if item["id"] == id:
			var lvl: int = upgrades.get(id, 0)
			if lvl >= item["max_lvl"] or not is_upgrade_unlocked(id):
				return false
			var cost: float = get_upgrade_cost(id)
			if currencies["EUR"] < cost:
				return false
			currencies["EUR"] = snappedf(currencies["EUR"] - cost, 0.1)
			upgrades[id] = lvl + 1
			currencies_updated.emit()
			return true
	return false

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
	return 1.0 + (targets_hit - 1) * (0.25 * upgrades["multi_hit_bonus"])

func get_rake_radius() -> float:
	return 48.0 + (upgrades["rake_magnet"] * 22.0)

func get_max_stamina() -> float:
	return 100.0 + (upgrades["max_stamina"] * 25.0)

func get_luck_multiplier() -> float:
	return 1.0 + (upgrades["global_luck"] * 0.20)

func get_foot_ice_cream_chance() -> float:
	return (0.10 + upgrades["ice_cream_foot"] * 0.10) * get_luck_multiplier()

func get_rocket_ice_cream_chance() -> float:
	return (upgrades["ice_cream_rocket"] * 0.10) * get_luck_multiplier()

func get_vampire_ice_cream_chance() -> float:
	return (upgrades["ice_cream_vampire"] * 0.18) * get_luck_multiplier()

func get_magnum_ice_cream_chance() -> float:
	return (upgrades["ice_cream_magnum"] * 0.16) * get_luck_multiplier()

func get_shark_ice_cream_chance() -> float:
	return (upgrades["ice_cream_shark"] * 0.12) * get_luck_multiplier()

func get_fridge_summary() -> String:
	var icons: Array[String] = []
	if upgrades["ice_cream_foot"] > 0:
		icons.append("🦶x%d" % upgrades["ice_cream_foot"])
	if upgrades["ice_cream_rocket"] > 0:
		icons.append("🚀x%d" % upgrades["ice_cream_rocket"])
	if upgrades["ice_cream_vampire"] > 0:
		icons.append("🧛x%d" % upgrades["ice_cream_vampire"])
	if upgrades["ice_cream_magnum"] > 0:
		icons.append("🍫x%d" % upgrades["ice_cream_magnum"])
	if upgrades["ice_cream_shark"] > 0:
		icons.append("🦈x%d" % upgrades["ice_cream_shark"])
	if icons.is_empty():
		return "🦶(Muestra)"
	return " ".join(icons)

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
