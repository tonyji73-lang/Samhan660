extends Control
const Army=preload("res://army_readiness.gd")
const Guide=preload("res://military_preparation_guide.gd")
const UI=preload("res://ui/living_city_v1/military_style.gd")
const Supply=preload("res://supply_transport.gd")
const Production=preload("res://production_system.gd")
const ProductionData=preload("res://production_data.gd")
var stage: Control
var header: Label
var screen_title: Label
var overview: Control
var training_surface: Control
var management_panel: Control
var local_stock: Label
var production_status: Label
var production_art: TextureRect
var arrivals: Label
var equip_stock: Label
var action_title: Label
var status: Label
var transport_button: Button
var manage_button: Button
var reset_button: Button
var metric_labels: Dictionary={}
var metric_bars: Dictionary={}
var navigation: Dictionary={}
var mode: String="formation"
var unit_list: VBoxContainer
var candidate_list: VBoxContainer
var formation_box: VBoxContainer
var training_box: VBoxContainer
var formation_actions: VBoxContainer
var training_actions: VBoxContainer
var unit_summary: Label
var equip_summary: Label
var training_summary: Label
var commander_portrait: TextureRect
var commander_name: Label
var mode_buttons: Dictionary={}
var candidate_buttons: Array[Button]=[]
var cancel_selection: Button
var selection_before: String=""
var preparation: Label
var preparation_model: Dictionary={}
var preparation_buttons: Dictionary={}
var campaign: Node
var city: String
var selector: OptionButton
var join_selector: OptionButton
var officers: OptionButton
var destination: OptionButton
var amount: SpinBox
var bundles: SpinBox
var details: Label
var result: Label
var split_button: Button
var merge_button: Button
var disband_button: Button
var equip_button: Button
var train_button: Button
var stop_button: Button
var commander_button: Button
var move_button: Button
var attack_button: Button
var close_button: Button
func _ready() -> void:
	preload("res://ui/living_city_v1/military_overview_layout.gd").build(self)
