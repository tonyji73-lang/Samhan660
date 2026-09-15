extends RefCounted
const Power=preload("res://noble_power_constraints.gd")
const Ending=preload("res://campaign_ending.gd")
const Economy=preload("res://faction_economy.gd")
const Registry=preload("res://officer_registry.gd")
const Industry=preload("res://industry_assignment.gd")
const Domestic=preload("res://domestic_assignment.gd")
const RULES={"bundle_persons":100,"training_limit":1000,"target":70,"base_gain":5,"cost_per_100":5,"recruit_training":50,"ai_reserve_gold":300,"ai_defense_fraction":0.5}

static func units(state: Dictionary) -> Dictionary: return state.get("unit_rosters",{})
static func create(state: Dictionary, faction: String, city: String, troop_count: int, kind: String="infantry", level: int=50, equipment: int=0, origin: String="", reason: String="external_support") -> Dictionary:
	if Ending.finished(state): return {}
	var id: String="unit:%d" % int(state.army.next_id); state.army.next_id=int(state.army.next_id)+1
	var u: Dictionary={"id":id,"creation_reason":reason,"faction_id":faction,"location":city,"kind":kind,"troops":troop_count,"training_points":troop_count*level,"equipment":equipment,"commander_id":"","origins":{origin if not origin.is_empty() else city:troop_count},"status":"stationed","transfer_id":"","power":50}
	state.unit_rosters[id]=u; return u

static func initialize(state: Dictionary, provinces: Dictionary, transfers: Array, definitions: Dictionary={}) -> void:
	if state.has("army"):
		sync(state,provinces); return
	var old: Dictionary=state.get("unit_rosters",{}).duplicate(true)
	state["army"]={"version":1,"next_id":1,"history":[],"migration":[],"legacy_archive":old,"ai_months":{},"ai_log":[],"battles":[]}
	state.unit_rosters={}
	var cities: Array=provinces.keys(); cities.sort()
	for city: String in cities:
		var target: int=maxi(0,int(provinces[city].get("troops",0)))
		var roster: Dictionary=old.get(city,{})
		var total: int=0
		for row: Dictionary in roster.values(): total+=maxi(0,int(row.get("troops",0)))
		var left: int=target
		var kinds: Array=roster.keys(); kinds.sort(); kinds.erase("infantry"); kinds.append("infantry")
		for kind: String in kinds:
			var row: Dictionary=roster.get(kind,{})
			var troop_count: int=left if kind=="infantry" else mini(left,maxi(0,int(row.get("troops",0))))
			if troop_count<=0: continue
			var u: Dictionary=create(state,Economy.resolve(state,str(provinces[city].get("faction",""))),city,troop_count,kind,clampi(int(row.get("training",50)),0,100),maxi(0,int(row.get("equipment",troop_count))),city)
			u["creation_reason"]="scenario_or_legacy_no_retroactive_charge"; u["legacy_faction"]=str(provinces[city].get("faction","")); u.power=int(row.get("power",definitions.get(kind,{}).get("power",50))); u["legacy_fields"]=row.duplicate(true)
			if row.get("origins") is Dictionary:
				var recorded: int=0
				for value: Variant in row.origins.values(): recorded+=maxi(0,int(value))
				if recorded==troop_count: u.origins=row.origins.duplicate(true)
				else: state.army.migration.append({"unit_id":u.id,"original_origins":row.origins.duplicate(true),"policy":"conflicting count archived; stationed city estimate"})
			u["origin_basis"]="existing origins if count matches; otherwise legacy stationed city"
			left-=troop_count
		if total!=target: state.army.migration.append({"city_id":city,"saved_city":target,"saved_roster":total,"policy":"city actual count; preserve non-infantry first, original archived"})
	for order: Dictionary in transfers:
		var transfer_count: int=maxi(0,int(order.get("troops",0)))
		if transfer_count>0 and not order.has("unit_ids"):
			var u: Dictionary=create(state,Economy.resolve(state,str(order.get("faction",""))),"",transfer_count,"infantry",50,transfer_count,str(order.get("source_id","")))
			u["creation_reason"]="legacy_transfer_no_retroactive_charge"; u["origin_basis"]="legacy transfer source_id"; u.status="transit"; order["unit_ids"]=[u.id]
	sync(state,provinces)

