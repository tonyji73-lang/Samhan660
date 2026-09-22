extends "res://tests/faction_selection_ui_v1_test.gd"

const DECLARATION_OUT = "res://.godot/declarations-v1/"

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DECLARATION_OUT + label + ".png")

func _run() -> void:
	create_timer(300).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(DECLARATION_OUT)
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	await enter_setup()
	var catalog = setup.faction_view._declaration_catalog
	check(catalog._entries.size()==16,"16 source entries")
	for entry: Dictionary in catalog._entries.values():
		var scenario: Dictionary=Scenarios.get_scenario(entry.scenario_id_reference)
		var matched: bool=false
		for faction: Dictionary in scenario.factions:
			if faction.id==entry.faction_id_reference:
				matched=faction.ruler==entry.ruler
		check(matched,"actual scenario/faction/ruler: "+str(entry.key))
	check(catalog.find_declaration("missing","silla").is_empty(),"no faction-only fallback")
	var count: int=0
	for scenario: Dictionary in Scenarios.SCENARIOS:
		await choose("scenario:"+str(scenario.id))
		for faction: Dictionary in Scenarios.get_scenario(str(scenario.id)).factions:
			var playable: bool=Scenarios.is_faction_playable_by_default(str(scenario.id),str(faction.id))
			check(setup.faction_view._focus_controls["faction:"+str(faction.id)].disabled==not playable,"lock preserved")
			if not playable: continue
			await choose("faction:"+str(faction.id))
			var d = setup.faction_view._declaration_view
			check(d._entry.key==str(scenario.id)+"/"+str(faction.id),"correct declaration")
			var old_time: float=d._elapsed
			setup.faction_view.difficulty_requested.emit("hard")
			d=setup.faction_view._declaration_view
			check(is_equal_approx(d._elapsed,old_time),"difficulty retains progress")
			setup.faction_view.mode_requested.emit("fictional")
			d=setup.faction_view._declaration_view
			check(is_equal_approx(d._elapsed,old_time),"mode retains progress")
			await create_timer(5).timeout
			check(is_equal_approx(d._elapsed,d._duration),"natural reveal complete including seal")
			var previous: Dictionary={}
			for glyph: Dictionary in d._glyphs:
				check(glyph.position.x>=0 and glyph.position.x+glyph.width<=d.size.x and glyph.position.y<=d._seal_box.position.y,"glyph fits paper")
				if not previous.is_empty():
					check(glyph.at>previous.at and (glyph.position.x<previous.position.x or (is_equal_approx(glyph.position.x,previous.position.x) and glyph.position.y>previous.position.y)),"right-left top-bottom reveal")
				previous=glyph
			for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
				root.size=res;await pause()
				check(is_equal_approx(d._elapsed,d._duration),"resize keeps completed declaration")
				await shot("%d-%d-%s"%[res.x,scenario.year,faction.id])
			count+=1
	# Rapid changes must reset only the new entity, never restore another ruler's text.
	for i: int in [0,1,2,3]:
		setup.faction_view.scenario_requested.emit(str(Scenarios.SCENARIOS[i].id))
		setup.faction_view.faction_requested.emit("goguryeo")
		var d=setup.faction_view._declaration_view
		check(d._entry.key==str(Scenarios.SCENARIOS[i].id)+"/goguryeo" and d._elapsed==0.0,"rapid new declaration resets")
	await choose("back");await create_timer(1).timeout
	await click(current_scene.new_game_button);await create_timer(1).timeout;setup=current_scene
	check(setup.faction_view._declaration_view._entry.key=="silla_equilibrium_632/silla","reopen new screen")
	await choose("scenario:"+str(Scenarios.SCENARIOS[1].id))
	await choose("start");await create_timer(3).timeout
	c=current_scene
	check(c.scenario_id==Scenarios.SCENARIOS[1].id and c.player_faction_id=="silla","campaign starts during reveal")
	print("DECLARATIONS: ",checks," checks, ",failures," failures; ",count," selections at two resolutions")
	quit(0 if failures==0 else 1)
