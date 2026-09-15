extends "res://tests/ai_military_planning_audit.gd"
var trace: Array=[]
func save_trace(label: String) -> void:
 c._on_save_button_pressed(DIR+label+".json")
 var file:=FileAccess.open(DIR+"actions.json",FileAccess.WRITE); file.store_string(JSON.stringify(trace)); file.close()
func _run() -> void:
 DIR="res://.godot/normal-completion-attempt-1/"; DirAccess.make_dir_recursive_absolute(DIR)
 create_timer(600).timeout.connect(func(): save_trace("timeout"); quit(2))
 seed(63220260915)
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 save_trace("normal-start")
 for step: int in range(180):
  if c.Ending.finished(c.strategy_state): break
  var s: Dictionary=c.strategy_state; var options: Array=[]
  for source: String in P.owned(c,"silla"):
   var force: float=Army.power(s,Army.attack_units(s,source,"silla"))*(1+float(c.get_best_commander(source,"attack").leadership)/100.0)
   for target: String in c.province_connections.get(source,[]):
    if c.Economy.resolve(s,c.provinces[target].faction)=="silla": continue
    var defense: float=Army.power(s,Army.at_city(s,target))*(1+float(c.get_best_commander(target).leadership)/100.0+float(c.provinces[target].fortress)/200.0)
    options.append({"source":source,"target":target,"ratio":force/maxf(1,defense),"force":force,"defense":defense})
  options.sort_custom(func(a,b): return a.source+a.target<b.source+b.target if is_equal_approx(a.ratio,b.ratio) else a.ratio>b.ratio)
  if options.is_empty(): break
  var chosen: Dictionary=options[0]
  var rally: String=chosen.source
  if float(chosen.ratio)>1.4 and c.validate_attack_staff(rally).ok and int(c.provinces[rally].food_stock)>=c.ATTACK_FOOD_COST:
   save_trace("before-battle-%03d"%step)
   var result: Dictionary=c.resolve_army_battle(rally,chosen.target,"silla")
   trace.append({"step":step,"action":"attack","choice":chosen,"result":result})
   print("BATTLE ",step," ",rally,"->",chosen.target," ",result.get("won",false)," losses ",result.get("attacker_losses",0))
   events(); await process_frame
   if result.get("won",false): rally=chosen.target
   c.evaluate_campaign_ending("normal_play_battle")
   if c.Ending.finished(s): save_trace("victory"); break
  # One-hop legal orders consolidate existing armies; leave real garrisons.
  for source: String in P.owned(c,"silla"):
   if source==rally: continue
   var path: Array=P.military_route(c,"silla",source,rally)
   if path.size()<2: continue
   var amount: int=maxi(0,Army.count(s,Army.at_city(s,source,"silla",true))-2000)
   if amount<100: continue
   var result: Dictionary=c.queue_province_transfer({"source_id":source,"target_id":path[1],"troops":amount,"officer_ids":[]},false,"silla")
   trace.append({"step":step,"action":"transfer","source":source,"target":path[1],"amount":amount,"result":result})
  c._on_end_turn_button_pressed(); events(); await process_frame
  trace.append({"step":step,"action":"month","year":c.year,"month":c.month,"state":metrics("silla")})
  if step%12==0: save_trace("month-%03d"%(step+1)); print("NORMAL ",step+1," cities ",P.owned(c,"silla").size()," gold ",c.gold)
 save_trace("final")
 print("NORMAL COMPLETION ",c.strategy_state.campaign_ending.status," cities ",P.owned(c,"silla").size()," date ",c.year,"/",c.month)
 quit()