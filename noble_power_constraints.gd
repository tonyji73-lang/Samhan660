extends RefCounted
const Core=preload("res://noble_politics.gd")
const RULES={"threshold":40.0,"minimum_gold":100,"city_months":2,"unit_months":1,"work_factor":0.8}
static var context: WeakRef
static var applying: bool=false
static func bind(c: Node) -> void: context=weakref(c)
static func live(r: Dictionary) -> Node:
 var c: Node=context.get_ref() if context!=null else null
 return c if is_instance_valid(c) and is_same(c.officer_registry,r) else null
static func db(s: Dictionary) -> Dictionary:
 var p: Dictionary=s.get("officer_registry",{}).get("politics",{})
 if p.is_empty(): return {}
 if not p.has("power_transfers"): p.power_transfers={"version":1,"next_id":1,"requests":{},"history":[],"cities":{},"units":{},"ai_month":-1}
 return p.power_transfers
static func records(s: Dictionary) -> Dictionary: return s.get("officer_registry",{}).get("politics",{}).get("power_transfers",{})
static func open_request(s: Dictionary, kind: String, target: String) -> Dictionary:
 for row: Dictionary in records(s).get("requests",{}).values():
  if row.status not in ["offered","waiting","successor_needed"]: continue
  if (row.request.kind==kind and row.request.target==target) or (kind=="commander" and row.get("units",[]).has(target)): return row
 return {}
static func unit_reason(s: Dictionary, id: String) -> String:
 var e: Dictionary=records(s).get("units",{}).get(id,{})
 return "군권 인계 차질 · 다음 %d회 월 처리 후 출정·훈련 재개" % int(e.remaining) if int(e.get("remaining",0))>0 and e.get("faction_id","")==s.get("unit_rosters",{}).get(id,{}).get("faction_id","") else ""
static func city_factor(s: Dictionary, city: String) -> float:
 return float(RULES.work_factor) if int(records(s).get("cities",{}).get(city,{}).get("remaining",0))>0 else 1.0
static func mean_income(c: Node, faction: String) -> Dictionary:
 var totals: Dictionary={}; var completed: int=c.year*12+c.month-int(c.ending_busy)
 for e: Dictionary in c.strategy_state.faction_economy.entries:
  if e.faction_id==faction and e.reason in ["tax","trade"] and int(e.amount)>=0 and int(e.month)<=completed: totals[int(e.month)]=int(totals.get(int(e.month),0))+int(e.amount)
 var months: Array=totals.keys(); months.sort(); months.reverse()
 var sum: float=0
 for n: int in range(mini(3,months.size())): sum+=totals[months[n]]
 if not months.is_empty(): return {"value":sum/mini(3,months.size()),"basis":"최근 완료 월의 실제 도시·통상 세입(일회성/환불 제외)","months":months.slice(0,3)}
 for city: String in c.Economy.city_ids(c.strategy_state,c.provinces):
  if c.Economy.resolve(c.strategy_state,c.provinces[city].faction)==faction: sum+=int(c.city_operation_quote(city).tax)
 return {"value":sum,"basis":"완료 세입 기록 없음: 현재 공통 세입 견적","months":[]}
static func validate(c: Node, req: Dictionary) -> Dictionary:
 var s: Dictionary=c.strategy_state; var r: Dictionary=c.officer_registry
 if c.Ending.finished(s): return {"ok":false,"reason":c.Ending.BLOCKED}
 var kind: String=req.kind; var target: String=req.target; var actor: String=req.faction_id
 var u: Dictionary=s.unit_rosters.get(target,{})
 var city: String=target if kind=="governor" else str(u.get("location",""))
 var access: Dictionary=c.Economy.validate(s,c.provinces,actor,actor,city)
 if not access.ok: return access
 if kind!="governor" and (u.is_empty() or u.status!="stationed" or int(u.troops)<=0): return {"ok":false,"reason":"실제 아군 주둔 부대가 필요합니다."}
 var successor: String=str(req.get("officer_id",""))
 if kind in ["governor","commander"] and not successor.is_empty():
  if not c.OfficerRegistry.eligible(r,successor,c.provinces,city) or r.people[successor].faction_id!=actor: return {"ok":false,"reason":"후임 재지정 필요: 같은 도시의 생존·활동 가능한 아군 인물"}
  if kind=="governor":
   for post: String in r.posts:
    if post.begins_with("governor:") and post!="governor:"+city and r.posts[post]==successor: return {"ok":false,"reason":"후임 재지정 필요: 다른 도시 태수"}
  elif not c.OfficerRegistry.action_available(r,successor,c.provinces,"attack",city): return {"ok":false,"reason":"후임 재지정 필요: 업무·사절·이동 충돌"}
 if kind=="disband" and (int(req.get("amount",0))<=0 or int(req.amount)>int(u.troops)): return {"ok":false,"reason":"해산 인원 변경: 다시 요청하세요."}
 if kind=="merge":
  var b: Dictionary=s.unit_rosters.get(str(req.get("source","")),{})
  if b.is_empty() or b.faction_id!=actor or b.status!="stationed" or b.location!=city or b.kind!=u.kind or b.id==u.id or not c.Army.training_job(s,b.id).is_empty() or not c.Army.training_job(s,u.id).is_empty(): return {"ok":false,"reason":"합류 부대 상태가 바뀌었습니다."}
 return {"ok":true,"reason":"","city":city}
