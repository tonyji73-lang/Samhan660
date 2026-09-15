extends RefCounted
const Ending=preload("res://campaign_ending.gd")

const Army=preload("res://army_readiness.gd")
const Mobilization=preload("res://mobilization.gd")
const Economy = preload("res://faction_economy.gd")
const UNIT: int = 100
const GOLD_PER_UNIT: int = 15
const FOOD_PER_UNIT: int = 20

static func affordable(state: Dictionary, provinces: Dictionary, faction_id: String, city: String, target: int) -> int:
	if not provinces.has(city): return 0
	return maxi(0,mini(mini(int(target/UNIT),int(Mobilization.view(state,provinces,city).available/UNIT)),mini(int(Economy.balance(state,faction_id)/GOLD_PER_UNIT),int(int(provinces[city].get("food_stock",0))/FOOD_PER_UNIT))))*UNIT

static func quote(state: Dictionary, provinces: Dictionary, actor: String, payer: String, city: String, amount: int) -> Dictionary:
	var gold_cost: int=int(amount/UNIT)*GOLD_PER_UNIT
	var food_cost: int=int(amount/UNIT)*FOOD_PER_UNIT
	var q: Dictionary=Economy.validate(state,provinces,actor,payer,city,gold_cost,food_cost)
	if amount<UNIT or amount%UNIT!=0: q={"ok":false,"reason":"모집은 100명 단위로 지정하세요."}
	var manpower: Dictionary=Mobilization.view(state,provinces,city)
	if q.ok and amount>int(manpower.available): q={"ok":false,"reason":"민간 인구·출신지 동원 한도 부족 (다른 도시·이동 중 병력 포함)"}
	q.merge(manpower)
	q.merge({"amount":amount,"gold_cost":gold_cost,"food_cost":food_cost,"faction_id":payer,"city_id":city,"available_gold":Economy.balance(state,payer),"available_food":provinces.get(city,{}).get("food_stock",0)})
	return q

static func execute(state: Dictionary, provinces: Dictionary, actor: String, payer: String, city: String, amount: int, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var q: Dictionary=quote(state,provinces,actor,payer,city,amount)
	var before: Dictionary={"gold":Economy.balance(state,payer),"food":provinces.get(city,{}).get("food_stock",0),"population":provinces.get(city,{}).get("population",0),"troops":provinces.get(city,{}).get("troops",0)}
	if q.ok:
		var cost: Dictionary=Economy.spend(state,provinces,actor,payer,city,q.gold_cost,q.food_cost,"recruitment",stamp)
		q.ok=cost.ok
		if cost.ok:
			Mobilization.initialize(state,provinces)
			provinces[city].population=int(provinces[city].get("population",0))-amount
			if state.has("army"):
				var unit: Dictionary=Army.create(state,payer,city,amount,"infantry",int(Army.RULES.recruit_training),0,city)
				unit["creation_reason"]="recruitment"; q["unit_id"]=unit.id; Army.sync(state,provinces)
			else: provinces[city].troops=int(provinces[city].troops)+amount
		else: q.reason=cost.reason
	state.faction_economy.recruitment.append({"month":stamp,"faction_id":payer,"city_id":city,"requested":amount,"recruited":amount if q.ok else 0,"ok":q.ok,"reason":q.reason,"gold_cost":q.gold_cost if q.ok else 0,"food_cost":q.food_cost if q.ok else 0,"before":before,"after":{"gold":Economy.balance(state,payer),"food":provinces.get(city,{}).get("food_stock",0),"population":provinces.get(city,{}).get("population",0),"troops":provinces.get(city,{}).get("troops",0)}})
	return q
