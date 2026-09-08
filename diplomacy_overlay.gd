extends Control

signal closed

var campaign: Node
var selected_target_id: String = ""
var selected_envoy_name: String = ""
var pending_cancel: Dictionary = {}
var header: Label
var targets: ItemList
var envoys: OptionButton
var details: Label
var result_label: Label
var action_buttons: Dictionary = {}
var action_labels: Dictionary = {}
var confirmation: ConfirmationDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.02, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.07
	panel.anchor_right = 0.93
	panel.anchor_top = 0.06
	panel.anchor_bottom = 0.94
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241f17")
	style.border_color = Color("c8a75c")
	style.set_border_width_all(1)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	header = _label(top, 28)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "닫기 (Esc)"
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(func(): closed.emit())
	top.add_child(close)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	column.add_child(content)
	targets = ItemList.new()
	targets.custom_minimum_size.x = 320
	targets.add_theme_font_size_override("font_size", 24)
	targets.fixed_column_width = 300
	targets.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	targets.item_selected.connect(_select_target)
	content.add_child(targets)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	_label(body, 22).text = "사절 선택"
	envoys = OptionButton.new()
	envoys.fit_to_longest_item = false
	envoys.clip_text = true
	envoys.add_theme_font_size_override("font_size", 23)
	envoys.item_selected.connect(_select_envoy)
	body.add_child(envoys)
	details = _label(body, 24)
	for id: String in ["gift", "trade_pact", "cancel_trade_pact"]:
		var button := Button.new()
		button.text = {"gift": "친선 사절", "trade_pact": "통상협의", "cancel_trade_pact": "통상협정 해지"}[id]
		button.custom_minimum_size.y = 46
		button.add_theme_font_size_override("font_size", 23)
		button.pressed.connect(_act.bind(id))
		body.add_child(button)
		action_buttons[id] = button
		action_labels[id] = _label(body, 21)
	result_label = _label(body, 23)
	result_label.add_theme_color_override("font_color", Color("efca78"))
	confirmation = ConfirmationDialog.new()
	confirmation.title = "통상협정 해지 확인"
	confirmation.ok_button_text = "협정 해지"
	confirmation.cancel_button_text = "취소"
	confirmation.confirmed.connect(_confirm_cancel)
	confirmation.canceled.connect(func(): pending_cancel.clear())
	add_child(confirmation)
	hide()


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func open_for_campaign(host: Node) -> void:
	campaign = host
	result_label.text = ""
	refresh()
	show()


func refresh() -> void:
	header.text = "외교 · %s · %d년 %d월 · 금 %d" % [campaign.player_faction, campaign.year, campaign.month, campaign.gold]
	targets.clear()
	var target_index: int = -1
	for faction: Dictionary in campaign.get_diplomacy_factions():
		if faction.id == campaign.player_faction_id:
			continue
		var index: int = targets.add_item(str(faction.name))
		targets.set_item_metadata(index, str(faction.id))
		targets.set_item_tooltip(index, str(faction.name))
		if faction.id == selected_target_id:
			target_index = index
	if target_index < 0 and targets.item_count > 0:
		target_index = 0
	selected_target_id = str(targets.get_item_metadata(target_index)) if target_index >= 0 else ""
	if target_index >= 0:
		targets.select(target_index)
	envoys.clear()
	var envoy_index: int = -1
	for envoy: Dictionary in campaign.get_diplomacy_envoys():
		var index: int = envoys.item_count
		envoys.add_item("%s · 정치 %d / 지력 %d / 권위 %d" % [envoy.name, envoy.get("politics", 50), envoy.get("intelligence", 50), envoy.get("authority", 50)])
		envoys.set_item_metadata(index, str(envoy.name))
		if envoy.name == selected_envoy_name:
			envoy_index = index
	if envoy_index < 0 and envoys.item_count > 0:
		envoy_index = 0
	selected_envoy_name = str(envoys.get_item_metadata(envoy_index)) if envoy_index >= 0 else ""
	if envoy_index >= 0:
		envoys.select(envoy_index)
	envoys.disabled = envoy_index < 0
	_update_details()


func _select_target(index: int) -> void:
	selected_target_id = str(targets.get_item_metadata(index))
	_update_details()


func _select_envoy(index: int) -> void:
	selected_envoy_name = str(envoys.get_item_metadata(index))
	_update_details()


func _update_details() -> void:
	var target: String = str(campaign.ScenarioData.get_faction(campaign.scenario_id, selected_target_id).get("name", ""))
	var relation: Dictionary = campaign.strategy.get_relation(campaign.strategy_state, campaign.player_faction, target)
	var treaties: Array = relation.get("treaties", []).duplicate()
	var pact: bool = treaties.has("통상 조약")
	var display_treaties: Array[String] = []
	for treaty: String in treaties:
		display_treaties.append("통상협정 체결" if treaty == "통상 조약" else treaty)
	details.text = "%s · 관계도 %d · %s\n현재 조약: %s\n선택 사절: %s" % [target if not target.is_empty() else "대상 세력 없음", int(relation.value), relation.status,
		" · ".join(display_treaties) if not display_treaties.is_empty() else "없음", selected_envoy_name if not selected_envoy_name.is_empty() else "보유 사절 없음"]
	if pact:
		details.text += "\n통상협정 체결 완료 · 교역로 개설은 다음 단계에서 지원됩니다."
	for id: String in action_buttons:
		var quote: Dictionary = campaign.get_diplomatic_action_quote(selected_target_id, id, selected_envoy_name)
		action_buttons[id].disabled = not quote.ok
		action_buttons[id].tooltip_text = str(quote.reason)
		action_labels[id].text = "금 %d · 성공률 %d%% · %s" % [int(quote.get("gold_cost", 0)), int(quote.get("chance", 0)), "행동 가능" if quote.ok else str(quote.reason)]


func _act(id: String) -> void:
	if id == "cancel_trade_pact":
		var quote: Dictionary = campaign.get_diplomatic_action_quote(selected_target_id, id, selected_envoy_name)
		if not quote.ok:
			result_label.text = str(quote.reason)
			refresh()
			return
		pending_cancel = {"target": selected_target_id, "envoy": selected_envoy_name}
		confirmation.dialog_text = "%s과의 통상협정을 해지하시겠습니까?\n관계도 -10 · 이번 달 외교 행동 사용\n다른 조약은 유지됩니다." % campaign.ScenarioData.get_faction_name(campaign.scenario_id, selected_target_id)
		confirmation.popup_centered(Vector2i(580, 190))
		return
	_execute(selected_target_id, id, selected_envoy_name)


func _confirm_cancel() -> void:
	var pending: Dictionary = pending_cancel.duplicate()
	pending_cancel.clear()
	if not pending.is_empty():
		_execute(str(pending.target), "cancel_trade_pact", str(pending.envoy))


func _execute(target: String, id: String, envoy: String) -> void:
	var result: Dictionary = campaign.request_diplomatic_action(target, id, envoy)
	result_label.text = str(result.get("message", result.get("reason", "")))
	refresh()
