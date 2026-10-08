extends Control
const Merit=preload("res://battle_merit.gd")
var campaign: Node
var battles: OptionButton
var summary: Label
var rows: VBoxContainer
var status: Label
var close_button: Button
var reward_buttons: Dictionary={}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var panel:=PanelContainer.new(); add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.08,true); panel.set_anchor(SIDE_RIGHT,0.92,true)
	panel.set_anchor(SIDE_TOP,0.06,true); panel.set_anchor(SIDE_BOTTOM,0.94,true)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("231f18"); style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new(); panel.add_child(box)
	var title:=Label.new(); title.text="전투 결과 · 공훈과 선택 포상"; box.add_child(title)
	battles=OptionButton.new(); box.add_child(battles); battles.item_selected.connect(func(_n): refresh())
	summary=Label.new(); summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(summary)
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	rows=VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(rows)
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(status)
	close_button=Button.new(); close_button.text="닫기 (Esc) · 미포상 유지"; close_button.pressed.connect(hide); box.add_child(close_button)
	add_theme_font_size_override("font_size",20); hide()

func open(c: Node, battle_id: String="") -> void:
	campaign=c; battles.clear(); status.text="자동 포상은 없습니다. 전투·인물별 한 번만 선택할 수 있습니다."
	var records: Array=c.strategy_state.get("army",{}).get("battles",[])
	for n: int in range(records.size()-1,-1,-1):
		var row: Dictionary=records[n]
		if row.get("attacker_faction","")!=c.player_faction_id and row.get("defender_faction","")!=c.player_faction_id: continue
		var id: String=str(row.get("battle_id",""))
		battles.add_item("%d년 %d월 · %s → %s" % [int((int(row.month)-1)/12.0),(int(row.month)-1)%12+1,c.provinces[row.source].name,c.provinces[row.target].name])
		battles.set_item_metadata(battles.item_count-1,id)
		if id==battle_id: battles.select(battles.item_count-1)
	show(); refresh()

func refresh() -> void:
	for child: Node in rows.get_children(): rows.remove_child(child); child.queue_free()
	reward_buttons.clear()
	var id: String=str(battles.get_item_metadata(battles.selected)) if battles.selected>=0 else ""
	var row: Dictionary=Merit.battle(campaign.strategy_state,id)
	if row.is_empty(): summary.text="선택할 전투 기록이 없습니다. 과거 전투의 포상 자격은 소급 생성하지 않습니다."; return
	summary.text="공격군 %s · 방어군 %s · 전체 손실 %d / %d\n개인별 처치·피해량은 기록되지 않아 표시하지 않습니다." % ["승리" if row.won else "패배","패배" if row.won else "승리",row.attacker_losses,row.defender_losses]
	if row.defender_faction==campaign.player_faction_id: summary.text="아군 방어 "+("패배" if row.won else "승리")+"\n"+summary.text
	for entry: Dictionary in row.get("participants",[]):
		if entry.faction_id!=campaign.player_faction_id: continue
		var q: Dictionary=Merit.quote(campaign,id,entry.officer_id)
		var label:=Label.new(); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.text="%s · 당시 소속 %s · %s%s\n참전 부대: %s\n%s" % [entry.name,campaign.officer_registry.factions.get(entry.faction_id,entry.faction_id),"승리" if entry.won else "패배"," · 전투 지휘" if entry.battle_leader else " · 부대 지휘",Merit.unit_text(row,entry.unit_ids),q.reason]
		if q.ok: label.text+="\n충성 %d→%d · %s" % [q.loyalty_before,q.loyalty_after,"협력 %d→%d" % [q.cooperation_before,q.cooperation_after] if q.has_group else "무소속: 집단 효과 없음"]
		rows.add_child(label)
		var button:=Button.new(); button.text="포상 완료" if row.rewards.has(entry.officer_id) else "금100으로 포상"; button.disabled=not q.ok
		button.pressed.connect(func():
			var result: Dictionary=Merit.reward(campaign,id,entry.officer_id)
			status.text=result.reason; campaign.update_top_bar(); refresh())
		rows.add_child(button); reward_buttons[entry.officer_id]=button
	if rows.get_child_count()==0:
		var empty:=Label.new(); empty.text="기록된 아군 참전 지휘관이 없습니다."; rows.add_child(empty)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide(); get_viewport().set_input_as_handled()
