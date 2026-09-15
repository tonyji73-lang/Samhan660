extends SceneTree

const Systems = preload("res://samhan_strategy_systems.gd")
const Campaign = preload("res://campaign_main.tscn")
const Scenarios = preload("res://scenario_data.gd")
const Setup = preload("res://new_game_setup.tscn")
var checks: int = 0
var failures: int = 0
var system = Systems.new()
var state: Dictionary
var provinces: Dictionary
var officers: Dictionary
var assignments: Dictionary
var active: Array[String] = ["신라", "백제"]


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func fixture(value: int = 0) -> void:
	provinces = {"geumseong": {"faction": "신라", "commerce": 50}, "sabi": {"faction": "백제", "commerce": 50}}
	officers = {"사절": {"politics": 98, "intelligence": 95, "authority": 95}, "다른 사절": {"politics": 50}, "외국 사절": {"politics": 100}}
	assignments = {"geumseong": ["사절", "다른 사절"], "sabi": ["외국 사절"]}
	state = {"relations": {}, "diplomacy_last_action_month": {}, "officer_metadata": {},
		"province_buildings": {"geumseong": {"market": 1}, "sabi": {"market": 1}}, "trade_routes": [], "next_trade_route_id": 1}
	system._ensure_relation(state, "신라", "백제").value = value


func quote(action: String, month: int = 1, money: int = 1000, name_value: String = "사절", target: String = "백제") -> Dictionary:
	return system.get_diplomatic_action_quote(state, "신라", target, action, {"name": name_value, "politics": 999}, 632, month, money, provinces, officers, assignments, active)


func perform(action: String, month: int = 1, money: int = 1000, name_value: String = "사절") -> Dictionary:
	return system.perform_diplomatic_action(state, "신라", "백제", action, {"name": name_value}, 632, month, money, provinces, officers, assignments, active)


