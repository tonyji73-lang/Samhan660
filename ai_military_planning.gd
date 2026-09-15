extends RefCounted
const Ending=preload("res://campaign_ending.gd")
const Army=preload("res://army_readiness.gd")
const Economy=preload("res://faction_economy.gd")
const Industry=preload("res://industry_assignment.gd")
const Supply=preload("res://supply_transport.gd")
const Production=preload("res://production_system.gd")
const Registry=preload("res://officer_registry.gd")
const Preparation=preload("res://military_preparation.gd")
const Network=preload("res://military_supply_network.gd")
const POLICY={"reserve_gold":300,"cohort":1000,"interior_garrison":3000,"transfer_limit":5000,"emergency_margin":1.1,"training_window":3,"food_months":3,"old_cohorts_before_new":1}
static func ensure(s: Dictionary) -> Dictionary:
 if not s.has("military_planning"): s.military_planning={"version":1,"months":{},"factions":{},"log":[]}
 return s.military_planning
static func owned(c: Node, faction: String) -> Array:
 var result: Array=[]
 for city: String in Economy.city_ids(c.strategy_state,c.provinces):
  if Economy.resolve(c.strategy_state,c.provinces[city].faction)==faction: result.append(city)
 result.sort(); return result
static func incoming(c: Node, faction: String, city: String) -> int:
 var total: int=0
 for order: Dictionary in c.pending_transfer_orders:
  if order.target_id==city and Economy.resolve(c.strategy_state,str(order.faction))==faction:
   total+=Army.count(c.strategy_state,order.get("unit_ids",[]))
 return total
static func staff(c: Node, faction: String, city: String, job: String="") -> Array:
 var result: Array=[]
 for id: String in c.get_city_officer_ids(city):
  if Industry.staff_reason(c.strategy_state,c.provinces,faction,city,id,c.year*12+c.month,job).is_empty(): result.append(id)
 result.sort_custom(func(a,b):
  var ap: Dictionary=c.get_officer(a); var bp: Dictionary=c.get_officer(b)
  var av: int=int(ap.get("politics",0))+int(ap.get("intelligence",0)); var bv: int=int(bp.get("politics",0))+int(bp.get("intelligence",0))
  return a<b if av==bv else av>bv)
 return result
static func fronts(c: Node, faction: String) -> Array:
 var s: Dictionary=c.strategy_state; var result: Array=[]
 for city: String in owned(c,faction):
  var enemy_power: float=0; var enemy: String=""
  for neighbor: String in c.province_connections.get(city,[]):
   if not c.provinces.has(neighbor) or Economy.resolve(s,c.provinces[neighbor].faction)==faction: continue
   # Historical AI currently attacks only the player. An adjacent AI which
   # cannot attack this faction must not trigger a permanent emergency draft.
   if c.play_style!="fictional" and c._get_province_controller(c.provinces[neighbor])!=c.CONTROLLER_PLAYER: continue
   var power: float=Army.power(s,Army.attack_units(s,neighbor))*(1+float(c.get_best_commander(neighbor,"attack").leadership)/100.0)
   if power>enemy_power: enemy_power=power; enemy=neighbor
  if enemy.is_empty(): continue
  var ids: Array=Army.at_city(s,city,faction)
  var own_power: float=Army.power(s,ids)
  var defense_factor: float=1+float(c.get_best_commander(city).leadership)/100.0+float(c.provinces[city].fortress)/200.0
  var inbound: int=incoming(c,faction,city)
  var deficit: int=maxi(0,ceili(enemy_power/defense_factor-own_power-inbound))
  var target: String=c.find_ai_target(city)
  var attack_need: int=0
  if not target.is_empty():
   var enemy_ids: Array=Army.at_city(s,target)
   var enemy_defense: float=Army.power(s,enemy_ids)*(1+float(c.get_best_commander(target).leadership)/100.0+float(c.provinces[target].fortress)/200.0)
   var attack_factor: float=(1+float(c.get_best_commander(city,"attack").leadership)/100.0)*maxf(0.64,own_power/maxi(1,Army.count(s,ids)))
   attack_need=maxi(0,maxi(ceili(enemy_defense*1.1/attack_factor),ceili(int(c.provinces[target].troops)*c.ai_attack_ratio))-Army.count(s,ids)-inbound)
  result.append({"city":city,"enemy":enemy,"target":target,"enemy_power":enemy_power,"defense_power":own_power*defense_factor,"defense_deficit":deficit,"attack_deficit":attack_need,"incoming":inbound,"troops":Army.count(s,ids)})
 result.sort_custom(func(a,b):
  if a.defense_deficit!=b.defense_deficit: return a.defense_deficit>b.defense_deficit
  if a.target.is_empty()!=b.target.is_empty(): return not a.target.is_empty()
  if a.attack_deficit!=b.attack_deficit: return a.attack_deficit<b.attack_deficit
  return a.city<b.city)
 return result
