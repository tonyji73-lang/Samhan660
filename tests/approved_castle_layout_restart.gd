extends "res://tests/approved_castle_layout_test.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1920,1080)
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CASTLE_OUT+"normal.json"))
	await start(Scenarios.SCENARIOS[0],"baekje","historical");await settle_events();await pause()
	check(OS.get_process_id()!=int(normal.pid),"new OS process")
	c._on_load_button_pressed(normal.slot);await pause()
	check(full_state()==normal.state,"date faction resources units pending orders restored")
	ui=c.settlement_overlay;await click(c.settlement_button)
	check(ui.map.get_layout_status().ready and ui.map.get_visible_ids().size()==35,"approved map default after restore")
	var prior: int=stamp()
	await click(ui.buttons.month);await settle_events();c.merit_overlay.hide();await pause()
	check(stamp()==prior+1 and c.Army.units(c.strategy_state)[normal.unit].location=="dalgubeol","restored support resolves once")
	check(c.pending_transfer_orders.filter(func(o): return o.unit_ids.has(normal.unit)).is_empty(),"no duplicate reservation")
	ui.select_city("dalgubeol");ui.map.focus_region();await shot("restart-gameplay")
	var f:=FileAccess.open(CASTLE_OUT+"restart.json",FileAccess.WRITE);f.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures}));f.close()
	print("APPROVED RESTART: ",checks," checks, ",failures," failures");quit(0 if failures==0 else 1)
