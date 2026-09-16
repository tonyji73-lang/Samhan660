extends "res://tests/battle_merit_playtest.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MERIT_DIR+"normal.json"))
	await start(Scenarios.SCENARIOS[0],"baekje","historical")
	check(OS.get_process_id()!=int(normal.pid),"distinct engine process after playtest exit")
	for label: String in ["unawarded","awarded"]:
		var saved: Dictionary=normal[label]
		c._on_load_button_pressed(saved.slot)
		check(full_state()==saved.state,"restart restores every ledger and troop "+label)
		check(not Merit.battle(c.strategy_state,normal.battle_id).is_empty(),"battle ID survives restart "+label)
		check(Merit.quote(c,normal.battle_id,normal.candidate).ok==(label=="unawarded"),"restart preserves reward eligibility "+label)
		if label=="awarded":
			var before: Dictionary=full_state()
			for n: int in range(3):
				c._on_load_button_pressed(saved.slot)
				check(not Merit.reward(c,normal.battle_id,normal.candidate).ok and full_state()==before,"repeat restore/click never pays twice "+str(n))
			c.open_battle_merit(normal.battle_id)
			check(c.merit_overlay.reward_buttons[normal.candidate].disabled,"restored GUI result keeps completed state")
			await screen("restart-rewarded")
	var output:=FileAccess.open(MERIT_DIR+"restart.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures},"\t")); output.close()
	print("BATTLE MERIT RESTART: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