static func military_route(c: Node, faction: String, source: String, target: String) -> Array:
 # The existing troop movement graph, including its existing sea links.
 var queue: Array=[[source]]; var visited: Dictionary={source:true}
 while not queue.is_empty():
  var path: Array=queue.pop_front(); var last: String=path.back()
  if last==target: return path
  var neighbors: Array=c.province_connections.get(last,[]).duplicate(); neighbors.sort()
  for next: String in neighbors:
   if visited.has(next) or not c.provinces.has(next) or Economy.resolve(c.strategy_state,c.provinces[next].faction)!=faction: continue
   visited[next]=true; queue.append(path+[next])
 return []
static func choose_hub(c: Node, faction: String, plan: Dictionary) -> String:
 var cities: Array=owned(c,faction)
 if cities.has(str(plan.get("hub",""))): return plan.hub
 var legacy: String=str(c.strategy_state.get("iron_ai",{}).get("hubs",{}).get(faction,""))
 if cities.has(legacy): return legacy
 var best: String=""; var score: int=-1
 for city: String in cities:
  var people: int=c.get_city_officer_ids(city).size()
  var buildings: Dictionary=c.strategy_state.province_buildings[city]
  var value: int=people*100+int(buildings.get("smelter",0))*80+int(buildings.get("forge",0))*80
  if value>score: score=value; best=city
 return best
static func infrastructure(c: Node, faction: String, hub: String, actions: Array, minimum_reserve: int=300, role: String="integrated") -> void:
 var s: Dictionary=c.strategy_state; var stamp: int=c.year*12+c.month
 # Resume paid jobs, never cancel/rebuy or steal a valid worker each month.
 for job: Dictionary in Industry.jobs(s).values():
  if job.get("faction_id","")!=faction or job.kind not in ["build","research"] or job.status!="paused": continue
  var city: String=hub if job.kind=="research" else str(job.city_id)
  if not owned(c,faction).has(city): continue
  var people: Array=staff(c,faction,city,str(job.id))
  if not people.is_empty(): actions.append({"action":"resume","result":Industry.assign(s,c.provinces,faction,job.id,city,people[0],stamp)})
 for request: Array in [["build","smelter"],["research","basic_smelting"],["build","forge"],["research","swordsmithing"]]:
  if role=="iron" and request[1] in ["forge","swordsmithing"]: continue
  if role=="forge" and request[1]=="smelter": continue
  var levels: Dictionary=s.province_buildings[hub] if request[0]=="build" else s.faction_research[s.faction_economy.factions[faction]]
  if int(levels.get(request[1],0))>0 or not Industry.active(s,request[0],hub,faction).is_empty(): continue
  var people: Array=staff(c,faction,hub)
  if people.is_empty(): continue
  var q: Dictionary=Industry.quote(s,c.provinces,c.strategy,faction,hub,request[0],request[1],people[0],stamp,c.scenario_id,c.iron_supply_rules)
  if q.ok and Economy.balance(s,faction)-int(q.gold_cost)>=minimum_reserve:
   actions.append({"action":"infrastructure","request":request,"result":Industry.start(s,c.provinces,c.strategy,faction,hub,request[0],request[1],people[0],stamp,c.scenario_id,c.iron_supply_rules)})