static func quote(c: Node, req: Dictionary) -> Dictionary:
 var valid: Dictionary=validate(c,req)
 if not valid.ok: return valid
 var s: Dictionary=c.strategy_state; var r: Dictionary=c.officer_registry; var kind: String=req.kind; var target: String=req.target; var successor: String=str(req.get("officer_id",""))
 var result: Dictionary={"ok":true,"required":false,"reason":"","request":req.duplicate(true),"city":valid.city,"losses":[],"units":[],"gold":0,"months":1,"old_ids":[]}
 if not r.has("politics") or r.politics.faction_id!=req.faction_id: return result
 var shadow: Dictionary=s.duplicate(true)
 var old: String=str(r.posts.get("governor:"+target,"")) if kind=="governor" else str(s.unit_rosters[target].commander_id)
 if kind=="governor": shadow.officer_registry.posts["governor:"+target]=successor
 elif kind=="commander":
  for uid: String in shadow.unit_rosters:
   var u: Dictionary=shadow.unit_rosters[uid]
   if uid==target or (not successor.is_empty() and u.commander_id==successor):
    result.units.append(uid); u.commander_id=successor if uid==target else ""
 elif kind=="disband": shadow.unit_rosters[target].troops=int(shadow.unit_rosters[target].troops)-int(req.amount); result.units=[target]
 elif kind=="merge":
  var source: String=req.source; shadow.unit_rosters[target].troops+=int(shadow.unit_rosters[source].troops); shadow.unit_rosters[source].troops=0; result.units=[target,source]; old=str(s.unit_rosters[source].commander_id); successor=str(s.unit_rosters[target].commander_id)
 else: return {"ok":false,"reason":"지원하지 않는 인사 명령"}
 var shadow_provinces: Dictionary=c.provinces.duplicate(true)
 if kind=="disband": shadow_provinces[valid.city].population+=int(req.amount)
 var before: Dictionary=Core.influence(s,c.provinces,req.faction_id); var after: Dictionary=Core.influence(shadow,shadow_provinces,req.faction_id)
 var income: Dictionary=mean_income(c,req.faction_id); result["income"]=income
 for gid: String in before.groups:
  var a: Dictionary=before.groups[gid]; var b: Dictionary=after.groups[gid]
  if r.politics.groups[gid].royal or float(a.influence)<float(RULES.threshold) or (int(a.troops)<=int(b.troops) and int(a.population)<=int(b.population)): continue
  var delta: float=maxf(0,float(a.influence)-float(b.influence))
  var retiree: String=old if Core.group(r,old)==gid else successor
  if retiree.is_empty(): retiree=str(r.politics.groups[gid].representative)
  var person: Dictionary=r.people[retiree]; var loyalty: int=int(person.get("loyalty",50)); var ambition: int=int(person.get("ambition",50))
  var factor: float=clampf(1+float(ambition-loyalty)/200,0.75,1.25)
  var fee: int=ceili(maxf(float(RULES.minimum_gold),float(income.value)*delta/100*(1+float(a.influence)/100)*factor)/10)*10
  var duration: int=clampi((3 if float(a.influence)>=60 else 2)-int(loyalty>=80)+int(ambition>=80),1,4)
  result.losses.append({"group_id":gid,"officer_id":retiree,"I":a.influence,"D":delta,"after":b.influence,"population_lost":maxi(0,int(a.population)-int(b.population)),"troops_lost":maxi(0,int(a.troops)-int(b.troops)),"loyalty":loyalty,"ambition":ambition,"F":factor,"gold":fee,"months":duration})
  result.gold+=fee; result.months=maxi(result.months,duration); result.old_ids.append(retiree)
 result.required=not result.losses.is_empty(); result["previous_id"]=old; result["successor_id"]=successor
 return result
