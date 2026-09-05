extends RefCounted

const Data = preload("res://production_data.gd")
const SupplyData = preload("res://iron_supply_data.gd")


static func normalize_state(state: Dictionary, provinces: Dictionary) -> void:
	for key: String in ["city_inventory", "city_production"]:
		if typeof(state.get(key)) != TYPE_DICTIONARY:
			state[key] = {}
	state["production_last_month"] = int(state.get("production_last_month", -1))
	for city_id: String in provinces:
		if typeof(state["city_inventory"].get(city_id)) != TYPE_DICTIONARY:
			state["city_inventory"][city_id] = {}
		var inventory: Dictionary = state["city_inventory"][city_id]
		# 정식 이전 저장은 iron/sword만 가집니다. 별칭이 들어온 경우에도 합산하지 않습니다.
		# canonical sword가 있으면 우선하고, 별칭만 있으면 해당 값 하나를 이동합니다.
		if inventory.has("weapons"):
			if not inventory.has("sword"):
				inventory["sword"] = maxi(0, int(inventory["weapons"]))
			inventory.erase("weapons")
		# 곡물의 유일한 원장은 provinces[id].food_stock입니다. 복사/합산/지급하지 않습니다.
		inventory.erase("grain")
		for item_id: String in Data.ITEMS:
			if not bool(Data.ITEMS[item_id]["enabled"]) or str(Data.ITEMS[item_id]["storage"]) != "city_inventory":
				continue
			inventory[item_id] = maxi(0, int(inventory.get(item_id, 0)))
		if typeof(state["city_production"].get(city_id)) != TYPE_DICTIONARY:
			state["city_production"][city_id] = {}
		var orders: Dictionary = state["city_production"][city_id]
		for recipe_id: String in Data.RECIPES:
			if typeof(orders.get(recipe_id)) != TYPE_DICTIONARY:
				orders[recipe_id] = {}
			var order: Dictionary = orders[recipe_id]
			order["enabled"] = bool(order.get("enabled", false))
			order["owner"] = str(order.get("owner", ""))
			order["status"] = str(order.get("status", "중지"))
			order["reason"] = str(order.get("reason", ""))
			# Also protects stale saves/direct ownership changes without running production.
			if bool(order["enabled"]) and str(order["owner"]) != str(provinces[city_id].get("faction", "")):
				order["enabled"] = false
				order["status"] = "중지"
				order["reason"] = "소유권 변경: 새 소유자가 생산을 다시 시작해야 합니다."


static func stop_on_capture(state: Dictionary, city_id: String) -> void:
	# Call at the ownership transition, including capture followed by recapture in
	# the same month. Stocks, buildings, research and month stamp remain untouched.
	for order: Dictionary in state.get("city_production", {}).get(city_id, {}).values():
		order["enabled"] = false
		order["status"] = "중지"
		order["reason"] = "소유권 변경: 새 소유자가 생산을 다시 시작해야 합니다."


static func get_stock(state: Dictionary, provinces: Dictionary, city_id: String, item_id: String) -> int:
	var canonical: String = Data.canonical_item_id(item_id)
	if not Data.ITEMS.has(canonical) or not provinces.has(city_id):
		return 0
	if str(Data.ITEMS[canonical]["storage"]) == "province_food_stock":
		return maxi(0, int(provinces[city_id].get("food_stock", 0)))
	return maxi(0, int(state.get("city_inventory", {}).get(city_id, {}).get(canonical, 0)))


static func get_inventory_view(state: Dictionary, provinces: Dictionary, city_id: String) -> Dictionary:
	# UI 전용 조회 결과입니다. 이 사전을 city_inventory에 저장하면 안 됩니다.
	var result: Dictionary = {}
	for item_id: String in Data.ITEMS:
		if bool(Data.ITEMS[item_id]["enabled"]):
			result[item_id] = get_stock(state, provinces, city_id, item_id)
	return result


static func ownership_reason(provinces: Dictionary, city_id: String, faction: String) -> String:
	if not provinces.has(city_id):
		return "도시가 존재하지 않습니다."
	if faction.is_empty() or str(provinces[city_id].get("faction", "")) != faction:
		return "현재 소유권이 다릅니다. 아군 도시에서만 명령할 수 있습니다."
	return ""


