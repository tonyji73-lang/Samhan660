extends RefCounted
const Army=preload("res://army_readiness.gd")
const Industry=preload("res://industry_assignment.gd")
const Economy=preload("res://faction_economy.gd")
const Production=preload("res://production_system.gd")
const Supply=preload("res://supply_transport.gd")
const POLICY={"sustained_months":3,"max_sites":3,"buffer_bundles":10,"material_months":2,"maximum_freight":3,"minimum_expansion_people":1000,"reserve_gold":300,"delivery_month_value":6}
static func ensure(plan: Dictionary) -> Dictionary:
 if not plan.has("network"): plan.network={"version":1,"sites":{},"shortage_months":0,"last_month":-1,"history":[],"report":{}}
 return plan.network
static func invalidate(c: Node) -> void:
 if c.Ending.finished(c.strategy_state): return
 for faction: String in c.strategy_state.get("military_planning",{}).get("factions",{}):
  var network: Dictionary=c.strategy_state.military_planning.factions[faction].get("network",{})
  if network.is_empty(): continue
  for city: String in network.sites.keys():
   if c.provinces.has(city) and Supply.owner(c.strategy_state,c.provinces,city)==faction: continue
   network.sites.erase(city)
   network.history.append({"action":"site_lost","month":c.year*12+c.month,"city":city,"reason":"전체 복원/전투 정산 후 소유권 검증: 실제 명령 재실행 없음"})
   network.report={}
static func stock(c: Node, city: String, item: String) -> int: return Production.get_stock(c.strategy_state,c.provinces,city,item)
static func local_need(c: Node, faction: String, city: String) -> int:
 var need: int=0
 for uid: String in Army.at_city(c.strategy_state,city,faction):
  var u: Dictionary=c.strategy_state.unit_rosters[uid]
  if u.kind=="infantry": need+=maxi(0,int(u.troops)-int(u.equipment))
 return ceili(float(need)/100)
static func freight_count(c: Node, faction: String, stamp: int) -> int:
 var count: int=0
 for order: Dictionary in Supply.ensure(c.strategy_state).orders.values():
  if order.faction_id==faction and int(order.created_month)==stamp: count+=1
 return count
static func reserve(c: Node, faction: String) -> int:
 var value: int=int(POLICY.reserve_gold)
 for job: Dictionary in Industry.jobs(c.strategy_state).values():
  if job.get("kind","")=="training" and job.get("faction_id","")==faction and job.get("status","")=="pending":
   var unit: Dictionary=c.strategy_state.unit_rosters.get(str(job.get("unit_id","")),{})
   value+=ceili(float(unit.get("troops",0))/100)*5
 return value
