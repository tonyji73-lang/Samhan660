extends RefCounted
const Ending=preload("res://campaign_ending.gd")

const Registry = preload("res://officer_registry.gd")
const Economy = preload("res://faction_economy.gd")
const COST: int = 100
const MONTHS: int = 1
const MAX_DEVELOPMENT: int = 100
const POLITICS_WEIGHT: float = 0.8
const INTELLIGENCE_WEIGHT: float = 0.2
const GOVERNOR_DIVISOR: float = 500.0
const BASE_GAIN: float = 1.0
const GAIN_RANGE: float = 4.0
const EFFICIENCY_SCALE: float = 100.0
const MIN_GAIN: int = 1
const MAX_GAIN: int = 5

static func ensure(state: Dictionary) -> Dictionary:
	if not state.has("domestic"):
		state.domestic = {"version":1,"next_id":1,"jobs":{},"settlements":{}}
	return state.domestic

static func efficiency(person: Dictionary) -> float:
	return float(person.get("politics",0))*POLITICS_WEIGHT+float(person.get("intelligence",0))*INTELLIGENCE_WEIGHT

static func increase(person: Dictionary) -> int:
	return clampi(roundi(BASE_GAIN+GAIN_RANGE*efficiency(person)/EFFICIENCY_SCALE),MIN_GAIN,MAX_GAIN)

static func active_job(state: Dictionary, city: String) -> Dictionary:
	for job: Dictionary in state.get("domestic",{}).get("jobs",{}).values():
		if job.kind in ["agriculture","commerce"] and job.city_id==city and job.status=="pending": return job
	return {}

static func quote(state: Dictionary, provinces: Dictionary, faction: String, city: String, kind: String, officer_ref: String, gold: int, stamp: int) -> Dictionary:
	if state.has("faction_economy"): gold=Economy.balance(state,Economy.resolve(state,faction))
	var r: Dictionary = state.get("officer_registry",{})
	var id: String = Registry.resolve(r,officer_ref)
	var p: Dictionary = Registry.view(r,id)
	var q: Dictionary = {"ok":false,"reason":"","cost":COST,"city_id":city,"kind":kind,"officer_id":id,"gain":0,"due_month":stamp+MONTHS,"person":p}
	if not provinces.has(city) or provinces[city].get("faction","")!=faction: q.reason="현재 소유한 도시에서만 개발할 수 있습니다."
	elif kind not in ["agriculture","commerce"]: q.reason="지원하지 않는 내정 업무입니다."
	elif not active_job(state,city).is_empty(): q.reason="이 도시에는 진행 중인 개발 업무가 있습니다."
	elif int(provinces[city].get(kind,0))>=MAX_DEVELOPMENT: q.reason="개발 수치가 상한 100에 도달했습니다."
	elif not Registry.eligible(r,id,provinces,city): q.reason="해당 도시와 소속에서 근무할 수 있는 담당자를 선택하세요."
	elif not Registry.action_available(r,id,provinces,"domestic",city): q.reason="진행 중인 내정 업무를 먼저 완료하거나 취소하세요."
	elif int(p.get("external_action_month",-1))>=stamp: q.reason="이 달에 출정·사절 활동을 수행한 인물입니다. 다음 달에 배정하세요."
	else:
		q["efficiency"]=efficiency(p)
		q.gain=mini(increase(p),MAX_DEVELOPMENT-int(provinces[city][kind]))
		if gold<COST: q.reason="금이 부족합니다. 금 100이 필요합니다."
		else: q.ok=true
	if q.ok and state.has("faction_economy"):
		var payer: String=Economy.resolve(state,faction)
		var budget: Dictionary=Economy.validate(state,provinces,payer,payer,city,COST)
		if not budget.ok: q.ok=false; q.reason=budget.reason
	return q

