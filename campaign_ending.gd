extends RefCounted
# Fixed battlefield definition v1. Sea edges ARE attackable in current combat;
# overseas WorldMap nodes are not members of this list.
const VERSION = 1
const TARGETS = ["shinseong","sokgunseong","ansi","geonanseong","gungnae","chaekseong","bireyeolhol","pyongyang","daedonggang","goksan","hwanghae","bukhansan","danghangseong","samnyeonsanseong","gukwon","haslla","siljik","imjonseong","ungjin","sabi","geummajeo","gosa","juryuseong","yeongsangang","geumseong","sabeol","dalgubeol","daegaya","geumgwan","sogaya","tamna","ulleung","ganghwa","jukryeong","chupungnyeong"]
const COMBINATIONS = {
 "silla_equilibrium_632":["silla","baekje","goguryeo"],
 "goguryeo_coup_642":["silla","baekje","goguryeo"],
 "baekje_fall_660":["silla","baekje","goguryeo"],
 "baekgang_663":["silla","goguryeo"],
 "silla_tang_war_670":["silla"]}
const BLOCKED = "캠페인이 종료되었습니다. 결과 열람·저장·불러오기·새 캠페인 시작만 가능합니다."
static func finished(state: Dictionary) -> bool:
 return state.get("campaign_ending",{}).get("status","ongoing") in ["victory","defeat"]
static func definition(scenario: String, faction: String) -> Dictionary:
 if not COMBINATIONS.get(scenario,[]).has(faction): return {}
 return {"version":VERSION,"scenario_id":scenario,"faction_id":faction,"kind":"direct_ownership","targets":TARGETS.duplicate(),"defeat":"no_actionable_base","precedence":"defeat","duration_months":0,"basis":"검수 v1 통일 목표 / 별도 최종 기간 정의가 없어 현재 전장 통일을 게임용 기본 규칙으로 적용","intermediate":["무기 제작","신규 보병 1000명 장비·훈련 준비","전투 승리"]}
static func initialize(state: Dictionary, scenario: String, faction: String, stamp: int, start_stamp: int) -> void:
 if state.has("campaign_ending"): return
 state.campaign_ending={"campaign_id":Crypto.new().generate_random_bytes(16).hex_encode(),"status":"ongoing","definition":definition(scenario,faction),"start_month":start_stamp,"start_basis":"actual_new_game_start","migration_month":stamp,"result":{}}
static func owner(state: Dictionary, province: Dictionary) -> String:
 var faction_ref: String=str(province.get("faction",""))
 var names: Dictionary=state.get("faction_economy",{}).get("factions",{})
 if names.has(faction_ref): return faction_ref
 for id: String in names:
  if names[id]==faction_ref: return id
 return ""
# Pure: never initializes, pays, relocates, advances time or confirms a result.
static func evaluate(state: Dictionary, provinces: Dictionary) -> Dictionary:
 var life: Dictionary=state.get("campaign_ending",{})
 var rule: Dictionary=life.get("definition",{})
 var targets: Array=rule.get("targets",[])
 if rule.is_empty() or targets.is_empty(): return {"status":"configuration_error","reason":"최종 목표 도시 목록이 비었습니다."}
 if rule.get("version",0)!=VERSION or not COMBINATIONS.get(rule.get("scenario_id",""),[]).has(rule.get("faction_id","")): return {"status":"configuration_error","reason":"지원하지 않는 조건 버전 또는 시나리오 조합입니다."}
 var seen: Dictionary={}
 for id: Variant in targets:
  if not TARGETS.has(id) or not provinces.has(id) or seen.has(id): return {"status":"configuration_error","reason":"잘못되거나 중복된 목표 도시 ID: "+str(id)}
  seen[id]=true
 if seen.size()!=TARGETS.size(): return {"status":"configuration_error","reason":"v1의 고정 목표 도시 일부가 누락되었습니다."}
 var owned: Array=[]; var achieved: Array=[]; var missing: Array=[]
 for id: String in TARGETS:
  if provinces.has(id) and owner(state,provinces[id])==rule.faction_id: owned.append(id)
 for id: String in targets:
  if owned.has(id): achieved.append(id)
  else: missing.append(id)
 # Current combat requires an owned source city. Transfers only arrive at owned
 # destinations; neither inert nor transit rosters can recapture enemy cities.
 var result: Dictionary={"status":"ongoing","reason":"목표 도시를 직접 점유하세요. 동맹 점유는 포함하지 않습니다.","owned":owned,"achieved":achieved,"missing":missing,"recovery":"현재 공격은 아군 출발 도시가 필요하며 무거점 수복·망명·세력 전환은 미구현"}
 if owned.is_empty(): result.status="defeat"; result.reason="최종 거점을 상실했습니다. 현재 규칙으로 실행 가능한 수복·세력 전환이 없습니다."
 elif missing.is_empty(): result.status="victory"; result.reason="고정 목표 %d개 도시를 모두 직접 점유하여 현재 전장을 통일했습니다." % targets.size()
 return result
