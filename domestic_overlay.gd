extends Control

# 삼한660 내정·군사 화면 V2
# 기존 campaign_main.tscn을 수정하지 않고 런타임에 전체 화면 오버레이를 구성합니다.

var campaign: Node = null
var province_id: String = ""
var view_model: Dictionary = {}

var title_label: Label = null
var summary_label: Label = null
var action_label: Label = null
var officer_select: OptionButton = null
var result_label: Label = null
var tabs: TabContainer = null
var building_list: VBoxContainer = null
var military_list: VBoxContainer = null
var research_list: VBoxContainer = null
var special_unit_list: VBoxContainer = null
var recruit_amount_spin: SpinBox = null
var recruit_amount_value: int = 1000

const GOLD: Color = Color("c8a75c")
const PALE_GOLD: Color = Color("e2cf9d")
const INK: Color = Color("181510")
const PANEL: Color = Color("241f17")
const PANEL_LIGHT: Color = Color("30291e")
const MUTED: Color = Color("aaa18e")
const SUCCESS: Color = Color("83b879")
const WARNING: Color = Color("d58b6d")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_screen()
	hide()


func open_for_province(
	campaign_node: Node, selected_province_id: String, requested_tab: String = ""
) -> void:
	campaign = campaign_node
	province_id = selected_province_id
	result_label.text = "담당 장수를 선택한 뒤 명령을 확정하세요."
	_refresh()
	if requested_tab != "":
		_select_tab(requested_tab)
	show()
	move_to_front()


func _build_screen() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.02, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "DomesticPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 28.0
	panel.offset_top = 20.0
	panel.offset_right = -28.0
	panel.offset_bottom = -20.0
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD, 2, 6))
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	root.add_child(top_row)

	title_label = Label.new()
	title_label.text = "내정도"
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", PALE_GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_label)

	var close_button: Button = Button.new()
	close_button.text = "지도 복귀"
	close_button.custom_minimum_size = Vector2(110.0, 38.0)
	_style_command_button(close_button, false)
	close_button.pressed.connect(_on_close_pressed)
	top_row.add_child(close_button)

	summary_label = Label.new()
	summary_label.add_theme_color_override("font_color", Color("d7d0c0"))
	root.add_child(summary_label)

	var command_bar: PanelContainer = PanelContainer.new()
	command_bar.add_theme_stylebox_override("panel", _panel_style(PANEL_LIGHT, Color("5f5138"), 1, 4))
	root.add_child(command_bar)

	var command_margin: MarginContainer = MarginContainer.new()
	command_margin.add_theme_constant_override("margin_left", 12)
	command_margin.add_theme_constant_override("margin_right", 12)
	command_margin.add_theme_constant_override("margin_top", 8)
	command_margin.add_theme_constant_override("margin_bottom", 8)
	command_bar.add_child(command_margin)

	var command_row: HBoxContainer = HBoxContainer.new()
	command_row.add_theme_constant_override("separation", 12)
	command_margin.add_child(command_row)

	var officer_caption: Label = Label.new()
	officer_caption.text = "담당 장수"
	officer_caption.add_theme_color_override("font_color", PALE_GOLD)
	command_row.add_child(officer_caption)

	officer_select = OptionButton.new()
	officer_select.custom_minimum_size = Vector2(260.0, 38.0)
	officer_select.item_selected.connect(_on_officer_selected)
	command_row.add_child(officer_select)

	action_label = Label.new()
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	command_row.add_child(action_label)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_color_override("font_selected_color", PALE_GOLD)
	tabs.add_theme_color_override("font_unselected_color", MUTED)
	root.add_child(tabs)

	building_list = _make_tab("건설")
	military_list = _make_tab("군사")
	research_list = _make_tab("연구")
	special_unit_list = _make_tab("특수 병종")

	result_label = Label.new()
	result_label.custom_minimum_size = Vector2(0.0, 30.0)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_color_override("font_color", MUTED)
	root.add_child(result_label)