func _backend() -> void:
	fixture()
	var before: String = JSON.stringify(state)
	check(not quote("trade_pact").ok and quote("trade_pact").reason.contains("10"), "relation zero blocks trade negotiation")
	check(quote("trade_pact").chance == 69 and quote("trade_pact").envoy.politics == 98, "quote uses authoritative stats and original integer formula, ignores forged stats")
	for target: String in ["신라", "없음"]:
		check(not quote("gift", 1, 1000, "사절", target).ok, "self/inactive target blocked: " + target)
	for name_value: String in ["외국 사절", "존재하지 않음", ""]:
		check(not quote("gift", 1, 1000, name_value).ok and not perform("gift", 1, 1000, name_value).executed, "invalid envoy rejected: " + name_value)
	check(JSON.stringify(state) == before, "quotes and rejected commands never mutate state")
	provinces.geumseong.faction = "백제"
	check(not quote("gift").ok, "captured envoy city invalidates authority")
	provinces.geumseong.faction = "신라"
	state.officer_metadata["사절"] = {"faction": "백제"}
	check(not quote("gift").ok, "foreign metadata rejected even in player city")
	state.officer_metadata.clear()
	assignments.geumseong.erase("사절")
	check(not quote("gift").ok, "unassigned/transferring envoy rejected")
	assignments.geumseong.append("사절")
	var result: Dictionary = perform("gift", 1, 199)
	check(not result.executed and result.gold_cost == 0 and JSON.stringify(state) == before, "insufficient gold has no partial effects or monthly consumption")
	result = perform("gift", 1, 200)
	check(result.ok and result.executed and result.gold_cost == 200 and result.chance == 100 and system.get_relation(state, "신라", "백제").value == 12, "gift costs 200 and adds twelve at exact boundary")
	check(state.diplomacy_last_action_month["신라"] == 632 * 12 + 1 and not quote("trade_pact").ok, "gift consumes monthly national action")
	check(not quote("gift", 1, 1000, "다른 사절").ok, "changing envoy cannot bypass monthly action")
	check(quote("trade_pact", 2).ok and quote("trade_pact", 2).chance == 71, "following month permits trade with shared displayed chance")
	var negotiated: Dictionary = state.duplicate(true)
	var success_month: int = 2
	while system.diplomatic_roll("신라", "백제", "trade_pact", "사절", 632, success_month) >= 71:
		success_month += 1
	result = perform("trade_pact", success_month)
	check(result.ok and result.chance == 71 and result.gold_cost == 0 and system.get_relation(state, "신라", "백제").value == 17, "successful negotiation adds five at zero cost")
	var relation: Dictionary = system._ensure_relation(state, "신라", "백제")
	check(relation.treaties.count("통상 조약") == 1 and result.message == "백제과 통상협정을 체결했습니다.", "one compatible treaty and Korean success message")
	check(not quote("trade_pact", success_month + 1).ok, "existing pact blocks duplication in later month")
	check(system.get_relation(state, "백제", "신라") == relation and state.relations.size() == 1, "sorted pair shares a single relationship ledger")
	for treaty: String in ["불가침", "동맹", "혼인 동맹"]:
		relation.treaties.append(treaty)
	relation.status = "동맹"
	result = perform("cancel_trade_pact", success_month + 1)
	check(result.ok and relation.value == 7 and relation.treaties == ["불가침", "동맹", "혼인 동맹"] and relation.status == "동맹", "cancellation removes only trade pact and deducts ten")
	check(not quote("gift", success_month + 1).ok and not quote("cancel_trade_pact", success_month + 2).ok, "cancellation consumes month; absent treaty cannot cancel")
	state = negotiated.duplicate(true)
	var fail_month: int = 2
	while system.diplomatic_roll("신라", "백제", "trade_pact", "사절", 632, fail_month) < 71:
		fail_month += 1
	result = perform("trade_pact", fail_month)
	check(not result.ok and result.executed and result.chance == 71 and system.get_relation(state, "신라", "백제").value == 9, "failed negotiation deducts three and records an executed action")
	check(not perform("trade_pact", fail_month).executed and not quote("gift", fail_month).ok, "failure cannot retry or gift in same month")
	var receipt: Dictionary = result.duplicate(true)
	state = JSON.parse_string(JSON.stringify(negotiated))
	result = perform("trade_pact", fail_month)
	check(result == receipt, "same pre-action JSON save gives identical negotiation result")
	var roll: int = system.diplomatic_roll("신라", "백제", "trade_pact", "사절", 632, 1)
	check(roll == system.diplomatic_roll("신라", "백제", "trade_pact", "사절", 632, 1), "roll is deterministic")
	check(system.diplomatic_roll("신라", "백제", "trade_pact", "김법민", 632, 2) == 35, "SHA256 roll matches independent golden vector including envoy/year/month")
	check(system.diplomatic_roll("신라", "백제", "trade_pact", "사절", 632, 0) == absi(hash("신라:백제:trade_pact:632")) % 100, "legacy no-month call retains original seed behavior")
	fixture(50)
	relation = system._ensure_relation(state, "신라", "백제")
	relation.treaties = ["통상 조약", "동맹"]
	result = system.perform_diplomatic_action(state, "신라", "백제", "declare_war", {}, 632)
	check(result.ok and relation.status == "전쟁" and relation.treaties.is_empty(), "legacy declaration removes treaties and sets war")
	check(not quote("gift").ok and not quote("trade_pact").ok, "war blocks friendship and trade")
	fixture(50)
	before = JSON.stringify(state)
	result = system.open_trade_route(state, "신라", "백제", "geumseong", "sabi", "철")
	check(not result.ok and result.reason == "먼저 상대 세력과 통상협정을 체결해야 합니다." and JSON.stringify(state) == before, "high relationship without pact cannot open a route")
	relation = system._ensure_relation(state, "신라", "백제")
	relation.treaties = ["통상 조약"]
	state.province_buildings.geumseong.market = 0
	check(system.open_trade_route(state, "신라", "백제", "geumseong", "sabi", "철").reason.contains("출발"), "pact then checks origin market")
	state.province_buildings.geumseong.market = 1
	state.province_buildings.sabi.market = 0
	check(system.open_trade_route(state, "신라", "백제", "geumseong", "sabi", "철").reason.contains("도착"), "pact then checks destination market")
	state.province_buildings.sabi.market = 1
	check(not system.open_trade_route(state, "신라", "신라", "geumseong", "sabi", "철").ok, "domestic route is not international trade")
	check(system.open_trade_route(state, "신라", "백제", "geumseong", "sabi", "철").ok, "valid pact and markets allow existing route backend")
	check(not system.open_trade_route(state, "신라", "백제", "geumseong", "sabi", "철").ok, "route duplication still blocked")
	check(system._process_trade(state, provinces).faction_gold_delta == {"신라": 40, "백제": 40}, "existing seasonal route formula preserved")
	for blocked: String in ["cancelled", "war", "inactive"]:
		relation.treaties = [] if blocked == "cancelled" else ["통상 조약"]
		relation.status = "전쟁" if blocked == "war" else "중립"
		state.trade_routes[0].active = blocked != "inactive"
		before = JSON.stringify(state)
		check(system._process_trade(state, provinces).faction_gold_delta.is_empty() and JSON.stringify(state) == before and state.trade_routes.size() == 1, "paused route is retained with no gold or relation change: " + blocked)
		if blocked == "war":
			check(not system.open_trade_route(state, "신라", "백제", "sabi", "geumseong", "철").ok, "war blocks new routes even with stale pact")
	var legacy: Dictionary = {"relations": state.relations.duplicate(true)}
	before = JSON.stringify(legacy.relations)
	system.normalize_loaded_state(legacy)
	check(legacy.diplomacy_last_action_month.is_empty() and JSON.stringify(legacy.relations) == before, "legacy normalization adds unused month ledger without changing treaties")
	var alias_state: Dictionary = {"relations": {"백제|왜(야마토)": {"value": 23, "status": "우호", "treaties": ["불가침"]}}}
	before = JSON.stringify(alias_state)
	check(system.get_relation(alias_state, "왜(야마토 조정)", "백제").value == 23 and JSON.stringify(alias_state) == before, "old Yamato relationship key is read without migration or regrant")
	system._ensure_relation(alias_state, "백제", "왜(야마토 조정)").value = 24
	check(alias_state.relations.size() == 1 and alias_state.relations["백제|왜(야마토)"].value == 24, "canonical writes reuse the old single relationship ledger")
	fixture()
	state.diplomacy_last_action_month["신라"] = 632 * 12 + 12
	check(system.get_diplomatic_action_quote(state, "신라", "백제", "gift", {"name": "사절"}, 633, 1, 1000, provinces, officers, assignments, active).ok, "month key includes year and permits January after December")
	fixture(-4)
	check(quote("trade_pact").chance == 69, "negative relation division truncates toward zero as before")
	officers["사절"] = {"politics": 999, "intelligence": 999, "authority": 999}
	check(quote("trade_pact").chance == 95, "chance upper cap 95")
	officers["사절"] = {"politics": -999, "intelligence": -999, "authority": -999}
	check(quote("trade_pact").chance == 15, "chance lower cap 15")