static func at_city(state: Dictionary, city: String, faction: String="", attack: bool=false) -> Array:
	var result: Array=[]
	for u: Dictionary in units(state).values():
		if int(u.troops)<=0 or u.location!=city or u.status!="stationed" or (not faction.is_empty() and u.faction_id!=faction): continue
		if attack and not training_job(state,u.id).is_empty(): continue
		result.append(u.id)
	result.sort(); return result
static func attack_units(state: Dictionary, city: String, faction: String="") -> Array:
	return at_city(state,city,faction,true).filter(func(id): return Power.unit_reason(state,id).is_empty())
static func count(state: Dictionary, ids: Array) -> int:
	var result: int=0
	for id: String in ids: result+=int(units(state)[id].troops)
	return result
static func sync(state: Dictionary, provinces: Dictionary) -> void:
	if not state.has("army"): return
	for city: String in provinces: provinces[city].troops=count(state,at_city(state,city))
static func training(u: Dictionary) -> float: return float(u.training_points)/maxi(1,int(u.troops))
static func ratio(u: Dictionary) -> float: return clampf(float(u.equipment)/maxi(1,int(u.troops)),0,1)
static func projection(state: Dictionary, city: String) -> Dictionary:
	var result: Dictionary={}
	for id: String in at_city(state,city):
		var u: Dictionary=units(state)[id]; var kind: String=u.kind
		if not result.has(kind): result[kind]={"troops":0,"training_points":0,"equipment":0,"name":kind,"category":kind,"power":u.power}
		result[kind].troops+=int(u.troops); result[kind].training_points+=int(u.training_points); result[kind].equipment+=int(u.equipment)
	for row: Dictionary in result.values(): row["training"]=training(row)
	return result
static func check_unit(state: Dictionary, provinces: Dictionary, actor: String, id: String) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var u: Dictionary=units(state).get(id,{})
	if u.is_empty() or u.faction_id!=actor or int(u.troops)<=0 or u.status!="stationed": return {"ok":false,"reason":"현재 아군 주둔 부대가 아닙니다."}
	return Economy.validate(state,provinces,actor,actor,str(u.location))
static func training_job(state: Dictionary, id: String) -> Dictionary:
	for job: Dictionary in Domestic.ensure(state).jobs.values():
		if job.kind=="training" and job.get("unit_id","")==id and job.status=="pending": return job
	return {}
static func divide(state: Dictionary, id: String, amount: int) -> String:
	if Ending.finished(state): return ""
	var u: Dictionary=units(state)[id]
	if amount==int(u.troops): return id
	if amount<=0 or amount>=int(u.troops): return ""
	var before: int=int(u.troops)
	var v: Dictionary=create(state,u.faction_id,u.location,amount,u.kind,0,0)
	v.commander_id=u.commander_id; Power.inherit(state,id,v.id)
	v["creation_reason"]="split"; v["parent_unit_id"]=id; v.power=u.power; v.status=u.status; v.origins={}
	# Truncate the transferred share; leave the remainder in the original unit.
	for field: String in ["training_points","equipment"]:
		v[field]=int(float(int(u[field])*amount)/before); u[field]=int(u[field])-int(v[field])
	var left: int=amount
	var origins: Array=u.origins.keys(); origins.sort()
	for n: int in range(origins.size()):
		var key: String=origins[n]; var allocated: int=mini(int(u.origins[key]),left) if n==origins.size()-1 else mini(left,int(float(int(u.origins[key])*amount)/before))
		v.origins[key]=allocated; u.origins[key]=int(u.origins[key])-allocated; left-=allocated
	# Any rounding remainder comes from remaining origins in stable order.
	for key: String in origins:
		var extra: int=mini(left,int(u.origins[key])); v.origins[key]=int(v.origins.get(key,0))+extra; u.origins[key]-=extra; left-=extra
	u.troops=before-amount; return v.id
static func split(state: Dictionary, provinces: Dictionary, actor: String, id: String, amount: int) -> Dictionary:
	var q: Dictionary=check_unit(state,provinces,actor,id)
	if not q.ok: return q
	if not training_job(state,id).is_empty(): return {"ok":false,"reason":"훈련을 먼저 중지하세요."}
	if not Power.formation_reason(state,id).is_empty(): return {"ok":false,"reason":Power.formation_reason(state,id)}
	var new_id: String=divide(state,id,amount)
	return {"ok":not new_id.is_empty(),"unit_id":new_id,"reason":"인원을 확인하세요." if new_id.is_empty() else ""}
