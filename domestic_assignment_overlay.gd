extends Control

var campaign: Node
var city: String
var kind: String
var selector: OptionButton
var details: Label
var status: Label
var execute_button: Button
var cancel_button: Button
var close_button: Button
var dismiss_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.78); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var center:=CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(center)
	var panel:=PanelContainer.new(); panel.custom_minimum_size=Vector2(850,610); center.add_child(panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.10,0.09,0.07,0.98); style.border_color=Color(0.63,0.51,0.27)
	style.set_border_width_all(1); panel.add_theme_stylebox_override("panel",style)
	panel.add_theme_font_size_override("font_size",22)
	var margin:=MarginContainer.new(); panel.add_child(margin)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",12); margin.add_child(box)
	status=Label.new(); box.add_child(status)
	selector=OptionButton.new(); box.add_child(selector); selector.item_selected.connect(func(_n): refresh_quote())
	details=Label.new(); details.custom_minimum_size=Vector2(790,340); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(details)
	execute_button=Button.new(); execute_button.text="개발 업무 시작 · 금 100"; box.add_child(execute_button); execute_button.pressed.connect(_execute)
	cancel_button=Button.new(); cancel_button.text="업무 취소 · 금 100 환불"; box.add_child(cancel_button); cancel_button.pressed.connect(_cancel)
	dismiss_button=Button.new(); dismiss_button.text="태수 해임"; box.add_child(dismiss_button); dismiss_button.pressed.connect(func(): campaign.dismiss_governor(city); refresh())
	close_button=Button.new(); close_button.text="닫기 (Esc)"; box.add_child(close_button); close_button.pressed.connect(hide)
	for control: Control in [status,selector,details,execute_button,cancel_button,dismiss_button,close_button]: control.add_theme_font_size_override("font_size",22)
	hide()

func open(c: Node, city_id: String, task_kind: String) -> void:
	campaign=c; city=city_id; kind=task_kind
	refresh(); show()

func selected_id() -> String:
	return str(selector.get_item_metadata(selector.selected)) if selector.selected>=0 else ""

func refresh() -> void:
	var previous: String=selected_id()
	var active: Dictionary=campaign.Domestic.active_job(campaign.strategy_state,city)
	if not active.is_empty(): previous=active.officer_id
	selector.clear()
	for id: String in campaign.get_city_officer_ids(city):
		var p: Dictionary=campaign.get_officer(id)
		selector.add_item("%s · 정치 %d / 지력 %d" % [p.name,p.politics,p.intelligence])
		selector.set_item_metadata(selector.item_count-1,id)
		if id==previous: selector.select(selector.item_count-1)
	refresh_quote()

func refresh_quote() -> void:
	var q: Dictionary=campaign.get_domestic_quote(city,kind,selected_id())
	var active: Dictionary=campaign.Domestic.active_job(campaign.strategy_state,city)
	status.text="%s · %s 개발 · 금 %d" % [campaign.provinces[city].name,"농업" if kind=="agriculture" else "상업",campaign.gold]
	var due: int=int(active.get("due_month",q.due_month))
	var gain: int=int(active.get("planned_gain",q.gain))
	selector.disabled=not active.is_empty()
	details.text="비용: 금 %d · 기간: 월 진행 1회\n예정 성과: +%d (상한 100) · 완료: %d년 %d월\n%s" % [q.cost,gain,int((due-1)/12.0),(due-1)%12+1,"실행 가능" if q.ok else q.reason]
	if not active.is_empty():
		details.text+="\n진행 중: %s +%d · 담당: %s\n정치 %d / 지력 %d · 금 %d 지불 완료\n업무 중 이동·사절·공격 출정 불가 (방어 가능)" % ["농업" if active.kind=="agriculture" else "상업",active.planned_gain,campaign.get_officer(active.officer_id).get("name",active.officer_id),active.politics,active.intelligence,active.cost_paid]
	else:
		var latest: Dictionary={}
		for job: Dictionary in campaign.Domestic.ensure(campaign.strategy_state).jobs.values():
			if job.city_id==city and job.kind in ["agriculture","commerce"]: latest=job
		if not latest.is_empty(): details.text+="\n최근 기록: %s" % latest.reason
	details.text+="\n\n"+campaign.get_city_operation_text(city)
	execute_button.disabled=not q.ok
	cancel_button.disabled=active.is_empty()
	dismiss_button.disabled=campaign.get_governor_id(city).is_empty()

func _execute() -> void:
	var result: Dictionary=campaign.start_domestic(city,kind,selected_id())
	refresh(); status.text+=" · "+("접수 완료" if result.ok else str(result.reason))

func _cancel() -> void:
	var job: Dictionary=campaign.Domestic.active_job(campaign.strategy_state,city)
	if not job.is_empty(): campaign.cancel_domestic(job.id)
	refresh()
