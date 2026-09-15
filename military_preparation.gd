extends RefCounted
const Army=preload("res://army_readiness.gd")
const Industry=preload("res://industry_assignment.gd")
const Economy=preload("res://faction_economy.gd")
const POLICY={"extra_cohorts":3,"garrison":3000,"reserve_gold":300}
static func ids(plan: Dictionary) -> Array:
 var result: Array=[str(plan.get("cohort",""))]
 for item: Dictionary in plan.get("preparation",[]): result.append(str(item.unit_id))
 return result
static func run(c: Node, faction: String, plan: Dictionary, borders: Array, actions: Array) -> void:
 if c.Ending.finished(c.strategy_state): return
 var s: Dictionary=c.strategy_state; var stamp: int=c.year*12+c.month
 if not plan.has("preparation"): plan.preparation=[]
 var queue: Array=plan.preparation; var cities: Array=c.MilitaryPlanning.owned(c,faction)
 for item: Dictionary in queue.duplicate():
  var u: Dictionary=Army.units(s).get(str(item.unit_id),{})
  if u.is_empty() or int(u.troops)<=0 or u.faction_id!=faction: queue.erase(item); continue
  if not cities.has(str(item.target)): item.target=plan.front
  item["equipment"]=int(u.equipment); item["troops"]=int(u.troops); item["training"]=Army.training(u)
  if u.status=="transit": item.reason="이동 중 · 다음 구간 도착 대기"; item.stage="transit"; continue
  var job: Dictionary=Army.training_job(s,u.id)
  if not job.is_empty():
   var q: Dictionary=Army.training_quote(s,c.provinces,faction,u.id,job.officer_id,stamp)
   item.stage="training"; item.reason=str(q.reason); item.officer_id=job.officer_id
   item["months_remaining"]=ceili(maxf(0,70-Army.training(u))/maxi(1,int(q.get("gain",5))))
   continue
  if Army.training(u)>=70 and Army.ratio(u)>=1:
   if u.location==item.target:
    plan.completed.append({"unit_id":u.id,"month":stamp,"troops":u.troops,"creation_reason":u.get("creation_reason",""),"parallel":true})
    actions.append({"action":"front_ready","unit_id":u.id,"city":u.location}); queue.erase(item); continue
   var move: Dictionary=c.MilitaryPlanning.transfer(c,faction,u.id,item.target)
   actions.append({"action":"deploy","unit_id":u.id,"result":move}); item.stage="transit" if move.ok else "movement_wait"; item.reason=move.get("reason",""); continue
  var staff: Array=c.MilitaryPlanning.staff(c,faction,u.location)
  if Army.training(u)<70 and not staff.is_empty():
   var result: Dictionary=Army.train(s,c.provinces,faction,u.id,staff[0],stamp)
   actions.append({"action":"training","unit_id":u.id,"result":result}); item.stage="training" if result.ok else "training_wait"; item.reason=result.reason
  elif Army.training(u)<70:
   item.stage="training_wait"; item.reason="담당자 부족 · 기존 업무 완료/이동 대기"
   # Bring a genuinely spare, unposted worker through the normal officer transfer.
   var pending: bool=false
   var assigned: String=str(item.get("trainer_id",""))
   if not assigned.is_empty():
    var person: Dictionary=c.get_officer(assigned)
    if person.is_empty() or not person.get("alive",true) or person.get("faction_id","")!=faction: item.trainer_id=""
    else:
     pending=true
     var origin: String=str(person.get("location",""))
     if not origin.is_empty() and origin!=u.location:
      var path: Array=c.MilitaryPlanning.military_route(c,faction,origin,u.location)
      if path.size()>1:
       var moved: Dictionary=c.queue_province_transfer({"source_id":origin,"target_id":path[1],"troops":0,"officer_ids":[assigned]},false,faction)
       actions.append({"action":"trainer_transfer","officer_id":assigned,"result":moved})
   for order: Dictionary in c.pending_transfer_orders:
    if order.target_id==u.location and not order.officer_ids.is_empty(): pending=true
   if not pending:
    for source: String in cities:
     if source==u.location: continue
     var free: Array=c.MilitaryPlanning.staff(c,faction,source)
     if free.size()<2: continue
     var path: Array=c.MilitaryPlanning.military_route(c,faction,source,u.location)
     if path.size()<2: continue
     var person: String=str(free.back())
     if s.officer_registry.posts.values().has(person): continue
     var moved: Dictionary=c.queue_province_transfer({"source_id":source,"target_id":path[1],"troops":0,"officer_ids":[person]},false,faction)
     actions.append({"action":"trainer_transfer","officer_id":person,"result":moved})
     if moved.ok: item.trainer_id=person
     break
  else: item.stage="equipment_wait"; item.reason="훈련 완료 · 실제 무기 도착 대기"
 # Only prepare existing surplus for an actual reachable military objective.
 if borders.is_empty(): return
 for city: String in cities:
  if queue.size()>=int(POLICY.extra_cohorts): break
  if queue.any(func(item): return Army.units(s).get(item.unit_id,{}).get("location","")==city): continue
  if c.MilitaryPlanning.staff(c,faction,city).is_empty(): continue
  var target: String=str(plan.front)
  if c.MilitaryPlanning.military_route(c,faction,city,target).is_empty(): continue
  var local: Array=borders.filter(func(b): return b.city==city)
  if not local.is_empty() and int(local[0].defense_deficit)>0: continue
  var eligible: Array=Army.at_city(s,city,faction,true)
  for excluded: String in ids(plan): eligible.erase(excluded)
  var surplus: int=Army.count(s,eligible)-int(POLICY.garrison)
  if surplus<100: continue
  eligible.sort_custom(func(a,b): return Army.training(s.unit_rosters[a])>Army.training(s.unit_rosters[b]))
  for uid: String in eligible:
   var u: Dictionary=s.unit_rosters[uid]
   if u.kind!="infantry" or Army.training(u)>=70: continue
   var size: int=mini(1000,mini(int(u.troops),surplus))
   if Economy.balance(s,faction)<c.MilitaryPlanning.Network.reserve(c,faction)+ceili(float(size)/100)*5*3: continue
   var split: Dictionary=Army.split(s,c.provinces,faction,uid,size)
   if not split.ok: continue
   var part: String=split.unit_id
   var people: Array=c.MilitaryPlanning.staff(c,faction,city)
   var result: Dictionary=Army.train(s,c.provinces,faction,part,people[0],stamp)
   actions.append({"action":"training","unit_id":part,"result":result})
   queue.append({"unit_id":part,"target":target,"created_month":stamp,"stage":"training" if result.ok else "training_wait","reason":result.reason})
   break
static func text(c: Node,plan: Dictionary) -> String:
 var lines: Array[String]=[]
 var labels: Dictionary={"training":"훈련 진행","training_wait":"훈련 배정 대기","transit":"이동 중","movement_wait":"이동 대기","equipment_wait":"장비 도착 대기"}
 for item: Dictionary in plan.get("preparation",[]):
  var u: Dictionary=Army.units(c.strategy_state).get(str(item.unit_id),{})
  if u.is_empty(): continue
  var remaining: String="조건 해소 후 재산정"
  if item.stage=="training" and int(item.get("months_remaining",0))>0: remaining="현재 담당자 유지 시 약 %d개월" % int(item.months_remaining)
  lines.append("병행 준비 %s · %d명 / 장비%d명분 / 훈련%.1f · %s → %s · %s · %s" % [item.unit_id,int(u.troops),int(u.equipment),Army.training(u),labels.get(item.stage,item.stage),c.provinces.get(str(item.target),{}).get("name",item.target),item.reason,remaining])
 return "\n".join(lines)