extends Control
## A live campaign view, never a second campaign or a command implementation.
const Map = preload("res://ui/korea_layout_v1/approved_korea_map.gd")
var campaign: Node
var map: Control
var selected: String = "dalgubeol"
var active: bool = false
var suspended: bool = false
var header: Label
var city_title: Label
var city_info: Label
var statistics: Label
var threat: Button
var sources: OptionButton
var route_text: Label
var support: Button
var preview: Button
var bottom: HBoxContainer
var buttons: Dictionary = {}
var refresh_clock: float = 0.0
var route_open: bool = false
var terrain_note: Label
var resources: Label
var last_action: String = ""
var opened_once: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_value := Theme.new()
	theme_value.default_font = preload("res://ui/faction_selection_v1/assets/SamhanUISans-Medium.ttf")
	theme_value.default_font_size = 20
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("6f261e") if state == "pressed" else Color("101b1a") if state != "hover" else Color("3d3830")
		style.border_color = Color("c2a36a")
		style.set_border_width_all(1)
		style.set_content_margin_all(9)
		style.set_corner_radius_all(3)
		theme_value.set_stylebox(state, "Button", style)
		theme_value.set_stylebox(state, "OptionButton", style)
	theme_value.set_color("font_color", "Label", Color("eee8d8"))
	theme_value.set_color("font_color", "Button", Color("d6b678"))
	theme = theme_value
	var bg := ColorRect.new()
	bg.color = Color("101b1a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.custom_minimum_size.y = 72
	box.add_child(top)
	header = label(top, "", 23)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources = label(top, "", 20)
	threat = button(top, "침공 예고", func(): suspend(); campaign.open_invasions(), "invasions")
	threat.custom_minimum_size = Vector2(150,48)
	button(top, "저장·메뉴", func(): suspend(); campaign.navigation_menu.show_popup(), "menu")
	button(top, "전체 지도", close, "close")
	var tools_row := HBoxContainer.new()
	box.add_child(tools_row)
	label(tools_row, "  지도 비교  ", 16)
	button(tools_row, "중부·동해", func(): map.focus_detail(), "detail_focus")
	button(tools_row, "후보 보기", func():
		map.set_detail_comparison(not map.detail_comparison)
		buttons.detail_r3.text = "r3 보충"
		buttons.detail_corrected.text = "보정 보기"
		buttons.detail_compare.text = "원본 보기" if map.detail_comparison else "후보 보기"
		terrain_note.text = "중부·동해 후보 비교 · 해안/강 정합 미완료 · 자동 전환 차단" if map.detail_comparison else "휠 확대 · 드래그 이동 · 성 선택  |  승인 지도 · 35개 거점 · 영토 경계 자료 미확정", "detail_compare")
	button(tools_row, "보정 보기", func():
		map.set_corrected_comparison(not map.corrected_comparison)
		buttons.detail_r3.text = "r3 보충"
		buttons.detail_compare.text = "후보 보기"
		buttons.detail_corrected.text = "원본 보기" if map.corrected_comparison else "보정 보기"
		terrain_note.text = "중부·동해 r2 보정 비교 · 일부 원본 복귀/흐림 · 자동 전환 차단" if map.corrected_comparison else "승인 지도 · 35개 거점 · 영토 경계 자료 미확정", "detail_corrected")
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(middle)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	nav.custom_minimum_size.x = 116
	middle.add_child(nav)
	for pair: Array in [["영지", "domestic"], ["군사", "army"], ["생산", "production"], ["인사", "politics"]]:
		var key: String = pair[1]
		var b := button(nav, pair[0], func(): action(key), key)
		b.custom_minimum_size.y = 48
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 18)
	var zoom_row := HBoxContainer.new()
	tools_row.add_child(zoom_row)
	button(zoom_row, "+", func(): map._set_map_zoom(map.map_zoom * map.MAP_ZOOM_STEP, map.size / 2), "zoom_in")
	button(zoom_row, "−", func(): map._set_map_zoom(map.map_zoom / map.MAP_ZOOM_STEP, map.size / 2), "zoom_out")
	button(tools_row, "선택 성", func(): map.focus_on_province(selected, 5.0), "focus")
	button(tools_row, "전체", func(): map.fit_all(), "overview")
	button(tools_row, "r3 보충", func():
		map.set_r3_comparison(not map.r3_comparison)
		buttons.detail_r3.text = "r2 복귀" if map.r3_comparison else "r3 보충"
		buttons.detail_compare.text = "후보 보기"
		buttons.detail_corrected.text = "원본 보기"
		terrain_note.text = "중부·동해 r3 보충 + r2 · 물길 정합 검토 중 · 자동 전환 차단" if map.r3_comparison else "중부·동해 r2 보정 비교 · 일부 원본 복귀/흐림 · 자동 전환 차단", "detail_r3")
	map = Map.new()
	map.z_index = 20
	map.campaign = campaign
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(map)
	map.settlement_selected.connect(select_city)
	bottom = HBoxContainer.new()
	bottom.custom_minimum_size.y = 260
	bottom.add_theme_constant_override("separation", 12)
	box.add_child(bottom)
	var left := column(bottom)
	city_title = label(left, "", 28)
	city_title.add_theme_color_override("font_color", Color("f3e2b7"))
	city_info = label(left, "", 18)
	city_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var center := column(bottom)
	label(center, "주둔 · 군량", 22)
	statistics = label(center, "", 18)
	statistics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var right := column(bottom)
	label(right, "방어 준비 · 지원", 23)
	sources = OptionButton.new()
	right.add_child(sources)
	sources.item_selected.connect(func(_n): route_open = true; refresh_route())
	route_text = label(right, "", 17)
	route_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview = button(right, "지원 경로 보기", func(): route_open = true; refresh_route(), "preview")
	var support_row := HBoxContainer.new()
	right.add_child(support_row)
	support = button(support_row, "부대 선택·지원", open_support, "support")
	button(support_row, "취소", func(): route_open = false; refresh_route(), "cancel")
	var turn := VBoxContainer.new()
	turn.custom_minimum_size.x = 146
	bottom.add_child(turn)
	label(turn, "명령을 마쳤다면", 16)
	var end_turn := button(turn, "턴 종료\n다음 달로", advance, "month")
	end_turn.custom_minimum_size.y = 86
	var turn_style := theme_value.get_stylebox("pressed", "Button").duplicate()
	end_turn.add_theme_stylebox_override("normal", turn_style)
	var note := label(box, "휠 확대 · 드래그 이동 · 성 선택  |  승인 지도 · 35개 거점 · 영토 경계 자료 미확정", 15)
	terrain_note = note
	note.add_theme_color_override("font_color", Color("b9b9aa"))
	hide()

