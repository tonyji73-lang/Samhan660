extends "res://tests/invasion_response_playtest.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INV_DIR+"normal.json"))
	await start(Scenarios.SCENARIOS[0],"baekje","historical"); initial_stamp=stamp()
	check(OS.get_process_id()!=int(normal.pid),"new process after original exit")
	for branch: String in ["none","support"]:
		var checkpoint: Dictionary=normal.checkpoints[branch]
		for n: int in range(2):
			c._on_load_button_pressed(checkpoint.slot); await process_frame
			check(full_state()==checkpoint.state,"pending invasion and support restored without execution "+branch+str(n))
		seed(64220260922); await next_month("restored "+branch); await process_frame; await process_frame
		var row: Dictionary=c.strategy_state.invasions.orders[normal.order]
		var actual: Dictionary=Merit.battle(c.strategy_state,row.battle_id)
		var expected: Dictionary=normal.branches[branch].battle
		for key: String in ["attacker_troops","defender_troops","attacker_power","defender_power","attacker_losses","defender_losses","won","attacker_state","defender_state","participants"]:
			check(canonical(actual[key])==canonical(expected[key]),"restored current-state defense matches "+branch+" "+key)
		check(c.gold==int(normal.branches[branch].gold),"restored pre-reward treasury "+branch)
		c.merit_overlay.hide(); await press(c.invasion_button); select_value(c.invasion_overlay.orders,normal.order); await screen("restart-"+branch); await press(c.invasion_overlay.close_button)
		var before: Dictionary=full_state(); c.Invasions.process(c); c.run_enemy_ai_turns()
		check(full_state()==before,"repeated restored month is inert "+branch)
		c._on_load_button_pressed(normal.checkpoints[branch+"_after"].slot); await process_frame
		check(full_state()==normal.checkpoints[branch+"_after"].state,"completed battle and reward preserve IDs "+branch)
		if normal.branches[branch].has("reward"):
			var candidate: String=normal.branches[branch].reward.officer
			before=full_state()
			check(not Merit.reward(c,normal.branches[branch].battle.battle_id,candidate).ok and full_state()==before,"defensive reward never duplicates after restart")
	var file:=FileAccess.open(INV_DIR+"restart.json",FileAccess.WRITE); file.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures},"\t")); file.close()
	print("INVASION RESTART: ",checks," checks, ",failures," failures"); quit(0 if failures==0 else 1)