static func confirm(state: Dictionary, provinces: Dictionary, stamp: int, source: String) -> bool:
 if finished(state): return false
 var evaluation: Dictionary=evaluate(state,provinces)
 if not evaluation.status in ["victory","defeat"]: return false
 var life: Dictionary=state.campaign_ending
 var faction: String=life.definition.faction_id
 var troops: int=0
 for unit: Dictionary in state.get("unit_rosters",{}).values():
  if unit.get("faction_id","")==faction: troops+=int(unit.get("troops",0))
 var snapshot: Dictionary={"cities":evaluation.owned.duplicate(),"troops":troops,"treasury":state.get("faction_economy",{}).get("accounts",{}).get(faction,{}).get("balance",null)}
 snapshot["city_resources"]={}
 snapshot["food_stock"]=0
 for city: String in evaluation.owned:
  snapshot.city_resources[city]={"food_stock":int(provinces[city].get("food_stock",0)),"population":int(provinces[city].get("population",0)),"inventory":state.get("city_inventory",{}).get(city,{}).duplicate(true)}
  snapshot.food_stock+=int(provinces[city].get("food_stock",0))
 var recruitment: Array=state.get("faction_economy",{}).get("recruitment",[]).filter(func(row): return row.get("faction_id","")==faction)
 if not recruitment.is_empty():
  snapshot["recorded_recruits"]=0
  for row: Dictionary in recruitment: snapshot.recorded_recruits+=int(row.get("recruited",0))
 var losses: int=0; var battle_count: int=0
 for battle: Dictionary in state.get("army",{}).get("battles",[]):
  for side: String in ["attacker","defender"]:
   var participants: Array=battle.get("attacker_state" if side=="attacker" else "defender_state",[])
   if participants.any(func(unit): return unit.get("faction_id","")==faction):
    losses+=int(battle.get(side+"_losses",0)); battle_count+=1
 if battle_count>0:
  snapshot["recorded_battles"]=battle_count
  snapshot["recorded_losses"]=losses
 if state.get("faction_economy",{}).has("entries"):
  var politics_cost: int=0
  var political_entries: int=0
  for entry: Dictionary in state.faction_economy.entries:
   if entry.get("faction_id","")==faction and str(entry.get("reason","")).begins_with("politic"):
    politics_cost-=mini(0,int(entry.amount)); political_entries+=1
  if political_entries>0 and state.get("officer_registry",{}).get("politics",{}).get("faction_id","")==faction: snapshot["recorded_politics_expense"]=politics_cost
 life.status=evaluation.status
 var fingerprint: String=JSON.stringify({"month":stamp,"evaluation":evaluation,"snapshot":snapshot}).sha256_text().substr(0,24)
 life.result={"result_id":str(life.campaign_id)+":"+fingerprint,"condition_version":VERSION,"month":stamp,"elapsed_months":maxi(0,stamp-int(life.start_month)),"source":source,"evaluation":evaluation,"snapshot":snapshot}
 return true
static func result_text(state: Dictionary) -> String:
 var life: Dictionary=state.campaign_ending
 var result: Dictionary=life.result
 var snap: Dictionary=result.snapshot
 var names: Dictionary={"silla_equilibrium_632":"632년 선덕여왕 즉위","goguryeo_coup_642":"642년 고구려 정변","baekje_fall_660":"660년 백제 멸망전","baekgang_663":"663년 백강 전투","silla_tang_war_670":"670년 나당 전쟁","silla":"신라","baekje":"백제","goguryeo":"고구려"}
 var statistics: String="기록된 모집: "+str(snap.recorded_recruits) if snap.has("recorded_recruits") else "모집 누계: 기록 없음"
 statistics="보유 도시 군량: "+str(snap.get("food_stock","기록 없음"))+"\n"+statistics
 statistics+="\n기록된 전투 %d회 · 전투 손실 %d명" % [snap.recorded_battles,snap.recorded_losses] if snap.has("recorded_battles") else "\n전투 누계: 기록 없음"
 statistics+="\n기록된 정치 지출: "+str(snap.recorded_politics_expense) if snap.has("recorded_politics_expense") else "\n정치 지출: 적용 대상 기록 없음"
 if life.get("start_basis","")=="legacy_scenario_january": statistics+="\n구저장 경과 개월은 시나리오 1월 시작을 가정한 추정치입니다."
 return "%s · %s\n%d년 %d월 · 경과 %d개월\n\n%s\n목표 직접 점유 %d/%d\n남은 도시 %d · 병력 %d명 · 국고 %s\n\n%s\n통계는 저장에 남은 기록 범위이며 미기록 과거를 추정하지 않습니다.\n새 보상이나 점수는 지급하지 않습니다.\n결과 ID: %s" % [names.get(life.definition.scenario_id,life.definition.scenario_id),names.get(life.definition.faction_id,life.definition.faction_id),int((int(result.month)-1)/12.0),((int(result.month)-1)%12)+1,result.elapsed_months,result.evaluation.reason,result.evaluation.achieved.size(),life.definition.targets.size(),snap.cities.size(),snap.troops,str(snap.treasury),statistics,result.result_id]
