extends RefCounted
const Ending=preload("res://campaign_ending.gd")
# population is the existing civilian ledger; origins belong to the army ledger.
const Army=preload("res://army_readiness.gd")
const RATE: float=0.25
const UNIT: int=100
const AI_FOOD_MONTHS: int=3
static func initialize(state: Dictionary, provinces: Dictionary) -> void:
	if state.has("mobilization"): return
	state["mobilization"]={"version":1,"history":[],"migration":[],"ai_decisions":{},"ai_log":[]}
	for u: Dictionary in Army.units(state).values():
		if not u.has("creation_reason"): u["creation_reason"]="legacy_or_scenario_no_retroactive_charge"
		if not u.has("origins") or (u.origins.is_empty() and int(u.troops)>0):
			u["origins"]={str(u.location) if provinces.has(str(u.location)) else "unknown":int(u.troops)}
			state.mobilization.migration.append({"unit_id":u.id,"policy":"current location if known; otherwise unknown","origins":u.origins.duplicate(true)})
static func serving(state: Dictionary, city: String) -> int:
	var total: int=0
	for u: Dictionary in Army.units(state).values():
		if int(u.troops)>0: total+=int(u.get("origins",{}).get(city,0))
	return total
static func view(state: Dictionary, provinces: Dictionary, city: String) -> Dictionary:
	var civilians: int=maxi(0,int(provinces.get(city,{}).get("population",0)))
	var soldiers: int=serving(state,city)
	var available: int=maxi(0,floori((civilians+soldiers)*RATE)-soldiers)
	return {"civilians":civilians,"serving":soldiers,"available":mini(civilians,available)/UNIT*UNIT,"rate":RATE}
static func disband_quote(state: Dictionary, provinces: Dictionary, actor: String, id: String, amount: int) -> Dictionary:
	var q: Dictionary=Army.check_unit(state,provinces,actor,id)
	if not q.ok: return q
	var u: Dictionary=Army.units(state)[id]
	if amount<=0 or amount>int(u.troops): return {"ok":false,"reason":"해산 인원을 확인하세요."}
	return {"ok":true,"reason":"현지 민간 인구 +%d · 금·군량·장비 환불 없음" % amount,"city":u.location,"amount":amount,"civilians_after":int(provinces[u.location].population)+amount}
static func disband(state: Dictionary, provinces: Dictionary, actor: String, id: String, amount: int, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var context: Node=Army.Power.live(state.officer_registry)
	if context!=null and not Army.Power.applying:
		var gate: Dictionary=Army.Power.intercept(context,{"kind":"disband","target":id,"amount":amount,"faction_id":actor})
		if not gate.ok: return gate
	if not Army.Power.applying and not Army.Power.formation_reason(state,id).is_empty(): return {"ok":false,"reason":Army.Power.formation_reason(state,id)}
	var q: Dictionary=disband_quote(state,provinces,actor,id,amount)
	if not q.ok: return q
	initialize(state,provinces)
	var removed: Dictionary=Army.units(state)[Army.divide(state,id,amount)]
	var receipt: Dictionary={"action":"disband","month":stamp,"unit_id":id,"faction_id":actor,"city":q.city,"amount":amount,"equipment_consumed":removed.equipment,"origins":removed.origins.duplicate(true),"civilian_before":provinces[q.city].population}
	Army.stop(state,removed.id,"전원 해산")
	removed.troops=0; removed.training_points=0; removed.equipment=0; removed.origins={}; removed.status="disbanded"; removed.commander_id=""
	provinces[q.city].population=int(provinces[q.city].population)+amount
	receipt["civilian_after"]=provinces[q.city].population
	state.mobilization.history.append(receipt); Army.sync(state,provinces)
	return q

static func ai_amount(c: Node, faction: String, city: String, target: int) -> int:
	var state: Dictionary=c.strategy_state
	var p: Dictionary=c.provinces[city]
	var maximum: int=c.Recruitment.affordable(state,c.provinces,faction,city,target)
	var reason: String="인구·국고·군량 한도"
	var before: Dictionary=c.city_operation_quote(city)
	while maximum>0:
		var shadow: Dictionary=p.duplicate(true); shadow.population=int(p.population)-maximum
		var remaining: int=int(p.food_stock)-maximum/100*20
		var monthly: int=(int(p.troops)+maximum)/100
		var tax_after: int=roundi(c.calculate_base_commerce_income(shadow)*float(before.governor.multiplier))
		var harvest_after: int=roundi(c.calculate_base_annual_harvest(shadow)*float(before.governor.multiplier))
		if remaining>=monthly*AI_FOOD_MONTHS and tax_after>=floori(int(before.tax)*0.95) and harvest_after>=floori(int(before.annual_harvest)*0.95): break
		reason="모집 후 3개월 군량·세입/수확 95% 보존 기준"; maximum-=UNIT
	var key: String=faction+":"+city
	var decision: Dictionary={"amount":maximum,"reason":reason if maximum==0 else "모집 가능 · 인구/예상 산출/주둔 유지 검증"}
	if state.mobilization.ai_decisions.get(key,{})!=decision:
		state.mobilization.ai_decisions[key]=decision
		state.mobilization.ai_log.append({"month":c.year*12+c.month,"faction_id":faction,"city":city,"decision":decision.duplicate(true),"civilians":p.population,"serving":serving(state,city),"tax":before.tax,"harvest":before.annual_harvest})
	return maximum