static func merge(state: Dictionary, provinces: Dictionary, actor: String, target: String, source: String) -> Dictionary:
	for id: String in [target,source]:
		var q: Dictionary=check_unit(state,provinces,actor,id)
		if not q.ok: return q
	var a: Dictionary=units(state)[target]; var b: Dictionary=units(state)[source]
	if target==source or a.location!=b.location or a.kind!=b.kind or not training_job(state,target).is_empty() or not training_job(state,source).is_empty(): return {"ok":false,"reason":"같은 도시·병종의 훈련 중이 아닌 서로 다른 부대만 합류 가능합니다."}
	var context: Node=Power.live(state.officer_registry)
	if context!=null and not Power.applying:
		var gate: Dictionary=Power.intercept(context,{"kind":"merge","target":target,"source":source,"faction_id":actor})
		if not gate.ok: return gate
	for uid: String in [target,source]:
		if not Power.applying and not Power.formation_reason(state,uid).is_empty(): return {"ok":false,"reason":Power.formation_reason(state,uid)}
	var target_effect: Dictionary=Power.records(state).get("units",{}).get(target,{})
	var source_effect: Dictionary=Power.records(state).get("units",{}).get(source,{})
	if int(source_effect.get("remaining",0))>int(target_effect.get("remaining",0)) or (int(source_effect.get("remaining",0))==int(target_effect.get("remaining",0)) and int(source_effect.get("created_month",-1))>int(target_effect.get("created_month",-1))): Power.inherit(state,source,target)
	for field: String in ["troops","training_points","equipment"]: a[field]=int(a[field])+int(b[field]); b[field]=0
	for city: String in b.origins: a.origins[city]=int(a.origins.get(city,0))+int(b.origins[city])
	b.origins={}; b.status="merged"; b.commander_id=""; state.army.history.append({"action":"merge","source":source,"target":target})
	return {"ok":true,"reason":"합류 완료"}
static func equip_quote(state: Dictionary, provinces: Dictionary, actor: String, id: String, bundles: int) -> Dictionary:
	var q: Dictionary=check_unit(state,provinces,actor,id)
	if not q.ok: return q
	var u: Dictionary=units(state)[id]; var needed: int=ceili(float(maxi(0,int(u.troops)-int(u.equipment)))/int(RULES.bundle_persons))
	if u.kind!="infantry" or bundles<=0 or bundles>needed: return {"ok":false,"reason":"일반 보병의 부족 장비만 묶음 단위로 지급하세요."}
	if int(state.get("city_inventory",{}).get(u.location,{}).get("sword",0))<bundles: return {"ok":false,"reason":"이 도시 창고의 무기 묶음이 부족합니다."}
	return {"ok":true,"reason":"","bundles":bundles,"persons":bundles*int(RULES.bundle_persons)}
static func equip(state: Dictionary, provinces: Dictionary, actor: String, id: String, bundles: int, stamp: int) -> Dictionary:
	var q: Dictionary=equip_quote(state,provinces,actor,id,bundles)
	if not q.ok: return q
	var u: Dictionary=units(state)[id]; state.city_inventory[u.location].sword-=bundles; u.equipment=int(u.equipment)+int(q.persons)
	state.army.history.append({"action":"equipment_issue","unit_id":id,"city_id":u.location,"faction_id":actor,"bundles":bundles,"persons":q.persons,"month":stamp}); return q
