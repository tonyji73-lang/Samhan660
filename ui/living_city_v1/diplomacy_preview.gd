extends RefCounted
## Existing deterministic command and trade settlement, on isolated copies only.
static func trade(c: Node,state: Dictionary,target_name: String) -> Dictionary:
	var copy: Dictionary=state.duplicate(true)
	copy.trade_routes=copy.get("trade_routes",[]).filter(func(row): return [str(row.get("faction_a","")),str(row.get("faction_b",""))].has(c.player_faction) and [str(row.get("faction_a","")),str(row.get("faction_b",""))].has(target_name))
	var count: int=copy.trade_routes.size()
	var value: Dictionary=c.strategy._process_trade(copy,c.provinces.duplicate(true))
	return {"routes":count,"income":int(value.faction_gold_delta.get(c.player_faction,0))}
static func inspect(c: Node,target: String,action: String,envoy: String) -> Dictionary:
	var q: Dictionary=c.get_diplomatic_action_quote(target,action,envoy)
	var names: Array[String]=[]; var target_name: String=""
	for f: Dictionary in c.get_diplomacy_factions():
		names.append(f.name)
		if f.id==target: target_name=f.name
	var state: Dictionary=c.strategy_state.duplicate(true)
	var before: Dictionary=c.strategy.get_relation(state,c.player_faction,target_name).duplicate(true)
	var result: Dictionary={"ok":false,"executed":false,"reason":q.reason}
	if q.ok:
		result=c.strategy.perform_diplomatic_action(state,c.player_faction,target_name,action,{"name":envoy},c.year,c.month,c.gold,c.provinces.duplicate(true),c.officers.duplicate(true),c.officers_by_province.duplicate(true),names)
	return {"quote":q,"result":result,"state":state,"before":before,"after":c.strategy.get_relation(state,c.player_faction,target_name).duplicate(true),"trade_before":trade(c,c.strategy_state,target_name),"trade_after":trade(c,state,target_name)}