static func forecast(c: Node, faction: String, hub: String) -> Dictionary:
 var s: Dictionary=c.strategy_state; var stamp: int=c.year*12+c.month
 var construction: int=0; var future_cost: int=0; var unresolved: Array=[]
 var people: Array=staff(c,faction,hub)
 var roster: Array=c.get_city_officer_ids(hub)
 var builder: Dictionary={}
 if not roster.is_empty(): builder=c.get_officer(roster[0])
 for request: Array in [["build","smelter"],["research","basic_smelting"],["build","forge"],["research","swordsmithing"]]:
  var kind: String=request[0]; var requirement: String=request[1]
  var levels: Dictionary=s.province_buildings[hub] if kind=="build" else s.faction_research[s.faction_economy.factions[faction]]
  if int(levels.get(requirement,0))>0: continue
  var job: Dictionary=Industry.active(s,kind,hub,faction)
  if not job.is_empty() and job.requirement_id==requirement:
   if job.status=="paused": unresolved.append(str(job.reason)); continue
   construction+=Industry.remaining_months(s,job.city_id,Registry.view(s.officer_registry,job.officer_id),kind,int(job.required)-int(job.progress))
  else:
   var defs: Dictionary=c.strategy.BUILDING_DEFS if kind=="build" else c.strategy.RESEARCH_DEFS
   var definition: Dictionary=defs[requirement]
   if builder.is_empty(): unresolved.append("군수 시설·연구 담당자 없음")
   else: construction+=ceili(float(int(definition.base_turns)*3*100)/Industry.work(builder,kind))
   future_cost+=int(definition.base_gold)
 var inventory: int=Production.get_stock(s,c.provinces,hub,"sword")
 var iron: int=Production.get_stock(s,c.provinces,hub,"iron")
 var work: int=Industry.production_work(s,c.provinces,hub,stamp)
 var production_months: int=ceili(float(int(POLICY.cohort)/100*100)/work)
 var training_months: int=int(POLICY.training_window)
 if not builder.is_empty():
  var gain: int=5+floori(roundi(float(builder.get("leadership",0))*0.7+float(builder.get("war",0))*0.3)/10.0)
  training_months=ceili(float(70-Army.RULES.recruit_training)/gain)
 var path: Array=military_route(c,faction,hub,str(s.military_planning.factions[faction].get("front",hub)))
 var travel: int=maxi(0,path.size()-1)
 var horizon: int=construction+production_months+training_months+travel+1
 var freight: int=Supply.incoming(s,c.provinces,faction,hub,"sword",stamp+horizon,stamp)
 var ready: bool=construction==0 and unresolved.is_empty()
 var batches: int=0; var operating: int=int(Production.Data.RECIPES.iron_procurement.operating_gold)+int(Production.Data.RECIPES.iron_sword.operating_gold)
 var supply_recipe: String="iron_procurement"
 if Production.validate_batch(s,c.provinces,hub,"iron_supply",s.faction_economy.factions[faction],Economy.balance(s,faction),c.scenario_id,c.iron_supply_rules).ok:
  operating=int(Production.Data.RECIPES.iron_supply.operating_gold)+int(Production.Data.RECIPES.iron_sword.operating_gold); supply_recipe="iron_supply"
 # This bounded future is CONDITIONAL, never recruited against or copied to stock.
 # Both facilities spend full recipe inputs; accepted jobs' paid gold is not charged again.
 var enabled: bool=bool(s.city_production[hub].get("iron_sword",{}).get("enabled",false))
 var input_available: bool=iron>=2 or bool(s.city_production[hub].iron_supply.enabled) or bool(s.city_production[hub].iron_procurement.enabled) or Supply.incoming(s,c.provinces,faction,hub,"iron",stamp+horizon,stamp)>=2
 if ready and enabled and input_available and int(c.provinces[hub].food_stock)>=Supply.upkeep(c.provinces[hub])*int(POLICY.food_months):
  batches=mini(floori(float(work)*production_months/100),maxi(0,(Economy.balance(s,faction)-int(POLICY.reserve_gold))/operating))
 return {"stock_bundles":inventory,"iron_units":iron,"incoming_bundles":freight,"conditional_future_bundles":batches,"facilities_ready":ready,"infrastructure_remaining":construction,"unresolved":unresolved,"horizon":horizon,"production_months":production_months,"training_months":training_months,"travel_months":travel,"unpaid_infrastructure_gold":future_cost,"gold_per_bundle":operating,"supply_recipe":supply_recipe,"training_staff_now":people.size(),"production_work":work,"reason":"군수 시설 준비 · 직렬 보수적 예상(병렬 완료 시 단축)" if not ready else "현재 재고만 배정 · 미래 생산은 가동·원료·국고 유지 조건부"}
