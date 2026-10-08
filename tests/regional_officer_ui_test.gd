extends "res://tests/settlement_ui_test.gd"
const REVIEW := "res://.godot/officer-distribution-review/"
func click(button: Control) -> void:
	var ancestor: Node=button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await pause()
		ancestor=ancestor.get_parent()
	await super.click(button)
func capture_officers(label: String) -> void:
	await pause()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(REVIEW+label+".png") == OK,"capture "+label)
func card_button(card: Node, id: String) -> Button:
	for node: Node in card.find_children("*","Button",true,false):
		if node.get_meta("officer_id","") == id: return node
	return null
func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	await settle_events()
	var catalog = preload("res://officer_catalog.gd")
	var portraits := 0
	var regions: Dictionary = {}
	var valid := true
	for person: Dictionary in catalog.definitions().values():
		if person.origin != "fictional": continue
		var texture: Texture2D = c.map_area._get_portrait_texture(person.display_name)
		var key: String = str(person.portrait.atlas)+":"+str(person.portrait.cell)
		valid = valid and texture is AtlasTexture and not regions.has(key)
		if texture is AtlasTexture:
			valid = valid and texture.region.size.x >= 300 and Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region)
		regions[key] = true
		portraits += 1
	check(valid and portraits == 190,"all 190 real portrait resources load with unique in-bounds atlas regions")
	ui = c.settlement_overlay
	if not ui.visible: await click(c.settlement_button)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		await pause()
		ui.select_city("dalgubeol")
		await click(ui.buttons.domestic)
		var panel: Control = c.domestic_overlay
		check(panel.visible and panel.selector.item_count >= 2,"previously empty city has actual candidates")
		check(panel.governor_portrait.texture is AtlasTexture,"new local governor has individual portrait")
		check(c.get_officer(c.get_governor_id("dalgubeol")).loyalty==50,"fictional initial loyalty uses existing default")
		check(panel.hero_context.text.contains(c.get_officer(c.get_governor_id("dalgubeol")).character_type),"military/civil classification displayed")
		var before: Dictionary=full_state()
		var original: String=panel.selected_id()
		await click(panel.choose_button)
		await capture_officers(str(resolution.x)+"-candidates")
		check(panel.choosing_officer and panel.picker_cards.get_child_count()==panel.selector.item_count,"all local candidates have cards")
		await click(panel.cancel_button)
		check(not panel.choosing_officer and panel.selected_id()==original and full_state()==before,"cancel preserves candidate and complete campaign")
		await click(panel.choose_button)
		var id: String=str(panel.selector.get_item_metadata(1))
		var card: Control=panel.picker_cards.get_child(1)
		panel.picker_scroll.ensure_control_visible(card)
		await pause()
		await click(card_button(card,id))
		check(panel.selected_id()==id and not panel.choosing_officer and full_state()==before,"card selection updates preview without spending")
		await capture_officers(str(resolution.x)+"-domestic")
		await click(panel.governor_button)
		check(panel.personnel_mode,"actual button opens appointment mode")
		panel.work_scroll.scroll_vertical=0
		await capture_officers(str(resolution.x)+"-governor")
		check(panel.execute_button.get_global_rect().end.y < resolution.y-80 and panel.close_button.get_global_rect().end.y < resolution.y-80,"confirmation and cancel stay above footer")
		check(panel.governor_portrait.texture is AtlasTexture and panel.candidate_row.get_child_count()==panel.selector.item_count,"appointment uses same individual portraits")
		await escape()
		check(not panel.visible and ui.visible and not ui.map.input_locked,"Esc returns map input")
	ui.select_city("dalgubeol")
	await click(ui.buttons.domestic)
	var panel: Control=c.domestic_overlay
	await click(panel.governor_button)
	panel.selector.select(1)
	panel.refresh_quote()
	var id: String=panel.selected_id()
	check(not panel.execute_button.disabled,"fictional governor appointment available")
	await click(panel.execute_button)
	check(c.get_governor_id("dalgubeol")==id,"fictional governor confirmed through actual button")
	await click(panel.governor_button)
	var quote: Dictionary=c.get_domestic_quote("dalgubeol","agriculture",id)
	check(quote.ok,"fictional governor has valid development quote")
	var gold_before: int=c.gold
	await click(panel.execute_button)
	var job: Dictionary=c.Domestic.active_job(c.strategy_state,"dalgubeol")
	check(not job.is_empty() and job.get("officer_id","")==id and c.gold<gold_before,"fictional officer starts paid development through GUI")
	var paid: int=c.gold
	panel._execute()
	check(c.gold==paid,"repeat confirmation does not charge twice")
	panel.hide()
	var path: String=REVIEW+"fictional-active-job.json"
	var state: Dictionary=full_state()
	c._on_save_button_pressed(path)
	c._on_load_button_pressed(path)
	check(full_state()==state and c.get_officer(id).character_type==catalog.definitions()[id].character_type,"new slot restores fictional profile, portrait metadata, assignment and job")
	for turn: int in range(8):
		if c.Domestic.active_job(c.strategy_state,"dalgubeol").is_empty(): break
		c._on_end_turn_button_pressed()
		await process_frame
		await settle_events()
	check(c.Domestic.active_job(c.strategy_state,"dalgubeol").is_empty(),"normal month progression completes fictional officer development")
	for faction: String in ["baekje","goguryeo"]:
		await start(Scenarios.SCENARIOS[0],faction,"historical")
		await settle_events()
		var city: String=""
		for key: String in c.provinces:
			if c.provinces[key].faction==c.player_faction and c.get_governor_id(key).begins_with("fictional:"):
				city=key; break
		check(not city.is_empty(),faction+" has newly staffed local cities")
		ui=c.settlement_overlay
		if not ui.visible: await click(c.settlement_button)
		ui.select_city(city)
		await click(ui.buttons.domestic)
		check(c.domestic_overlay.governor_portrait.texture is AtlasTexture,faction+" local portrait shown")
		await capture_officers(faction+"-local-governor")
		await escape()
	# Shared container regression: original ruler portrait and historical cards.
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	await settle_events()
	ui=c.settlement_overlay
	if not ui.visible: await click(c.settlement_button)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		await pause()
		ui.select_city("geumseong")
		await click(ui.buttons.domestic)
		panel=c.domestic_overlay
		state=full_state()
		await click(panel.governor_button)
		var queen_button: Button
		for card: Node in panel.candidate_row.get_children():
			var possible: Button=card_button(card,"historical:001")
			if possible!=null: queen_button=possible
		check(queen_button!=null,"original ruler remains an available candidate")
		await click(queen_button)
		check(panel.selected_id()=="historical:001" and panel.governor_portrait.texture is AtlasTexture and full_state()==state,"original queen portrait framing and read-only selection preserved")
		check(panel.execute_button.get_global_rect().end.y<resolution.y-80,"historical confirm remains visible")
		panel.work_scroll.scroll_vertical=0
		await capture_officers(str(resolution.x)+"-historical-governor")
		var scroll_point: Vector2=panel.work_scroll.get_global_rect().get_center()
		await mouse(scroll_point,MOUSE_BUTTON_WHEEL_DOWN,true)
		await mouse(scroll_point,MOUSE_BUTTON_WHEEL_DOWN,false)
		await pause()
		check(panel.work_scroll.scroll_vertical>0 or panel.work_scroll.get_v_scroll_bar().max_value<=panel.work_scroll.size.y,"long detail supports actual wheel scrolling")
		panel.close_button.grab_focus()
		for down: bool in [true,false]:
			var key_event:=InputEventKey.new(); key_event.keycode=KEY_ENTER; key_event.pressed=down; root.push_input(key_event,true)
		await pause()
		check(not panel.visible and ui.visible and not ui.map.input_locked and full_state()==state,"keyboard close preserves campaign and restores map")
	print("FICTIONAL OFFICER GUI: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)