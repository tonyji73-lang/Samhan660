extends RefCounted
const Economy=preload("res://faction_economy.gd")
const Army=preload("res://army_readiness.gd")
const Industry=preload("res://industry_assignment.gd")
const Supply=preload("res://supply_transport.gd")
static func text(c: Node) -> String:
	var cities: Array[String]=[]; var troops: int=0; var equipped: int=0
	for city: String in Economy.city_ids(c.strategy_state,c.provinces):
		if Economy.resolve(c.strategy_state,c.provinces[city].faction)==c.player_faction_id: cities.append(city)
	for u: Dictionary in c.strategy_state.unit_rosters.values():
		if u.faction_id==c.player_faction_id:
			troops+=maxi(0,int(u.troops)); equipped+=mini(maxi(0,int(u.troops)),int(u.equipment))
	var lines: Array[String]=[
		"장기 목표: 한반도 35개 지역 통일 · 현재 %d/35개 지역" % cities.size(),
		"종료 v1: 고정 목표 35개 도시 직접 점유 시 승리, 최종 거점 상실 및 실행 가능한 수복 경로 부재 시 패배합니다. 동맹 점유는 제외하며 전투·월·필수 사건 정산 후 판정합니다. 종료 후 결과 저장·불러오기·새 캠페인을 사용할 수 있습니다.",
		"군주 사망·계승 및 역사 연도에 따른 강제 교체도 아직 연결되지 않았습니다. 초기 시나리오 배치와 플레이 중 상태를 구분합니다.",
		"\n보유군 %d명 · 장비 지급 %d명분 · 미지급 %d명" % [troops,equipped,maxi(0,troops-equipped)],
		"기존 병력은 기본 장비와 훈련50을 보유합니다. 전원을 다시 준비할 필요는 없습니다. 신규 병력은 모집 시 무기가 지급되지 않습니다.",
		"신규 보병1,000명: 모집 금150·현지 군량200·민간1,000 + 무기10묶음. 훈련50→70은 담당자에 따라 2~3개월·금100~150이며 정상 군량 유지비는 별도입니다.",
		"무기0부터 기본 시설 한 쌍은 월1묶음=100명분, 연1,200명분을 생산합니다. 공통 조달은 1,000명분 금280/10개월, 기존 허용 지역 공급은 금160/10개월입니다. 연구·시설 준비와 수송 기간은 추가됩니다.",
		"\n패전 회복: 안전한 아군 도시로 잔존 병력 이동 → 현지 모집 한도/군량 확인 → 생산 도시의 무기 수송 → 부족분 지급. 민간·군량 부족 때는 모집 축소·현지 해산·아군 군량 수송을 검토하세요.",
		"공급망 상실: 다음 경유지가 적이면 화물 대기 → 현재 아군 위치에서 재지정/하역. 지역 공급이 막혀도 기본 제련+제철시설이 있는 아군 도시의 공통 철 조달을 사용할 수 있습니다.",
		"\n현재 자동 전투: 실제 참여 병력·보병 장비/훈련·병종 기본 전투력·지휘관 통솔·성곽을 반영합니다. 지형/병종 상성/진형 선택의 별도 전술 효과는 연결되지 않았습니다.",
		"정치 영향력은 실제 직책 기반이며 반란 확률이 아닙니다. 현재 협력 효과는 귀족 생산 담당자의 작업량에만 적용되고 인사권 제한·반란 전투는 없습니다."
	]
	var city: String=c.selected_province_id
	var base: String=c.ScenarioData.get_starting_province(c.scenario_id,c.player_faction_id)
	if c.provinces.has(city) and c.provinces[city].faction==c.player_faction and city!=base:
		var route: Array=Supply.route(c.strategy_state,c.provinces,c.player_faction_id,base,city)
		lines.insert(1,"선택 도시 %s · 시작 거점과 아군 육상 보급로: %s · 현지 군량%d/월 소비%d" % [c.provinces[city].name,"없음 — 경유지 소유권·도로 확인" if route.is_empty() else "%d구간" % (route.size()-1),int(c.provinces[city].food_stock),Supply.upkeep(c.provinces[city])])
	return "\n".join(lines)
