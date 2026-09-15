extends Control
const Supply = preload("res://supply_transport.gd")
var campaign: Node
var source: String=""
var destination: OptionButton
var orders: OptionButton
var amounts: Dictionary={}
var details: Label
var status: Label
var execute_button: Button
var cancel_button: Button
var reroute_button: Button
var unload_button: Button
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.8); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var panel:=PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.12,true); panel.set_anchor(SIDE_RIGHT,0.88,true); panel.set_anchor(SIDE_TOP,0.04,true); panel.set_anchor(SIDE_BOTTOM,0.96,true)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("241f17"); style.border_color=Color("c8a75c"); style.set_border_width_all(1)
	for side: String in ["left","right","top","bottom"]: style.set("content_margin_"+side,16)
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",8); panel.add_child(box)
	status=Label.new(); box.add_child(status)
	orders=OptionButton.new(); box.add_child(orders); orders.item_selected.connect(func(_n): refresh())
	destination=OptionButton.new(); box.add_child(destination); destination.item_selected.connect(func(_n): refresh())
	var row:=HBoxContainer.new(); box.add_child(row)
	for item: String in ["grain","iron","sword"]:
		var label:=Label.new(); label.text={"grain":"군량","iron":"철","sword":"칼"}[item]; row.add_child(label)
		var spin:=SpinBox.new(); spin.min_value=0; spin.max_value=2000; spin.step=1; spin.custom_minimum_size.x=125; row.add_child(spin); amounts[item]=spin; spin.value_changed.connect(func(_v): refresh())
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	details=Label.new(); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(details)
	execute_button=button(box,"화물 수송 접수 · 운송비 지불",func(): submit("start"))
	var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",12); box.add_child(actions)
	cancel_button=button(actions,"첫 이동 전 취소·환불",func(): submit("cancel"))
	reroute_button=button(actions,"선택 목적지로 재지정·비용 지불",func(): submit("reroute"))
	unload_button=button(actions,"현재 아군 도시에 하역",func(): submit("unload"))
	close_button=button(box,"닫기 (Esc)",hide)
	add_theme_font_size_override("font_size",18); hide()

func button(parent: Node, text: String, callback: Callable) -> Button:
	var b:=Button.new(); b.text=text; parent.add_child(b); b.pressed.connect(callback); return b

func open(context: Node, city: String) -> void:
	campaign=context; source=city
	destination.clear()
	var cities: Array=Supply.Economy.city_ids(campaign.strategy_state,campaign.provinces); cities.sort()
	for id: String in cities:
		if Supply.owner(campaign.strategy_state,campaign.provinces,id)==campaign.player_faction_id:
			destination.add_item(str(campaign.provinces[id].name)); destination.set_item_metadata(destination.item_count-1,id)
	for spin: SpinBox in amounts.values(): spin.set_value_no_signal(0)
	rebuild(); status.text="육상 화물 수송 · 출발지 "+city_name(source); show()

func rebuild(selected: String="") -> void:
	orders.clear(); orders.add_item("새 화물 수송 · 장수/병력 선택 불필요"); orders.set_item_metadata(0,"")
	for order: Dictionary in Supply.ensure(campaign.strategy_state).orders.values():
		if order.faction_id!=campaign.player_faction_id: continue
		orders.add_item("%s · %s → %s · %s" % [order.id,city_name(order.source),city_name(order.target),state_name(order.status)])
		orders.set_item_metadata(orders.item_count-1,order.id)
		if selected==order.id: orders.select(orders.item_count-1)
	refresh()

func city_name(id: String) -> String: return str(campaign.provinces.get(id,{}).get("name",id))
func state_name(value: String) -> String: return {"transit":"이동 중","waiting":"대기","arrived":"도착","unloaded":"하역 완료","captured":"피탈","canceled":"취소"}.get(value,value)
func date(value: int) -> String: return "%d년 %d월" % [(value-1)/12,(value-1)%12+1]
func selected_order() -> Dictionary:
	return Supply.ensure(campaign.strategy_state).orders.get(str(orders.get_item_metadata(orders.selected)),{}) if orders.selected>=0 else {}
