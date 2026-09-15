extends "res://tests/ai_military_planning_audit.gd"
const Network=preload("res://military_supply_network.gd")
const SaveFixtures=preload("res://tests/test_save_fixtures.gd")
func full() -> Variant:
 return canonical({"s":c.strategy_state,"p":c.provinces,"t":c.pending_transfer_orders})
func _run() -> void:
 DIR=SaveFixtures.directory("supply-expansion-results")
 var politics_save: String=SaveFixtures.directory("noble-power-results")+"normal-concentrated.json"
 if not SaveFixtures.available([DIR+"silla-60months.json",DIR+"baekje-60months.json",politics_save]):
  quit(77); return
 create_timer(240).timeout.connect(func(): quit(2))
 await start(Scenarios.SCENARIOS[0],"baekje","historical"); events()
 c._on_load_button_pressed(DIR+"baekje-60months.json"); events()
 var n: Dictionary=c.strategy_state.military_planning.factions.goguryeo.network
 check(n.sites.size()==1 and n.history.filter(func(x):return x.action=="invest").is_empty(),"A normal no threatened front: one site, no expansion spending")
 for player: String in ["silla","baekje"]:
  c._on_load_button_pressed(DIR+player+"-60months.json"); events()
  for faction: String in ["silla","baekje","goguryeo"]:
   if faction==player or (player=="baekje" and faction=="goguryeo"): continue
   var case_plan: Dictionary=c.strategy_state.military_planning.factions[faction]
   var produced: Dictionary={}; var costs: Dictionary={}; var shipments: Array=[]
   for entry: Dictionary in c.strategy_state.faction_economy.entries:
    if entry.faction_id!=faction: continue
    if str(entry.token).contains(":forge:") and entry.reason=="production": produced[entry.city_id]=int(produced.get(entry.city_id,0))-int(float(entry.amount)/10.0)
    if entry.reason=="industry_build": costs[entry.city_id]=int(costs.get(entry.city_id,0))-int(entry.amount)
   for order: Dictionary in c.Supply.ensure(c.strategy_state).orders.values():
    if order.faction_id==faction and order.source!=case_plan.hub and order.status=="arrived" and int(order.original_cargo.sword)>0: shipments.append(order.duplicate(true))
   check(produced.size()>=2,"B normal two paid producing cities "+faction)
   check(not shipments.is_empty(),"B actual secondary-site weapons arrive "+faction)
   check(case_plan.network.report.raw_military_shortfall>case_plan.unarmed_people,"raw demand distinct from suppressed recruitment "+faction)
   print("NORMAL_SITES ",faction," production=",produced," extra_shipments=",shipments.size())
  var before: Variant=full()
  for faction: String in c.strategy_state.military_planning.factions: P.run(c,faction)
  check(full()==before,"same month all national planners inert "+player)
  c._on_save_button_pressed(DIR+"restore-"+player+".json")
  for repeat: int in range(2):
   c._on_load_button_pressed(DIR+"restore-"+player+".json"); events()
   check(full()==before,"saved network/cost/stock restore no commands "+player+str(repeat))
 # Pure allocation: one physical pool cannot satisfy two destination demands twice.
 var allocation: Dictionary=Network.allocate(c,"silla",{"geumseong":10,"geumgwan":10},{"geumseong":10},6)
 check(allocation.unmet.size()==1 and allocation.unmet.geumgwan==10,"disposable allocation never duplicates bundles")
 allocation=Network.allocate(c,"silla",{"geumseong":10},{"ulleung":100},6)
 check(allocation.unmet.geumseong==10,"sea island stock never counts as land supply")
 # C boundary: normal sixty-month state, change only ownership, use capture hooks.
 c._on_load_button_pressed(DIR+"silla-60months.json"); events()
 var s: Dictionary=c.strategy_state
 var lost: String=s.military_planning.factions.goguryeo.hub
 c.provinces[lost].faction=c.player_faction
 c.Supply.capture(s,c.provinces,lost,c.year*12+c.month)
 c.ProductionSystem.stop_on_capture(s,lost)
 c._on_save_button_pressed(DIR+"boundary-loss-start.json")
 var rows: Array=[]; var initial_issued: int=int(metrics("goguryeo").issued)
 for step: int in range(18):
  c._on_end_turn_button_pressed(); events(); await process_frame
  var row: Dictionary=metrics("goguryeo"); rows.append(row)
  check(P.owned(c,"goguryeo").has(lost) or not row.plan.network.sites.has(lost),"enemy-owned stock/facility excluded; actual recapture may reuse "+str(step))
  check(row.finance.balance>=0,"loss replanning pays real treasury "+str(step))
 c._on_save_button_pressed(DIR+"boundary-loss-final.json")
 check(int(rows.back().issued)>initial_issued,"C surviving network resumes actual equipment issues")
 var file:=FileAccess.open(DIR+"loss-months.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows)); file.close()
 # D normal political save, real choice; trial AI assessment for player nation is isolated.
 for choice: String in ["wait","force","compensate"]:
  c._on_load_button_pressed(politics_save); events()
  var offer: Dictionary=c.Power.intercept(c,{"kind":"governor","target":"geumseong","officer_id":"historical:001","faction_id":"silla"})
  check(offer.has("negotiation_id"),"D genuine existing authority negotiation "+choice)
  var paid_before: int=c.gold
  check(c.Power.resolve(c,offer.negotiation_id,choice).ok,"D choice accepted "+choice)
  var quote: Dictionary=Network.site_quote(c,"silla","geumseong",12)
  check(int(quote.work_now)==c.Industry.production_work(c.strategy_state,c.provinces,"geumseong",c.year*12+c.month),"political work uses common factor once "+choice)
  if choice=="force": check(quote.disruption_months==2 and quote.work_after_disruption>quote.work_now,"temporary disruption distinguished from permanent capacity")
  if choice=="wait": check(c.officer_registry.posts["governor:geumseong"]=="historical:004","waiting retains incumbent authority")
  if choice=="compensate": check(c.gold<paid_before,"negotiation fee reduces real investment budget")
  print("POLITICAL_NETWORK ",choice," gold ",paid_before,"->",c.gold," quote=",quote)
  c._on_save_button_pressed(DIR+"political-"+choice+".json")
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 P.run(c,"baekje")
 var plan: Dictionary=c.strategy_state.military_planning.factions.baekje
 var job: Dictionary=c.Industry.active(c.strategy_state,"build",plan.hub,"baekje")
 check(not job.is_empty(),"paid construction present for lost-staff boundary")
 c.officer_registry.people[job.officer_id].active=false
 var invalid_staff: Dictionary=Network.site_quote(c,"baekje",plan.hub,18)
 check(invalid_staff.conditional_bundles==0 and not invalid_staff.reasons.is_empty(),"unqualified assigned builder cannot promise future supply")
 print("SUPPLY EXPANSION RISK: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
