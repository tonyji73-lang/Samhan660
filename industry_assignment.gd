extends RefCounted
const Ending=preload("res://campaign_ending.gd")

const Registry=preload("res://officer_registry.gd")
const Domestic=preload("res://domestic_assignment.gd")
const Economy=preload("res://faction_economy.gd")
const SEASON_MONTHS: int=3
const WORK_PER_MONTH: int=100
const BASE_WORK: int=50
const FACILITY_BY_RECIPE: Dictionary={"iron_supply":"smelter","iron_sword":"forge","iron_procurement":"smelter"}

static func efficiency(person: Dictionary, kind: String) -> int:
	var politics: float=float(person.get("politics",0))
	var intelligence: float=float(person.get("intelligence",0))
	var value: float=politics*0.5+intelligence*0.5
	if kind=="build": value=politics*0.7+intelligence*0.3
	if kind=="research": value=intelligence*0.8+politics*0.2
	return clampi(roundi(value),0,100)

static func work(person: Dictionary, kind: String) -> int:
	return 100+roundi(float(efficiency(person,kind))/2.0) if kind=="production" else BASE_WORK+efficiency(person,kind)

static func jobs(state: Dictionary) -> Dictionary:
	return Domestic.ensure(state).jobs

static func active(state: Dictionary, kind: String, city: String, faction_id: String) -> Dictionary:
	for job: Dictionary in jobs(state).values():
		if job.kind=="training": continue
		if job.kind!=kind or job.status not in ["pending","paused"]: continue
		if (kind=="research" and job.get("faction_id","")==faction_id) or (kind!="research" and job.city_id==city): return job
	return {}

static func release(state: Dictionary, job: Dictionary) -> void:
	Domestic.release(state,job)

static func history(job: Dictionary, stamp: int, action: String, previous: String = "") -> void:
	if not job.has("history"): job["history"]=[]
	job.history.append({"month":stamp,"action":action,"officer_id":job.officer_id,"previous_id":previous,"city_id":job.city_id,"progress":job.progress})

static func queue_pointer(state: Dictionary, job: Dictionary) -> void:
	if job.kind=="production": return
	var key: String=job.faction if job.kind=="research" else job.city_id
	var table: String="research_queues" if job.kind=="research" else "construction_queues"
	state[table][key]={"industry_job_id":job.id,"research_id" if job.kind=="research" else "building_id":job.requirement_id}

static func remove_queue(state: Dictionary, job: Dictionary) -> void:
	if job.kind=="production": return
	var table: String="research_queues" if job.kind=="research" else "construction_queues"
	var key: String=job.faction if job.kind=="research" else job.city_id
	if state.get(table,{}).get(key,{}).get("industry_job_id","")==job.id: state[table].erase(key)

static func normalize(state: Dictionary, provinces: Dictionary, strategy: RefCounted, stamp: int) -> void:
	state["industry_version"]=1
	Domestic.ensure(state)
	for kind: String in ["build","research"]:
		var table: String="construction_queues" if kind=="build" else "research_queues"
		for key: String in state.get(table,{}).keys():
			var old: Dictionary=state[table][key]
			if old.has("industry_job_id"): continue
			var requirement: String=str(old.get("building_id" if kind=="build" else "research_id",""))
			var definitions: Dictionary=strategy.BUILDING_DEFS if kind=="build" else strategy.RESEARCH_DEFS
			var definition: Dictionary=definitions.get(requirement,{})
			var level: int=int(old.get("target_level",1))
			var base_seasons: int=int(definition.get("base_turns",1))+(int((level-1)/2) if kind=="build" else level-1)
			var remaining: int=maxi(0,int(old.get("remaining_turns",base_seasons)))*SEASON_MONTHS*WORK_PER_MONTH
			var required: int=maxi(remaining,base_seasons*SEASON_MONTHS*WORK_PER_MONTH)
			var city: String=key if kind=="build" else str(old.get("city_id",""))
			var faction: String=key if kind=="research" else str(provinces.get(city,{}).get("faction",""))
			var payer: String=str(old.get("payer_faction_id",Economy.resolve(state,faction)))
			var id: String="industry:%d" % int(state.domestic.next_id); state.domestic.next_id=int(state.domestic.next_id)+1
			var job: Dictionary={"id":id,"kind":kind,"requirement_id":requirement,"target_level":level,"name":definition.get("name",requirement),"city_id":city,"faction":state.faction_economy.factions.get(payer,faction),"faction_id":payer,"payer_faction_id":payer,"officer_id":"","cost_paid":int(old.get("cost_paid",0)),"cost_known":old.has("cost_paid"),"refund":0,"required":required,"progress":required-remaining,"status":"paused","reason":"담당자 배정 필요","accepted_month":stamp,"last_month":stamp,"legacy_queue":old.duplicate(true)}
			jobs(state)[id]=job; queue_pointer(state,job); history(job,stamp,"구형 계절 작업 변환")
			var reference: String=str(old.get("officer_id",old.get("assigned_officer","")))
			if not reference.is_empty():
				var existing: String=Registry.resolve(state.officer_registry,reference)
				if kind=="research" and city.is_empty(): city=str(Registry.view(state.officer_registry,existing).get("location",""))
				var restored: Dictionary=assign(state,provinces,payer,id,city,existing,stamp)
				if not restored.ok: job.reason="기존 담당자 확인 필요: "+str(restored.reason)
	if not state.has("facility_progress"): state["facility_progress"]={}

