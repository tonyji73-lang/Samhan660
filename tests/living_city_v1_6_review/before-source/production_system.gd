extends RefCounted
const Ending=preload("res://campaign_ending.gd")

const Economy = preload("res://faction_economy.gd")
const Industry = preload("res://industry_assignment.gd")

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
			if order.has("last_batches"): order.last_batches=int(order.last_batches)
			# Also protects stale saves/direct ownership changes without running production.
			if bool(order["enabled"]) and str(order["owner"]) != str(provinces[city_id].get("faction", "")):
				order["enabled"] = false
				order["status"] = "중지"
				order["reason"] = "소유권 변경: 새 소유자가 생산을 다시 시작해야 합니다."


static func stop_on_capture(state: Dictionary, city_id: String) -> void:
	if not Ending.finished(state): Industry.Registry.Power.capture(state,city_id)
	if Ending.finished(state): return
	if state.has("industry_version"): Industry.capture(state,city_id,int(state.get("officer_registry",{}).get("clock_month",0)))
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
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
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
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	normalize_state(state, provinces)
	var messages: Array[String] = []
	var payer: String=Economy.resolve(state,faction) if state.has("faction_economy") else faction
	if not state.has("production_months"):
		state["production_months"]={}
		state["production_legacy_month"]=int(state["production_last_month"])
	if state.has("faction_economy"): available_gold=Economy.balance(state,payer)
	if month_key <= int(state.production_months.get(payer,state.get("production_legacy_month",-1))):
		return {"gold": available_gold, "messages": messages}
	# 보류/중지 상태도 이 달의 시도를 마친 것으로 기록합니다. 로드 시 실행하지 않습니다.
	state.production_months[payer]=month_key
	state["production_last_month"] = maxi(month_key,int(state["production_last_month"]))
	if state.has("industry_version"):
		return process_facilities(state,provinces,faction,month_key,scenario_id,supply_rules)
	var city_ids: Array = state["city_production"].keys()
	city_ids.sort()
	# National funds: ascending city ID, then supply -> manufacture in that city.
	# Each faction's stamp covers successes, stopped orders and failures; no retries.
	for city_id: String in city_ids:
		if provinces.get(city_id,{}).get("faction","")!=faction: continue
		if state.has("faction_economy") and not Economy.city_ids(state,provinces).has(city_id): continue
		var orders: Dictionary = state["city_production"][city_id]
		var used_facilities: Dictionary={}
		for recipe_id: String in ["iron_supply","iron_procurement","iron_sword"]:
			var order: Dictionary = orders.get(recipe_id, {})
			if not bool(order.get("enabled", false)):
				continue
			var result: Dictionary
			var facility: String=str(Industry.FACILITY_BY_RECIPE.get(recipe_id,recipe_id))
			if used_facilities.has(facility): continue
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
			if state.has("faction_economy"):
				var paid: Dictionary=Economy.spend(state,provinces,payer,payer,city_id,int(recipe.operating_gold),0,"production",month_key,"production:%s:%s:%d" % [city_id,recipe_id,month_key])
				if not paid.ok: continue
			used_facilities[facility]=true
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

static func process_all(state: Dictionary, provinces: Dictionary, month_key: int, scenario_id: String = "", supply_rules: Dictionary = SupplyData.SCENARIOS) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var messages: Array[String]=[]
	for id: String in state.faction_economy.accounts:
		var result: Dictionary=process_month(state,provinces,str(state.faction_economy.factions[id]),Economy.balance(state,id),month_key,scenario_id,supply_rules)
		messages.append_array(result.messages)
	return {"messages":messages}

