extends SceneTree
## External opt-in GUI driver. Uses the unchanged final EXE/PCK and real saved campaign.
class Driver extends "res://qa/windows_export_v1_10.gd":
	func _ready() -> void:
		root=get_tree().root; phase="recovery_complete"
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--out="): out=arg.trim_prefix("--out=")
		run.call_deferred()
	func run() -> void:
		await get_tree().create_timer(1).timeout; root.size=Vector2i(1280,720)
		var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("recovery-restart.json")))
		get_tree().current_scene._load_selected_game(receipt.slot); await get_tree().create_timer(3).timeout; c=get_tree().current_scene
		await settle_events(); var job_id: String=""
		for job: Dictionary in c.strategy_state.domestic.jobs.values():
			if job.kind=="training" and job.get("faction_id","")=="silla" and job.status=="pending": job_id=job.id; break
		check(not job_id.is_empty(),"normal defeat recovery has pending training")
		if job_id.is_empty(): finish(1); return
		var job: Dictionary=c.strategy_state.domestic.jobs[job_id]; var paid: int=job.cost_paid; var history_count: int=job.history.size()
		await advance_month(); await advance_month()
		job=c.strategy_state.domestic.jobs[job_id]
		check(job.status=="completed","two GUI months complete quoted recovery training")
		check(job.history.size()==history_count+2 and int(job.cost_paid)==paid+100,"two actual training charges and no duplicate processing")
		await click(c.settlement_overlay.buttons.army); var a: Node=c.army_overlay
		for b: Button in buttons(a.unit_list):
			if b.text.contains(str(job.unit_id)): await click(b); break
		await click(a.mode_buttons.training); await capture("recovery-training-completed-720")
		note("completed training",{"summary":a.training_summary.text,"job":job,"unit":c.strategy_state.unit_rosters[job.unit_id]})
		await key(KEY_ESCAPE); await save_new(); evidence={"trace":trace}; finish()
func _initialize() -> void:
	start.call_deferred()
func start() -> void:
	change_scene_to_file("res://title_screen.tscn")
	await process_frame
	root.add_child(Driver.new())