static func intercept(c: Node, req: Dictionary) -> Dictionary:
 if applying: return {"ok":true}
 var existing: Dictionary=open_request(c.strategy_state,req.kind,req.target)
 if not existing.is_empty():
  if req.faction_id==c.player_faction_id and c.has_method("show_power_transfer"): c.show_power_transfer.call_deferred(existing.id)
  return {"ok":false,"reason":"진행 중인 권력 인계 협의를 완료하거나 철회하세요.","negotiation_id":existing.id}
 var q: Dictionary=quote(c,req)
 if not q.ok or not q.required: return q
 var data: Dictionary=db(c.strategy_state); var id: String="handover:%d" % int(data.next_id); data.next_id+=1
 q.merge({"id":id,"status":"offered","created_month":c.year*12+c.month,"due_month":-1,"choice":"","cost_paid":0,"applied":false})
 data.requests[id]=q
 # A pending demand for the same authority is superseded without gift/reaction.
 var pending: Dictionary=c.officer_registry.politics.pending
 if not pending.is_empty() and pending.kind==req.kind and pending.target==req.target:
  c.officer_registry.politics.resolved[pending.occurrence_id]={"month":c.year*12+c.month,"choice":"superseded","reason":"권력 인계 협의 우선"}; c.officer_registry.politics.pending={}
 if req.faction_id==c.player_faction_id: c.show_power_transfer.call_deferred(id)
 return {"ok":false,"reason":"권력 인계 협의 필요 · 선택 전에는 비용·직책 변화 없음","negotiation_id":id}
static func guard_post(r: Dictionary, post: String, id: String, reason: String) -> bool:
 var c: Node=live(r)
 if c==null or applying or not post.begins_with("governor:") or reason not in ["임명/해임","해임","왕명 인사"]: return true
 return intercept(c,{"kind":"governor","target":post.trim_prefix("governor:"),"officer_id":id,"faction_id":c.Economy.resolve(c.strategy_state,c.provinces.get(post.trim_prefix("governor:"),{}).get("faction",""))}).ok
static func stale(c: Node, row: Dictionary) -> String:
 var at: String=row.city
 if row.request.kind!="governor":
  var unit: Dictionary=c.strategy_state.unit_rosters.get(row.request.target,{})
  if unit.get("faction_id","")!=row.request.faction_id: return "부대 소속 상실 · 협의 종료"
  at=str(unit.get("location","")) if unit.get("status","")=="stationed" else ""
 if not at.is_empty() and c.Economy.resolve(c.strategy_state,c.provinces.get(at,{}).get("faction",""))!=row.request.faction_id: return "현재 거점 상실 · 환불 없이 협의 종료"
 for id: String in row.old_ids:
  var p: Dictionary=c.officer_registry.people.get(id,{})
  if p.is_empty() or not p.alive or not p.active: return "퇴임 대상 사망·활동 자격 상실 · 왕명 불이익 없음"
 if row.request.kind=="governor":
  if c.officer_registry.posts.get("governor:"+row.request.target,"")!=row.previous_id: return "직책이 이미 변경됨 · 재적용 없음"
 else:
  for uid: String in row.units:
   if not c.strategy_state.unit_rosters.has(uid) or int(c.strategy_state.unit_rosters[uid].troops)<=0: return "대상 부대 소멸 · 인계 종료"
 return ""
