extends "res://tests/military_preparation_playtest.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PREP_DIR+"normal.json"))
	await start(Scenarios.SCENARIOS[0],"baekje","historical")
	unit_id=normal.unit_id
	initial_stamp=int(normal.checkpoints.ready.state.year)*12+int(normal.checkpoints.ready.state.month)-int(normal.elapsed)
	check(OS.get_process_id()!=int(normal.pid),"distinct process after GUI campaign exit")
	for label: String in ["progress","ready"]:
		var saved: Dictionary=normal.checkpoints[label]
		c._on_load_button_pressed(saved.slot)
		check(full_state()==saved.state,"all campaign state restored "+label)
		army(); select_value(c.army_overlay.officers,"historical:004")
		check(c.army_overlay.preparation_model.parallel==(label=="progress"),"restored guide reflects active work or readiness "+label)
		await screen("restart-"+label)
		await round_trip("production",true)
		check(full_state()==saved.state,"restored browsing makes no payment or job change "+label)
		await press(c.army_overlay.close_button)
		await next_month("restored "+label)
		if label=="progress":
			check(c.Army.training(c.Army.units(c.strategy_state)[unit_id])==70,"in-progress training resumes to target")
			var jobs: Array=c.strategy_state.domestic.jobs.values().filter(func(j): return j.kind=="training" and j.get("unit_id","")==unit_id)
			check(jobs.size()==1 and jobs[0].cost_paid==100,"restored training charges two total months, no repeat")
		else: check(c.Army.units(c.strategy_state)[unit_id].equipment==1000,"completed equipment preserved after restart continuation")
	var out:=FileAccess.open(PREP_DIR+"restart.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures},"\t")); out.close()
	print("MILITARY PREPARATION RESTART: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
