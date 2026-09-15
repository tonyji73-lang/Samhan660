extends Control

var campaign: Node
var city: String
var kind: String
var requirement: String
var last_job: String=""
var kind_selector: OptionButton
var city_selector: OptionButton
var requirement_selector: OptionButton
var officer_selector: OptionButton
var details: Label
var status: Label
var execute_button: Button
var assign_button: Button
var pause_button: Button
var cancel_button: Button
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.83); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var panel:=PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.15,true); panel.set_anchor(SIDE_RIGHT,0.85,true); panel.set_anchor(SIDE_TOP,0.04,true); panel.set_anchor(SIDE_BOTTOM,0.96,true)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("241f17"); style.border_color=Color("c8a75c"); style.set_border_width_all(1)
	for side: String in ["left","right","top","bottom"]: style.set("content_margin_"+side,18)
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",10); panel.add_child(box)
	status=Label.new(); box.add_child(status)
	kind_selector=OptionButton.new(); box.add_child(kind_selector)
	for kind_label: String in ["건설 업무","연구 업무","도시 생산 관리"]: kind_selector.add_item(kind_label)
	kind_selector.item_selected.connect(func(n): kind=["build","research","production"][n]; last_job=""; rebuild())
	city_selector=OptionButton.new(); box.add_child(city_selector); city_selector.item_selected.connect(func(n): city=str(city_selector.get_item_metadata(n)); rebuild_officers(); refresh())
	requirement_selector=OptionButton.new(); box.add_child(requirement_selector); requirement_selector.item_selected.connect(func(n): requirement=str(requirement_selector.get_item_metadata(n)); refresh())
	officer_selector=OptionButton.new(); box.add_child(officer_selector); officer_selector.item_selected.connect(func(_n): refresh())
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	details=Label.new(); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(details)
	execute_button=button(box,"업무 접수 · 견적 비용 지불",execute)
	assign_button=button(box,"선택한 담당자·거점으로 변경/재개 · 재결제 없음",assign_officer)
	var actions:=HBoxContainer.new(); box.add_child(actions)
	pause_button=button(actions,"일시 중지 · 담당자 해제",pause_job)
	cancel_button=button(actions,"업무 취소",cancel_job)
	close_button=button(box,"닫기 (Esc)",hide)
	for control: Control in [status,kind_selector,city_selector,requirement_selector,officer_selector,details,execute_button,assign_button,pause_button,cancel_button,close_button]: control.add_theme_font_size_override("font_size",21)
	hide()