static func resolve(c: Node, id: String, choice: String) -> Dictionary:
 if c.Ending.finished(c.strategy_state): return {"ok":false,"reason":c.Ending.BLOCKED}
 var data: Dictionary=db(c.strategy_state); var row: Dictionary=data.get("requests",{}).get(id,{})
 if row.is_empty() or row.status not in ["offered","waiting","successor_needed"]: return {"ok":false,"reason":"이미 종료된 협의"}
 if choice=="withdraw": row.status="withdrawn"; row["reason"]="권력 유지 · 미실행 인사 효과 없음"; return {"ok":true,"reason":row.reason}
 var invalid: String=stale(c,row)
 if not invalid.is_empty(): row.status="invalid"; row["reason"]=invalid; return {"ok":false,"reason":invalid}
 if choice=="wait" and row.status=="offered":
  row.choice=choice; row.status="waiting"; row.due_month=c.year*12+c.month+int(row.months); return {"ok":true,"reason":"기존 권한 유지 · 인계 예정 월 %d" % int(row.due_month)}
 if choice not in ["compensate","force","complete"]: return {"ok":false,"reason":"선택을 확인하세요."}
 if choice=="complete" and (row.due_month<0 or c.year*12+c.month<int(row.due_month)): return {"ok":false,"reason":"인계 기한 전"}
 var valid: Dictionary=validate(c,row.request)
 if not valid.ok:
  if row.status!="offered": row.status="successor_needed"
  row["reason"]=valid.reason; return valid
 var fee: int=int(row.gold) if choice=="compensate" else 0
 if not c.Economy.validate_national(c.strategy_state,row.request.faction_id,row.request.faction_id,fee).ok: return {"ok":false,"reason":"협상금 부족 · 직책·국고 유지"}
 applying=true; c.officer_registry["_power_suppress"]=true
 var outcome: Dictionary={"ok":true}; var req: Dictionary=row.request
 match str(req.kind):
  "governor": outcome.ok=c.OfficerRegistry.set_post(c.officer_registry,"governor:"+req.target,str(req.get("officer_id","")),"권력 인계")
  "commander": outcome=c.Army.appoint(c.strategy_state,c.provinces,req.faction_id,req.target,str(req.get("officer_id","")))
  "disband": outcome=c.Mobilization.disband(c.strategy_state,c.provinces,req.faction_id,req.target,int(req.amount),c.year*12+c.month)
  "merge": outcome=c.Army.merge(c.strategy_state,c.provinces,req.faction_id,req.target,req.source)
 c.officer_registry.erase("_power_suppress"); applying=false
 if not outcome.ok: return outcome
 if fee>0: c.Economy.post(c.strategy_state,req.faction_id,-fee,"politics:power_compensation",c.year*12+c.month,row.city,id+":payment")
 row.cost_paid=fee; row.applied=true; row.status="completed"; row.choice="wait" if choice=="complete" else choice; row["completed_month"]=c.year*12+c.month
 for loss: Dictionary in row.losses: Core.change(c.officer_registry,loss.officer_id,-20 if choice=="force" else -4,-12 if choice=="force" else -2,"권력 인계 "+choice,c.year*12+c.month)
 if req.kind in ["governor","commander"]:
  c.officer_registry["_power_skip_loss"]=true
  Core.reaction(c.officer_registry,row.previous_id,str(req.get("officer_id","")),true,"인계 후 임명",c.year*12+c.month)
  c.officer_registry.erase("_power_skip_loss")
 if choice=="force":
  var effect: Dictionary={"remaining":int(RULES.city_months) if req.kind=="governor" else int(RULES.unit_months),"created_month":c.year*12+c.month,"last_month":-1,"faction_id":req.faction_id,"request_id":id}
  if req.kind=="governor": data.cities[row.city]=effect
  else:
   for uid: String in row.units: data.units[uid]=effect.duplicate(true)
 data.history.append({"request_id":id,"month":c.year*12+c.month,"choice":choice,"request":req.duplicate(true),"cost":fee,"losses":row.losses.duplicate(true)})
 c._sync_officer_labels(); c.Army.sync(c.strategy_state,c.provinces); c.update_top_bar()
 return {"ok":true,"reason":"인계 완료 · 금 %d · %s" % [fee,choice]}
static func retarget(c: Node, id: String, officer: String) -> Dictionary:
 var row: Dictionary=records(c.strategy_state).get("requests",{}).get(id,{})
 if c.Ending.finished(c.strategy_state) or row.is_empty() or row.status not in ["waiting","successor_needed"]: return {"ok":false,"reason":"후임 변경 가능한 협의가 아닙니다."}
 var req: Dictionary=row.request.duplicate(true); req.officer_id=officer
 var valid: Dictionary=validate(c,req)
 if not valid.ok: return valid
 for loss: Dictionary in row.losses:
  if Core.group(c.officer_registry,officer)==loss.group_id: return {"ok":false,"reason":"같은 집단의 권한 유지라면 협의를 철회하세요."}
 row.request=req; row.status="waiting"; row["reason"]="후임 변경 · 기존 기한 유지"
 if int(row.due_month)<=c.year*12+c.month: return resolve(c,id,"complete")
 return {"ok":true,"reason":row.reason}
