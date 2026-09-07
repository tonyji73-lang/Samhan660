extends RefCounted

# Balance rules, not historical statistics. Versioned SHA identity is save-stable.
const Regions = preload("res://korea_35_data.gd")
const EVENT_ID: String = "domestic_crop_failure"
const EFFECTS: Dictionary = {
	"relieve_people": {"grain": -800, "order": 8, "title": "백성을 구휼했습니다"},
	"maintain_tax": {"grain": 0, "order": -6, "title": "기존 징수를 유지했습니다"},
	"force_requisition": {"grain": 500, "order": -12, "title": "군량을 징발했습니다"},
}


static func chance_bp(province: Dictionary) -> int:
	return clampi(1200 - 4 * (clampi(int(province.get("agriculture", 0)), 0, 100)
		+ clampi(int(province.get("public_order", 0)), 0, 100)), 400, 1200)


static func roll_bp(scenario: String, year: int, province_id: String) -> int:
	return ("crop_failure:v1|%s|%d|%s" % [scenario, year, province_id]).sha256_text().substr(0, 8).hex_to_int() % 10000


static func restore_state(value: Variant, year: int, month: int) -> Dictionary:
	var state: Dictionary = {"version": 1, "years": {}, "pending": {}, "resolved": {}}
	if value is Dictionary:
		for key: String in ["years", "pending", "resolved"]:
			if value.get(key) is Dictionary:
				state[key] = value[key].duplicate(true)
	if month >= 9 and not state.years.has(str(year)):
		state.years[str(year)] = {"evaluated": true, "province_id": "", "legacy_settled": true}
	if not state.pending.is_empty() and state.resolved.has(str(state.pending.get("occurrence_id", ""))):
		state.pending = {}
	if state.pending.get("payload") is Dictionary and state.pending.payload.has("harvest_loss"):
		state.pending.payload.harvest_loss = int(state.pending.payload.harvest_loss)
	return state


static func cancel_if_unowned(state: Dictionary, provinces: Dictionary, player: String) -> bool:
	var pending: Dictionary = state.get("pending", {})
	if pending.is_empty():
		return false
	var id: String = str(pending.get("province_id", ""))
	if provinces.has(id) and provinces[id].get("faction", "") == player:
		return false
	# September AI combat can capture the territory after damage was settled.
	# Retain settled damage, but never change another owner's resources or leave
	# an impossible decision blocking all future annual events.
	if not state.has("resolved"):
		state.resolved = {}
	state.resolved[str(pending.get("occurrence_id", ""))] = {"cancelled": true, "reason": "ownership_changed"}
	state.pending = {}
	return true


static func apply_september(state: Dictionary, scenario: String, year: int, month: int,
	provinces: Dictionary, player: String, harvests: Dictionary, bounty_id: String) -> Dictionary:
	if month != 9 or not state.get("pending", {}).is_empty():
		return {}
	if not state.has("years"):
		state.years = {}
	if state.years.has(str(year)):
		return {}
	state.years[str(year)] = {"evaluated": true, "province_id": ""}
	# Explicit world-data order, independent of dictionary insertion order.
	for id: String in Regions.PROVINCE_IDS:
		if id == bounty_id or not provinces.has(id) or int(harvests.get(id, 0)) <= 0:
			continue
		var province: Dictionary = provinces[id]
		if province.get("faction", "") != player or roll_bp(scenario, year, id) >= chance_bp(province):
			continue
		var loss: int = mini(maxi(0, int(province.get("food_stock", 0))), roundi(int(harvests[id]) * 0.30))
		var occurrence: String = "crop_failure:v1:%s:%d:%s" % [scenario, year, id]
		var payload: Dictionary = {"province_name": str(province.get("name", id)), "harvest_loss": loss}
		var pending: Dictionary = {"event_id": EVENT_ID, "occurrence_id": occurrence, "province_id": id, "payload": payload}
		state.years[str(year)] = {"evaluated": true, "province_id": id, "harvest_loss": loss, "occurrence_id": occurrence}
		state.pending = pending.duplicate(true)
		province.food_stock = int(province.get("food_stock", 0)) - loss
		return pending
	return {}


static func choice_reason(state: Dictionary, provinces: Dictionary, player: String, occurrence: String, choice: String) -> String:
	var pending: Dictionary = state.get("pending", {})
	if pending.is_empty() or str(pending.get("occurrence_id", "")) != occurrence or state.get("resolved", {}).has(occurrence):
		return "이미 처리된 선택입니다"
	var id: String = str(pending.get("province_id", ""))
	if not provinces.has(id) or provinces[id].get("faction", "") != player:
		return "플레이어 영지가 아닙니다"
	if not EFFECTS.has(choice):
		return "알 수 없는 선택입니다"
	if choice == "relieve_people" and int(provinces[id].get("food_stock", 0)) < 800:
		return "군량 800 필요"
	return ""


static func resolve(state: Dictionary, provinces: Dictionary, player: String, occurrence: String, choice: String) -> Dictionary:
	if not choice_reason(state, provinces, player, occurrence, choice).is_empty():
		return {}
	var province: Dictionary = provinces[str(state.pending.province_id)]
	var effect: Dictionary = EFFECTS[choice]
	var old_food: int = int(province.get("food_stock", 0))
	var old_order: int = int(province.get("public_order", 0))
	var new_food: int = maxi(0, old_food + int(effect.grain))
	var new_order: int = clampi(old_order + int(effect.order), 0, 100)
	var result: Dictionary = {"choice_id": choice, "choice_result_title": effect.title,
		"grain_delta": new_food - old_food, "public_order_delta": new_order - old_order,
		"grain_result_text": "%+d" % (new_food - old_food),
		"public_order_result_text": "%+d" % (new_order - old_order)}
	if not state.has("resolved"):
		state.resolved = {}
	# Synchronous receipt + effects, with no signals/await until commit completes.
	state.resolved[occurrence] = result.duplicate(true)
	province.food_stock = new_food
	province.public_order = new_order
	state.pending = {}
	return result
