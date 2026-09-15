extends "res://tests/military_supply_expansion_audit.gd"
func _run() -> void:
 DIR="res://.godot/completion-training-results/"; DirAccess.make_dir_recursive_absolute(DIR)
 var rows: Array=[]
 for player: String in ["silla","baekje"]:
  seed(63220260915); await start(Scenarios.SCENARIOS[0],player,"historical"); events()
  c._on_load_button_pressed("res://.godot/supply-expansion-results/"+player+"-60months.json"); events()
  for step: int in range(24):
   c._on_end_turn_button_pressed(); events(); await process_frame
   for f: String in ["silla","baekje","goguryeo"]:
    if f!=player: rows.append(metrics(f).merged({"player":player,"step":step+1}))
  c._on_save_button_pressed(DIR+player+"-after24.json")
 var file:=FileAccess.open(DIR+"months.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows)); file.close()
 print("TRAINING AUDIT DONE ",rows.size()); quit()