static func appoint(state: Dictionary, provinces: Dictionary, actor: String, id: String, officer: String) -> Dictionary:
	var original: String=officer
	officer=Registry.resolve(state.officer_registry,officer)
	if not original.is_empty() and officer.is_empty(): return {"ok":false,"reason":"식별되지 않은 지휘관입니다."}
	var q: Dictionary=check_unit(state,provinces,actor,id)
	if not q.ok: return q
	var u: Dictionary=units(state)[id]
	if not officer.is_empty() and (not Registry.eligible(state.officer_registry,officer,provinces,u.location) or Registry.get_person(state.officer_registry,officer).faction_id!=actor): return {"ok":false,"reason":"같은 도시의 활동 가능한 아군 지휘관이 필요합니다."}
	if not officer.is_empty() and not Registry.action_available(state.officer_registry,officer,provinces,"attack",u.location): return {"ok":false,"reason":"이동·사절·진행 업무를 먼저 정리하세요."}
	if str(u.commander_id)==officer: return {"ok":true,"reason":"동일 지휘관 · 추가 인사 효과 없음"}
	var context: Node=Power.live(state.officer_registry)
	if context!=null and not Power.applying:
		var gate: Dictionary=Power.intercept(context,{"kind":"commander","target":id,"officer_id":officer,"faction_id":actor})
		if not gate.ok: return gate
	var previous: String=str(u.commander_id)
	var commanded_before: int=Registry.Politics.commanded(state,officer)
	for other: Dictionary in units(state).values():
		if not officer.is_empty() and other.commander_id==officer: other.commander_id=""
	u.commander_id=officer
	Registry.Politics.reaction(state.officer_registry,previous,officer,Registry.Politics.commanded(state,officer)>commanded_before,"지휘관 인사",int(state.officer_registry.get("clock_month",0)))
	return {"ok":true,"reason":"지휘관 갱신"}
static func training_quote(state: Dictionary, provinces: Dictionary, actor: String, id: String, officer: String, stamp: int) -> Dictionary:
	var q: Dictionary=check_unit(state,provinces,actor,id)
	if not q.ok: return q
	var u: Dictionary=units(state)[id]; var job: Dictionary=training_job(state,id)
	var reason: String=Industry.staff_reason(state,provinces,actor,u.location,officer,stamp,str(job.get("id","")))
	var person: Dictionary=Registry.view(state.officer_registry,officer)
	var efficiency: int=clampi(roundi(float(person.get("leadership",0))*0.7+float(person.get("war",0))*0.3),0,100)
	var gain: int=int(RULES.base_gain)+int(efficiency/10.0)
	var fee: int=ceili(float(u.troops)/100.0)*int(RULES.cost_per_100)
	if u.kind!="infantry" or int(u.troops)>int(RULES.training_limit): reason="일반 보병 1~1,000명을 편성하세요."
	elif training(u)>=int(RULES.target): reason="훈련 목표 이상입니다. 기존 훈련도는 유지합니다."
	elif Economy.balance(state,actor)<fee: reason="국고 부족 · 유료 훈련 보류"
	elif bool(provinces[u.location].get("food_shortage",false)): reason="주둔군 군량 유지 실패 · 훈련 보류"
	elif int(state.faction_economy.phase_months.get("upkeep",-1))!=stamp and int(provinces[u.location].food_stock)<int(float(provinces[u.location].troops)/100.0): reason="주둔군 군량 부족 · 훈련 보류"
	if not Power.unit_reason(state,id).is_empty(): reason=Power.unit_reason(state,id)
	return {"ok":reason.is_empty(),"reason":reason,"efficiency":efficiency,"gain":gain,"cost":fee,"next_training":minf(float(RULES.target),training(u)+gain)}
static func train(state: Dictionary, provinces: Dictionary, actor: String, id: String, officer: String, stamp: int) -> Dictionary:
	officer=Registry.resolve(state.officer_registry,officer)
	var q: Dictionary=training_quote(state,provinces,actor,id,officer,stamp)
	if not q.ok: return q
	var u: Dictionary=units(state)[id]; var job: Dictionary=training_job(state,id)
	if job.is_empty():
		var db: Dictionary=Domestic.ensure(state); var key: String="training:%d" % int(db.next_id); db.next_id+=1
		job={"id":key,"kind":"training","unit_id":id,"city_id":u.location,"faction_id":actor,"officer_id":"","status":"pending","reason":"","last_month":stamp,"cost_paid":0,"history":[]}; db.jobs[key]=job
	Domestic.release(state,job); job.officer_id=officer; job.reason=""; job.last_month=maxi(stamp,int(job.last_month))
	Registry.get_person(state.officer_registry,officer).duties.append({"kind":"training","job_id":job.id,"city_id":u.location})
	return q
static func stop(state: Dictionary, id: String, reason: String="훈련 중지") -> void:
	if Ending.finished(state): return
	var job: Dictionary=training_job(state,id)
	if job.is_empty(): return
	Domestic.release(state,job); job.status="stopped"; job.reason=reason