static func begin_month(c: Node) -> void:
 if c.Ending.finished(c.strategy_state): return
 for row: Dictionary in records(c.strategy_state).get("requests",{}).values():
  if row.status not in ["offered","waiting","successor_needed"]: continue
  var reason: String=stale(c,row)
  if not reason.is_empty(): row.status="invalid"; row["reason"]=reason
  elif row.status in ["waiting","successor_needed"] and int(row.due_month)<=c.year*12+c.month: resolve(c,row.id,"complete")
static func finish_month(c: Node) -> void:
 if c.Ending.finished(c.strategy_state): return
 var stamp: int=c.year*12+c.month
 for category: String in ["cities","units"]:
  for e: Dictionary in records(c.strategy_state).get(category,{}).values():
   if int(e.remaining)>0 and int(e.created_month)<stamp and int(e.last_month)<stamp: e.remaining-=1; e.last_month=stamp
static func formation_reason(s: Dictionary, id: String) -> String:
 return "권력 인계 협의 중인 부대는 완료·철회 후 편성을 변경하세요." if not open_request(s,"commander",id).is_empty() else ""
static func inherit(s: Dictionary, parent: String, child: String) -> void:
 if records(s).get("units",{}).has(parent): db(s).units[child]=records(s).units[parent].duplicate(true)
static func ai(c: Node) -> void:
 if c.Ending.finished(c.strategy_state) or not c.officer_registry.has("politics") or c.player_faction_id==c.officer_registry.politics.faction_id: return
 var data: Dictionary=db(c.strategy_state); var stamp: int=c.year*12+c.month
 if int(data.get("ai_month",-1))>=stamp: return
 data.ai_month=stamp
 var open: bool=data.requests.values().any(func(row): return row.status in ["offered","waiting","successor_needed"])
 if not open and stamp-int(data.get("last_nomination",-100))>=6:
  var faction: String=c.officer_registry.politics.faction_id
  var chosen: Dictionary={}; var gain: int=9
  for city: String in c.Economy.city_ids(c.strategy_state,c.provinces):
   if c.Economy.resolve(c.strategy_state,c.provinces[city].faction)!=faction: continue
   var old: String=str(c.officer_registry.posts.get("governor:"+city,""))
   if old.is_empty(): continue
   for candidate: String in c.get_city_officer_ids(city):
    var difference: int=int(c.get_officer(candidate).get("politics",0))-int(c.get_officer(old).get("politics",0))
    if difference<=gain: continue
    var req: Dictionary={"kind":"governor","target":city,"officer_id":candidate,"faction_id":faction}
    var q: Dictionary=quote(c,req)
    if q.ok and q.required: chosen=req; gain=difference
  if not chosen.is_empty():
   data.last_nomination=stamp; intercept(c,chosen)
 for row: Dictionary in records(c.strategy_state).get("requests",{}).values():
  if row.status!="offered": continue
  var newp: Dictionary=c.get_officer(str(row.request.get("officer_id",""))); var oldp: Dictionary=c.get_officer(row.previous_id)
  var attribute: String="politics" if row.request.kind=="governor" else "leadership"
  var choice: String="wait"
  var front: bool=c.province_connections.get(row.city,[]).any(func(city): return c.Economy.resolve(c.strategy_state,c.provinces.get(city,{}).get("faction",""))!=row.request.faction_id)
  if int(newp.get(attribute,0))<=int(oldp.get(attribute,0)): choice="withdraw"
  elif c.Economy.balance(c.strategy_state,row.request.faction_id)>=int(row.gold)+300: choice="compensate"
  elif not front and row.request.kind=="commander" and int(newp.get(attribute,0))-int(oldp.get(attribute,0))>=20: choice="force"
  var result: Dictionary=resolve(c,row.id,choice)
  db(c.strategy_state).history.append({"month":c.year*12+c.month,"ai_choice":choice,"request_id":row.id,"front":front,"result":result})
