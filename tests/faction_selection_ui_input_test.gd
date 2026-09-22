extends "res://tests/faction_selection_ui_v1_test.gd"
func press_key(code: Key) -> void:
	for down: bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.pressed=down;root.push_input(e,true);await process_frame
	await pause()
func _run() -> void:
	create_timer(90).timeout.connect(func():quit(2))
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	await enter_setup()
	var v: Control=setup.faction_view
	v._focus_controls["difficulty:hard"].grab_focus()
	await press_key(KEY_ENTER)
	check(setup.selected_difficulty_id=="hard","Enter activates focused difficulty")
	await press_key(KEY_TAB)
	check(is_instance_valid(root.gui_get_focus_owner()) and v.is_ancestor_of(root.gui_get_focus_owner()),"Tab stays in visible new UI")
	var scene_path: String=setup.campaign_scene_path
	setup.campaign_scene_path="res://missing_campaign_for_ui_test.tscn"
	await choose("start")
	check(not setup.menu_locked and not v._busy and not str(v._model.start_error).is_empty(),"missing campaign gives recoverable visible error")
	setup.campaign_scene_path=scene_path
	setup._start_from_faction_view({"scenario_id":"preview_invalid"})
	check(not v._busy and not str(v._model.start_error).is_empty(),"stale or preview IDs rejected")
	await choose("difficulty:normal")
	check(v._can_start(),"valid choice recovers start")
	await choose("back");await create_timer(2).timeout
	check(current_scene.scene_file_path=="res://title_screen.tscn","back button returns title")
	print("FACTION KEYBOARD: ",checks," checks, ",failures," failures");quit(0 if failures==0 else 1)
