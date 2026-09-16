extends "res://tests/silla_642_politics_playtest.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	await start(Scenarios.SCENARIOS[2],"baekje","historical")
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"normal.json"))
	var fixtures: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"fixtures.json"))
	check(normal.pid!=OS.get_process_id() and fixtures.pid!=OS.get_process_id(),"restart uses a separate engine process")
	var cases: Array=[normal.merged({"label":"normal-12-months"})]+fixtures.checkpoints
	for entry: Dictionary in cases:
		c._on_load_button_pressed(entry.slot)
		check(full_state()==entry.state,"process restart restores all state "+entry.label)
		if entry.label=="waiting":
			var row: Dictionary=c.Power.records(c.strategy_state).requests.values()[0]
			var before: int=stamp()
			var remaining: int=int(row.due_month)-before
			check(remaining>0 and remaining<=4,"saved negotiation retains bounded remaining term")
			for n: int in range(clampi(remaining,0,4)):
				c.event_presentation.restore_state({}); c.power_dialog.hide()
				c._on_end_turn_button_pressed(); await process_frame; await settle_events()
				if n<remaining-1: check(row.status=="waiting","handover stays pending before due month")
			check(stamp()==before+remaining and row.status=="completed" and c.officer_registry.posts["governor:geumseong"]=="historical:001","restored waiting negotiation completes on its actual due turn")
	var output:=FileAccess.open(DIR+"restart.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"user_dir":ProjectSettings.globalize_path("user://")},"\t")); output.close()
	print("SILLA 642 RESTART: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