func _make_tab(tab_name: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tabs.add_child(scroll)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	margin.add_child(list)
	return list


func _refresh() -> void:
	if campaign == null or not is_instance_valid(campaign):
		return
	var model_value: Variant = campaign.call("get_domestic_view_model", province_id)
	if typeof(model_value) != TYPE_DICTIONARY:
		return
	view_model = model_value
	if view_model.is_empty():
		return

	title_label.text = "%s 내정도" % str(view_model.get("province_name", province_id))
	summary_label.text = (
		"세력  %s    태수  %s    국가 금  %d    국가 군량  %d"
		% [
			view_model.get("faction", ""),
			view_model.get("governor", ""),
			int(view_model.get("gold", 0)),
			int(view_model.get("food", 0)),
		]
	)
	_refresh_officers()
	_refresh_action_label()
	_refresh_buildings()
	_refresh_military()
	_refresh_research()
	_refresh_special_units()


func _refresh_officers() -> void:
	var previous_name: String = _selected_officer_name()
	officer_select.clear()
	var first_available: int = -1
	var previous_index: int = -1
	var officer_rows: Array = view_model.get("officers", [])
	for officer_value: Variant in officer_rows:
		if typeof(officer_value) != TYPE_DICTIONARY:
			continue
		var officer: Dictionary = officer_value
		var officer_name: String = str(officer.get("name", ""))
		var suffix: String = ""
		if bool(officer.get("in_transit", false)):
			suffix = " · 이동 중"
		elif bool(officer.get("acted", false)):
			suffix = " · 행동 완료"
		var item_index: int = officer_select.item_count
		officer_select.add_item(
			"%s  [통 %d · 무 %d · 지 %d · 정 %d]%s"
			% [
				officer_name,
				int(officer.get("leadership", 0)),
				int(officer.get("war", 0)),
				int(officer.get("intelligence", 0)),
				int(officer.get("politics", 0)),
				suffix,
			]
		)
		officer_select.set_item_metadata(item_index, officer_name)
		var available: bool = bool(officer.get("available", false))
		officer_select.set_item_disabled(item_index, not available)
		if available and first_available < 0:
			first_available = item_index
		if available and officer_name == previous_name:
			previous_index = item_index
	if previous_index >= 0:
		officer_select.select(previous_index)
	elif first_available >= 0:
		officer_select.select(first_available)
	elif officer_select.item_count > 0:
		officer_select.select(0)
	else:
		officer_select.add_item("담당 가능한 장수 없음")
		officer_select.set_item_disabled(0, true)


func _refresh_action_label() -> void:
	if bool(view_model.get("province_action_used", false)):
		action_label.text = "이번 계절 영지 행동 완료"
		action_label.add_theme_color_override("font_color", WARNING)
	else:
		action_label.text = "이번 계절 영지 행동 가능"
		action_label.add_theme_color_override("font_color", SUCCESS)


func _refresh_buildings() -> void:
	_clear_list(building_list)
	var construction_queue: Dictionary = view_model.get("construction_queue", {})
	if not construction_queue.is_empty():
		var queue_label: Label = Label.new()
		queue_label.text = (
			"현재 건설 중: %s %d단계 · 담당 %s · 남은 %d턴"
			% [
				_find_catalog_name(view_model.get("buildings", []), str(construction_queue.get("building_id", ""))),
				int(construction_queue.get("target_level", 0)),
				str(construction_queue.get("assigned_officer", "현지 관리")),
				int(construction_queue.get("remaining_turns", 0)),
			]
		)
		queue_label.add_theme_color_override("font_color", WARNING)
		building_list.add_child(queue_label)
	_add_column_header(building_list, "건물", "현재", "비용·기간", "효과 / 상태")
	var province_used: bool = bool(view_model.get("province_action_used", false))
	for row_value: Variant in view_model.get("buildings", []):
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		var quote: Dictionary = row.get("quote", {})
		var detail: String = str(row.get("effect", "최대 %d단계" % int(row.get("max_level", 3))))
		var cost_text: String = "-"
		if bool(quote.get("ok", false)):
			cost_text = "금 %d · %d턴" % [int(quote.get("gold_cost", 0)), int(quote.get("turns", 1))]
		else:
			detail = str(quote.get("reason", detail))
		_add_command_row(
			building_list,
			str(row.get("name", "건물")),
			"%d / %d" % [int(row.get("current_level", 0)), int(row.get("max_level", 3))],
			cost_text,
			detail,
			"건설",
			Callable(self, "_on_build_pressed").bind(str(row.get("id", ""))),
			province_used or not bool(quote.get("ok", false)) or _selected_officer_name() == ""
		)


func _refresh_research() -> void:
	_clear_list(research_list)
	var research_queue: Dictionary = view_model.get("research_queue", {})
	if not research_queue.is_empty():
		var queue_label: Label = Label.new()
		queue_label.text = (
			"현재 연구 중: %s %d단계 · 담당 %s · 남은 %d턴"
			% [
				_find_catalog_name(view_model.get("research", []), str(research_queue.get("research_id", ""))),
				int(research_queue.get("target_level", 0)),
				str(research_queue.get("assigned_officer", "조정 관료")),
				int(research_queue.get("remaining_turns", 0)),
			]
		)
		queue_label.add_theme_color_override("font_color", WARNING)
		research_list.add_child(queue_label)
	_add_column_header(research_list, "연구", "현재", "비용·기간", "효과 / 상태")
	var action_used: bool = (
		bool(view_model.get("province_action_used", false))
		or bool(view_model.get("research_action_used", false))
	)
	for row_value: Variant in view_model.get("research", []):
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		var quote: Dictionary = row.get("quote", {})
		var detail: String = str(row.get("effect", "세력 전체에 적용"))
		var cost_text: String = "-"
		if bool(quote.get("ok", false)):
			cost_text = "금 %d · %d턴" % [int(quote.get("gold_cost", 0)), int(quote.get("turns", 1))]
		else:
			detail = str(quote.get("reason", detail))
		_add_command_row(
			research_list,
			str(row.get("name", "연구")),
			"%d / %d" % [int(row.get("current_level", 0)), int(row.get("max_level", 3))],
			cost_text,
			detail,
			"연구",
			Callable(self, "_on_research_pressed").bind(str(row.get("id", ""))),
			action_used or not bool(quote.get("ok", false)) or _selected_officer_name() == ""
		)


func _refresh_military() -> void:
	_clear_list(military_list)
	var roster: Dictionary = view_model.get("unit_roster", {})
	var total_troops: int = 0
	for unit_value: Variant in roster.values():
		if typeof(unit_value) == TYPE_DICTIONARY:
			total_troops += int(unit_value.get("troops", 0))

	var heading_panel: PanelContainer = PanelContainer.new()
	heading_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("352b1d"), GOLD, 1, 4)
	)
	military_list.add_child(heading_panel)
	var heading_margin: MarginContainer = MarginContainer.new()
	heading_margin.add_theme_constant_override("margin_left", 12)
	heading_margin.add_theme_constant_override("margin_right", 12)
	heading_margin.add_theme_constant_override("margin_top", 8)
	heading_margin.add_theme_constant_override("margin_bottom", 8)
	heading_panel.add_child(heading_margin)
	var heading_row: HBoxContainer = HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 14)
	heading_margin.add_child(heading_row)
	var roster_title: Label = Label.new()
	roster_title.text = "영지 병력 편성  ·  총 %d명" % total_troops
	roster_title.add_theme_font_size_override("font_size", 18)
	roster_title.add_theme_color_override("font_color", PALE_GOLD)
	roster_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(roster_title)
	var amount_label: Label = Label.new()
	amount_label.text = "모집 인원"
	heading_row.add_child(amount_label)
	recruit_amount_spin = SpinBox.new()
	recruit_amount_spin.min_value = 500
	recruit_amount_spin.max_value = 5000
	recruit_amount_spin.step = 500
	recruit_amount_spin.value = recruit_amount_value
	recruit_amount_spin.custom_minimum_size = Vector2(150.0, 34.0)
	recruit_amount_spin.suffix = "명"
	recruit_amount_spin.value_changed.connect(_on_recruit_amount_changed)
	heading_row.add_child(recruit_amount_spin)

	var roster_row: HBoxContainer = HBoxContainer.new()
	roster_row.add_theme_constant_override("separation", 8)
	military_list.add_child(roster_row)
	for unit_id: String in ["infantry", "archer", "cavalry"]:
		var entry: Dictionary = roster.get(unit_id, {})
		roster_row.add_child(_make_roster_card(unit_id, entry))
	for unit_id_value: Variant in roster.keys():
		var unit_id: String = str(unit_id_value)
		if unit_id in ["infantry", "archer", "cavalry"]:
			continue
		var entry: Dictionary = roster[unit_id]
		if int(entry.get("troops", 0)) > 0:
			roster_row.add_child(_make_roster_card(unit_id, entry))

	var commander: Dictionary = _selected_officer_row()
	var commander_name: String = str(commander.get("name", ""))
	var affinity_label: Label = Label.new()
	var affinities: Dictionary = commander.get("affinities", {})
	affinity_label.text = (
		"담당 적성  ·  보병 %s  /  궁병 %s  /  기병 %s"
		% [
			affinities.get("infantry", "-"),
			affinities.get("archer", "-"),
			affinities.get("cavalry", "-"),
		]
	)
	affinity_label.add_theme_color_override("font_color", PALE_GOLD)
	military_list.add_child(affinity_label)
	var amount: int = 1000
	if recruit_amount_spin != null:
		amount = int(recruit_amount_spin.value)
	var province_used: bool = bool(view_model.get("province_action_used", false))
	for unit_value: Variant in view_model.get("recruit_catalog", []):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_value
		var unit_id: String = str(unit.get("id", ""))
		var quote: Dictionary = {}
		if commander_name != "":
			var quote_value: Variant = campaign.call(
				"strategy_get_recruit_quote", province_id, unit_id, commander_name, amount
			)
			if typeof(quote_value) == TYPE_DICTIONARY:
				quote = quote_value
		var current: Dictionary = roster.get(unit_id, {})
		var detail: String = str(unit.get("role", unit.get("bonus", "")))
		var cost_text: String = "조건 미충족"
		var forecast: String = "-"
		if bool(quote.get("ok", false)):
			cost_text = "금 %d · 군량 %d" % [int(quote.get("gold_cost", 0)), int(quote.get("food_cost", 0))]
			forecast = "적성 %s · 훈련 %d · 사기 %d" % [
				quote.get("affinity", "B"), quote.get("training", 50), quote.get("morale", 50)
			]
		elif not quote.is_empty():
			detail = str(quote.get("reason", detail))
		elif commander_name == "":
			detail = "담당 장수를 선택하세요."
		_add_military_command_row(
			str(unit.get("name", unit_id)),
			int(current.get("troops", 0)),
			cost_text,
			forecast,
			detail,
			unit_id,
			province_used or not bool(quote.get("ok", false))
		)


