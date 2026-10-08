extends "res://noble_politics_overlay.gd"
const UI=preload("res://ui/living_city_v1/military_style.gd")
const Preview=preload("res://ui/living_city_v1/politics_preview.gd")
const ProductionData=preload("res://production_data.gd")
var national: Label
var ruler: TextureRect
var ruler_name: Label
var group_list: VBoxContainer
var member_list: VBoxContainer
var group_buttons: Dictionary={}
var selected_group: String=""
var issues: OptionButton
var choices: OptionButton
var issue_detail: Label
var successors: OptionButton
var issue_box: VBoxContainer
var appointment_box: VBoxContainer
var cancel_button: Button
var mode: String="issues"
var model: Dictionary={}
var group_summary: Label

func button(parent: Node,text: String,action: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(b); UI.City.button(b); b.pressed.connect(action); return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP; theme=UI.City.make_theme()
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.8); add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.035,true); panel.set_anchor(SIDE_RIGHT,0.965,true); panel.set_anchor(SIDE_TOP,0.03,true); panel.set_anchor(SIDE_BOTTOM,0.97,true)
	var style:=UI.City.panel(true); style.set_content_margin_all(24); panel.add_theme_stylebox_override("panel",style); UI.Industry.frame(panel)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",14); panel.add_child(box)
	var title:=UI.Industry.heading(); title.text="조정 · 귀족 정치"; box.add_child(title)
	var columns:=HBoxContainer.new(); columns.add_theme_constant_override("separation",16); columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(columns)
	var left:=column(columns,0.26); var middle:=column(columns,0.37); var right:=column(columns,0.37)
	var sovereign:=UI.section(left,"군주 · 국정 요약"); var row:=HBoxContainer.new(); sovereign.add_child(row)
	ruler=UI.portrait(row,null,Vector2(100,116)); ruler_name=UI.label(row,""); national=UI.label(sovereign,"",21); group_list=UI.scroll(left)
	var center:=UI.section(middle,"선택 집단 · 실제 기반"); center.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	var body:=UI.scroll(center); group_summary=UI.label(body,"",26); member_list=VBoxContainer.new(); member_list.add_theme_constant_override("separation",12); body.add_child(member_list); details=UI.label(body,"",21)
	history_people=OptionButton.new(); history_people.clip_text=true; body.add_child(history_people); history_people.item_selected.connect(func(_n): refresh())
	var response:=UI.section(right,"현안 · 대응 확인"); response.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	var tabs:=HBoxContainer.new(); response.add_child(tabs); button(tabs,"현안 대응",func(): set_mode("issues")); button(tabs,"인사 제안",func(): set_mode("appointment"))
	var scroll:=UI.scroll(response); issue_box=VBoxContainer.new(); scroll.add_child(issue_box)
	issues=selector(issue_box); issues.item_selected.connect(func(_n): populate_choices())
	choices=selector(issue_box); choices.item_selected.connect(func(_n): forecast())
	successors=selector(issue_box); successors.item_selected.connect(func(_n): forecast())
	preview=UI.label(scroll,"",24); issue_detail=UI.label(scroll,"",20)
	appointment_box=VBoxContainer.new(); scroll.add_child(appointment_box)
	targets=selector(appointment_box); targets.item_selected.connect(func(_n): populate())
	people=selector(appointment_box); people.item_selected.connect(func(_n): forecast())
	result=UI.label(response,"선택은 미리보기입니다.",20)
	apply_button=button(response,"대응 확정",execute); UI.City.button(apply_button,false,true)
	cancel_button=button(response,"선택 취소 · 상태 유지",cancel_selection); close_button=button(box,"닫기 (Esc)",hide); hide()

func column(parent: Node,ratio: float) -> VBoxContainer:
	var box:=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.size_flags_stretch_ratio=ratio; parent.add_child(box); return box
func selector(parent: Node) -> OptionButton:
	var b:=OptionButton.new(); b.clip_text=true; parent.add_child(b); return b
func clear_box(box: Node) -> void:
	for child: Node in box.get_children(): box.remove_child(child); child.queue_free()
func open(c: Node) -> void:
	# A loaded campaign may no longer contain the previously selected request.
	mode="issues"; issues.clear(); choices.clear(); model={}
	super.open(c); rebuild_issues(); set_mode("issues"); close_button.grab_focus()
	for scroll: Node in find_children("*","ScrollContainer",true,false): scroll.set_deferred("scroll_vertical",0)
