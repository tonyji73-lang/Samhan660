extends "res://tests/industry_assignment_gui_test.gd"
func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; c._open_diplomacy(); await settle(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/living_city_v1_8_review/before-diplomacy-"+str(resolution.y)+".png")
	print("V1.8 BEFORE CAPTURE COMPLETE"); quit()

