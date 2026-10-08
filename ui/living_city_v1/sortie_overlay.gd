extends Control
const Style=preload("res://ui/living_city_v1/battle_style.gd")
const UI=Style.UI
var campaign: Node
var source: String
var target: String
var selected_unit: String=""
var targets: OptionButton
var units: VBoxContainer
var details: VBoxContainer
var reason: Label
var execute_button: Button
var close_button: Button
var unit_buttons: Dictionary={}
var quote: Dictionary={}
var accepted:=false
func _ready() -> void:
	var box:=Style.frame(self,"출정 · 병력과 현지 군량 확인")
	var columns:=HBoxContainer.new(); columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; columns.add_theme_constant_override("separation",18); box.add_child(columns)
	var left:=UI.section(columns,"목표와 출정 부대"); left.get_parent().size_flags_stretch_ratio=1
	targets=OptionButton.new(); left.add_child(targets); UI.City.button(targets); targets.item_selected.connect(func(n): target=str(targets.get_item_metadata(n)); refresh())
	UI.label(left,"출정 가능 부대 전체가 참가합니다.\n카드 선택은 상세 조회이며 편성 변경이 아닙니다.",21); units=UI.scroll(left)
	var right:=UI.section(columns,"지휘관 · 실행 조건"); right.get_parent().size_flags_stretch_ratio=1.25; details=UI.scroll(right)
	reason=UI.label(right,"",22); reason.add_theme_color_override("font_color",UI.City.RED)
	execute_button=Style.button(right,"군량 확인 · 출정 확정",confirm,true)
	close_button=Style.button(box,"취소 · 지도 복귀 (Esc)",cancel); hide()
func open(c: Node,from: String,to: String) -> void:
	c.map_area.hide_city_card(); c.province_panel.hide()
	campaign=c; source=from; target=to; accepted=false; selected_unit=""; targets.clear()
	for id: String in c.province_connections.get(source,[]):
		if c.provinces[id].faction==c.player_faction: continue
		targets.add_item(c.provinces[id].name); targets.set_item_metadata(targets.item_count-1,id)
		if id==target: targets.select(targets.item_count-1)
	show(); refresh(); close_button.grab_focus()
func refresh() -> void:
	quote=campaign.get_sortie_quote(source,target); Style.clear(units); Style.clear(details); unit_buttons.clear()
	var ids: Array=campaign.Army.at_city(campaign.strategy_state,source,campaign.player_faction_id)
	if not ids.has(selected_unit): selected_unit=str(ids[0]) if not ids.is_empty() else ""
	for id: String in ids:
		var u: Dictionary=campaign.Army.units(campaign.strategy_state)[id]
		var available: bool=quote.units.has(id)
		var b:=Style.button(units,("선택 · " if id==selected_unit else "")+"부대 %d · %s · %d명\n%s" % [ids.find(id)+1,{"infantry":"보병","archer":"궁병","cavalry":"기병"}.get(u.kind,u.kind),u.troops,"출정 참가" if available else "출정 제외 · 훈련·예약·군권 상태 확인"],func(): selected_unit=id; refresh(); unit_buttons[id].grab_focus())
		UI.City.button(b,id==selected_unit); unit_buttons[id]=b
	Style.side(details,campaign,campaign.player_faction,str(quote.commander.get("officer_id","")),"아군 전투 지휘관")
	UI.label(details,"%s → %s\n출정 병력 %d명\n필요 현지 군량 %d · 국고 금 0\n출발지 군량 %d → %d" % [campaign.provinces[source].name,campaign.provinces[target].name,quote.troops,campaign.ATTACK_FOOD_COST,quote.food,maxi(0,quote.food-campaign.ATTACK_FOOD_COST)],28)
	UI.label(details,"상대국 %s · 공개 주둔 병력 %d명\n적 부대별 장비·훈련 및 승률은 표시하지 않습니다." % [campaign.provinces[target].faction,campaign.provinces[target].troops],22)
	if not selected_unit.is_empty():
		var u: Dictionary=campaign.Army.units(campaign.strategy_state)[selected_unit]
		Style.side(details,campaign,campaign.player_faction,str(u.commander_id),"조회 부대 %d" % (ids.find(selected_unit)+1))
		UI.label(details,"병력 %d명 · 실제 장비 %d명분\n장비 충족 %.1f%% · 숙련 %.1f\n%s\n%s" % [u.troops,u.equipment,campaign.Army.ratio(u)*100,campaign.Army.training(u),"훈련 진행 중" if not campaign.Army.training_job(campaign.strategy_state,selected_unit).is_empty() else "진행 중 훈련 없음",campaign.Power.unit_reason(campaign.strategy_state,selected_unit)],22)
	reason.text=quote.reason; execute_button.disabled=not quote.ok; UI.wire_focus.call_deferred(self)
func confirm() -> void:
	if not visible or accepted: return
	refresh()
	if not quote.ok: return
	accepted=true; hide(); campaign.resolve_attack(source,target)
func cancel() -> void:
	hide(); campaign.attack_source_id=""; campaign.select_province(source)
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): cancel(); get_viewport().set_input_as_handled()
