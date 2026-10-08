extends "res://diplomacy_overlay.gd"
const UI=preload("res://ui/living_city_v1/military_style.gd")
const Preview=preload("res://ui/living_city_v1/diplomacy_preview.gd")
const Flag=preload("res://ui/living_city_v1/faction_flag.gd")
const Colors=preload("res://world_map_data.gd")
const NAMES={"gift":"친선 사절","trade_pact":"통상협의","cancel_trade_pact":"협정 해지"}
var selected_action: String="gift"
var target_list: VBoxContainer
var candidate_list: VBoxContainer
var candidate_buttons: Dictionary={}
var target_buttons: Dictionary={}
var ruler: TextureRect
var ruler_text: Label
var cost: Label
var settlement_summary: Label
var confirmation_text: Label
var effect: Label
var trade_info: Label
var blocked: Label
var execute_button: Button
var cancel_button: Button
var close_button: Button
var model: Dictionary={}

func button(parent: Node,text: String,callback: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(b); UI.City.button(b); b.pressed.connect(callback); return b
func column(parent: Node,ratio: float) -> VBoxContainer:
	var box:=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.size_flags_stretch_ratio=ratio; parent.add_child(box); return box
func clear_box(box: Node) -> void:
	for child: Node in box.get_children(): box.remove_child(child); child.queue_free()
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP; theme=UI.City.make_theme()
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.8); add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame:=PanelContainer.new(); add_child(frame); frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); frame.set_anchor(SIDE_LEFT,0.035,true); frame.set_anchor(SIDE_RIGHT,0.965,true); frame.set_anchor(SIDE_TOP,0.03,true); frame.set_anchor(SIDE_BOTTOM,0.97,true)
	var style:=UI.City.panel(true); style.set_content_margin_all(24); frame.add_theme_stylebox_override("panel",style); UI.Industry.frame(frame)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",14); frame.add_child(box)
	header=UI.Industry.heading(); box.add_child(header)
	var columns:=HBoxContainer.new(); columns.add_theme_constant_override("separation",16); columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(columns)
	var left:=column(columns,0.25); var middle:=column(columns,0.38); var right:=column(columns,0.37)
	var country:=UI.section(left,"1 · 상대국"); var row:=HBoxContainer.new(); country.add_child(row); ruler=UI.portrait(row,null,Vector2(96,112)); ruler_text=UI.label(row,"",24); details=UI.label(country,"",20); target_list=UI.scroll(left)
	var action:=UI.section(middle,"2 · 행동 선택")
	for id: String in NAMES:
		action_buttons[id]=button(action,NAMES[id],func(): selected_action=id; refresh()); action_labels[id]=UI.label(action,"",18)
	var candidates:=UI.section(middle,"3 · 사절 선택"); candidates.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL; candidate_list=UI.scroll(candidates)
	var condition:=UI.section(right,"4 · 조건 확인"); condition.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	var scroll:=UI.scroll(condition); cost=UI.label(scroll,"",32); settlement_summary=UI.label(scroll,"",24); effect=UI.label(scroll,"",24); trade_info=UI.label(scroll,"",21)
	result_label=UI.label(condition,"",20); blocked=UI.label(condition,"",20); blocked.add_theme_color_override("font_color",UI.City.RED)
	execute_button=button(condition,"5 · 검토한 조건으로 실행",func(): _act(selected_action)); UI.City.button(execute_button,false,true)
	cancel_button=button(condition,"선택 취소 · 상태 유지",func(): selected_action="gift"; pending_cancel.clear(); confirmation.hide(); result_label.text="선택 취소 · 국고·관계·업무 유지"; refresh())
	close_button=button(box,"닫기 (Esc)",func(): closed.emit())
	# Retain existing selectors/API for regression and campaign integrations.
	targets=ItemList.new(); add_child(targets); targets.hide(); targets.item_selected.connect(_select_target)
	envoys=OptionButton.new(); add_child(envoys); envoys.hide(); envoys.item_selected.connect(_select_envoy)
	confirmation=ConfirmationDialog.new(); confirmation.title="외교 실행 확인"; confirmation.ok_button_text="외교 행동 확정"; confirmation.cancel_button_text="취소"; add_child(confirmation)
	confirmation.add_theme_constant_override("buttons_min_width",260)
	confirmation.add_theme_constant_override("buttons_min_height",64)
	confirmation.theme=theme; confirmation.add_theme_stylebox_override("panel",UI.City.panel())
	confirmation.get_label().hide()
	var confirm_body:=UI.scroll(confirmation); confirm_body.get_parent().custom_minimum_size=Vector2(650,260); confirmation_text=UI.label(confirm_body,"",22)
	confirmation.confirmed.connect(_confirm_cancel); confirmation.canceled.connect(func(): pending_cancel.clear()); confirmation.add_theme_font_size_override("font_size",22)
	UI.City.button(confirmation.get_ok_button(),false,true); UI.City.button(confirmation.get_cancel_button())
	confirmation.get_ok_button().custom_minimum_size=Vector2(240,64)
	confirmation.get_cancel_button().custom_minimum_size=Vector2(160,64); hide()