func _refresh_special_units() -> void:
	_clear_list(special_unit_list)
	var best_unit: Dictionary = view_model.get("best_unit", {})
	var fielded_unit: Dictionary = view_model.get("best_fielded_unit", {})
	var best_label: Label = Label.new()
	best_label.text = (
		"실전 편성 최고 병종: %s [전투력 %d]  ·  해금 최고 병종: %s [전투력 %d]"
		% [
			fielded_unit.get("name", "보병"),
			int(fielded_unit.get("power", 50)),
			best_unit.get("name", "향토군"),
			int(best_unit.get("power", 50)),
		]
	)
	best_label.add_theme_font_size_override("font_size", 18)
	best_label.add_theme_color_override("font_color", PALE_GOLD)
	special_unit_list.add_child(best_label)
	var separator: HSeparator = HSeparator.new()
	special_unit_list.add_child(separator)

	for unit_value: Variant in view_model.get("special_units", []):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_value
		var unlocked: bool = bool(unit.get("unlocked", false))
		var row: PanelContainer = PanelContainer.new()
		row.add_theme_stylebox_override(
			"panel",
			_panel_style(Color("2e291f"), SUCCESS if unlocked else Color("625039"), 1, 4)
		)
		special_unit_list.add_child(row)
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 9)
		margin.add_theme_constant_override("margin_bottom", 9)
		row.add_child(margin)
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var requirement_text: String = "해금 완료"
		if not unlocked:
			var missing: Array = unit.get("missing", [])
			var missing_texts: PackedStringArray = []
			for missing_value: Variant in missing:
				missing_texts.append(str(missing_value))
			requirement_text = "필요: %s" % " · ".join(missing_texts)
		label.text = (
			"%s  [전투력 %d]  %s\n%s"
			% [unit.get("name", "특수 병종"), int(unit.get("power", 0)), unit.get("bonus", ""), requirement_text]
		)
		label.add_theme_color_override("font_color", SUCCESS if unlocked else Color("d0c5ae"))
		margin.add_child(label)


