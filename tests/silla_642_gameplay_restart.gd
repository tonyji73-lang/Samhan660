extends "res://tests/silla_642_gameplay_loop.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LOOP_DIR+"normal.json"))
	await start(Scenarios.SCENARIOS[0],"baekje","historical")
	initial_stamp=int(normal.checkpoints.final.state.year)*12+int(normal.checkpoints.final.state.month)-int(normal.elapsed)
	check(OS.get_process_id()!=int(normal.pid),"new engine process after full gameplay exit")
	for label: String in ["trained","unawarded","final"]:
		var saved: Dictionary=normal.checkpoints[label]
		c._on_load_button_pressed(saved.slot)
		check(full_state()==saved.state,"restart restores date faction resources units politics and jobs "+label)
		if label=="trained":
			c.open_army("geumseong"); select_value(c.army_overlay.selector,normal.unit_id)
			await screen("restart-trained"); c.army_overlay.hide()
		else:
			var battle_id: String=normal.outcome.battle.battle_id
			check(Merit.quote(c,battle_id,"historical:004").ok==(label=="unawarded"),"restart preserves reward eligibility "+label)
			c.open_battle_merit(battle_id); await screen("restart-"+label)
			if label=="final":
				check(c.merit_overlay.reward_buttons["historical:004"].disabled,"restored reward button is completed")
				for n: int in range(3):
					check(not Merit.reward(c,battle_id,"historical:004").ok and full_state()==saved.state,"repeat reward has no cost or effect "+str(n))
			for down: bool in [true,false]:
				var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=down; root.push_input(event,true)
			await process_frame
			check(not c.merit_overlay.visible and not c.map_area.modal_input_locked,"restored result Esc releases input "+label)
	var previous: int=stamp(); await next_month("restart continuation")
	check(stamp()==previous+1,"restored final campaign continues normally")
	var output:=FileAccess.open(LOOP_DIR+"restart.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures},"\t")); output.close()
	print("GAMEPLAY RESTART: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
