extends Control
const Army=preload("res://army_readiness.gd")
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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.8); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var panel:=PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.12,true); panel.set_anchor(SIDE_RIGHT,0.88,true); panel.set_anchor(SIDE_TOP,0.03,true); panel.set_anchor(SIDE_BOTTOM,0.97,true)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("241f17"); style.border_color=Color("c8a75c"); style.set_border_width_all(1)
	for side: String in ["left","right","top","bottom"]: style.set("content_margin_"+side,14)
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",7); panel.add_child(box)
	result=Label.new(); box.add_child(result)
	selector=OptionButton.new(); box.add_child(selector); selector.item_selected.connect(func(_n): refresh())
	var row:=HBoxContainer.new(); box.add_child(row)
	amount=SpinBox.new(); amount.min_value=1; amount.max_value=100000; amount.value=1000; row.add_child(amount)
	split_button=button(row,"명 분리 편성",func(): run("split"))
	disband_button=button(row,"명 현지 해산",func(): run("disband"))
	amount.value_changed.connect(func(_v): refresh())
	join_selector=OptionButton.new(); row.add_child(join_selector)
	merge_button=button(row,"선택 부대에 합류·보충",func(): run("merge"))
	row=HBoxContainer.new(); box.add_child(row)
	bundles=SpinBox.new(); bundles.min_value=1; bundles.max_value=10000; bundles.value=10; row.add_child(bundles); bundles.value_changed.connect(func(_v): refresh())
	equip_button=button(row,"무기 묶음 지급 (1묶음=100명분)",func(): run("equip"))
	officers=OptionButton.new(); box.add_child(officers); officers.item_selected.connect(func(_n): refresh())
	row=HBoxContainer.new(); box.add_child(row)
	commander_button=button(row,"지휘관 임명",func(): run("commander"))
	train_button=button(row,"훈련 시작·담당자 교체",func(): run("train"))
	stop_button=button(row,"훈련 중지",func(): run("stop"))
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	details=Label.new(); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(details)
	row=HBoxContainer.new(); box.add_child(row)
	destination=OptionButton.new(); row.add_child(destination)
	move_button=button(row,"선택 부대 이동",func(): run("move"))
	attack_button=button(row,"도시 가용 부대 출정",func(): hide(); campaign.select_province(city); campaign._on_attack_button_pressed())
	close_button=button(box,"닫기 (Esc)",hide)
	add_theme_font_size_override("font_size",19); hide()
func button(parent: Node,text: String,callback: Callable) -> Button:
	var b:=Button.new(); b.text=text; parent.add_child(b); b.pressed.connect(callback); return b
func open(c: Node,city_id: String) -> void:
	campaign=c; city=city_id; rebuild(); show(); result.text="부대 편성·장비·훈련 · "+str(c.provinces[city].name)
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
	var u: Dictionary=Army.units(campaign.strategy_state).get(id(),{})
	if u.is_empty(): details.text="주둔 부대 없음"; return
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
	equip_button.disabled=not Army.equip_quote(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,id(),int(bundles.value)).ok
	stop_button.disabled=active_job.is_empty(); move_button.disabled=destination.item_count==0
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
	Army.sync(state,campaign.provinces); campaign.update_top_bar(); rebuild(uid); result.text="부대 명령 · "+str(q.get("reason","완료"))

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