static func transfer(c: Node, faction: String, unit: String, target: String) -> Dictionary:
 var u: Dictionary=Army.units(c.strategy_state).get(unit,{})
 if u.is_empty() or u.status!="stationed": return {"ok":false,"reason":"이동 중 또는 소실된 부대"}
 var path: Array=military_route(c,faction,str(u.location),target)
 if path.size()<2: return {"ok":false,"reason":"수송 경로 단절 또는 이미 전선 도착"}
 return c.queue_province_transfer({"source_id":u.location,"target_id":path[1],"troops":int(u.troops),"unit_ids":[unit],"officer_ids":[]},false,faction)
static func run(c: Node, faction: String, planned_attacks: Dictionary={}) -> Array[String]:
 var s: Dictionary=c.strategy_state
 if Ending.finished(s): return []
 var db: Dictionary=ensure(s); var stamp: int=c.year*12+c.month
 if int(db.months.get(faction,-1))>=stamp: return []
 db.months[faction]=stamp
 var cities: Array=owned(c,faction)
 if cities.is_empty(): return []
 var plan: Dictionary=db.factions.get(faction,{"cohort":"","cycles":0,"completed":[],"reason":""})
 db.factions[faction]=plan
 plan.hub=choose_hub(c,faction,plan)
 var hub: String=plan.hub; var actions: Array=[]; var borders: Array=fronts(c,faction)
 var reachable: Array=borders.filter(func(row): return not military_route(c,faction,hub,row.city).is_empty())
 var target: String=str(reachable[0].city) if not reachable.is_empty() else hub
 for row: Dictionary in reachable:
  if row.city==plan.get("front","") and maxi(int(row.defense_deficit),int(row.attack_deficit))>=100: target=row.city; break
 var demand: Dictionary={"defense_deficit":0,"attack_deficit":0}
 for row: Dictionary in borders:
  if row.city==target: demand=row; break
 plan["front"]=target; plan["demand"]=borders
 var messages: Array[String]=Supply.ai(s,c.provinces,faction,stamp,0,planned_attacks,c.scenario_id,c.iron_supply_rules)
 # Limited emergency draft: confirmed adjacent strength, remaining deficit,
 # existing support, and actual common population/cash/local-grain constraints.
 for border: Dictionary in borders:
  if float(border.enemy_power)<=float(border.defense_power)*float(POLICY.emergency_margin) or int(border.defense_deficit)<100: continue
  var wanted: int=mini(int(border.defense_deficit),int(c.ai_recruitment_amount))
  var amount: int=c.Mobilization.ai_amount(c,faction,border.city,wanted)
  amount=mini(amount,maxi(0,Economy.balance(s,faction)/15)*100)
  if amount>0: actions.append({"action":"emergency_recruit","city":border.city,"deficit":border.defense_deficit,"result":c.recruit_for_faction(faction,border.city,amount)})
  break
 Network.run(c,faction,plan,borders,actions)
 plan["supply"]=forecast(c,faction,hub)
 var id: String=str(plan.cohort); var u: Dictionary=Army.units(s).get(id,{})
 if not u.is_empty() and (int(u.troops)<=0 or u.faction_id!=faction): plan.cohort=""; u={}; plan.reason="전투 손실·소속 변경: 보충 계획 재작성"
 if not u.is_empty() and u.status=="stationed" and Army.training(u)>=70 and Army.ratio(u)>=1 and Army.training_job(s,id).is_empty():
  var destination: String=str(plan.get("destination",target))
  if not cities.has(destination) or military_route(c,faction,u.location,destination).is_empty(): destination=target
  plan["destination"]=destination
  if u.location==destination:
   plan.completed.append({"unit_id":id,"month":stamp,"troops":u.troops,"creation_reason":u.get("creation_reason","")}); plan.cohort=""; plan.cycles=int(plan.cycles)+1; u={}
   actions.append({"action":"front_ready","unit_id":id,"city":target})
  else: actions.append({"action":"deploy","unit_id":id,"result":transfer(c,faction,id,destination)})
 if str(plan.cohort).is_empty():
  var stock: int=Production.get_stock(s,c.provinces,hub,"sword")
  var selected: String=""
  # Alternate one legacy repair/training cohort with a supply-backed new one;
  # never require every legacy soldier to reach 70 first.
  var want_new: bool=int(plan.cycles)%(int(POLICY.old_cohorts_before_new)+1)==int(POLICY.old_cohorts_before_new) and stock>=10 and maxi(int(demand.defense_deficit),int(demand.attack_deficit))>=100
  for repair_city: String in cities:
   if int(plan.cycles)%(int(POLICY.old_cohorts_before_new)+1)==int(POLICY.old_cohorts_before_new): continue
   if staff(c,faction,repair_city).is_empty():
    if staff(c,faction,hub).is_empty() or military_route(c,faction,repair_city,hub).is_empty(): continue
    var exposed: Array=borders.filter(func(row): return row.city==repair_city and row.defense_deficit>0)
    if not exposed.is_empty(): continue
   for repair_id: String in Army.at_city(s,repair_city,faction,true):
    var repair: Dictionary=Army.units(s)[repair_id]
    if repair.kind!="infantry" or Army.ratio(repair)>=1: continue
    var repair_size: int=mini(int(POLICY.cohort),int(repair.troops))
    if Army.count(s,Army.at_city(s,repair_city,faction,true))-repair_size<int(POLICY.interior_garrison): continue
    selected=str(Army.split(s,c.provinces,faction,repair_id,repair_size).get("unit_id","")); break
   if not selected.is_empty(): break
  if selected.is_empty() and want_new and not staff(c,faction,hub).is_empty():
   var needed: int=maxi(int(demand.defense_deficit),int(demand.attack_deficit))
   var amount: int=c.Mobilization.ai_amount(c,faction,hub,mini(int(POLICY.cohort),needed))
   if amount>=100 and Economy.balance(s,faction)>=int(POLICY.reserve_gold)+amount/100*15+ceili(float(amount)/100)*5*int(POLICY.training_window):
    var recruited: Dictionary=c.recruit_for_faction(faction,hub,amount)
    actions.append({"action":"planned_recruit","city":hub,"result":recruited})
    if recruited.ok: selected=recruited.unit_id
  if selected.is_empty():
   for candidate: String in Army.at_city(s,hub,faction,true):
    var existing: Dictionary=Army.units(s)[candidate]
    if existing.kind!="infantry" or Army.training(existing)>=70: continue
    if want_new: break
    var size: int=mini(int(POLICY.cohort),int(existing.troops))
    if Army.count(s,Army.at_city(s,hub,faction,true))-size<int(POLICY.interior_garrison): continue
    if not staff(c,faction,hub).is_empty(): selected=str(Army.split(s,c.provinces,faction,candidate,size).get("unit_id","")); break
  plan.cohort=selected; plan["destination"]=target; id=selected; u=Army.units(s).get(id,{})
 if not u.is_empty() and u.status=="stationed" and Army.training_job(s,id).is_empty() and u.location!=hub and ((Army.training(u)<70 and staff(c,faction,str(u.location)).is_empty()) or (Army.ratio(u)<1 and Supply.route(s,c.provinces,faction,hub,str(u.location)).is_empty())):
  actions.append({"action":"return_to_training","unit_id":id,"result":transfer(c,faction,id,hub)})
 if not u.is_empty() and u.status=="stationed":
  var city: String=u.location
  var need: int=ceili(float(maxi(0,int(u.troops)-int(u.equipment)))/100)
  var stock: int=Production.get_stock(s,c.provinces,city,"sword")
  if need>0 and stock>0: actions.append({"action":"equip","unit_id":id,"result":Army.equip(s,c.provinces,faction,id,mini(need,stock),stamp)})
  if need>stock:
   var can_ship: bool=true
   for order: Dictionary in Supply.ensure(s).orders.values():
    if order.faction_id==faction and int(order.created_month)==stamp: can_ship=false
   if can_ship and Supply.incoming(s,c.provinces,faction,city,"sword",stamp+20,stamp)<need-stock:
    for donor: String in cities:
     var bundles: int=mini(need-stock,Production.get_stock(s,c.provinces,donor,"sword"))
     if donor==city or bundles<=0: continue
     var shipment: Dictionary=Supply.start(s,c.provinces,faction,donor,city,{"sword":bundles},stamp)
     if shipment.ok: actions.append({"action":"weapons_transport","result":shipment}); break
   plan.reason="장비 공급 대기"
  if Army.training(u)<70 and Army.training_job(s,id).is_empty():
   var trainers: Array=staff(c,faction,city)
   plan.reason="훈련 담당자 부족" if trainers.is_empty() else "훈련 접수 검증"
   if not trainers.is_empty():
    var trained: Dictionary=Army.train(s,c.provinces,faction,id,trainers[0],stamp)
    actions.append({"action":"training","unit_id":id,"result":trained}); plan.reason="훈련 접수 · 다음 월 유료 진행" if trained.ok else trained.get("reason","")
  else:
   var job: Dictionary=Army.training_job(s,id)
   plan.reason=str(job.reason) if not job.is_empty() and not str(job.get("reason","" )).is_empty() else "훈련 진행 또는 전선 배치"
 elif not u.is_empty(): plan.reason="전선 지원군 이동 중"
 else: plan.reason="장비·훈련 담당자·동원 한도 대기" if plan.supply.facilities_ready else "군수 시설 준비"
 Preparation.run(c,faction,plan,borders,actions)
 # Move an available reserve through the SAME one-edge transfer command.
 # Ready cohort deployment has priority; leave assessed border defense intact.
 var moved: bool=actions.any(func(a): return a.action in ["deploy","return_to_training"] and a.result.get("ok",false))
 if not borders.is_empty():
  var sources: Array=cities.duplicate()
  sources.sort_custom(func(a,b):
   var ad: int=military_route(c,faction,a,target).size(); var bd: int=military_route(c,faction,b,target).size()
   return a<b if ad==bd else ad<bd)
  for source: String in sources:
   if source==target: continue
   var local: Array=borders.filter(func(row): return row.city==source)
   var units: Array=Army.at_city(s,source,faction,true)
   for excluded: String in Preparation.ids(plan): units.erase(excluded)
   var total: int=Army.count(s,Army.at_city(s,source,faction))
   var keep: int=int(POLICY.interior_garrison)
   if not local.is_empty():
    var defense_per_person: float=float(local[0].defense_power)/maxi(1,total)
    keep=maxi(keep,ceili(float(local[0].enemy_power)*float(POLICY.emergency_margin)/maxf(0.01,defense_per_person)))
   var surplus: int=mini(Army.count(s,units),total-keep)
   var need: int=maxi(int(demand.defense_deficit),int(demand.attack_deficit))
   if surplus<100 or need<100 or military_route(c,faction,source,target).size()<2: continue
   var amount: int=mini(int(POLICY.transfer_limit),mini(surplus,need))
   var path: Array=military_route(c,faction,source,target)
   var moved_result: Dictionary=c.queue_province_transfer({"source_id":source,"target_id":path[1],"troops":amount,"officer_ids":[],"excluded_unit_ids":Preparation.ids(plan)},false,faction)
   actions.append({"action":"reserve_transfer","city":source,"result":moved_result}); break
 var shortage: int=0; var training_wait: int=0; var assigned: int=0
 for unit: Dictionary in Army.units(s).values():
  if unit.faction_id!=faction or int(unit.troops)<=0: continue
  shortage+=maxi(0,int(unit.troops)-int(unit.equipment))
  if Army.training(unit)<70: training_wait+=int(unit.troops)
  if not Army.training_job(s,unit.id).is_empty(): assigned+=int(unit.troops)
 plan["unarmed_people"]=shortage; plan["training_waiting_people"]=training_wait; plan["training_assigned_people"]=assigned
 for action: Dictionary in actions:
  if action.has("result") and not action.result.get("ok",true): plan.reason=str(action.result.get("reason","명령 보류"))
 plan["month"]=stamp; plan["actions"]=actions
 db.log.append({"month":stamp,"faction_id":faction,"hub":hub,"front":target,"supply":plan.supply.duplicate(true),"reason":plan.reason,"actions":actions.duplicate(true),"gold":Economy.balance(s,faction)})
 messages.append("%s 군수 계획: %s · 재고 %d묶음 / 조건부 %d묶음 · %s" % [faction,hub,plan.supply.stock_bundles,plan.supply.conditional_future_bundles,plan.reason])
 return messages

