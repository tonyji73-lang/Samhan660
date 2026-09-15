extends "res://tests/ai_military_planning_audit.gd"
func metrics(faction: String) -> Dictionary:
 var row: Dictionary=super.metrics(faction); var sites: Dictionary={}
 for city: String in P.owned(c,faction):
  var fp: Dictionary=c.strategy_state.get("facility_progress",{}).get(city,{})
  var data: Dictionary={"sword":0,"iron":0,"weapons_stock":c.ProductionSystem.get_stock(c.strategy_state,c.provinces,city,"sword"),"work":c.Industry.production_work(c.strategy_state,c.provinces,city,c.year*12+c.month)}
  for facility: String in ["forge","smelter"]:
   if int(fp.get(facility,{}).get("last_month",-1))==c.year*12+c.month: data["sword" if facility=="forge" else "iron"]=int(fp[facility].last_batches)*(1 if facility=="forge" else 2)
  sites[city]=data
 row["site_output"]=sites
 return row
func _run() -> void:
 DIR="res://.godot/supply-expansion-results/"
 create_timer(500).timeout.connect(func(): quit(2))
 DirAccess.make_dir_recursive_absolute(DIR)
 var rows: Array=[]
 for player: String in ["silla","baekje"]:
  seed(63220260915)
  await start(Scenarios.SCENARIOS[0],player,"historical"); events()
  c._on_load_button_pressed("res://.godot/supply-expansion-before/"+player+"-initial.json"); events()
  var milestones: Dictionary={}
  c._on_save_button_pressed(DIR+player+"-initial.json")
  for step: int in range(60):
   if c.Ending.finished(c.strategy_state): break
   c._on_end_turn_button_pressed(); events(); await process_frame
   for faction: String in ["silla","baekje","goguryeo"]:
    if faction!=player:
     var row: Dictionary=metrics(faction).merged({"player":player}); rows.append(row)
     var marks: Dictionary={"production":row.sword_month>0,"new-ready":row.new_ready>=1000,"battle":row.losses>0,"front":row.plan.get("completed",[]).any(func(x): return x.creation_reason=="recruitment")}
     for mark: String in marks:
      var key: String=faction+"-"+mark
      if marks[mark] and not milestones.has(key):
       milestones[key]=step+1; c._on_save_button_pressed(DIR+player+"-"+key+".json")
   if step%12==0: print("MONTH ",player," ",step+1," ",rows.back().faction," recruits=",rows.back().recruits," ready=",rows.back().new_ready," losses=",rows.back().losses)
  c._on_save_button_pressed(DIR+player+"-60months.json")
  print("MILESTONES ",player," ",milestones)
 var file:=FileAccess.open(DIR+"months.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows)); file.close()
 print("AI PLANNING RUN DONE ",rows.size()); quit()