static func staff_reason(state: Dictionary, provinces: Dictionary, faction_id: String, city: String, officer_id: String, stamp: int, current_job: String = "") -> String:
	var budget: Dictionary=Economy.validate(state,provinces,faction_id,faction_id,city)
	if not budget.ok: return budget.reason
	if not Registry.eligible(state.officer_registry,officer_id,provinces,city): return "해당 도시에서 근무할 담당자 배정 필요"
	var p: Dictionary=Registry.view(state.officer_registry,officer_id)
	if p.faction_id!=faction_id: return "담당자 소속이 다릅니다."
	if int(p.get("external_action_month",-1))>=stamp: return "이 달 사절·출정 활동으로 업무 배정 불가"
	if current_job.is_empty():
		if not Registry.action_available(state.officer_registry,officer_id,provinces,"industry",city): return "다른 업무를 먼저 중단하거나 완료하세요."
	else:
		for duty: Dictionary in Registry.get_person(state.officer_registry,officer_id).get("duties",[]):
			if duty.get("job_id","")!=current_job: return "다른 업무를 먼저 중단하거나 완료하세요."
	return ""

static func quote(state: Dictionary, provinces: Dictionary, strategy: RefCounted, faction_id: String, city: String, kind: String, requirement: String, officer_id: String, stamp: int, scenario: String, rules: Dictionary) -> Dictionary:
	var faction: String=state.faction_economy.factions.get(faction_id,"")
	var q: Dictionary={"ok":true,"gold_cost":0,"turns":0,"name":"생산 관리","next_level":0}
	if kind=="build": q=strategy.get_building_quote(state,city,requirement,scenario,rules)
	elif kind=="research": q=strategy.get_research_quote(state,faction,requirement)
	elif kind!="production": return {"ok":false,"reason":"지원하지 않는 업무입니다."}
	q=q.duplicate(true)
	var p: Dictionary=Registry.view(state.officer_registry,officer_id)
	q.merge({"person":p,"efficiency":efficiency(p,kind),"work":work(p,kind),"required":int(q.get("turns",0))*SEASON_MONTHS*WORK_PER_MONTH,"reason":q.get("reason","")})
	q["work"]=effective_work(state,city,p,kind)
	q["months"]=remaining_months(state,city,p,kind,int(q.required))
	q["due_month"]=stamp+int(q.months)
	if not q.ok: return q
	if not active(state,kind,city,faction_id).is_empty(): q.ok=false; q.reason="이미 진행 중인 업무가 있습니다. 기존 업무의 담당자를 변경하세요."; return q
	q.reason=staff_reason(state,provinces,faction_id,city,officer_id,stamp)
	if q.reason.is_empty():
		var budget: Dictionary=Economy.validate(state,provinces,faction_id,faction_id,city,int(q.gold_cost))
		q.reason=budget.reason
	q.ok=q.reason.is_empty()
	return q

