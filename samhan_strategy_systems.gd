extends RefCounted

# 삼한660 장기 전략 백엔드 V2
# UI와 분리된 순수 데이터 모듈입니다. 모든 상태는 JSON 저장이 가능한 Dictionary/Array로 유지합니다.

const STATE_VERSION: int = 3
const GENERATED_STAT_CAP: int = 72
const DYNASTIC_STAT_CAP: int = 88
const ADULT_AGE: int = 16
const MAX_AUTO_OFFICERS_PER_FACTION_YEAR: int = 2
const STAT_KEYS: Array[String] = [
	"leadership", "war", "intelligence", "politics", "authority"
]

const FACTION_ALIASES: Dictionary = {
	"silla": "신라",
	"baekje": "백제",
	"goguryeo": "고구려",
	"baekje_revival": "백제부흥군",
	"goguryeo_revival": "고구려부흥군",
	"tang": "당",
	"yamato": "왜(야마토 조정)",
	"xueyantuo": "설연타",
}

const BUILDING_DEFS: Dictionary = {
	"barracks": {"name": "병영", "max_level": 3, "base_gold": 220, "base_turns": 1, "effect": "징병·주둔군과 보병 해금"},
	"academy": {"name": "강무학당", "max_level": 3, "base_gold": 260, "base_turns": 2, "effect": "정예병 훈련과 장수 교육"},
	"stables": {"name": "마장", "max_level": 3, "base_gold": 280, "base_turns": 2, "effect": "기병 생산과 이동력 강화"},
	"dockyard": {"name": "선창", "max_level": 3, "base_gold": 300, "base_turns": 2, "effect": "수군 생산과 해상 수송"},
	"forge": {"name": "군기감", "max_level": 3, "base_gold": 320, "base_turns": 2, "effect": "무기·갑주와 공격력 강화"},
	"market": {"name": "시장", "max_level": 3, "base_gold": 200, "base_turns": 1, "effect": "금 수입과 교역로 개설"},
	"caravanserai": {"name": "역관", "max_level": 3, "base_gold": 240, "base_turns": 1, "effect": "육상 교역과 사절 이동"},
	"embassy": {"name": "객관", "max_level": 3, "base_gold": 260, "base_turns": 2, "effect": "외교 성공률과 관계 유지"},
}

const RESEARCH_DEFS: Dictionary = {
	"infantry": {"name": "보병 전술", "max_level": 3, "base_gold": 260, "base_turns": 2, "effect": "보병 전투력과 정예 보병 해금"},
	"archery": {"name": "궁술", "max_level": 3, "base_gold": 280, "base_turns": 2, "effect": "궁병 사거리와 집중 사격 강화"},
	"cavalry": {"name": "기병 전술", "max_level": 3, "base_gold": 300, "base_turns": 2, "effect": "기병 돌격력과 정예 기병 해금"},
	"naval": {"name": "수군 전술", "max_level": 3, "base_gold": 300, "base_turns": 2, "effect": "수군 전투력과 상륙 작전"},
	"logistics": {"name": "군량 수송", "max_level": 3, "base_gold": 240, "base_turns": 2, "effect": "행군 군량 절감과 원거리 보급"},
	"commerce": {"name": "교역 제도", "max_level": 3, "base_gold": 220, "base_turns": 2, "effect": "교역 수입과 무역 안정성"},
	"diplomacy": {"name": "외교 제도", "max_level": 3, "base_gold": 240, "base_turns": 2, "effect": "교섭 성공률과 조약 선택지"},
}

const RECRUIT_UNIT_DEFS: Dictionary = {
	"infantry": {
		"name": "보병", "category": "infantry", "power": 50,
		"gold_per_1000": 150, "food_per_1000": 200,
		"buildings": {"barracks": 1}, "research": {},
		"role": "저렴한 주력 병종 · 성곽과 방어에 유리",
	},
	"archer": {
		"name": "궁병", "category": "archer", "power": 56,
		"gold_per_1000": 220, "food_per_1000": 250,
		"buildings": {"barracks": 1, "forge": 1}, "research": {"archery": 1},
		"role": "원거리 공격 · 방어선 후방 지원",
	},
	"cavalry": {
		"name": "기병", "category": "cavalry", "power": 62,
		"gold_per_1000": 350, "food_per_1000": 400,
		"buildings": {"stables": 1}, "research": {"cavalry": 1},
		"role": "높은 기동력과 돌격력 · 유지 비용이 큼",
	},
}

const SPECIAL_UNIT_CATEGORY: Dictionary = {
	"silla_seodang": "infantry",
	"silla_nangdo": "cavalry",
	"baekje_guard": "infantry",
	"baekje_navy": "naval",
	"goguryeo_gaemamusa": "cavalry",
	"goguryeo_fort_guard": "infantry",
	"tang_xuanjia": "cavalry",
	"tang_expedition_navy": "naval",
	"yamato_navy": "naval",
	"steppe_cavalry": "cavalry",
}

const AFFINITY_GRADE_BONUS: Dictionary = {
	"S": 18, "A": 12, "B": 6, "C": 0,
}

const HISTORICAL_AFFINITIES: Dictionary = {
	"김유신": {"infantry": "A", "archer": "B", "cavalry": "S"},
	"김인문": {"infantry": "B", "archer": "A", "cavalry": "C"},
	"김흠순": {"infantry": "A", "archer": "C", "cavalry": "A"},
	"김춘추": {"infantry": "B", "archer": "A", "cavalry": "C"},
	"계백": {"infantry": "S", "archer": "B", "cavalry": "A"},
	"흑치상지": {"infantry": "A", "archer": "B", "cavalry": "S"},
	"연개소문": {"infantry": "S", "archer": "A", "cavalry": "S"},
	"양만춘": {"infantry": "S", "archer": "S", "cavalry": "B"},
	"소정방": {"infantry": "A", "archer": "A", "cavalry": "S"},
}

# 특수 병종은 세력 고유 잠재력일 뿐입니다. 연구와 현지 건물이 모두 충족되어야 실제 사용됩니다.
const SPECIAL_UNIT_DEFS: Dictionary = {
	"silla_seodang": {
		"name": "서당 정예군", "faction": "신라", "power": 76,
		"research": {"infantry": 2, "logistics": 1},
		"buildings": {"barracks": 2, "academy": 1},
		"bonus": "사기·지휘 보너스",
	},
	"silla_nangdo": {
		"name": "낭도 기병", "faction": "신라", "power": 80,
		"research": {"cavalry": 2},
		"buildings": {"stables": 2, "academy": 2},
		"bonus": "산악·기동 보너스",
	},
	"baekje_guard": {
		"name": "백제 결사대", "faction": "백제", "power": 78,
		"research": {"infantry": 2},
		"buildings": {"barracks": 2, "forge": 1},
		"bonus": "성곽 방어·역습 보너스",
	},
	"baekje_navy": {
		"name": "백제 정예수군", "faction": "백제", "power": 82,
		"research": {"naval": 2, "logistics": 1},
		"buildings": {"dockyard": 2, "academy": 1},
		"bonus": "해상 이동·상륙 보너스",
	},
	"goguryeo_gaemamusa": {
		"name": "개마무사", "faction": "고구려", "power": 92,
		"research": {"cavalry": 3},
		"buildings": {"stables": 3, "forge": 2},
		"bonus": "중기병 돌격·방어 보너스",
	},
	"goguryeo_fort_guard": {
		"name": "산성 수비군", "faction": "고구려", "power": 79,
		"research": {"infantry": 2, "logistics": 1},
		"buildings": {"barracks": 2, "forge": 1},
		"bonus": "산성 방어·군량 절감",
	},
	"tang_xuanjia": {
		"name": "현갑 정예기병", "faction": "당", "power": 94,
		"research": {"cavalry": 3, "logistics": 2},
		"buildings": {"stables": 3, "forge": 3},
		"bonus": "평지 돌격·갑주 방어",
	},
	"tang_expedition_navy": {
		"name": "당 원정수군", "faction": "당", "power": 84,
		"research": {"naval": 2, "logistics": 2},
		"buildings": {"dockyard": 2},
		"bonus": "원거리 보급·상륙",
	},
	"yamato_navy": {
		"name": "야마토 원정수군", "faction": "왜(야마토 조정)", "power": 78,
		"research": {"naval": 2},
		"buildings": {"dockyard": 2, "caravanserai": 1},
		"bonus": "해상 수송·원군",
	},
	"steppe_cavalry": {
		"name": "초원 정예기병", "faction_group": "steppe", "power": 84,
		"research": {"cavalry": 2},
		"buildings": {"stables": 2},
		"bonus": "장거리 이동·추격",
	},
}

