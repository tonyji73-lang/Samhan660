extends "res://tests/silla_642_power_handover.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(HANDOVER_DIR+"normal.json"))
	await start(Scenarios.SCENARIOS[0],"baekje","historical")
	check(OS.get_process_id()!=int(normal.pid),"distinct process after normal branch run exit")
	unit_id=normal.unit_id; initial_stamp=642*12+7
	for choice: String in ["wait","force"]:
		var saved: Dictionary=normal.checkpoints[choice]
		for n: int in range(2):
			c._on_load_button_pressed(saved.slot); await process_frame
			check(full_state()==saved.state,"repeated load does not settle or pay "+choice+str(n))
		seed(64220260920)
		negotiation=str(c.Power.records(c.strategy_state).requests.keys().back())
		c.show_power_transfer(negotiation); await process_frame; await screen("restart-"+choice); await press(c.power_dialog.get_ok_button())
		var before: Dictionary=full_state()
		check(not c.Power.resolve(c,negotiation,"complete").ok and full_state()==before,"premature or repeated completion changes nothing "+choice)
		for n: int in range(int(normal.branches[choice].before.row.months)):
			await next_month("restart "+choice)
			var actual: Dictionary=measure()
			var expected: Dictionary=normal.branches[choice].timeline[n]
			for key: String in ["month","gold","commander","old_loyalty","new_loyalty","cooperation","royal_cooperation","attack_eligible","restriction","row"]:
				check(actual[key]==expected[key],"restart resumes same scheduled effect "+choice+str(n+1)+" "+key)
			check(actual.training.ok==expected.training.ok,"restored training permission "+choice+str(n+1))
			c.show_power_transfer(negotiation); await process_frame; await screen("restart-"+choice+"-month"+str(n+1)); await press(c.power_dialog.get_ok_button())
		var after: Dictionary=full_state()
		for n: int in range(3): check(not c.Power.resolve(c,negotiation,"force").ok and full_state()==after,"restart completed choice never repeats "+choice+str(n))
		check(c.Power.records(c.strategy_state).history.filter(func(e): return e.get("request_id","")==negotiation).size()==1,"one handover receipt after restoration "+choice)
	var out:=FileAccess.open(HANDOVER_DIR+"restart.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures},"\t")); out.close()
	print("642 HANDOVER RESTART: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
