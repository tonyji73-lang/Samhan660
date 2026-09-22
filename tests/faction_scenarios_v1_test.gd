extends "res://tests/faction_selection_ui_v1_test.gd"
const ART_OUT="res://.godot/faction-scenarios-v1/"
var records: Array=[]
func art_shot(name: String) -> void:
	var e:=InputEventMouseMotion.new();e.position=Vector2(5,5);root.push_input(e,true)
	await pause();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ART_OUT+name+".png")
func _run() -> void:
	create_timer(600).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(ART_OUT)
	root.content_scale_size=Vector2i.ZERO
	await enter_setup()
	var jobs: Array=[]
	for scenario: Dictionary in Scenarios.SCENARIOS:
		var actual: Dictionary=Scenarios.get_scenario(str(scenario.id))
		for faction: Dictionary in actual.factions:
			if Scenarios.is_faction_playable_by_default(str(scenario.id),str(faction.id)):
				jobs.append({"scenario":str(scenario.id),"faction":str(faction.id),"year":int(scenario.year)})
	for job: Dictionary in jobs:
		await choose("scenario:"+job.scenario);await choose("faction:"+job.faction)
		var view: Control=setup.faction_view
		var data: Dictionary=setup._get_selected_faction_data()
		var art: Dictionary=view._model.art
		var start_id: String=Scenarios.get_starting_province(job.scenario,job.faction)
		check(art.get("profile_key","")!="","matched ruler art "+str(job))
		check(ResourceLoader.exists(str(art.portrait)) and ResourceLoader.exists(str(art.background)),"portrait/background resources")
		check(art.start_province_id==start_id and art.capital_uv==setup.selection_map_points[start_id],"actual start registration")
		check(view._model.leader==data.ruler and view._model.capital==data.capital,"live ruler/capital")
		for faction: Dictionary in setup._get_selected_scenario().factions:
			check(view._focus_controls["faction:"+str(faction.id)].disabled==not Scenarios.is_faction_playable_by_default(job.scenario,str(faction.id)),"lock preserved "+str(faction.id))
		for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=res;await pause()
			var marker: Control=view._stage.get_node("StartMarker")
			check(marker.z_index==1 and view._stage.get_node("StartMarkerLabel").text==art.capital_label,"marker above portrait and correct name")
			check(view._focus_controls.start.get_global_rect().end.y<=res.y,"start fits")
			await art_shot("%d-%d-%s" % [res.x,job.year,job.faction])
		records.append({"scenario":job.scenario,"year":job.year,"faction":job.faction,"ruler":data.ruler,"capital":data.capital,"start":start_id,"art":art})
		await choose("modes:fictional");await choose("difficulty:hard")
		await choose("start");await create_timer(3).timeout
		c=current_scene;c.event_presentation.display_level="minimal";await settle_events()
		check(c.scenario_id==job.scenario and c.player_faction_id==job.faction,"actual campaign identity")
		check(c.play_style=="fictional" and c.difficulty=="hard","actual campaign mode/difficulty")
		check(c._get_starting_province_id()==start_id and c.selected_province_id==start_id,"actual initial province")
		change_scene_to_file("res://new_game_setup.tscn");await create_timer(2).timeout;setup=current_scene
	# Synchronous rapid selection must not retain the prior art/marker.
	for id: String in ["baekje","goguryeo","silla"]: setup.faction_view.faction_requested.emit(id)
	check(setup.faction_view._model.faction_id=="silla" and setup.faction_view._model.art.profile_key=="632_silla","rapid selection coherent")
	await choose("back");await create_timer(2).timeout
	await click(current_scene.new_game_button);await create_timer(2).timeout;setup=current_scene
	check(setup.faction_view._model.art.profile_key=="632_silla","reopen approved 632")
	var f:=FileAccess.open(ART_OUT+"result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));f.close()
	print("SCENARIO ART: ",checks," checks, ",failures," failures; ",jobs.size()," campaigns")
	quit(0 if failures==0 else 1)