const SIGNATURE_UNITS_BY_FACTION_ID: Dictionary = {
	"silla": ["서당 정예군", "낭도 기병"],
	"baekje": ["백제 결사대", "백제 정예수군"],
	"goguryeo": ["개마무사", "산성 수비군"],
	"tang": ["현갑 정예기병", "당 원정수군"],
	"yamato": ["야마토 원정수군"],
	"xueyantuo": ["초원 정예기병"],
	"huihe": ["초원 정예기병"],
	"pugu": ["초원 정예기병"],
	"tongluo": ["초원 정예기병"],
	"bayegu": ["초원 정예기병"],
	"sijie": ["초원 정예기병"],
	"qibi": ["초원 정예기병"],
	"hun": ["초원 정예기병"],
	"duolange": ["초원 정예기병"],
	"adie": ["초원 정예기병"],
}

const EDUCATION_PATHS: Dictionary = {
	"balanced": {"name": "균형 교육", "growth": {"leadership": 1, "war": 1, "intelligence": 1, "politics": 1, "authority": 1}},
	"martial": {"name": "무예 수련", "growth": {"war": 3, "leadership": 1}},
	"command": {"name": "병법 교육", "growth": {"leadership": 3, "intelligence": 1}},
	"scholar": {"name": "경학 교육", "growth": {"intelligence": 3, "politics": 1}},
	"administration": {"name": "행정 교육", "growth": {"politics": 3, "authority": 1}},
	"diplomacy": {"name": "외교 교육", "growth": {"authority": 2, "politics": 2, "intelligence": 1}},
}

const COMMON_SKILLS: Array[String] = [
	"징병 보조", "치안 보조", "행군 보조", "농정 보조", "상업 보조", "수비 보조"
]

const NAME_POOLS: Dictionary = {
	"신라": {"surnames": ["김", "박", "석"], "given": ["유담", "흠진", "사륜", "문달", "지명", "천광", "원진", "진복"]},
	"백제": {"surnames": ["부여", "사택", "흑치", "연", "해"], "given": ["문진", "복신", "도침", "충달", "진수", "덕무", "의광"]},
	"백제부흥군": {"surnames": ["부여", "사택", "흑치", "연"], "given": ["복진", "도광", "충무", "문달", "진수"]},
	"고구려": {"surnames": ["고", "연", "을지", "대", "고돌"], "given": ["건무", "남진", "연수", "무달", "덕창", "온사", "진명"]},
	"고구려부흥군": {"surnames": ["고", "연", "을지", "대"], "given": ["연무", "덕진", "건달", "온명", "진수"]},
	"당": {"surnames": ["이", "유", "소", "왕", "장", "설"], "given": ["경업", "인덕", "현무", "문진", "정원", "덕창", "지원"]},
	"왜(야마토 조정)": {"surnames": ["아베노 ", "소가노 ", "나카토미노 ", "오토모노 "], "given": ["히로마로", "다케루", "무라지", "구라마로", "아즈마"]},
	"default": {"surnames": ["아사", "바야", "투르", "쿠르"], "given": ["테긴", "보리", "카간", "타르", "미르"]},
}


func _new_turn_actions(current_year: int, season_index: int) -> Dictionary:
	return {
		"year": current_year,
		"season_index": season_index,
		"province_used": {},
		"officer_used": {},
		"research_used": false,
	}


func _base_unit_roster(total_troops: int) -> Dictionary:
	return {
		"infantry": {
			"name": "보병", "category": "infantry",
			"troops": maxi(0, total_troops), "training": 50, "morale": 55,
		},
		"archer": {
			"name": "궁병", "category": "archer",
			"troops": 0, "training": 50, "morale": 50,
		},
		"cavalry": {
			"name": "기병", "category": "cavalry",
			"troops": 0, "training": 50, "morale": 50,
		},
	}


func create_initial_state(
	current_year: int,
	provinces: Dictionary,
	officers: Dictionary,
	officers_by_province: Dictionary,
	scenario: Dictionary,
	current_season_index: int = 0
) -> Dictionary:
	var state: Dictionary = {
		"version": STATE_VERSION,
		"created_year": current_year,
		"officer_metadata": {},
		"emergent_officers": {},
		"province_buildings": {},
		"unit_rosters": {},
		"construction_queues": {},
		"faction_research": {},
		"research_queues": {},
		"relations": {},
		"trade_routes": [],
		"next_trade_route_id": 1,
		"auto_generation": {"counts_by_year": {}},
		"dynasty": {"people": {}, "marriages": [], "children": {}, "next_child_id": 1},
		"turn_actions": _new_turn_actions(current_year, current_season_index),
	}

	var faction_names: Array[String] = _collect_faction_names(provinces, scenario)
	var capital_by_faction: Dictionary = _get_capitals_by_faction(provinces, scenario)
	for province_id_value: Variant in provinces.keys():
		var province_id: String = str(province_id_value)
		var province: Dictionary = provinces[province_id]
		var faction_name: String = str(province.get("faction", ""))
		var is_capital: bool = str(capital_by_faction.get(faction_name, "")) == province_id
		state["province_buildings"][province_id] = {
			"barracks": 1 if int(province.get("fortress", 0)) >= 60 else 0,
			"academy": 1 if is_capital else 0,
			"stables": 0,
			"dockyard": 0,
			"forge": 0,
			"market": 1 if is_capital or int(province.get("commerce", 0)) >= 70 else 0,
			"caravanserai": 0,
			"embassy": 1 if is_capital else 0,
		}
		state["unit_rosters"][province_id] = _base_unit_roster(
			int(province.get("troops", 0))
		)

	for faction_name: String in faction_names:
		state["faction_research"][faction_name] = _empty_research_levels()

	for first_index: int in range(faction_names.size()):
		for second_index: int in range(first_index + 1, faction_names.size()):
			var key: String = _relation_key(faction_names[first_index], faction_names[second_index])
			state["relations"][key] = {"value": 0, "status": "중립", "treaties": []}
	_apply_historical_start_relations(state, current_year)

	var officer_factions: Dictionary = _map_officer_factions(provinces, officers_by_province)
	for officer_name_value: Variant in officers.keys():
		var officer_name: String = str(officer_name_value)
		var officer: Dictionary = officers[officer_name]
		state["officer_metadata"][officer_name] = {
			"origin": "historical",
			"is_historical": true,
			"featured_eligible": true,
			"faction_screen_eligible": true,
			"faction": str(officer_factions.get(officer_name, "")),
			"quality_tier": "historical",
		}
		state["dynasty"]["people"][officer_name] = _person_from_officer(
			officer_name, officer, str(officer_factions.get(officer_name, "")), "historical"
		)
	return state


func normalize_loaded_state(state: Dictionary, provinces: Dictionary = {}) -> Dictionary:
	if state.is_empty():
		return state
	state["version"] = STATE_VERSION
	for key: String in [
		"officer_metadata", "emergent_officers", "province_buildings",
		"construction_queues", "faction_research", "research_queues", "relations",
		"unit_rosters"
	]:
		if typeof(state.get(key, null)) != TYPE_DICTIONARY:
			state[key] = {}
	if typeof(state.get("trade_routes", null)) != TYPE_ARRAY:
		state["trade_routes"] = []
	if typeof(state.get("dynasty", null)) != TYPE_DICTIONARY:
		state["dynasty"] = {"people": {}, "marriages": [], "children": {}, "next_child_id": 1}
	if typeof(state.get("auto_generation", null)) != TYPE_DICTIONARY:
		state["auto_generation"] = {"counts_by_year": {}}
	if typeof(state.get("turn_actions", null)) != TYPE_DICTIONARY:
		state["turn_actions"] = _new_turn_actions(
			int(state.get("created_year", 660)), 0
		)
	if not provinces.is_empty():
		ensure_unit_rosters(state, provinces)
	return state


func reset_turn_actions(state: Dictionary, current_year: int, season_index: int) -> void:
	state["turn_actions"] = _new_turn_actions(current_year, season_index)


func ensure_turn_actions_for_turn(
	state: Dictionary, current_year: int, season_index: int
) -> void:
	var actions: Dictionary = state.get("turn_actions", {})
	if (
		int(actions.get("year", -1)) != current_year
		or int(actions.get("season_index", -1)) != season_index
	):
		reset_turn_actions(state, current_year, season_index)


func is_province_action_used(state: Dictionary, province_id: String) -> bool:
	return bool(
		state.get("turn_actions", {}).get("province_used", {}).get(province_id, false)
	)


func is_officer_action_used(state: Dictionary, officer_name: String) -> bool:
	return bool(
		state.get("turn_actions", {}).get("officer_used", {}).get(officer_name, false)
	)


func is_research_action_used(state: Dictionary) -> bool:
	return bool(state.get("turn_actions", {}).get("research_used", false))