func person_basis(id: String) -> String:
	var p: Dictionary=campaign.get_officer(id); var lines: Array[String]=[]
	lines.append("충성 %s / 100 · 야망 %s / 100" % [str(int(p.loyalty)) if p.has("loyalty") else "미설정",str(int(p.ambition)) if p.has("ambition") else "미설정"])
	lines.append("위치 · "+str(campaign.provinces.get(str(p.get("location","")),{}).get("name","이동 중 또는 미상")))
	lines.append("상태 · "+("사망" if not p.get("alive",true) else ("비활동" if not p.get("active",true) else ("이동 중" if p.get("in_transit",false) else "활동 중"))))
	for post: String in campaign.officer_registry.posts:
		if campaign.officer_registry.posts[post]!=id: continue
		if post.begins_with("governor:"): lines.append(str(campaign.provinces.get(post.trim_prefix("governor:"),{}).get("name",""))+" 태수")
		elif post.begins_with("ruler:"): lines.append("군주")
	lines.append("지휘 병력 %d명" % Core.commanded(campaign.strategy_state,id))
	for duty: Dictionary in p.get("duties",[]):
		var kind: String=str(duty.get("kind","기록 없음"))
		if kind=="industry": kind=str(campaign.strategy_state.get("domestic",{}).get("jobs",{}).get(str(duty.get("job_id","")),{}).get("kind",kind))
		lines.append("업무 · "+str({"training":"훈련","domestic":"내정","production":"생산","build":"건설","research":"연구","industry":"산업"}.get(kind,kind)))
	return "\n".join(lines)
func refresh() -> void:
	var c: Node=campaign; var r: Dictionary=c.officer_registry
	var king: String=str(r.posts.get("ruler:"+c.player_faction_id,"")); ruler.texture=UI.texture(c,king); ruler_name.text=str(c.get_officer(king).get("name","군주 정보 없음"))+"\n"+str(c.player_faction)+"\n"+c.Power.date(c.year*12+c.month)
	var power: Dictionary=Core.influence(c.strategy_state,c.provinces,c.player_faction_id); var available:=0
	for city: String in c.Economy.city_ids(c.strategy_state,c.provinces): available+=c.Army.count(c.strategy_state,c.Army.attack_units(c.strategy_state,city,c.player_faction_id))
	national.text="국가 금 %d\n전체 병력 %d명\n출정 후보 병력 %d명\n군량·출정 조건은 명령에서 확인" % [c.gold,power.troops,available]
	var groups: Dictionary=r.get("politics",{}).get("groups",{}) if r.get("politics",{}).get("faction_id","")==c.player_faction_id else {}
	if not groups.has(selected_group): selected_group=str(groups.keys()[0]) if not groups.is_empty() else ""
	clear_box(group_list); group_buttons.clear(); clear_box(member_list)
	for gid: String in groups:
		var g: Dictionary=groups[gid]; var b:=button(group_list,("선택 · " if gid==selected_group else "")+str(g.name)+"\n협력 %d/100 · 영향력 %.2f/100" % [g.cooperation,power.groups[gid].influence],func(): selected_group=gid; refresh(); member_list.get_parent().get_parent().set_deferred("scroll_vertical",0); group_buttons[gid].grab_focus())
		UI.City.button(b,gid==selected_group); group_buttons[gid]=b
	var members: Array=[]; var lines: Array[String]=[]
	if groups.is_empty():
		lines.append("이 국가·시나리오에는 정의된 정치 집단이 없습니다. 아래는 실제 소속 인물입니다.")
		for id: String in r.people:
			if r.people[id].faction_id==c.player_faction_id and r.people[id].active: members.append(id)
	else:
		var g: Dictionary=groups[selected_group]; var row: Dictionary=power.groups[selected_group]; members=g.members
		lines.append("%s · 협력 %d/100 · 영향력 %.2f/100\n%s" % [g.name,g.cooperation,row.influence,g.get("description","")])
		lines.append("개인 충성: 인물별 왕명 반응\n집단 협력: 관계 상태, 일부 생산 작업량에 반영\n영향력: 지휘 병력 비중×60 + 태수 민간 인구 비중×40 (점, 확률 아님)")
		lines.append("지휘 %d / 국가 %d명\n태수 민간 기반 %d / 국가 %d명\n도시: %s\n부대: %s\n업무 자체는 영향력에 가산되지 않습니다." % [row.troops,power.troops,row.population,power.population," · ".join(row.cities.map(func(city): return str(c.provinces[city].name)))," · ".join(row.units)])
		var history: Array=g.get("history",[]); lines.append("최근 변화 기록" if not history.is_empty() else "변화 원인 기록 없음 · 원인을 추정하지 않습니다.")
		for h: Dictionary in history.slice(maxi(0,history.size()-6)):
			lines.append("%s · %s · %s\n충성 %d→%d / 협력 %d→%d" % [c.Power.date(int(h.month)),c.get_officer(h.officer_id).get("name",h.officer_id),str(h.reason).replace("compensate","보상").replace("complete","기한 인계").replace("force","강제 회수"),h.loyalty_before,h.loyalty_after,h.cooperation_before,h.cooperation_after])
	lines.append("미배정 병력 %d명 · 무소속 지휘 병력 %d명\n독립 왕권 점수는 없습니다. 미배정 기반을 왕실에 귀속하지 않습니다." % [power.unassigned.troops,power.unaffiliated.troops])
	if history_people.selected>0: lines.append(Merit.history(c.strategy_state,str(history_people.get_item_metadata(history_people.selected)),c.provinces))
	details.text="\n\n".join(lines)
	group_summary.text=str(groups[selected_group].name) if not selected_group.is_empty() else "실제 소속 인물 · 집단 설정 없음"
	for id: String in members: UI.card(member_list,c,id,false,person_basis(id),"인물 이력 확인 가능",func():
		for n: int in range(history_people.item_count):
			if history_people.get_item_metadata(n)==id: history_people.select(n); refresh(); history_people.grab_focus(); break)
	UI.wire_focus.call_deferred(self)