func button(parent: Node,text: String,callback: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(b); UI.City.button(b); b.pressed.connect(callback); return b
func open(c: Node,city_id: String) -> void:
	campaign=c; city=city_id; rebuild(); selection_before=officer(); show(); result.text=""; mode_buttons[mode].grab_focus()

func show_mode(value: String) -> void:
	mode=value
	overview.visible=mode=="formation"; training_surface.visible=mode=="training"
	formation_actions.visible=mode=="formation"; training_actions.visible=mode=="training"
	equip_button.visible=mode=="formation"; train_button.visible=mode=="training"; reset_button.visible=mode=="formation"
	action_title.text="장비 지급" if mode=="formation" else "훈련 · 지휘관"
	for key: String in mode_buttons: UI.City.button(mode_buttons[key],mode==key)
	if campaign!=null: selection_before=officer(); refresh()

func select_officer(value: String) -> void:
	for n: int in range(officers.item_count):
		if str(officers.get_item_metadata(n))==value: officers.select(n); break
	refresh()
func id() -> String: return str(selector.get_item_metadata(selector.selected)) if selector.selected>=0 else ""
func officer() -> String: return str(officers.get_item_metadata(officers.selected)) if officers.selected>=0 else ""
func rebuild(selected: String="") -> void:
	# A completed command refreshes the roster; keep its selected trainer so the
	# next-month quote still describes the officer the player actually chose.
	var selected_officer: String=officer()
	selector.clear(); join_selector.clear(); officers.clear(); destination.clear()
	for uid: String in Army.at_city(campaign.strategy_state,city,campaign.player_faction_id):
		var u: Dictionary=Army.units(campaign.strategy_state)[uid]
		selector.add_item("%s · %s · %d명" % [uid,{"infantry":"보병","archer":"궁병","cavalry":"기병"}.get(u.kind,u.kind),u.troops]); selector.set_item_metadata(selector.item_count-1,uid)
		join_selector.add_item(uid); join_selector.set_item_metadata(join_selector.item_count-1,uid)
		if uid==selected: selector.select(selector.item_count-1)
	officers.add_item("훈련 담당자·지휘관 선택"); officers.set_item_metadata(0,"")
	for oid: String in campaign.get_city_officer_ids(city):
		var p: Dictionary=campaign.get_officer(oid)
		officers.add_item("%s · 통솔 %d / 무력 %d" % [p.name,p.leadership,p.war]); officers.set_item_metadata(officers.item_count-1,oid)
		if oid==selected_officer: officers.select(officers.item_count-1)
	for target: String in campaign.province_connections.get(city,[]):
		if campaign.provinces[target].faction==campaign.player_faction: destination.add_item(campaign.provinces[target].name); destination.set_item_metadata(destination.item_count-1,target)
	refresh()
func refresh() -> void:
	if campaign==null: return
	UI.wire_focus.call_deferred(management_panel if management_panel.visible else self)
	refresh_logistics()
	preparation_model=Guide.model(campaign,city,id(),officer())
	preparation.text=preparation_model.text+"\n\n부대 상세"
	var u: Dictionary=Army.units(campaign.strategy_state).get(id(),{})
	if u.is_empty():
		details.text="주둔 부대 없음"; unit_summary.text=details.text; equip_summary.text="선택할 부대가 없습니다."; training_summary.text=equip_summary.text
		status.text="이 도시에 주둔 부대가 없습니다."; metric_labels.equipment.text="장비 · —"; metric_labels.training.text="숙련도 · —"
		metric_bars.equipment.value=0; metric_bars.training.value=0
		commander_portrait.texture=null; commander_name.text="미지정"
		for b: Button in [split_button,merge_button,disband_button,equip_button,train_button,stop_button,commander_button,move_button,attack_button]: b.disabled=true
		_render_candidates(); return
	split_button.disabled=false; merge_button.disabled=join_selector.item_count<2; commander_button.disabled=false; attack_button.disabled=false
	var q: Dictionary=Army.training_quote(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,id(),officer(),campaign.year*12+campaign.month)
	var active_job: Dictionary=Army.training_job(campaign.strategy_state,id())
	var job: Dictionary=active_job
	if job.is_empty():
		for previous: Dictionary in campaign.strategy_state.domestic.jobs.values():
			if previous.kind=="training" and previous.get("unit_id","")==id(): job=previous
	var stock: int=campaign.strategy_state.city_inventory[city].sword
	details.text="%s · 병력 %d명 · 훈련도 %.3f\n부대 장비 %d명분 · 충족 %.1f%% (전투 최대100%%)\n도시 무기 %d묶음 = 지급 가능 %d명분\n지휘관: %s · 모집 출신: %s\n훈련 담당: %s · %s\n월 훈련비 금 %d · 예상 훈련도 %.1f → %.1f\n%s\n다음 월부터 지불·훈련, 목표70 · 1인 최대1,000명\n정상 군량은 도시 유지비로 한 번만 부담합니다.\n부대 기본 전투력 %.1f (장수·성곽 별도)" % [id(),u.troops,Army.training(u),u.equipment,Army.ratio(u)*100,stock,stock*100,campaign.get_officer(u.commander_id).get("name","미지정"),origin_text(u.origins),campaign.get_officer(str(job.get("officer_id",""))).get("name","없음"),str(job.get("reason",""))+str({"completed":"훈련 완료","pending":"진행 중","stopped":"중지"}.get(job.get("status",""),"")),int(q.get("cost",0)),Army.training(u),float(q.get("next_training",Army.training(u))),q.reason,Army.power(campaign.strategy_state,[id()])]
	var dq: Dictionary=campaign.Mobilization.disband_quote(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,id(),int(amount.value))
	details.text+="\n해산 견적: "+str(dq.reason)
	disband_button.disabled=not dq.ok
	details.text+="\n"+campaign.Power.summary(campaign.strategy_state,city,id())
	details.text+=battle_text()
	train_button.disabled=not q.ok
	var eq: Dictionary=Army.equip_quote(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,id(),int(bundles.value))
	equip_button.disabled=not eq.ok
	stop_button.disabled=active_job.is_empty(); move_button.disabled=destination.item_count==0
	unit_summary.text="%s · %s · 병력 %d명" % [{"infantry":"보병","archer":"궁병","cavalry":"기병"}.get(u.kind,u.kind),id(),u.troops]
	metric_labels.equipment.text="장비 %d / %d명분 (%.0f%%)" % [u.equipment,u.troops,Army.ratio(u)*100]
	metric_labels.training.text="숙련도 %.1f / 목표 %d" % [Army.training(u),Army.RULES.target]
	metric_bars.equipment.value=Army.ratio(u)*100
	metric_bars.training.max_value=Army.RULES.target; metric_bars.training.value=Army.training(u)
	commander_portrait.texture=UI.texture(campaign,str(u.commander_id)); commander_name.text=str(campaign.get_officer(u.commander_id).get("name","미지정"))
	# Preview only the delta returned by the existing acceptance quote.
	var maximum: int=mini(stock,ceili(float(maxi(0,int(u.troops)-int(u.equipment)))/int(Army.RULES.bundle_persons)))
	var max_quote: Dictionary=Army.equip_quote(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,id(),maximum)
	equip_summary.text="현재 지급 가능 %d묶음\n" % [maximum if max_quote.ok else 0]
	if eq.ok:
		equip_summary.text+="현지 창고  %d → %d묶음\n부대 장비  %d → %d명분\n지급 후 부족  %d명분\n병력 %d명 유지" % [stock,stock-int(eq.bundles),u.equipment,int(u.equipment)+int(eq.persons),maxi(0,int(u.troops)-int(u.equipment)-int(eq.persons)),u.troops]
	else: equip_summary.text+=str(eq.reason)
	training_summary.text="현재 숙련도  %.1f / 목표 %d\n%s\n" % [Army.training(u),Army.RULES.target,"진행 중" if not active_job.is_empty() else str({"completed":"훈련 완료","stopped":"중지"}.get(job.get("status",""),"접수 전"))]
	if not job.is_empty(): training_summary.text+="현재 담당 %s · 누적 납부 금 %d\n" % [campaign.get_officer(str(job.get("officer_id",""))).get("name","없음"),int(job.get("cost_paid",0))]
	# Duration/cost text is the existing preparation model, never a second formula.
	var guide_lines: PackedStringArray=str(preparation_model.text).split("\n")
	for line: String in guide_lines:
		if line.begins_with("훈련 ") or line.begins_with("월 금"): training_summary.text+="\n"+line
	training_summary.text+="\n\n"+("확정 후 다음 월부터 지불·훈련" if q.ok else str(q.reason))
	status.text=("확정 시에만 현지 재고가 차감됩니다." if eq.ok else str(eq.reason)) if mode=="formation" else ("확정 후 다음 월부터 지불·훈련" if q.ok else str(q.reason))
	_render_candidates()

func _render_units() -> void:
	var had_focus: bool=unit_list.is_ancestor_of(get_viewport().gui_get_focus_owner()) if get_viewport().gui_get_focus_owner()!=null else false
	for child: Node in unit_list.get_children(): unit_list.remove_child(child); child.queue_free()
	var title:=UI.section(unit_list,"현지 주둔 부대")
	if selector.item_count==0: UI.label(title,"주둔 부대 없음")
	for n: int in range(selector.item_count):
		var index: int=n
		var b:=button(title,selector.get_item_text(n),func(): selector.select(index); refresh())
		UI.City.button(b,n==selector.selected)
		if had_focus and n==selector.selected: b.grab_focus.call_deferred()

func _render_candidates() -> void:
	var focused_id: String=""
	for b: Button in candidate_buttons:
		if is_instance_valid(b) and b.has_focus(): focused_id=str(b.get_meta("officer_id",""))
	candidate_buttons.clear()
	for child: Node in candidate_list.get_children(): candidate_list.remove_child(child); child.queue_free()
	if officers.item_count<=1: UI.label(candidate_list,"이 도시에 훈련 담당자 후보가 없습니다."); return
	for n: int in range(1,officers.item_count):
		var oid: String=str(officers.get_item_metadata(n)); var p: Dictionary=campaign.get_officer(oid)
		var preview: Dictionary=campaign.strategy_state.duplicate(true)
		var quote: Dictionary=Army.training_quote(preview,campaign.provinces.duplicate(true),campaign.player_faction_id,id(),oid,campaign.year*12+campaign.month)
		var duty_names: Array[String]=[]
		for duty: Dictionary in p.get("duties",[]): duty_names.append(str({"training":"훈련","domestic":"내정","production":"생산","build":"건설","research":"연구"}.get(duty.get("kind",""),duty.get("kind",""))))
		var info: String="통솔 %d · 무력 %d\n현재 업무 · %s" % [p.get("leadership",0),p.get("war",0),"없음" if duty_names.is_empty() else " · ".join(duty_names)]
		var b:=UI.card(candidate_list,campaign,oid,oid==officer(),info,"훈련 배정 가능" if quote.ok else str(quote.reason),func(): select_officer(oid))
		candidate_buttons.append(b)
		if oid==focused_id: b.grab_focus.call_deferred()
func run(action: String) -> void:
	var uid: String=id(); if uid.is_empty(): return
	var state: Dictionary=campaign.strategy_state; var actor: String=campaign.player_faction_id; var stamp: int=campaign.year*12+campaign.month
	var q: Dictionary={"ok":true,"reason":"처리 완료"}
	match action:
		"split": q=Army.split(state,campaign.provinces,actor,uid,int(amount.value)); uid=str(q.get("unit_id",uid))
		"merge": q=Army.merge(state,campaign.provinces,actor,str(join_selector.get_item_metadata(join_selector.selected)),uid)
		"equip": q=Army.equip(state,campaign.provinces,actor,uid,int(bundles.value),stamp)
		"commander": q=Army.appoint(state,campaign.provinces,actor,uid,officer())
		"train": q=Army.train(state,campaign.provinces,actor,uid,officer(),stamp)
		"stop": Army.stop(state,uid)
		"disband": q=campaign.Mobilization.disband(state,campaign.provinces,actor,uid,int(amount.value),stamp)
		"move":
			var u: Dictionary=Army.units(state)[uid]
			var staff: Array=[] if str(u.commander_id).is_empty() else [u.commander_id]
			q=campaign.queue_province_transfer({"source_id":city,"target_id":destination.get_item_metadata(destination.selected),"troops":u.troops,"unit_ids":[uid],"officer_ids":staff},true)
	Army.sync(state,campaign.provinces); campaign.update_top_bar(); rebuild(uid); selection_before=officer()
	var message: String=str(q.get("reason",""))
	result.text="부대 명령 · "+("처리 완료" if message.is_empty() else message)

func fit_stage() -> void:
	if stage==null: return
	var factor: float=minf(size.x/1920.0,size.y/1080.0)
	stage.scale=Vector2.ONE*factor; stage.position=(size-Vector2(1920,1080)*factor)/2

func refresh_logistics() -> void:
	var province: Dictionary=campaign.provinces[city]
	header.text="%s · %s  |  %d년 %d월   국고 %d" % [campaign.player_faction,province.name,campaign.year,campaign.month,campaign.gold]
	screen_title.text=str(province.name)+" · 군수"
	var inventory: Dictionary=Production.get_inventory_view(campaign.strategy_state,campaign.provinces,city)
	local_stock.text="군량\n%d\n\n철\n%d\n\n무기 %d묶음" % [inventory.get("grain",0),inventory.get("iron",0),inventory.get("sword",0)]
	equip_stock.text="현지 무기 재고 (%s) · %d묶음" % [province.name,inventory.get("sword",0)]
	var running: Array[String]=[]
	for recipe: String in ProductionData.RECIPE_ORDER:
		var order: Dictionary=campaign.strategy_state.get("city_production",{}).get(city,{}).get(recipe,{})
		if not order.get("enabled",false): continue
		var model: Dictionary=campaign.get_production_view_model(city,recipe)
		var reason: String=str(model.get("reason",""))
		running.append(str(ProductionData.RECIPES[recipe].name)+"\n"+("가동 예약 · 다음 월 정산" if reason.is_empty() else "생산 보류 · "+reason))
	production_status.text="가동 예약 중인 생산 없음" if running.is_empty() else "\n\n".join(running)
	production_art.modulate=Color(0.6,0.6,0.6) if running.is_empty() else Color.WHITE
	var incoming: Array[String]=[]
	for order: Dictionary in campaign.strategy_state.get("supply_transport",{}).get("orders",{}).values():
		if order.get("target","")!=city or order.get("faction_id","")!=campaign.player_faction_id or not Supply.active(order): continue
		var reason: String=Supply.remaining_reason(campaign.strategy_state,campaign.provinces,order)
		incoming.append("%s → %s\n군량 %d · 철 %d · 무기 %d묶음\n%s" % [campaign.provinces.get(order.source,{}).get("name",order.source),province.name,order.cargo.get("grain",0),order.cargo.get("iron",0),order.cargo.get("sword",0),"이동 중" if reason.is_empty() else "도착 보류 · "+reason])
	arrivals.text="도착 예정 화물 없음" if incoming.is_empty() else "\n\n".join(incoming)
	transport_button.disabled=transport_source().is_empty()

func transport_source() -> String:
	for source: String in Supply.Economy.city_ids(campaign.strategy_state,campaign.provinces):
		if source!=city and Supply.owner(campaign.strategy_state,campaign.provinces,source)==campaign.player_faction_id: return source
	return ""

func open_transport() -> void:
	var source: String=transport_source()
	if source.is_empty(): return
	var context: Dictionary={"city":city,"unit":id(),"officer":officer()}
	campaign.open_supply(source)
	if not campaign.supply_overlay.visible: return
	hide(); campaign.preparation_return=context
	for n: int in range(campaign.supply_overlay.destination.item_count):
		if str(campaign.supply_overlay.destination.get_item_metadata(n))==city:
			campaign.supply_overlay.destination.select(n); break
	campaign.supply_overlay.refresh()

func open_management() -> void:
	management_panel.show(); management_panel.move_to_front()
	UI.wire_focus(management_panel); amount.get_line_edit().grab_focus()

func close_management() -> void:
	management_panel.hide(); UI.wire_focus(self); manage_button.grab_focus()

func _input(event: InputEvent) -> void:
	if visible and management_panel!=null and management_panel.visible and event.is_action_pressed("ui_cancel"):
		close_management(); get_viewport().set_input_as_handled()

func navigate(target: String) -> void:
	if target=="army": return
	hide()
	match target:
		"domestic","personnel":
			campaign.domestic_overlay.open(campaign,city,"agriculture")
			if target=="personnel": campaign.domestic_overlay._set_mode(true)
		"production","build","research": campaign.open_preparation_destination(city,id(),officer(),target)
		"court": campaign.open_politics()
		"diplomacy": campaign._open_diplomacy()
		"month": campaign._on_end_turn_button_pressed()

func origin_text(origins: Dictionary) -> String:
	var pieces: Array[String]=[]
	for origin: String in origins:
		if int(origins[origin])>0: pieces.append("%s %d명" % [campaign.provinces.get(origin,{}).get("name","미상" if origin.is_empty() else origin),origins[origin]])
	return " · ".join(pieces)
func battle_text() -> String:
	var records: Array=campaign.strategy_state.army.battles
	for n: int in range(records.size()-1,-1,-1):
		var b: Dictionary=records[n]
		if b.source==city or b.target==city:
			return "\n\n최근 실제 전투 · %s → %s · %s\n실효 전투력 %.1f / %.1f\n참여 %d / %d명 · 손실 %d / %d명\n장비·훈련은 부대별 합산, 장수·성곽은 각각 한 번 적용" % [campaign.provinces[b.source].name,campaign.provinces[b.target].name,"공격 승리" if b.won else "방어 성공",b.attacker_power,b.defender_power,b.attacker_troops,b.defender_troops,b.attacker_losses,b.defender_losses]
	return ""
