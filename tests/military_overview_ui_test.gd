extends "res://tests/settlement_ui_test.gd"
const REVIEW="res://.godot/military-overview-review/"
const Army=preload("res://army_readiness.gd")

func shot(label: String) -> void:
	await pause(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(REVIEW+label+".png")==OK,"capture "+label)

func key(code: Key, shift: bool=false) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.shift_pressed=shift; event.pressed=down; root.push_input(event,true)
	await pause()

func fits(control: Control) -> bool:
	var rect: Rect2=control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
	return root.get_visible_rect().grow(2).encloses(rect)

func _run() -> void:
	create_timer(200).timeout.connect(func():push_error("MILITARY OVERVIEW TIMEOUT");quit(2))
	DirAccess.make_dir_recursive_absolute(REVIEW)
	await start(Scenarios.SCENARIOS[0],"silla","historical"); await settle_events()
	var before: Dictionary=full_state()
	c.open_army("geumseong"); var panel: Node=c.army_overlay; await pause()
	check(panel.visible and panel.overview.visible,"army opens supply overview")
	check(full_state()==before,"opening overview is read-only")
	check(panel.local_stock.text.contains(str(c.provinces.geumseong.food_stock)),"local grain from city ledger")
	check(panel.arrivals.text=="도착 예정 화물 없음","empty incoming shown")
	check(panel.equip_button.disabled and not panel.status.text.is_empty(),"zero stock blocks confirmation with reason")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await pause()
		for control: Control in [panel.overview,panel.selector,panel.equip_button,panel.close_button,panel.commander_portrait]: check(fits(control),"screen fits "+control.get_class()+str(resolution.x))
		await shot("overview-"+str(resolution.x))
		await click(panel.mode_buttons.training)
		check(panel.training_surface.visible and not panel.overview.visible and panel.train_button.visible,"training context toggles")
		await shot("training-"+str(resolution.x))
		await click(panel.mode_buttons.formation)
	await click(panel.manage_button)
	check(panel.management_panel.visible,"existing editing commands accessible")
	await key(KEY_ESCAPE)
	check(panel.visible and not panel.management_panel.visible,"Esc closes editing first")
	panel.bundles.value=5; await pause()
	check(full_state()==before,"quantity preview does not change state")
	await click(panel.reset_button)
	check(panel.bundles.value==1 and full_state()==before,"reset is read-only")
	await click(panel.preparation_buttons.production)
	check(c.production_overlay.visible and not panel.visible,"production shortcut")
	await escape()
	check(panel.visible and panel.city=="geumseong","production return keeps city")
	await click(panel.transport_button)
	check(c.supply_overlay.visible and not panel.visible and c.supply_overlay.target()=="geumseong","transport shortcut targets selected city")
	await escape()
	check(panel.visible and panel.city=="geumseong","transport return keeps city")
	check(full_state()==before,"supply shortcuts preserve state")
	panel.mode_buttons.training.grab_focus(); await key(KEY_ENTER)
	check(panel.mode=="training","keyboard tab activation")
	await key(KEY_TAB); check(root.gui_get_focus_owner()!=null,"Tab focus exists")
	await key(KEY_TAB,true); check(root.gui_get_focus_owner()!=null,"Shift Tab focus exists")
	await escape(); check(not panel.visible and not c.settlement_overlay.busy(),"Esc restores current map")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--prepared-save="): await prepared_campaign(argument.trim_prefix("--prepared-save="))
	print("MILITARY OVERVIEW GUI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

## Optional, read-only input from a previously recorded normal-play campaign.
func prepared_campaign(path: String) -> void:
	var original: String=FileAccess.get_sha256(path)
	check(FileAccess.file_exists(path),"prepared normal-play slot exists")
	c._on_load_button_pressed(path); await pause(); await settle_events()
	c.open_army("geumseong"); var panel: Node=c.army_overlay
	for uid: String in Army.at_city(c.strategy_state,"geumseong",c.player_faction_id):
		var unit: Dictionary=Army.units(c.strategy_state)[uid]
		if int(unit.troops)<=1000 and int(unit.equipment)<int(unit.troops): unit_id=uid; break
	check(not unit_id.is_empty(),"normal recruited unit available")
	if unit_id.is_empty(): return
	select_value(panel.selector,unit_id); panel.show_mode("formation"); panel.bundles.value=1; await pause()
	var unit: Dictionary=Army.units(c.strategy_state)[unit_id]
	var stock: int=c.strategy_state.city_inventory.geumseong.sword
	var equipment: int=unit.equipment
	var before: Dictionary=full_state()
	check(not panel.equip_button.disabled and stock>0,"normal production stock can be issued")
	await shot("normal-issue-preview")
	check(full_state()==before,"valid issue preview remains read-only")
	await click(panel.equip_button)
	check(c.strategy_state.city_inventory.geumseong.sword==stock-1 and unit.equipment==equipment+100,"GUI issue matches quote once")
	before=full_state(); panel.hide(); c.open_army("geumseong"); select_value(panel.selector,unit_id)
	check(full_state()==before,"reopening does not repeat equipment issue")
	await click(panel.mode_buttons.training)
	if not panel.stop_button.disabled: await click(panel.stop_button)
	for n: int in range(panel.officers.item_count):
		var oid: String=panel.officers.get_item_metadata(n)
		var quote: Dictionary=Army.training_quote(c.strategy_state,c.provinces,c.player_faction_id,unit_id,oid,stamp())
		if quote.ok: panel.select_officer(oid); break
	await pause(); check(not panel.train_button.disabled,"normal eligible trainer available")
	var gold: int=c.gold
	await click(panel.train_button)
	var job: Dictionary=Army.training_job(c.strategy_state,unit_id)
	check(not job.is_empty() and c.gold==gold,"training accepted without early charge")
	await shot("normal-training-accepted")
	var training: float=Army.training(unit)
	panel.hide(); await next_month("military overview training")
	check(Army.training(unit)>training and int(job.cost_paid)>0,"normal month advances paid training")
	c.open_army("geumseong"); select_value(panel.selector,unit_id); panel.show_mode("training"); await pause()
	check(panel.metric_labels.training.text.contains("%.1f" % Army.training(unit)),"training display follows actual progress")
	await shot("normal-training-month")
	check(FileAccess.get_sha256(path)==original,"source save preserved byte-for-byte")
