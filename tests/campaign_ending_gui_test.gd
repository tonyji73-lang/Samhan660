extends "res://tests/project_foundation_test.gd"
const Ending=preload("res://campaign_ending.gd")
var DIR: String=""
func click(button: Control) -> void:
 await settle()
 if button.get_viewport()!=root:
  button.grab_focus()
  for down: bool in [true,false]:
   var key:=InputEventKey.new(); key.keycode=KEY_ENTER; key.pressed=down
   button.get_viewport().push_input(key,true)
  await settle()
  return
 var position: Vector2=button.get_global_transform_with_canvas()*(button.size/2.0)
 for down: bool in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=position
  button.get_viewport().push_input(event,true)
 await settle()
func screen(label: String) -> void:
 await settle(); await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(DIR+label+".png")==OK,"native capture "+label)
func button_named(node: Node, label: String) -> Button:
 if node is Button and node.text==label: return node
 for child: Node in node.get_children(true):
  var found: Button=button_named(child,label)
  if found!=null: return found
 return null
func _run() -> void:
 create_timer(180).timeout.connect(func(): quit(2))
 DIR=FileAccess.get_file_as_string("res://.godot/ending-results/latest.txt")
 root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
 change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await finish_events()
 c._on_load_button_pressed(DIR+"boundary-before-victory.json"); await settle(); await finish_events()
 c.event_presentation.display_level="all"
 # Presentation-only boundary seam: the existing named battle cutscene is
 # triggered by this battle too. No combat rule, person stat or target changes.
 for key: String in c.event_presentation.events:
  if c.event_presentation.events[key].get("trigger",{}).get("event_key","")=="battle_start":
   c.event_presentation.events[key]=c.event_presentation.events[key].duplicate(true)
   c.event_presentation.events[key].trigger={"event_key":"battle_start"}
   break
 c.resolve_attack("danghangseong","hwanghae"); await settle()
 check(c.event_presentation.active and not Ending.finished(c.strategy_state),"boundary battle cutscene starts before ending evaluation")
 check(not (c.event_presentation.active and c.ending_dialog.visible),"actual player battle and ending windows never overlap")
 if c.event_presentation.active: await screen("boundary-battle-presentation")
 await finish_events(); await settle()
 check(Ending.finished(c.strategy_state) and c.ending_dialog.visible,"native player battle reaches result screen")
 await screen("victory")
 await click(button_named(c.ending_dialog,"결과 저장·재시도")); await settle()
 check(c.ending_save_message.contains("완료"),"actual result save button writes dedicated user-profile ending")
 await screen("victory-saved")
 await click(button_named(c.ending_dialog,"다른 위치에 결과 저장")); await settle()
 check(c.ending_save_dialog.visible,"alternate save picker opens")
 await click(c.ending_save_dialog.get_cancel_button()); await settle()
 check(c.ending_dialog.visible and not c.ending_save_dialog.visible,"cancel save picker returns to result without exclusive-window overlap")
 await click(button_named(c.ending_dialog,"다른 위치에 결과 저장")); await settle()
 c.ending_save_dialog.file_selected.emit(ProjectSettings.globalize_path(DIR+"gui-alternate-ending.json")); await settle()
 check(c.ending_dialog.visible and c.ending_save_message.contains("완료"),"alternate file selection writes result and restores window")
 # Explicit inaccessible boundary, never a claimed successful save.
 c.save_ending_result(DIR+"missing-directory/gui.json"); c.show_ending_result(); await screen("save-failure")
 check(c.ending_save_message.contains("실패") and c.ending_dialog.visible,"save failure remains in result UI")
 await click(button_named(c.ending_dialog,"결과 저장·재시도")); await settle()
 check(c.ending_save_message.contains("완료"),"retry via actual button succeeds")
 await click(button_named(c.ending_dialog,"진행 저장 불러오기")); await settle()
 check(c.ending_load_dialog.visible,"result opens file picker for another campaign save")
 c.ending_load_dialog.file_selected.emit(ProjectSettings.globalize_path(DIR+"normal-before.json")); await settle(); await finish_events()
 check(not Ending.finished(c.strategy_state) and not c.ending_dialog.visible and not c.map_area.modal_input_locked,"selected normal save restores progress and map input")
 var stamp: int=c.year*12+c.month
 await click(c.end_turn_button); await finish_events(); await settle()
 check(c.year*12+c.month==stamp+1,"actual restored month button advances")
 await screen("restored-ongoing")
 c._on_load_button_pressed(DIR+"defeat.json"); await settle()
 check(c.ending_dialog.visible and c.strategy_state.campaign_ending.status=="defeat","loaded defeat renders without resume")
 await screen("defeat-restored")
 await click(button_named(c.ending_dialog,"새 캠페인")); await settle()
 check(current_scene!=c and current_scene.has_method("_on_start_pressed"),"result new-campaign button reaches existing selection screen")
 var setup: Node=current_scene
 await click(setup.start_button)
 await create_timer(1.5).timeout; await settle(); c=current_scene
 check(c.has_method("evaluate_campaign_ending"),"existing selection starts next real campaign")
 await finish_events(); await settle()
 check(not Ending.finished(c.strategy_state) and not c.ending_dialog.visible and not c.map_area.modal_input_locked,"fresh real scene clears result and lock")
 stamp=c.year*12+c.month; await click(c.end_turn_button); await finish_events(); await settle()
 check(c.year*12+c.month==stamp+1,"next campaign actual month button works")
 await screen("next-campaign")
 # Returning to the main screen is navigation, not an additional defeat.
 c._on_load_button_pressed(DIR+"victory.json"); await settle()
 await click(button_named(c.ending_dialog,"메인 화면")); await settle()
 check(current_scene!=c,"result main-screen button uses existing navigation")
 print("ENDING GUI: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
