extends "res://tests/military_preparation_playtest.gd"
const INV_DIR="res://.godot/invasion-response/"
var branches: Dictionary={}
var selected_order: String=""

func press(button: Button) -> void:
	if DisplayServer.get_name()=="headless" or button.get_viewport()==root: await super.press(button); return
	check(not button.disabled,"enabled native dialog command")
	button.grab_focus(); await process_frame
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_ENTER; event.pressed=down; button.get_viewport().push_input(event,true)
	await process_frame; await process_frame

func screen(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(INV_DIR+label+".png")==OK,"GUI "+label)

func save_slot(label: String) -> Dictionary:
	var path: String="user://invasion_response_%s_%d_%d.json" % [label,int(Time.get_unix_time_from_system()),OS.get_process_id()]
	check(not FileAccess.file_exists(path) and c._on_save_button_pressed(path),"unique native slot "+label)
	return {"slot":path,"state":full_state()}

func finish() -> void:
	var file:=FileAccess.open(INV_DIR+"normal.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"order":selected_order,"checkpoints":checkpoints,"branches":branches,"actions":actions,"months":months,"events":occurrences,"checks":checks,"failures":failures},"\t")); file.close()
	print("INVASION NORMAL: ",checks," checks, ",failures," failures"); quit(0 if failures==0 else 1)

func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2)); DirAccess.make_dir_recursive_absolute(INV_DIR)
	seed(64220260921); await start(Scenarios.SCENARIOS[1],"silla","historical"); await settle_events(); initial_stamp=stamp()
	for n: int in range(12):
		await next_month("await actual AI declaration")
		var threats: Array=c.Invasions.pending(c.strategy_state).filter(func(o): return o.defender=="silla")
		if not threats.is_empty(): selected_order=threats[0].id; break
		c.merit_overlay.hide()
	check(not selected_order.is_empty(),"AI normally declares invasion")
	if selected_order.is_empty(): finish(); return
	checkpoints.pending=save_slot("pending")
	print("THREATS ",c.Invasions.pending(c.strategy_state))
	for branch: String in ["none","support"]:
		c._on_load_button_pressed(checkpoints.pending.slot); await process_frame; await settle_events(); seed(64220260922)
		check(full_state()==checkpoints.pending.state,"same natural pending save "+branch)
		var order: Dictionary=c.strategy_state.invasions.orders[selected_order]
		await press(c.invasion_button); select_value(c.invasion_overlay.orders,selected_order); await screen(branch+"-alert")
		var preview: Dictionary=full_state(); c._on_end_turn_button_pressed()
		check(full_state()==preview,"alert browsing blocks accidental month and never spends")
		for down: bool in [true,false]:
			var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=down; root.push_input(event,true)
		await process_frame
		check(not c.invasion_overlay.visible and not c.map_area.modal_input_locked,"alert Esc restores input")
		await press(c.invasion_button); select_value(c.invasion_overlay.orders,selected_order)
		var before: Dictionary=full_state(); await press(c.invasion_overlay.army_button)
		check(c.army_overlay.visible and c.army_overlay.city==order.target and full_state()==before,"threat to current army is read only")
		c.army_overlay.hide()
		if branch=="support":
			for source: String in c.province_connections.get(order.target,[]):
				if c.provinces[source].faction!=c.player_faction: continue
				var amount: int=maxi(0,c.Army.count(c.strategy_state,c.Army.at_city(c.strategy_state,source,"silla",true))-1000)
				if amount<=0: continue
				var people: Array=[]
				for oid: String in c.get_city_officer_ids(source):
					if c.OfficerRegistry.action_available(c.officer_registry,oid,c.provinces,"move",source): people.append(oid)
				var request: Dictionary={"source_id":source,"target_id":order.target,"troops":amount,"officer_ids":people}
				await press(c.invasion_button); select_value(c.invasion_overlay.orders,selected_order); select_value(c.invasion_overlay.sources,source)
				await press(c.invasion_overlay.support_button)
				check(c.transfer_panel.visible and c.transfer_panel.source_province_id==source,"shortcut opens real support source")
				check(c.transfer_panel.destination_option.get_item_metadata(c.transfer_panel.destination_option.selected)==order.target,"shortcut preselects threatened destination")
				select_value(c.transfer_panel.destination_option,order.target); c.transfer_panel.troop_spin.value=amount
				for index: int in range(c.transfer_panel.officer_list.item_count):
					if people.has(c.transfer_panel.officer_list.get_item_metadata(index)): c.transfer_panel.officer_list.select(index,false)
				var count: int=c.pending_transfer_orders.size()
				await screen("support-"+source); await press(c.transfer_panel.execute_button)
				if c.governor_transfer_confirmation.visible:
					if DisplayServer.get_name()=="headless": c.governor_transfer_confirmation.confirmed.emit(); c.governor_transfer_confirmation.hide()
					else: await press(c.governor_transfer_confirmation.get_ok_button())
				actions.append({"branch":branch,"month":stamp(),"request":request,"orders":c.pending_transfer_orders.duplicate(true)})
				check(c.pending_transfer_orders.size()==count+1,"normal GUI support "+source)
		checkpoints[branch]=save_slot(branch)
		await next_month(branch+" actual defense"); await process_frame; await process_frame
		order=c.strategy_state.invasions.orders[selected_order]
		check(order.status=="completed","declared invasion executes despite response "+branch)
		check(c.merit_overlay.visible,"actual defense automatically opens merit result "+branch)
		if order.status!="completed": print("CANCELLED ",order); finish(); return
		var battle: Dictionary=Merit.battle(c.strategy_state,order.battle_id)
		branches[branch]={"order":order.duplicate(true),"battle":battle.duplicate(true),"gold":c.gold}
		print("DEFENSE ",branch," ",battle)
		c.merit_overlay.hide(); c.open_invasions(); select_value(c.invasion_overlay.orders,selected_order); await screen(branch+"-outcome"); await press(c.invasion_overlay.result_button)
		check(c.merit_overlay.summary.text.contains("아군 방어"),"player perspective result "+branch)
		if not battle.won:
			for person: Dictionary in battle.participants:
				var q: Dictionary=Merit.quote(c,battle.battle_id,person.officer_id)
				if not q.ok: continue
				var money: int=c.gold; await press(c.merit_overlay.reward_buttons[person.officer_id])
				check(c.gold==money-100 and c.officer_registry.people[person.officer_id].loyalty==q.loyalty_after and c.officer_registry.politics.groups[q.group_id].cooperation==q.cooperation_after,"actual defensive victory reward")
				branches[branch]["reward"]={"officer":person.officer_id,"quote":q}; await screen(branch+"-reward"); break
		await press(c.merit_overlay.close_button)
		check(not c.map_area.modal_input_locked,"close restores input")
		checkpoints[branch+"_after"]=save_slot(branch+"_after")
		var state: Dictionary=full_state(); c.Invasions.process(c); c.run_enemy_ai_turns()
		check(full_state()==state,"duplicate same month has no cost battle or new declaration")
	finish()