func _new_campaign(index: int) -> Node:
	var scenario: Dictionary = Scenarios.SCENARIOS[index]
	root.set_meta("new_game_settings", {"scenario_id": scenario.id, "scenario_year": scenario.year, "scenario_season": scenario.season, "faction": "silla", "play_style": "historical", "difficulty": "normal"})
	var c: Node = Campaign.instantiate()
	root.add_child(c)
	# The integrated campaign also dispatches opening cutscenes. This suite tests
	# diplomacy after entry; the foundation UI test covers the opening itself.
	c.event_presentation.display_level = "minimal"
	current_scene = c
	return c


func _save_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _campaign_cases() -> void:
	var path: String = OS.get_temp_dir().path_join("samhan-diplomacy-%d.json" % OS.get_process_id())
	for index: int in range(5):
		var c: Node = _new_campaign(index)
		await process_frame
		await process_frame
		var initial_gold: int = c.gold
		var initial_relations: String = JSON.stringify(c.strategy_state.relations)
		c.navigation_menu.get_popup().id_pressed.emit(c.navigation_menu.ITEM_DIPLOMACY)
		var d: Node = c.diplomacy_overlay
		check(d.visible and c.end_turn_button.disabled, "%d Menu diplomacy opens and locks turns" % c.year)
		var target_ids: Array[String] = []
		for i: int in range(d.targets.item_count):
			target_ids.append(str(d.targets.get_item_metadata(i)))
		var expected_ids: Array[String] = []
		for id: String in Scenarios.get_active_faction_ids(c.scenario_id):
			if id != "silla" and c.get_faction_controller(id) != c.CONTROLLER_INACTIVE:
				expected_ids.append(id)
		check(target_ids == expected_ids and not target_ids.has("silla"), "%d target list uses scenario order and excludes self/inactive" % c.year)
		var before_selection: String = c.selected_province_id
		var before_month: int = c.month
		c.select_province("sabi")
		c._on_end_turn_button_pressed()
		check(c.selected_province_id == before_selection and c.month == before_month, "%d campaign commands blocked by diplomacy modal" % c.year)
		var envoy: String = d.selected_envoy_name
		d.refresh()
		check(d.selected_envoy_name == envoy and c.get_diplomacy_envoys().size() > 0, "%d envoy identity retained through refresh" % c.year)
		var sila_tang: Dictionary = c.strategy.get_relation(c.strategy_state, "신라", "당")
		var baekje_yamato: Dictionary = c.strategy.get_relation(c.strategy_state, "백제", "왜(야마토 조정)")
		print("INITIAL PACTS %d: Silla-Tang=%s, Baekje-Yamato=%s; targets=%s" % [c.year, sila_tang.treaties, baekje_yamato.treaties, target_ids])
		check(sila_tang.treaties.has("통상 조약") == (c.year >= 660), "%d existing Silla-Tang initial rule retained" % c.year)
		check(baekje_yamato.treaties.has("통상 조약") == (c.year == 660), "%d canonical Baekje-Yamato agreement only when both start factions exist" % c.year)
		check(c.gold == initial_gold and c.strategy_state.diplomacy_last_action_month.is_empty() and JSON.stringify(c.strategy_state.relations) == initial_relations, "%d opening/quotes grant nothing and consume no month" % c.year)
		if index == 0:
			c._on_save_button_pressed(path)
			var original: String = FileAccess.get_file_as_string(path)
			var q: Dictionary = c.get_diplomatic_action_quote("baekje", "gift", envoy)
			var result: Dictionary = c.request_diplomatic_action("baekje", "gift", envoy)
			check(q.ok and result.ok and result.chance == q.chance and c.gold == initial_gold - 200 and c.strategy.get_relation(c.strategy_state, "신라", "백제").value == 12, "real campaign gift updates treasury/relation once")
			check(c.log_label.text == result.message, "campaign log receives Korean result")
			c._close_diplomacy()
			c._open_diplomacy()
			check(not c.get_diplomatic_action_quote("baekje", "gift", envoy).ok, "closing/reopening cannot retry same month")
			c._on_save_button_pressed(path)
			c._on_load_button_pressed(path)
			check(c.gold == initial_gold - 200 and c.strategy.get_relation(c.strategy_state, "신라", "백제").value == 12 and not c.get_diplomatic_action_quote("baekje", "gift", envoy).ok, "real save preserves month and gift effects")
			c._on_end_turn_button_pressed()
			check(c.get_diplomatic_action_quote("baekje", "trade_pact", envoy).ok, "normal next monthly turn permits negotiation")
			c._on_save_button_pressed(path)
			var before_attempt: String = FileAccess.get_file_as_string(path)
			result = c.request_diplomatic_action("baekje", "trade_pact", envoy)
			var received: String = JSON.stringify(c.strategy.get_relation(c.strategy_state, "신라", "백제"))
			_save_text(path, before_attempt)
			c._on_load_button_pressed(path)
			var again: Dictionary = c.request_diplomatic_action("baekje", "trade_pact", envoy)
			check(result == again and JSON.stringify(c.strategy.get_relation(c.strategy_state, "신라", "백제")) == received, "campaign pre-action reload cannot reroll negotiation")
			c._on_save_button_pressed(path)
			c._on_load_button_pressed(path)
			check(not c.get_diplomatic_action_quote("baekje", "gift", envoy).ok, "post-attempt reload cannot reset used month")
			var legacy: Dictionary = JSON.parse_string(original)
			legacy.strategy_state.erase("diplomacy_last_action_month")
			_save_text(path, JSON.stringify(legacy))
			c._on_load_button_pressed(path)
			check(c.gold == initial_gold and c.strategy_state.diplomacy_last_action_month.is_empty() and c.get_diplomatic_action_quote("baekje", "gift", envoy).ok, "real legacy save without monthly field loads unused and unchanged")
		if index == 2:
			d.selected_target_id = "baekje"
			d.refresh()
			check(d.targets.item_count > 0 and d.details.text.contains("전쟁") and d.action_buttons.gift.disabled and d.action_buttons.trade_pact.disabled, "660 war target remains visible with friendship/trade blocked")
			d.selected_target_id = "tang"
			d.refresh()
			check(d.details.text.contains("통상협정 체결") and not d.action_buttons.cancel_trade_pact.disabled, "660 Tang initial agreement visible and cancellable")
			d._act("cancel_trade_pact")
			check(d.confirmation.visible and c.strategy.get_relation(c.strategy_state, "신라", "당").value == 70, "cancel opens confirmation before mutating")
			d.confirmation.hide()
			d.confirmation.confirmed.emit()
			var cancelled: Dictionary = c.strategy.get_relation(c.strategy_state, "신라", "당")
			check(cancelled.value == 60 and cancelled.treaties == ["동맹"] and d.result_label.text == c.log_label.text and d.action_buttons.cancel_trade_pact.disabled, "confirmed cancellation preserves alliance and immediately refreshes log/UI")
			c._on_save_button_pressed(path)
			c._on_load_button_pressed(path)
			var restored: Dictionary = c.strategy.get_relation(c.strategy_state, "신라", "당")
			check(int(restored.value) == int(cancelled.value) and restored.status == cancelled.status and restored.treaties == cancelled.treaties and not c.get_diplomatic_action_quote("tang", "gift", envoy).ok, "cancelled treaty and month persist without regrant")
			var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			legacy.erase("strategy_state")
			_save_text(path, JSON.stringify(legacy))
			c._on_load_button_pressed(path)
			check(not c.strategy.get_relation(c.strategy_state, "신라", "당").treaties.has("통상 조약") and c.gold == initial_gold, "pre-strategy legacy load does not grant historical agreements or charge gold")
		c._close_diplomacy()
		c._on_city_card_production_requested("geumgwan")
		check(c.production_overlay.visible and not d.visible, "%d production remains accessible alone" % c.year)
		c._open_diplomacy()
		check(d.visible and not c.production_overlay.visible, "%d diplomacy closes production" % c.year)
		c._close_diplomacy()
		check(not c.end_turn_button.disabled, "%d close restores turn input" % c.year)
		c.queue_free()
		await process_frame
		await process_frame
	DirAccess.remove_absolute(path)