static func process(state: Dictionary, provinces: Dictionary, stamp: int) -> void:
	if Ending.finished(state): return
	for u: Dictionary in units(state).values():
		if u.status!="transit" and not str(u.commander_id).is_empty() and (not Registry.eligible(state.officer_registry,u.commander_id,provinces,u.location) or Registry.get_person(state.officer_registry,u.commander_id).faction_id!=u.faction_id): u.commander_id=""
		var job: Dictionary=training_job(state,u.id)
		if job.is_empty() or stamp<=int(job.last_month): continue
		job.last_month=stamp
		var q: Dictionary=training_quote(state,provinces,u.faction_id,u.id,job.officer_id,stamp)
		if not q.ok:
			job.reason=q.reason
			if not check_unit(state,provinces,u.faction_id,u.id).ok or not Registry.eligible(state.officer_registry,job.officer_id,provinces,u.location): stop(state,u.id,q.reason)
			continue
		var paid: Dictionary=Economy.spend(state,provinces,u.faction_id,u.faction_id,u.location,q.cost,0,"training",stamp,job.id+":"+str(stamp))
		if not paid.ok: job.reason=paid.reason; continue
		var old: int=u.training_points; u.training_points=mini(int(u.troops)*int(RULES.target),old+int(u.troops)*int(q.gain)); job.cost_paid+=q.cost; job.reason=""
		job.history.append({"month":stamp,"cost":q.cost,"officer_id":job.officer_id,"before_points":old,"after_points":u.training_points})
		if training(u)>=int(RULES.target): Domestic.release(state,job); job.status="completed"
static func casualties(state: Dictionary, ids: Array, losses: int, stamp: int) -> void:
	if Ending.finished(state): return
	var left: int=clampi(losses,0,count(state,ids)); var remaining: int=count(state,ids)
	for id: String in ids:
		var u: Dictionary=units(state)[id]; var old: int=u.troops
		if old<=0: continue
		var lost: int=mini(old,left) if old==remaining else mini(left,int(float(left*old)/remaining))
		var equipment_lost: int=int(u.equipment) if lost==old else ceili(float(u.equipment)*lost/old)
		var part: String=divide(state,id,lost) if lost>0 and lost<old else id
		if lost>0:
			var dead: Dictionary=units(state)[part]
			if part!=id:
				var extra: int=equipment_lost-int(dead.equipment); u.equipment-=extra; dead.equipment+=extra
			state.army.history.append({"action":"casualties","unit_id":id,"troops":lost,"equipment_lost":dead.equipment,"origins":dead.origins.duplicate(true),"month":stamp})
			stop(state,part,"부대 전멸"); dead.troops=0; dead.training_points=0; dead.equipment=0; dead.origins={}; dead.status="destroyed"; dead.commander_id=""
		left-=lost; remaining-=old
static func power(state: Dictionary, ids: Array) -> float:
	var result: float=0
	for id: String in ids:
		var u: Dictionary=units(state)[id]
		var factor: float=(0.8+0.2*ratio(u))*(0.8+0.4*training(u)/100.0) if u.kind=="infantry" else 1.0
		result+=int(u.troops)*float(u.power)/50.0*factor
	return result
static func relocate(state: Dictionary, ids: Array, city: String, status: String="stationed") -> void:
	if Ending.finished(state): return
	for id: String in ids:
		var u: Dictionary=units(state)[id]; stop(state,id,"이동·출정으로 훈련 중지"); u.location=city; u.status=status
static func take(state: Dictionary, city: String, amount: int, faction: String, attack: bool=false, excluded: Array=[]) -> Array:
	if Ending.finished(state): return []
	var result: Array=[]; var left: int=amount
	for id: String in at_city(state,city,faction,attack):
		if excluded.has(id): continue
		if left<=0: break
		var n: int=mini(left,int(units(state)[id].troops)); var part: String=divide(state,id,n); result.append(part); left-=n
	return result