static func site_quote(c: Node, faction: String, city: String, horizon: int, role: String="integrated") -> Dictionary:
 var s: Dictionary=c.strategy_state; var stamp: int=c.year*12+c.month
 var buildings: Dictionary=s.province_buildings[city]; var research: Dictionary=s.faction_research[s.faction_economy.factions[faction]]
 var eta: int=0; var cost: int=0; var missing: Array=[]; var reasons: Array=[]
 var staff: Array=c.MilitaryPlanning.staff(c,faction,city)
 var builder: Dictionary=c.get_officer(staff[0]) if not staff.is_empty() else {}
 var construction: int=0; var science: int=0; var unpaid_research: Dictionary={}
 for request: Array in [["build","smelter"],["build","forge"],["research","basic_smelting"],["research","swordsmithing"]]:
  var kind: String=request[0]; var key: String=request[1]
  if role=="iron" and key in ["forge","swordsmithing"]: continue
  if role=="forge" and key=="smelter": continue
  if int((buildings if kind=="build" else research).get(key,0))>0: continue
  missing.append(key)
  var job: Dictionary=Industry.active(s,kind,city,faction)
  var turns: int=0
  if not job.is_empty() and job.requirement_id==key:
   var person: Dictionary=c.get_officer(job.officer_id)
   if job.status!="pending" or person.is_empty() or not Industry.staff_reason(s,c.provinces,faction,str(job.city_id),str(job.officer_id),stamp,str(job.id)).is_empty(): reasons.append("담당자 배정/재개 필요: "+key)
   else: turns=Industry.remaining_months(s,job.city_id,person,kind,int(job.required)-int(job.progress))
  else:
   var definition: Dictionary=(c.strategy.BUILDING_DEFS if kind=="build" else c.strategy.RESEARCH_DEFS)[key]
   cost+=int(definition.base_gold)
   if kind=="research": unpaid_research[key]=int(definition.base_gold)
   if builder.is_empty(): reasons.append("미착공 담당자 없음: "+key)
   else: turns=Industry.remaining_months(s,city,builder,kind,int(definition.base_turns)*300)
   if not job.is_empty(): turns+=Industry.remaining_months(s,job.city_id,c.get_officer(job.officer_id),kind,maxi(0,int(job.required)-int(job.progress)))
  if kind=="build": construction+=turns
  else: science+=turns
 eta=construction+science # Conservative: do not promise parallel use of one worker.
 var work: int=Industry.production_work(s,c.provinces,city,stamp)
 var factor: float=c.Power.city_factor(s,city)
 var normal_work: int=floori(work/factor) # Conservative undo of a temporary rounded penalty.
 var disrupted: int=int(c.Power.records(s).get("cities",{}).get(city,{}).get("remaining",0))
 var amount: int=0
 for n: int in range(1,horizon+1):
  if n<=eta or not reasons.is_empty(): continue
  amount+=work if n<=disrupted else normal_work
 var potential: int=int(amount/100.0) if role!="iron" else 0
 if role=="forge": potential=mini(potential,int(float(stock(c,city,"iron")+Supply.incoming(s,c.provinces,faction,city,"iron",stamp+horizon,stamp))/2.0))
 var ready: bool=missing.is_empty()
 var current: Dictionary=Production.city_quote(s,c.provinces,city,stamp+1,c.scenario_id,c.iron_supply_rules)
 return {"city":city,"role":role,"ready":ready,"eta":eta,"unpaid_gold":cost,"unpaid_research":unpaid_research,"missing":missing,"reasons":reasons,"worker_ids":staff,"work_now":work,"work_after_disruption":normal_work,"disruption_months":disrupted,"conditional_bundles":potential,"next_batches":current.forge.batches.size(),"stock_iron":stock(c,city,"iron"),"stock_bundles":stock(c,city,"sword"),"incoming_bundles":Supply.incoming(s,c.provinces,faction,city,"sword",stamp+horizon,stamp)}
static func reachable(c: Node, faction: String, source: String, targets: Dictionary) -> bool:
 for target: String in targets:
  if not Supply.route(c.strategy_state,c.provinces,faction,source,target).is_empty(): return true
 return false
static func allocate(c: Node, faction: String, targets: Dictionary, pools: Dictionary, horizon: int) -> Dictionary:
 # This is a disposable forecast allocation. No stock or gold is reserved on disk.
 var remaining: Dictionary=pools.duplicate(true); var unmet: Dictionary={}
 for target: String in targets:
  var need: int=int(targets[target]); var offers: Array=[]
  for source: String in remaining:
   var path: Array=Supply.route(c.strategy_state,c.provinces,faction,source,target)
   if path.is_empty() or path.size()-1>horizon: continue
   offers.append({"city":source,"travel":path.size()-1})
  offers.sort_custom(func(a,b): return a.city<b.city if a.travel==b.travel else a.travel<b.travel)
  for offer: Dictionary in offers:
   var assigned: int=mini(need,int(remaining[offer.city]))
   remaining[offer.city]-=assigned; need-=assigned
  if need>0: unmet[target]=need
 return {"unmet":unmet,"unused":remaining}