static func facility_quote(state: Dictionary, provinces: Dictionary, city: String, facility: String, stamp: int, scenario: String, rules: Dictionary = SupplyData.SCENARIOS) -> Dictionary:
	var faction: String=str(provinces.get(city,{}).get("faction",""))
	var payer: String=Economy.resolve(state,faction)
	var prior: Dictionary=state.get("facility_progress",{}).get(city,{}).get(facility,{})
	var remainder: int=int(prior.get("remainder",0)) if prior.get("owner",faction)==faction else 0
	var capacity: int=Industry.production_work(state,provinces,city,stamp)
	# Only complete 100-work batches can run; fractional work remains below.
	var total: int=remainder+capacity
	var batches: Array[String]=[]
	var reasons: Array[String]=[]
	var shadow: Dictionary=state.duplicate(false)
	shadow.city_inventory=state.city_inventory.duplicate(false)
	shadow.city_inventory[city]=state.city_inventory[city].duplicate(true)
	var gold: int=Economy.balance(state,payer)
	var opening: int=gold
	for n: int in range(int(total/100.0)):
		var chosen: String=""
		for recipe_id: String in Data.RECIPE_ORDER:
			if Industry.FACILITY_BY_RECIPE.get(recipe_id,"")!=facility: continue
			var order: Dictionary=state.city_production[city].get(recipe_id,{})
			if not order.get("enabled",false) or order.get("owner","")!=faction: continue
			var checked: Dictionary=validate_batch(shadow,provinces,city,recipe_id,faction,gold,scenario,rules)
			if not checked.ok:
				if not reasons.has(checked.reason): reasons.append(checked.reason)
				continue
			chosen=recipe_id; break
		if chosen.is_empty(): break
		var recipe: Dictionary=Data.RECIPES[chosen]
		gold-=int(recipe.operating_gold)
		for item: String in recipe.inputs: shadow.city_inventory[city][item]=int(shadow.city_inventory[city].get(item,0))-int(recipe.inputs[item])
		for item: String in recipe.outputs: shadow.city_inventory[city][item]=int(shadow.city_inventory[city].get(item,0))+int(recipe.outputs[item])
		batches.append(chosen)
	if batches.is_empty() and reasons.is_empty(): reasons.append("가동 생산 명령 없음 · 생산 화면에서 가동 설정 필요")
	return {"work":capacity,"remainder_before":remainder,"remainder":total%100 if not batches.is_empty() else remainder,"batches":batches,"gold_cost":opening-gold,"inventory":shadow.city_inventory[city],"reason":" / ".join(reasons),"possible_batches":int(total/100.0)}

static func city_quote(state: Dictionary, provinces: Dictionary, city: String, stamp: int, scenario: String, rules: Dictionary = SupplyData.SCENARIOS) -> Dictionary:
	# Quote the same supply -> manufacture sequence, on isolated temporary resources.
	var shadow: Dictionary=state.duplicate(true)
	var result: Dictionary={}
	var payer: String=Economy.resolve(state,str(provinces[city].faction))
	for facility: String in ["smelter","forge"]:
		var q: Dictionary=facility_quote(shadow,provinces,city,facility,stamp,scenario,rules)
		result[facility]=q
		shadow.city_inventory[city]=q.inventory
		shadow.faction_economy.accounts[payer].balance=int(shadow.faction_economy.accounts[payer].balance)-int(q.gold_cost)
	return result

static func process_facilities(state: Dictionary, provinces: Dictionary, faction: String, stamp: int, scenario: String, rules: Dictionary) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var messages: Array[String]=[]
	var payer: String=Economy.resolve(state,faction)
	Industry.validate_ownership(state,provinces,stamp)
	var cities: Array[String]=Economy.city_ids(state,provinces); cities.sort()
	for city: String in cities:
		if provinces[city].faction!=faction: continue
		if not state.facility_progress.has(city): state.facility_progress[city]={}
		for facility: String in ["smelter","forge"]:
			var prior: Dictionary=state.facility_progress[city].get(facility,{"last_month":-1,"remainder":0,"owner":faction})
			if int(prior.last_month)>=stamp: continue
			var q: Dictionary=facility_quote(state,provinces,city,facility,stamp,scenario,rules)
			var paid: Dictionary=Economy.spend(state,provinces,payer,payer,city,int(q.gold_cost),0,"production",stamp,"facility:%s:%s:%d" % [city,facility,stamp]) if not q.batches.is_empty() else {"ok":true}
			if not paid.ok: continue
			state.city_inventory[city]=q.inventory
			state.facility_progress[city][facility]={"owner":faction,"last_month":stamp,"remainder":q.remainder,"last_work":q.work,"last_batches":q.batches.size(),"last_gold":q.gold_cost,"reason":q.reason}
			for recipe_id: String in Data.RECIPE_ORDER:
				if Industry.FACILITY_BY_RECIPE.get(recipe_id,"")!=facility: continue
				var order: Dictionary=state.city_production[city][recipe_id]
				if not order.enabled: continue
				var count: int=q.batches.count(recipe_id)
				order.status="생산 완료" if count>0 else "보류"
				order.reason=q.reason
				order["last_batches"]=count
				messages.append("%s · %s %d배치 · 금 %d · 잔여 작업량 %d/100%s" % [provinces[city].name,Data.RECIPES[recipe_id].name,count,q.gold_cost,q.remainder," · "+str(q.reason) if not str(q.reason).is_empty() else ""])
	return {"gold":Economy.balance(state,payer),"messages":messages}
