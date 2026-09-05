extends RefCounted

# Evidence is not permission. Runtime gates require BOTH explicit scenario/city
# permission and confirmed GAME placement. This is not historical confirmation.
# This table is code data, never save data.
const CANDIDATES: Dictionary = {
	"ugye_ri": {
		"city_id": "geumgwan", "site": "김해 상동면 우계리",
		"source_url": "https://portal.nrich.go.kr/file_link/newFolder/897/report/8%20%EA%B9%80%ED%95%B4%20%EC%9A%B0%EA%B3%84%EB%A6%AC%20%EC%A0%9C%EC%B2%A0%EC%9C%A0%EC%A0%81.pdf",
		"source_title": "국립문화유산연구원 공개 자료: 김해 우계리 제철유적",
		"period": "자료 분류 6~7세기 / 측정 연대 5세기~7세기 중반",
		"evidence_types": ["제철 공방", "제탄", "제련 추정"],
		"confirmed_facts": "제철 관련 주거지·탄요·철광석·철재 확인",
		"uncertainty": "연료 생산 중심 취락일 가능성. 632~670년 채굴 가동, 개별 연도 조업 및 게임 도시 권역 대응은 미확정.",
		"mining_confirmed": false, "placement_confirmed": false,
	},
}
# Candidate evidence above remains unconfirmed. The following is an explicitly
# approved design pilot, NOT a claim of a working mine in 632 or 642.
# Schema: scenario_id -> city_id -> {allowed, placement_confirmed, candidate_id}.
const GEUMGWAN_PILOT: Dictionary = {
	"allowed": true, "placement_confirmed": true, "candidate_id": "ugye_ri",
	"label": "지역 제철 공급 시범 배치",
	"design_assumption": "우계리 제철 근거를 활용한 게임 설계상 가정입니다. 해당 시작 연도의 실제 채굴·가동 확정을 뜻하지 않습니다.",
}
# Keys are immutable campaign START scenario IDs, never the current year.
const SCENARIOS: Dictionary = {
	"silla_equilibrium_632": {"geumgwan": GEUMGWAN_PILOT},
	"goguryeo_coup_642": {"geumgwan": GEUMGWAN_PILOT},
}
# New-game model setup only. This does not imply other countries lacked the
# historical ability to smelt iron. No buildings, stocks or money are granted.
const STARTING_TECHNOLOGIES: Dictionary = {
	"silla_equilibrium_632": {"신라": {"basic_smelting": 1}},
	"goguryeo_coup_642": {"신라": {"basic_smelting": 1}},
}


static func apply_new_game_technologies(state: Dictionary, start_scenario_id: String) -> void:
	for faction: String in STARTING_TECHNOLOGIES.get(start_scenario_id, {}):
		var levels: Dictionary = state.get("faction_research", {}).get(faction, {})
		for tech_id: String in STARTING_TECHNOLOGIES[start_scenario_id][faction]:
			levels[tech_id] = maxi(int(levels.get(tech_id, 0)), int(STARTING_TECHNOLOGIES[start_scenario_id][faction][tech_id]))


static func placement_text(scenario_id: String, city_id: String, rules: Dictionary = SCENARIOS) -> String:
	if not blocked_reason(scenario_id, city_id, rules).is_empty():
		return "철 공급 공정 구현 / 본게임 생산지 배치 미적용"
	var placement: Dictionary = rules.get(scenario_id, {}).get(city_id, {})
	return "%s: %s" % [placement.get("label", "지역 제철 공급 허용"), placement.get("design_assumption", "설정된 시작 시나리오의 지역 조건을 적용합니다.")]


static func blocked_reason(scenario_id: String, city_id: String, rules: Dictionary = SCENARIOS) -> String:
	var placement: Dictionary = rules.get(scenario_id, {}).get(city_id, {})
	if not bool(placement.get("allowed", false)) or not bool(placement.get("placement_confirmed", false)):
		return "지역 철 공급 미허용: 본게임 생산지 배치 미적용 (후보 등록·연구·건설로 해제되지 않음)"
	return ""


static func evidence_text(city_id: String) -> String:
	for candidate: Dictionary in CANDIDATES.values():
		if str(candidate["city_id"]) == city_id:
			return "%s · 검토 근거 / 역사적 조업 미확정\n편년: %s\n근거: %s\n확인: %s\n불확실성: %s\n출처: %s\n%s" % [candidate.site, candidate.period, ", ".join(candidate.evidence_types), candidate.confirmed_facts, candidate.uncertainty, candidate.source_title, candidate.source_url]
	return "이 도시에는 검토된 철 공급 지역 근거가 등록되지 않았습니다."
