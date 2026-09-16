extends Control
const Core=preload("res://noble_politics.gd")
const Personnel=preload("res://noble_personnel.gd")
const Merit=preload("res://battle_merit.gd")
var history_people: OptionButton
var campaign: Node
var targets: OptionButton
var people: OptionButton
var details: Label
var preview: Label
var apply_button: Button
var close_button: Button
var result: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
	var panel:=PanelContainer.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.08,true); panel.set_anchor(SIDE_RIGHT,0.92,true); panel.set_anchor(SIDE_TOP,0.04,true); panel.set_anchor(SIDE_BOTTOM,0.96,true)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("231f18"); style.set_content_margin_all(16); panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new(); panel.add_child(box)
	result=Label.new(); result.text="귀족·군권·인사정치"; box.add_child(result)
	history_people=OptionButton.new(); box.add_child(history_people)
	history_people.item_selected.connect(func(_n): refresh())
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	details=Label.new(); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(details)
	targets=OptionButton.new(); box.add_child(targets); targets.item_selected.connect(func(_n): populate())
	people=OptionButton.new(); box.add_child(people); people.item_selected.connect(func(_n): forecast())
	preview=Label.new(); preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(preview)
	apply_button=Button.new(); apply_button.text="견적 확인 후 인사 실행"; box.add_child(apply_button); apply_button.pressed.connect(execute)
	close_button=Button.new(); close_button.text="닫기 (Esc)"; box.add_child(close_button); close_button.pressed.connect(hide)
	add_theme_font_size_override("font_size",20); hide()
func open(c: Node) -> void:
	campaign=c; targets.clear(); show()
	history_people.clear(); history_people.add_item("인물별 참전·포상 이력 선택"); history_people.set_item_metadata(0,"")
	for id: String in c.officer_registry.people:
		var person: Dictionary=c.officer_registry.people[id]
		var served: bool=c.strategy_state.get("army",{}).get("battles",[]).any(func(row): return Merit.participant(row,id).get("faction_id","")==c.player_faction_id)
		if (person.faction_id==c.player_faction_id and person.active) or served:
			history_people.add_item(person.name); history_people.set_item_metadata(history_people.item_count-1,id)
	for city: String in c.Economy.city_ids(c.strategy_state,c.provinces):
		if c.provinces[city].faction!=c.player_faction: continue
		targets.add_item(c.provinces[city].name+" 태수"); targets.set_item_metadata(targets.item_count-1,{"kind":"governor","target":city,"city":city})
		var n: int=0
		for id: String in c.Army.at_city(c.strategy_state,city,c.player_faction_id):
			n+=1; targets.add_item("%s 부대%d · %d명" % [c.provinces[city].name,n,c.strategy_state.unit_rosters[id].troops]); targets.set_item_metadata(targets.item_count-1,{"kind":"commander","target":id,"city":city})
	populate()
func populate() -> void:
	people.clear()
	if targets.selected<0: refresh(); return
	var t: Dictionary=targets.get_item_metadata(targets.selected)
	for id: String in campaign.get_city_officer_ids(t.city):
		var p: Dictionary=campaign.get_officer(id)
		people.add_item(p.name); people.set_item_metadata(people.item_count-1,id)
	refresh(); forecast()