func _select_tab(tab_name: String) -> void:
	if tabs == null:
		return
	for tab_index: int in range(tabs.get_tab_count()):
		if tabs.get_tab_title(tab_index) == tab_name:
			tabs.current_tab = tab_index
			return


func _selected_officer_row() -> Dictionary:
	var selected_name: String = _selected_officer_name()
	for row_value: Variant in view_model.get("officers", []):
		if typeof(row_value) == TYPE_DICTIONARY:
			var row: Dictionary = row_value
			if str(row.get("name", "")) == selected_name:
				return row
	return {}


func _make_roster_card(unit_id: String, entry: Dictionary) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(210.0, 82.0)
	card.add_theme_stylebox_override(
		"panel", _panel_style(Color("2b251c"), Color("66583e"), 1, 4)
	)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var glyph: Label = Label.new()
	var category: String = str(entry.get("category", unit_id))
	glyph.text = {"infantry": "步", "archer": "弓", "cavalry": "騎", "naval": "舟"}.get(category, "兵")
	glyph.custom_minimum_size = Vector2(42.0, 0.0)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 28)
	glyph.add_theme_color_override("font_color", GOLD)
	row.add_child(glyph)
	var text_label: Label = Label.new()
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.text = (
		"%s  %d명\n훈련 %d · 사기 %d"
		% [
			entry.get("name", _unit_name(unit_id)),
			int(entry.get("troops", 0)),
			int(entry.get("training", 50)),
			int(entry.get("morale", 50)),
		]
	)
	text_label.add_theme_color_override("font_color", Color("e8ddc3"))
	row.add_child(text_label)
	return card