static func start(state: Dictionary, provinces: Dictionary, strategy: RefCounted, faction_id: String, city: String, kind: String, requirement: String, officer_id: String, stamp: int, scenario: String, rules: Dictionary) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var q: Dictionary=quote(state,provinces,strategy,faction_id,city,kind,requirement,officer_id,stamp,scenario,rules)
	if not q.ok: return q
	var id: String="industry:%d" % int(state.domestic.next_id)
	var paid: Dictionary=Economy.spend(state,provinces,faction_id,faction_id,city,int(q.gold_cost),0,kind,stamp,id+":cost")
	if not paid.ok: return paid
	state.domestic.next_id=int(state.domestic.next_id)+1
	var job: Dictionary={"id":id,"kind":kind,"name":q.name,"requirement_id":requirement,"target_level":int(q.next_level),"city_id":city,"faction_id":faction_id,"faction":state.faction_economy.factions[faction_id],"payer_faction_id":faction_id,"officer_id":officer_id,"cost_paid":int(q.gold_cost),"cost_known":true,"refund":0,"required":int(q.required),"progress":0,"status":"pending","reason":"","accepted_month":stamp,"last_month":stamp}
	jobs(state)[id]=job
	Registry.get_person(state.officer_registry,officer_id).duties.append({"kind":"industry","job_id":id,"city_id":city})
	queue_pointer(state,job); history(job,stamp,"접수")
	q["job_id"]=id
	return q

