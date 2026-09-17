extends RefCounted
const Army=preload("res://army_readiness.gd")
const Economy=preload("res://faction_economy.gd")
const Registry=preload("res://officer_registry.gd")
const Ending=preload("res://campaign_ending.gd")

static func ensure(s: Dictionary) -> Dictionary:
	if not s.has("invasions"): s.invasions={"version":1,"next_id":1,"orders":{}}
	return s.invasions

static func pending(s: Dictionary) -> Array:
	return s.get("invasions",{}).get("orders",{}).values().filter(func(o): return o.status=="pending")

static func validate(c: Node, row: Dictionary) -> String:
	if Ending.finished(c.strategy_state): return Ending.BLOCKED
	for city: String in [row.source,row.target]:
		if not c.provinces.has(city): return "출발지 또는 목표가 사라졌습니다."
	if Economy.resolve(c.strategy_state,c.provinces[row.source].faction)!=row.faction: return "출발지 소유권 변경"
	if Economy.resolve(c.strategy_state,c.provinces[row.target].faction)!=row.defender: return "목표 소유권 변경"
	if not c.province_connections.get(row.source,[]).has(row.target): return "침공 경로 단절"
	var staff: Dictionary=c.validate_attack_staff(row.source)
	if not staff.ok: return str(staff.reason)
	if not str(row.commander).is_empty() and not Registry.action_available(c.officer_registry,row.commander,c.provinces,"attack",row.source): return "지휘관 사망·소속·이동·업무 자격 변경"
	if not str(row.commander).is_empty() and c.get_officer(row.commander).faction_id!=row.faction: return "지휘관 소속 변경"
	if row.units.is_empty(): return "참전 부대 없음"
	for id: String in row.units:
		var u: Dictionary=Army.units(c.strategy_state).get(id,{})
		if u.is_empty() or int(u.troops)<=0 or u.faction_id!=row.faction or u.location!=row.source or u.status!="stationed": return "예약 부대 소실·소속·이동 변경: "+id
		if not Army.training_job(c.strategy_state,id).is_empty() or not c.Power.unit_reason(c.strategy_state,id).is_empty(): return "예약 부대 훈련·군권 자격 변경: "+id
		var owner: String=Army.reservation(c.strategy_state,id)
		if not owner.is_empty() and owner!=row.id: return "다른 침공에 예약된 부대: "+id
		var leader: String=str(u.commander_id)
		if leader!=str(row.get("unit_commanders",{}).get(id,leader)): return "예약 부대 지휘관 변경: "+id
		if not leader.is_empty() and (not Registry.action_available(c.officer_registry,leader,c.provinces,"attack",row.source) or c.get_officer(leader).faction_id!=row.faction): return "참전 부대 지휘관 자격 변경: "+id
	var authority: String=c.Power.attack_reason(c,row.source,row.commander)
	if not authority.is_empty(): return authority
	var q: Dictionary=Economy.validate(c.strategy_state,c.provinces,row.faction,row.faction,row.source,0,c.ATTACK_FOOD_COST)
	return "" if q.ok else str(q.reason)

static func declare(c: Node, source: String, target: String) -> Dictionary:
	if Ending.finished(c.strategy_state): return {"ok":false,"reason":Ending.BLOCKED}
	if not c.provinces.has(source) or not c.provinces.has(target): return {"ok":false,"reason":"존재하지 않는 침공 출발지·목표"}
	var db: Dictionary=ensure(c.strategy_state)
	var faction: String=Economy.resolve(c.strategy_state,c.provinces[source].faction)
	var ids: Array=Army.attack_units(c.strategy_state,source,faction)
	var leader: Dictionary=c.get_best_commander(source,"attack")
	var row: Dictionary={"id":"invasion:%d" % int(db.next_id),"source":source,"target":target,"faction":faction,"defender":Economy.resolve(c.strategy_state,c.provinces[target].faction),"units":ids.duplicate(),"commander":str(leader.get("officer_id","")),"announced_troops":Army.count(c.strategy_state,ids),"created_month":c.year*12+c.month,"due_month":c.year*12+c.month+1,"status":"pending","reason":"","battle_id":""}
	row["unit_commanders"]={}
	for id: String in ids: row.unit_commanders[id]=str(Army.units(c.strategy_state)[id].commander_id)
	var reason: String=validate(c,row)
	if not reason.is_empty(): return {"ok":false,"reason":reason}
	db.next_id+=1; db.orders[row.id]=row
	return {"ok":true,"order":row,"reason":"침공 예고: %s → %s · %s · 예고 병력 %d명" % [c.provinces[source].name,c.provinces[target].name,c.Power.date(row.due_month),row.announced_troops]}

static func process(c: Node) -> Array[String]:
	var messages: Array[String]=[]
	for row: Dictionary in pending(c.strategy_state):
		if int(row.due_month)>c.year*12+c.month: continue
		var reason: String=validate(c,row)
		# Synchronous execution owns precisely these IDs; reservation is released
		# for the common combat's casualty/occupation operations, never a frame early.
		row.status="executing"
		var result: Dictionary={"ok":false,"reason":reason}
		if reason.is_empty(): result=c.resolve_army_battle(row.source,row.target,row.faction,row)
		row.status="completed" if result.ok else "cancelled"
		row.reason=str(result.get("message",result.get("reason","")))
		row["processed_month"]=c.year*12+c.month
		row.battle_id=str(result.get("battle_id",""))
		messages.append("%s: %s" % [row.id,row.reason])
		if result.ok: c.queue_battle_merit(result)
	return messages