func _setup_cases() -> void:
	var s: Node = Setup.instantiate()
	root.add_child(s)
	current_scene = s
	await process_frame
	await process_frame
	var width: float = s.faction_cards_vbox.get_parent().get_parent().get_parent().size.x
	var height: float = s.faction_buttons.values()[0].size.y
	for index: int in range(5):
		for style: String in s.PLAY_STYLE_ORDER:
			if not s.play_style_buttons.has(style):
				continue
			s.scenario_buttons[index].pressed.emit()
			s.play_style_buttons[style].button_pressed = true
			await process_frame
			await process_frame
			var seen_disabled: bool = false
			var valid: bool = true
			for id: String in s.faction_buttons:
				var button: Button = s.faction_buttons[id]
				if button.disabled:
					seen_disabled = true
				elif seen_disabled:
					valid = false
				valid = valid and is_equal_approx(button.size.y, height)
			check(valid and is_equal_approx(s.faction_cards_vbox.get_parent().get_parent().get_parent().size.x, width), "setup order and fixed size: %d/%s" % [index, style])
			check(s._get_scenario_id() == str(Scenarios.SCENARIOS[index].id) and s.scenario_title_label.text.contains(str(Scenarios.SCENARIOS[index].year)), "scenario tab and actual ID match: %d/%s" % [index, style])
	s.music_player.stop()
	await create_timer(0.15).timeout
	s.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	_backend()
	await _campaign_cases()
	await _setup_cases()
	system = null
	print("DIPLOMACY TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
