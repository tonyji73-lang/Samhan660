extends "res://tests/silla_642_politics_playtest.gd"

const Merit=preload("res://battle_merit.gd")
const Planning=preload("res://ai_military_planning.gd")
const MERIT_DIR="res://.godot/battle-merit/"
var trace: Array=[]

func screen(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(MERIT_DIR+label+".png")==OK,"capture "+label)

func save_slot(label: String) -> Dictionary:
	var slot: String="user://battle_merit_%s_%d_%d.json" % [label,int(Time.get_unix_time_from_system()),OS.get_process_id()]
	check(not FileAccess.file_exists(slot) and c._on_save_button_pressed(slot),"unique native slot "+label)
	return {"slot":slot,"state":full_state()}

func normal_battle() -> Dictionary:
	for step: int in range(24):
		var options: Array=[]
		for source: String in Planning.owned(c,"silla"):
			if not c.validate_attack_staff(source).ok or c.get_city_officer_ids(source).is_empty(): continue
			var strength: float=c.Army.power(c.strategy_state,c.Army.attack_units(c.strategy_state,source,"silla"))*(1+float(c.get_best_commander(source,"attack").leadership)/100.0)
			for target: String in c.province_connections.get(source,[]):
				if c.Economy.resolve(c.strategy_state,c.provinces[target].faction)=="silla": continue
				var defense: float=c.Army.power(c.strategy_state,c.Army.at_city(c.strategy_state,target))*(1+float(c.get_best_commander(target).leadership)/100.0+float(c.provinces[target].fortress)/200.0)
				options.append({"source":source,"target":target,"ratio":strength/maxf(1,defense)})
		options.sort_custom(func(a,b): return a.source+a.target<b.source+b.target if is_equal_approx(a.ratio,b.ratio) else a.ratio>b.ratio)
		if options.is_empty(): return {}
		var best: Dictionary=options[0]
		if best.ratio>1.05 and int(c.provinces[best.source].food_stock)>=c.ATTACK_FOOD_COST:
			var officer: String=c.get_best_commander(best.source,"attack").get("officer_id","")
			var ids: Array=c.Army.attack_units(c.strategy_state,best.source,"silla")
			check(not officer.is_empty() and c.Noble.appoint(c,"silla","commander",ids[0],officer).ok,"normal commander appointment before battle")
			var count: int=c.strategy_state.army.battles.size()
			c.resolve_attack(best.source,best.target)
			await process_frame; await settle_events(); await process_frame; await process_frame
			check(c.strategy_state.army.battles.size()==count+1,"normal attack commits one battle")
			trace.append({"step":step,"attack":best})
			return c.strategy_state.army.battles.back()
		for source: String in Planning.owned(c,"silla"):
			if source==best.source: continue
			var path: Array=Planning.military_route(c,"silla",source,best.source)
			var amount: int=maxi(0,c.Army.count(c.strategy_state,c.Army.at_city(c.strategy_state,source,"silla",true))-3000)
			if path.size()<2 or amount<100: continue
			trace.append({"step":step,"move":c.queue_province_transfer({"source_id":source,"target_id":path[1],"troops":amount,"officer_ids":[]},false,"silla")})
		c._on_end_turn_button_pressed(); await process_frame; await settle_events()
	return {}

func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(MERIT_DIR)
	seed(64220260917)
	await start(Scenarios.SCENARIOS[1],"silla","historical"); await settle_events()
	var row: Dictionary=await normal_battle()
	check(not row.is_empty() and row.won,"642 normal commands produce victory")
	if row.is_empty() or not row.won: quit(1); return
	check(c.merit_overlay.visible and c.map_area.modal_input_locked,"actual battle result opens reward candidates and locks map")
	var candidate: String=""
	for person: Dictionary in row.participants:
		if Merit.quote(c,row.battle_id,person.officer_id).ok: candidate=person.officer_id; break
	check(not candidate.is_empty(),"actual surviving victorious commander is eligible")
	if candidate.is_empty(): quit(1); return
	check(row.participants.filter(func(p): return p.officer_id==candidate).size()==1,"one candidate per officer")
	check(c.merit_overlay.reward_buttons.has(candidate) and not c.merit_overlay.reward_buttons[candidate].disabled,"candidate has explicit cost and selectable reward")
	await screen("normal-result-before")
	var unawarded: Dictionary=save_slot("unawarded")
	c._on_end_turn_button_pressed()
	check(full_state()==unawarded.state,"result modal blocks monthly commands until closed")
	var q: Dictionary=Merit.quote(c,row.battle_id,candidate)
	var money: int=c.gold
	if DisplayServer.get_name()=="headless": c.merit_overlay.reward_buttons[candidate].pressed.emit()
	else: await click(c.merit_overlay.reward_buttons[candidate])
	check(c.gold==money-100,"selected reward charges exactly100")
	check(c.officer_registry.people[candidate].loyalty==q.loyalty_after and c.officer_registry.politics.groups[q.group_id].cooperation==q.cooperation_after,"selected reward applies loyalty5 and cooperation6 once")
	check(row.rewards.has(candidate) and c.merit_overlay.reward_buttons[candidate].disabled,"result shows completed disabled reward")
	await screen("normal-result-rewarded")
	var awarded: Dictionary=save_slot("awarded")
	check(not Merit.reward(c,row.battle_id,candidate).ok and full_state()==awarded.state,"repeat action changes no ledger or political effect")
	if DisplayServer.get_name()=="headless": c.merit_overlay.close_button.pressed.emit()
	else: await click(c.merit_overlay.close_button)
	check(not c.merit_overlay.visible and not c.map_area.modal_input_locked,"Close button restores map input")
	c.open_battle_merit(row.battle_id)
	check(c.merit_overlay.reward_buttons[candidate].disabled and full_state()==awarded.state,"result reentry preserves completion")
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=down; root.push_input(event,true)
	await process_frame
	check(not c.merit_overlay.visible and not c.map_area.modal_input_locked,"result Esc restores map input")
	c.open_politics()
	var picker: OptionButton=c.politics_overlay.history_people
	for n: int in range(picker.item_count):
		if picker.get_item_metadata(n)==candidate: picker.select(n); picker.item_selected.emit(n); break
	check(c.politics_overlay.details.text.contains("포상 완료") and c.politics_overlay.details.text.contains("참전·포상 이력"),"personnel screen contains actual participation and reward history")
	await screen("normal-personnel-history")
	c.politics_overlay.hide()
	var previous: int=stamp(); c._on_end_turn_button_pressed(); await process_frame; await settle_events()
	check(stamp()==previous+1,"closing screens restores real monthly input")
	var output:=FileAccess.open(MERIT_DIR+"normal.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"pid":OS.get_process_id(),"battle_id":row.battle_id,"candidate":candidate,"unawarded":unawarded,"awarded":awarded,"trace":trace,"checks":checks,"failures":failures},"\t")); output.close()
	print("BATTLE MERIT NORMAL: ",checks," checks, ",failures," failures; ",trace)
	quit(0 if failures==0 else 1)
