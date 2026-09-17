extends Control
var campaign: Node
var orders: OptionButton
var details: Label
var sources: OptionButton
var city_button: Button
var army_button: Button
var support_button: Button
var result_button: Button
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
	var panel:=PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.1,true); panel.set_anchor(SIDE_RIGHT,0.9,true); panel.set_anchor(SIDE_TOP,0.08,true); panel.set_anchor(SIDE_BOTTOM,0.92,true)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("231f18"); style.set_content_margin_all(24); panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new(); panel.add_child(box)
	var title:=Label.new(); title.text="침공 예고 · 방어 대응"; box.add_child(title)
	orders=OptionButton.new(); box.add_child(orders); orders.item_selected.connect(func(_n): refresh())
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	details=Label.new(); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(details)
	sources=OptionButton.new(); box.add_child(sources)
	city_button=button(box,"위협 도시 보기",func(): hide(); campaign.select_province(row().target))
	army_button=button(box,"방어 부대 · 장비 · 지휘관",func(): hide(); campaign.open_army(row().target))
	support_button=button(box,"선택한 인접 도시에서 지원 명령",func():
		var source: String=str(sources.get_item_metadata(sources.selected)); hide(); campaign.select_province(source); campaign._on_transfer_button_pressed()
		var destinations: OptionButton=campaign.transfer_panel.destination_option
		for n: int in range(destinations.item_count):
			if destinations.get_item_metadata(n)==row().target: destinations.select(n); break)
	result_button=button(box,"이 침공의 전투 결과·공훈 포상",func(): hide(); campaign.open_battle_merit(row().battle_id))
	close_button=button(box,"닫기 (Esc)",hide)
	add_theme_font_size_override("font_size",20); hide()

func button(box: Node, text: String, action: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.pressed.connect(action); box.add_child(b); return b

func row() -> Dictionary:
	if orders.selected<0: return {}
	return campaign.strategy_state.invasions.orders.get(str(orders.get_item_metadata(orders.selected)),{})

func open(c: Node) -> void:
	campaign=c; orders.clear()
	var all: Array=c.strategy_state.get("invasions",{}).get("orders",{}).values(); all.reverse()
	for entry: Dictionary in all:
		if entry.defender!=c.player_faction_id: continue
		orders.add_item("%s · %s · %s" % [c.provinces[entry.target].name,c.Power.date(entry.due_month),{"pending":"예고","completed":"전투 완료","cancelled":"취소"}.get(entry.status,entry.status)])
		orders.set_item_metadata(orders.item_count-1,entry.id)
	show(); refresh()

func refresh() -> void:
	var entry: Dictionary=row(); sources.clear()
	for b: Button in [city_button,army_button,support_button,result_button]: b.disabled=true
	if entry.is_empty(): details.text="기록된 적 침공이 없습니다. 과거 공격은 다시 실행되지 않습니다."; return
	details.text="%s → %s\n예정: %s · 예고 당시 적 병력 %d명\n지휘관: %s\n지원군 도착 후 현재 장비·훈련·지휘관으로 전투합니다. 예고 병력은 현재 전력 보장이 아닙니다.\n\n대응: 인접 아군 도시의 병력·인물 지원(1개월), 현지 지휘관 임명, 보유 장비 지급.\n지원 출발 도시를 선택하세요. 기존 지원 화면의 목적지는 위협 도시로 맞춰집니다.\n" % [campaign.provinces[entry.source].name,campaign.provinces[entry.target].name,campaign.Power.date(entry.due_month),entry.announced_troops,campaign.get_officer(entry.commander).get("name","무명 장수")]
	city_button.disabled=false
	var owned: bool=campaign.provinces[entry.target].faction==campaign.player_faction
	army_button.disabled=not owned
	if owned:
		for city: String in campaign.province_connections.get(entry.target,[]):
			if campaign.provinces[city].faction!=campaign.player_faction: continue
			sources.add_item(campaign.provinces[city].name); sources.set_item_metadata(sources.item_count-1,city)
	support_button.disabled=sources.item_count==0
	result_button.disabled=str(entry.battle_id).is_empty()
	if entry.status=="cancelled": details.text+="\n취소 사유: "+str(entry.reason)
	elif entry.status=="completed":
		var battle: Dictionary=campaign.Merit.battle(campaign.strategy_state,entry.battle_id)
		details.text+="\n아군 방어 %s · 아군 손실 %d / 적 손실 %d" % ["패배" if battle.won else "승리",battle.defender_losses,battle.attacker_losses]
	else: details.text+="\n다음 달 침공 대기 중 · 대응으로 전력비가 바뀌어도 선언한 공격은 유지됩니다."

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): hide(); get_viewport().set_input_as_handled()