func button(parent: Node, text: String, callback: Callable, key: String) -> Button:
	var b := Button.new()
	b.text = text
	parent.add_child(b)
	b.pressed.connect(callback)
	buttons[key] = b
	return b

func label(parent: Node, text: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

func column(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b1a")
	style.border_color = Color("77623f")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var result := VBoxContainer.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.size_flags_stretch_ratio = 1
	panel.add_child(result)
	return result

func open() -> void:
	if busy(): return
	active = true
	suspended = false
	show()
	select_city(selected if campaign.provinces.has(selected) else campaign.selected_province_id)
	# Keep the comparison camera when returning from the full map.
	if not opened_once:
		if selected == "dalgubeol": map.call_deferred("focus_region")
		else: map.call_deferred("focus_on_province", selected, 4.2)
	opened_once = true
	campaign.map_area.hide_city_card()
	campaign.province_panel.hide()
	campaign._sync_modal_map_input()

func close() -> void:
	active = false
	suspended = false
	hide()
	campaign.select_province(selected, false)
	campaign.map_area.focus_on_province(selected)
	campaign._sync_modal_map_input()

func suspend() -> void:
	suspended = true
	hide()
	campaign._sync_modal_map_input()

func busy() -> bool:
	if campaign.navigation_menu.get_popup().visible: return true
	var confirmation: Node = campaign.navigation_menu.get_node_or_null("ConfirmationDialog")
	if confirmation != null and confirmation.visible: return true
	if campaign.event_presentation != null and campaign.event_presentation.active: return true
	for property: String in ["production_overlay", "army_overlay", "politics_overlay", "invasion_overlay", "merit_overlay", "domestic_overlay", "industry_overlay", "supply_overlay", "recruitment_overlay", "diplomacy_overlay", "power_dialog", "playability_dialog", "transfer_panel", "ending_dialog", "ending_load_dialog", "ending_save_dialog", "governor_transfer_confirmation", "governor_appointment_confirmation"]:
		var node: Node = campaign.get(property)
		if node != null and node.visible: return true
	return false

func _process(delta: float) -> void:
	if not active: return
	if busy():
		if visible: suspend()
		return
	if suspended:
		suspended = false
		show()
		campaign.select_province(selected, false)
		campaign.map_area.hide_city_card()
		campaign.province_panel.hide()
		refresh()
		campaign._sync_modal_map_input()
	refresh_clock += delta
	if refresh_clock >= 0.2:
		refresh_clock = 0
		refresh()

func select_city(id: String) -> void:
	if not campaign.provinces.has(id): return
	selected = id
	campaign.select_province(id, false)
	route_open = false
	refresh()

func refresh() -> void:
	if not campaign.provinces.has(selected): return
	var p: Dictionary = campaign.provinces[selected]
	header.text = "  %s  ·  거점 지도\n  %d년 %d월" % [campaign.player_faction, campaign.year, campaign.month]
	resources.text = "국고  %s 금\n세력 군량  %s" % [String.num_int64(campaign.gold), String.num_int64(campaign.food)]
	city_title.text = str(p.name)
	city_info.text = "%s 영토\n태수  %s\n인접 거점 %d곳 · 치안 %d · 성벽 %d" % [p.faction, p.governor, campaign.province_connections.get(selected, []).size(), p.public_order, p.fortress]
	var owned: bool = p.faction == campaign.player_faction
	var production: Array[String] = []
	if owned:
		for id: String in campaign.strategy_state.get("city_production", {}).get(selected, {}):
			var order: Dictionary = campaign.strategy_state.city_production[selected][id]
			if order.get("enabled", false): production.append(str(campaign.ProductionData.RECIPES[id].name) + " · " + str(order.status))
	statistics.text = "주둔 병력  %d명\n군량  %d / %d\n생산  %s" % [p.troops, p.food_stock, p.granary_capacity, ("없음" if production.is_empty() else " / ".join(production)) if owned else "아군 도시에서 확인"]
	statistics.tooltip_text = statistics.text
	if owned and map.map_zoom >= 4.2:
		var tasks: Array[String] = []
		for job: Dictionary in campaign.strategy_state.get("domestic", {}).get("jobs", {}).values():
			if job.get("kind", "") not in ["build", "research", "production"] or job.city_id != selected or job.status not in ["pending", "paused"]: continue
			if job.kind == "production":
				tasks.append("생산 담당 " + str(campaign.get_officer(job.officer_id).get("name", "없음")))
			else:
				var person: Dictionary = campaign.get_officer(job.officer_id)
				var months: int = campaign.Industry.remaining_months(campaign.strategy_state, selected, person, job.kind, maxi(0, int(job.required) - int(job.progress)))
				tasks.append("%s: %s" % ["건설" if job.kind == "build" else "연구", "일시 중지" if job.status == "paused" else "현재 조건 약 %d개월" % months])
		if not tasks.is_empty(): statistics.text += "\n" + " / ".join(tasks)
		statistics.tooltip_text = statistics.text
	for key: String in ["domestic", "army", "production"]:
		buttons[key].disabled = not owned or campaign.Ending.finished(campaign.strategy_state)
	for key: String in ["domestic", "army", "production", "politics"]:
		buttons[key].set_pressed_no_signal(key == last_action)
	buttons.month.disabled = campaign.Ending.finished(campaign.strategy_state)
	var previous: String = source_id()
	var candidates: Array[String] = []
	if owned:
		for id: String in campaign.province_connections.get(selected, []):
			if campaign.provinces[id].faction != campaign.player_faction: continue
			candidates.append(id)
	var old: Array[String] = []
	for n: int in range(sources.item_count): old.append(str(sources.get_item_metadata(n)))
	if old != candidates:
		sources.clear()
		for id: String in candidates:
			sources.add_item("")
			sources.set_item_metadata(sources.item_count - 1, id)
			if id == previous: sources.select(sources.item_count - 1)
	for n: int in range(sources.item_count):
		sources.set_item_text(n, campaign.provinces[candidates[n]].name + " → " + p.name)
	refresh_route()
	var warnings: Array[String] = []
	for order: Dictionary in campaign.Invasions.pending(campaign.strategy_state):
		if order.defender != campaign.player_faction_id: continue
		warnings.append("%s · %s · 예고 당시 적 %d명" % [campaign.provinces[order.target].name, campaign.Power.date(order.due_month), order.announced_troops])
	threat.text = "침공 예고  %d건" % warnings.size()
	threat.tooltip_text = "\n".join(warnings) if not warnings.is_empty() else "현재 예고된 침공이 없습니다. 침공 목록 열기"
	threat.modulate = Color("ffcc9e") if not warnings.is_empty() else Color.WHITE
	map.selected = selected
	map._refresh_marker_data()

func source_id() -> String:
	return str(sources.get_item_metadata(sources.selected)) if sources.selected >= 0 else ""

func refresh_route() -> void:
	var turns: int = campaign.province_transfer_turns(source_id(), selected)
	preview.disabled = turns <= 0
	support.disabled = turns <= 0 or not route_open or campaign.Ending.finished(campaign.strategy_state)
	if route_open and turns > 0: map.preview_source = source_id()
	else: map.clear_route()
	if turns <= 0: route_text.text = "직접 연결된 아군 지원 출발지가 없습니다."
	elif not route_open: route_text.text = "출발지를 골라 경로를 확인하세요."
	else: route_text.text = "%s → %s · %d개월\n%s 도착 예정" % [campaign.provinces[source_id()].name, campaign.provinces[selected].name, turns, campaign.Power.date(campaign.year * 12 + campaign.month + turns)]
	support.tooltip_text = "출발지의 지원 가능한 부대를 선택합니다. 업무 중이거나 군권 인계 중인 부대는 기존 명령 제한을 따릅니다."
	if map.selection_layer != null: map.selection_layer.queue_redraw()

func open_support() -> void:
	refresh_route()
	if support.disabled: return
	var source := source_id()
	suspend()
	campaign.open_army(source)
	var options: OptionButton = campaign.army_overlay.destination
	for n: int in range(options.item_count):
		if options.get_item_metadata(n) == selected: options.select(n); break

func action(kind: String) -> void:
	if buttons[kind].disabled: return
	last_action = kind
	refresh()
	campaign.select_province(selected, false)
	suspend()
	match kind:
		"domestic": campaign.open_domestic("agriculture")
		"army": campaign.open_army(selected)
		"production": campaign._on_city_card_production_requested(selected)
		"politics":
			campaign.open_politics()
			var targets: OptionButton = campaign.politics_overlay.targets
			for n: int in range(targets.item_count):
				var item: Dictionary = targets.get_item_metadata(n)
				if item.kind == "governor" and item.city == selected:
					targets.select(n)
					campaign.politics_overlay.populate()
					break

func advance() -> void:
	if busy(): return
	campaign._on_end_turn_button_pressed()
	refresh()
