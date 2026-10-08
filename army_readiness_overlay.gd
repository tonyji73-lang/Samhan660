extends Control
const Army=preload("res://army_readiness.gd")
const Guide=preload("res://military_preparation_guide.gd")
const UI=preload("res://ui/living_city_v1/military_style.gd")
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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.8); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var panel:=PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.04,true); panel.set_anchor(SIDE_RIGHT,0.96,true); panel.set_anchor(SIDE_TOP,0.035,true); panel.set_anchor(SIDE_BOTTOM,0.965,true)
	theme=UI.City.make_theme()
	var style:=UI.City.panel(true); style.set_content_margin_all(24); panel.add_theme_stylebox_override("panel",style); UI.Industry.frame(panel)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",16); panel.add_child(box)
	result=UI.Industry.heading(); box.add_child(result)
	var tabs:=HBoxContainer.new(); box.add_child(tabs)
	for key: String in ["formation","training"]:
		mode_buttons[key]=button(tabs,{"formation":"편성 · 장비 지급","training":"훈련 · 지휘관"}[key],func(): show_mode(key))
		mode_buttons[key].size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var columns:=HBoxContainer.new(); columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; columns.add_theme_constant_override("separation",18); box.add_child(columns)
	var left:=VBoxContainer.new(); left.size_flags_horizontal=Control.SIZE_EXPAND_FILL; left.size_flags_stretch_ratio=0.25; columns.add_child(left)
	var middle:=VBoxContainer.new(); middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL; middle.size_flags_stretch_ratio=0.40; columns.add_child(middle)
	var right:=VBoxContainer.new(); right.size_flags_horizontal=Control.SIZE_EXPAND_FILL; right.size_flags_stretch_ratio=0.35; columns.add_child(right)
	unit_list=UI.scroll(left)
	var commander:=UI.section(left,"현재 지휘관")
	commander_portrait=UI.portrait(commander,null,Vector2(140,140)); commander_name=UI.label(commander,"미지정")
	selector=OptionButton.new(); add_child(selector); selector.hide(); selector.item_selected.connect(func(_n): refresh())
	officers=OptionButton.new(); add_child(officers); officers.hide(); officers.item_selected.connect(func(_n): refresh())
	var selection:=UI.section(middle,"선택 부대")
	unit_summary=UI.label(selection,"")
	formation_box=UI.scroll(middle)
	var edit:=UI.section(formation_box,"편성 조정")
	UI.label(edit,"인원을 정한 뒤 명령을 확정하세요.",21)
	var row:=HBoxContainer.new(); edit.add_child(row)
	amount=SpinBox.new(); amount.custom_minimum_size.x=170; amount.min_value=1; amount.max_value=100000; amount.value=1000; row.add_child(amount)
	split_button=button(row,"명 분리 편성",func(): run("split"))
	disband_button=button(edit,"선택 인원 현지 해산",func(): run("disband"))
	amount.value_changed.connect(func(_v): refresh())
	join_selector=OptionButton.new(); join_selector.clip_text=true; edit.add_child(join_selector)
	merge_button=button(edit,"선택한 부대에 합류·보충",func(): run("merge"))
	var movement:=UI.section(formation_box,"이동 · 출정")
	destination=OptionButton.new(); movement.add_child(destination)
	move_button=button(movement,"선택 부대 이동",func(): run("move"))
	attack_button=button(movement,"도시 가용 부대 출정",func(): hide(); campaign.select_province(city); campaign._on_attack_button_pressed())
	training_box=UI.scroll(middle); candidate_list=training_box
	var execute:=UI.section(right,"실행 정보")
	execute.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	var execute_scroll:=UI.scroll(execute)
	formation_actions=VBoxContainer.new(); execute_scroll.add_child(formation_actions)
	UI.label(formation_actions,"장비 지급 견적",27)
	bundles=SpinBox.new(); bundles.min_value=1; bundles.max_value=10000; bundles.value=10; formation_actions.add_child(bundles); bundles.value_changed.connect(func(_v): refresh())
	UI.label(formation_actions,"묶음 · 1묶음 = 100명분",21)
	equip_summary=UI.label(formation_actions,"")
	equip_button=button(formation_actions,"장비 지급 확정",func(): run("equip")); UI.City.button(equip_button,false,true)
	training_actions=VBoxContainer.new(); execute_scroll.add_child(training_actions)
	training_summary=UI.label(training_actions,"")
	commander_button=button(training_actions,"선택 후보를 지휘관으로 임명",func(): run("commander"))
	train_button=button(training_actions,"훈련 시작 · 담당자 교체",func(): run("train")); UI.City.button(train_button,false,true)
	stop_button=button(training_actions,"훈련 중지",func(): run("stop"))
	cancel_selection=button(training_actions,"후보 선택 취소",func(): select_officer(selection_before))
	var links:=UI.section(execute_scroll,"부족 물자 준비")
	for key: String in ["production","build","research"]:
		preparation_buttons[key]=button(links,{"production":"장비 생산 보기","build":"시설 건설 보기","research":"기술 연구 보기"}[key],func(): campaign.open_preparation_destination(city,id(),officer(),key))
	preparation=UI.label(execute_scroll,"",20)
	details=UI.label(UI.section(formation_box,"세부 기록"),"",20)
	close_button=button(box,"닫기 (Esc)",hide)
	show_mode("formation"); hide()