func open_for_campaign(host: Node) -> void:
	campaign=host; pending_cancel.clear(); confirmation.hide(); result_label.text="선택은 조회입니다. 마지막 확인 후에만 실행합니다."; show(); refresh(); close_button.grab_focus()
func refresh() -> void:
	header.text="외교 · 통상 | %s · %d년 %d월 · 국가 금 %d" % [campaign.player_faction,campaign.year,campaign.month,campaign.gold]
	targets.clear(); clear_box(target_list); target_buttons.clear()
	for f: Dictionary in campaign.get_diplomacy_factions():
		if f.id==campaign.player_faction_id: continue
		var n: int=targets.add_item(f.name); targets.set_item_metadata(n,f.id)
	if not range(targets.item_count).any(func(n): return targets.get_item_metadata(n)==selected_target_id): selected_target_id=str(targets.get_item_metadata(0)) if targets.item_count>0 else ""
	for n: int in range(targets.item_count):
		var id: String=targets.get_item_metadata(n); var row:=HBoxContainer.new(); target_list.add_child(row)
		var flag:=Flag.new(); flag.color=Colors.FACTION_COLORS.get(targets.get_item_text(n),Color("777777")); row.add_child(flag)
		var b:=button(row,("선택 · " if id==selected_target_id else "")+targets.get_item_text(n),func(): selected_target_id=id; refresh(); target_buttons[id].grab_focus())
		b.tooltip_text="지도 세력색의 게임용 깃발"; UI.City.button(b,id==selected_target_id); target_buttons[id]=b
		if id==selected_target_id: targets.select(n)
	envoys.clear(); clear_box(candidate_list); candidate_buttons.clear()
	var candidates: Array=campaign.get_diplomacy_envoy_candidates()
	if not candidates.any(func(p): return p.officer_id==selected_envoy_name):
		selected_envoy_name=""
		for p: Dictionary in candidates:
			if p.available: selected_envoy_name=p.officer_id; break
		if selected_envoy_name.is_empty() and not candidates.is_empty(): selected_envoy_name=candidates[0].officer_id
	for p: Dictionary in candidates:
		var id: String=p.officer_id; envoys.add_item(p.name); envoys.set_item_metadata(envoys.item_count-1,id)
		if id==selected_envoy_name: envoys.select(envoys.item_count-1)
		var duty: Array[String]=[]
		for d: Dictionary in p.get("duties",[]):
			var kind: String=str(d.get("kind",""))
			if kind=="industry": kind=str(campaign.strategy_state.domestic.jobs.get(str(d.get("job_id","")),{}).get("kind",kind))
			duty.append(str({"domestic":"내정","training":"훈련","production":"생산","build":"건설","research":"연구","industry":"산업"}.get(kind,kind)))
		var info: String="통상 능력 · 정치 %d · 지력 %d · 권위 %d\n업무 · %s" % [p.get("politics",50),p.get("intelligence",50),p.get("authority",50)," · ".join(duty) if not duty.is_empty() else "배정 없음"]
		var b:=UI.card(candidate_list,campaign,id,id==selected_envoy_name,info,"사절 선택 가능" if p.available else p.reason,func(): selected_envoy_name=id; refresh(); candidate_buttons[id].grab_focus())
		b.disabled=not p.available; candidate_buttons[id]=b
	if candidates.is_empty(): UI.label(candidate_list,"현재 소속 사절 후보가 없습니다.")
	_update_details(); UI.wire_focus.call_deferred(self)
