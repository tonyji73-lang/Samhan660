extends Control

const Data = preload("res://production_data.gd")
var selected_recipe_id: String = "iron_sword"
var recipe_selector: OptionButton

var campaign: Node
var province_id: String = ""
var summary: Label
var details: Label
var result_label: Label
var research_button: Button
var building_button: Button
var start_button: Button
var stop_button: Button
var all_items_toggle: CheckButton
var catalog_label: Label
var scroll_container: ScrollContainer
var extra_research_buttons: VBoxContainer
var extra_building_buttons: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.02, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT, 0.12, true)
	panel.set_anchor(SIDE_TOP, 0.08, true)
	panel.set_anchor(SIDE_RIGHT, 0.88, true)
	panel.set_anchor(SIDE_BOTTOM, 0.92, true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241f17")
	style.border_color = Color("c8a75c")
	style.set_border_width_all(1)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	summary = Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(summary)
	var close_button := Button.new()
	close_button.text = "닫기 (Esc)"
	close_button.pressed.connect(hide)
	header.add_child(close_button)
	recipe_selector = OptionButton.new()
	for id: String in Data.RECIPE_ORDER:
		recipe_selector.add_item("철 공급" if id == "iron_supply" else "칼 제작")
		recipe_selector.set_item_metadata(recipe_selector.item_count - 1, id)
	recipe_selector.select(Data.RECIPE_ORDER.find(selected_recipe_id))
	recipe_selector.item_selected.connect(_on_recipe_selected)
	layout.add_child(recipe_selector)
	all_items_toggle = CheckButton.new()
	all_items_toggle.text = "전체 품목 보기"
	all_items_toggle.toggled.connect(_on_all_items_toggled)
	layout.add_child(all_items_toggle)
	var scroll := ScrollContainer.new()
	scroll_container = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(details)
	research_button = _button(body, "", _research)
	extra_research_buttons = VBoxContainer.new()
	body.add_child(extra_research_buttons)
	building_button = _button(body, "", _build)
	extra_building_buttons = VBoxContainer.new()
	body.add_child(extra_building_buttons)
	start_button = _button(body, "매월 생산 시작", _start)
	stop_button = _button(body, "생산 중지", _stop)
	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(result_label)
	catalog_label = Label.new()
	catalog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_label.hide()
	body.add_child(catalog_label)
	hide()


func _button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 38
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func open_for_province(campaign_node: Node, city_id: String) -> void:
	campaign = campaign_node
	province_id = city_id
	result_label.text = ""
	all_items_toggle.set_pressed_no_signal(false)
	_set_catalog_visible(false)
	refresh()
	show()
	start_button.grab_focus()


func refresh() -> void:
	var model: Dictionary = campaign.call("get_production_view_model", province_id, selected_recipe_id)
	if model.is_empty():
		hide()
		return
	summary.text = "%s 생산 · %d년 %d월 · 국가 금 %d" % [model["name"], model["year"], model["month"], model["gold"]]
	var recipe: Dictionary = Data.RECIPES[selected_recipe_id]
	var lines: Array[String] = ["공정별 예약: " + str(model["reservations"]), "\n도시 재고"]
	for item_id: String in Data.ITEMS:
		var item: Dictionary = Data.ITEMS[item_id]
		if not bool(item["enabled"]):
			continue
		if int(model["inventory"].get(item_id, 0)) <= 0 and not recipe["inputs"].has(item_id) and not recipe["outputs"].has(item_id):
			continue
		lines.append("%s (%s): %d" % [item["name"], Data.ITEM_CATEGORIES[item["category"]], int(model["inventory"].get(item_id, 0))])
	lines.append("\n생산법: %s" % recipe["name"])
	lines.append("월 예상 투입: %s · 운영비 금 %d" % [_items_text(recipe["inputs"]), recipe["operating_gold"]])
	lines.append("월 예상 산출: %s" % _items_text(recipe["outputs"]))
	lines.append("\n필요 기술: %s" % model["research_status"])
	lines.append("필요 시설: %s" % model["building_status"])
	lines.append("\n생산 설정: %s · 최근 처리: %s" % ["가동" if model["enabled"] else "중지", model["status"]])
	if str(model["last_reason"]) != "":
		lines.append("최근 보류 이유: %s" % model["last_reason"])
	lines.append("현재 조건: %s" % ("충족 — 다음 월 정산 시 생산" if model["reason"] == "" else model["reason"]))
	lines.append("\n생산은 턴 종료 후 월 1회 처리합니다. 연구·건설은 기존 계절 전환 때 진행되며, 완공·연구 완료 후 다음 월부터 생산에 적용됩니다.")
	lines.append("%s\n재료 부족 시 칼 제작을 보류합니다." % model["supply_notice"])
	if selected_recipe_id == "iron_supply":
		lines.append("원료 채취·조달, 선광·배소, 목탄 조달, 제련·정련을 추상화합니다. 별도 철광석·숯 재고는 없습니다.")
		lines.append(str(model["evidence"]))
		if str(model["regional_reason"]) != "":
			lines.append(str(model["regional_reason"]))
	lines.append("곡물·군량은 기존 도시 군량 장부를 조회합니다. 무기 (칼)는 기존 칼 재고 하나를 사용합니다.")
	lines.append("생산량·운영비·도검 연구비는 검증용 임시 설정입니다.")
	details.text = "\n".join(lines)
	_render_requirements(research_button, extra_research_buttons, model["research_options"], "research")
	_render_requirements(building_button, extra_building_buttons, model["building_options"], "build")
	start_button.disabled = not bool(model["can_start"]) or bool(model["enabled"])
	stop_button.disabled = not bool(model["owned"]) or not bool(model["enabled"])
	catalog_label.text = _catalog_text(model["inventory"])
	_set_catalog_visible(all_items_toggle.button_pressed)


func _render_requirements(primary: Button, extra: VBoxContainer, options: Array, action: String) -> void:
	for child: Node in extra.get_children():
		extra.remove_child(child)
		child.queue_free()
	primary.text = "필요 조건 없음"
	primary.disabled = true
	primary.set_meta("requirement_id", "")
	for index: int in range(options.size()):
		var option: Dictionary = options[index]
		var button: Button = primary if index == 0 else _button(extra, "", _command.bind(action, str(option["id"])))
		button.text = str(option["label"])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = not bool(option["can_execute"])
		button.set_meta("requirement_id", option["id"])


func _on_recipe_selected(index: int) -> void:
	# Selection only: never call set_enabled or cancel another recipe's order.
	selected_recipe_id = str(recipe_selector.get_item_metadata(index))
	result_label.text = ""
	refresh()


func _catalog_text(inventory: Dictionary) -> String:
	var lines: Array[String] = ["기본 품목 14종 · 역할은 설계 설명이며 새로운 경제·군사 효과가 아닙니다."]
	for tier: String in ["core", "expansion"]:
		if tier == "expansion":
			lines.append("\n확장 후보 4종 · 비활성 / 생산 불가")
		for item_id: String in Data.ITEMS:
			var item: Dictionary = Data.ITEMS[item_id]
			if str(item["tier"]) != tier:
				continue
			var status: String = "정의만 등록 · 생산법 미구현"
			if not bool(item["enabled"]):
				status = "비활성 · 생산 불가"
			elif str(item["storage"]) == "province_food_stock":
				status = "기존 군량 장부 · 기존 수확만 적용"
			else:
				for recipe_id: String in item["recipe_ids"]:
					if Data.recipe_is_enabled(recipe_id):
						status = "생산법: " + str(Data.RECIPES[recipe_id]["name"])
			lines.append("\n%s (%s / %s) · %s" % [item["name"], Data.ITEM_CATEGORIES[item["category"]], Data.PRODUCTION_METHODS[item["production_method"]], status])
			if bool(item["enabled"]):
				lines.append("현재 재고: %d" % int(inventory.get(item_id, 0)))
			lines.append("경제 역할: %s\n군사 역할: %s" % [item["economic_use"], item["military_use"]])
			lines.append("출처: %s · 지역 배치 미확정" % ", ".join(item["source_ids"]))
	return "\n".join(lines)


func _on_all_items_toggled(show_all: bool) -> void:
	_set_catalog_visible(show_all)


func _set_catalog_visible(show_all: bool) -> void:
	catalog_label.visible = show_all
	for control: Control in [details, research_button, extra_research_buttons, building_button, extra_building_buttons, start_button, stop_button, result_label]:
		control.visible = not show_all
	scroll_container.scroll_vertical = 0


func _items_text(items: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id: String in items:
		parts.append("%s %d" % [Data.ITEMS[item_id]["name"], items[item_id]])
	return "없음" if parts.is_empty() else ", ".join(parts)


func _command(action: String, requirement_id: String = "") -> void:
	var result: Dictionary = campaign.call("request_production_command", province_id, selected_recipe_id, action, requirement_id)
	result_label.text = str(result.get("message", result.get("reason", "")))
	refresh()


func _research() -> void:
	_command("research", str(research_button.get_meta("requirement_id", "")))


func _build() -> void:
	_command("build", str(building_button.get_meta("requirement_id", "")))


func _start() -> void:
	_command("start")


func _stop() -> void:
	_command("stop")
