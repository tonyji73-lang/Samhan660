extends "res://tests/officer_registry_test.gd"
const P=preload("res://ai_military_planning.gd")
const Army=preload("res://army_readiness.gd")
var DIR="res://.godot/ai-planning-results/"
func events() -> void:
 c.event_presentation.queue.clear()
 if c.event_presentation.active: c.event_presentation._finish()
 var crop: Dictionary=c.crop_failure_events.get("pending",{})
 if not crop.is_empty(): c.resolve_event_choice(c.CropFailure.EVENT_ID,crop.occurrence_id,"maintain_tax")
 var politics: Dictionary=c.officer_registry.get("politics",{}).get("pending",{})
 if not politics.is_empty(): c.Noble.resolve(c,politics.occurrence_id,"reject")
func metrics(faction: String) -> Dictionary:
 var s: Dictionary=c.strategy_state; var total: int=0; var equipment: int=0; var ready: int=0; var new_ready: int=0
 for unit: Dictionary in s.unit_rosters.values():
  if unit.faction_id!=faction: continue
  total+=int(unit.troops); equipment+=mini(int(unit.troops),int(unit.equipment))
  if Army.training(unit)>=70 and Army.ratio(unit)>=1:
   ready+=int(unit.troops)
   var ancestor: Dictionary=unit
   for hop: int in range(64):
    if ancestor.get("creation_reason","")=="recruitment": new_ready+=int(unit.troops); break
    if not s.unit_rosters.has(str(ancestor.get("parent_unit_id",""))): break
    ancestor=s.unit_rosters[ancestor.parent_unit_id]
 var people: int=0; var food: int=0; var weapons: int=0; var recruits: int=0
 for city: String in P.owned(c,faction):
  people+=int(c.provinces[city].population); food+=int(c.provinces[city].food_stock); weapons+=c.ProductionSystem.get_stock(s,c.provinces,city,"sword")
 for receipt: Dictionary in s.faction_economy.recruitment:
  if receipt.faction_id==faction: recruits+=int(receipt.recruited)
 var iron_month: int=0; var sword_month: int=0; var issued: int=0; var losses: int=0; var spent: Dictionary={}
 for city: String in s.get("facility_progress",{}):
  for facility: String in s.facility_progress[city]:
   var fp: Dictionary=s.facility_progress[city][facility]
   if c.Economy.resolve(s,str(fp.owner))!=faction or int(fp.last_month)!=c.year*12+c.month: continue
   if facility=="smelter": iron_month+=int(fp.last_batches)*2
   if facility=="forge": sword_month+=int(fp.last_batches)
 for entry: Dictionary in s.army.history:
  if entry.action=="equipment_issue" and entry.faction_id==faction: issued+=int(entry.persons)
  if entry.action=="casualties" and s.unit_rosters.get(entry.unit_id,{}).get("faction_id","")==faction: losses+=int(entry.troops)
 for entry: Dictionary in s.faction_economy.entries:
  if entry.faction_id==faction: spent[entry.reason]=int(spent.get(entry.reason,0))+int(entry.amount)
 return {"iron_month":iron_month,"sword_month":sword_month,"issued":issued,"losses":losses,"spent":spent,"battles":s.army.battles.size(),"month":c.year*12+c.month,"faction":faction,"cities":P.owned(c,faction).size(),"troops":total,"equipment":equipment,"ready":ready,"new_ready":new_ready,"civilian":people,"food":food,"weapons":weapons,"recruits":recruits,"finance":s.faction_economy.accounts[faction].duplicate(true),"plan":s.get("military_planning",{}).get("factions",{}).get(faction,{}).duplicate(true)}
func _run() -> void:
 create_timer(500).timeout.connect(func(): quit(2))
 DirAccess.make_dir_recursive_absolute(DIR)
 var rows: Array=[]
 for player: String in ["silla","baekje"]:
  seed(63220260915)
  await start(Scenarios.SCENARIOS[0],player,"historical"); events()
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