func _select_target(index: int) -> void: selected_target_id=str(targets.get_item_metadata(index)); refresh()
func _select_envoy(index: int) -> void: selected_envoy_name=str(envoys.get_item_metadata(index)); refresh()
func _update_details() -> void:
	var target: String=campaign.ScenarioData.get_faction_name(campaign.scenario_id,selected_target_id)
	var king: String=str(campaign.officer_registry.posts.get("ruler:"+selected_target_id,"")); ruler.texture=UI.texture(campaign,king); ruler_text.text=target+"\n"+str(campaign.get_officer(king).get("name","군주 기록 없음"))
	var relation: Dictionary=campaign.strategy.get_relation(campaign.strategy_state,campaign.player_faction,target)
	details.text="관계 %d · %s\n%s" % [relation.value,relation.status," · ".join(relation.treaties).replace("통상 조약","통상협정 체결") if not relation.treaties.is_empty() else "현재 협정 없음"]
	for id: String in action_buttons:
		var q: Dictionary=campaign.get_diplomatic_action_quote(selected_target_id,id,selected_envoy_name)
		action_buttons[id].disabled=not q.ok; action_buttons[id].tooltip_text=q.reason; UI.City.button(action_buttons[id],id==selected_action)
		action_labels[id].text="금 %d · %s" % [q.gold_cost,"선택 가능" if q.ok else q.reason]
	model=Preview.inspect(campaign,selected_target_id,selected_action,selected_envoy_name)
	var q: Dictionary=model.quote; var performed: bool=model.result.get("executed",false)
	execute_button.disabled=not q.ok; blocked.text=q.reason
	cost.text="즉시 필요 금 %d\n국고 %d → %s" % [q.gold_cost,campaign.gold,str(campaign.gold-int(q.gold_cost)) if performed else "실행 불가"]
	settlement_summary.text="다음 계절 정산 참고 금 %d → %d\n조건부 · 매월 고정 지급 없음" % [model.trade_before.income,model.trade_after.income]
	effect.text="%s · 사절 %s\n기존 견적 성공률 %d%%\n" % [NAMES[selected_action],campaign.get_officer(selected_envoy_name).get("name","미선택"),q.chance]
	if performed: effect.text+="현재 조건의 판정 예상\n"+str(model.result.get("message",model.result.get("reason","")))+"\n관계 %d → %d\n조약 · %s" % [model.before.value,model.after.value," · ".join(model.after.treaties).replace("통상 조약","통상협정") if not model.after.treaties.is_empty() else "없음"]
	effect.text+="\n성공·결렬 모두 이번 달 외교 행동 사용. 확정 때 실제 자격·조건을 재검사합니다."
	trade_info.text="통상 정산 · 즉시 지급과 별도\n매월 고정 수입 없음. 기존 교역로는 계절 전환월(1·4·7·10월)에 정산합니다.\n이 상대와 등록된 교역로 %d개\n현재 조건의 다음 정산 참고 금 %d → %d\n협정·비전쟁·경로 활성 상태와 당시 도시·시장·위험도에 따라 달라지며 확정 수입이 아닙니다.\n협정만으로 교역로가 생기지 않습니다. 교역로 개설 UI는 아직 연결되지 않았습니다." % [model.trade_before.routes,model.trade_before.income,model.trade_after.income]
func _act(id: String) -> void:
	selected_action=id; _update_details()
	if not model.quote.ok: result_label.text=model.quote.reason; return
	pending_cancel={"target":selected_target_id,"envoy":selected_envoy_name,"action":id}
	confirmation_text.text=cost.text+"\n\n"+settlement_summary.text+"\n\n"+effect.text+"\n\n취소하면 게임 상태를 변경하지 않습니다."
	confirmation.popup_centered(Vector2i(780,420))
func _confirm_cancel() -> void:
	var pending: Dictionary=pending_cancel.duplicate(); pending_cancel.clear()
	if visible and not pending.is_empty(): _execute(pending.target,pending.action,pending.envoy)
