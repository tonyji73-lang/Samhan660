extends "res://tests/project_foundation_test.gd"

const Registry = preload("res://officer_registry.gd")
const Catalog = preload("res://officer_catalog.gd")
const GUI_OUT = "res://.godot/officer-results/"

func click(button: Control) -> void:
	if button.get_viewport() == root:
		await super.click(button)
		return
	# Native ConfirmationDialog owns a separate viewport and coordinates.
	await settle()
	button.grab_focus()
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ENTER
		event.pressed=down
		button.get_viewport().push_input(event,true)
		await process_frame
	await settle()

func capture(label: String) -> void:
	await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(GUI_OUT+label+".png")==OK,"rendered capture "+label)

func _run() -> void:
	create_timer(240.0).timeout.connect(func(): push_error("OFFICER GUI TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(GUI_OUT)
	print("OFFICER GUI renderer=%s version=%s" % [DisplayServer.get_name(),Engine.get_version_info().string])
	var combinations: int = 0
	var indices: Array = [] if "--actions-only" in OS.get_cmdline_user_args() else [1,2,3,4,0]
	for index: int in indices:
		var scenario: Dictionary = Scenarios.SCENARIOS[index]
		for mode: String in ["historical","fictional"]:
			for faction: String in Scenarios.get_active_faction_ids(scenario.id):
				if not Scenarios.is_faction_playable_by_default(scenario.id,faction): continue
				check(change_scene_to_packed(Setup)==OK,"open actual setup")
				await settle()
				var s: Node = current_scene
				s.scenario_buttons[index].pressed.emit()
				s.selected_play_style_id=mode
				s.faction_buttons[faction].button_pressed=true
				await settle()
				check(s.selected_faction_id==faction and not s.start_button.disabled,"selectable UI %d/%s/%s" % [scenario.year,faction,mode])
				var row: Dictionary = Scenarios.get_faction(scenario.id,faction)
				check(not row.ruler_id.is_empty() and s.ruler_label.text.contains(row.ruler),"ruler display resolves common identity")
				if faction=="silla" and mode=="historical": await capture("selection_%d" % scenario.year)
				s._on_start_pressed()
				await create_timer(1.0).timeout
				await settle()
				c=current_scene
				check(c.scene_file_path=="res://campaign_main.tscn" and c.player_faction_id==faction and c.play_style==mode,"actual selected campaign entered")
				await finish_events()
				check(not c.map_area.cutscene_input_locked and not c.end_turn_button.disabled,"campaign input restored")
				if faction=="silla" and mode=="historical": await capture("campaign_%d" % scenario.year)
				combinations+=1
	if not indices.is_empty(): check(combinations==24,"all selectable combinations entered via real setup")
	# Return to Silla 632 through normal settings contract for action screen tests.
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn")
	await settle()
	c=current_scene
	await finish_events()
	c.strategy.auto_fill_officer_shortages(c.strategy_state,c.year,c.provinces,c.officers_by_province,Scenarios.get_scenario(c.scenario_id))
	var id: String = ""
	for person: Dictionary in c.officer_registry.people.values():
		if person.origin=="generated" and person.faction_id=="silla": id=person.officer_id; break
	check(not id.is_empty(),"actual generated officer available")
	if not id.is_empty(): await generated_ui(id)
	print("OFFICER GUI TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func generated_ui(id: String) -> void:
	var city: String = c.get_officer(id).location
	c._on_city_card_detail_requested(city)
	await settle()
	var selected: int = -1
	for n: int in range(c.officer_list.item_count):
		if c.officer_list.get_item_metadata(n)==id: selected=n
	check(selected>=0,"detail item stores generated officer ID")
	if selected<0: return
	c.officer_list.select(selected)
	c.officer_list.item_selected.emit(selected)
	await capture("generated_details")
	await click(c.appoint_governor_button)
	check(c.get_governor_id(city)==id,"rendered appoint button installs generated governor")
	await capture("generated_governor")
	c._hide_province_detail()
	c._open_diplomacy()
	var d: Node = c.diplomacy_overlay
	d.selected_envoy_name=id
	d.selected_target_id="baekje"
	d.refresh()
	await settle()
	check(d.visible and c.map_area.modal_input_locked,"generated envoy screen locks map")
	await capture("generated_envoy")
	var before: int = c.gold
	await click(d.action_buttons.gift)
	check(c.gold==before-200,"rendered generated envoy gift charges once")
	await escape()
	check(not d.visible and not c.map_area.modal_input_locked,"envoy Esc restores map")
	c.select_province(city)
	c._on_transfer_button_pressed()
	var panel: Node = c.transfer_panel
	for n: int in range(panel.officer_list.item_count):
		if panel.officer_list.get_item_metadata(n)==id: panel.officer_list.select(n)
	panel.troop_spin.value=0
	var target: String = panel.destination_option.get_item_metadata(panel.destination_option.selected)
	await capture("generated_transfer")
	await click(panel.execute_button)
	check(c.governor_transfer_confirmation.visible,"governor transfer confirmation displayed")
	await click(c.governor_transfer_confirmation.get_ok_button())
	check(c.is_officer_transfer_pending(id) and not panel.visible,"rendered transfer executes and closes")
	var before_month: int = c.month
	await click(c.end_turn_button)
	await finish_events()
	check(c.month==before_month+1 and not c.is_officer_transfer_pending(id) and c.get_officer(id).location==target,"actual month button delivers generated officer")
	c._on_city_card_detail_requested(c.get_officer(id).location)
	await capture("generated_arrived")
	await escape()
	check(not c.province_panel.visible and not c.map_area.modal_input_locked and not c.map_area.cutscene_input_locked,"detail Esc restores map input")