static func validate_batch(
	state: Dictionary, provinces: Dictionary, city_id: String,
	recipe_id: String, faction: String, available_gold: int,
	scenario_id: String = "", supply_rules: Dictionary = SupplyData.SCENARIOS
) -> Dictionary:
	var reasons: Array[String] = []
	var ownership: String = ownership_reason(provinces, city_id, faction)
	if ownership != "":
		return {"ok": false, "reason": ownership}
	if not Data.recipe_is_enabled(recipe_id):
		return {"ok": false, "reason": "알 수 없는 생산법입니다."}
	var recipe: Dictionary = Data.RECIPES[recipe_id]
	if bool(recipe.get("regional_supply", false)):
		var regional_reason: String = SupplyData.blocked_reason(scenario_id, city_id, supply_rules)
		if regional_reason != "":
			reasons.append(regional_reason)
	var research: Dictionary = state.get("faction_research", {}).get(faction, {})
	var buildings: Dictionary = state.get("province_buildings", {}).get(city_id, {})
	var inventory: Dictionary = state.get("city_inventory", {}).get(city_id, {})
	for tech_id: String in recipe["research"]:
		if int(research.get(tech_id, 0)) < int(recipe["research"][tech_id]):
			reasons.append("필요 기술 미연구: %s" % tech_id)
	for facility_id: String in recipe["buildings"]:
		if int(buildings.get(facility_id, 0)) < int(recipe["buildings"][facility_id]):
			reasons.append("필요 시설 미완공: %s" % facility_id)
	for item_id: String in recipe["inputs"]:
		if int(inventory.get(item_id, 0)) < int(recipe["inputs"][item_id]):
			reasons.append("재료 부족: %s 부족" % str(Data.ITEMS[item_id]["name"]))
	if available_gold < int(recipe["operating_gold"]):
		reasons.append("국가 금 부족")
	return {"ok": reasons.is_empty(), "reason": " / ".join(reasons)}


static func set_enabled(
	state: Dictionary, provinces: Dictionary, city_id: String,
	recipe_id: String, faction: String, enabled: bool,
	scenario_id: String = "", supply_rules: Dictionary = SupplyData.SCENARIOS
) -> Dictionary:
	var reason: String = ownership_reason(provinces, city_id, faction)
	if reason != "":
		return {"ok": false, "reason": reason}
	if not Data.recipe_is_enabled(recipe_id):
		return {"ok": false, "reason": "알 수 없는 생산법입니다."}
	if enabled and bool(Data.RECIPES[recipe_id].get("regional_supply", false)):
		var regional_reason: String = SupplyData.blocked_reason(scenario_id, city_id, supply_rules)
		if regional_reason != "":
			return {"ok": false, "reason": regional_reason}
	normalize_state(state, provinces)
	var order: Dictionary = state["city_production"][city_id][recipe_id]
	order["enabled"] = enabled
	order["owner"] = faction
	order["status"] = "대기" if enabled else "중지"
	order["reason"] = ""
	return {"ok": true, "message": "매월 생산을 예약했습니다." if enabled else "생산을 중지했습니다."}


static func process_month(
	state: Dictionary, provinces: Dictionary, faction: String,
	available_gold: int, month_key: int,
	scenario_id: String = "", supply_rules: Dictionary = SupplyData.SCENARIOS
) -> Dictionary:
	normalize_state(state, provinces)
	var messages: Array[String] = []
	if month_key <= int(state["production_last_month"]):
		return {"gold": available_gold, "messages": messages}
	# 보류/중지 상태도 이 달의 시도를 마친 것으로 기록합니다. 로드 시 실행하지 않습니다.
	state["production_last_month"] = month_key
	var city_ids: Array = state["city_production"].keys()
	city_ids.sort()
	# National funds: ascending city ID, then supply -> manufacture in that city.
	# One shared stamp covers successes, stopped orders and failures; no retries.
	for city_id: String in city_ids:
		var orders: Dictionary = state["city_production"][city_id]
		for recipe_id: String in Data.RECIPE_ORDER:
			var order: Dictionary = orders.get(recipe_id, {})
			if not bool(order.get("enabled", false)):
				continue
			var result: Dictionary
			if str(order.get("owner", "")) != faction:
				result = {"ok": false, "reason": "생산 명령의 소유 세력이 달라 재설정이 필요합니다."}
			else:
				result = validate_batch(state, provinces, city_id, recipe_id, faction, available_gold, scenario_id, supply_rules)
			if not bool(result["ok"]):
				order["status"] = "보류"
				order["reason"] = str(result["reason"])
				messages.append("%s 생산 보류: %s" % [city_id, order["reason"]])
				continue
			var recipe: Dictionary = Data.RECIPES[recipe_id]
			var inventory: Dictionary = state["city_inventory"][city_id]
			# 모든 조건을 먼저 확인한 뒤 한 배치를 일괄 반영합니다.
			for item_id: String in recipe["inputs"]:
				inventory[item_id] = int(inventory.get(item_id, 0)) - int(recipe["inputs"][item_id])
			available_gold -= int(recipe["operating_gold"])
			for item_id: String in recipe["outputs"]:
				inventory[item_id] = int(inventory.get(item_id, 0)) + int(recipe["outputs"][item_id])
			order["status"] = "생산 완료"
			order["reason"] = ""
			messages.append("%s: %s 월 생산 완료" % [str(provinces[city_id].get("name", city_id)), recipe["name"]])
	return {"gold": available_gold, "messages": messages}
