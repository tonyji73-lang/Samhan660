extends SceneTree

const Army=preload("res://army_readiness.gd")
const FIXTURE="res://tests/fixtures/dalgubeol_644_battle.json"
var checks: int=0
var failures: int=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	else: print("PASS: "+label)

func _initialize() -> void:
	if not FileAccess.file_exists(FIXTURE):
		push_error("Missing recorded battle fixture"); quit(1); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var baseline: Dictionary=fixture.battle
	var unchanged: String=JSON.stringify(baseline)
	var results: Array=[]
	for mode: int in range(4):
		# Isolated arithmetic experiment, never a campaign load or a normal command.
		# Leadership is supplied identically even when the recruited unit is absent.
		var state: Dictionary={"army":{"next_id":10000,"history":[],"battles":[]},"unit_rosters":{},"officer_registry":{"people":{}},"faction_economy":{"factions":{"silla":"신라","baekje":"백제"}}}
		var provinces: Dictionary={baseline.source:{"faction":"신라","fortress":0},baseline.target:{"faction":"백제","fortress":baseline.fortress}}
		for original: Dictionary in baseline.attacker_state+baseline.defender_state:
			var u: Dictionary=original.duplicate(true)
			if u.id=="unit:124":
				if mode==0: continue
				u.equipment=0 if mode==1 else 1000
				u.training_points=70000 if mode==3 else 50000
			state.unit_rosters[u.id]=u
		var defense: Array=Army.at_city(state,baseline.target)
		check(Army.count(state,defense)==23674,"same opposing troop count case"+str(mode+1))
		var row: Dictionary=Army.combat(state,provinces,baseline.source,baseline.target,baseline.attacker_leadership,baseline.defender_leadership,baseline.month)
		var expected: float=[54600.0,56160.0,56550.0,56706.0][mode]
		check(is_equal_approx(row.attacker_power,expected),"independent infantry formula case"+str(mode+1))
		check(is_equal_approx(row.defender_power,baseline.defender_power) and row.defender_state==baseline.defender_state,"unchanged defender snapshots and modifiers case"+str(mode+1))
		check(row.won and row.attacker_losses==13020 and row.defender_losses==23674,"existing combat outcome and loss formula case"+str(mode+1))
		check(Army.count(state,Army.units(state).keys())==row.attacker_troops+row.defender_troops-row.attacker_losses-row.defender_losses,"actual casualty mutation conserves survivors case"+str(mode+1))
		if mode==3:
			for key: String in ["attacker_troops","defender_troops","attacker_power","defender_power","won","attacker_losses","defender_losses","attacker_state"]:
				check(JSON.parse_string(JSON.stringify(row[key]))==baseline[key],"fully prepared case reproduces saved actual battle "+key)
		results.append({"case":mode+1,"troops":row.attacker_troops,"attacker_power":row.attacker_power,"defender_power":row.defender_power,"ratio":row.attacker_power/row.defender_power,"won":row.won,"losses":row.attacker_losses,"survivors":row.attacker_troops-row.attacker_losses})
	check(JSON.stringify(baseline)==unchanged,"source ledger is immutable across all cases")
	DirAccess.make_dir_recursive_absolute("res://.godot/military-balance")
	var out:=FileAccess.open("res://.godot/military-balance/results.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"experiment":"controlled calculation, not normal play","source_battle":baseline.battle_id,"results":results,"checks":checks,"failures":failures},"\t")); out.close()
	print(JSON.stringify(results,"\t"))
	print("MILITARY BALANCE: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