static func candidates(c: Node, faction: String, nodes: Dictionary, borders: Array, horizon: int) -> Array:
 var result: Array=[]
 for city: String in c.MilitaryPlanning.owned(c,faction):
  if nodes.has(city): continue
  var q: Dictionary=site_quote(c,faction,city,horizon)
  if q.worker_ids.is_empty() or not q.reasons.is_empty(): continue
  var distance: int=999; var destination: String=""
  for front: Dictionary in borders:
   var path: Array=Supply.route(c.strategy_state,c.provinces,faction,city,front.city)
   if not path.is_empty() and path.size()-1<distance: distance=path.size()-1; destination=front.city
  if destination.is_empty():
   var hub: String=c.strategy_state.military_planning.factions[faction].hub
   var path: Array=Supply.route(c.strategy_state,c.provinces,faction,city,hub)
   if not path.is_empty(): distance=path.size()-1; destination=hub
  if destination.is_empty(): continue
  var threat: float=0
  for front: Dictionary in borders:
   if front.city==city: threat=maxf(0,float(front.enemy_power)-float(front.defense_power))
  var food: int=Supply.upkeep(c.provinces[city])*3
  if int(c.provinces[city].food_stock)<food: continue
  q["destination"]=destination; q["travel"]=distance
  q["first_delivery"]=q.eta+1+distance
  q["threat"]=threat; q["transport_estimate"]=distance*11
  q["score"]=int(q.first_delivery)*100+int(q.unpaid_gold)+int(q.transport_estimate)+ceili(threat/100)
  result.append(q)
 result.sort_custom(func(a,b): return a.city<b.city if a.score==b.score else a.score<b.score)
 return result
static func request_shipment(c: Node, faction: String, target: String, item: String, needed: int, cap: int, stamp: int, actions: Array, maximum_unit_cost: float=INF) -> bool:
 if freight_count(c,faction,stamp)>=cap: return false
 var offers: Array=[]
 for donor: String in c.MilitaryPlanning.owned(c,faction):
  if donor==target: continue
  var keep: int=local_need(c,faction,donor) if item=="sword" else 0
  if item=="iron" and bool(c.strategy_state.city_production[donor].iron_sword.enabled): keep=ceili(float(Industry.production_work(c.strategy_state,c.provinces,donor,stamp))/100)*2*int(POLICY.material_months)
  if item=="sword" and donor==str(c.strategy_state.military_planning.factions[faction].hub): keep+=int(POLICY.buffer_bundles)
  var amount: int=mini(200,mini(needed,stock(c,donor,item)-keep))
  if amount<=0: continue
  var q: Dictionary=Supply.quote(c.strategy_state,c.provinces,faction,donor,target,{item:amount},stamp)
  if not q.ok or Economy.balance(c.strategy_state,faction)-int(q.cost)<reserve(c,faction): continue
  if float(q.cost)/amount>maximum_unit_cost: continue
  offers.append({"source":donor,"amount":amount,"quote":q,"score":float(q.cost)/amount+(q.path.size()-1)*int(POLICY.delivery_month_value)})
 offers.sort_custom(func(a,b): return a.source<b.source if is_equal_approx(a.score,b.score) else a.score<b.score)
 if offers.is_empty(): return false
 var offer: Dictionary=offers[0]
 var result: Dictionary=Supply.start(c.strategy_state,c.provinces,faction,offer.source,target,{item:offer.amount},stamp)
 actions.append({"action":"network_transport","item":item,"source":offer.source,"target":target,"amount":offer.amount,"arrival":stamp+offer.quote.path.size()-1,"result":result})
 return result.ok
