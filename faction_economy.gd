extends RefCounted
const Ending=preload("res://campaign_ending.gd")

const Korea = preload("res://korea_35_data.gd")
const DEFAULT_AI_GOLD: int = 1000

static func initialize(state: Dictionary, scenario: Dictionary, player_id: String, player_gold: int, legacy: bool = false) -> void:
	if state.has("faction_economy"): return
	var ledger: Dictionary={"version":1,"accounts":{},"factions":{},"entries":[],"receipts":{},"recruitment":[],"ai_months":{},"phase_months":{},"migration":"legacy AI validation seed; not reconstructed historical wealth" if legacy else "new game"}
	for faction: Dictionary in scenario.get("factions",[]):
		var id: String=str(faction.id)
		var opening: int=maxi(0,int(faction.get("starting_gold",faction.get("gold",DEFAULT_AI_GOLD))))
		if id==player_id: opening=player_gold
		ledger.factions[id]=str(faction.name)
		ledger.accounts[id]={"opening":opening,"balance":opening,"income":0,"expense":0}
	state["faction_economy"]=ledger
	# The old global stamp only proves the saved player's production was tried.
	state["production_months"]={player_id:int(state.get("production_last_month",-1))}
	for job: Dictionary in state.get("domestic",{}).get("jobs",{}).values():
		if not job.has("payer_faction_id"): job["payer_faction_id"]=resolve(state,str(job.get("faction","")))

static func resolve(state: Dictionary, faction_ref: String) -> String:
	var names: Dictionary=state.get("faction_economy",{}).get("factions",{})
	if names.has(faction_ref): return faction_ref
	for id: String in names:
		if names[id]==faction_ref: return id
	return ""

static func balance(state: Dictionary, id: String) -> int:
	return int(state.get("faction_economy",{}).get("accounts",{}).get(id,{}).get("balance",0))

static func city_ids(state: Dictionary, provinces: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	for city: String in Korea.PROVINCE_IDS:
		if provinces.has(city) and not resolve(state,str(provinces[city].get("faction",""))).is_empty(): result.append(city)
	return result

static func validate_national(state: Dictionary, actor: String, payer: String, gold_cost: int = 0) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	if actor!=payer or not state.get("faction_economy",{}).get("accounts",{}).has(payer): return {"ok":false,"reason":"명령 권한과 비용 부담 국가가 다릅니다."}
	if gold_cost<0: return {"ok":false,"reason":"올바르지 않은 비용입니다."}
	if balance(state,payer)<gold_cost: return {"ok":false,"reason":"국고의 금이 부족합니다."}
	return {"ok":true,"reason":""}

static func validate(state: Dictionary, provinces: Dictionary, actor: String, payer: String, city: String, gold_cost: int = 0, food_cost: int = 0) -> Dictionary:
	var national: Dictionary=validate_national(state,actor,payer,gold_cost)
	if not national.ok: return national
	var reason: String=""
	if actor!=payer or not state.get("faction_economy",{}).get("accounts",{}).has(payer): reason="명령 권한과 비용 부담 국가가 다릅니다."
	elif not city_ids(state,provinces).has(city): reason="현재 경제 운영 대상 도시가 아닙니다."
	elif resolve(state,str(provinces[city].get("faction","")))!=payer: reason="다른 국가의 도시 자원을 사용할 수 없습니다."
	elif gold_cost<0 or food_cost<0: reason="올바르지 않은 비용입니다."
	elif balance(state,payer)<gold_cost: reason="국고의 금이 부족합니다."
	elif int(provinces[city].get("food_stock",0))<food_cost: reason="해당 도시의 군량이 부족합니다."
	return {"ok":reason.is_empty(),"reason":reason}

static func post(state: Dictionary, id: String, amount: int, reason: String, month: int, city: String = "", token: String = "") -> bool:
	if Ending.finished(state): return false
	var ledger: Dictionary=state.get("faction_economy",{})
	if not ledger.get("accounts",{}).has(id): return false
	if not token.is_empty() and ledger.receipts.has(token): return false
	var account: Dictionary=ledger.accounts[id]
	if int(account.balance)+amount<0: return false
	account.balance=int(account.balance)+amount
	if amount>=0: account.income=int(account.income)+amount
	else: account.expense=int(account.expense)-amount
	ledger.entries.append({"faction_id":id,"amount":amount,"reason":reason,"month":month,"city_id":city,"balance":account.balance,"token":token})
	if not token.is_empty(): ledger.receipts[token]=true
	return true

static func spend(state: Dictionary, provinces: Dictionary, actor: String, payer: String, city: String, gold_cost: int, food_cost: int, reason: String, month: int, token: String = "") -> Dictionary:
	var result: Dictionary=validate(state,provinces,actor,payer,city,gold_cost,food_cost)
	if not result.ok: return result
	if not post(state,payer,-gold_cost,reason,month,city,token): return {"ok":false,"reason":"이미 처리한 비용입니다."}
	var before: int=int(provinces[city].get("food_stock",0))
	provinces[city].food_stock=before-food_cost
	if not state.faction_economy.has("food_entries"): state.faction_economy["food_entries"]=[]
	if food_cost>0: state.faction_economy.food_entries.append({"faction_id":payer,"city_id":city,"month":month,"reason":reason,"amount":-food_cost,"before":before,"after":provinces[city].food_stock})
	return {"ok":true,"gold_cost":gold_cost,"food_cost":food_cost}