static func describe(c: Node, row: Dictionary) -> String:
 var lines: Array[String]=["권력 인계 협의 · "+str(c.provinces.get(row.city,{}).get("name",row.city)),"실제 인계가 완료되었습니다." if row.get("applied",false) else "기존 권한은 선택·실제 인계 전까지 유지됩니다."]
 lines.append("담당자: %s → %s" % [c.get_officer(str(row.previous_id)).get("name","공석"),c.get_officer(str(row.request.get("officer_id",""))).get("name","공석")])
 lines.append("협의 접수 당시 견적:")
 for loss: Dictionary in row.losses:
  lines.append("%s: 영향력 %.2f → %.2f (감소 %.2f) · 관할 인구 -%d / 지휘 병력 -%d\n충성 %d · 야망 %d · 조정 F %.2f" % [c.officer_registry.politics.groups[loss.group_id].name,loss.I,loss.after,loss.D,loss.population_lost,loss.troops_lost,loss.loyalty,loss.ambition,loss.F])
 lines.append("세입 M %.1f · %s\n협상금 %d (금10 올림, 최소100) · 보장 기간 %d개월" % [row.income.value,row.income.basis,row.gold,row.months])
 if not row.get("applied",false):
  lines.append("A 보상: 금%d, 즉시 인계, 퇴임 충성 -4 / 집단 협력 -2\nB 기한: 금0, 기존 담당 유지 후 인계, 퇴임 -4 / 집단 -2\nC 강제: 금0, 즉시 인계, 퇴임 -20 / 집단 -12" % row.gold)
  lines.append("강제 차질: 도시 다음2회 월 결산 태수 보너스 없음·건설/생산80%" if row.request.kind=="governor" else "강제 차질: 다음1회 월 처리까지 해당 병력 공격·훈련 중단. 방어·아군 이동 허용")
  lines.append("후임 임명 효과는 기존 충성·협력 규칙과 보상 간격을 적용합니다.")
 lines.append("상태: %s · %s %s · %s" % [status_name(str(row.get("status","견적"))),"완료 월" if row.get("applied",false) else "예정 월",date(int(row.completed_month)) if row.get("applied",false) else (date(int(row.due_month)) if int(row.get("due_month",-1))>0 else date(c.year*12+c.month+int(row.months))),str(row.get("reason",""))])
 if row.get("applied",false): lines.append("실제 납부 금 %d · 인계 완료 %s" % [row.cost_paid,date(int(row.completed_month))])
 for loss: Dictionary in row.losses:
  var person: Dictionary=c.get_officer(loss.officer_id)
  lines.append("현재 %s 충성 %d · %s 협력 %d" % [person.get("name",loss.officer_id),person.get("loyalty",0),c.officer_registry.politics.groups[loss.group_id].name,c.officer_registry.politics.groups[loss.group_id].cooperation])
 var next_person: Dictionary=c.get_officer(str(row.request.get("officer_id","")))
 if not next_person.is_empty(): lines.append("현재 후임 %s 충성 %d" % [next_person.get("name",""),next_person.get("loyalty",0)])
 if row.request.kind!="governor":
  var blocked: Array[String]=[]
  for uid: String in row.units:
   var reason: String=unit_reason(c.strategy_state,uid)
   if not reason.is_empty(): blocked.append(uid+": "+reason)
  lines.append("현재 부대 인계 차질 없음 · 출정·훈련은 일반 자격/군량 조건 적용" if blocked.is_empty() else "\n".join(blocked))
 lines.append(summary(c.strategy_state,row.city))
 return "\n".join(lines)
static func move_reason(c: Node, req: Dictionary) -> String:
 if applying: return ""
 var ids: Array=req.get("unit_ids",[])
 if ids.is_empty() and int(req.get("troops",0))>0: ids=c.Army.at_city(c.strategy_state,str(req.source_id),"",true).filter(func(id): return not req.get("excluded_unit_ids",[]).has(id))
 var remaining: int=int(req.get("troops",0)); var people: Array=req.get("officer_ids",[])
 for uid: String in ids:
  if remaining<=0: break
  var u: Dictionary=c.strategy_state.unit_rosters[uid]
  if remaining<int(u.troops) and not str(u.commander_id).is_empty(): return "지휘 병력의 부분 지원은 먼저 부대를 분할한 뒤 인계할 부대를 선택하세요. 병력·직책은 변경하지 않았습니다."
  remaining-=int(u.troops)
  if not str(u.commander_id).is_empty() and not people.has(str(u.commander_id)):
   var result: Dictionary=intercept(c,{"kind":"commander","target":uid,"officer_id":"","faction_id":u.faction_id})
   if not result.ok: return "지휘권이 바뀌는 지원: "+result.reason+". 부분 병력만 넘기려면 같은 지휘관으로 먼저 분할하세요."
 for person: String in people:
  for post: String in c.officer_registry.posts:
   if post.begins_with("governor:") and c.officer_registry.posts[post]==person:
    var result: Dictionary=intercept(c,{"kind":"governor","target":post.trim_prefix("governor:"),"officer_id":"","faction_id":c.officer_registry.people[person].faction_id})
    if not result.ok: return result.reason
  for u: Dictionary in c.strategy_state.unit_rosters.values():
   if u.commander_id==person and int(u.troops)>0 and u.status=="stationed" and not ids.has(u.id):
    var result: Dictionary=intercept(c,{"kind":"commander","target":u.id,"officer_id":"","faction_id":u.faction_id})
    if not result.ok: return result.reason
 return ""