static func start(state: Dictionary, provinces: Dictionary, faction: String, city: String, kind: String, officer_ref: String, gold: int, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	if state.has("faction_economy"): gold=Economy.balance(state,Economy.resolve(state,faction))
	var q: Dictionary = quote(state,provinces,faction,city,kind,officer_ref,gold,stamp)
	q["gold"]=gold
	if not q.ok: return q
	var d: Dictionary = ensure(state)
	var id: String = "domestic:%d" % int(d.next_id)
	var payer: String=Economy.resolve(state,faction)
	if state.has("faction_economy"):
		var paid: Dictionary=Economy.spend(state,provinces,payer,payer,city,COST,0,"domestic",stamp,id+":cost")
		if not paid.ok:
			q.ok=false; q.reason=paid.reason
			return q
	d.next_id=int(d.next_id)+1
	var job: Dictionary = {"id":id,"city_id":city,"kind":kind,"officer_id":q.officer_id,"faction":faction,"accepted_month":stamp,"due_month":q.due_month,
		"status":"pending","cost_paid":COST,"refund":0,"planned_gain":q.gain,"applied_gain":0,"politics":q.person.politics,"intelligence":q.person.intelligence,"efficiency":q.efficiency,"reason":""}
	d.jobs[id]=job
	job["payer_faction_id"]=payer
	Registry.get_person(state.officer_registry,q.officer_id).duties.append({"kind":"domestic","job_id":id,"city_id":city})
	q.gold=gold-COST
	q["job_id"]=id
	return q

static func release(state: Dictionary, job: Dictionary) -> void:
	var p: Dictionary = Registry.get_person(state.officer_registry,job.officer_id)
	if p.is_empty(): return
	p.duties=p.duties.filter(func(d: Variant): return not (d is Dictionary and d.get("job_id","")==job.id))

static func invalid_reason(state: Dictionary, provinces: Dictionary, job: Dictionary) -> String:
	if not provinces.has(job.city_id) or provinces[job.city_id].get("faction","")!=job.faction: return "도시 상실: 환불 없이 중단"
	if not Registry.eligible(state.officer_registry,job.officer_id,provinces,job.city_id): return "담당자 자격 상실: 환불 없이 중단"
	return ""

static func cancel(state: Dictionary, provinces: Dictionary, faction: String, id: String, gold: int, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	if state.has("faction_economy"): gold=Economy.balance(state,Economy.resolve(state,faction))
	var job: Dictionary = ensure(state).jobs.get(id,{})
	if job.is_empty() or job.kind not in ["agriculture","commerce"] or job.status!="pending" or job.faction!=faction: return {"ok":false,"gold":gold,"reason":"취소 가능한 업무가 없습니다."}
	var reason: String = invalid_reason(state,provinces,job)
	if not reason.is_empty():
		job.status="interrupted"; job.reason=reason; job["processed_month"]=stamp; release(state,job)
		return {"ok":false,"gold":gold,"reason":reason}
	if stamp>=int(job.due_month): return {"ok":false,"gold":gold,"reason":"월 진행 전까지만 취소할 수 있습니다."}
	if state.has("faction_economy"):
		var payer: String=str(job.get("payer_faction_id",Economy.resolve(state,job.faction)))
		if payer!=Economy.resolve(state,faction) or not Economy.post(state,payer,int(job.cost_paid),"domestic_refund",stamp,job.city_id,id+":refund"):
			return {"ok":false,"gold":gold,"reason":"비용 부담 국가 또는 환불 기록을 확인하세요."}
	job.status="cancelled"; job.refund=job.cost_paid; job["processed_month"]=stamp; job.reason="정상 취소"
	release(state,job)
	return {"ok":true,"gold":gold+int(job.refund),"reason":"업무 취소 · 금 100 환불"}

static func process(state: Dictionary, provinces: Dictionary, stamp: int) -> Array[String]:
	if Ending.finished(state): return []
	var messages: Array[String]=[]
	for job: Dictionary in ensure(state).jobs.values():
		if job.kind not in ["agriculture","commerce"]: continue
		if job.status!="pending": continue
		var reason: String=invalid_reason(state,provinces,job)
		if reason.is_empty() and stamp<int(job.due_month): continue
		job["processed_month"]=stamp
		if not reason.is_empty(): job.status="interrupted"; job.reason=reason
		else:
			var before: int=int(provinces[job.city_id][job.kind])
			job.applied_gain=maxi(0,mini(int(job.planned_gain),MAX_DEVELOPMENT-before))
			provinces[job.city_id][job.kind]=before+int(job.applied_gain)
			job.status="completed"; job.reason="개발 완료 +%d" % int(job.applied_gain)
		release(state,job)
		messages.append("%s · %s · %s" % [provinces.get(job.city_id,{}).get("name",job.city_id),Registry.view(state.officer_registry,job.officer_id).get("name",job.officer_id),job.reason])
	return messages

static func governor(state: Dictionary, provinces: Dictionary, city: String, stamp: int) -> Dictionary:
	var r: Dictionary=state.get("officer_registry",{})
	var id: String=Registry.governor_id(r,city)
	if Registry.Power.city_factor(state,city)<1: return {"officer_id":id,"multiplier":1.0,"politics":0,"reason":"권력 인계 차질: 태수 보너스 중단"}
	if not Registry.eligible(r,id,provinces,city): return {"officer_id":"","multiplier":1.0,"politics":0}
	var p: Dictionary=Registry.view(r,id)
	if int(p.get("external_action_month",-1))>=stamp: return {"officer_id":"","multiplier":1.0,"politics":0}
	return {"officer_id":id,"politics":p.politics,"multiplier":1.0+clampf(float(p.politics),0,100)/GOVERNOR_DIVISOR}