static func combat(state: Dictionary, provinces: Dictionary, source: String, target: String, attack_leadership: int, defend_leadership: int, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var faction: String=Economy.resolve(state,str(provinces[source].faction))
	var attackers: Array=attack_units(state,source,faction); var defenders: Array=at_city(state,target)
	if attackers.is_empty(): return {"ok":false,"executed":false,"won":false,"reason":"출정 가능한 부대가 없습니다.","messages":[],"gold_spent":0}
	var attacker_state: Array=[]; var defender_state: Array=[]
	for id: String in attackers: attacker_state.append(units(state)[id].duplicate(true))
	for id: String in defenders: defender_state.append(units(state)[id].duplicate(true))
	var a: int=count(state,attackers); var d: int=count(state,defenders)
	var ap: float=power(state,attackers)*(1+attack_leadership/100.0)
	var dp: float=power(state,defenders)*(1+defend_leadership/100.0+int(provinces[target].fortress)/200.0)
	var won: bool=a>0 and ap>dp
	var al: int=mini(a,maxi(0,mini(maxi(0,a-1),maxi(1000,int(d*0.55))))) if won else mini(a,maxi(1000,int(a*0.45)))
	var dl: int=d if won else mini(d,maxi(500,int(a*0.2)))
	casualties(state,attackers,al,stamp); casualties(state,defenders,dl,stamp)
	if won:
		var survivors: int=a-al; var garrison: int=floori(survivors*0.35)
		var excluded: Array=at_city(state,source,faction).filter(func(uid): return not attackers.has(uid))
		var occupying: Array=take(state,source,survivors-garrison,faction,true,excluded); relocate(state,occupying,target)
		provinces[target].faction=provinces[source].faction
	sync(state,provinces)
	var result: Dictionary={"attacker_troops":a,"defender_troops":d,"attacker_power":ap,"defender_power":dp,"attacker_losses":al,"defender_losses":dl,"won":won,"source":source,"target":target,"month":stamp,"attack_units":attackers,"defend_units":defenders,"attacker_state":attacker_state,"defender_state":defender_state,"attacker_leadership":attack_leadership,"defender_leadership":defend_leadership,"fortress":int(provinces[target].fortress)}
	state.army.battles.append(result.duplicate(true)); return result
static func ai(state: Dictionary, provinces: Dictionary, faction: String, stamp: int, recruitment_reserve: int=0) -> void:
	if Ending.finished(state): return
	if int(state.army.ai_months.get(faction,-1))>=stamp: return
	state.army.ai_months[faction]=stamp
	var trained: bool=false
	for city: String in Economy.city_ids(state,provinces):
		if Economy.resolve(state,str(provinces[city].faction))!=faction: continue
		for id: String in at_city(state,city,faction):
			var u: Dictionary=units(state)[id]
			if u.kind!="infantry": continue
			var bundles: int=mini(int(state.city_inventory[city].sword),ceili(float(maxi(0,int(u.troops)-int(u.equipment)))/100.0))
			if bundles>0: equip(state,provinces,faction,id,bundles,stamp)
			if trained or training(u)>=int(RULES.target) or not training_job(state,id).is_empty() or Economy.balance(state,faction)<int(RULES.ai_reserve_gold)+recruitment_reserve+50 or bool(provinces[city].get("food_shortage",false)): continue
			var size: int=mini(1000,int(u.troops)); if count(state,at_city(state,city,faction,true))-size<ceili(count(state,at_city(state,city,faction))*float(RULES.ai_defense_fraction)): continue
			for officer: String in state.officer_registry.people:
				if not Industry.staff_reason(state,provinces,faction,city,officer,stamp).is_empty(): continue
				var part: String=divide(state,id,size); var q: Dictionary=train(state,provinces,faction,part,officer,stamp)
				state.army.ai_log.append({"month":stamp,"faction_id":faction,"unit_id":part,"result":q}); trained=q.ok; break
			if trained: continue

static func change_faction(state: Dictionary, provinces: Dictionary, actor: String, id: String, new_faction: String, city: String, stamp: int) -> Dictionary:
	var q: Dictionary=check_unit(state,provinces,actor,id)
	if not q.ok: return q
	q=Economy.validate(state,provinces,new_faction,new_faction,city)
	if not q.ok: return q
	var u: Dictionary=units(state)[id]
	stop(state,id,"소속 변경"); u.faction_id=new_faction; u.location=city; u.commander_id=""
	state.army.history.append({"action":"faction_change","unit_id":id,"previous_id":actor,"new_id":new_faction,"city_id":city,"month":stamp})
	sync(state,provinces); return {"ok":true,"reason":"소속 변경; 모집 출신 보존"}