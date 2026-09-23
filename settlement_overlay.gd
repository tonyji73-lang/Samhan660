extends Control
## A live campaign view, never a second campaign or a command implementation.
const Map = preload("res://ui/korea_layout_v1/approved_korea_map.gd")
const Atlas = preload("res://ui/light_atlas_v1/atlas_theme.gd")
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
var _design_stage: Control
var _city_panel: PanelContainer
var _comparison_panel: PanelContainer
var _modal_shield: Control
var save_picker: FileDialog
var review_tools: bool = "--map-review" in OS.get_cmdline_user_args()
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
var bottom: VBoxContainer
var buttons: Dictionary = {}
var refresh_clock: float = 0.0
var route_open: bool = false
var terrain_note: Label
var resources: Label
var command_status: Label
var last_action: String = ""
var opened_once: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Atlas.make_theme()
	var bg := ColorRect.new()
	bg.color = Atlas.PAPER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_design_stage = Control.new()
	_design_stage.name = "AtlasStage"
	_design_stage.size = DESIGN_SIZE
	_design_stage.clip_contents = true
	_design_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design_stage)
	map = Map.new()
	map.campaign = campaign
	map.position = Vector2(0, 80)
	map.size = Vector2(1920, 1000)
	_design_stage.add_child(map)
	map.settlement_selected.connect(select_city)
	var top := _atlas_panel(Rect2(0, 0, 1920, 80), false)
	header = label(top, "", 26)
	header.position = Vector2(28, 14)
	header.size = Vector2(800, 52)
	header.clip_text = true
	resources = label(top, "", 23)
	resources.position = Vector2(834, 14)
	resources.size = Vector2(370, 52)
	resources.clip_text = true
	threat = button(top, "침공 예고", func(): suspend(); campaign.open_invasions(), "invasions")
	_position_button(threat, Rect2(1232, 16, 200, 48), "warning-circle")
	var menu_button := button(top, "저장·메뉴", open_menu, "menu")
	_position_button(menu_button, Rect2(1452, 16, 196, 48), "floppy-disk")
	var close_button := button(top, "전체 지도", func(): map.fit_all(), "overview")
	_position_button(close_button, Rect2(1668, 16, 220, 48), "list")
	var nav_panel := _atlas_panel(Rect2(24, 106, 926, 64))
	var nav := HBoxContainer.new()
	nav.position = Vector2(6, 6)
	nav.size = Vector2(914, 52)
	nav.add_theme_constant_override("separation", 8)
	nav_panel.add_child(nav)
	for pair: Array in [["영지", "domestic", "buildings"], ["군사", "army", "sword"], ["생산", "production", "plant"], ["인사", "politics", "users-three"], ["연구", "research", "book-open"]]:
		var key: String = pair[1]
		var b := button(nav, pair[0], func(): action(key), key)
		b.icon = Atlas.icon(pair[2])
		b.custom_minimum_size = Vector2(132, 52)
		b.toggle_mode = true
	var card_button := button(nav, "성 정보", func(): _city_panel.visible = not _city_panel.visible, "city_info")
	card_button.custom_minimum_size = Vector2(170, 52)
	if review_tools:
		var view_button := button(_design_stage, "지도 검토", func(): _comparison_panel.visible = not _comparison_panel.visible, "view_options")
		_position_button(view_button, Rect2(1670, 112, 218, 52), "list")
	_build_city_panel()
	if review_tools: _build_comparison_panel()
	var zoom_in := button(_design_stage, "", func(): map._set_map_zoom(map.map_zoom * map.MAP_ZOOM_STEP, map.size / 2), "zoom_in")
	_position_button(zoom_in, Rect2(1832, 786, 56, 56), "plus")
	zoom_in.tooltip_text = "지도 확대"
	var zoom_out := button(_design_stage, "", func(): map._set_map_zoom(map.map_zoom / map.MAP_ZOOM_STEP, map.size / 2), "zoom_out")
	_position_button(zoom_out, Rect2(1832, 850, 56, 56), "minus")
	zoom_out.tooltip_text = "지도 축소"
	var end_turn := button(_design_stage, "다음 달", advance, "month")
	Atlas.apply_button(end_turn, false, "primary")
	_position_button(end_turn, Rect2(1640, 984, 248, 68), "arrow-right")
	end_turn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	end_turn.add_theme_font_size_override("font_size", 28)
	command_status = label(_design_stage, "", 20)
	command_status.position = Vector2(24,984)
	command_status.size = Vector2(1540,68)
	command_status.clip_text = true
	command_status.add_theme_color_override("font_color", Atlas.WHITE)
	command_status.add_theme_color_override("font_shadow_color", Atlas.INK)
	command_status.add_theme_constant_override("shadow_outline_size", 5)
	command_status.mouse_filter = Control.MOUSE_FILTER_PASS
	_modal_shield = Control.new()
	_modal_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal_shield)
	_modal_shield.hide()
	save_picker = FileDialog.new()
	save_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_picker.access = FileDialog.ACCESS_FILESYSTEM
	save_picker.filters = PackedStringArray(["*.json ; 캠페인 저장"])
	save_picker.title = "진행 저장 · 파일 선택"
	save_picker.current_dir = ProjectSettings.globalize_path("user://")
	add_child(save_picker)
	save_picker.file_selected.connect(func(path): campaign._on_save_button_pressed(path))
	campaign.navigation_menu.get_popup().add_item("진행 저장 · 파일 선택", 15)
	campaign.navigation_menu.get_popup().id_pressed.connect(func(id):
		if id == 15:
			save_picker.current_file = "campaign_%d_%02d.json" % [campaign.year, campaign.month]
			save_picker.popup_centered(Vector2i(1000,650)))
	resized.connect(_fit_atlas_stage)
	_fit_atlas_stage()
	hide()

