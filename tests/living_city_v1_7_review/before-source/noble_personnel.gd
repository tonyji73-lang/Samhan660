extends RefCounted
const Ending=preload("res://campaign_ending.gd")
const Core=preload("res://noble_politics.gd")
const Registry=preload("res://officer_registry.gd")
const Army=preload("res://army_readiness.gd")
const Economy=preload("res://faction_economy.gd")
const EVENT="noble_personnel_demand"
static func quote(c: Node, faction: String, kind: String, target: String, id: String) -> Dictionary:
	var r: Dictionary=c.officer_registry; var p: Dictionary=Registry.get_person(r,id)
	var city: String=target if kind=="governor" else str(c.strategy_state.unit_rosters.get(target,{}).get("location",""))
	var access: Dictionary=Economy.validate(c.strategy_state,c.provinces,faction,faction,city)
	if not access.ok: return access
	if p.is_empty() or p.get("faction_id","")!=faction or not Registry.eligible(r,id,c.provinces,city): return {"ok":false,"reason":"같은 도시의 활동 가능한 아군 인물이 필요합니다."}
	if kind not in ["governor","commander"]: return {"ok":false,"reason":"지원하지 않는 직책"}
	var old: String=str(r.posts.get("governor:"+city,"")) if kind=="governor" else str(c.strategy_state.unit_rosters.get(target,{}).get("commander_id",""))
	if kind=="commander":
		var q: Dictionary=Army.check_unit(c.strategy_state,c.provinces,faction,target)
		if not q.ok: return q
		if not Registry.action_available(r,id,c.provinces,"attack",city): return {"ok":false,"reason":"이동·사절·진행 업무를 먼저 정리하세요."}
	if old==id: return {"ok":false,"reason":"이미 같은 담당자입니다."}
	var attribute: String="politics" if kind=="governor" else "leadership"
	var shadow: Dictionary=c.strategy_state.duplicate(true)
	if kind=="governor":
		for post: String in shadow.officer_registry.posts.keys():
			if post.begins_with("governor:") and shadow.officer_registry.posts[post]==id: shadow.officer_registry.posts.erase(post)
		shadow.officer_registry.posts["governor:"+city]=id
	else:
		for u: Dictionary in shadow.unit_rosters.values():
			if u.commander_id==id: u.commander_id=""
		shadow.unit_rosters[target].commander_id=id
	var before: Dictionary=Core.influence(c.strategy_state,c.provinces,faction)
	var after: Dictionary=Core.influence(shadow,c.provinces,faction)
	var history_start: int=shadow.officer_registry.get("politics",{}).get("history",[]).size()
	Core.reaction(shadow.officer_registry,old,id,kind=="governor" or Core.commanded(shadow,id)>Core.commanded(c.strategy_state,id),"인사 예상",c.year*12+c.month)
	var reactions: Array=shadow.officer_registry.get("politics",{}).get("history",[]).slice(history_start)
	return {"ok":true,"reason":"","kind":kind,"target":target,"city":city,"officer_id":id,"previous_id":old,"attribute":attribute,"old_ability":Registry.view(r,old).get(attribute,0),"ability":Registry.view(r,id).get(attribute,0),"before":before,"after":after,"reactions":reactions}
