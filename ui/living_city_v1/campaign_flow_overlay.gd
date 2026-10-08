extends Control
const UI=preload("res://ui/living_city_v1/military_style.gd")
const Report=preload("res://ui/living_city_v1/campaign_flow_report.gd")
var campaign: Node
var title: Label
var body: VBoxContainer
var history: OptionButton
var close_button: Button
var routes: Dictionary={}

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_STOP; theme=UI.City.make_theme()
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.75); shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(shade)
	var panel:=PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.04,true); panel.set_anchor(SIDE_RIGHT,0.96,true); panel.set_anchor(SIDE_TOP,0.04,true); panel.set_anchor(SIDE_BOTTOM,0.96,true)
	var style:=UI.City.panel(); style.set_content_margin_all(24); panel.add_theme_stylebox_override("panel",style); UI.Industry.frame(panel)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",12); panel.add_child(box)
	var top:=HBoxContainer.new(); box.add_child(top); title=UI.Industry.heading(); title.add_theme_color_override("font_color",UI.City.INK); top.add_child(title)
	close_button=Button.new(); close_button.text="닫기 (Esc)"; UI.City.button(close_button); top.add_child(close_button); close_button.pressed.connect(close)
	history=OptionButton.new(); box.add_child(history); history.item_selected.connect(func(_n): render())
	var links:=GridContainer.new(); links.columns=4; box.add_child(links)
	for pair: Array in [["내정·인사","domestic"],["생산·수송","production"],["편성·장비·훈련","army"],["건설·연구","research"],["조정·요구","court"],["외교·통상","diplomacy"],["병력 보충·모집","recruit"]]:
		var key: String=pair[1]; var b:=Button.new(); b.text=pair[0]; b.size_flags_horizontal=SIZE_EXPAND_FILL; UI.City.button(b); links.add_child(b); routes[key]=b; b.pressed.connect(func(): navigate(key))
	body=UI.scroll(box); hide()

func open(c: Node) -> void:
	campaign=c; title.text="월 보고 · 다음 행동"; history.clear(); history.add_item("현재 업무와 접근 경로")
	var reports: Array=c.strategy_state.get("ui_month_reports",[])
	for n: int in range(reports.size()-1,-1,-1):
		var row: Dictionary=reports[n]; history.add_item("%d년 %d월 · 실제 월 처리 보고" % [row.year,row.month]); history.set_item_metadata(history.item_count-1,n)
	if not reports.is_empty(): history.select(1)
	show(); render(); close_button.grab_focus()

func render() -> void:
	for child: Node in body.get_children(): body.remove_child(child); child.queue_free()
	var city: Dictionary=campaign.provinces.get(campaign.selected_province_id,{})
	var owned: bool=city.get("faction","")==campaign.player_faction
	for key: String in routes: routes[key].disabled=not owned and key not in ["court","diplomacy"]
	UI.label(body,"현재 선택 도시: %s · 국가 금 %d\n도시 업무는 내 소유 도시에서 진행합니다. 아래 경로는 화면만 열며 명령을 접수하지 않습니다." % [city.get("name","미선택"),campaign.gold],21)
	if history.selected>0:
		var report: Dictionary=campaign.strategy_state.ui_month_reports[int(history.get_item_metadata(history.selected))]
		var treasury:=UI.section(body,"국고 변화 · 월 처리 전후")
		UI.label(treasury,"금 %d → %d  (%+d)" % [report.gold_before,report.gold_after,int(report.gold_after)-int(report.gold_before)],30)
		UI.label(treasury,"월 정산에서 실제 반영된 합계입니다. 이후 선택한 대응 비용은 해당 대응 화면에서 확인하세요.",20)
		var changes:=UI.section(body,"업무 상태 변화")
		UI.label(changes,"상태 변화 없음" if report.transitions.is_empty() else "\n\n".join(report.transitions))
		var full:=UI.section(body,"경제·업무 전체 내역 · 기존 월 보고")
		UI.label(full,"처리 내역 없음" if report.messages.is_empty() else "\n\n".join(report.messages),21)
	else:
		var guide:=UI.section(body,"접수 전 확인 순서")
		UI.label(guide,"내정·인사: 도시 → 담당자 카드 → 견적 → 개발 지시\n생산·수송: 현지 창고 → 품목의 필요 기술·시설 → 담당자 → 생산 예약 / 수송 화물 확정\n편성·장비·훈련: 잔존 부대 → 보충·장비 확보 → 지급 미리보기 → 담당자·훈련 견적\n조정·외교: 대상 → 현안·행동 → 실제 비용과 제약 → 확정",22)
		if campaign.strategy_state.get("ui_month_reports",[]).is_empty(): UI.label(guide,"저장된 월 보고가 없습니다. 다음 월 진행부터 최근 12개월의 실제 내역을 보관합니다. 이전 저장의 과거 결과는 복원해 만들지 않습니다.",20)
	var current:=UI.section(body,"현재 진행 중 · 다음 달 전에 확인")
	var jobs: Array[String]=Report.jobs(campaign); UI.label(current,"진행 중인 담당 업무 없음" if jobs.is_empty() else "\n\n".join(jobs),21)
	UI.label(current,"생산 보류·도착 예정은 ‘생산·수송’, 출정 준비는 ‘편성·장비·훈련’에서 현재 선택 도시 기준으로 확인하세요.",20)
	var pending: Dictionary=campaign.officer_registry.get("politics",{}).get("pending",{})
	UI.label(current,"미응답 정치 요구 있음 · 조정에서 대상·기한·대응을 확인해야 월 진행할 수 있습니다." if pending.get("faction_id","")==campaign.player_faction_id else "현재 미응답 정치 요구 없음",21)
	var restrictions: String=campaign.Power.summary(campaign.strategy_state,campaign.selected_province_id)
	for unit: Dictionary in campaign.strategy_state.get("unit_rosters",{}).values():
		if unit.get("location","")!=campaign.selected_province_id or unit.get("faction_id","")!=campaign.player_faction_id: continue
		var reason: String=campaign.Power.unit_reason(campaign.strategy_state,str(unit.id))
		if not reason.is_empty(): restrictions+="\n"+str(unit.id)+" · "+reason
	if not restrictions.strip_edges().is_empty(): UI.label(current,restrictions.strip_edges(),21)
	body.get_parent().scroll_vertical=0; UI.wire_focus.call_deferred(self)

func navigate(key: String) -> void:
	hide()
	if key=="court": campaign.open_politics()
	elif key=="diplomacy": campaign._open_diplomacy()
	elif key=="recruit": campaign._on_recruit_button_pressed()
	else: campaign.settlement_overlay.action(key)

func close() -> void:
	hide()
	if campaign.settlement_overlay.visible: campaign.settlement_overlay.buttons.report.grab_focus()
