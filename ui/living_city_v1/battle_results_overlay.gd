extends "res://battle_merit_overlay.gd"
const Style=preload("res://ui/living_city_v1/battle_style.gd")
const UI=Style.UI
var overview: VBoxContainer
var recovery: HBoxContainer
func _ready() -> void:
	var box:=Style.frame(self,"전투 결과 · 전후 병력과 공훈")
	battles=OptionButton.new(); box.add_child(battles); UI.City.button(battles); battles.item_selected.connect(func(_n): refresh())
	var columns:=HBoxContainer.new(); columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; columns.add_theme_constant_override("separation",18); box.add_child(columns)
	var left:=UI.section(columns,"승패 · 양군 원장"); overview=UI.scroll(left); summary=UI.label(overview,"",30)
	var right:=UI.section(columns,"참전 지휘관 · 선택 포상"); rows=UI.scroll(right)
	status=UI.label(right,"",21)
	recovery=HBoxContainer.new(); box.add_child(recovery)
	close_button=Style.button(box,"닫기 (Esc) · 결과는 다시 처리하지 않습니다",hide); hide()
func refresh() -> void:
	super.refresh()
	for child: Node in overview.get_children():
		if child!=summary: overview.remove_child(child); child.queue_free()
	Style.clear(recovery)
	var id: String=str(battles.get_item_metadata(battles.selected)) if battles.selected>=0 else ""
	var row: Dictionary=Merit.battle(campaign.strategy_state,id)
	if row.is_empty(): return
	var own_attack: bool=row.attacker_faction==campaign.player_faction_id
	summary.text="아군 %s · %s → %s" % ["승리" if bool(row.won)==own_attack else "패배",campaign.provinces[row.source].name,campaign.provinces[row.target].name]
	for side: String in ["attacker","defender"]:
		var oid: String=""
		for p: Dictionary in row.get("participants",[]):
			if p.side==side and p.battle_leader: oid=p.officer_id; break
		var faction: String=campaign.officer_registry.factions.get(row[side+"_faction"],row[side+"_faction"])
		Style.side(overview,campaign,faction,oid,"공격군" if side=="attacker" else "방어군")
		UI.label(overview,"전투 전 %d → 전투 직후 %d명\n손실 %d명 · 당시 실효 전투력 %.1f" % [row[side+"_troops"],int(row[side+"_troops"])-int(row[side+"_losses"]),row[side+"_losses"],row[side+"_power"]],26)
	UI.label(overview,"전투 당시 목표 소유권\n%s → %s\n현재 소유국 %s" % [campaign.officer_registry.factions.get(row.defender_faction,row.defender_faction),campaign.officer_registry.factions.get(row.attacker_faction if row.won else row.defender_faction,""),campaign.provinces[row.target].faction],23)
	UI.label(overview,"실제 계산 요소\n병종 전투력·병력, 일반 보병의 장비 충족·훈련, 양군 지휘관 통솔, 수비 성곽 %d가 반영됐습니다.\n현재 캠페인 자동 전투에는 숲·언덕 등 전술 지형과 별도 장수 특성이 적용되지 않습니다. 승률을 새로 계산하지 않습니다.\n병력·손실은 전투 원장 값입니다. 이후 이동·모집한 현재 병력과 구분합니다. 개인별 처치·손실 분배는 기록되지 않았습니다." % row.fortress,21)
	for b: Button in reward_buttons.values(): UI.City.button(b,false,true)
	for entry: Dictionary in row.get("participants",[]):
		if entry.faction_id==campaign.player_faction_id:
			var portrait:=UI.portrait(rows,UI.texture(campaign,entry.officer_id),Vector2(90,100)); rows.move_child(portrait,0)
	for city: String in [str(row.source),str(row.target)]:
		if campaign.Economy.resolve(campaign.strategy_state,campaign.provinces[city].faction)!=campaign.player_faction_id: continue
		var b:=Style.button(recovery,campaign.provinces[city].name+" · 보충",func(): hide(); campaign.select_province(city); campaign._on_recruit_button_pressed()); b.disabled=campaign.Ending.finished(campaign.strategy_state)
		b=Style.button(recovery,campaign.provinces[city].name+" · 장비·훈련",func(): hide(); campaign.open_army(city)); b.disabled=campaign.Ending.finished(campaign.strategy_state)
	UI.wire_focus.call_deferred(self); close_button.grab_focus()
