extends "res://tests/ai_military_planning_audit.gd"
func _run() -> void:
 create_timer(180).timeout.connect(func(): quit(2))
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 c._on_load_button_pressed(DIR+"silla-baekje-production.json"); events()
 var s: Dictionary=c.strategy_state; var hub: String=s.military_planning.factions.baekje.hub
 var saved_units: Variant=canonical(s.unit_rosters)
 var saved_gold: int=c.Economy.balance(s,"baekje")
 var q: Dictionary=P.forecast(c,"baekje",hub)
 check(q.facilities_ready and q.stock_bundles>=1,"normal first supply forecast has actual stock")
 # Boundary: stopping production/input invalidates the conditional future, not stocks.
 for recipe: String in ["iron_supply","iron_procurement","iron_sword"]: s.city_production[hub][recipe].enabled=false
 check(P.forecast(c,"baekje",hub).conditional_future_bundles==0,"stopped production invalidates forecast")
 check(c.Economy.balance(s,"baekje")==saved_gold and canonical(s.unit_rosters)==saved_units,"forecast is not a payment or troop creation")
 # Boundary route interruption, using an actual existing army route.
 var target: String=s.military_planning.factions.baekje.front
 var route: Array=P.military_route(c,"baekje",hub,target)
 check(route.size()>1,"normal hub has a valid military route")
 var graph: Dictionary=c.province_connections.duplicate(true)
 c.province_connections[hub]=[]
 check(P.military_route(c,"baekje",hub,target).is_empty(),"cut route invalidates deployment immediately")
 c.province_connections=graph
 # Capture uses the real common capture hooks; no credit or free replacement facility.
 c.provinces[hub].faction="신라"; c.ProductionSystem.stop_on_capture(s,hub); c.Supply.capture(s,c.provinces,hub,c.year*12+c.month)
 s.military_planning.months.baekje=-1
 P.run(c,"baekje")
 check(s.military_planning.factions.baekje.hub!=hub,"lost hub causes replanning at a genuinely owned city")
 check(not s.city_production[hub].iron_sword.enabled,"old-owner production is not re-enabled after capture")
 # Historical other AI cannot invade under the existing actual attack rule.
 await start(Scenarios.SCENARIOS[0],"baekje","historical"); events()
 check(P.fronts(c,"goguryeo").is_empty(),"historical AI-to-AI adjacency is not a false emergency")
 # Switching back to general planning after removing a real local threat.
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 P.run(c,"goguryeo")
 check(c.strategy_state.military_planning.factions.goguryeo.actions.any(func(a): return a.action=="emergency_recruit"),"actual adjacent player strength triggers bounded emergency")
 for city: String in P.owned(c,"silla"): c.provinces[city].faction="백제"
 c.strategy_state.military_planning.months.goguryeo=-1
 P.run(c,"goguryeo")
 check(not c.strategy_state.military_planning.factions.goguryeo.actions.any(func(a): return a.action=="emergency_recruit"),"removed threat returns to general plan without recurring emergency")
 print("AI PLANNING CONSTRAINTS ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
