extends "res://tests/project_foundation_test.gd"

const ECONOMY_OUT="res://.godot/economy-results/"

func screen(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ECONOMY_OUT+label+".png")==OK,"capture "+label)

func _run() -> void:
	create_timer(100).timeout.connect(func(): push_error("ECONOMY GUI TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(ECONOMY_OUT)
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[1].id,"scenario_year":642,"scenario_season":Scenarios.SCENARIOS[1].season})
	change_scene_to_file("res://campaign_main.tscn")
	await settle(); c=current_scene
	await finish_events()
	c._on_city_card_detail_requested("geumseong")
	await click(c.recruit_button)
	var panel: Node=c.recruitment_overlay
	check(panel.visible and c.map_area.modal_input_locked and panel.quantity.value==1000,"existing recruit button opens default1000 with map locked")
	check(panel.details.text.contains("금 150") and panel.details.text.contains("군량 200"),"visible default quote from shared validator")
	await screen("recruit_quote_642")
	panel.quantity.value=300
	check(panel.details.text.contains("금 45") and panel.details.text.contains("군량 60"),"quantity edit refreshes exact100-unit quote")
	var troops: int=c.provinces.geumseong.troops
	var grain: int=c.provinces.geumseong.food_stock
	await click(panel.execute_button)
	check(c.gold==955 and c.provinces.geumseong.food_stock==grain-60 and c.provinces.geumseong.troops==troops+300,"real confirm button pays quote once")
	await screen("recruit_paid_642")
	await escape()
	check(not panel.visible and not c.map_area.modal_input_locked,"Esc restores map")
	await click(c.end_turn_button); await finish_events()
	check(c.month==8 and c.gold_label.tooltip_text.contains("수입"),"actual month updates treasury and ledger breakdown")
	await click(c.recruit_button)
	check(panel.details.text.contains("국가 원장") and panel.details.text.contains("태수"),"settlement and governor breakdown visible")
	await screen("treasury_settlement_642")
	c._on_save_button_pressed(ECONOMY_OUT+"gui-save.json")
	c._on_load_button_pressed(ECONOMY_OUT+"gui-save.json")
	await settle()
	check(not panel.visible and not c.map_area.modal_input_locked,"load closes recruitment and restores map")
	await click(c.recruit_button)
	c._open_diplomacy()
	check(not panel.visible and c.diplomacy_overlay.visible,"recruitment to diplomacy restores one modal")
	await escape()
	await click(c.recruit_button)
	c._on_develop_button_pressed()
	check(not panel.visible and c.domestic_overlay.visible,"recruitment to domestic has one modal")
	await escape()
	await click(c.recruit_button)
	await click(panel.close_button)
	check(not c.map_area.modal_input_locked,"close restores input")
	print("FACTION ECONOMY GUI TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
