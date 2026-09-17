extends "res://tests/military_preparation_playtest.gd"

const HANDOVER_DIR="res://.godot/silla-642-handover/"
var main_unit: String=""
var negotiation: String=""
var branches: Dictionary={}

func screen(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var viewport: Viewport=c.power_dialog if c.power_dialog.visible else root
	check(viewport.get_texture().get_image().save_png(HANDOVER_DIR+label+".png")==OK,"GUI "+label)

func press(button: Button) -> void:
	if DisplayServer.get_name()=="headless" or button.get_viewport()==root: await super.press(button); return
	check(not button.disabled,"enabled negotiation button "+button.text)
	if button.disabled: return
	await process_frame; await process_frame
	button.grab_focus()
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_ENTER; event.pressed=down
		button.get_viewport().push_input(event,true)
	await process_frame; await process_frame

func save_slot(label: String) -> Dictionary:
	var slot: String="user://silla_642_handover_%s_%d_%d.json" % [label,int(Time.get_unix_time_from_system()),OS.get_process_id()]
	check(not FileAccess.file_exists(slot) and c._on_save_button_pressed(slot),"unique host save "+label)
	return {"slot":slot,"state":full_state()}

func choice_button(choice: String) -> Button:
	for b: Node in c.power_dialog.find_children("*","Button",true,false):
		if b.get_meta("power_choice","")==choice: return b
	return null

func measure() -> Dictionary:
	var row: Dictionary=c.Power.records(c.strategy_state).get("requests",{}).get(negotiation,{})
	var q: Dictionary=c.Army.training_quote(c.strategy_state,c.provinces,"silla",unit_id,"historical:001",stamp())
	return canonical({"month":stamp(),"gold":c.gold,"commander":c.strategy_state.unit_rosters[unit_id].commander_id,"old_loyalty":c.officer_registry.people["historical:004"].loyalty,"new_loyalty":c.officer_registry.people["historical:001"].loyalty,"cooperation":c.officer_registry.politics.groups["silla:military"].cooperation,"royal_cooperation":c.officer_registry.politics.groups["silla:royal"].cooperation,"influence":Core.influence(c.strategy_state,c.provinces,"silla"),"attack_eligible":c.Army.attack_units(c.strategy_state,"geumseong","silla").has(unit_id),"training":q,"restriction":c.Power.unit_reason(c.strategy_state,unit_id),"row":row})

func request_handover() -> void:
	c.open_army("geumseong"); select_value(c.army_overlay.selector,unit_id); select_value(c.army_overlay.officers,"historical:001")
	var money: int=c.gold
	await press(c.army_overlay.commander_button)
	await process_frame; await process_frame
	negotiation=c.power_request_id
	check(c.power_dialog.visible and not negotiation.is_empty(),"normal commander change opens negotiation")
	check(c.gold==money and c.strategy_state.unit_rosters[unit_id].commander_id=="historical:004","offer keeps money and old command")

func concentrate() -> void:
	main_unit=c.Army.at_city(c.strategy_state,"geumseong","silla")[0]
	check(c.Noble.appoint(c,"silla","governor","geumseong","historical:004").ok,"normal capital governor appointment")
	check(c.Army.appoint(c.strategy_state,c.provinces,"silla",main_unit,"historical:004").ok,"normal capital commander appointment")
	for step: int in range(12):
		for uid: String in c.Army.at_city(c.strategy_state,"geumseong","silla"):
			if uid==main_unit: continue
			var result: Dictionary=c.Army.merge(c.strategy_state,c.provinces,"silla",main_unit,uid)
			actions.append({"month":stamp(),"merge":uid,"result":result})
		var power: Dictionary=Core.influence(c.strategy_state,c.provinces,"silla")
		print("NORMAL 642 CONCENTRATION ",step," ",power.groups["silla:military"])
		if power.groups["silla:military"].influence>=40: return
		for city: String in Planning.owned(c,"silla"):
			if city=="geumseong": continue
			var path: Array=Planning.military_route(c,"silla",city,"geumseong")
			if path.size()<2: continue
			var ids: Array=c.Army.at_city(c.strategy_state,city,"silla",true)
			var available: int=maxi(0,c.Army.count(c.strategy_state,ids)-1000)
			for uid: String in ids:
				var u: Dictionary=c.strategy_state.unit_rosters[uid]
				if not str(u.commander_id).is_empty() or available<=0: continue
				if int(u.troops)>available:
					var part: Dictionary=c.Army.split(c.strategy_state,c.provinces,"silla",uid,available)
					check(part.ok,"normal split for retained1000 garrison")
					if not part.ok: continue
					uid=part.unit_id; u=c.strategy_state.unit_rosters[uid]
				var result: Dictionary=c.queue_province_transfer({"source_id":city,"target_id":path[1],"troops":u.troops,"officer_ids":[],"unit_ids":[uid]},false,"silla")
				actions.append({"month":stamp(),"source":city,"target":path[1],"unit":uid,"troops":u.troops,"move":result})
				if result.ok: available-=int(u.troops)
		await next_month("normal concentration")
	check(false,"influence40 reached by normal commands")

func finish() -> void:
	var out:=FileAccess.open(HANDOVER_DIR+"normal.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"pid":OS.get_process_id(),"unit_id":unit_id,"main_unit":main_unit,"checkpoints":checkpoints,"branches":branches,"actions":actions,"months":months,"events":occurrences,"checks":checks,"failures":failures},"\t")); out.close()
	print("642 HANDOVER: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)

func _run() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(HANDOVER_DIR)
	seed(64220260919)
	await start(Scenarios.SCENARIOS[1],"silla","historical"); await settle_events()
	initial_stamp=stamp(); await concentrate()
	if failures>0: finish(); return
	var part: Dictionary=c.Army.split(c.strategy_state,c.provinces,"silla",main_unit,1000)
	check(part.ok,"normal split preserves concentrated command while selecting trainable1000")
	unit_id=part.unit_id
	checkpoints.before=save_slot("before")
	for choice: String in ["compensate","wait","force"]:
		c._on_load_button_pressed(checkpoints.before.slot); await process_frame; await settle_events()
		seed(64220260920)
		check(full_state()==checkpoints.before.state,"same normal pre-negotiation save "+choice)
		await request_handover()
		var data: Dictionary={"before":measure(),"timeline":[]}
		await screen(choice+"-offer")
		await press(choice_button(choice))
		data.selected=measure()
		check(data.selected.row.status==("waiting" if choice=="wait" else "completed"),"GUI choice applied "+choice)
		check(data.selected.gold==data.before.gold-(int(data.before.row.gold) if choice=="compensate" else 0),"actual quoted payment "+choice)
		check(data.selected.old_loyalty==data.before.old_loyalty-(0 if choice=="wait" else (20 if choice=="force" else 4)) and data.selected.cooperation==data.before.cooperation-(0 if choice=="wait" else (12 if choice=="force" else 2)),"retiring loyalty and cooperation match preview "+choice)
		check(data.selected.attack_eligible==(choice!="force") and data.selected.training.ok==(choice!="force"),"per-unit attack and training restriction after choice "+choice)
		check(c.power_dialog.get_ok_button().text==("닫기·기존 권한 유지" if choice=="wait" else "닫기"),"close label matches actual authority "+choice)
		if choice=="wait":
			await process_frame; await process_frame
			check(c.power_successors.get_global_rect().position.y>=c.power_details.get_parent().get_global_rect().end.y,"successor picker never overlaps negotiation text scroll")
		await screen(choice+"-selected"); await press(c.power_dialog.get_ok_button())
		check(not c.map_area.modal_input_locked,"dialog close restores game input")
		if choice in ["wait","force"]: checkpoints[choice]=save_slot(choice)
		if choice=="force":
			var before: Dictionary=full_state()
			check(not c.Army.train(c.strategy_state,c.provinces,"silla",unit_id,"historical:001",stamp()).ok and full_state()==before,"force blocks real training without payment")
		for n: int in range(int(data.before.row.months)):
			await next_month(choice+" settlement")
			data.timeline.append(measure())
			check(data.timeline.back().attack_eligible and data.timeline.back().training.ok,"after monthly settlement no per-unit disruption "+choice+str(n+1))
			if choice=="wait": check(data.timeline.back().commander==("historical:001" if n+1==int(data.before.row.months) else "historical:004"),"wait transfers exactly at due month")
			c.show_power_transfer(negotiation); await process_frame; await screen(choice+"-month"+str(n+1)); await press(c.power_dialog.get_ok_button())
			if choice=="force": check(c.power_details.text.contains("현재 부대 인계 차질 없음") and not c.power_details.text.contains("다음1회 월 처리까지"),"completed force UI shows recovered current restriction")
		var final: Dictionary=measure()
		check(final.row.applied and final.commander=="historical:001","handover eventually completed "+choice)
		check(final.attack_eligible and final.training.ok,"normal sortie and training eligibility restored "+choice)
		var before_repeat: Dictionary=full_state()
		check(not c.Power.resolve(c,negotiation,choice).ok and full_state()==before_repeat,"completed negotiation cannot repeat cost or effects "+choice)
		c.open_army("geumseong"); select_value(c.army_overlay.selector,unit_id); select_value(c.army_overlay.officers,"historical:001")
		await press(c.army_overlay.train_button); c.army_overlay.hide()
		await next_month(choice+" actual resumed training")
		data.resumed=measure(); data.training_job=c.Army.training_job(c.strategy_state,unit_id).duplicate(true)
		check(c.Army.training(c.strategy_state.unit_rosters[unit_id])>50,"actual paid training resumes "+choice)
		branches[choice]=data
	finish()
