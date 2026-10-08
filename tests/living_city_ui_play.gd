extends "res://tests/project_foundation_test.gd"

const REVIEW = "res://tests/living_city_review/"
var results: Dictionary = {}

func choose(ui: Node, id: String) -> void:
	for n: int in range(ui.selector.item_count):
		if str(ui.selector.get_item_metadata(n)) == id:
			ui.selector.select(n)
			ui.refresh_quote()
			return

func bounds(ui: Node) -> void:
	for button: Control in [ui.execute_button,ui.cancel_button,ui.close_button,ui.month_button]:
		check(Rect2(Vector2.ZERO,ui.size).encloses(button.get_global_rect()),"persistent control inside viewport: "+button.text)
	var panorama: Control = ui.find_child("CityPanorama",true,false)
	var panel: Control = ui.find_child("CityWorkPanel",true,false)
	check(is_equal_approx(panorama.size.x/ui.size.x,0.65) and is_equal_approx(panel.size.x/ui.size.x,0.35),"city and work panel retain 65/35 split")

func save_state() -> Array:
	return JSON.parse_string(JSON.stringify([c.gold,c.provinces,c.officer_registry,c.strategy_state.domestic]))

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(REVIEW+label+".png")==OK,"capture "+label)

func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(REVIEW)
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[1].id,"scenario_year":642,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn")
	await settle()
	c=current_scene
	await finish_events()
	c._on_city_card_detail_requested("geumseong")
	await click(c.settlement_overlay.buttons.domestic)
	var ui: Node = c.domestic_overlay
	await capture("domestic-1280")
	bounds(ui)
	var initial: Array = save_state()
	await click(ui.governor_button)
	check(ui.personnel_mode and c.map_area.modal_input_locked,"same-city personnel mode retains map lock")
	check(save_state()==initial,"opening personnel and quote leaves state unchanged")
	await capture("personnel-1280")
	bounds(ui)
	root.size = Vector2i(1920,1080)
	await capture("personnel-1920")
	await click(ui.cancel_button)
	await capture("domestic-1920")
	bounds(ui)
	root.size = Vector2i(2560,1440)
	await capture("domestic-2560")
	bounds(ui)
	root.size = Vector2i(1920,1080)
	if OS.get_cmdline_user_args().has("--visual-only"):
		print("LIVING CITY VISUAL CHECKS: %d checks, %d failures" % [checks,failures])
		quit(0 if failures==0 else 1)
		return
	check(save_state()==initial,"cancel candidate selection changes no resources or personnel")
	await escape()
	await click(c.settlement_overlay.buttons.politics)
	check(ui.visible and ui.personnel_mode,"atlas personnel navigation opens selected-city appointment")
	await click(ui.cancel_button)
	var officer: String = ui.selected_id()
	var q: Dictionary = c.get_domestic_quote("geumseong","agriculture",officer)
	check(q.ok,"normal 642 development candidate available")
	var gold: int = c.gold
	var agriculture: int = c.provinces.geumseong.agriculture
	await click(ui.execute_button)
	ui._execute()
	check(c.gold==gold-q.cost and ui.execute_button.disabled,"development cost charged once under repeated confirmation")
	check(not c.get_domestic_quote("geumseong","commerce",officer).ok,"conflicting development cannot reuse busy city and officer")
	check(c.provinces.geumseong.agriculture==agriculture,"development has no immediate completion")
	await capture("pending-1920")
	await click(ui.cancel_button)
	ui._cancel()
	check(c.gold==gold,"development cancellation refunds once")
	await click(ui.execute_button)
	var pending: Array = save_state()
	c._on_save_button_pressed(REVIEW+"pending.json")
	c._on_load_button_pressed(REVIEW+"pending.json")
	await settle()
	check(save_state()==pending,"save/load restores actual job, people, city and treasury")
	check(not ui.visible and not c.settlement_overlay.busy(),"load closes UI and unlocks active atlas")
	c._on_develop_button_pressed()
	await click(ui.month_button)
	await finish_events()
	check(c.month==2 and c.provinces.geumseong.agriculture==agriculture+q.gain,"normal next-month command completes quoted development")
	c._on_develop_button_pressed()
	check(ui.details.text.contains("개발 완료"),"reopened UI displays completion")
	results.development={"officer":officer,"cost":q.cost,"gain":q.gain,"agriculture_before":agriculture,"agriculture_after":c.provinces.geumseong.agriculture,"gold_after_acceptance":gold-q.cost}
	await capture("completed-1920")
	await click(ui.governor_button)
	var candidate: String = ""
	for n: int in range(ui.selector.item_count):
		var id: String = str(ui.selector.get_item_metadata(n))
		var quote: Dictionary = ui.Personnel.quote(c,c.player_faction_id,"governor","geumseong",id)
		var power: Dictionary = c.Power.quote(c,{"kind":"governor","target":"geumseong","officer_id":id,"faction_id":c.player_faction_id})
		if quote.ok and power.ok and not power.get("required",false): candidate=id; break
	check(not candidate.is_empty(),"normal local governor candidate requires no rule override")
	choose(ui,candidate)
	var before_appointment: Array = save_state()
	ui.refresh_quote()
	check(save_state()==before_appointment,"governor forecast is read-only")
	check(ui.governor_label.text.contains(c.get_officer(candidate).name) and ui.governor_portrait.texture==ui._texture(candidate),"large portrait follows the selected candidate")
	var old: String = c.get_governor_id("geumseong")
	var tax_before: int = c.city_operation_quote("geumseong").tax
	await capture("appointment-preview-1920")
	await click(ui.execute_button)
	check(c.get_governor_id("geumseong")==candidate,"UI appointment changes actual governor")
	var appointed: Array = save_state()
	ui._execute()
	check(save_state()==appointed,"repeated appointment does not repeat political effects")
	results.appointment={"previous":old,"appointed":candidate,"tax_before":tax_before,"tax_after":c.city_operation_quote("geumseong").tax}
	c._on_save_button_pressed(REVIEW+"appointed.json")
	c._on_load_button_pressed(REVIEW+"appointed.json")
	check(save_state()==appointed,"appointment and politics persist through save/load")
	for n: int in range(3):
		c._on_develop_button_pressed()
		await escape()
		check(not ui.visible and not c.settlement_overlay.busy(),"repeated open/Esc unlocks active atlas")
	c._on_develop_button_pressed()
	await click(ui.navigation.industry)
	check(c.production_overlay.visible and not ui.visible,"construction and military production remain accessible")
	await escape()
	c._on_develop_button_pressed()
	await click(ui.navigation.diplomacy)
	check(c.diplomacy_overlay.visible and not ui.visible,"diplomacy remains accessible")
	await escape()
	# Isolated edge fixtures after the unmodified normal campaign path.
	c._on_develop_button_pressed()
	var balance: int = c.gold
	c.gold=0; ui.refresh()
	check(ui.execute_button.disabled and ui.status.text.contains("금"),"zero-gold UI shows the actual rejection")
	c.gold=balance
	var registry: Dictionary = c.officer_registry.duplicate(true)
	for person: Dictionary in c.officer_registry.people.values():
		if person.active and person.alive and person.faction_id==c.player_faction_id and person.location!="geumseong":
			person.location="geumseong"
			break
	ui._set_mode(true)
	check(ui.candidate_row.get_child_count()>3,"all candidates remain available beyond three portraits")
	var last_card: Node = ui.candidate_row.get_child(ui.candidate_row.get_child_count()-1)
	await click(last_card.get_child(1))
	check(ui.selected_id()==str(last_card.get_child(1).get_meta("officer_id")),"horizontal scroll can select the last candidate")
	ui.cancel_button.grab_focus()
	check(ui.cancel_button.has_focus(),"candidate cancellation has keyboard focus")
	for id: String in c.get_city_officer_ids("geumseong"):
		c.officer_registry.people[id].active=false
	ui._set_mode(true)
	check(ui.selector.item_count==0 and ui.execute_button.disabled,"empty candidate UI disables confirmation")
	await click(ui.cancel_button)
	check(not ui.personnel_mode,"empty candidate state can be cancelled")
	c.officer_registry.clear(); c.officer_registry.merge(registry,true)
	c.officer_registry.posts.erase("governor:geumseong")
	ui.refresh()
	check(ui.governor_label.text.contains("공석"),"vacant governor is shown explicitly")
	await escape()
	check(not c.settlement_overlay.busy(),"edge fixtures leave active atlas unlocked")
	c.settlement_overlay.select_city("dalgubeol")
	await click(c.settlement_overlay.buttons.domestic)
	check(ui.city=="dalgubeol" and ui.city_title.text.contains(c.provinces.dalgubeol.name),"city switch refreshes context and candidates")
	check(not ui.city_art.visible,"Seorabeol art is not reused for another city")
	await click(ui.close_button)
	check(not c.settlement_overlay.busy(),"close button unlocks atlas after city switch")
	var output := FileAccess.open(REVIEW+"results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(results,"\t")); output.close()
	print("LIVING CITY TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