func _add_military_command_row(
	unit_name: String,
	current_troops: int,
	cost_text: String,
	forecast: String,
	detail_text: String,
	unit_id: String,
	disabled: bool
) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_LIGHT, Color("504530"), 1, 3))
	military_list.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	_add_fixed_label(row, unit_name, 150.0, Color("eee4ca"))
	_add_fixed_label(row, "보유 %d" % current_troops, 110.0, Color("d0c5ae"))
	_add_fixed_label(row, cost_text, 190.0, Color("d0c5ae"))
	_add_fixed_label(row, forecast, 210.0, PALE_GOLD)
	var detail: Label = Label.new()
	detail.text = detail_text
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_theme_color_override("font_color", MUTED)
	row.add_child(detail)
	var button: Button = Button.new()
	button.text = "징병"
	button.custom_minimum_size = Vector2(86.0, 34.0)
	button.disabled = disabled
	_style_command_button(button, true)
	button.pressed.connect(_on_recruit_pressed.bind(unit_id))
	row.add_child(button)


func _unit_name(unit_id: String) -> String:
	return {
		"infantry": "보병", "archer": "궁병", "cavalry": "기병"
	}.get(unit_id, unit_id)


func _add_column_header(
	parent: VBoxContainer, first: String, second: String, third: String, fourth: String
) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	_add_fixed_label(row, first, 190.0, PALE_GOLD)
	_add_fixed_label(row, second, 80.0, PALE_GOLD)
	_add_fixed_label(row, third, 160.0, PALE_GOLD)
	var detail: Label = Label.new()
	detail.text = fourth
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_color_override("font_color", PALE_GOLD)
	row.add_child(detail)
	_add_fixed_label(row, "명령", 90.0, PALE_GOLD)


func _add_command_row(
	parent: VBoxContainer,
	command_name: String,
	level_text: String,
	cost_text: String,
	detail_text: String,
	button_text: String,
	pressed_callable: Callable,
	disabled: bool
) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_LIGHT, Color("504530"), 1, 3))
	parent.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	_add_fixed_label(row, command_name, 180.0, Color("eee4ca"))
	_add_fixed_label(row, level_text, 80.0, Color("d0c5ae"))
	_add_fixed_label(row, cost_text, 160.0, Color("d0c5ae"))
	var detail: Label = Label.new()
	detail.text = detail_text
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_theme_color_override("font_color", MUTED)
	row.add_child(detail)
	var button: Button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(90.0, 34.0)
	button.disabled = disabled
	_style_command_button(button, false)
	button.pressed.connect(pressed_callable)
	row.add_child(button)


