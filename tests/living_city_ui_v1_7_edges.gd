extends "res://tests/living_city_ui_v1_7_play.gd"

func _run() -> void:
	create_timer(300).timeout.connect(func(): push_error("V1.7 EDGE TIMEOUT"); quit(2))
	for faction: String in ["silla","baekje","goguryeo"]:
		await campaign_start(faction); c.open_politics(); await settle()
		var p: Node=c.politics_overlay; var before: Dictionary=snapshot()
		for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=resolution; await shot("final-"+faction+"-court")
		p.set_mode("appointment")
		var valid:=false
		for t: int in range(p.targets.item_count):
			p.targets.select(t); p.populate()
			for n: int in range(p.people.item_count):
				p.people.select(n); p.forecast()
				if not p.apply_button.disabled: valid=true; break
			if valid: break
		check(valid,"actual appointment candidate "+faction)
		check(before==snapshot(),"appointment browsing pure "+faction)
		if faction!="silla": check(not p.preview.text.contains("왕실 직속") and not p.preview.text.contains("귀족 연합"),"appointment has no foreign group labels "+faction)
		await shot("appointment-"+faction)
		var target: Dictionary=p.targets.get_item_metadata(p.targets.selected); var oid: String=p.people.get_item_metadata(p.people.selected)
		p.cancel_button.grab_focus(); await key(KEY_SPACE); check(before==snapshot(),"appointment cancel pure "+faction)
		p.set_mode("appointment"); p.apply_button.grab_focus(); await key(KEY_SPACE)
		check(c.officer_registry.posts.get("governor:"+str(target.target),"")==oid if target.kind=="governor" else c.strategy_state.unit_rosters[target.target].commander_id==oid,"keyboard appointment applied "+faction)
		await key(KEY_ESCAPE); check(not c.settlement_overlay.busy(),"appointment close restores map input "+faction)
	await campaign_start()
	c._on_load_button_pressed(REVIEW+"governor-wait-save.json"); await settle(); await events()
	var id: String=""
	for row: Dictionary in c.Power.records(c.strategy_state).requests.values():
		if row.status=="waiting": id=row.id; break
	check(not id.is_empty(),"waiting save found")
	c.show_power_transfer(id); await settle(); var p: Node=c.politics_overlay
	var before: Dictionary=snapshot(); pick(p.choices,"retarget"); pick(p.successors,"historical:001"); await settle()
	var expected: Dictionary=p.model.duplicate(true)
	check(expected.ok and before==snapshot(),"retarget preview read only")
	await click(p.apply_button); match_model(expected,"retarget")
	pick(p.choices,"withdraw"); expected=p.model.duplicate(true); before=snapshot()
	check(expected.ok and before==snapshot(),"withdraw preview read only")
	await click(p.apply_button); match_model(expected,"withdraw")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; c._on_load_button_pressed(REVIEW+"demand-start.json"); await settle(); await events(); c._show_court_demand(); await settle()
		p=c.politics_overlay; pick(p.choices,"gift"); await shot("final-demand-gift")
		before=snapshot(); await key(KEY_ESCAPE); c._on_end_turn_button_pressed(); await settle()
		check(before==snapshot() and p.visible,"unresolved demand reopens without month advancing")
		await normal_load()
		var offer: Dictionary=c.Power.intercept(c,{"kind":"governor","target":"geumseong","officer_id":"historical:001","faction_id":"silla"}); await settle()
		check(offer.has("negotiation_id"),"final authority offered")
		p=c.politics_overlay; pick(p.choices,"force"); await shot("final-governor-force")
		check(p.issue_detail.text.contains("해당 도시의 진행 업무"),"affected city work shown")
		var work: Dictionary={"ok":false}
		for officer: String in c.get_city_officer_ids("geumseong"):
			work=c.Domestic.start(c.strategy_state,c.provinces,c.player_faction,"geumseong","agriculture",officer,c.gold,c.year*12+c.month)
			if work.ok: break
		check(work.ok,"normal domestic work accepted for detail check")
		p.populate_choices()
		check(p.issue_detail.text.contains("농업 · 담당") and p.issue_detail.text.contains("진척 수치 기록 없음"),"work without numeric progress is not fabricated")
	var f:=FileAccess.open(REVIEW+"edges-result.json",FileAccess.WRITE); f.store_string(JSON.stringify({"checks":checks,"failures":failures})); f.close()
	print("V1.7 EDGES: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