static func run(c: Node, faction: String, plan: Dictionary, borders: Array, actions: Array) -> void:
 var s: Dictionary=c.strategy_state
 if c.Ending.finished(s): return
 var network: Dictionary=ensure(plan); var stamp: int=c.year*12+c.month
 if int(network.last_month)>=stamp: return
 network.last_month=stamp
 var cities: Array=c.MilitaryPlanning.owned(c,faction); var hub: String=plan.hub
 var invalid: Array=[]
 for city: String in network.sites.keys():
  if not cities.has(city):
   network.history.append({"month":stamp,"city":city,"action":"site_lost","reason":"소유권 상실: 전망·배정 제외, 실제 재고/시설은 점령 원장 유지"}); invalid.append(city); network.sites.erase(city)
 if not network.sites.has(hub): network.sites[hub]={"selected_month":stamp,"role":"integrated","reason":"기존 주 거점"}
 for city: String in cities:
  if network.sites.has(city): continue
  var buildings: Dictionary=s.province_buildings[city]
  if int(buildings.get("smelter",0))+int(buildings.get("forge",0))>0:
   var role: String="integrated" if int(buildings.get("smelter",0))>0 and int(buildings.get("forge",0))>0 else ("iron" if int(buildings.get("smelter",0))>0 else "forge")
   network.sites[city]={"selected_month":stamp,"role":role,"reason":"기존 시설 재사용"}
 var raw_demand: int=0; var unarmed: int=0; var targets: Dictionary={}
 for city: String in cities:
  if local_need(c,faction,city)>0: targets[city]=local_need(c,faction,city)
 for front: Dictionary in borders:
  var deficit: int=maxi(int(front.defense_deficit),int(front.attack_deficit))
  raw_demand+=deficit
  if deficit>0: targets[front.city]=maxi(int(targets.get(front.city,0)),ceili(float(deficit)/100))
 if targets.is_empty(): targets[hub]=int(POLICY.buffer_bundles)
 for u: Dictionary in s.unit_rosters.values():
  if u.faction_id==faction and u.kind=="infantry": unarmed+=maxi(0,int(u.troops)-int(u.equipment))
 var horizon: int=clampi(int(c.MilitaryPlanning.forecast(c,faction,hub).horizon),6,18)
 var wanted: int=0
 for value: int in targets.values(): wanted+=value
 var current: int=0; var inbound: int=0; var pools: Dictionary={}; var stranded: int=0
 for city: String in cities:
  current+=stock(c,city,"sword")
  var arriving: int=Supply.incoming(s,c.provinces,faction,city,"sword",stamp+horizon,stamp)
  inbound+=arriving; pools[city]=stock(c,city,"sword")+arriving
  if not reachable(c,faction,city,targets): stranded+=int(pools[city])
 var quotes: Array=[]; var capacity: int=0; var research_budgeted: Dictionary={}; var virtual_gold: int=maxi(0,Economy.balance(s,faction)-reserve(c,faction))
 for city: String in network.sites:
  var nearest: int=horizon+1
  for target: String in targets:
   var path: Array=Supply.route(s,c.provinces,faction,city,target)
   if not path.is_empty(): nearest=mini(nearest,path.size()-1)
  var q: Dictionary=site_quote(c,faction,city,maxi(0,horizon-nearest),network.sites[city].role)
  q["nearest_delivery_months"]=nearest
  var investment: int=int(q.unpaid_gold)
  for key: String in q.unpaid_research:
   if research_budgeted.has(key): investment-=int(q.unpaid_research[key])
   else: research_budgeted[key]=true
  var direct_cost: int=28
  if Production.validate_batch(s,c.provinces,city,"iron_supply",s.faction_economy.factions[faction],Economy.balance(s,faction),c.scenario_id,c.iron_supply_rules).ok: direct_cost=16
  var paid_capacity: int=mini(int(q.conditional_bundles),int(float(maxi(0,virtual_gold-investment))/direct_cost))
  virtual_gold=maxi(0,virtual_gold-investment-paid_capacity*direct_cost)
  q["allocated_unpaid_gold"]=investment; q["direct_gold_per_bundle"]=direct_cost
  pools[city]=int(pools.get(city,0))+paid_capacity
  q["budgeted_conditional_bundles"]=paid_capacity; capacity+=paid_capacity; quotes.append(q)
 var allocation: Dictionary=allocate(c,faction,targets,pools,horizon)
 var shortage: bool=not allocation.unmet.is_empty() and maxi(raw_demand,unarmed)>=int(POLICY.minimum_expansion_people)
 network.shortage_months=int(network.shortage_months)+1 if shortage else 0
 var options: Array=[]
 if (int(network.shortage_months)>=int(POLICY.sustained_months) or not invalid.is_empty()) and network.sites.size()<int(POLICY.max_sites):
  options=candidates(c,faction,network.sites,borders,horizon)
  options=options.filter(func(q): return reachable(c,faction,q.city,allocation.unmet) if not allocation.unmet.is_empty() else true)
  for q: Dictionary in options:
   if Economy.balance(s,faction)<reserve(c,faction)+int(q.unpaid_gold): continue
   network.sites[q.city]={"selected_month":stamp,"role":"integrated","reason":"지속 수요/공급 부족","selection":q.duplicate(true)}
   network.history.append({"month":stamp,"action":"invest","city":q.city,"raw_demand":raw_demand,"unarmed":unarmed,"wanted_bundles":wanted,"conditional_bundles":capacity,"candidate":q.duplicate(true)})
   network.shortage_months=0; break
 var cap: int=mini(int(POLICY.maximum_freight),maxi(1,network.sites.size()))
 # Existing grain support ran first and counts against this shared dispatch budget.
 for city: String in network.sites:
  c.MilitaryPlanning.infrastructure(c,faction,city,actions,reserve(c,faction),str(network.sites[city].role))
  var available: Array=c.MilitaryPlanning.staff(c,faction,city)
  if available.size()>1 and Industry.active(s,"production",city,faction).is_empty() and int(s.province_buildings[city].get("forge",0))>0:
   actions.append({"action":"production_manager","city":city,"result":Industry.start(s,c.provinces,c.strategy,faction,city,"production","",available.back(),stamp,c.scenario_id,c.iron_supply_rules)})
  var local_target: int=mini(30,maxi(int(POLICY.buffer_bundles),ceili(float(wanted)/network.sites.size())))
  var name: String=s.faction_economy.factions[faction]
  var enabled: bool=current+inbound<wanted or local_need(c,faction,city)>0
  var can_pay: bool=Economy.balance(s,faction)>=reserve(c,faction)+28
  Production.set_enabled(s,c.provinces,city,"iron_sword",name,enabled and can_pay and stock(c,city,"sword")<local_target,c.scenario_id,c.iron_supply_rules)
  var desired_iron: int=ceili(float(Industry.production_work(s,c.provinces,city,stamp))/100)*2*int(POLICY.material_months)
  if network.sites[city].role=="iron": desired_iron=20
  var need: int=desired_iron-stock(c,city,"iron")-Supply.incoming(s,c.provinces,faction,city,"iron",stamp+horizon,stamp)
  var recipe: String="iron_supply"
  if not Production.validate_batch(s,c.provinces,city,recipe,name,Economy.balance(s,faction),c.scenario_id,c.iron_supply_rules).ok: recipe="iron_procurement"
  var local_valid: bool=Production.validate_batch(s,c.provinces,city,recipe,name,Economy.balance(s,faction),c.scenario_id,c.iron_supply_rules).ok
  var imported: bool=false
  if need>0:
   var unit_price: float=float(Production.Data.RECIPES[recipe].operating_gold)/2.0 if local_valid else INF
   imported=request_shipment(c,faction,city,"iron",need,cap,stamp,actions,unit_price)
  # Keep local supply during transit if forging would run out before arrival.
  if imported and stock(c,city,"iron")>=desired_iron: need=0
  for option: String in ["iron_supply","iron_procurement"]: Production.set_enabled(s,c.provinces,city,option,name,enabled and can_pay and need>0 and option==recipe,c.scenario_id,c.iron_supply_rules)
 # Issue from each city's real stock before allocating shipments; never reserve the same bundle twice.
 var destinations: Array=cities.duplicate()
 destinations.sort_custom(func(a,b): return a<b if local_need(c,faction,a)==local_need(c,faction,b) else local_need(c,faction,a)>local_need(c,faction,b))
 for city: String in destinations:
  for uid: String in Army.at_city(s,city,faction):
   var u: Dictionary=s.unit_rosters[uid]
   if u.kind!="infantry": continue
   var bundles: int=mini(stock(c,city,"sword"),ceili(float(maxi(0,int(u.troops)-int(u.equipment)))/100))
   if bundles>0: actions.append({"action":"network_equip","city":city,"unit_id":uid,"result":Army.equip(s,c.provinces,faction,uid,bundles,stamp)})
  var need: int=local_need(c,faction,city)+(int(POLICY.buffer_bundles) if city==hub and raw_demand>0 else 0)-stock(c,city,"sword")-Supply.incoming(s,c.provinces,faction,city,"sword",stamp+horizon,stamp)
  if need>0: request_shipment(c,faction,city,"sword",need,cap,stamp,actions)
 network.report={"month":stamp,"horizon":horizon,"raw_military_shortfall":raw_demand,"unarmed_before":unarmed,"wanted_bundles":wanted,"warehouse_before":current,"stranded_bundles":stranded,"demand_by_city":targets,"allocation":allocation,"valid_inbound":inbound,"conditional_bundles":capacity,"shortage_months":network.shortage_months,"sites":quotes,"candidates":options,"freight_limit":cap,"freight_used":freight_count(c,faction,stamp),"lost_sites":invalid,"reserve_gold":reserve(c,faction)}
 network.history.append({"month":stamp,"action":"assessment","report":network.report.duplicate(true)})
