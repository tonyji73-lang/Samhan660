extends RefCounted
const Ending=preload("res://campaign_ending.gd")

const Economy = preload("res://faction_economy.gd")
const Production = preload("res://production_system.gd")
const Data = preload("res://production_data.gd")
const Korea = preload("res://korea_35_data.gd")
const MAX_LOAD: int = 2000
const WEIGHTS: Dictionary = {"grain":1,"iron":10,"sword":10}
const POLICY: Dictionary = {"max_new_per_month":1,"donor_reserve_months":6,"target_reserve_months":3,"material_batches":4,"delivery_month_value":6}

static func ensure(state: Dictionary) -> Dictionary:
	if not state.has("supply_transport"):
		state["supply_transport"]={"version":1,"next_id":1,"orders":{},"history":[],"ai_months":{},"ai_log":[]}
	return state.supply_transport

static func owner(state: Dictionary, provinces: Dictionary, city: String) -> String:
	return Economy.resolve(state,str(provinces.get(city,{}).get("faction","")))

static func upkeep(province: Dictionary) -> int:
	return floori(float(maxi(0,int(province.get("troops",0))))/100.0)

static func cargo_quote(raw: Dictionary) -> Dictionary:
	var cargo: Dictionary={"grain":0,"iron":0,"sword":0}
	var seen: Dictionary={}
	for key: String in raw:
		var canonical: String=Data.canonical_item_id(key)
		if key in ["food","food_stock"]: canonical="grain"
		if not WEIGHTS.has(canonical): return {"ok":false,"reason":"지원하지 않는 화물: "+key}
		var amount: Variant=raw[key]
		if typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or float(amount)!=floor(float(amount)) or float(amount)<0 or float(amount)>MAX_LOAD:
			return {"ok":false,"reason":"화물 수량은 0 이상의 정수여야 합니다."}
		if seen.has(canonical) and int(seen[canonical])!=int(amount): return {"ok":false,"reason":"같은 품목의 별칭 수량이 서로 다릅니다."}
		seen[canonical]=int(amount); cargo[canonical]=int(amount)
	var load: int=int(cargo.grain)+10*(int(cargo.iron)+int(cargo.sword))
	return {"ok":load>0 and load<=MAX_LOAD,"reason":"적재량은 1~2,000이어야 합니다." if load<=0 or load>MAX_LOAD else "","cargo":cargo,"load":load}

static func graph() -> Dictionary:
	var result: Dictionary={}
	for road: Array in Korea.get_roads():
		var kind: String=str(road[2]) if road.size()>2 else "land"
		if kind not in ["land","mountain"]: continue
		for pair: Array in [[road[0],road[1]],[road[1],road[0]]]:
			if not result.has(pair[0]): result[pair[0]]=[]
			if not result[pair[0]].has(pair[1]): result[pair[0]].append(pair[1])
	for neighbors: Array in result.values(): neighbors.sort()
	return result

static func route(state: Dictionary, provinces: Dictionary, faction: String, source: String, target: String) -> Array:
	var cities: Array=Economy.city_ids(state,provinces)
	if not cities.has(source) or not cities.has(target) or owner(state,provinces,source)!=faction or owner(state,provinces,target)!=faction: return []
	var edges: Dictionary=graph()
	var queue: Array=[[source]]
	var visited: Dictionary={source:true}
	while not queue.is_empty():
		var path: Array=queue.pop_front()
		var current: String=str(path.back())
		if current==target: return path
		for neighbor: String in edges.get(current,[]):
			if visited.has(neighbor) or not cities.has(neighbor) or owner(state,provinces,neighbor)!=faction: continue
			visited[neighbor]=true
			var next: Array=path.duplicate(); next.append(neighbor); queue.append(next)
	return []

