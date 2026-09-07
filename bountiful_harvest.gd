extends RefCounted

# Basis points: 400 = 4%. Each agriculture/order point adds 4 basis points.
# These balance constants and the versioned hash input are part of save behavior.
const BASE_CHANCE_BP: int = 400
const STAT_CHANCE_BP: int = 4
const MAX_CHANCE_BP: int = 1200
const GRAIN_BONUS_RATE: float = 0.25
const ORDER_BONUS: int = 3


static func chance_bp(province: Dictionary) -> int:
	return mini(MAX_CHANCE_BP, BASE_CHANCE_BP + STAT_CHANCE_BP * (
		clampi(int(province.get("agriculture", 0)), 0, 100)
		+ clampi(int(province.get("public_order", 0)), 0, 100)
	))


static func roll_bp(scenario_id: String, year: int, province_id: String) -> int:
	# No global RNG, time seed, process-dependent hash(), or save-dependent seed.
	var identity: String = "bountiful_harvest:v1|%s|%d|%s" % [scenario_id, year, province_id]
	return identity.sha256_text().substr(0, 8).hex_to_int() % 10000


static func restore_state(value: Variant, saved_year: int, saved_month: int) -> Dictionary:
	var state: Dictionary = {"version": 1, "years": {}}
	if value is Dictionary and value.get("years") is Dictionary:
		state.years = value.years.duplicate(true)
	# Entering September already settles harvest. Do not retroactively grant an
	# event when loading an old September/later save that has no annual record.
	if saved_month >= 9 and not state.years.has(str(saved_year)):
		state.years[str(saved_year)] = {"evaluated": true, "province_id": "", "legacy_settled": true}
	return state


static func apply_september(state: Dictionary, scenario_id: String, year: int,
	month: int, provinces: Dictionary, player_faction: String,
	september_harvests: Dictionary) -> Dictionary:
	if month != 9:
		return {}
	if not state.has("years"):
		state["years"] = {}
	var key: String = str(year)
	if state.years.has(key):
		return {}
	# Record a failed year too: ownership/stat changes cannot re-open September.
	state.years[key] = {"evaluated": true, "province_id": ""}
	var ids: Array = september_harvests.keys()
	ids.sort()
	for id: String in ids:
		if not provinces.has(id) or provinces[id].get("faction", "") != player_faction:
			continue
		var base: int = int(september_harvests[id])
		if base <= 0:
			continue
		var province: Dictionary = provinces[id]
		var chance: int = chance_bp(province)
		var roll: int = roll_bp(scenario_id, year, id)
		if roll >= chance:
			continue
		var grain_delta: int = roundi(float(base) * GRAIN_BONUS_RATE)
		var old_order: int = int(province.get("public_order", 0))
		var new_order: int = mini(100, old_order + ORDER_BONUS)
		var result: Dictionary = {
			"evaluated": true, "applied": true, "province_id": id,
			"province_name": str(province.get("name", id)),
			"september_harvest": base, "grain_delta": grain_delta,
			"public_order_delta": new_order - old_order,
			"roll_bp": roll, "chance_bp": chance,
			"occurrence_id": "bountiful_harvest:v1:%s:%d:%s" % [scenario_id, year, id],
		}
		# Commit the receipt and actual effects synchronously before any UI call.
		state.years[key] = result.duplicate(true)
		province["food_stock"] = int(province.get("food_stock", 0)) + grain_delta
		province["public_order"] = new_order
		return result
	return {}