func target() -> String: return str(destination.get_item_metadata(destination.selected)) if destination.selected>=0 else ""
func payload() -> Dictionary: return {"grain":int(amounts.grain.value),"iron":int(amounts.iron.value),"sword":int(amounts.sword.value)}
func cargo_text(cargo: Dictionary) -> String: return "군량 %d · 철 %d · 칼 %d" % [int(cargo.get("grain",0)),int(cargo.get("iron",0)),int(cargo.get("sword",0))]

func refresh() -> void:
	if campaign==null: return
	var stamp: int=campaign.year*12+campaign.month
	var order: Dictionary=selected_order()
	var current: String=source if order.is_empty() else str(order.current)
	var cargo: Dictionary=payload() if order.is_empty() else order.cargo
	var q: Dictionary=Supply.quote(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,current,target(),cargo,stamp,not order.is_empty())
	var stock: Dictionary=Supply.Production.get_inventory_view(campaign.strategy_state,campaign.provinces,current)
	details.text="%s 창고: %s\n국고 금 %d\n" % [city_name(current),cargo_text(stock),Supply.Economy.balance(campaign.strategy_state,campaign.player_faction_id)]
	if not order.is_empty():
		var remaining: Array=order.path.slice(int(order.index)); var names: Array=[]
		for id: String in remaining: names.append(city_name(id))
		var reason: String=Supply.remaining_reason(campaign.strategy_state,campaign.provinces,order) if Supply.active(order) else ""
		details.text+="%s · 현재 위치 %s\n이동 중 재고: %s\n남은 경로: %s\n기존 납부 금 %d · %s\n" % [state_name(order.status),city_name(current),cargo_text(cargo)," → ".join(names),order.cost_paid,"예상 도착 "+date(stamp+remaining.size()-1) if reason.is_empty() and Supply.active(order) else "도착 예정 보류/종료"]
		details.text+="대기 사유: "+(reason if not reason.is_empty() else str(order.reason))+"\n"
		if order.has("delivered_cargo"): details.text+="종료 화물: "+cargo_text(order.delivered_cargo)+"\n"
	if q.has("path"):
		var names: Array=[]
		for id: String in q.path: names.append(city_name(id))
		details.text+="\n%s 견적: %s · 적재량 %d / 2,000\n경로: %s\n예상 도착: %s (다음 월부터 구간당 1개월)\n기본 금 %d · 군량 수송 연구 할인 %d%% · 최종 금 %d\n출발 후 군량 %d · 현재 주둔군 월 소비 %d · 유지 %s\n" % ["새 수송" if order.is_empty() else "재지정",cargo_text(cargo),q.load," → ".join(names),date(q.eta),q.base_cost,q.discount_percent,q.cost,q.food_after,q.upkeep,("%.1f개월" % (float(q.food_after)/q.upkeep)) if q.upkeep>0 else "소비 없음"]
	details.text+="\n"+str(q.reason)+"\n이동 중 화물은 모집·생산에 사용할 수 없습니다.\n첫 이동 전 취소는 화물·납부 운송비 환불. 이동 후 재지정 비용은 추가 지불하며 이전 비용은 환불하지 않습니다."
	execute_button.disabled=not order.is_empty() or not q.ok
	var can_manage: bool=not order.is_empty() and Supply.active(order) and Supply.owner(campaign.strategy_state,campaign.provinces,current)==campaign.player_faction_id
	cancel_button.disabled=not can_manage or int(order.get("moves",0))>0 or current!=str(order.get("source",""))
	reroute_button.disabled=not can_manage or not q.ok
	unload_button.disabled=not can_manage

func submit(action: String) -> void:
	var order: Dictionary=selected_order()
	var stamp: int=campaign.year*12+campaign.month
	var result: Dictionary=Supply.start(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,source,target(),payload(),stamp) if action=="start" else Supply.command(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,str(order.get("id","")),action,target(),stamp)
	status.text="화물 수송 · "+("처리 완료" if result.ok else str(result.reason))
	campaign.update_top_bar(); rebuild(str(result.get("order_id",order.get("id",""))))