static func remaining_reason(state: Dictionary, provinces: Dictionary, order: Dictionary) -> String:
	var edges: Dictionary=graph()
	for n: int in range(int(order.index),order.path.size()):
		var city: String=str(order.path[n])
		if owner(state,provinces,city)!=order.faction_id: return "남은 경로의 소유권 변경: "+city
		if n>int(order.index) and not edges.get(order.path[n-1],[]).has(city): return "육로 연결 없음: "+city
	return ""

static func quote(state: Dictionary, provinces: Dictionary, actor: String, source: String, target: String, raw: Dictionary, stamp: int, in_transit: bool=false) -> Dictionary:
	var result: Dictionary=cargo_quote(raw)
	if not result.ok: return result
	var access: Dictionary=Economy.validate(state,provinces,actor,actor,source)
	if not access.ok: return access
	var path: Array=route(state,provinces,actor,source,target)
	if path.size()<2: return {"ok":false,"reason":"서로 다른 아군 도시를 잇는 육로·산길 경로가 없습니다."}
	var faction_name: String=str(state.faction_economy.factions[actor])
	var level: int=clampi(int(state.get("faction_research",{}).get(faction_name,{}).get("logistics",0)),0,3)
	var base: int=(path.size()-1)*(10+ceili(float(result.load)/100.0))
	var cost: int=maxi(1,ceili(float(base)*(100-level*10)/100.0))
	var food_after: int=Production.get_stock(state,provinces,source,"grain")-(0 if in_transit else int(result.cargo.grain))
	result.merge({"path":path,"cost":cost,"base_cost":base,"discount_percent":level*10,"eta":stamp+path.size()-1,"food_after":food_after,"upkeep":upkeep(provinces[source])},true)
	result["reason"]=""
	if not in_transit:
		for item: String in WEIGHTS:
			if Production.get_stock(state,provinces,source,item)<int(result.cargo[item]): result.reason="출발 도시의 "+item+" 재고가 부족합니다."
	if Economy.balance(state,actor)<cost: result.reason="국고의 금이 부족합니다."
	result.ok=str(result.reason).is_empty()
	return result

static func move_stock(state: Dictionary, provinces: Dictionary, city: String, cargo: Dictionary, sign_value: int, order: Dictionary, stamp: int, reason: String) -> void:
	if Ending.finished(state): return
	if not state.has("city_inventory"): state["city_inventory"]={}
	if not state.city_inventory.has(city): state.city_inventory[city]={}
	for item: String in WEIGHTS:
		var amount: int=sign_value*int(cargo.get(item,0))
		if item=="grain": provinces[city].food_stock=int(provinces[city].get("food_stock",0))+amount
		else: state.city_inventory[city][item]=int(state.city_inventory[city].get(item,0))+amount
	ensure(state).history.append({"order_id":order.id,"faction_id":order.faction_id,"city_id":city,"month":stamp,"reason":reason,"cargo":cargo.duplicate(true),"direction":sign_value})