func set_mode(value: String) -> void:
	mode=value; issue_box.visible=value=="issues"; issue_detail.visible=value=="issues"; appointment_box.visible=value=="appointment"; forecast()
func rebuild_issues(select_id: String="") -> void:
	issues.clear(); var pending: Dictionary=campaign.officer_registry.get("politics",{}).get("pending",{})
	if pending.get("faction_id","")==campaign.player_faction_id:
		issues.add_item("요구 · "+campaign.get_officer(pending.officer_id).get("name","")); issues.set_item_metadata(0,{"type":"demand","id":pending.occurrence_id})
	for row: Dictionary in campaign.Power.records(campaign.strategy_state).get("requests",{}).values():
		if row.request.faction_id!=campaign.player_faction_id: continue
		issues.add_item("%s · %s · %s" % [campaign.provinces.get(row.city,{}).get("name",row.city),row.id,campaign.Power.status_name(row.status)]); issues.set_item_metadata(issues.item_count-1,{"type":"power","id":row.id})
	for n: int in range(issues.item_count):
		if issues.get_item_metadata(n).id==select_id: issues.select(n)
	issues.disabled=issues.item_count==0; choices.disabled=issues.item_count==0
	if issues.item_count==0: issues.text="현재 현안 없음"
	populate_choices()
func show_issue(_kind: String,id: String) -> void:
	set_mode("issues"); rebuild_issues(id); show(); issues.grab_focus()
