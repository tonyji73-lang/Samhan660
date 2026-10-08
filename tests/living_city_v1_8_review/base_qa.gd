extends Node
## Opt-in packaged QA only. Normal launch removes this node immediately.
var c: Node
var root: Window
var checks := 0
var failures := 0
var out := ""
var phase := "prepare"
var slot := ""
var evidence: Dictionary = {}

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--qa-v1-8"):
		queue_free(); return
	root = get_tree().root
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(1200).timeout.connect(func(): finish(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout

func capture(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join(label+".png")) == OK, "capture "+label)

func click(control: Control) -> void:
	await settle()
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await settle()
	var point := control.get_global_transform_with_canvas() * (control.size / 2)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point
		root.push_input(event,true)
	await settle()

func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.pressed=down; root.push_input(event,true)
	await settle()

func events() -> void:
	for index: int in range(45):
		var e: Node = c.event_presentation
		if not e.active: break
		if e.awaiting_choice():
			if e.current.steps[e.step_index].get("mode","") == "choice": await click(e.view.choice_buttons.maintain_tax)
			else: e.view.next_button.pressed.emit(); await settle()
		else: e.skip(); await settle()
	if c.merit_overlay.visible: await key(KEY_ESCAPE)

func month() -> void:
	await events()
	var before: int = c.year*12+c.month
	await click(c.settlement_overlay.buttons.month); await events()
	check(c.year*12+c.month == before+1, "actual month advances")

func pick(selector: OptionButton, id: String) -> void:
	for i: int in range(selector.item_count):
		if str(selector.get_item_metadata(i)) == id:
			selector.select(i); selector.item_selected.emit(i); return

func snapshot() -> Dictionary:
	return JSON.parse_string(JSON.stringify({"year":c.year,"month":c.month,"gold":c.gold,"provinces":c.provinces,"strategy":c.OfficerRegistry.export_strategy(c.strategy_state)}))

func finish(code: int = -1) -> void:
	var file := FileAccess.open(out.path_join(phase+"-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"exe":OS.get_executable_path(),"user_dir":OS.get_user_data_dir(),"slot":slot,"evidence":evidence},"\t")); file.close()
	print("EXPORT V1.8 ",phase,": ",checks," checks, ",failures," failures")
	get_tree().quit(code if code >= 0 else (0 if failures == 0 else 1))

func states(button: Button, label: String) -> void:
	button.grab_focus(); await settle()
	check(button.has_focus(),label+" keyboard focus")
	await capture(label+"-focus-"+str(root.size.y))
	await key(KEY_TAB)
	check(root.gui_get_focus_owner()!=button,label+" Tab moves focus")
	var motion := InputEventMouseMotion.new(); motion.position=button.get_global_transform_with_canvas()*(button.size/2); root.push_input(motion,true)
	await capture(label+"-hover-"+str(root.size.y))
	var press := InputEventMouseButton.new(); press.position=motion.position; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; root.push_input(press,true)
	await capture(label+"-pressed-"+str(root.size.y))
	motion.position=Vector2(2,2); root.push_input(motion,true)
	press=InputEventMouseButton.new(); press.position=Vector2(2,2); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=false; root.push_input(press,true)
	await settle()

func visuals() -> void:
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size; await settle()
		c.select_province("geumseong",false); c.open_domestic("agriculture"); await settle()
		var d: Node=c.domestic_overlay
		var previous: Dictionary=snapshot()
		await capture("domestic-"+str(size.y))
		var panorama: Control=d.find_child("CityPanorama",true,false)
		check(is_equal_approx(panorama.size.x/d.size.x,0.65),"domestic 65 percent")
		await states(d.execute_button,"development")
		await click(d.choose_button); await capture("officers-"+str(size.y))
		check(d.choosing_officer and d.picker_cards.get_child_count()>0,"real officer cards")
		d.picker_scroll.scroll_vertical=10000; await settle()
		await click(d.cancel_button)
		check(snapshot()==previous and not d.choosing_officer,"cancel no state mutation")
		await click(d.choose_button); await key(KEY_ESCAPE)
		check(d.visible and not d.choosing_officer,"Esc returns from picker")
		await click(d.governor_button); await capture("governor-"+str(size.y))
		check(d.governor_portrait.texture!=null,"portrait loaded")
		d.detail_scroll.scroll_vertical=10000; await settle(); await capture("governor-scroll-"+str(size.y))
		await click(d.cancel_button); await key(KEY_ESCAPE)
		check(not c.settlement_overlay.busy(),"domestic Esc restores map")
		c._on_city_card_production_requested("geumseong"); await capture("production-"+str(size.y))
		var p: Node=c.production_overlay
		p.scroll_container.scroll_vertical=10000; await capture("production-scroll-"+str(size.y))
		check(p.scroll_container.scroll_vertical>0,"production internal scroll")
		await click(p.close_button)
		for kind: String in ["build","research"]:
			c.open_industry("geumseong",kind,"forge" if kind=="build" else "swordsmithing")
			var panel: Node=c.industry_overlay
			panel.officer_selector.select(0); panel.officer_selector.item_selected.emit(0)
			check(panel.execute_button.disabled,"unselected worker disables "+kind)
			await capture(kind+"-disabled-"+str(size.y))
			panel.officer_selector.select(1); panel.officer_selector.item_selected.emit(1)
			await capture(kind+"-"+str(size.y))
			await states(panel.execute_button,kind)
			check(Rect2(Vector2.ZERO,panel.size).encloses(panel.close_button.get_global_rect()),"close in viewport "+kind)
			await key(KEY_ESCAPE)
			check(not c.settlement_overlay.busy(),"Esc restores map "+kind)
		check(snapshot()==previous,"all previews leave campaign untouched")
	root.size=Vector2i(1280,720)

func accept(city: String, kind: String, target: String, worker: String) -> Dictionary:
	c.open_industry(city,kind,target); var panel: Node=c.industry_overlay
	pick(panel.officer_selector,worker); await settle()
	check(not panel.execute_button.disabled,"normal available "+kind+" "+target)
	await click(panel.execute_button)
	var job: Dictionary=panel.job().duplicate(true)
	check(not job.is_empty(),"accepted "+kind+" "+target)
	await capture(kind+"-accepted-"+target)
	await key(KEY_ESCAPE)
	return job

func wait_job(kind: String, city: String) -> void:
	for i: int in range(14):
		if c.Industry.active(c.strategy_state,kind,city,"silla").is_empty(): break
		await month()
	check(c.Industry.active(c.strategy_state,kind,city,"silla").is_empty(),"completed "+kind)

func resources() -> void:
	check(not ProjectSettings.has_setting("autoload/_mcp_game_helper"),"editor helper absent")
	for path: String in ["data/officers_v1.json","cutscenes/cutscene_catalog_v1.json","ui/faction_selection_v1/layout.json","ui/faction_declaration_v1/declarations.json","ui/korea_layout_v1/full_r3_v1/manifest.json","licenses/NanumMyeongjo-OFL.txt","licenses/SamhanUISans-OFL.txt","licenses/GODOT-LICENSE.txt"]:
		check(FileAccess.file_exists("res://"+path),"pack includes "+path)
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ui/korea_layout_v1/full_r3_v1/manifest.json"))
	check(FileAccess.get_sha256("res://ui/korea_layout_v1/assets/korea_approved_1254.png")==catalog.source_sha256,"packed raw map hash")
	var font: Font=load("res://ui/living_city_v1/assets/fonts/nanummyeongjo/title_font.res")
	check(font.has_char("금".unicode_at(0)) and font.has_char("성".unicode_at(0)),"title Korean glyphs")

func run() -> void:
	await get_tree().create_timer(3).timeout
	resources()
	await capture("title-"+phase)
	if phase in ["reload","production-reload"]:
		var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("restart-production.json" if phase=="production-reload" else "restart.json")))
		slot=receipt.slot
		get_tree().current_scene._load_selected_game(slot)
		await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await settle()
		check(snapshot()==receipt.snapshot,"restart restores exact date officers progress treasury inventory")
		await capture("restored")
		await events()
		if phase=="production-reload":
			check(c.strategy_state.city_production.geumgwan.iron_sword.enabled,"production order restored enabled")
			await month()
			await capture("production-after-second-restart")
			finish(); return
		await wait_job("research","geumgwan")
		await wait_job("build","geumgwan")
		await accept("geumgwan","build","forge",receipt.workers[0])
		await wait_job("build","geumgwan")
		await accept("geumgwan","production","",receipt.workers[0])
		c._on_city_card_production_requested("geumgwan")
		var p: Node=c.production_overlay
		for recipe: int in [0,1]:
			p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe); await click(p.start_button)
			check(c.strategy_state.city_production.geumgwan[p.selected_recipe_id].enabled,"production reservation enabled "+p.selected_recipe_id)
		await capture("production-running"); await key(KEY_ESCAPE)
		var before: int=c.strategy_state.city_inventory.geumgwan.sword
		for i: int in range(3): await month()
		check(c.strategy_state.city_inventory.geumgwan.sword>before,"actual monthly sword output increases")
		evidence["final"]=snapshot()
		await capture("production-complete")
		slot="user://windows_export_v1_5_production_"+str(int(Time.get_unix_time_from_system()))+".json"
		check(not FileAccess.file_exists(slot),"second new slot does not overwrite saves")
		var saved: bool=c._on_save_button_pressed(slot)
		check(saved,"save running production to default user path")
		if saved:
			var file:=FileAccess.open(out.path_join("restart-production.json"),FileAccess.WRITE)
			file.store_string(JSON.stringify({"slot":slot,"snapshot":snapshot()},"\t")); file.close()
		finish(); return
	var title: Node=get_tree().current_scene
	await click(title.new_game_button)
	await get_tree().create_timer(3).timeout
	var setup: Node=get_tree().current_scene
	print("SETUP_CONTROLS ",setup.faction_view._focus_controls.keys())
	await click(setup.faction_view._focus_controls["scenario:silla_equilibrium_632"])
	await click(setup.faction_view._focus_controls["faction:silla"])
	await capture("new-game-632-silla")
	await click(setup.faction_view._focus_controls.start)
	await get_tree().create_timer(3).timeout
	c=get_tree().current_scene; await events()
	check(c.year==632 and c.player_faction_id=="silla","actual new game 632 Silla")
	await visuals()
	c.select_province("geumseong",false); c.open_domestic("agriculture")
	var personnel: Node=c.domestic_overlay
	await click(personnel.governor_button)
	var candidate := ""
	for i: int in range(personnel.selector.item_count):
		var id: String=str(personnel.selector.get_item_metadata(i))
		var quote: Dictionary=personnel.Personnel.quote(c,c.player_faction_id,"governor","geumseong",id)
		var power: Dictionary=c.Power.quote(c,{"kind":"governor","target":"geumseong","officer_id":id,"faction_id":c.player_faction_id})
		if quote.ok and power.ok and not power.get("required",false) and id!=c.get_governor_id("geumseong"): candidate=id; break
	check(not candidate.is_empty(),"eligible normal governor candidate")
	pick(personnel.selector,candidate); personnel.refresh_quote()
	await click(personnel.execute_button)
	check(c.get_governor_id("geumseong")==candidate,"actual governor appointment")
	await capture("governor-appointed"); await key(KEY_ESCAPE)
	var people: Array=c.get_city_officer_ids("geumseong")
	var workers: Array=[people[1],people[2]]
	c.select_province("geumseong",false); c.open_domestic("agriculture")
	var d: Node=c.domestic_overlay
	pick(d.selector,people[0]); d.refresh_quote()
	var q: Dictionary=c.get_domestic_quote("geumseong","agriculture",people[0])
	var before_agri: int=c.provinces.geumseong.agriculture
	await click(d.execute_button)
	check(d.execute_button.disabled,"development accepted")
	await key(KEY_ESCAPE)
	check(c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","officer_ids":workers,"troops":0},true).ok,"normal worker transfer")
	await month()
	check(c.provinces.geumseong.agriculture==before_agri+q.gain,"normal development completes")
	await accept("geumgwan","build","smelter",workers[0])
	await accept("geumgwan","research","swordsmithing",workers[1])
	await month()
	slot="user://windows_export_v1_5_"+str(int(Time.get_unix_time_from_system()))+".json"
	check(not FileAccess.file_exists(slot),"new user slot never overwrites existing save")
	var saved: bool=c._on_save_button_pressed(slot)
	check(saved,"default user path save")
	if saved:
		var file:=FileAccess.open(out.path_join("restart.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"slot":slot,"workers":workers,"snapshot":snapshot()},"\t")); file.close()
		await capture("saved-pending")
	else: evidence["unverified"]="default user path blocked; no relocated save substitute"
	finish()


