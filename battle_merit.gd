extends RefCounted

const Economy=preload("res://faction_economy.gd")
const Politics=preload("res://noble_politics.gd")
const Ending=preload("res://campaign_ending.gd")
const SCENARIOS=["silla_equilibrium_632","goguryeo_coup_642"]

# Called only for a newly resolved battle. Never reconstruct entitlements on load.
static func record(state: Dictionary, result: Dictionary, leaders: Array) -> void:
	result["battle_id"]="battle:"+Crypto.new().generate_random_bytes(16).hex_encode()
	result["merit_version"]=1
	result["participants"]=[]
	result["rewards"]={}
	var registry: Dictionary=state.officer_registry
	result["reward_enabled"]=registry.get("scenario_id","") in SCENARIOS and registry.has("politics")
	for side: int in range(2):
		var snapshots: Array=result.attacker_state if side==0 else result.defender_state
		var faction: String=result.attacker_faction if side==0 else result.defender_faction
		var city: String=result.source if side==0 else result.target
		var entries: Dictionary={}
		for unit: Dictionary in snapshots:
			var ids: Array=[str(unit.get("commander_id","")),str(leaders[side])]
			for index: int in range(ids.size()):
				var id: String=ids[index]
				var person: Dictionary=registry.people.get(id,{})
				if person.is_empty() or not person.active or not person.alive or person.in_transit or person.faction_id!=faction or person.location!=city: continue
				if not entries.has(id):
					entries[id]={"officer_id":id,"name":person.name,"faction_id":faction,"group_id":person.get("political_group_id",""),"side":"attacker" if side==0 else "defender","won":bool(result.won) if side==0 else not bool(result.won),"unit_ids":[],"commanded_units":[],"battle_leader":false}
				var entry: Dictionary=entries[id]
				if not entry.unit_ids.has(unit.id): entry.unit_ids.append(unit.id)
				if index==0 and not entry.commanded_units.has(unit.id): entry.commanded_units.append(unit.id)
				if index==1: entry.battle_leader=true
		result.participants.append_array(entries.values())