func _add_fixed_label(parent: HBoxContainer, value: String, width: float, color: Color) -> void:
	var label: Label = Label.new()
	label.text = value
	label.custom_minimum_size = Vector2(width, 0.0)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _selected_officer_name() -> String:
	if officer_select == null or officer_select.item_count <= 0:
		return ""
	var index: int = officer_select.selected
	if index < 0 or index >= officer_select.item_count or officer_select.is_item_disabled(index):
		return ""
	return str(officer_select.get_item_metadata(index))


func _find_catalog_name(rows: Array, item_id: String) -> String:
	for row_value: Variant in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		if str(row.get("id", "")) == item_id:
			return str(row.get("name", item_id))
	return item_id


func _on_build_pressed(building_id: String) -> void:
	var officer_name: String = _selected_officer_name()
	var result_value: Variant = campaign.call(
		"strategy_start_building", province_id, building_id, officer_name
	)
	_show_result(result_value, "건설 명령을 내렸습니다.")


func _on_research_pressed(research_id: String) -> void:
	var officer_name: String = _selected_officer_name()
	var result_value: Variant = campaign.call(
		"strategy_start_research", research_id, officer_name, province_id
	)
	_show_result(result_value, "연구 명령을 내렸습니다.")


func _on_recruit_pressed(unit_id: String) -> void:
	var officer_name: String = _selected_officer_name()
	var result_value: Variant = campaign.call(
		"strategy_recruit_unit", province_id, unit_id, officer_name, recruit_amount_value
	)
	if typeof(result_value) == TYPE_DICTIONARY and bool(result_value.get("ok", false)):
		var result: Dictionary = result_value
		result_label.text = (
			"%s이(가) %s %d명을 모집했습니다. · 적성 %s · 훈련 %d · 사기 %d"
			% [
				officer_name,
				result.get("name", _unit_name(unit_id)),
				int(result.get("amount", recruit_amount_value)),
				result.get("affinity", "B"),
				int(result.get("training", 50)),
				int(result.get("morale", 50)),
			]
		)
		result_label.add_theme_color_override("font_color", SUCCESS)
		_refresh()
		_select_tab("군사")
		return
	_show_result(result_value, "징병을 완료했습니다.")


func _on_recruit_amount_changed(value: float) -> void:
	recruit_amount_value = int(value)
	_refresh_military()


func _style_command_button(button: Button, highlighted: bool) -> void:
	var normal_fill: Color = Color("4a321d") if highlighted else Color("28231b")
	button.add_theme_stylebox_override("normal", _panel_style(normal_fill, GOLD, 1, 3))
	button.add_theme_stylebox_override("hover", _panel_style(Color("6a4725"), PALE_GOLD, 1, 3))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("8b5a27"), PALE_GOLD, 2, 3))
	button.add_theme_color_override("font_color", PALE_GOLD)
	button.add_theme_color_override("font_hover_color", Color("fff0c7"))


func _show_result(result_value: Variant, success_fallback: String) -> void:
	if typeof(result_value) != TYPE_DICTIONARY:
		result_label.text = "명령 결과를 확인할 수 없습니다."
		result_label.add_theme_color_override("font_color", WARNING)
		return
	var result: Dictionary = result_value
	if bool(result.get("ok", false)):
		result_label.text = (
			"%s 담당 %s · 완료까지 %d턴"
			% [success_fallback, _selected_officer_name(), int(result.get("turns", 1))]
		)
		result_label.add_theme_color_override("font_color", SUCCESS)
	else:
		result_label.text = str(result.get("reason", "명령을 실행할 수 없습니다."))
		result_label.add_theme_color_override("font_color", WARNING)
	_refresh()


func _on_officer_selected(_index: int) -> void:
	_refresh_buildings()
	_refresh_military()
	_refresh_research()


func _on_close_pressed() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _clear_list(list: VBoxContainer) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _panel_style(fill_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