static func text(c: Node) -> String:
 var lines: Array[String]=["국가별 AI 군수·동원 계획", "칼 1묶음 = 보병 100명분. 현재 창고와 조건부 미래 생산을 구분합니다."]
 for faction: String in c.strategy_state.get("military_planning",{}).get("factions",{}):
  var plan: Dictionary=c.strategy_state.military_planning.factions[faction]
  var q: Dictionary=plan.get("supply",{})
  lines.append("\n%s · 국고 %d · 거점 %s → 전선 %s" % [c.strategy_state.faction_economy.factions.get(faction,faction),Economy.balance(c.strategy_state,faction),c.provinces.get(plan.hub,{}).get("name",plan.hub),c.provinces.get(plan.front,{}).get("name",plan.front)])
  lines.append("창고 칼 %d묶음 / 유효 운송 %d묶음 / 조건부 생산 %d묶음 · 예상 범위 %d개월" % [q.get("stock_bundles",0),q.get("incoming_bundles",0),q.get("conditional_future_bundles",0),q.get("horizon",0)])
  lines.append("미장비 %d명 · 훈련70 미만 %d명(기존 기본50 포함) / 배정 %d명 · 준비 도착 %d회" % [plan.get("unarmed_people",0),plan.get("training_waiting_people",0),plan.get("training_assigned_people",0),plan.get("completed",[]).size()])
  var cohort: Dictionary=Army.units(c.strategy_state).get(str(plan.get("cohort","")),{})
  if not cohort.is_empty(): lines.append("현재 준비 부대 %d명 · 장비 %.0f%% / 훈련 %.0f · %s" % [cohort.troops,Army.ratio(cohort)*100,Army.training(cohort),"이동 중" if cohort.status=="transit" else c.provinces.get(str(cohort.location),{}).get("name",cohort.location)])
  lines.append(Network.text(c,faction))
  lines.append(Preparation.text(c,plan))
  lines.append("판단: "+str(plan.get("reason","")))
  var actions: Array=[]
  var labels: Dictionary={"network_transport":"군수망 수송","network_equip":"거점 재고 지급","infrastructure":"시설·연구 접수","resume":"기존 업무 재개","production_manager":"생산 담당 임명","emergency_recruit":"긴급 방어 모집","planned_recruit":"일반 모집","equip":"장비 지급","trainer_transfer":"훈련 담당자 이동","training":"훈련 배정","weapons_transport":"무기 수송","deploy":"전선 이동","return_to_training":"훈련 거점 복귀","reserve_transfer":"예비 병력 지원","front_ready":"전선 준비 완료"}
  for action: Dictionary in plan.get("actions",[]): actions.append(labels.get(action.action,action.action))
  var expense: int=0; var income: int=0
  for receipt: Dictionary in c.strategy_state.faction_economy.entries:
   if receipt.faction_id==faction and int(receipt.month)==int(plan.month):
    expense+=maxi(0,-int(receipt.amount)); income+=maxi(0,int(receipt.amount))
  lines.append("이번 월 국고 수입 %d / 지출 %d" % [income,expense])
  lines.append("이번 월 명령: "+(", ".join(actions) if not actions.is_empty() else "현 작업 유지"))
 return "\n".join(lines)
