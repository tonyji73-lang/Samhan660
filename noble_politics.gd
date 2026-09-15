extends RefCounted
const RULES={"initial_loyalty":50,"initial_ambition":50,"initial_cooperation":50,"cooperation_base":0.9,"cooperation_step":0.002,"ai_concentration_limit":60,"ai_reserve_gold":300,"ambition_weight":2,"gain":8,"loss":-10,"group_gain":4,"group_loss":-6,"reward_cooldown":6,"group_interval":12,"national_interval":6,"threshold":20.0,"gift_cost":100,"gift_loyalty":5,"gift_cooperation":6,"reject_loyalty":-6,"reject_cooperation":-6}
const GROUPS={
	"silla:royal":{"name":"왕실 직속","representative":"historical:001","members":["historical:001"],"royal":true},
	"silla:civil":{"name":"중앙 귀족 연합","representative":"historical:003","members":["historical:003","historical:002"],"royal":false},
	"silla:military":{"name":"군사 귀족 연합","representative":"historical:004","members":["historical:004","historical:006"],"royal":false}}
static func initialize(r: Dictionary, scenario: String, stamp: int) -> void:
	if r.has("politics") or scenario!="silla_equilibrium_632": return
	var db: Dictionary={"version":1,"faction_id":"silla","groups":{},"history":[],"last_positive":{},"last_demands":{},"last_national":-10000,"pending":{},"resolved":{},"next_id":1,"ai_log":[],"initialized_month":stamp}
	for key: String in GROUPS:
		var g: Dictionary=GROUPS[key].duplicate(true); g["id"]=key; g["faction_id"]="silla"; g["cooperation"]=int(RULES.initial_cooperation); g["history"]=[]
		g["description"]="기존 인물만 묶은 게임용 정치 연합입니다. 역사적으로 확인된 파벌·가문 소속을 뜻하지 않습니다."
		g["basis"]="632 explicit game coalition v1; existing identities and family links unchanged"
		g.members=[]
		for id: String in GROUPS[key].members:
			var p: Dictionary=r.people.get(id,{})
			if p.is_empty() or p.faction_id!="silla" or not p.active or not p.alive: continue
			if not str(p.get("political_group_id","")).is_empty(): continue
			p.political_group_id=key
			if not p.has("loyalty"): p["loyalty"]=int(RULES.initial_loyalty)
			if not p.has("ambition"): p["ambition"]=int(RULES.initial_ambition)
			g.members.append(id)
		db.groups[key]=g
	r["politics"]=db
static func group(r: Dictionary, id: String) -> String: return str(r.get("people",{}).get(id,{}).get("political_group_id",""))
static func change(r: Dictionary, id: String, loyalty: int, cooperation: int, reason: String, stamp: int) -> void:
	if not r.has("politics") or not r.people.has(id): return
	if r.people[id].get("faction_id","")!=r.politics.faction_id: return
	var p: Dictionary=r.people[id]; var gid: String=group(r,id); var db: Dictionary=r.politics
	var before: int=int(p.get("loyalty",50)); p["loyalty"]=clampi(before+loyalty,0,100)
	var g: Dictionary=db.groups.get(gid,{}); var previous: int=int(g.get("cooperation",50))
	if not g.is_empty(): g.cooperation=clampi(previous+cooperation,0,100)
	var entry: Dictionary={"month":stamp,"officer_id":id,"group_id":gid,"reason":reason,"loyalty_before":before,"loyalty_after":p.loyalty,"cooperation_before":previous,"cooperation_after":g.get("cooperation",previous)}
	db.history.append(entry)
	if not g.is_empty(): g.history.append(entry.duplicate(true))
static func reaction(r: Dictionary, old: String, new_id: String, gain: bool, reason: String, stamp: int) -> void:
	if not r.has("politics") or old==new_id or r.get("_power_suppress",false): return
	if r.people.get(new_id,{}).get("faction_id","")!=r.politics.faction_id and r.people.get(old,{}).get("faction_id","")!=r.politics.faction_id: return
	var a: String=group(r,old); var b: String=group(r,new_id)
	if not old.is_empty() and not r.get("_power_skip_loss",false): change(r,old,int(RULES.loss),int(RULES.group_loss) if a!=b else 0,reason+" · 권한 상실",stamp)
	if gain and not new_id.is_empty() and stamp-int(r.politics.last_positive.get(new_id,-10000))>=int(RULES.reward_cooldown):
		change(r,new_id,int(RULES.gain),int(RULES.group_gain) if not a.is_empty() and a!=b else 0,reason+" · 권한 획득",stamp)
		r.politics.last_positive[new_id]=stamp
static func post_changed(r: Dictionary, post: String, old: String, new_id: String, reason: String) -> void:
	if not post.begins_with("governor:") or reason not in ["임명/해임","해임","왕명 인사"]: return
	reaction(r,old,new_id,true,"태수 인사",int(r.get("clock_month",0)))
static func commanded(state: Dictionary, id: String) -> int:
	if id.is_empty(): return 0
	var total: int=0
	for u: Dictionary in state.get("unit_rosters",{}).values():
		if u.get("commander_id","")==id: total+=maxi(0,int(u.get("troops",0)))
	return total
static func multiplier(state: Dictionary, id: String) -> float:
	var r: Dictionary=state.get("officer_registry",{}); var g: Dictionary=r.get("politics",{}).get("groups",{}).get(group(r,id),{})
	return 1.0 if g.is_empty() or g.get("royal",false) else float(RULES.cooperation_base)+int(g.cooperation)*float(RULES.cooperation_step)
static func influence(state: Dictionary, provinces: Dictionary, faction: String) -> Dictionary:
	var r: Dictionary=state.officer_registry; var out: Dictionary={"troops":0,"population":0,"groups":{},"unassigned":{"troops":0,"population":0},"unaffiliated":{"troops":0,"population":0}}
	for gid: String in r.get("politics",{}).get("groups",{}): out.groups[gid]={"troops":0,"population":0,"units":[],"cities":[],"influence":0.0}
	for u: Dictionary in state.get("unit_rosters",{}).values():
		if u.get("faction_id","")!=faction or int(u.get("troops",0))<=0: continue
		out.troops+=int(u.troops)
		var id: String=str(u.get("commander_id","")); var p: Dictionary=r.people.get(id,{})
		var valid: bool=not p.is_empty() and p.active and p.alive and p.faction_id==faction and (u.status=="transit" or p.location==u.location)
		var gid: String=group(r,id) if valid else ""
		if out.groups.has(gid): out.groups[gid].troops+=int(u.troops); out.groups[gid].units.append(u.id)
		else: out.unassigned.troops+=int(u.troops) if not valid else 0; out.unaffiliated.troops+=int(u.troops) if valid else 0
	for city: String in provinces:
		if str(provinces[city].get("faction",""))!=str(r.factions.get(faction,"")): continue
		var pop: int=maxi(0,int(provinces[city].get("population",0))); out.population+=pop
		var id: String=str(r.posts.get("governor:"+city,"")); var p: Dictionary=r.people.get(id,{})
		var valid: bool=not p.is_empty() and p.active and p.alive and not p.in_transit and p.location==city and p.faction_id==faction
		var gid: String=group(r,id) if valid else ""
		if out.groups.has(gid): out.groups[gid].population+=pop; out.groups[gid].cities.append(city)
		else: out.unassigned.population+=pop if not valid else 0; out.unaffiliated.population+=pop if valid else 0
	for row: Dictionary in out.groups.values(): row.influence=float(row.troops)/maxi(1,int(out.troops))*60+float(row.population)/maxi(1,int(out.population))*40
	return out
