extends Control

signal army_requested(city: String)
var army_button: Button
var campaign: Node
var city: String
var quantity: SpinBox
var details: Label
var execute_button: Button
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.78); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var center:=CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(center)
	var panel:=PanelContainer.new(); panel.custom_minimum_size=Vector2(1000,600); center.add_child(panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.10,0.09,0.07,0.98); style.border_color=Color(0.63,0.51,0.27); style.set_border_width_all(1); style.content_margin_left=24; style.content_margin_right=24; style.content_margin_top=20; style.content_margin_bottom=20; panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",18); panel.add_child(box)
	var title:=Label.new(); title.text="도시 병력 모집 · 100명 단위"; box.add_child(title)
	quantity=SpinBox.new(); quantity.min_value=100; quantity.max_value=100000; quantity.step=100; quantity.value=1000; box.add_child(quantity); quantity.value_changed.connect(func(_v): refresh())
	details=Label.new(); details.custom_minimum_size=Vector2(750,250); box.add_child(details)
	execute_button=Button.new(); execute_button.text="견적대로 모집"; box.add_child(execute_button); execute_button.pressed.connect(func(): campaign.request_recruitment(city,int(quantity.value)); refresh())
	army_button=Button.new(); army_button.text="부대 편성·장비 지급·훈련"; box.add_child(army_button); army_button.pressed.connect(func(): army_requested.emit(city))
	close_button=Button.new(); close_button.text="닫기 (Esc)"; box.add_child(close_button); close_button.pressed.connect(hide)
	for control: Control in [title,quantity,details,execute_button,close_button]: control.add_theme_font_size_override("font_size",22)
	hide()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide(); get_viewport().set_input_as_handled()

func open(c: Node, city_id: String) -> void:
	campaign=c; city=city_id; quantity.value=1000; refresh(); show()

func refresh() -> void:
	if campaign==null: return
	var q: Dictionary=campaign.get_recruitment_quote(city,int(quantity.value))
	var account: Dictionary=campaign.strategy_state.faction_economy.accounts[campaign.player_faction_id]
	details.text="%s · %s 국고 %d\n도시 군량 %d · 주둔 병력 %d\n\n모집 %d명 → 금 %d / 이 도시 군량 %d\n%s\n\n국가 원장: 시작 %d + 수입 %d − 지출 %d = %d\n%s" % [campaign.provinces[city].name,campaign.player_faction,q.available_gold,q.available_food,campaign.provinces[city].troops,q.amount,q.gold_cost,q.food_cost,"실행 가능" if q.ok else q.reason,account.opening,account.income,account.expense,account.balance,campaign.get_city_operation_text(city).split("\n")[1]]
	var manpower: String="\n민간 인구 %d → %d · 출신 복무 %d · 추가 동원 %d명\n다른 도시·이동 중 출신 병력도 동원 부담에 포함됩니다.\n다음 월 세입 %d → %d · 연간 수확 %d → %d (현재 조건)" % [q.civilians,maxi(0,int(q.civilians)-int(q.amount)),q.serving,q.available,q.tax_before,q.tax_after,q.harvest_before,q.harvest_after]
	details.text+=manpower
	details.text+="\n다음 수확 %s 국고 수취 군량 %d → %d (풍흉년 별도)" % [q.next_harvest_date,q.next_harvest_before,q.next_harvest_after]
	execute_button.disabled=not q.ok
	var receipt: Dictionary=campaign.strategy_state.get("domestic",{}).get("settlements",{}).get(city,{})
	if receipt.has("tax_month"):
		details.text+="\n직전 세입 결산: 기본 %d + 태수 %d = %d" % [receipt.base_tax,receipt.tax_bonus,receipt.tax]