static func location_reason(r: Dictionary, id: String, city: String, transit: bool) -> String:
 var c: Node=live(r); var p: Dictionary=r.people.get(id,{})
 if c==null or applying or p.is_empty() or not p.alive or not p.active or (p.location==city and not transit): return ""
 for post: String in r.posts:
  if post.begins_with("governor:") and r.posts[post]==id and c.Economy.resolve(c.strategy_state,c.provinces.get(post.trim_prefix("governor:"),{}).get("faction",""))==p.faction_id:
   var result: Dictionary=intercept(c,{"kind":"governor","target":post.trim_prefix("governor:"),"officer_id":"","faction_id":p.faction_id})
   if not result.ok: return "태수 권한을 회수하는 이동: "+result.reason
 for u: Dictionary in c.strategy_state.unit_rosters.values():
  if u.commander_id==id and u.status=="stationed" and int(u.troops)>0 and c.Economy.resolve(c.strategy_state,c.provinces.get(u.location,{}).get("faction",""))==p.faction_id:
   var result: Dictionary=intercept(c,{"kind":"commander","target":u.id,"officer_id":"","faction_id":p.faction_id})
   if not result.ok: return "지휘권을 남기는 장수 이동: "+result.reason
 return ""

static func capture(s: Dictionary, city: String) -> void:
 var e: Dictionary=records(s).get("cities",{}).get(city,{})
 if not e.is_empty(): e.remaining=0; e["reason"]="도시 점령: 이전 국가 차질 종료"
static func date(stamp: int) -> String:
 return "%d년 %d월" % [floori(float(stamp-1)/12),(stamp-1)%12+1]
static func summary(s: Dictionary, city: String="", unit: String="") -> String:
 var lines: Array[String]=[]
 for row: Dictionary in records(s).get("requests",{}).values():
  if row.status not in ["offered","waiting","successor_needed"]: continue
  if not city.is_empty() and row.city!=city: continue
  if not unit.is_empty() and not row.units.has(unit): continue
  lines.append("인계 %s · %s · %s → %s · %s" % [row.id,row.status,row.previous_id,row.request.get("officer_id","공석"),date(int(row.due_month)) if int(row.due_month)>0 else "방식 선택 필요"])
 if not city.is_empty():
  var e: Dictionary=records(s).get("cities",{}).get(city,{})
  if int(e.get("remaining",0))>0: lines.append("도시 인계 차질: 남은 %d회 결산 · 태수 보너스 없음 · 건설/생산 80%%" % e.remaining)
 if not unit.is_empty() and not unit_reason(s,unit).is_empty(): lines.append(unit_reason(s,unit))
 return "\n".join(lines)
static func status_name(status: String) -> String:
 return {"offered":"선택 대기","waiting":"기한 보장 중","successor_needed":"후임 재지정 필요","completed":"인계 완료","withdrawn":"철회","invalid":"유효성 상실"}.get(status,status)
static func attack_reason(c: Node, city: String, commander: String) -> String:
 if not c.officer_registry.has("politics"): return ""
 var actor: String=c.Economy.resolve(c.strategy_state,c.provinces[city].faction)
 if actor!=c.officer_registry.politics.faction_id: return ""
 for uid: String in c.Army.attack_units(c.strategy_state,city,actor):
  var previous: String=c.strategy_state.unit_rosters[uid].commander_id
  if previous.is_empty() or previous==commander: continue
  var q: Dictionary=quote(c,{"kind":"commander","target":uid,"officer_id":commander,"faction_id":actor})
  if q.get("required",false): return "출정 지휘관 변경으로 귀족 군권이 회수됩니다. 부대 화면에서 지휘관 인계를 먼저 처리하세요. 기존 담당자의 외부 업무도 확인하세요."
 return ""