static func assign(state: Dictionary, provinces: Dictionary, actor: String, id: String, city: String, officer_id: String, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var job: Dictionary=jobs(state).get(id,{})
	if job.is_empty() or job.get("faction_id","")!=actor or job.status not in ["pending","paused"]: return {"ok":false,"reason":"변경 가능한 아군 업무가 없습니다."}
	if job.kind!="research" and city!=job.city_id: return {"ok":false,"reason":"이 업무의 수행 도시는 변경할 수 없습니다."}
	var reason: String=staff_reason(state,provinces,actor,city,officer_id,stamp,id)
	if not reason.is_empty(): return {"ok":false,"reason":reason}
	var previous: String=job.officer_id
	release(state,job); job.officer_id=officer_id; job.city_id=city; job.status="pending"; job.reason=""
	job.last_month=maxi(int(job.last_month),stamp)
	Registry.get_person(state.officer_registry,officer_id).duties.append({"kind":"industry","job_id":id,"city_id":city})
	history(job,stamp,"담당자/거점 변경",previous)
	return {"ok":true,"reason":"누적 진척과 납부 내역을 유지했습니다."}

static func pause(state: Dictionary, actor: String, id: String, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var job: Dictionary=jobs(state).get(id,{})
	if job.is_empty() or job.get("faction_id","")!=actor or job.status not in ["pending","paused"]: return {"ok":false,"reason":"중단 가능한 업무가 없습니다."}
	release(state,job); job.status="paused"; job.reason="일시 중지 · 담당자 배정 필요"
	var previous: String=job.officer_id; job.officer_id=""; history(job,stamp,"일시 중지",previous)
	return {"ok":true,"reason":job.reason}

static func cancel(state: Dictionary, provinces: Dictionary, actor: String, id: String, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	validate_ownership(state,provinces,stamp)
	var job: Dictionary=jobs(state).get(id,{})
	if job.is_empty() or job.get("faction_id","")!=actor or job.status not in ["pending","paused"]: return {"ok":false,"reason":"취소 가능한 업무가 없습니다."}
	var refund: int=int(job.cost_paid) if int(job.progress)==0 and bool(job.cost_known) else 0
	if refund>0 and not Economy.post(state,job.payer_faction_id,refund,"industry_refund",stamp,job.city_id,id+":refund"): return {"ok":false,"reason":"환불 기록 확인 필요"}
	release(state,job); job.refund=refund; job.status="cancelled"; job.reason="취소 · 환불 %d" % refund
	remove_queue(state,job); history(job,stamp,"취소")
	return {"ok":true,"reason":job.reason,"refund":refund}

static func capture(state: Dictionary, city: String, stamp: int) -> void:
	if Ending.finished(state): return
	for job: Dictionary in jobs(state).values():
		if job.kind=="training": continue
		if job.kind not in ["build","research","production"] or job.city_id!=city or job.status not in ["pending","paused"]: continue
		release(state,job)
		job.status="paused" if job.kind=="research" else "interrupted"
		job.reason="연구 거점 상실 · 아군 거점과 담당자 재지정 필요" if job.kind=="research" else "도시 상실 · 환불 없이 종료"
		if job.kind!="research": remove_queue(state,job)
		history(job,stamp,"도시 상실")
	for facility: Dictionary in state.get("facility_progress",{}).get(city,{}).values():
		facility.remainder=0; facility.owner=""

static func validate_ownership(state: Dictionary, provinces: Dictionary, stamp: int) -> void:
	var captured: Dictionary={}
	for job: Dictionary in jobs(state).values():
		if job.kind=="training": continue
		if job.kind not in ["build","research","production"] or job.status not in ["pending","paused"]: continue
		if Economy.resolve(state,str(provinces.get(job.city_id,{}).get("faction","")))!=job.faction_id and not (job.kind=="research" and job.status=="paused"):
			captured[job.city_id]=true
	for city: String in captured: capture(state,city,stamp)

static func process(state: Dictionary, provinces: Dictionary, stamp: int) -> Array[String]:
	if Ending.finished(state): return []
	validate_ownership(state,provinces,stamp)
	var messages: Array[String]=[]
	for job: Dictionary in jobs(state).values():
		if job.kind=="training": continue
		if job.kind not in ["build","research","production"] or job.status!="pending": continue
		if int(job.last_month)>=stamp: continue
		job.last_month=stamp
		var reason: String=staff_reason(state,provinces,job.faction_id,job.city_id,job.officer_id,stamp,job.id)
		if not reason.is_empty():
			release(state,job); job.status="paused"; job.reason=reason; history(job,stamp,"자격 상실 중지"); continue
		if job.kind=="production": continue
		var amount: int=work(Registry.view(state.officer_registry,job.officer_id),job.kind)
		if job.kind=="build": amount=floori(amount*Registry.Power.city_factor(state,job.city_id))
		job["last_work"]=amount; job.progress=mini(int(job.required),int(job.progress)+amount)
		history(job,stamp,"월 진척")
		if int(job.progress)<int(job.required): continue
		var levels: Dictionary=state.faction_research[job.faction] if job.kind=="research" else state.province_buildings[job.city_id]
		levels[job.requirement_id]=maxi(int(levels.get(job.requirement_id,0)),int(job.target_level))
		job.status="completed"; job.reason="%s %d단계 완료" % [job.name,job.target_level]; job["completed_month"]=stamp
		release(state,job); remove_queue(state,job); history(job,stamp,"완료"); messages.append(job.reason)
	return messages

static func production_work(state: Dictionary, provinces: Dictionary, city: String, stamp: int) -> int:
	var owner: String=Economy.resolve(state,str(provinces.get(city,{}).get("faction","")))
	var job: Dictionary=active(state,"production",city,owner)
	if job.is_empty() or job.status!="pending" or not staff_reason(state,provinces,owner,city,job.officer_id,stamp,job.id).is_empty(): return floori(100*Registry.Power.city_factor(state,city))
	return floori(roundi(work(Registry.view(state.officer_registry,job.officer_id),"production")*Registry.Politics.multiplier(state,job.officer_id))*Registry.Power.city_factor(state,city))

# Shared current work and expiry-aware estimate for execution, UI and AI.
static func effective_work(state: Dictionary, city: String, person: Dictionary, kind: String) -> int:
	return floori(work(person,kind)*(Registry.Power.city_factor(state,city) if kind=="build" else 1.0))
static func remaining_months(state: Dictionary, city: String, person: Dictionary, kind: String, required: int) -> int:
	var remaining: int=maxi(0,required); var months: int=0
	var disrupted: int=int(Registry.Power.records(state).get("cities",{}).get(city,{}).get("remaining",0)) if kind=="build" else 0
	var base: int=maxi(1,work(person,kind))
	while remaining>0:
		remaining-=maxi(1,floori(base*0.8)) if months<disrupted else base
		months+=1
	return months