func _fit_atlas_stage() -> void:
	if not is_instance_valid(_design_stage): return
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_design_stage.scale = Vector2.ONE * factor
	_design_stage.position = (size - DESIGN_SIZE * factor) * 0.5

func _atlas_panel(rectangle: Rect2, floating: bool = true) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", Atlas.panel(Atlas.SURFACE, Atlas.LINE, 1, 6 if floating else 0))
	_design_stage.add_child(panel)
	panel.position = rectangle.position
	panel.size = rectangle.size
	return panel

func _position_button(value: Button, rectangle: Rect2, icon_name: String = "") -> void:
	value.position = rectangle.position
	value.size = rectangle.size
	if not icon_name.is_empty(): value.icon = Atlas.icon(icon_name)

func _build_city_panel() -> void:
	_city_panel = PanelContainer.new()
	_city_panel.name = "AtlasCityPanel"
	_city_panel.position = Vector2(24, 194)
	_city_panel.size = Vector2(440, 736)
	var style := Atlas.panel()
	style.set_content_margin_all(20)
	_city_panel.add_theme_stylebox_override("panel", style)
	_design_stage.add_child(_city_panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	_city_panel.add_child(card)
	var title_row := HBoxContainer.new()
	card.add_child(title_row)
	city_title = label(title_row, "", 34)
	city_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dismiss := button(title_row, "", func(): _city_panel.hide(), "hide_city")
	dismiss.icon = Atlas.icon("x")
	dismiss.custom_minimum_size = Vector2(48, 48)
	dismiss.tooltip_text = "성 정보 닫기"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(scroll)
	bottom = VBoxContainer.new()
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override("separation", 12)
	scroll.add_child(bottom)
	var fortress := TextureRect.new()
	fortress.texture = load("res://ui/korea_layout_v1/assets/korean_fortress_original.png") as Texture2D
	fortress.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fortress.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fortress.custom_minimum_size = Vector2(0, 132)
	fortress.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fortress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(fortress)
	city_info = label(bottom, "", 21)
	city_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city_info.add_theme_color_override("font_color", Atlas.MUTED)
	statistics = label(bottom, "", 22)
	statistics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(bottom, "지원 준비", 26)
	sources = OptionButton.new()
	sources.custom_minimum_size.y = 48
	sources.clip_text = true
	Atlas.apply_button(sources)
	bottom.add_child(sources)
	sources.item_selected.connect(func(_n): route_open = true; refresh_route())
	route_text = label(bottom, "", 21)
	route_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview = button(bottom, "경로 확인", func(): route_open = true; refresh_route(), "preview")
	preview.custom_minimum_size.y = 48
	var support_row := HBoxContainer.new()
	support_row.add_theme_constant_override("separation", 10)
	card.add_child(support_row)
	support = button(support_row, "지원군 선택", open_support, "support")
	Atlas.apply_button(support, false, "primary")
	support.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	support.custom_minimum_size.y = 54
	var cancel := button(support_row, "취소", func(): route_open = false; refresh_route(), "cancel")
	cancel.custom_minimum_size = Vector2(90, 54)

func _build_comparison_panel() -> void:
	_comparison_panel = PanelContainer.new()
	_comparison_panel.name = "AtlasMapOptions"
	_comparison_panel.position = Vector2(1450, 184)
	_comparison_panel.size = Vector2(438, 0)
	_design_stage.add_child(_comparison_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_comparison_panel.add_child(column)
	label(column, "지도 보기", 24)
	button(column, "선택 성으로 이동", func(): map.focus_on_province(selected, 5.0), "focus")
	# Keep existing comparison tools available, but outside the normal play HUD.
	button(column, "중부·동해", func(): map.focus_detail(), "detail_focus")
	button(column, "후보 보기", func():
		map.set_detail_comparison(not map.detail_comparison)
		buttons.detail_r3.text = "r3 보충"
		buttons.detail_corrected.text = "보정 보기"
		buttons.detail_compare.text = "원본 보기" if map.detail_comparison else "후보 보기"
		terrain_note.text = "중부·동해 후보 비교 · 정합 미완료 · 자동 전환 차단" if map.detail_comparison else "승인 지도 · 영토 경계 자료 미확정", "detail_compare")
	button(column, "보정 보기", func():
		map.set_corrected_comparison(not map.corrected_comparison)
		buttons.detail_r3.text = "r3 보충"
		buttons.detail_compare.text = "후보 보기"
		buttons.detail_corrected.text = "원본 보기" if map.corrected_comparison else "보정 보기"
		terrain_note.text = "중부·동해 r2 보정 비교 · 일부 흐림 · 자동 전환 차단" if map.corrected_comparison else "승인 지도 · 영토 경계 자료 미확정", "detail_corrected")
	button(column, "r3 보충", func():
		map.set_r3_comparison(not map.r3_comparison)
		buttons.detail_r3.text = "r2 복귀" if map.r3_comparison else "r3 보충"
		buttons.detail_compare.text = "후보 보기"
		buttons.detail_corrected.text = "원본 보기"
		terrain_note.text = "중부·동해 r3 + r2 · 물길 정합 검토 중 · 자동 전환 차단" if map.r3_comparison else "중부·동해 r2 · 일부 흐림 · 자동 전환 차단", "detail_r3")
	terrain_note = label(column, "승인 지도 · 영토 경계 자료 미확정", 19)
	terrain_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comparison_panel.hide()

func button(parent: Node, text: String, callback: Callable, key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 48
	Atlas.apply_button(b)
	b.add_theme_font_size_override("font_size", 22)
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

func open() -> void:
	active = true
	suspended = false
	show()
	accept_selection(campaign.selected_province_id)
	# Focus only on first entry; commands and menus keep the same camera.
	if not opened_once:
		if selected == "dalgubeol": map.focus_region()
		else: map.focus_on_province(selected, 4.2)
	opened_once = true
	campaign.map_area.hide_city_card()
	campaign.province_panel.hide()
	campaign._sync_modal_map_input()

func open_menu() -> void:
	if busy(): return
	suspend()
	campaign.navigation_menu.show_popup()

func export_view() -> Dictionary:
	var camera: Dictionary = map.get_view_state()
	if campaign.event_presentation != null and campaign.event_presentation.active:
		camera = campaign.event_presentation.adapter.saved_view.duplicate(true)
	return {"camera":camera, "card_visible":_city_panel.visible}

func restore_view(state: Dictionary, city: String) -> void:
	active = true
	show()
	accept_selection(city)
	map.focus_on_province(city, 4.2)
	if state.get("camera") is Dictionary:
		map.restore_view_state(state.camera)
		map.selected = city
	_city_panel.visible = bool(state.get("card_visible", true))
	opened_once = true
	campaign._sync_modal_map_input()

func suspend() -> void:
	suspended = true
	# A tooltip from the button opening a command must not cover that command.
	_design_stage.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	support.tooltip_text = ""
	_modal_shield.show()
	campaign._sync_modal_map_input()

func busy() -> bool:
	if save_picker != null and save_picker.visible: return true
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
		suspended = true
		_design_stage.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		_modal_shield.show()
		map.input_locked = true
		return
	map.input_locked = false
	_modal_shield.hide()
	_design_stage.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if suspended:
		suspended = false
		show()
		campaign.map_area.hide_city_card()
		campaign.province_panel.hide()
		refresh()
		campaign._sync_modal_map_input()
	refresh_clock += delta
	if refresh_clock >= 0.2:
		refresh_clock = 0
		refresh()

func select_city(id: String) -> void:
	if busy(): return
	campaign.select_province(id, false)
	accept_selection(id)

func accept_selection(id: String, focus: bool = false) -> void:
	if not campaign.provinces.has(id): return
	selected = id
	_city_panel.show()
	route_open = false
	if focus: map.focus_on_province(id, 4.2)
	refresh()

func refresh() -> void:
	if not campaign.provinces.has(selected): return
	var p: Dictionary = campaign.provinces[selected]
	header.text = "삼한 660  |  %s    %d년 %d월" % [campaign.player_faction, campaign.year, campaign.month]
	resources.text = "금 %s · 군량 %s" % [String.num_int64(campaign.gold), String.num_int64(campaign.food)]
	command_status.text = campaign.log_label.text
	command_status.tooltip_text = command_status.text
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
	for key: String in ["domestic", "army", "production", "research"]:
		buttons[key].disabled = not owned or campaign.Ending.finished(campaign.strategy_state)
	for key: String in ["domestic", "army", "production", "politics", "research"]:
		var is_selected := key == last_action
		buttons[key].set_pressed_no_signal(is_selected)
		if bool(buttons[key].get_meta("atlas_selected", false)) != is_selected:
			Atlas.apply_button(buttons[key], is_selected)
			buttons[key].set_meta("atlas_selected", is_selected)
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
	var has_warning := not warnings.is_empty()
	if bool(threat.get_meta("atlas_warning", false)) != has_warning:
		Atlas.apply_button(threat, has_warning)
		threat.set_meta("atlas_warning", has_warning)
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
		"research": campaign.open_industry(selected, "research")
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
