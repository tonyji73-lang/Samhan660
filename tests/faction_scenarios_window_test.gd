extends "res://tests/faction_selection_ui_v1_test.gd"
func _run() -> void:
	create_timer(90).timeout.connect(func():quit(2))
	root.content_scale_size=Vector2i.ZERO
	await enter_setup()
	await choose("scenario:"+str(Scenarios.SCENARIOS[1].id));await choose("faction:goguryeo")
	var selected: Dictionary=setup.faction_view.current_selection()
	root.mode=Window.MODE_FULLSCREEN;await create_timer(1).timeout
	check(setup.faction_view.current_selection()==selected,"fullscreen selection preserved")
	check(setup.faction_view._stage.get_node("StartMarkerLabel").text==setup.faction_view._model.art.capital_label,"fullscreen marker coherent")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/faction-scenarios-v1/fullscreen-642-goguryeo.png")
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);await create_timer(1).timeout
	check(setup.faction_view.current_selection()==selected and setup.faction_view._stage.scale.is_equal_approx(Vector2.ONE*2.0/3.0),"window resize preserves selection and aspect")
	print("SCENARIO WINDOW: ",checks," checks, ",failures," failures");quit(0 if failures==0 else 1)