func mark_domestic_action(
	state: Dictionary,
	province_id: String,
	officer_name: String,
	uses_research_action: bool = false
) -> void:
	var actions: Dictionary = state.get("turn_actions", {})
	var province_used: Dictionary = actions.get("province_used", {})
	var officer_used: Dictionary = actions.get("officer_used", {})
	province_used[province_id] = true
	officer_used[officer_name] = true
	actions["province_used"] = province_used
	actions["officer_used"] = officer_used
	if uses_research_action:
		actions["research_used"] = true
	state["turn_actions"] = actions


func ensure_unit_rosters(state: Dictionary, provinces: Dictionary) -> void:
	if typeof(state.get("unit_rosters", null)) != TYPE_DICTIONARY:
		state["unit_rosters"] = {}
	for province_id_value: Variant in provinces.keys():
		var province_id: String = str(province_id_value)
		if typeof(state["unit_rosters"].get(province_id, null)) != TYPE_DICTIONARY:
			state["unit_rosters"][province_id] = _base_unit_roster(
				int(provinces[province_id].get("troops", 0))
			)
		else:
			reconcile_unit_roster(
				state, province_id, int(provinces[province_id].get("troops", 0))
			)


func reconcile_unit_roster(
	state: Dictionary, province_id: String, total_troops: int
) -> Dictionary:
	var rosters: Dictionary = state.get("unit_rosters", {})
	if typeof(rosters.get(province_id, null)) != TYPE_DICTIONARY:
		rosters[province_id] = _base_unit_roster(total_troops)
		state["unit_rosters"] = rosters
		return rosters[province_id]
	var roster: Dictionary = rosters[province_id]
	for base_id: String in ["infantry", "archer", "cavalry"]:
		if typeof(roster.get(base_id, null)) != TYPE_DICTIONARY:
			roster[base_id] = _base_unit_roster(0)[base_id]
	var roster_total: int = _roster_total(roster)
	total_troops = maxi(0, total_troops)
	if roster_total < total_troops:
		var infantry: Dictionary = roster["infantry"]
		infantry["troops"] = int(infantry.get("troops", 0)) + total_troops - roster_total
		roster["infantry"] = infantry
	elif roster_total > total_troops:
		var unit_ids: Array = roster.keys()
		var remaining: int = total_troops
		for index: int in range(unit_ids.size()):
			var unit_id: String = str(unit_ids[index])
			var unit: Dictionary = roster[unit_id]
			var adjusted: int = 0
			if index == unit_ids.size() - 1:
				adjusted = remaining
			elif roster_total > 0:
				adjusted = int(
					float(int(unit.get("troops", 0))) * float(total_troops) / float(roster_total)
				)
			unit["troops"] = maxi(0, adjusted)
			remaining = maxi(0, remaining - adjusted)
			roster[unit_id] = unit
	rosters[province_id] = roster
	state["unit_rosters"] = rosters
	return roster


func get_unit_roster(
	state: Dictionary, province_id: String, total_troops: int = -1
) -> Dictionary:
	if total_troops >= 0:
		reconcile_unit_roster(state, province_id, total_troops)
	var roster: Dictionary = state.get("unit_rosters", {}).get(province_id, {})
	return roster.duplicate(true)


func get_officer_affinities(
	state: Dictionary, officer_name: String, officer: Dictionary
) -> Dictionary:
	if HISTORICAL_AFFINITIES.has(officer_name):
		return HISTORICAL_AFFINITIES[officer_name].duplicate(true)
	var result: Dictionary = {
		"infantry": _affinity_from_score(
			int(officer.get("leadership", 50)) + int(officer.get("authority", 50))
		),
		"archer": _affinity_from_score(
			int(officer.get("intelligence", 50)) + int(officer.get("leadership", 50))
		),
		"cavalry": _affinity_from_score(
			int(officer.get("war", 50)) + int(officer.get("leadership", 50))
		),
	}
	var metadata: Dictionary = state.get("officer_metadata", {}).get(officer_name, {})
	if not bool(metadata.get("is_historical", false)):
		for category: String in result.keys():
			if str(result[category]) in ["S", "A"]:
				result[category] = "B"
	return result


