extends "res://tests/settlement_ui_test.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var normal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_DIR + "normal.json"))
	await start(Scenarios.SCENARIOS[0], "baekje", "historical"); await settle_events(); await pause()
	check(OS.get_process_id() != int(normal.pid), "fresh OS process")
	c._on_load_button_pressed(normal.slot); await pause()
	check(full_state() == normal.state, "all date faction resources units politics and pending support restored")
	ui = c.settlement_overlay
	await click(c.settlement_button)
	check(ui.visible and ui.selected == "dalgubeol" and ui.header.text.contains("신라"), "restored selection and faction")
	await screen("restart-pending")
	var previous: int = stamp()
	await click(ui.buttons.month); await settle_events(); c.merit_overlay.hide(); await pause()
	check(stamp() == previous + 1 and c.Army.units(c.strategy_state)[normal.unit].location == "dalgubeol", "restored support arrives once")
	check(c.pending_transfer_orders.filter(func(o): return o.unit_ids.has(normal.unit)).is_empty(), "no stale support reservation")
	# Continue normal AI months until a genuine public threat is available.
	var observed: bool = false
	for n: int in range(12):
		if ui.threat.visible: observed = true; break
		await click(ui.buttons.month); await settle_events(); c.merit_overlay.hide(); await pause()
	check(observed, "normal AI produces visible invasion alert")
	if observed:
		await screen("natural-threat")
		var state: Dictionary = full_state()
		await click(ui.threat)
		check(c.invasion_overlay.visible and full_state() == state, "alert opens existing multi-invasion response without spending")
		await escape()
		check(ui.visible, "alert returns to settlement map")
		await click(ui.buttons.month); await settle_events(); c.merit_overlay.hide(); await pause()
		var pending: Array = c.Invasions.pending(c.strategy_state).filter(func(o): return o.defender == c.player_faction_id)
		check(ui.threat.visible == not pending.is_empty(), "resolved alerts track only current pending invasions")
		await screen("resolved-threat")
	# UI-only controlled fixture: cancellation/ownership are not called natural play.
	var saved: Dictionary = full_state()
	for order: Dictionary in c.Invasions.pending(c.strategy_state): order.status = "cancelled"
	ui.refresh()
	check(not ui.threat.visible, "controlled cancelled warnings disappear")
	c._on_load_button_pressed(normal.slot); await pause()
	check(full_state() == normal.state, "controlled fixture discarded by native restore")
	ui.select_city("geumseong")
	var owner: String = c.provinces.geumseong.faction
	c.provinces.geumseong.faction = "백제"; ui.refresh()
	check(ui.buttons.army.disabled and ui.buttons.production.disabled and ui.support.disabled, "controlled ownership change invalidates actions")
	c.provinces.geumseong.faction = owner
	c._on_load_button_pressed(normal.slot); await pause()
	await click(ui.buttons.menu)
	check(not ui.visible and c.navigation_menu.get_popup().visible, "existing save and navigation menu reachable")
	c.navigation_menu.get_popup().hide()
	var out := FileAccess.open(UI_DIR + "restart.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"pid":OS.get_process_id(), "checks":checks, "failures":failures, "natural_threat":observed, "natural_final_month":saved.month}, "\t")); out.close()
	print("SETTLEMENT RESTART: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