func button(parent: Node, text: String, callable: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.custom_minimum_size.y=38; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(b); b.pressed.connect(callable); return b

func open(c: Node, city_id: String, task_kind: String, target: String) -> void:
	campaign=c; city=city_id; kind=task_kind; requirement=target; last_job=""
	kind_selector.select(["build","research","production"].find(kind)); rebuild(); show()

func selected_id() -> String:
	return str(officer_selector.get_item_metadata(officer_selector.selected)) if officer_selector.selected>=0 else ""

func rebuild_officers() -> void:
	var previous: String=selected_id(); officer_selector.clear()
	officer_selector.add_item("담당자를 선택하세요"); officer_selector.set_item_metadata(0,"")
	for id: String in campaign.get_city_officer_ids(city):
		var p: Dictionary=campaign.get_officer(id)
		officer_selector.add_item("%s · 정치 %d / 지력 %d%s" % [p.name,p.politics,p.intelligence," · 업무 중" if not p.get("duties",[]).is_empty() else ""])
		officer_selector.set_item_metadata(officer_selector.item_count-1,id)
		if id==previous: officer_selector.select(officer_selector.item_count-1)

func rebuild() -> void:
	city_selector.clear()
	for id: String in campaign.Economy.city_ids(campaign.strategy_state,campaign.provinces):
		if campaign.provinces[id].faction!=campaign.player_faction: continue
		city_selector.add_item("수행 도시: "+str(campaign.provinces[id].name)); city_selector.set_item_metadata(city_selector.item_count-1,id)
		if id==city: city_selector.select(city_selector.item_count-1)
	city_selector.disabled=kind!="research"
	requirement_selector.clear()
	var defs: Dictionary=campaign.SamhanStrategySystems.BUILDING_DEFS if kind=="build" else campaign.SamhanStrategySystems.RESEARCH_DEFS
	if kind!="production":
		for id: String in defs:
			requirement_selector.add_item(str(defs[id].name)); requirement_selector.set_item_metadata(requirement_selector.item_count-1,id)
			if id==requirement: requirement_selector.select(requirement_selector.item_count-1)
		if requirement_selector.selected>=0: requirement=str(requirement_selector.get_item_metadata(requirement_selector.selected))
	requirement_selector.visible=kind!="production"
	rebuild_officers(); refresh()

func job() -> Dictionary:
	return campaign.Industry.active(campaign.strategy_state,kind,city,campaign.player_faction_id)

func refresh() -> void:
	var active: Dictionary=job()
	if not active.is_empty(): last_job=active.id
	elif last_job.is_empty():
		for recent: Dictionary in campaign.Industry.jobs(campaign.strategy_state).values():
			if recent.kind==kind and recent.city_id==city and recent.get("requirement_id","")==requirement and recent.get("faction_id","")==campaign.player_faction_id: last_job=recent.id
	var q: Dictionary=campaign.Industry.quote(campaign.strategy_state,campaign.provinces,campaign.strategy,campaign.player_faction_id,city,kind,requirement,selected_id(),campaign.year*12+campaign.month,campaign.scenario_id,campaign.iron_supply_rules)
	status.text="%s · %s · 국고 %d" % [campaign.provinces.get(city,{}).get("name",city),["건설","연구","생산 관리"][["build","research","production"].find(kind)],campaign.gold]
	var p: Dictionary=campaign.get_officer(selected_id())
	var amount: int=campaign.Industry.effective_work(campaign.strategy_state,city,p,kind)
	details.text="선택 담당자: %s · 정치 %d / 지력 %d\n효율 E %d · 월 작업량 %d\n" % [p.get("name","미선택"),p.get("politics",0),p.get("intelligence",0),campaign.Industry.efficiency(p,kind),amount]
	if kind=="production": details.text+="위 수치는 개인 기본 작업량입니다. 협력·인계 차질 적용 결과는 아래 시설별 견적을 확인하세요.\n"
	if active.is_empty():
		details.text+="접수 비용: 금 %d · 필요 작업량 %d\n%s\n" % [q.get("gold_cost",0),q.get("required",0),"실행 가능" if q.ok else q.reason]
		if kind!="production" and q.get("months",0)>0 and not selected_id().is_empty(): details.text+="예상 %d개월 · %s 완료 (현재 선택 담당자 유지 시)\n" % [q.months,date(int(q.due_month))]
		var recent: Dictionary=campaign.Industry.jobs(campaign.strategy_state).get(last_job,{})
		if not recent.is_empty(): details.text+="최근 처리: %s · 진척 %d/%d · 환불 %d\n" % [recent.reason,recent.progress,recent.required,recent.refund]
	else:
		var current: Dictionary=campaign.get_officer(active.officer_id)
		var rate: int=campaign.Industry.effective_work(campaign.strategy_state,city,current,kind)
		var months: int=campaign.Industry.remaining_months(campaign.strategy_state,city,current,kind,int(active.required)-int(active.progress))
		var current_reason: String=campaign.Industry.staff_reason(campaign.strategy_state,campaign.provinces,active.faction_id,active.city_id,active.officer_id,campaign.year*12+campaign.month,active.id)
		details.text+="진행: %s · %s\n현재 담당: %s · 거점 %s\n" % [active.name,"진행 중" if active.status=="pending" else "일시 중지",current.get("name","배정 필요"),campaign.provinces.get(active.city_id,{}).get("name",active.city_id)]
		if kind!="production": details.text+="납부 금 %d · 진척 %d/%d · 월 작업량 %d\n" % [active.cost_paid,active.progress,active.required,rate]
		if not active.cost_known: details.text+="구형 저장에 납부 비용 기록 없음 · 재결제/추정 환불 없음\n"
		if kind!="production":
			if active.status=="pending" and current_reason.is_empty(): details.text+="예상 잔여 %d개월 · %s 완료 (유효한 현재 담당자 유지 시)\n" % [months,date(campaign.year*12+campaign.month+months)]
			else: details.text+="예상 완료: 담당자·거점 배정 및 재개 필요\n"
		if not current_reason.is_empty(): details.text+="현재 수행 불가: "+current_reason+"\n"
		var reason: String=campaign.Industry.staff_reason(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,city,selected_id(),campaign.year*12+campaign.month,active.id)
		details.text+="%s\n변경/재개: %s\n" % [active.reason,"가능" if reason.is_empty() else reason]
	if campaign.Power.city_factor(campaign.strategy_state,city)<1: details.text+="권력 인계 차질: 태수 보너스 중단 · 건설·생산 작업량 80% (기한 종료 후 복원)\n"
	if kind=="production":
		details.text+="담당자 없음: 시설별 월 100 / 담당자 있음: 100 + 반올림(E/2)\n100당 1배치 · 추가 배치도 금/재료 전액 지불\n"
		var city_forecast: Dictionary=campaign.ProductionSystem.city_quote(campaign.strategy_state,campaign.provinces,city,campaign.year*12+campaign.month+1,campaign.scenario_id,campaign.iron_supply_rules)
		for facility: String in ["smelter","forge"]:
			var forecast: Dictionary=city_forecast[facility]
			details.text+="%s: 잔여 %d/100 · 다음 월 최대 %d / 선행 공정 반영 %d배치 · 금 %d\n%s\n" % ["제철시설" if facility=="smelter" else "군기감",forecast.remainder_before,forecast.possible_batches,forecast.batches.size(),forecast.gold_cost,forecast.reason]
	else: details.text+="첫 월 진척 전 취소: 납부 비용 환불 1회\n진척 후 취소: 환불 없음 · 담당자 변경/일시 중지는 재결제 없음\n"
	details.text+="태수는 같은 도시 업무 하나 겸직 가능 · 업무 중 이동/사절/공격 출정 불가"
	execute_button.disabled=not active.is_empty() or not q.ok
	assign_button.disabled=active.is_empty() or not campaign.Industry.staff_reason(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,city,selected_id(),campaign.year*12+campaign.month,active.get("id","")).is_empty()
	pause_button.disabled=active.is_empty() or active.status!="pending"
	cancel_button.disabled=active.is_empty()

func date(stamp: int) -> String:
	return "%d년 %d월" % [int((stamp-1)/12.0),(stamp-1)%12+1]

func execute() -> void:
	var result: Dictionary=campaign.Industry.start(campaign.strategy_state,campaign.provinces,campaign.strategy,campaign.player_faction_id,city,kind,requirement,selected_id(),campaign.year*12+campaign.month,campaign.scenario_id,campaign.iron_supply_rules)
	if result.ok: last_job=result.job_id
	campaign.update_top_bar(); refresh()

func assign_officer() -> void:
	if job().is_empty(): return
	campaign.Industry.assign(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,job().id,city,selected_id(),campaign.year*12+campaign.month); refresh()

func pause_job() -> void:
	if job().is_empty(): return
	campaign.Industry.pause(campaign.strategy_state,campaign.player_faction_id,job().id,campaign.year*12+campaign.month); refresh()

func cancel_job() -> void:
	if job().is_empty(): return
	campaign.Industry.cancel(campaign.strategy_state,campaign.provinces,campaign.player_faction_id,job().id,campaign.year*12+campaign.month); campaign.update_top_bar(); refresh()
