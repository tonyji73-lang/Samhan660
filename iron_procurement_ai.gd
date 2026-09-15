extends RefCounted
const Army=preload("res://army_readiness.gd")
const Industry=preload("res://industry_assignment.gd")
const Economy=preload("res://faction_economy.gd")
const Production=preload("res://production_system.gd")
const Supply=preload("res://supply_transport.gd")
const POLICY={"reserve_gold":300,"target_bundles":10,"delivery_month_value":6,"supply_batches":4}
static func run(c: Node, faction: String, reserve: int) -> void:
	if c.Ending.finished(c.strategy_state): return
	var s: Dictionary=c.strategy_state; var ps: Dictionary=c.provinces; var stamp: int=c.year*12+c.month
	if not s.has("iron_ai"): s["iron_ai"]={"months":{},"log":[],"last":{}}
	if int(s.iron_ai.months.get(faction,-1))>=stamp: return
	s.iron_ai.months[faction]=stamp
	var cities: Array=[]
	for city: String in Economy.city_ids(s,ps):
		if Economy.resolve(s,str(ps[city].faction))==faction: cities.append(city)
	cities.sort()
	var candidates: Array=[]
	for city: String in cities:
		var shortage: int=0
		for uid: String in Army.at_city(s,city,faction): shortage+=maxi(0,int(s.unit_rosters[uid].troops)-int(s.unit_rosters[uid].equipment))
		# A limited stock buffer also permits preparation before unarmed recruits exist.
		if Production.get_stock(s,ps,city,"sword")>=int(POLICY.target_bundles) and shortage==0: continue
		for officer: String in c.get_city_officer_ids(city):
			if Industry.staff_reason(s,ps,faction,city,officer,stamp).is_empty(): candidates.append({"city":city,"officer":officer}); break
	# Resume existing production sites even while their worker is busy on infrastructure.
	for city: String in cities:
		if int(s.province_buildings[city].get("smelter",0))>0 and not candidates.any(func(x): return x.city==city): candidates.append({"city":city,"officer":""})
	if not s.iron_ai.has("hubs"): s.iron_ai["hubs"]={}
	var hub: String=str(s.iron_ai.hubs.get(faction,""))
	if not cities.has(hub):
		hub=str(candidates[0].city) if not candidates.is_empty() else ""
		s.iron_ai.hubs[faction]=hub
	candidates=candidates.filter(func(x): return x.city==hub)
	var actions: Array=[]
	var name: String=s.faction_economy.factions[faction]
	for entry: Dictionary in candidates:
		var city: String=entry.city
		if int(ps[city].food_stock)<Supply.upkeep(ps[city])*3: continue
		var missing: Array=[]
		if int(s.province_buildings[city].get("smelter",0))<1: missing.append(["build","smelter"])
		if int(s.faction_research[name].get("basic_smelting",0))<1: missing.append(["research","basic_smelting"])
		if int(s.province_buildings[city].get("forge",0))<1: missing.append(["build","forge"])
		if int(s.faction_research[name].get("swordsmithing",0))<1: missing.append(["research","swordsmithing"])
		if not missing.is_empty():
			if entry.officer.is_empty(): continue
			var request: Array=missing[0]
			var q: Dictionary=Industry.quote(s,ps,c.strategy,faction,city,request[0],request[1],entry.officer,stamp,c.scenario_id,c.iron_supply_rules)
			if q.ok and Economy.balance(s,faction)-int(q.gold_cost)>=int(POLICY.reserve_gold)+reserve:
				var result: Dictionary=Industry.start(s,ps,c.strategy,faction,city,request[0],request[1],entry.officer,stamp,c.scenario_id,c.iron_supply_rules)
				actions.append({"city":city,"infrastructure":request,"result":result}); break
			continue
		var choices: Array=[]
		for recipe: String in ["iron_supply","iron_procurement"]:
			var q: Dictionary=Production.validate_batch(s,ps,city,recipe,name,Economy.balance(s,faction),c.scenario_id,c.iron_supply_rules)
			if q.ok: choices.append({"recipe":recipe,"source":city,"amount":2,"cost":int(Production.Data.RECIPES[recipe].operating_gold),"eta":1})
		var needed: int=maxi(0,2*int(POLICY.supply_batches)-Production.get_stock(s,ps,city,"iron")-Supply.incoming(s,ps,faction,city,"iron",stamp+12,stamp))
		var new_transport: bool=false
		for order: Dictionary in Supply.ensure(s).orders.values():
			if order.faction_id==faction and int(order.created_month)==stamp: new_transport=true
		if needed>0 and not new_transport:
			for donor: String in cities:
				var amount: int=mini(needed,Production.get_stock(s,ps,donor,"iron")-8)
				if donor==city or amount<=0: continue
				var q: Dictionary=Supply.quote(s,ps,faction,donor,city,{"iron":amount},stamp)
				if q.ok: choices.append({"recipe":"transport","source":donor,"amount":amount,"cost":q.cost,"eta":q.path.size()-1})
		choices.sort_custom(func(a,b):
			var av: float=float(a.cost)*2/maxi(1,int(a.amount))+int(a.eta)*int(POLICY.delivery_month_value)
			var bv: float=float(b.cost)*2/maxi(1,int(b.amount))+int(b.eta)*int(POLICY.delivery_month_value)
			return str(a.recipe)+str(a.source)<str(b.recipe)+str(b.source) if is_equal_approx(av,bv) else av<bv)
		var enough: bool=Production.get_stock(s,ps,city,"sword")>=int(POLICY.target_bundles)
		if enough:
			for recipe: String in ["iron_supply","iron_procurement","iron_sword"]: Production.set_enabled(s,ps,city,recipe,name,false,c.scenario_id,c.iron_supply_rules)
			continue
		if choices.is_empty() or Economy.balance(s,faction)<reserve+int(POLICY.reserve_gold)+28: continue
		var best: Dictionary=choices[0]
		for recipe: String in ["iron_supply","iron_procurement"]: Production.set_enabled(s,ps,city,recipe,name,false,c.scenario_id,c.iron_supply_rules)
		if needed>0:
			if best.recipe=="transport": best["result"]=Supply.start(s,ps,faction,best.source,city,{"iron":best.amount},stamp)
			else: Production.set_enabled(s,ps,city,best.recipe,name,true,c.scenario_id,c.iron_supply_rules)
		Production.set_enabled(s,ps,city,"iron_sword",name,true,c.scenario_id,c.iron_supply_rules)
		actions.append({"city":city,"need":needed,"options":choices,"chosen":best}); break
	var fingerprint: String=JSON.stringify(actions)
	if s.iron_ai.last.get(faction,"")!=fingerprint:
		s.iron_ai.last[faction]=fingerprint
		s.iron_ai.log.append({"month":stamp,"faction_id":faction,"actions":actions,"reason":"예산·군량·인력·시설 확인 후 변경 없음" if actions.is_empty() else "공통 유료 명령 선택"})