func populate_choices() -> void:
	choices.clear(); choices.add_item("대응 선택 · 아직 실행하지 않음"); choices.set_item_metadata(0,""); successors.clear(); successors.hide()
	if issues.selected<0: issue_detail.text="현재 이 국가의 요구·권력 인계 기록이 없습니다."; forecast(); return
	var issue: Dictionary=issues.get_item_metadata(issues.selected)
	if issue.type=="power":
		var row: Dictionary=campaign.Power.records(campaign.strategy_state).requests[issue.id]; issue_detail.text=campaign.Power.describe(campaign,row)
		for oid: String in row.old_ids: issue_detail.text+="\n영향 인물 · "+campaign.get_officer(oid).get("name",oid)+"\n"+person_basis(oid)
		var successor: String=str(row.request.get("officer_id",""))
		if not successor.is_empty() and not row.old_ids.has(successor): issue_detail.text+="\n후임 · "+campaign.get_officer(successor).get("name",successor)+"\n"+person_basis(successor)
		for uid: String in row.units: issue_detail.text+="\n영향 부대 · %s · %d명 · 훈련 %s" % [uid,campaign.strategy_state.unit_rosters.get(uid,{}).get("troops",0),"진행 중" if not campaign.Army.training_job(campaign.strategy_state,uid).is_empty() else "없음"]
		if row.request.kind=="governor":
			issue_detail.text+="\n해당 도시의 진행 업무 (강제 시 건설·생산 작업량에 차질):"
			for job: Dictionary in campaign.strategy_state.get("domestic",{}).get("jobs",{}).values():
				if job.get("city_id","")==row.city and job.get("status","") in ["pending","paused"]:
					issue_detail.text+="\n%s · 담당 %s · %s" % [{"build":"건설","research":"연구","production":"생산","training":"훈련","domestic":"내정","agriculture":"농업","commerce":"상업"}.get(job.kind,job.kind),campaign.get_officer(str(job.get("officer_id",""))).get("name","없음"),("진척 "+str(job.progress)) if job.has("progress") else "진척 수치 기록 없음"]
			for recipe: String in campaign.strategy_state.get("city_production",{}).get(row.city,{}):
				if campaign.strategy_state.city_production[row.city][recipe].get("enabled",false): issue_detail.text+="\n가동 예약 · "+str(ProductionData.RECIPES.get(recipe,{}).get("name",recipe))
		if row.status in ["offered","waiting","successor_needed"]:
			for key: String in ["compensate","wait","force","withdraw"]:
				if key=="wait" and row.status!="offered": continue
				choices.add_item({"compensate":"보상 · 즉시 인계","wait":"기한 보장","force":"강제 회수","withdraw":"협의 철회"}[key]); choices.set_item_metadata(choices.item_count-1,key)
			if row.status in ["waiting","successor_needed"] and row.request.kind in ["governor","commander"]:
				choices.add_item("후임 재지정 · 기존 기한 유지"); choices.set_item_metadata(choices.item_count-1,"retarget")
				successors.add_item("공석으로 인계"); successors.set_item_metadata(0,"")
				var city: String=row.city if row.request.kind=="governor" else str(campaign.strategy_state.unit_rosters.get(row.request.target,{}).get("location",row.city))
				for oid: String in campaign.get_city_officer_ids(city): successors.add_item(campaign.get_officer(oid).name); successors.set_item_metadata(successors.item_count-1,oid)
	else:
		var request: Dictionary=campaign.officer_registry.politics.pending
		issue_detail.text="기존 요구 · %s\n%s · %s\n발생 %s" % [request.payload.group,request.payload.candidate,request.payload.position,campaign.Power.date(request.created_month)]
		for key: String in ["accept","gift","reject"]:
			choices.add_item({"accept":"요구 수락 · 인사/인계 협의","gift":"포상 · 직책 유지","reject":"거절 · 직책 유지"}[key]); choices.set_item_metadata(choices.item_count-1,key)
	forecast()