func refresh() -> void:
	var r: Dictionary=campaign.officer_registry
	if not r.has("politics") or r.politics.faction_id!=campaign.player_faction_id:
		details.text="이 국가·시나리오에는 정치집단 초기 설정을 아직 적용하지 않았습니다. 기존 인사 기능은 유지됩니다."; return
	var power: Dictionary=Core.influence(campaign.strategy_state,campaign.provinces,campaign.player_faction_id)
	var lines: Array[String]=["집단은 게임용 정치 연합이며 역사적으로 확정된 파벌·가문 소속을 뜻하지 않습니다. 미배정 기반은 왕실 직할로 계산하지 않습니다."]
	for gid: String in r.politics.groups:
		var g: Dictionary=r.politics.groups[gid]; var row: Dictionary=power.groups[gid]; var members: Array[String]=[]; var cities: Array[String]=[]
		for id: String in g.members:
			var p: Dictionary=campaign.get_officer(id); members.append("%s (충성%d·야망%d)" % [p.name,p.get("loyalty",50),p.get("ambition",50)])
		for city: String in row.cities: cities.append(campaign.provinces[city].name)
		for uid: String in row.units:
			var unit: Dictionary=campaign.strategy_state.unit_rosters[uid]
			lines.append("지휘 기반 · %s · %s · %d명%s" % [campaign.get_officer(unit.commander_id).name,campaign.provinces.get(unit.location,{}).get("name","이동 중"),unit.troops," (이동 중)" if unit.status=="transit" else ""])
		lines.append("\n%s · 대표 %s · 영향력 %.2f · 협력 %d\n%s\n군권 %d/%d명 · 태수 민간 기반 %d/%d명 · 도시 %s\n지휘 부대 %d개 · %s" % [g.name,campaign.get_officer(g.representative).name,row.influence,g.cooperation," / ".join(members),row.troops,power.troops,row.population,power.population,"·".join(cities),row.units.size(),"직접 맡긴 인물을 통한 왕실 기반" if g.royal else "협력이 높으면 강한 귀족 기반도 국정과 생산에 도움이 됩니다."])
	lines.append("\n미배정: 병력%d / 민간%d · 무소속 인물: 병력%d / 민간%d" % [power.unassigned.troops,power.unassigned.population,power.unaffiliated.troops,power.unaffiliated.population])
	for n: int in range(maxi(0,r.politics.history.size()-4),r.politics.history.size()):
		var h: Dictionary=r.politics.history[n]; lines.append("%s · %s · 충성%d→%d / 협력%d→%d" % [campaign.get_officer(h.officer_id).name,h.reason,h.loyalty_before,h.loyalty_after,h.cooperation_before,h.cooperation_after])
	lines.append(campaign.Power.summary(campaign.strategy_state))
	if history_people.selected>0:
		var id: String=str(history_people.get_item_metadata(history_people.selected))
		lines.push_front("참전·포상 이력 · "+campaign.get_officer(id).name+"\n"+Merit.history(campaign.strategy_state,id,campaign.provinces)+"\n")
	details.text="\n".join(lines)
func forecast() -> void:
	apply_button.disabled=true
	if people.selected<0 or targets.selected<0: preview.text="현지 임명 가능한 인물이 없습니다."; return
	var t: Dictionary=targets.get_item_metadata(targets.selected); var id: String=str(people.get_item_metadata(people.selected))
	var q: Dictionary=Personnel.quote(campaign,campaign.player_faction_id,t.kind,t.target,id)
	preview.text=q.reason
	if not q.ok: return
	apply_button.disabled=false
	var transfer: Dictionary=campaign.Power.quote(campaign,{"kind":t.kind,"target":t.target,"officer_id":id,"faction_id":campaign.player_faction_id})
	if transfer.get("required",false): preview.text=campaign.Power.describe(campaign,transfer); return
	var old: String=campaign.get_officer(q.previous_id).get("name","공석")
	preview.text="%s → %s · %s %d → %d" % [old,campaign.get_officer(id).name,"정치" if t.kind=="governor" else "통솔",q.old_ability,q.ability]
	for h: Dictionary in q.reactions:
		preview.text+="\n%s 충성%d→%d · 협력%d→%d" % [campaign.get_officer(h.officer_id).name,h.loyalty_before,h.loyalty_after,h.cooperation_before,h.cooperation_after]
	if q.reactions.is_empty(): preview.text+="\n정치 반응 없음 · 보상 간격 또는 실질 권한 증가 조건 적용"
	for gid: String in q.before.groups:
		preview.text+=" · %s %.1f→%.1f" % [campaign.officer_registry.politics.groups[gid].name,q.before.groups[gid].influence,q.after.groups[gid].influence]
func execute() -> void:
	if targets.selected<0 or people.selected<0: return
	var t: Dictionary=targets.get_item_metadata(targets.selected)
	var q: Dictionary=Personnel.appoint(campaign,campaign.player_faction_id,t.kind,t.target,str(people.get_item_metadata(people.selected)))
	result.text=q.reason; campaign.update_top_bar(); refresh(); forecast()
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): hide(); get_viewport().set_input_as_handled()
