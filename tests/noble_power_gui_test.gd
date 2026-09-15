extends "res://tests/campaign_ending_gui_test.gd"
const Power=preload("res://noble_power_constraints.gd")
func _run() -> void:
 create_timer(180).timeout.connect(func(): quit(2))
 DIR="res://.godot/noble-power-results/"
 root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
 change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await finish_events()
 for choice: String in ["compensate","wait","force"]:
  c._on_load_button_pressed(DIR+"normal-concentrated.json"); await settle(); await finish_events()
  var result: Dictionary=c.Noble.appoint(c,"silla","governor","geumseong","historical:001")
  await settle()
  check(not result.ok and c.power_dialog.visible and c.map_area.modal_input_locked,"real personnel command displays negotiation and locks map")
  await screen("normal-"+choice+"-quote")
  await click(button_named(c.power_dialog,{"compensate":"A 보상·즉시 인계","wait":"B 기한 보장","force":"C 강제 회수"}[choice]))
  await settle()
  var id: String=c.power_request_id
  check(c.Power.records(c.strategy_state).requests[id].status==("waiting" if choice=="wait" else "completed"),"actual choice button "+choice)
  await screen("normal-"+choice+"-selected")
  await click(c.power_dialog.get_ok_button()); await settle()
  check(not c.power_dialog.visible and not c.map_area.modal_input_locked,"close restores map "+choice)
  var month: int=c.year*12+c.month
  await click(c.end_turn_button); await finish_events(); await settle()
  check(c.year*12+c.month==month+1,"actual month button after choice "+choice)
  var pending: Dictionary=c.officer_registry.politics.pending
  if not pending.is_empty(): c.Noble.resolve(c,pending.occurrence_id,"reject")
  c.event_presentation.queue.clear()
  if c.event_presentation.active: c.event_presentation._finish()
  await settle(); c.show_power_transfer(id); await settle()
  check(c.power_dialog.visible and not c.event_presentation.active,"post-event handover status is actually visible")
  await screen("normal-"+choice+"-next-month")
  await click(c.power_dialog.get_ok_button()); await settle()
  if choice=="force":
   c.open_industry("geumseong","production"); await settle()
   check(c.industry_overlay.visible and c.industry_overlay.details.text.contains("80%"),"real production overlay shows authority disruption and facility forecast")
   await screen("normal-force-production")
   var key:=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true; Input.parse_input_event(key); await settle()
   key=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=false; Input.parse_input_event(key); await settle()
   check(not c.industry_overlay.visible and not c.map_area.modal_input_locked,"production Esc restores map input")
 print("NOBLE POWER GUI: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)