func forecast() -> void:
	apply_button.disabled=true; model={}; successors.visible=false
	if campaign==null: return
	if mode=="appointment":
		apply_button.text="인사 확정 · 필요 시 인계 협의"
		if people.selected<0 or targets.selected<0: preview.text="현지 임명 가능한 인물이 없습니다."; return
		var t: Dictionary=targets.get_item_metadata(targets.selected); var oid: String=str(people.get_item_metadata(people.selected))
		var q: Dictionary=Personnel.quote(campaign,campaign.player_faction_id,t.kind,t.target,oid)
		if not q.ok: preview.text=q.reason; return
		var transfer: Dictionary=campaign.Power.quote(campaign,{"kind":t.kind,"target":t.target,"officer_id":oid,"faction_id":campaign.player_faction_id})
		if not transfer.ok: preview.text=transfer.reason; return
		apply_button.disabled=false
		if transfer.get("required",false): preview.text=campaign.Power.describe(campaign,transfer); return
		preview.text="인사 예상 · 필요 금 0\n%s → %s · %s %d → %d" % [campaign.get_officer(q.previous_id).get("name","공석"),campaign.get_officer(oid).name,"정치" if t.kind=="governor" else "통솔",q.old_ability,q.ability]
		for h: Dictionary in q.reactions: preview.text+="\n%s 충성 %d→%d / 협력 %d→%d" % [campaign.get_officer(h.officer_id).name,h.loyalty_before,h.loyalty_after,h.cooperation_before,h.cooperation_after]
		if q.reactions.is_empty(): preview.text+="\n기존 계산의 정치 반응 없음"
		if campaign.officer_registry.get("politics",{}).get("faction_id","")==campaign.player_faction_id:
			for gid: String in q.before.groups: preview.text+="\n%s 영향력 %.2f → %.2f" % [campaign.officer_registry.politics.groups[gid].name,q.before.groups[gid].influence,q.after.groups[gid].influence]
		UI.wire_focus.call_deferred(self); return
	apply_button.text="검토한 대응 확정"
	if issues.selected<0 or choices.selected<=0: preview.text="대응을 선택하면 비용·관계 변화를 확인합니다."; UI.wire_focus.call_deferred(self); return
	var issue: Dictionary=issues.get_item_metadata(issues.selected); var choice: String=str(choices.get_item_metadata(choices.selected)); successors.visible=choice=="retarget"
	model=Preview.inspect(campaign,issue.type,issue.id,choice,str(successors.get_item_metadata(successors.selected)) if successors.selected>=0 else "")
	apply_button.disabled=not model.ok
	preview.text="확정 시 현재 조건의 예상 결과\n필요 금 %d · 국고 %d → %d" % [model.gold_before-model.gold_after,model.gold_before,model.gold_after]
	for h: Dictionary in model.reactions: preview.text+="\n%s · %s %d → %d / 100" % [h.name,h.unit,h.before,h.after]
	if model.reactions.is_empty(): preview.text+="\n지금 적용되는 충성·협력 변화 없음"
	preview.text+="\n"+str(model.result.get("reason",model.result.get("result_text",""))).replace("compensate","보상").replace("force","강제 회수")
	if issue.type=="power":
		var row: Dictionary=campaign.Power.records(model.state).requests[issue.id]
		if row.status=="waiting": preview.text+="\n인계 예정 · "+campaign.Power.date(int(row.due_month))
		var effects: Dictionary=campaign.Power.records(model.state)
		var city_effect: Dictionary=effects.get("cities",{}).get(row.city,{})
		if int(city_effect.get("remaining",0))>0: preview.text+="\n도시 차질 · 다음 %d회 결산\n태수 보너스 제외 · 건설/생산 작업량 %d%%" % [city_effect.remaining,int(campaign.Power.city_factor(model.state,row.city)*100)]
		for uid: String in row.units:
			var reason: String=campaign.Power.unit_reason(model.state,uid)
			if not reason.is_empty(): preview.text+="\n"+uid+" · "+reason
	if choice=="wait": preview.text+="\n기한 인계 시에는 아래 기존 반응 규칙을 적용하며 당시 후임 자격·상태를 다시 검사합니다."
	result.text="확정 시 최신 상태를 다시 검사합니다." if model.ok else str(model.result.get("reason","실행 불가")); UI.wire_focus.call_deferred(self)
func cancel_selection() -> void:
	choices.select(0); set_mode("issues"); result.text="선택 취소 · 인사·국고·관계 유지"
func execute() -> void:
	if apply_button.disabled: return
	if mode=="appointment": super.execute(); return
	var issue: Dictionary=issues.get_item_metadata(issues.selected); var choice: String=str(choices.get_item_metadata(choices.selected)); var outcome: Dictionary
	if issue.type=="power": outcome=campaign.Power.retarget(campaign,issue.id,str(successors.get_item_metadata(successors.selected))) if choice=="retarget" else campaign.Power.resolve(campaign,issue.id,choice)
	else: outcome=Personnel.resolve(campaign,issue.id,choice)
	campaign.update_top_bar(); refresh(); rebuild_issues(issue.id); result.text="실행 결과 · "+str(outcome.get("reason",outcome.get("result_text","처리되지 않았습니다."))).replace("compensate","보상").replace("force","강제 회수")
	if issue.type=="power":
		var current: Dictionary=campaign.Power.records(campaign.strategy_state).requests[issue.id]
		if current.status=="waiting": result.text="기한 보장 중 · 인계 예정 "+campaign.Power.date(int(current.due_month))
	campaign.evaluate_campaign_ending.call_deferred("court_response")
