extends "res://tests/player_playtest_base.gd"
func record(label: String) -> void:
 actions.append({"action":label,"year":c.year,"month":c.month,"gold":c.gold,"city":c.provinces.geumseong.duplicate(true),"jobs":c.strategy_state.domestic.jobs.duplicate(true),"log":c.log_label.text})
 var f:=FileAccess.open(OUT+"ui-actions.json",FileAccess.WRITE); f.store_string(JSON.stringify(actions)); f.close()
func events() -> void:
 for step: int in range(50):
  await settle()
  if not c.event_presentation.active: return
  var view: Node=c.event_presentation.view
  var chosen: Button=null
  for id: String in view.choice_buttons:
   var b: Button=view.choice_buttons[id]
   if b.is_visible_in_tree() and not b.disabled:
    chosen=b
    if id in ["reject","maintain_tax"]: break
  if chosen!=null:
   await screen("event-choice-"+str(c.year)+"-"+str(c.month)); actions.append({"action":"event UI choice","label":chosen.text}); await click(chosen)
  elif view.skip_button.is_visible_in_tree() and not view.skip_button.disabled: await click(view.skip_button)
  elif view.next_button.is_visible_in_tree(): await click(view.next_button)
  else: await create_timer(0.3).timeout
 check(false,"event presentation did not close through buttons")
func city_card() -> void:
 await click(c.map_area.city_buttons.geumseong); await settle()
 check(c.selected_province_id=="geumseong","map click selects capital")
func escape() -> void: await key(root,KEY_ESCAPE); await settle()
func pick_id(selector: OptionButton,id: String) -> void:
 for n: int in range(selector.item_count):
  if str(selector.get_item_metadata(n))==id: await choose(selector,n); return
 check(false,"missing UI option "+id)
func officer(selector: OptionButton) -> void:
 for n: int in range(selector.item_count):
  var id: String=str(selector.get_item_metadata(n))
  var person: Dictionary=c.officer_registry.people.get(id,{})
  if not person.is_empty() and person.get("duties",[]).is_empty(): await choose(selector,n); return
 check(false,"no free local officer in UI")
func industry(kind: String,requirement: String) -> void:
 await city_card(); await click(c.map_area.floating_city_card.production_button)
 await click(c.production_overlay.industry_button)
 await choose(c.industry_overlay.kind_selector,0 if kind=="build" else 1)
 await pick_id(c.industry_overlay.requirement_selector,requirement)
 await officer(c.industry_overlay.officer_selector)
 await screen("quote-"+requirement)
 check(not c.industry_overlay.execute_button.disabled,"industry UI quote accepted "+requirement)
 if not c.industry_overlay.execute_button.disabled: await click(c.industry_overlay.execute_button)
 record("UI industry "+requirement); await screen("pending-"+requirement); await escape()
func _run() -> void:
 create_timer(500).timeout.connect(func(): quit(2))
 await boot(); await click(c.load_game_button); await screen("sample-picker")
 await pick_file(c.load_picker,"01_632-02_start.json"); await create_timer(1).timeout; c=current_scene
 check(c.has_method("get_officer"),"title chosen sample enters campaign")
 if not c.has_method("get_officer"): quit(1); return
 await events(); check(c.year==632 and c.month==2,"sample timestamp unchanged"); await screen("sample-early")
 await menu("세력 선택으로"); await click(c.navigation_menu.confirmation_dialog.get_ok_button()); await create_timer(1.5).timeout; c=current_scene
 await click(c.start_button); await create_timer(2).timeout; c=current_scene; await events()
 check(c.year==632 and c.month==1,"actual selection starts new632Silla")
 await menu("캠페인 목표·전쟁 준비"); await screen("new-objectives"); await click(c.playability_dialog.get_ok_button())
 await menu("귀족·군권·인사정치"); await screen("politics-open"); print("POLITICS VISIBLE ",c.politics_overlay.visible)
 var p: Node=c.politics_overlay
 for n: int in range(p.targets.item_count):
  var t: Dictionary=p.targets.get_item_metadata(n)
  if t.kind=="governor" and t.city=="geumseong": await choose(p.targets,n); break
 var appointed: String=""
 for n: int in range(p.people.item_count):
  if str(p.people.get_item_metadata(n))!=c.get_governor_id("geumseong"): appointed=str(p.people.get_item_metadata(n)); await choose(p.people,n); break
 await screen("governor-preview")
 await click(p.apply_button); check(c.get_governor_id("geumseong")==appointed,"actual governor appointment changes shared post"); await screen("governor-result"); await escape()
 await city_card(); await click(c.map_area.floating_city_card.detail_button); await screen("officers-and-city"); await click(c.close_detail_button)
 await city_card(); await click(c.map_area.floating_city_card.domestic_button); await screen("domestic-quote"); await click(c.domestic_overlay.execute_button); record("UI agriculture accepted"); await escape()
 for step: int in range(12):
  await click(c.end_turn_button); await events(); record("UI month "+str(step+1)); await screen("month-%02d"%(step+1))
  if step==0:
   await industry("build","smelter"); await industry("research","swordsmithing")
  if step==6: await industry("build","forge")
  if step==10:
   await city_card(); await click(c.map_area.floating_city_card.production_button)
   await pick_id(c.production_overlay.recipe_selector,"iron_procurement"); await screen("production-common-iron")
   await click(c.production_overlay.start_button); record("UI common iron order"); await escape()
 check(c.year==633 and c.month==1,"12 UI monthly clicks advanced exactly12months")
 await city_card(); await click(c.map_area.floating_city_card.recruit_button); await screen("recruitment-costs")
 await click(c.recruitment_overlay.army_button); await screen("army-equipment-training-menu"); await escape()
 await city_card(); await click(c.map_area.floating_city_card.move_button); await click(c.transfer_panel.cargo_button); await screen("cargo-transport-menu"); await escape()
 await click(c.save_button); record("UI save button"); check(FileAccess.file_exists(c.SAVE_PATH),"UI creates review progress save")
 await click(c.load_button); await events(); check(c.year==633 and c.month==1,"UI restore preserves date")
 await menu("저장 파일 선택"); check(c.ending_load_dialog.visible and not c.power_dialog.visible,"load menu does not open power dialog")
 await pick_file(c.ending_load_dialog,"02_635-02_front.json"); await events(); check(c.year==635 and c.month==2,"middle sample loaded via game picker"); await screen("sample-front")
 await menu("저장 파일 선택"); await pick_file(c.ending_load_dialog,"03_638-02_unification.json"); await events(); check(c.year==638 and c.month==2,"late sample loaded via game picker"); await screen("sample-late")
 print("PLAYER UI RESULT failures ",failures); quit(1 if failures else 0)