static func battle(state: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in state.get("army",{}).get("battles",[]):
		if not id.is_empty() and row.get("battle_id","")==id: return row
	return {}

static func participant(row: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in row.get("participants",[]):
		if entry.officer_id==id: return entry
	return {}

static func quote(c: Node, battle_id: String, officer_id: String) -> Dictionary:
	var row: Dictionary=battle(c.strategy_state,battle_id)
	if Ending.finished(c.strategy_state): return {"ok":false,"reason":Ending.BLOCKED}
	if c.player_faction_id!="silla" or c.scenario_id not in SCENARIOS or not c.officer_registry.has("politics"):
		return {"ok":false,"reason":"632·642년 신라 정치 캠페인에서 포상할 수 있습니다."}
	if row.get("merit_version",0)!=1 or not row.get("reward_enabled",false): return {"ok":false,"reason":"포상 대상 기록이 없는 과거 전투입니다."}
	if row.rewards.has(officer_id): return {"ok":false,"reason":"포상 완료 · 이 전투에서 다시 지급할 수 없습니다."}
	var entry: Dictionary=participant(row,officer_id)
	if entry.is_empty() or not entry.won or entry.faction_id!=c.player_faction_id: return {"ok":false,"reason":"승리한 아군 참전 지휘관만 포상할 수 있습니다."}
	var person: Dictionary=c.officer_registry.people.get(officer_id,{})
	if person.is_empty() or not person.get("alive",false) or not person.get("active",false) or person.get("faction_id","")!=c.player_faction_id:
		return {"ok":false,"reason":"현재 생존·활동 중인 아군 지휘관이 아닙니다."}
	var cost: int=int(Politics.RULES.gift_cost)
	var paid: Dictionary=Economy.validate_national(c.strategy_state,c.player_faction_id,c.player_faction_id,cost)
	if not paid.ok: return {"ok":false,"reason":"국고 금%d가 부족합니다." % cost}
	var gid: String=Politics.group(c.officer_registry,officer_id)
	var group: Dictionary=c.officer_registry.politics.groups.get(gid,{})
	var loyalty: int=int(person.get("loyalty",50)); var cooperation: int=int(group.get("cooperation",50))
	return {"ok":true,"reason":"금%d · 충성 +%d · 집단 협력 +%d (상한100)" % [cost,Politics.RULES.gift_loyalty,Politics.RULES.gift_cooperation],"cost":cost,"group_id":gid,
		"loyalty_before":loyalty,"loyalty_after":mini(100,loyalty+int(Politics.RULES.gift_loyalty)),
		"cooperation_before":cooperation,"cooperation_after":mini(100,cooperation+int(Politics.RULES.gift_cooperation)) if not group.is_empty() else cooperation,"has_group":not group.is_empty()}

static func reward(c: Node, battle_id: String, officer_id: String) -> Dictionary:
	# Revalidate immediately before the synchronous debit/effect/receipt transaction.
	var q: Dictionary=quote(c,battle_id,officer_id)
	if not q.ok: return q
	var stamp: int=c.year*12+c.month
	var key: String=battle_id+":"+officer_id+":reward"
	if not Economy.post(c.strategy_state,c.player_faction_id,-int(q.cost),"political_gift",stamp,"",key): return {"ok":false,"reason":"이미 처리된 포상 결제입니다."}
	var row: Dictionary=battle(c.strategy_state,battle_id)
	Politics.change(c.officer_registry,officer_id,int(Politics.RULES.gift_loyalty),int(Politics.RULES.gift_cooperation),"전투 공훈 포상 · %s→%s" % [c.provinces[row.source].name,c.provinces[row.target].name],stamp)
	battle(c.strategy_state,battle_id).rewards[officer_id]=q.merged({"month":stamp,"officer_id":officer_id,"transaction_id":key})
	return {"ok":true,"reason":"포상 완료 · 금%d · 충성%d→%d%s" % [q.cost,q.loyalty_before,q.loyalty_after," · 협력%d→%d" % [q.cooperation_before,q.cooperation_after] if q.has_group else " · 무소속: 집단 효과 없음"]}

static func unit_text(row: Dictionary, ids: Array) -> String:
	var names: Array[String]=[]
	for unit: Dictionary in row.get("attacker_state",[])+row.get("defender_state",[]):
		if not ids.has(unit.id): continue
		var name: String=str(unit.get("legacy_fields",{}).get("name",{"infantry":"보병","archer":"궁병","cavalry":"기병"}.get(unit.kind,unit.kind)))
		names.append("%s %d명" % [name,unit.troops])
	return " / ".join(names)

static func history(state: Dictionary, officer_id: String, provinces: Dictionary={}) -> String:
	var lines: Array[String]=[]
	for row: Dictionary in state.get("army",{}).get("battles",[]):
		var entry: Dictionary=participant(row,officer_id)
		if entry.is_empty(): continue
		var receipt: Dictionary=row.get("rewards",{}).get(officer_id,{})
		var awarded: String="미포상" if receipt.is_empty() else "포상 완료 · 금%d · 충성%d→%d · 협력%d→%d" % [receipt.cost,receipt.loyalty_before,receipt.loyalty_after,receipt.cooperation_before,receipt.cooperation_after]
		lines.append("%d년 %d월 · %s → %s · %s · 당시 소속 %s\n참전 부대 %s · %s%s" % [int((int(row.month)-1)/12.0),(int(row.month)-1)%12+1,provinces.get(row.source,{}).get("name",row.source),provinces.get(row.target,{}).get("name",row.target),"승리" if entry.won else "패배",state.officer_registry.factions.get(entry.faction_id,entry.faction_id),unit_text(row,entry.unit_ids),awarded," · 전투 지휘" if entry.battle_leader else ""])
	return "\n".join(lines) if not lines.is_empty() else "기록된 참전·포상 이력이 없습니다. 과거 전투의 공훈은 소급 생성하지 않습니다."