func button(parent: Node,text: String,callback: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(b); UI.City.button(b); b.pressed.connect(callback); return b
func open(c: Node,city_id: String) -> void:
	campaign=c; city=city_id; rebuild(); selection_before=officer(); show(); result.text="부대 편성·장비·훈련 · "+str(c.provinces[city].name); mode_buttons[mode].grab_focus()

func show_mode(value: String) -> void:
	mode=value
	formation_box.get_parent().visible=mode=="formation"; training_box.get_parent().visible=mode=="training"
	formation_actions.visible=mode=="formation"; training_actions.visible=mode=="training"
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
	UI.wire_focus.call_deferred(self)
	_render_units()
	preparation_model=Guide.model(campaign,city,id(),officer())
	preparation.text=preparation_model.text+"\n\n부대 상세"
	var u: Dictionary=Army.units(campaign.strategy_state).get(id(),{})
	if u.is_empty():
		details.text="주둔 부대 없음"; unit_summary.text=details.text; equip_summary.text="선택할 부대가 없습니다."; training_summary.text=equip_summary.text
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
	unit_summary.text="%s · %s\n병력 %d명  /  장비 충족 %.1f%%\n장비 %d명분 · 현재 숙련도 %.1f" % [id(),{"infantry":"보병","archer":"궁병","cavalry":"기병"}.get(u.kind,u.kind),u.troops,Army.ratio(u)*100,u.equipment,Army.training(u)]
	commander_portrait.texture=UI.texture(campaign,str(u.commander_id)); commander_name.text=str(campaign.get_officer(u.commander_id).get("name","미지정"))
	# Preview only the delta returned by the existing acceptance quote.
	var maximum: int=mini(stock,ceili(float(maxi(0,int(u.troops)-int(u.equipment)))/int(Army.RULES.bundle_persons)))
	var max_quote: Dictionary=Army.equip_quote(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,id(),maximum)
	equip_summary.text="현지 창고  %d묶음\n현재 지급 가능  %d묶음\n" % [stock,maximum if max_quote.ok else 0]
	if eq.ok:
		equip_summary.text+="\n확정 후 현지 창고\n%d → %d묶음\n\n부대 장비\n%d → %d명분\n병력 %d명 유지\n\n" % [stock,stock-int(eq.bundles),u.equipment,int(u.equipment)+int(eq.persons),u.troops]
	equip_summary.text+="지급 가능 · 확정 시에만 재고 차감" if eq.ok else str(eq.reason)
	training_summary.text="현재 숙련도  %.1f / 목표 %d\n%s\n" % [Army.training(u),Army.RULES.target,"진행 중" if not active_job.is_empty() else str({"completed":"훈련 완료","stopped":"중지"}.get(job.get("status",""),"접수 전"))]
	if not job.is_empty(): training_summary.text+="현재 담당 %s · 누적 납부 금 %d\n" % [campaign.get_officer(str(job.get("officer_id",""))).get("name","없음"),int(job.get("cost_paid",0))]
	# Duration/cost text is the existing preparation model, never a second formula.
	var guide_lines: PackedStringArray=str(preparation_model.text).split("\n")
	for line: String in guide_lines:
		if line.begins_with("훈련 ") or line.begins_with("월 금"): training_summary.text+="\n"+line
	training_summary.text+="\n\n"+("확정 후 다음 월부터 지불·훈련" if q.ok else str(q.reason))
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