static func text(c: Node, faction: String) -> String:
 var network: Dictionary=c.strategy_state.get("military_planning",{}).get("factions",{}).get(faction,{}).get("network",{})
 var r: Dictionary=network.get("report",{})
 if r.is_empty(): return ""
 var warehouse: int=0; var in_transit: int=0; var stamp: int=c.year*12+c.month
 for city: String in c.MilitaryPlanning.owned(c,faction):
  warehouse+=stock(c,city,"sword"); in_transit+=Supply.incoming(c.strategy_state,c.provinces,faction,city,"sword",stamp+int(r.horizon),stamp)
 var lines: Array[String]=["당월 판단 시점의 군수망 · 모집 제한 전 부족 %d명 / 기존 미장비 %d명 · 조건부 계획 %d개월" % [r.raw_military_shortfall,r.unarmed_before,r.horizon],"창고 %d묶음 / 유효 운송 %d / 예산 포함 조건부 생산 %d · 월 화물 %d/%d" % [warehouse,in_transit,r.conditional_bundles,r.freight_used,r.freight_limit]]
 for city: String in network.sites:
  if Supply.owner(c.strategy_state,c.provinces,city)!=faction: continue
  var q: Dictionary=site_quote(c,faction,city,int(r.horizon),str(network.sites[city].role))
  lines.append("%s · %s · 현물 칼%d/철%d · 다음 월 %d배치 · 미납 투자%d · 선행작업 %d개월\n%s" % [c.provinces.get(q.city,{}).get("name",q.city),{"integrated":"철·무기","iron":"철 공급","forge":"무기 제작"}.get(q.role,q.role),q.stock_bundles,q.stock_iron,q.next_batches,q.unpaid_gold,q.eta," / ".join(q.reasons)])
 for order: Dictionary in Supply.ensure(c.strategy_state).orders.values():
  if order.faction_id!=faction or not Supply.active(order): continue
  lines.append("운송 %s → %s · 철%d/칼%d · 남은 %d구간 · %s" % [c.provinces.get(order.current,{}).get("name",order.current),c.provinces.get(order.target,{}).get("name",order.target),order.cargo.iron,order.cargo.sword,maxi(0,order.path.size()-1-int(order.index)),order.reason])
 lines.append("미래 생산은 소유권·담당자·국고·원료·경로 유지 조건부이며 현재 재고가 아닙니다.")
 return "\n".join(lines)