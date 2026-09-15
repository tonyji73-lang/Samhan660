extends SceneTree

const Campaign = preload("res://campaign_main.tscn")
const Presentation = preload("res://cutscenes/event_presentation.gd")
const Preview = preload("res://tests/cutscene_preview.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func snapshot(c: Node) -> Dictionary:
	return JSON.parse_string(JSON.stringify({"provinces": c.provinces, "strategy": c.strategy_state, "gold": c.gold, "year": c.year, "month": c.month}))


func finish_scene(p: Node) -> void:
	var guard: int = 0
	while p.active and guard < 20:
		p.next()
		guard += 1


func _run() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	for faction: String in ["silla", "baekje", "goguryeo"]:
		root.set_meta("new_game_settings", {"scenario_id": "baekje_fall_660", "scenario_year": 660, "scenario_season": "summer", "faction": faction})
		var c: Node = Campaign.instantiate()
		root.add_child(c)
		current_scene = c
		await process_frame
		await process_frame
		var p: Node = c.event_presentation
		check(p.active and p.current.id == faction + "_660_intro", faction + " actual new-game opening")
		check(not p.auto_play, faction + " automatic advance initially off")
		var before: Dictionary = snapshot(c)
		var selected: String = c.selected_province_id
		c._on_end_turn_button_pressed()
		c.select_province("sabi")
		check(snapshot(c) == before and selected == c.selected_province_id, faction + " turn and city commands locked")
		check(c.map_area.cutscene_input_locked and c.end_turn_button.disabled, faction + " map and turn UI locked")
		var path: String = OS.get_temp_dir().path_join("samhan-cutscene-%d-%s.json" % [OS.get_process_id(), faction])
		c._on_save_button_pressed(path)
		p.skip()
		check(not p.active and not c.map_area.cutscene_input_locked and not c.end_turn_button.disabled, faction + " skip restores input")
		c._on_load_button_pressed(path)
		check(not p.active and not p.play(faction + "_660_intro"), faction + " save during opening suppresses replay")
		check(snapshot(c) == before, faction + " skip/load do not grant resources")
		DirAccess.remove_absolute(path)
		p.restore_state({})
		p.play(faction + "_660_intro")
		p.next()
		check(p.step_index == 0 and p.view.body_label.visible_characters == p.view.body_label.text.length(), faction + " first Next reveals text")
		p.next()
		check(p.step_index == 1 and p.view.left_portrait.texture != null, faction + " dialogue uses existing portrait")
		finish_scene(p)
		check(not p.active and snapshot(c) == before, faction + " all steps finish without effects")
		c.queue_free()
		await process_frame
		await process_frame
	var c: Node = Campaign.instantiate()
	root.add_child(c)
	current_scene = c
	await process_frame
	await process_frame
	var p: Node = c.event_presentation
	check(not p.active, "F6/legacy initialization does not invent an opening")
	check(p.events.size() == 7, "single catalog contains existing events and crop failure")
	check(not p.play("unknown") and not p.play("domestic_bountiful_harvest"), "unknown event and missing dynamic data fail without locking")
	for id: String in p.events:
		for step: Dictionary in p.events[id].steps:
			for key: String in ["background", "portrait", "left_portrait", "right_portrait"]:
				if step.has(key):
					var base: String = p.catalog.asset_root if key == "background" else p.catalog.portrait_root
					check(ResourceLoader.exists(base + str(step[key])), id + " " + key + " resource exists")
			var camera: Dictionary = step.get("camera", {})
			for key: String in ["target", "from", "to"]:
				if camera.has(key) and not str(camera[key]).begins_with("{"):
					check(not p.adapter.city_ids(str(camera[key])).is_empty(), id + " camera target resolves")
	var before: Dictionary = snapshot(c)
	var original_zoom: float = c.map_area.map_zoom
	var original_pan: Vector2 = c.map_area.map_pan_offset
	p.play("domestic_bountiful_harvest", {"province_name": "금관가야", "grain_delta": 777, "public_order_delta": 4}, "harvest-fixture-1")
	check(p.view.body_label.text.contains("금관가야"), "dynamic province name")
	p.next()
	p.next()
	check(p.view.body_label.text.contains("+777") and p.view.body_label.text.contains("+4"), "dynamic grain and public order")
	p.skip()
	check(not p.play("domestic_bountiful_harvest", Preview.PAYLOADS.domestic_bountiful_harvest, "harvest-fixture-1"), "same occurrence cannot replay")
	check(snapshot(c) == before, "presentation never applies a displayed harvest reward")
	var preview_payload: Dictionary = Preview.PAYLOADS.domestic_bountiful_harvest.duplicate(true)
	p.play("domestic_bountiful_harvest", preview_payload)
	p.next()
	p.next()
	check(p.view.body_label.text.contains("치안 100 · 최대치") and not p.view.body_label.text.contains("+0"), "zero-order preview displays maximum caption")
	p.skip()
	check(preview_payload.public_order_delta == 0 and snapshot(c) == before, "maximum caption changes neither payload nor campaign rewards")
	p.play("enemy_invasion_alert", Preview.PAYLOADS.enemy_invasion_alert)
	check(p.current.steps[0].camera.target == "sabi" and p.adapter.effects.size() == 1, "invasion target and pulse are data driven")
	await create_timer(0.1).timeout
	check(c.map_area.map_zoom != original_zoom or c.map_area.map_pan_offset != original_pan, "map camera animates")
	p.open_menu()
	var elapsed: float = p.step_elapsed
	p._process(5.0)
	check(p.menu_open() and p.step_elapsed == elapsed, "pause menu remains available and pauses advance")
	c.navigation_menu.get_popup().hide()
	p.skip()
	check(is_equal_approx(c.map_area.map_zoom, original_zoom) and c.map_area.map_pan_offset.is_equal_approx(original_pan) and p.adapter.effects.is_empty(), "skip restores camera and removes pulses")
	p.play("battle_hwangsanbeol", Preview.PAYLOADS.battle_hwangsanbeol)
	check(p.view.left_portrait.texture != null and p.view.right_portrait.texture != null and p.view.versus_label.text.contains("김유신") and p.view.versus_label.text.contains("계백"), "battle versus portraits and names")
	p.set_auto(true)
	p._process(4.1)
	check(p.step_index == 1 and p.view.title_label.text == "대승" and p.view.body_label.text.contains("-2800") and p.view.body_label.text.contains("-9100"), "automatic battle result with dynamic losses")
	p._process(5.1)
	check(not p.active and not p.auto_play, "automatic finish restores input and resets auto")
	p.skip()
	p.next()
	check(snapshot(c) == before, "repeated next/skip after finish never applies effects")
	p.display_level = "major"
	p.play("domestic_bountiful_harvest", Preview.PAYLOADS.domestic_bountiful_harvest)
	check(not p.active, "major policy filters normal events")
	p.play("enemy_invasion_alert", Preview.PAYLOADS.enemy_invasion_alert)
	check(p.active, "major policy retains alerts")
	p.skip()
	p.display_level = "minimal"
	p.play("silla_660_intro")
	check(not p.active and p.completed_ids.has("silla_660_intro"), "minimal policy records once-only opening")
	p.restore_state({})
	p.play("enemy_invasion_alert", Preview.PAYLOADS.enemy_invasion_alert)
	p.play("battle_hwangsanbeol", Preview.PAYLOADS.battle_hwangsanbeol)
	p.skip()
	check(p.active and p.current.id == "battle_hwangsanbeol" and c.end_turn_button.disabled, "queued events preserve input lock")
	p.restore_state({})
	check(not p.active and p.queue.is_empty() and not c.map_area.cutscene_input_locked, "load cancels queue without executing it")
	# A real AI simulation result is committed once, then only displayed.
	c.resolve_ai_attack("ungjin", "gukwon")
	var after_combat: Dictionary = snapshot(c)
	await process_frame
	check(p.active and p.current.id == "enemy_invasion_alert", "actual AI attack dispatches invasion alert")
	p.skip()
	check(snapshot(c) == after_combat, "skipping real alert preserves exactly one combat result")
	# Test fixtures only: put the existing two commanders in isolated armies.
	for city: String in ["geumseong", "geumgwan"]:
		for id: String in c.get_city_officer_ids(city): c.OfficerRegistry.set_location(c.officer_registry,id,"")
	c.OfficerRegistry.set_location(c.officer_registry,"김유신","geumseong")
	c.provinces.geumgwan.faction="백제"
	for uid: String in c.Army.at_city(c.strategy_state,"geumgwan"): c.Army.units(c.strategy_state)[uid].faction_id="baekje"
	c.OfficerRegistry.set_location(c.officer_registry,"계백","geumgwan")
	c.resolve_attack("geumseong", "geumgwan")
	after_combat = snapshot(c)
	await process_frame
	check(p.active and p.current.id == "battle_hwangsanbeol", "existing combat matches catalog commander trigger")
	p.skip()
	check(snapshot(c) == after_combat, "battle skip does not apply casualties or capture again")
	p.play("enemy_invasion_alert", Preview.PAYLOADS.enemy_invasion_alert)
	await create_timer(2.1).timeout
	check(p.adapter.camera_tween == null, "completed camera tween is retired without being replayed")
	p.open_menu()
	p._process(1.0)
	c.navigation_menu.get_popup().hide()
	p._process(0.1)
	p.skip()
	check(not p.active and not c.map_area.cutscene_input_locked, "menu after camera completion also restores input")
	p.play("domestic_bountiful_harvest", Preview.PAYLOADS.domestic_bountiful_harvest, "persisted-harvest")
	p.skip()
	var saved: Dictionary = p.export_state()
	p.restore_state(JSON.parse_string(JSON.stringify(saved)))
	check(p.occurrence_ids.has("persisted-harvest") and not p.play("domestic_bountiful_harvest", Preview.PAYLOADS.domestic_bountiful_harvest, "persisted-harvest"), "occurrence history round trips")
	p.restore_state({})
	c.queue_free()
	await process_frame
	await process_frame
	print("CUTSCENE TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
