extends Node
## Isolated read model: execute existing commands against deep copies only.
const Core=preload("res://noble_politics.gd")
const Power=preload("res://noble_power_constraints.gd")
const Noble=preload("res://noble_personnel.gd")
const OfficerRegistry=preload("res://officer_registry.gd")
const Army=preload("res://army_readiness.gd")
const Mobilization=preload("res://mobilization.gd")
const Economy=preload("res://faction_economy.gd")
const Ending=preload("res://campaign_ending.gd")
var source: Node
var strategy_state: Dictionary
var officer_registry: Dictionary
var provinces: Dictionary
var year: int
var month: int
var ending_busy: bool=false
var player_faction_id: String="preview:no-presentation"
func get_officer(id: String) -> Dictionary: return OfficerRegistry.view(officer_registry,id)
func city_operation_quote(city: String) -> Dictionary: return source.city_operation_quote(city)
func _sync_officer_labels() -> void: pass
func update_top_bar() -> void: pass

static func inspect(c: Node, kind: String, id: String, choice: String, successor: String="") -> Dictionary:
	var shadow:=new(); shadow.source=c; shadow.strategy_state=c.strategy_state.duplicate(true)
	shadow.officer_registry=shadow.strategy_state.officer_registry; shadow.provinces=c.provinces.duplicate(true)
	shadow.year=c.year; shadow.month=c.month; shadow.ending_busy=c.ending_busy
	var result: Dictionary={}
	var before_gold: int=Economy.balance(shadow.strategy_state,c.player_faction_id)
	if kind=="power": result=Power.retarget(shadow,id,successor) if choice=="retarget" else Power.resolve(shadow,id,choice)
	elif kind=="demand":
		var reason: String=Noble.reason(shadow,id,choice)
		if reason.is_empty(): result=Noble.resolve(shadow,id,choice); result["ok"]=not result.is_empty()
		else: result={"ok":false,"reason":reason}
	var reactions: Array=[]
	for oid: String in shadow.officer_registry.people:
		var p: Dictionary=shadow.officer_registry.people[oid]; var old: Dictionary=c.officer_registry.people.get(oid,{})
		if p.get("loyalty",null)!=old.get("loyalty",null): reactions.append({"name":p.name,"before":old.get("loyalty",0),"after":p.get("loyalty",0),"unit":"개인 충성"})
	for gid: String in shadow.officer_registry.get("politics",{}).get("groups",{}):
		var g: Dictionary=shadow.officer_registry.politics.groups[gid]; var old: Dictionary=c.officer_registry.politics.groups[gid]
		if g.cooperation!=old.cooperation: reactions.append({"name":g.name,"before":old.cooperation,"after":g.cooperation,"unit":"집단 협력"})
	var output: Dictionary={"ok":result.get("ok",false),"result":result,"gold_before":before_gold,"gold_after":Economy.balance(shadow.strategy_state,c.player_faction_id),"reactions":reactions,"state":shadow.strategy_state,"provinces":shadow.provinces}
	shadow.free(); return output