func get_recruit_catalog(
	state: Dictionary, province_id: String, faction_name: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit_id_value: Variant in RECRUIT_UNIT_DEFS.keys():
		var unit_id: String = str(unit_id_value)
		var item: Dictionary = RECRUIT_UNIT_DEFS[unit_id].duplicate(true)
		item["id"] = unit_id
		item["special"] = false
		result.append(item)
	for special: Dictionary in get_unlocked_special_units(state, province_id, faction_name):
		var special_id: String = str(special.get("id", ""))
		var item: Dictionary = special.duplicate(true)
		item["category"] = str(SPECIAL_UNIT_CATEGORY.get(special_id, "infantry"))
		item["gold_per_1000"] = 250 + int(special.get("power", 70)) * 2
		item["food_per_1000"] = 320 + int(special.get("power", 70))
		item["role"] = "%s · 해금된 세력 특수병" % str(special.get("bonus", "정예병"))
		item["special"] = true
		result.append(item)
	return result


func get_recruit_quote(
	state: Dictionary,
	province_id: String,
	faction_name: String,
	unit_id: String,
	officer_name: String,
	officer: Dictionary,
	amount: int
) -> Dictionary:
	if amount < 500 or amount > 5000 or amount % 500 != 0:
		return {"ok": false, "reason": "모집 인원은 500명 단위로 500~5,000명입니다."}
	var definition: Dictionary = {}
	var special: bool = false
	if RECRUIT_UNIT_DEFS.has(unit_id):
		definition = RECRUIT_UNIT_DEFS[unit_id]
	elif SPECIAL_UNIT_DEFS.has(unit_id):
		var unlocked_ids: Array[String] = []
		for unlocked: Dictionary in get_unlocked_special_units(state, province_id, faction_name):
			unlocked_ids.append(str(unlocked.get("id", "")))
		if not unlocked_ids.has(unit_id):
			return {"ok": false, "reason": "아직 해금되지 않은 특수 병종입니다."}
		definition = SPECIAL_UNIT_DEFS[unit_id].duplicate(true)
		definition["category"] = str(SPECIAL_UNIT_CATEGORY.get(unit_id, "infantry"))
		definition["gold_per_1000"] = 250 + int(definition.get("power", 70)) * 2
		definition["food_per_1000"] = 320 + int(definition.get("power", 70))
		special = true
	else:
		return {"ok": false, "reason": "알 수 없는 병종입니다."}
	var buildings: Dictionary = state.get("province_buildings", {}).get(province_id, {})
	var research: Dictionary = state.get("faction_research", {}).get(faction_name, {})
	if not _requirements_met(buildings, definition.get("buildings", {})):
		var missing_buildings: PackedStringArray = []
		for requirement_value: Variant in definition.get("buildings", {}).keys():
			var requirement_id: String = str(requirement_value)
			var required_level: int = int(definition["buildings"][requirement_id])
			var current_level: int = int(buildings.get(requirement_id, 0))
			if current_level < required_level:
				missing_buildings.append(
					"%s %d/%d"
					% [BUILDING_DEFS[requirement_id]["name"], current_level, required_level]
				)
		return {"ok": false, "reason": "필요 시설: %s" % " · ".join(missing_buildings)}
	if not _requirements_met(research, definition.get("research", {})):
		var missing_research: PackedStringArray = []
		for research_requirement_value: Variant in definition.get("research", {}).keys():
			var research_requirement_id: String = str(research_requirement_value)
			var required_research_level: int = int(definition["research"][research_requirement_id])
			var current_research_level: int = int(research.get(research_requirement_id, 0))
			if current_research_level < required_research_level:
				missing_research.append(
					"%s %d/%d"
					% [RESEARCH_DEFS[research_requirement_id]["name"], current_research_level, required_research_level]
				)
		return {"ok": false, "reason": "필요 연구: %s" % " · ".join(missing_research)}
	var category: String = str(definition.get("category", "infantry"))
	var affinities: Dictionary = get_officer_affinities(state, officer_name, officer)
	var grade: String = str(affinities.get(category, "B"))
	var grade_bonus: int = int(AFFINITY_GRADE_BONUS.get(grade, 0))
	var training: int = clampi(
		38 + int(float(int(officer.get("leadership", 50))) / 3.0) + grade_bonus, 45, 95
	)
	var morale: int = clampi(
		38 + int(float(int(officer.get("authority", 50))) / 3.0) + int(float(grade_bonus) / 2.0), 45, 95
	)
	return {
		"ok": true,
		"unit_id": unit_id,
		"name": str(definition.get("name", unit_id)),
		"category": category,
		"special": special,
		"amount": amount,
		"gold_cost": int(ceil(float(int(definition.get("gold_per_1000", 150)) * amount) / 1000.0)),
		"food_cost": int(ceil(float(int(definition.get("food_per_1000", 200)) * amount) / 1000.0)),
		"affinity": grade,
		"training": training,
		"morale": morale,
		"power": int(definition.get("power", 50)),
	}


func recruit_unit(
	state: Dictionary, province_id: String, quote: Dictionary
) -> Dictionary:
	if not bool(quote.get("ok", false)):
		return quote
	if typeof(state.get("unit_rosters", null)) != TYPE_DICTIONARY:
		state["unit_rosters"] = {}
	var roster: Dictionary = state["unit_rosters"].get(province_id, _base_unit_roster(0))
	var unit_id: String = str(quote.get("unit_id", "infantry"))
	var existing: Dictionary = roster.get(unit_id, {
		"name": str(quote.get("name", unit_id)),
		"category": str(quote.get("category", "infantry")),
		"troops": 0, "training": 50, "morale": 50,
		"power": int(quote.get("power", 50)),
	})
	var old_troops: int = int(existing.get("troops", 0))
	var added: int = int(quote.get("amount", 0))
	var new_total: int = old_troops + added
	if new_total <= 0:
		return {"ok": false, "reason": "모집 인원이 올바르지 않습니다."}
	existing["troops"] = new_total
	existing["training"] = int(
		(float(int(existing.get("training", 50)) * old_troops) + float(int(quote.get("training", 50)) * added))
		/ float(new_total)
	)
	existing["morale"] = int(
		(float(int(existing.get("morale", 50)) * old_troops) + float(int(quote.get("morale", 50)) * added))
		/ float(new_total)
	)
	roster[unit_id] = existing
	state["unit_rosters"][province_id] = roster
	return quote


func get_best_fielded_unit(
	state: Dictionary, province_id: String, _faction_name: String
) -> Dictionary:
	var roster: Dictionary = state.get("unit_rosters", {}).get(province_id, {})
	var best: Dictionary = {"id": "infantry", "name": "보병", "power": 50, "category": "infantry", "bonus": "기본 병종"}
	for unit_id_value: Variant in roster.keys():
		var unit_id: String = str(unit_id_value)
		var entry: Dictionary = roster[unit_id]
		if int(entry.get("troops", 0)) <= 0:
			continue
		var power: int = int(entry.get("power", RECRUIT_UNIT_DEFS.get(unit_id, {}).get("power", 50)))
		if power <= int(best.get("power", 50)):
			continue
		best = entry.duplicate(true)
		best["id"] = unit_id
		best["power"] = power
		if SPECIAL_UNIT_DEFS.has(unit_id):
			best["bonus"] = str(SPECIAL_UNIT_DEFS[unit_id].get("bonus", "정예병 보너스"))
		else:
			best["bonus"] = str(RECRUIT_UNIT_DEFS.get(unit_id, {}).get("role", "기본 병종"))
	return best


func get_army_combat_profile(state: Dictionary, province_id: String) -> Dictionary:
	var roster: Dictionary = state.get("unit_rosters", {}).get(province_id, {})
	var total_troops: int = _roster_total(roster)
	if total_troops <= 0:
		return {"power": 50, "training": 50, "morale": 50, "troops": 0}
	var power_sum: float = 0.0
	var training_sum: float = 0.0
	var morale_sum: float = 0.0
	var best_unit_name: String = "보병"
	var best_unit_power: int = 50
	for unit_id_value: Variant in roster.keys():
		var unit_id: String = str(unit_id_value)
		var unit: Dictionary = roster[unit_id]
		var unit_troops: int = maxi(0, int(unit.get("troops", 0)))
		if unit_troops <= 0:
			continue
		var unit_power: int = int(
			unit.get("power", RECRUIT_UNIT_DEFS.get(unit_id, {}).get("power", 50))
		)
		if unit_power > best_unit_power:
			best_unit_power = unit_power
			best_unit_name = str(unit.get("name", unit_id))
		power_sum += float(unit_power * unit_troops)
		training_sum += float(int(unit.get("training", 50)) * unit_troops)
		morale_sum += float(int(unit.get("morale", 50)) * unit_troops)
	return {
		"power": int(round(power_sum / float(total_troops))),
		"training": int(round(training_sum / float(total_troops))),
		"morale": int(round(morale_sum / float(total_troops))),
		"troops": total_troops,
		"name": best_unit_name,
	}


func _roster_total(roster: Dictionary) -> int:
	var total: int = 0
	for unit_value: Variant in roster.values():
		if typeof(unit_value) == TYPE_DICTIONARY:
			total += maxi(0, int(unit_value.get("troops", 0)))
	return total


func _affinity_from_score(score: int) -> String:
	if score >= 185:
		return "S"
	if score >= 165:
		return "A"
	if score >= 135:
		return "B"
	return "C"


func get_building_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building_id_value: Variant in BUILDING_DEFS.keys():
		var building_id: String = str(building_id_value)
		var item: Dictionary = BUILDING_DEFS[building_id].duplicate(true)
		item["id"] = building_id
		result.append(item)
	return result


func get_research_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for research_id_value: Variant in RESEARCH_DEFS.keys():
		var research_id: String = str(research_id_value)
		var item: Dictionary = RESEARCH_DEFS[research_id].duplicate(true)
		item["id"] = research_id
		result.append(item)
	return result


func get_special_unit_progress(
	state: Dictionary, province_id: String, faction_name: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var buildings: Dictionary = state.get("province_buildings", {}).get(province_id, {})
	var research: Dictionary = state.get("faction_research", {}).get(faction_name, {})
	for unit_id_value: Variant in SPECIAL_UNIT_DEFS.keys():
		var unit_id: String = str(unit_id_value)
		var definition: Dictionary = SPECIAL_UNIT_DEFS[unit_id]
		if not _unit_matches_faction(definition, faction_name):
			continue
		var missing: Array[String] = []
		for building_id_value: Variant in definition.get("buildings", {}).keys():
			var building_id: String = str(building_id_value)
			var required_level: int = int(definition["buildings"][building_id])
			var current_level: int = int(buildings.get(building_id, 0))
			if current_level < required_level:
				missing.append(
					"%s %d/%d"
					% [BUILDING_DEFS[building_id]["name"], current_level, required_level]
				)
		for research_id_value: Variant in definition.get("research", {}).keys():
			var research_id: String = str(research_id_value)
			var required_level: int = int(definition["research"][research_id])
			var current_level: int = int(research.get(research_id, 0))
			if current_level < required_level:
				missing.append(
					"%s %d/%d"
					% [RESEARCH_DEFS[research_id]["name"], current_level, required_level]
				)
		var item: Dictionary = definition.duplicate(true)
		item["id"] = unit_id
		item["unlocked"] = missing.is_empty()
		item["missing"] = missing
		result.append(item)
	result.sort_custom(_sort_units_by_power)
	return result


func process_season(
	state: Dictionary,
	current_year: int,
	season_index: int,
	provinces: Dictionary,
	officers_by_province: Dictionary,
	scenario: Dictionary
) -> Dictionary:
	var messages: Array[String] = []
	messages.append_array(_process_construction(state))
	messages.append_array(_process_research(state))
	var trade_result: Dictionary = _process_trade(state, provinces)
	messages.append_array(trade_result.get("messages", []))

	# 봄(0)에 연 단위 인재 보충과 가문 성장을 처리합니다.
	if season_index == 0:
		messages.append_array(
			auto_fill_officer_shortages(
				state, current_year, provinces, officers_by_province, scenario
			)
		)
		messages.append_array(
			_process_dynasty_year(
				state, current_year, provinces, officers_by_province, scenario
			)
		)
	return {
		"messages": messages,
		"faction_gold_delta": trade_result.get("faction_gold_delta", {}),
	}


func get_building_quote(state: Dictionary, province_id: String, building_id: String) -> Dictionary:
	if not BUILDING_DEFS.has(building_id):
		return {"ok": false, "reason": "알 수 없는 건물입니다."}
	if state.get("construction_queues", {}).has(province_id):
		return {"ok": false, "reason": "이 영지는 이미 건설 중입니다."}
	var levels: Dictionary = state.get("province_buildings", {}).get(province_id, {})
	var definition: Dictionary = BUILDING_DEFS[building_id]
	var current_level: int = int(levels.get(building_id, 0))
	var next_level: int = current_level + 1
	if next_level > int(definition.get("max_level", 3)):
		return {"ok": false, "reason": "이미 최고 단계입니다."}
	return {
		"ok": true,
		"building_id": building_id,
		"name": str(definition["name"]),
		"next_level": next_level,
		"gold_cost": int(definition["base_gold"]) * next_level,
		"turns": int(definition["base_turns"]) + int((next_level - 1) / 2),
	}


func start_building(
	state: Dictionary,
	province_id: String,
	building_id: String,
	assigned_officer: String = "",
	turns_override: int = -1
) -> Dictionary:
	var quote: Dictionary = get_building_quote(state, province_id, building_id)
	if not bool(quote.get("ok", false)):
		return quote
	var remaining_turns: int = int(quote["turns"])
	if turns_override > 0:
		remaining_turns = turns_override
	state["construction_queues"][province_id] = {
		"building_id": building_id,
		"target_level": int(quote["next_level"]),
		"remaining_turns": remaining_turns,
		"assigned_officer": assigned_officer,
	}
	quote["turns"] = remaining_turns
	quote["assigned_officer"] = assigned_officer
	return quote


func get_research_quote(state: Dictionary, faction_name: String, research_id: String) -> Dictionary:
	if not RESEARCH_DEFS.has(research_id):
		return {"ok": false, "reason": "알 수 없는 연구입니다."}
	if state.get("research_queues", {}).has(faction_name):
		return {"ok": false, "reason": "이 세력은 이미 연구 중입니다."}
	var levels: Dictionary = state.get("faction_research", {}).get(faction_name, _empty_research_levels())
	var definition: Dictionary = RESEARCH_DEFS[research_id]
	var next_level: int = int(levels.get(research_id, 0)) + 1
	if next_level > int(definition.get("max_level", 3)):
		return {"ok": false, "reason": "이미 최고 단계입니다."}
	return {
		"ok": true,
		"research_id": research_id,
		"name": str(definition["name"]),
		"next_level": next_level,
		"gold_cost": int(definition["base_gold"]) * next_level,
		"turns": int(definition["base_turns"]) + next_level - 1,
	}


func start_research(
	state: Dictionary,
	faction_name: String,
	research_id: String,
	assigned_officer: String = "",
	turns_override: int = -1
) -> Dictionary:
	var quote: Dictionary = get_research_quote(state, faction_name, research_id)
	if not bool(quote.get("ok", false)):
		return quote
	var remaining_turns: int = int(quote["turns"])
	if turns_override > 0:
		remaining_turns = turns_override
	state["research_queues"][faction_name] = {
		"research_id": research_id,
		"target_level": int(quote["next_level"]),
		"remaining_turns": remaining_turns,
		"assigned_officer": assigned_officer,
	}
	quote["turns"] = remaining_turns
	quote["assigned_officer"] = assigned_officer
	return quote


func get_unlocked_special_units(
	state: Dictionary, province_id: String, faction_name: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var buildings: Dictionary = state.get("province_buildings", {}).get(province_id, {})
	var research: Dictionary = state.get("faction_research", {}).get(faction_name, {})
	for unit_id_value: Variant in SPECIAL_UNIT_DEFS.keys():
		var unit_id: String = str(unit_id_value)
		var unit: Dictionary = SPECIAL_UNIT_DEFS[unit_id]
		if not _unit_matches_faction(unit, faction_name):
			continue
		if not _requirements_met(research, unit.get("research", {})):
			continue
		if not _requirements_met(buildings, unit.get("buildings", {})):
			continue
		var unlocked: Dictionary = unit.duplicate(true)
		unlocked["id"] = unit_id
		result.append(unlocked)
	result.sort_custom(_sort_units_by_power)
	return result


func get_best_available_unit(state: Dictionary, province_id: String, faction_name: String) -> Dictionary:
	var unlocked: Array[Dictionary] = get_unlocked_special_units(state, province_id, faction_name)
	if unlocked.is_empty():
		return {"id": "local_levy", "name": "향토군", "power": 50, "bonus": "특수 보너스 없음"}
	return unlocked[0]


func perform_diplomatic_action(
	state: Dictionary,
	actor_faction: String,
	target_faction: String,
	action_id: String,
	actor: Dictionary,
	current_year: int
) -> Dictionary:
	if actor_faction == target_faction:
		return {"ok": false, "reason": "같은 세력에는 외교할 수 없습니다."}
	var relation: Dictionary = _ensure_relation(state, actor_faction, target_faction)
	var relation_value: int = int(relation.get("value", 0))
	var gold_cost: int = 0
	var required_relation: int = -100
	var relation_change: int = 0
	var new_status: String = str(relation.get("status", "중립"))
	var treaty: String = ""
	match action_id:
		"gift":
			gold_cost = 200
			relation_change = 12
		"trade_pact":
			required_relation = 10
			relation_change = 5
			treaty = "통상 조약"
		"nonaggression":
			required_relation = 20
			relation_change = 8
			treaty = "불가침"
			new_status = "우호"
		"alliance":
			required_relation = 50
			relation_change = 10
			treaty = "동맹"
			new_status = "동맹"
		"declare_war":
			relation_change = -60
			new_status = "전쟁"
			relation["treaties"] = []
		_:
			return {"ok": false, "reason": "지원하지 않는 외교 행동입니다."}
	if relation_value < required_relation:
		return {"ok": false, "reason": "관계도가 부족합니다.", "gold_cost": gold_cost}

	var politics: int = int(actor.get("politics", 50))
	var intelligence: int = int(actor.get("intelligence", 50))
	var authority: int = int(actor.get("authority", 50))
	var chance: int = clampi(
		45 + int((politics + intelligence + authority) / 12) + int(relation_value / 5),
		15,
		95
	)
	if action_id == "gift" or action_id == "declare_war":
		chance = 100
	var roll: int = absi(hash("%s:%s:%s:%d" % [actor_faction, target_faction, action_id, current_year])) % 100
	if roll >= chance:
		relation["value"] = clampi(relation_value - 3, -100, 100)
		return {"ok": false, "reason": "교섭이 결렬되었습니다.", "gold_cost": gold_cost, "chance": chance}

	relation["value"] = clampi(relation_value + relation_change, -100, 100)
	relation["status"] = new_status
	var treaties: Array = relation.get("treaties", [])
	if treaty != "" and not treaties.has(treaty):
		treaties.append(treaty)
	relation["treaties"] = treaties
	return {
		"ok": true,
		"gold_cost": gold_cost,
		"chance": chance,
		"relation": relation.duplicate(true),
		"message": "%s과의 %s 교섭이 성사되었습니다." % [target_faction, action_id],
	}


func open_trade_route(
	state: Dictionary,
	faction_a: String,
	faction_b: String,
	origin_id: String,
	destination_id: String,
	goods: String
) -> Dictionary:
	var relation: Dictionary = _ensure_relation(state, faction_a, faction_b)
	if str(relation.get("status", "중립")) == "전쟁":
		return {"ok": false, "reason": "전쟁 중에는 교역할 수 없습니다."}
	if int(relation.get("value", 0)) < 10 and not relation.get("treaties", []).has("통상 조약"):
		return {"ok": false, "reason": "관계도 10 또는 통상 조약이 필요합니다."}
	var buildings: Dictionary = state.get("province_buildings", {})
	if int(buildings.get(origin_id, {}).get("market", 0)) < 1:
		return {"ok": false, "reason": "출발 영지에 시장이 필요합니다."}
	if int(buildings.get(destination_id, {}).get("market", 0)) < 1:
		return {"ok": false, "reason": "도착 영지에 시장이 필요합니다."}
	for route_value: Variant in state.get("trade_routes", []):
		var route: Dictionary = route_value
		if str(route.get("origin_id", "")) == origin_id and str(route.get("destination_id", "")) == destination_id:
			return {"ok": false, "reason": "이미 개설된 교역로입니다."}
	var route_id: int = int(state.get("next_trade_route_id", 1))
	state["next_trade_route_id"] = route_id + 1
	state["trade_routes"].append({
		"id": route_id, "faction_a": faction_a, "faction_b": faction_b,
		"origin_id": origin_id, "destination_id": destination_id,
		"goods": goods, "active": true, "risk": 10,
	})
	return {"ok": true, "route_id": route_id, "message": "%s 교역로를 개설했습니다." % goods}


func arrange_marriage(
	state: Dictionary,
	person_a: String,
	person_b: String,
	current_year: int,
	gender_a: String = "unknown",
	gender_b: String = "unknown"
) -> Dictionary:
	var people: Dictionary = state.get("dynasty", {}).get("people", {})
	if not people.has(person_a) or not people.has(person_b):
		return {"ok": false, "reason": "가문 인물 정보가 없습니다."}
	var first: Dictionary = people[person_a]
	var second: Dictionary = people[person_b]
	if str(first.get("spouse", "")) != "" or str(second.get("spouse", "")) != "":
		return {"ok": false, "reason": "이미 혼인한 인물입니다."}
	if _person_age(first, current_year) < ADULT_AGE or _person_age(second, current_year) < ADULT_AGE:
		return {"ok": false, "reason": "혼인은 만 16세부터 가능합니다."}
	if gender_a != "unknown":
		first["gender"] = gender_a
	if gender_b != "unknown":
		second["gender"] = gender_b
	first["spouse"] = person_b
	second["spouse"] = person_a
	people[person_a] = first
	people[person_b] = second
	state["dynasty"]["marriages"].append({
		"person_a": person_a, "person_b": person_b, "year": current_year,
		"last_birth_year": -999,
	})
	var faction_a: String = str(first.get("faction", ""))
	var faction_b: String = str(second.get("faction", ""))
	if faction_a != "" and faction_b != "" and faction_a != faction_b:
		var relation: Dictionary = _ensure_relation(state, faction_a, faction_b)
		relation["value"] = clampi(int(relation.get("value", 0)) + 15, -100, 100)
		var treaties: Array = relation.get("treaties", [])
		if not treaties.has("혼인 동맹"):
			treaties.append("혼인 동맹")
		relation["treaties"] = treaties
	return {"ok": true, "message": "%s과 %s이 혼인했습니다." % [person_a, person_b]}


func set_child_education(
	state: Dictionary, child_id: String, education_id: String, mentor_name: String = ""
) -> Dictionary:
	if not EDUCATION_PATHS.has(education_id):
		return {"ok": false, "reason": "알 수 없는 교육 과정입니다."}
	var children: Dictionary = state.get("dynasty", {}).get("children", {})
	if not children.has(child_id):
		return {"ok": false, "reason": "자녀를 찾을 수 없습니다."}
	var child: Dictionary = children[child_id]
	if bool(child.get("adult", false)):
		return {"ok": false, "reason": "이미 성인이 된 인물입니다."}
	child["education"] = education_id
	child["mentor"] = mentor_name
	children[child_id] = child
	return {"ok": true, "message": "%s의 교육을 %s으로 정했습니다." % [child["name"], EDUCATION_PATHS[education_id]["name"]]}


func auto_fill_officer_shortages(
	state: Dictionary,
	current_year: int,
	provinces: Dictionary,
	officers_by_province: Dictionary,
	scenario: Dictionary
) -> Array[String]:
	var messages: Array[String] = []
	var faction_provinces: Dictionary = _group_provinces_by_faction(provinces)
	var counts_by_year: Dictionary = state["auto_generation"].get("counts_by_year", {})
	var year_key: String = str(current_year)
	if typeof(counts_by_year.get(year_key, null)) != TYPE_DICTIONARY:
		counts_by_year[year_key] = {}
	var year_counts: Dictionary = counts_by_year[year_key]
	var capitals: Dictionary = _get_capitals_by_faction(provinces, scenario)

	for faction_name_value: Variant in faction_provinces.keys():
		var faction_name: String = str(faction_name_value)
		var province_ids: Array = faction_provinces[faction_name]
		var active_count: int = 0
		for province_id_value: Variant in province_ids:
			active_count += officers_by_province.get(str(province_id_value), []).size()
		var required_count: int = maxi(2, province_ids.size() + 1)
		var shortage: int = required_count - active_count
		var already_created: int = int(year_counts.get(faction_name, 0))
		var allowed: int = mini(shortage, MAX_AUTO_OFFICERS_PER_FACTION_YEAR - already_created)
		for generation_index: int in range(maxi(0, allowed)):
			var destination_id: String = _pick_generation_province(
				province_ids, officers_by_province, str(capitals.get(faction_name, ""))
			)
			var officer: Dictionary = _generate_ordinary_officer(
				state, faction_name, current_year, already_created + generation_index
			)
			state["emergent_officers"][officer["name"]] = officer
			state["officer_metadata"][officer["name"]] = {
				"origin": "generated", "is_historical": false,
				"featured_eligible": false, "faction_screen_eligible": false,
				"faction": faction_name, "quality_tier": "ordinary",
			}
			state["dynasty"]["people"][officer["name"]] = _person_from_officer(
				officer["name"], officer, faction_name, "generated"
			)
			var destination_officers: Array = officers_by_province.get(destination_id, []).duplicate()
			destination_officers.append(officer["name"])
			officers_by_province[destination_id] = destination_officers
			messages.append("%s에서 보조 인재 %s을 등용했습니다." % [provinces[destination_id]["name"], officer["name"]])
		year_counts[faction_name] = already_created + maxi(0, allowed)
	counts_by_year[year_key] = year_counts
	state["auto_generation"]["counts_by_year"] = counts_by_year
	return messages


func is_faction_screen_eligible(state: Dictionary, officer_name: String) -> bool:
	var metadata: Dictionary = state.get("officer_metadata", {}).get(officer_name, {})
	return bool(metadata.get("is_historical", false)) and bool(metadata.get("faction_screen_eligible", false))


func get_signature_units_for_faction_id(faction_id: String) -> Array[String]:
	var result: Array[String] = []
	for unit_name_value: Variant in SIGNATURE_UNITS_BY_FACTION_ID.get(faction_id, ["정예 향병"]):
		result.append(str(unit_name_value))
	return result


func _process_construction(state: Dictionary) -> Array[String]:
	var messages: Array[String] = []
	var queues: Dictionary = state.get("construction_queues", {})
	for province_id_value: Variant in queues.keys().duplicate():
		var province_id: String = str(province_id_value)
		var queue: Dictionary = queues[province_id]
		queue["remaining_turns"] = int(queue.get("remaining_turns", 1)) - 1
		if int(queue["remaining_turns"]) > 0:
			queues[province_id] = queue
			continue
		var building_id: String = str(queue["building_id"])
		var levels: Dictionary = state["province_buildings"].get(province_id, {})
		levels[building_id] = int(queue["target_level"])
		state["province_buildings"][province_id] = levels
		queues.erase(province_id)
		messages.append("%s %d단계 건설이 완료되었습니다." % [BUILDING_DEFS[building_id]["name"], levels[building_id]])
	return messages


func _process_research(state: Dictionary) -> Array[String]:
	var messages: Array[String] = []
	var queues: Dictionary = state.get("research_queues", {})
	for faction_name_value: Variant in queues.keys().duplicate():
		var faction_name: String = str(faction_name_value)
		var queue: Dictionary = queues[faction_name]
		queue["remaining_turns"] = int(queue.get("remaining_turns", 1)) - 1
		if int(queue["remaining_turns"]) > 0:
			queues[faction_name] = queue
			continue
		var research_id: String = str(queue["research_id"])
		var levels: Dictionary = state["faction_research"].get(faction_name, _empty_research_levels())
		levels[research_id] = int(queue["target_level"])
		state["faction_research"][faction_name] = levels
		queues.erase(faction_name)
		messages.append("%s의 %s %d단계 연구가 완료되었습니다." % [faction_name, RESEARCH_DEFS[research_id]["name"], levels[research_id]])
	return messages


func _process_trade(state: Dictionary, provinces: Dictionary) -> Dictionary:
	var messages: Array[String] = []
	var deltas: Dictionary = {}
	for route_value: Variant in state.get("trade_routes", []):
		if typeof(route_value) != TYPE_DICTIONARY:
			continue
		var route: Dictionary = route_value
		if not bool(route.get("active", true)):
			continue
		var origin_id: String = str(route.get("origin_id", ""))
		var destination_id: String = str(route.get("destination_id", ""))
		if not provinces.has(origin_id) or not provinces.has(destination_id):
			continue
		var relation: Dictionary = _ensure_relation(state, str(route["faction_a"]), str(route["faction_b"]))
		if str(relation.get("status", "중립")) == "전쟁":
			continue
		var buildings: Dictionary = state.get("province_buildings", {})
		var market_level: int = int(buildings.get(origin_id, {}).get("market", 0)) + int(buildings.get(destination_id, {}).get("market", 0))
		var commerce_value: int = int(provinces[origin_id].get("commerce", 50)) + int(provinces[destination_id].get("commerce", 50))
		var income: int = maxi(
			20,
			int(commerce_value / 5) + market_level * 15 - int(route.get("risk", 10))
		)
		for faction_key: String in [str(route["faction_a"]), str(route["faction_b"])]:
			deltas[faction_key] = int(deltas.get(faction_key, 0)) + income
		relation["value"] = clampi(int(relation.get("value", 0)) + 1, -100, 100)
		messages.append("%s 교역로에서 양측이 금 %d을 얻었습니다." % [route.get("goods", "물산"), income])
	return {"messages": messages, "faction_gold_delta": deltas}


func _process_dynasty_year(
	state: Dictionary,
	current_year: int,
	provinces: Dictionary,
	officers_by_province: Dictionary,
	scenario: Dictionary
) -> Array[String]:
	var messages: Array[String] = []
	var dynasty: Dictionary = state["dynasty"]
	var children: Dictionary = dynasty.get("children", {})
	var capital_by_faction: Dictionary = _get_capitals_by_faction(provinces, scenario)

	for child_id_value: Variant in children.keys():
		var child_id: String = str(child_id_value)
		var child: Dictionary = children[child_id]
		if bool(child.get("adult", false)):
			continue
		var age: int = current_year - int(child.get("birth_year", current_year))
		child["age"] = age
		if age >= 6 and age < ADULT_AGE:
			_apply_child_growth(state, child)
		if age >= ADULT_AGE:
			child["adult"] = true
			var adult: Dictionary = _adult_officer_from_child(child, current_year)
			state["emergent_officers"][adult["name"]] = adult
			state["officer_metadata"][adult["name"]] = {
				"origin": "dynastic", "is_historical": false,
				"featured_eligible": false, "faction_screen_eligible": false,
				"faction": child.get("faction", ""), "quality_tier": "heir",
			}
			var destination_id: String = str(capital_by_faction.get(child.get("faction", ""), ""))
			if destination_id == "":
				destination_id = _first_faction_province(provinces, str(child.get("faction", "")))
			if destination_id != "":
				var destination_officers: Array = officers_by_province.get(destination_id, []).duplicate()
				destination_officers.append(adult["name"])
				officers_by_province[destination_id] = destination_officers
			if dynasty.get("people", {}).has(adult["name"]):
				var adult_person: Dictionary = dynasty["people"][adult["name"]]
				adult_person["stats"] = child.get("stats", {}).duplicate(true)
				adult_person["origin"] = "dynastic"
				dynasty["people"][adult["name"]] = adult_person
			messages.append("%s이 만 16세가 되어 성인 장수로 출사했습니다." % adult["name"])
		children[child_id] = child

	var marriages: Array = dynasty.get("marriages", [])
	for marriage_index: int in range(marriages.size()):
		var marriage: Dictionary = marriages[marriage_index]
		if current_year - int(marriage.get("last_birth_year", -999)) < 2:
			continue
		var person_a: Dictionary = dynasty.get("people", {}).get(str(marriage.get("person_a", "")), {})
		var person_b: Dictionary = dynasty.get("people", {}).get(str(marriage.get("person_b", "")), {})
		if person_a.is_empty() or person_b.is_empty():
			continue
		if not _couple_can_have_child(person_a, person_b, current_year):
			continue
		var existing_children: int = _count_couple_children(children, str(marriage["person_a"]), str(marriage["person_b"]))
		if existing_children >= 4:
			continue
		var birth_roll: int = absi(hash("birth:%s:%s:%d" % [marriage["person_a"], marriage["person_b"], current_year])) % 100
		if birth_roll >= 22:
			continue
		var newborn: Dictionary = _create_child(state, person_a, person_b, current_year)
		children[newborn["id"]] = newborn
		var people: Dictionary = dynasty.get("people", {})
		people[newborn["name"]] = {
			"name": newborn["name"], "birth_year": current_year, "death_year": 0,
			"gender": newborn["gender"], "faction": newborn["faction"],
			"origin": "dynastic", "spouse": "",
			"parents": [newborn["parent_a"], newborn["parent_b"]],
			"children": [], "stats": newborn["stats"].duplicate(true),
		}
		for parent_name: String in [str(newborn["parent_a"]), str(newborn["parent_b"])]:
			if not people.has(parent_name):
				continue
			var parent: Dictionary = people[parent_name]
			var parent_children: Array = parent.get("children", [])
			if not parent_children.has(newborn["name"]):
				parent_children.append(newborn["name"])
			parent["children"] = parent_children
			people[parent_name] = parent
		dynasty["people"] = people
		marriage["last_birth_year"] = current_year
		marriages[marriage_index] = marriage
		messages.append("%s 가문에 자녀 %s이 태어났습니다." % [marriage["person_a"], newborn["name"]])
	dynasty["children"] = children
	dynasty["marriages"] = marriages
	state["dynasty"] = dynasty
	return messages


func _apply_child_growth(state: Dictionary, child: Dictionary) -> void:
	var education_id: String = str(child.get("education", "balanced"))
	var education: Dictionary = EDUCATION_PATHS.get(education_id, EDUCATION_PATHS["balanced"])
	var growth: Dictionary = education.get("growth", {})
	var mentor_bonus: int = 0
	var mentor_name: String = str(child.get("mentor", ""))
	var mentor: Dictionary = state.get("emergent_officers", {}).get(mentor_name, {})
	if mentor.is_empty() and state.get("dynasty", {}).get("people", {}).has(mentor_name):
		mentor = state["dynasty"]["people"][mentor_name].get("stats", {})
	if not mentor.is_empty():
		mentor_bonus = 1 if _highest_stat(mentor) >= 70 else 0
	var stats: Dictionary = child.get("stats", {})
	var potential: Dictionary = child.get("potential", {})
	for stat_key_value: Variant in growth.keys():
		var stat_key: String = str(stat_key_value)
		var increase: int = int(growth[stat_key]) + mentor_bonus
		stats[stat_key] = mini(int(potential.get(stat_key, DYNASTIC_STAT_CAP)), int(stats.get(stat_key, 30)) + increase)
	child["stats"] = stats
	child["xp"] = int(child.get("xp", 0)) + 10


func _create_child(state: Dictionary, first: Dictionary, second: Dictionary, current_year: int) -> Dictionary:
	var dynasty: Dictionary = state["dynasty"]
	var child_number: int = int(dynasty.get("next_child_id", 1))
	dynasty["next_child_id"] = child_number + 1
	state["dynasty"] = dynasty
	var faction_name: String = str(first.get("faction", second.get("faction", "")))
	var child_id: String = "child_%d" % child_number
	var name: String = _generate_unique_name(state, faction_name, current_year, child_number + 1000)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = absi(hash("child:%s:%s:%d" % [first.get("name", ""), second.get("name", ""), current_year]))
	var base_stats: Dictionary = {}
	var potential: Dictionary = {}
	for stat_key: String in STAT_KEYS:
		var parent_average: int = int(
			(int(first.get("stats", {}).get(stat_key, 55)) + int(second.get("stats", {}).get(stat_key, 55))) / 2
		)
		base_stats[stat_key] = clampi(24 + rng.randi_range(0, 8), 20, 40)
		potential[stat_key] = clampi(parent_average + rng.randi_range(-6, 8), 55, DYNASTIC_STAT_CAP)
	return {
		"id": child_id, "name": name, "birth_year": current_year, "age": 0,
		"gender": "male" if rng.randi() % 2 == 0 else "female",
		"parent_a": str(first.get("name", "")), "parent_b": str(second.get("name", "")),
		"faction": faction_name, "stats": base_stats, "potential": potential,
		"education": "balanced", "mentor": "", "xp": 0, "adult": false,
		"origin": "dynastic", "featured_eligible": false,
	}


func _adult_officer_from_child(child: Dictionary, current_year: int) -> Dictionary:
	var stats: Dictionary = child.get("stats", {})
	var education_id: String = str(child.get("education", "balanced"))
	var skill_name: String = str(EDUCATION_PATHS.get(education_id, EDUCATION_PATHS["balanced"])["name"])
	return {
		"name": str(child["name"]), "birth_year": int(child["birth_year"]), "death_year": current_year + 45,
		"leadership": clampi(int(stats.get("leadership", 40)), 30, DYNASTIC_STAT_CAP),
		"war": clampi(int(stats.get("war", 40)), 30, DYNASTIC_STAT_CAP),
		"intelligence": clampi(int(stats.get("intelligence", 40)), 30, DYNASTIC_STAT_CAP),
		"politics": clampi(int(stats.get("politics", 40)), 30, DYNASTIC_STAT_CAP),
		"authority": clampi(int(stats.get("authority", 40)), 30, DYNASTIC_STAT_CAP),
		"skills": [skill_name], "origin": "dynastic", "is_historical": false,
		"featured_eligible": false, "faction_screen_eligible": false,
		"portrait_profile": {"age_group": "young", "role": education_id, "gender": child.get("gender", "unknown")},
	}


func _generate_ordinary_officer(state: Dictionary, faction_name: String, current_year: int, generation_index: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = absi(hash("generated:%s:%d:%d" % [faction_name, current_year, generation_index]))
	var roles: Array[String] = ["군관", "문관", "지방 호족"]
	var role: String = roles[rng.randi_range(0, roles.size() - 1)]
	var stats: Dictionary = {
		"leadership": rng.randi_range(44, 64), "war": rng.randi_range(42, 64),
		"intelligence": rng.randi_range(42, 64), "politics": rng.randi_range(42, 64),
		"authority": rng.randi_range(40, 62),
	}
	match role:
		"군관":
			stats["leadership"] = rng.randi_range(58, GENERATED_STAT_CAP)
			stats["war"] = rng.randi_range(56, GENERATED_STAT_CAP)
		"문관":
			stats["intelligence"] = rng.randi_range(56, GENERATED_STAT_CAP)
			stats["politics"] = rng.randi_range(58, GENERATED_STAT_CAP)
		"지방 호족":
			stats["authority"] = rng.randi_range(55, GENERATED_STAT_CAP)
			stats["politics"] = rng.randi_range(52, 68)
	var skills: Array[String] = []
	if rng.randi_range(0, 99) < 45:
		skills.append(COMMON_SKILLS[rng.randi_range(0, COMMON_SKILLS.size() - 1)])
	var officer_age: int = rng.randi_range(20, 39)
	var officer_name: String = _generate_unique_name(state, faction_name, current_year, generation_index)
	return {
		"name": officer_name, "birth_year": current_year - officer_age, "death_year": current_year + rng.randi_range(20, 42),
		"leadership": mini(GENERATED_STAT_CAP, int(stats["leadership"])),
		"war": mini(GENERATED_STAT_CAP, int(stats["war"])),
		"intelligence": mini(GENERATED_STAT_CAP, int(stats["intelligence"])),
		"politics": mini(GENERATED_STAT_CAP, int(stats["politics"])),
		"authority": mini(GENERATED_STAT_CAP, int(stats["authority"])),
		"skills": skills, "role": role, "origin": "generated", "is_historical": false,
		"quality_tier": "ordinary", "featured_eligible": false, "faction_screen_eligible": false,
		"portrait_profile": {"age_group": "adult", "role": role, "gender": "male"},
	}


func _generate_unique_name(state: Dictionary, faction_name: String, current_year: int, salt: int) -> String:
	var pool: Dictionary = NAME_POOLS.get(faction_name, NAME_POOLS["default"])
	var surnames: Array = pool["surnames"]
	var given_names: Array = pool["given"]
	var used: Dictionary = state.get("officer_metadata", {})
	for attempt: int in range(30):
		var seed_value: int = absi(hash("name:%s:%d:%d:%d" % [faction_name, current_year, salt, attempt]))
		var surname: String = str(surnames[seed_value % surnames.size()])
		var given_index: int = int(seed_value / maxi(1, surnames.size())) % given_names.size()
		var given_name: String = str(given_names[given_index])
		var candidate: String = surname + given_name
		if not used.has(candidate) and not state.get("emergent_officers", {}).has(candidate):
			return candidate
	return "%s 인재%d" % [faction_name, salt + 1]


func _person_from_officer(name: String, officer: Dictionary, faction_name: String, origin: String) -> Dictionary:
	var stats: Dictionary = {}
	for stat_key: String in STAT_KEYS:
		stats[stat_key] = int(officer.get(stat_key, 50))
	return {
		"name": name, "birth_year": int(officer.get("birth_year", 0)),
		"death_year": int(officer.get("death_year", 0)), "gender": str(officer.get("gender", "unknown")),
		"faction": faction_name, "origin": origin, "spouse": "", "parents": [], "children": [],
		"stats": stats,
	}


func _collect_faction_names(provinces: Dictionary, scenario: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for province_value: Variant in provinces.values():
		var province: Dictionary = province_value
		var faction_name: String = str(province.get("faction", ""))
		if faction_name != "" and not names.has(faction_name):
			names.append(faction_name)
	for faction_value: Variant in scenario.get("factions", []):
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction_name: String = str(faction_value.get("name", ""))
		if faction_name != "" and not names.has(faction_name):
			names.append(faction_name)
	names.sort()
	return names


func _get_capitals_by_faction(provinces: Dictionary, scenario: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for faction_value: Variant in scenario.get("factions", []):
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction: Dictionary = faction_value
		var faction_name: String = str(faction.get("name", ""))
		var start_id: String = str(faction.get("start_province", ""))
		if faction_name != "" and provinces.has(start_id):
			result[faction_name] = start_id
	return result


func _map_officer_factions(provinces: Dictionary, officers_by_province: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for province_id_value: Variant in officers_by_province.keys():
		var province_id: String = str(province_id_value)
		if not provinces.has(province_id):
			continue
		var faction_name: String = str(provinces[province_id].get("faction", ""))
		for officer_name_value: Variant in officers_by_province[province_id]:
			result[str(officer_name_value)] = faction_name
	return result


func _group_provinces_by_faction(provinces: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for province_id_value: Variant in provinces.keys():
		var province_id: String = str(province_id_value)
		var faction_name: String = str(provinces[province_id].get("faction", ""))
		if faction_name == "":
			continue
		if not result.has(faction_name):
			result[faction_name] = []
		result[faction_name].append(province_id)
	return result


func _pick_generation_province(province_ids: Array, officers_by_province: Dictionary, capital_id: String) -> String:
	var best_id: String = capital_id if province_ids.has(capital_id) else str(province_ids[0])
	var fewest: int = officers_by_province.get(best_id, []).size()
	for province_id_value: Variant in province_ids:
		var province_id: String = str(province_id_value)
		var count: int = officers_by_province.get(province_id, []).size()
		if count < fewest:
			best_id = province_id
			fewest = count
	return best_id


func _empty_research_levels() -> Dictionary:
	var result: Dictionary = {}
	for research_id_value: Variant in RESEARCH_DEFS.keys():
		result[str(research_id_value)] = 0
	return result


func _requirements_met(actual: Dictionary, required: Dictionary) -> bool:
	for key_value: Variant in required.keys():
		var key: String = str(key_value)
		if int(actual.get(key, 0)) < int(required[key]):
			return false
	return true


func _unit_matches_faction(unit: Dictionary, faction_name: String) -> bool:
	if unit.has("faction"):
		return str(unit["faction"]) == faction_name
	if str(unit.get("faction_group", "")) == "steppe":
		return not ["신라", "백제", "백제부흥군", "고구려", "고구려부흥군", "당", "왜(야마토 조정)"].has(faction_name)
	return false


func _relation_key(first: String, second: String) -> String:
	var names: Array[String] = [first, second]
	names.sort()
	return "%s|%s" % [names[0], names[1]]


func _ensure_relation(state: Dictionary, first: String, second: String) -> Dictionary:
	var key: String = _relation_key(first, second)
	if not state["relations"].has(key):
		state["relations"][key] = {"value": 0, "status": "중립", "treaties": []}
	return state["relations"][key]


func _apply_historical_start_relations(state: Dictionary, current_year: int) -> void:
	if current_year < 660:
		return
	_set_start_relation(state, "신라", "당", 70, "동맹", ["동맹", "통상 조약"])
	_set_start_relation(state, "백제", "왜(야마토 조정)", 60, "동맹", ["동맹", "통상 조약"])
	_set_start_relation(state, "신라", "백제", -85, "전쟁", [])
	_set_start_relation(state, "신라", "고구려", -65, "전쟁", [])
	_set_start_relation(state, "고구려", "당", -80, "전쟁", [])
	_set_start_relation(state, "백제", "당", -80, "전쟁", [])


func _set_start_relation(
	state: Dictionary,
	first: String,
	second: String,
	value: int,
	status: String,
	treaties: Array
) -> void:
	var key: String = _relation_key(first, second)
	if not state.get("relations", {}).has(key):
		return
	state["relations"][key] = {
		"value": clampi(value, -100, 100),
		"status": status,
		"treaties": treaties.duplicate(),
	}


func _person_age(person: Dictionary, current_year: int) -> int:
	var birth_year: int = int(person.get("birth_year", 0))
	return current_year - birth_year if birth_year > 0 else 0


func _couple_can_have_child(first: Dictionary, second: Dictionary, current_year: int) -> bool:
	var first_gender: String = str(first.get("gender", "unknown"))
	var second_gender: String = str(second.get("gender", "unknown"))
	if not ((first_gender == "male" and second_gender == "female") or (first_gender == "female" and second_gender == "male")):
		return false
	var first_age: int = _person_age(first, current_year)
	var second_age: int = _person_age(second, current_year)
	var female_age: int = first_age if first_gender == "female" else second_age
	return first_age >= ADULT_AGE and second_age >= ADULT_AGE and female_age <= 42


func _count_couple_children(children: Dictionary, person_a: String, person_b: String) -> int:
	var count: int = 0
	for child_value: Variant in children.values():
		var child: Dictionary = child_value
		var parents: Array[String] = [str(child.get("parent_a", "")), str(child.get("parent_b", ""))]
		if parents.has(person_a) and parents.has(person_b):
			count += 1
	return count


func _first_faction_province(provinces: Dictionary, faction_name: String) -> String:
	for province_id_value: Variant in provinces.keys():
		var province_id: String = str(province_id_value)
		if str(provinces[province_id].get("faction", "")) == faction_name:
			return province_id
	return ""


func _highest_stat(officer: Dictionary) -> int:
	var highest: int = 0
	for stat_key: String in STAT_KEYS:
		highest = maxi(highest, int(officer.get(stat_key, 0)))
	return highest


func _sort_units_by_power(first: Dictionary, second: Dictionary) -> bool:
	return int(first.get("power", 0)) > int(second.get("power", 0))