static func appoint(c: Node, faction: String, kind: String, target: String, id: String) -> Dictionary:
	if Ending.finished(c.strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var q: Dictionary=quote(c,faction,kind,target,id)
	if not q.ok: return q
	var gate: Dictionary=Registry.Power.intercept(c,{"kind":kind,"target":target,"officer_id":id,"faction_id":faction})
	if not gate.ok: return gate
	c.officer_registry.clock_month=c.year*12+c.month
	if kind=="governor": Registry.set_post(c.officer_registry,"governor:"+target,id,"왕명 인사"); c._sync_officer_labels()
	else: return Army.appoint(c.strategy_state,c.provinces,faction,target,id)
	return {"ok":true,"reason":"태수 임명 완료"}
static func viable(c: Node, request: Dictionary) -> bool:
	if Core.group(c.officer_registry,str(request.officer_id))!=str(request.group_id): return false
	var q: Dictionary=quote(c,str(request.faction_id),str(request.kind),str(request.target),str(request.officer_id))
	if not q.ok: return false
	if request.kind=="commander": return int(c.strategy_state.unit_rosters[request.target].troops)>Core.commanded(c.strategy_state,request.officer_id)
	return true
static func propose(c: Node) -> Dictionary:
	if Ending.finished(c.strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var r: Dictionary=c.officer_registry
	if not r.has("politics"): return {}
	var db: Dictionary=r.politics; var stamp: int=c.year*12+c.month
	if not db.pending.is_empty(): return db.pending
	if stamp-int(db.last_national)<int(Core.RULES.national_interval): return {}
	var f: String=db.faction_id; var power: Dictionary=Core.influence(c.strategy_state,c.provinces,f)
	var candidates: Array=[]
	for gid: String in db.groups:
		if db.groups[gid].royal or float(power.groups[gid].influence)<float(Core.RULES.threshold) or stamp-int(db.last_demands.get(gid,-10000))<int(Core.RULES.group_interval): continue
		for id: String in db.groups[gid].members:
			var p: Dictionary=r.people[id]
			if not p.active or not p.alive or p.in_transit: continue
			var options: Array=[{"kind":"governor","target":p.location}]
			for uid: String in Army.at_city(c.strategy_state,p.location,f): options.append({"kind":"commander","target":uid})
			for option: Dictionary in options:
				if not Registry.Power.open_request(c.strategy_state,option.kind,option.target).is_empty(): continue
				var candidate_request: Dictionary=option.merged({"officer_id":id,"group_id":gid,"faction_id":f})
				if viable(c,candidate_request): candidate_request["priority"]=int(p.get("ambition",50))*int(Core.RULES.ambition_weight)+(100-int(p.get("loyalty",50))); candidates.append(candidate_request)
	if candidates.is_empty(): return {}
	candidates.sort_custom(func(a,b): return str(a.officer_id)+str(a.target)<str(b.officer_id)+str(b.target) if a.priority==b.priority else a.priority>b.priority)
	var request: Dictionary=candidates[0]; var key: String="noble:%d" % int(db.next_id); db.next_id=int(db.next_id)+1
	var city: String=request.target if request.kind=="governor" else c.strategy_state.unit_rosters[request.target].location
	request.merge({"event_id":EVENT,"occurrence_id":key,"created_month":stamp,"payload":{"candidate":r.people[request.officer_id].name,"group":db.groups[request.group_id].name,"position":str(c.provinces[city].name)+(" 태수" if request.kind=="governor" else " 부대 지휘관"),"result_text":""}})
	db.pending=request; db.last_national=stamp; db.last_demands[request.group_id]=stamp
	return request
static func reason(c: Node, occurrence: String, choice: String) -> String:
	var request: Dictionary=c.officer_registry.get("politics",{}).get("pending",{})
	if request.is_empty() or request.get("occurrence_id","")!=occurrence: return "이미 처리된 요구입니다."
	if choice not in ["accept","gift","reject"]: return "알 수 없는 선택"
	if not viable(c,request): return "" # Any choice dismisses the invalid demand without side effects.
	if choice=="gift" and Economy.balance(c.strategy_state,request.faction_id)<int(Core.RULES.gift_cost): return "포상 금100이 부족합니다."
	return ""
static func resolve(c: Node, occurrence: String, choice: String) -> Dictionary:
	if Ending.finished(c.strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	if not reason(c,occurrence,choice).is_empty(): return {}
	var r: Dictionary=c.officer_registry; var db: Dictionary=r.politics; var request: Dictionary=db.pending
	if request.is_empty(): return {}
	var stamp: int=c.year*12+c.month; var text: String="후보·직책 조건이 바뀌어 요구를 취소했습니다. 비용과 반응은 없습니다."
	var valid: bool=viable(c,request)
	if valid:
		match choice:
			"accept":
				var result: Dictionary=appoint(c,request.faction_id,request.kind,request.target,request.officer_id)
				if not result.ok:
					if result.has("negotiation_id"):
						db.resolved[occurrence]={"month":stamp,"choice":"handover_required","negotiation_id":result.negotiation_id}; db.pending={}
						return {"result_text":"권력 인계 협의가 필요합니다. 인사 효과·비용 없이 기존 요구를 닫습니다. 메뉴의 권력 인계에서 선택하세요."}
					return {}
				text="실제 직책을 임명했습니다. 일반 인사 반응만 한 번 적용했습니다."
			"gift":
				var paid: Dictionary=Economy.validate_national(c.strategy_state,request.faction_id,request.faction_id,int(Core.RULES.gift_cost))
				# No city stock is consumed by this national gift.
				if not paid.ok or not Economy.post(c.strategy_state,request.faction_id,-int(Core.RULES.gift_cost),"political_gift",stamp,"",occurrence+":gift"): return {}
				Core.change(r,request.officer_id,int(Core.RULES.gift_loyalty),int(Core.RULES.gift_cooperation),"인사 요구 포상",stamp); text="국고 금100 지출 · 충성 +5 · 협력 +6 · 직책 유지"
			"reject": Core.change(r,request.officer_id,int(Core.RULES.reject_loyalty),int(Core.RULES.reject_cooperation),"인사 요구 거절",stamp); text="충성 -6 · 협력 -6 · 국고/직책 유지"
	db.resolved[occurrence]={"month":stamp,"choice":choice,"valid":valid,"request":request.duplicate(true),"result":text}; db.pending={}
	return {"result_text":text}
static func ai(c: Node) -> void:
	if Ending.finished(c.strategy_state): return
	var r: Dictionary=c.officer_registry
	if not r.has("politics") or c.player_faction_id==r.politics.faction_id: return
	var request: Dictionary=propose(c)
	if request.is_empty(): return
	var q: Dictionary=quote(c,request.faction_id,request.kind,request.target,request.officer_id)
	var reserve: int=int(Core.RULES.ai_reserve_gold)
	for city: String in Economy.city_ids(c.strategy_state,c.provinces):
		if Economy.resolve(c.strategy_state,c.provinces[city].faction)==request.faction_id: reserve+=c.ai_recruitment_amount/100*15
	var choice: String="reject"; var why: String="능력/집중도 또는 예산 기준으로 거절"
	if q.ok and int(q.ability)>=int(q.old_ability) and float(q.after.groups[request.group_id].influence)<=float(Core.RULES.ai_concentration_limit): choice="accept"; why="직무 능력이 낮아지지 않고 집단 영향력60 이하"
	elif Economy.balance(c.strategy_state,request.faction_id)>=int(Core.RULES.gift_cost)+reserve:
		choice="gift"; why="직책 교체 대신 모집/보급 예비금 이후 포상"
	var result: Dictionary=resolve(c,request.occurrence_id,choice)
	r.politics.ai_log.append({"month":c.year*12+c.month,"choice":choice,"reserve":reserve,"reason":why,"result":result})