static func start(state: Dictionary, provinces: Dictionary, actor: String, source: String, target: String, raw: Dictionary, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var q: Dictionary=quote(state,provinces,actor,source,target,raw,stamp)
	if not q.ok: return q
	var ledger: Dictionary=ensure(state)
	var id: String="supply:%d" % int(ledger.next_id)
	var payment: Dictionary=Economy.spend(state,provinces,actor,actor,source,q.cost,0,"transport",stamp,id+":start")
	if not payment.ok: return payment
	var order: Dictionary={"id":id,"faction_id":actor,"source":source,"target":target,"current":source,"path":q.path.duplicate(),"index":0,"cargo":q.cargo.duplicate(true),"original_cargo":q.cargo.duplicate(true),"cost_paid":q.cost,"initial_cost":q.cost,"created_month":stamp,"last_move_month":stamp,"last_processed_month":stamp,"moves":0,"status":"transit","reason":"","refund":false,"payments":[{"month":stamp,"cost":q.cost,"path":q.path.duplicate()}],"ended_month":-1}
	ledger.next_id=int(ledger.next_id)+1; ledger.orders[id]=order
	move_stock(state,provinces,source,order.cargo,-1,order,stamp,"dispatch")
	q["order_id"]=id
	return q

static func active(order: Dictionary) -> bool:
	return str(order.get("status","")) in ["transit","waiting"]

static func settle(state: Dictionary, provinces: Dictionary, order: Dictionary, city: String, status: String, stamp: int) -> void:
	if Ending.finished(state): return
	if not active(order): return
	move_stock(state,provinces,city,order.cargo,1,order,stamp,status)
	order["delivered_cargo"]=order.cargo.duplicate(true); order.cargo={"grain":0,"iron":0,"sword":0}
	order.status=status; order.ended_month=stamp; order.reason=""; order.current=city

static func capture(state: Dictionary, provinces: Dictionary, city: String, stamp: int) -> void:
	if Ending.finished(state): return
	for order: Dictionary in ensure(state).orders.values():
		if active(order) and order.current==city and owner(state,provinces,city)!=order.faction_id and provinces.has(city): settle(state,provinces,order,city,"captured",stamp)

static func process(state: Dictionary, provinces: Dictionary, stamp: int) -> Array[String]:
	if Ending.finished(state): return []
	var messages: Array[String]=[]
	for order: Dictionary in ensure(state).orders.values():
		if not active(order): continue
		capture(state,provinces,str(order.current),stamp)
		if not active(order): messages.append("화물 피탈: "+str(order.id)); continue
		if stamp<=int(order.last_processed_month) or stamp<=int(order.last_move_month): continue
		order.last_processed_month=stamp
		var reason: String=remaining_reason(state,provinces,order)
		if not reason.is_empty(): order.status="waiting"; order.reason=reason; continue
		order.index=int(order.index)+1; order.current=str(order.path[order.index]); order.moves=int(order.moves)+1; order.last_move_month=stamp; order.status="transit"; order.reason=""
		ensure(state).history.append({"order_id":order.id,"month":stamp,"reason":"move","city_id":order.current})
		if int(order.index)==order.path.size()-1:
			settle(state,provinces,order,str(order.current),"arrived",stamp); messages.append("화물 도착: "+str(order.target)+" · "+str(order.delivered_cargo))
	return messages

static func command(state: Dictionary, provinces: Dictionary, actor: String, id: String, action: String, target: String, stamp: int) -> Dictionary:
	if Ending.finished(state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var order: Dictionary=ensure(state).orders.get(id,{})
	if order.is_empty() or order.get("faction_id","")!=actor or not active(order): return {"ok":false,"reason":"수송 명령 권한 또는 진행 상태가 올바르지 않습니다."}
	if owner(state,provinces,str(order.current))!=actor: return {"ok":false,"reason":"현재 도시의 소유권을 상실했습니다."}
	if action=="cancel":
		if int(order.moves)>0 or order.current!=order.source: return {"ok":false,"reason":"첫 이동 후에는 재지정하거나 현지 하역하세요."}
		settle(state,provinces,order,str(order.current),"canceled",stamp)
		Economy.post(state,actor,int(order.cost_paid),"transport_refund",stamp,str(order.source),id+":refund"); order.refund=true
	elif action=="unload": settle(state,provinces,order,str(order.current),"unloaded",stamp)
	elif action=="reroute":
		var q: Dictionary=quote(state,provinces,actor,str(order.current),target,order.cargo,stamp,true)
		if not q.ok: return q
		var paid: Dictionary=Economy.spend(state,provinces,actor,actor,str(order.current),q.cost,0,"transport_reroute",stamp,id+":route:%d" % order.payments.size())
		if not paid.ok: return paid
		order.path=q.path.duplicate(); order.index=0; order.target=target; order.cost_paid=int(order.cost_paid)+int(q.cost); order.status="transit"; order.reason=""
		order.last_processed_month=maxi(stamp,int(order.last_processed_month))
		order.payments.append({"month":stamp,"cost":q.cost,"path":q.path.duplicate()})
	else: return {"ok":false,"reason":"알 수 없는 수송 명령입니다."}
	return {"ok":true,"reason":"처리 완료"}

static func incoming(state: Dictionary, provinces: Dictionary, faction: String, target: String, item: String, deadline: int, stamp: int) -> int:
	var total: int=0
	for order: Dictionary in ensure(state).orders.values():
		if active(order) and order.faction_id==faction and order.target==target and remaining_reason(state,provinces,order).is_empty():
			if stamp+order.path.size()-1-int(order.index)<=deadline: total+=int(order.cargo.get(item,0))
	return total

static func ai(state: Dictionary, provinces: Dictionary, faction: String, stamp: int, recruit_target: int, attacks: Dictionary, scenario: String, rules: Dictionary) -> Array[String]:
	if Ending.finished(state): return []
	var ledger: Dictionary=ensure(state)
	if int(ledger.ai_months.get(faction,-1))>=stamp: return []
	ledger.ai_months[faction]=stamp
	var messages: Array[String]=[]
	for order: Dictionary in ledger.orders.values():
		if not active(order) or order.faction_id!=faction: continue
		if owner(state,provinces,str(order.current))!=faction: capture(state,provinces,str(order.current),stamp); continue
		if not remaining_reason(state,provinces,order).is_empty():
			var rerouted: Dictionary=command(state,provinces,faction,order.id,"reroute",order.target,stamp)
			if not rerouted.ok: command(state,provinces,faction,order.id,"unload","",stamp)
			ledger.ai_log.append({"month":stamp,"faction_id":faction,"order_id":order.id,"reason":"막힌 경로 재지정" if rerouted.ok else "재지정 불가 · 현지 하역"})
	var cities: Array=[]
	for city: String in Economy.city_ids(state,provinces):
		if owner(state,provinces,city)==faction: cities.append(city)
	cities.sort_custom(func(a,b):
		var a_months: float=float(Production.get_stock(state,provinces,a,"grain"))/maxi(1,upkeep(provinces[a]))
		var b_months: float=float(Production.get_stock(state,provinces,b,"grain"))/maxi(1,upkeep(provinces[b]))
		return a<b if is_equal_approx(a_months,b_months) else a_months<b_months)
	var attempts: Array=[]
	var new_count: int=0
	var urgent: bool=false
	for target: String in cities:
		var use: int=upkeep(provinces[target])
		var recruitment_food: int=maxi(0,recruit_target/100)*20
		var stock: int=Production.get_stock(state,provinces,target,"grain")
		if stock+incoming(state,provinces,faction,target,"grain",stamp+int(POLICY.target_reserve_months),stamp)>=use*int(POLICY.target_reserve_months)+recruitment_food+int(attacks.get(target,0)): continue
		urgent=true
		var donors: Array=cities.duplicate()
		donors.sort_custom(func(a,b):
			var length_a: int=route(state,provinces,faction,a,target).size()
			var length_b: int=route(state,provinces,faction,b,target).size()
			return a<b if length_a==length_b else length_a<length_b)
		for source: String in donors:
			var path: Array=route(state,provinces,faction,source,target)
			if path.size()<2: continue
			var travel: int=path.size()-1
			var need: int=use*(travel+int(POLICY.target_reserve_months))+recruitment_food*(travel+1)+int(attacks.get(target,0))-stock-incoming(state,provinces,faction,target,"grain",stamp+travel,stamp)
			var surplus: int=Production.get_stock(state,provinces,source,"grain")-upkeep(provinces[source])*int(POLICY.donor_reserve_months)
			var amount: int=mini(MAX_LOAD,mini(need,surplus))
			if amount<=0: continue
			var result: Dictionary=start(state,provinces,faction,source,target,{"grain":amount},stamp)
			attempts.append({"source":source,"target":target,"need":need,"surplus":surplus,"travel":travel,"result":result})
			if result.ok: new_count+=1; messages.append("AI 군량 수송: %s → %s · %d" % [source,target,amount]); break
		if new_count>=int(POLICY.max_new_per_month): break
	if not urgent and new_count==0:
		for target: String in cities:
			for recipe_id: String in state.get("city_production",{}).get(target,{}):
				var order: Dictionary=state.city_production[target][recipe_id]
				if not order.get("enabled",false) or str(order.get("owner",""))!=str(provinces[target].faction) or not Data.RECIPES.has(recipe_id): continue
				var recipe: Dictionary=Data.RECIPES[recipe_id]
				var shadow: Dictionary=state.duplicate(true)
				for item: String in recipe.inputs: shadow.city_inventory[target][item]=int(recipe.inputs[item])
				if not Production.validate_batch(shadow,provinces,target,recipe_id,str(provinces[target].faction),Economy.balance(state,faction),scenario,rules).ok: continue
				for item: String in recipe.inputs:
					if item not in ["iron","sword"] or Production.get_stock(state,provinces,target,item)>=int(recipe.inputs[item]): continue
					for source: String in cities:
						var path: Array=route(state,provinces,faction,source,target)
						if path.size()<2: continue
						var need: int=int(recipe.inputs[item])*int(POLICY.material_batches)-Production.get_stock(state,provinces,target,item)-incoming(state,provinces,faction,target,item,stamp+path.size()-1,stamp)
						var reserve: int=0
						for donor_recipe: String in state.get("city_production",{}).get(source,{}):
							if state.city_production[source][donor_recipe].get("enabled",false): reserve+=int(Data.RECIPES.get(donor_recipe,{}).get("inputs",{}).get(item,0))*int(POLICY.material_batches)
						var amount: int=mini(200,mini(need,Production.get_stock(state,provinces,source,item)-reserve))
						if amount<=0: continue
						var delivery: Dictionary=quote(state,provinces,faction,source,target,{item:amount},stamp)
						if item=="iron" and delivery.ok:
							var local_recipe: String=""
							var local_cost: int=2147483647
							for option: String in ["iron_supply","iron_procurement"]:
								var local: Dictionary=Production.validate_batch(state,provinces,target,option,str(provinces[target].faction),Economy.balance(state,faction),scenario,rules)
								var price: int=ceili(float(amount)/2)*int(Data.RECIPES[option].operating_gold)
								if local.ok and price<local_cost: local_recipe=option; local_cost=price
							var local_months: int=ceili(float(amount)/2)
							attempts.append({"target":target,"comparison":"iron procurement vs existing stock delivery","amount":amount,"local_cost":local_cost,"local_months":local_months,"transport_cost":delivery.cost,"transport_months":path.size()-1})
							if not local_recipe.is_empty() and local_cost+local_months*int(POLICY.delivery_month_value)<=int(delivery.cost)+(path.size()-1)*int(POLICY.delivery_month_value):
								Production.set_enabled(state,provinces,target,local_recipe,str(provinces[target].faction),true,scenario,rules)
								continue
						var result: Dictionary=start(state,provinces,faction,source,target,{item:amount},stamp)
						attempts.append({"source":source,"target":target,"item":item,"result":result})
						if result.ok: new_count+=1; messages.append("AI 생산 재료 수송: %s → %s" % [source,target]); break
					if new_count>0: break
				if new_count>0: break
			if new_count>0: break
	ledger.ai_log.append({"month":stamp,"faction_id":faction,"new_orders":new_count,"urgent_food":urgent,"reason":"수송 접수" if new_count>0 else ("군량 부족 · 공급 여유/경로/국고 조건 미충족" if urgent else "추가 지원 수요 또는 유효 공급 경로 없음"),"attempts":attempts})
	return messages
