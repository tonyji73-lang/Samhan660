extends "res://tests/faction_economy_test.gd"

const REPORT = "res://.godot/main-host-save.json"

func host_state() -> Dictionary:
	return canonical({"year":c.year,"month":c.month,"faction":c.player_faction,
		"gold":c.gold,"provinces":c.provinces,"inventory":c.strategy_state.city_inventory,
		"accounts":c.strategy_state.faction_economy.accounts,"units":c.strategy_state.unit_rosters,
		"orders":c.pending_transfer_orders})

func slot_hashes() -> Dictionary:
	var result: Dictionary={}
	for file: String in DirAccess.get_files_at("user://"):
		if file.ends_with(".json"): result[file]=FileAccess.get_sha256("user://"+file)
	return result

func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var restoring: bool=OS.get_cmdline_user_args().has("restore")
	var report: Dictionary={}
	if restoring:
		report=JSON.parse_string(FileAccess.get_file_as_string(REPORT))
		check(report.saved and report.pid!=OS.get_process_id(),"separate process after successful save")
		await start(Scenarios.SCENARIOS[1],"silla","historical")
		check(host_state()!=report.state,"fresh campaign differs before loading")
		c._on_load_button_pressed(report.slot)
		var restored: Dictionary=host_state()
		for key: String in report.state:
			check(restored[key]==report.state[key],"host restart restores "+key)
		report["restore_pid"]=OS.get_process_id()
		report["restored"]=failures==0
	else:
		await start(Scenarios.SCENARIOS[0],"baekje","historical")
		check(c.request_recruitment("sabi",1000).ok,"save fixture uses paid recruitment")
		await advance()
		var slot: String="user://main_office_probe_%d_%d.json" % [int(Time.get_unix_time_from_system()),OS.get_process_id()]
		check(not FileAccess.file_exists(slot),"unique test slot does not overwrite a save")
		report={"pid":OS.get_process_id(),"slot":slot,"user_dir":ProjectSettings.globalize_path("user://"),"existing":slot_hashes(),"state":host_state()}
		report["saved"]=c._on_save_button_pressed(slot)
		check(report.saved and FileAccess.file_exists(slot),"native save writes actual host user directory")
	var current: Dictionary=slot_hashes()
	for file: String in report.existing:
		check(current.get(file,"")==report.existing[file],"preserved existing slot "+file)
	report["checks"]=checks
	report["failures"]=failures
	var output:=FileAccess.open(REPORT,FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	print("HOST SAVE ","RESTORE" if restoring else "WRITE",": ",checks," checks, ",failures," failures; ",report.user_dir)
	quit(0 if failures==0 else 1)
