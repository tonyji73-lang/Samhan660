extends RefCounted

# Common validators may normalize legacy dictionaries. Quote only an isolated copy.
static func model(c: Node, city: String, uid: String, selected_trainer: String) -> Dictionary:
	var s: Dictionary=c.strategy_state.duplicate(true)
	var provinces: Dictionary=c.provinces.duplicate(true)
	var actor: String=c.player_faction_id
	var stamp: int=c.year*12+c.month
	var out: Dictionary={"text":"", "parallel":false,"training":{},"steps":[]}
	var access: Dictionary=c.Economy.validate(s,provinces,actor,actor,city)
	if not access.ok: out.text=access.reason; return out
	var u: Dictionary=c.Army.units(s).get(uid,{})
	if u.is_empty() or u.location!=city or u.faction_id!=actor:
		out.text="준비할 아군 주둔 부대를 선택하세요. 모집 화면에서 보병을 모집할 수 있습니다."; return out
	if u.kind!="infantry": out.text="첫 보병 준비 안내입니다. 보병 부대를 선택하세요."; return out
	var missing: int=maxi(0,int(u.troops)-int(u.equipment))
	var needed: int=ceili(float(missing)/int(c.Army.RULES.bundle_persons))
	var stock: int=c.ProductionSystem.get_stock(s,provinces,city,"sword")
	var job: Dictionary=c.Army.training_job(s,uid)
	var trainer: String=selected_trainer if not selected_trainer.is_empty() else str(job.get("officer_id",""))
	var tq: Dictionary=c.Army.training_quote(s,provinces,actor,uid,trainer,stamp)
	out.training=tq
	var lines: Array[String]=["군사 준비 · %s / %s · 병력 %d명" % [provinces[city].name,uid,u.troops],"장비 부족 %d명분 (%d묶음) · 도시 재고 %d묶음" % [missing,needed,stock]]
	if missing==0: lines.append("장비 충족 · 추가 지급 불필요")
	else:
		var available: int=mini(needed,stock)
		var eq: Dictionary=c.Army.equip_quote(s,provinces,actor,uid,maxi(1,available))
		lines.append("지금 지급 가능: 수량을 %d묶음으로 선택 후 장비 지급" % available if available>0 and eq.ok else "지급 대기: "+str(eq.reason))
	var level: float=c.Army.training(u)
	if level>=c.Army.RULES.target:
		lines.append("훈련 %.1f · 목표 %d 도달" % [level,c.Army.RULES.target])
	elif tq.ok:
		var months: int=ceili((float(c.Army.RULES.target)-level)/int(tq.gain))
		lines.append("훈련 %.1f → %.1f · %s · %s\n월 금%d · 현재 조건 예상 잔여%d개월 / 금%d · 다음 월부터 처리" % [level,tq.next_training,c.get_officer(trainer).name,"진행 중" if not job.is_empty() else "지금 시작 가능",tq.cost,months,months*int(tq.cost)])
	else: lines.append("훈련 %.1f · %s" % [level,tq.reason])
	if not job.is_empty() and trainer!=str(job.officer_id): lines.append("현재 훈련 담당: "+str(c.get_officer(job.officer_id).get("name","미지정"))+" · 위 견적은 선택한 교체 후보 기준")
	var candidates: Array[String]=[]
	var ids: Array=c.get_city_officer_ids(city)
	for oid: String in ids:
		if c.Army.training_quote(s,provinces,actor,uid,oid,stamp).ok: candidates.append(str(c.get_officer(oid).name))
	if not tq.ok and level<c.Army.RULES.target and not candidates.is_empty(): lines.append("훈련 가능 담당자: "+", ".join(candidates))
	var parallel_tasks: Array[String]=[]
	if missing>0 and stock>=needed: lines.append("도시 재고로 장비 충족 가능 · 지급에 추가 건설·연구는 필요하지 않습니다.")
	lines.append("자체 생산 조건 · 재고가 부족할 때 확인")
	for requirement: String in ["smelter","forge","basic_smelting","swordsmithing"]:
		var kind: String="build" if requirement in ["smelter","forge"] else "research"
		var defs: Dictionary=c.SamhanStrategySystems.BUILDING_DEFS if kind=="build" else c.SamhanStrategySystems.RESEARCH_DEFS
		var name: String=defs[requirement].name
		var levels: Dictionary=s.province_buildings.get(city,{}) if kind=="build" else s.faction_research.get(c.player_faction,{})
		if int(levels.get(requirement,0))>=1:
			lines.append(name+" 완료"); continue
		var active: Dictionary=c.Industry.active(s,kind,city,actor)
		var row: Dictionary={"kind":kind,"requirement":requirement,"ready":false}
		if not active.is_empty() and active.requirement_id==requirement:
			var reason: String=c.Industry.staff_reason(s,provinces,actor,active.city_id,active.officer_id,stamp,active.id)
			var p: Dictionary=c.get_officer(active.officer_id)
			row.ready=active.status=="pending" and reason.is_empty()
			if row.ready:
				lines.append("%s 진행 %d/%d · %s · 월 작업%d · 예상 잔여%d개월" % [name,active.progress,active.required,p.name,c.Industry.effective_work(s,active.city_id,p,kind),c.Industry.remaining_months(s,active.city_id,p,kind,int(active.required)-int(active.progress))])
				if active.officer_id!=trainer: parallel_tasks.append(name+" 진행 중")
			else: lines.append(name+" 보류: "+("업무 재개 필요" if reason.is_empty() else reason))
		else:
			var q: Dictionary=c.Industry.quote(s,provinces,c.strategy,actor,city,kind,requirement,"",stamp,c.scenario_id,c.iron_supply_rules)
			for oid: String in ids:
				if oid==trainer and tq.ok: continue
				var choice: Dictionary=c.Industry.quote(s,provinces,c.strategy,actor,city,kind,requirement,oid,stamp,c.scenario_id,c.iron_supply_rules)
				if choice.ok and (not q.ok or int(choice.months)<int(q.months)): q=choice
			row.ready=q.ok
			if q.ok:
				lines.append("%s 접수 가능 · %s · 금%d · 월 작업%d / 필요%d · 예상%d개월" % [name,q.person.name,q.gold_cost,q.work,q.required,q.months])
				if c.Economy.balance(s,actor)>=int(q.gold_cost)+int(tq.get("cost",0)): parallel_tasks.append(name+" 접수 ("+str(q.person.name)+")")
			else: lines.append(name+" 필요: "+str(q.reason))
		out.steps.append(row)
	var forecasts: Dictionary=c.ProductionSystem.city_quote(s,provinces,city,stamp+1,c.scenario_id,c.iron_supply_rules)
	# Training is paid before production in the monthly pipeline. Requote with that
	# fee reserved, without assigning jobs or pretending unavailable staff are free.
	if tq.ok:
		if missing>0 and stock>=needed and c.Army.equip_quote(s,provinces,actor,uid,needed).ok: parallel_tasks.push_front("보유 장비 지급")
		s.faction_economy.accounts[actor].balance-=int(tq.cost)
		forecasts=c.ProductionSystem.city_quote(s,provinces,city,stamp+1,c.scenario_id,c.iron_supply_rules)
		lines.append("훈련비 금%d를 먼저 고려한 생산 견적" % tq.cost)
		if forecasts.forge.batches.has("iron_sword"): parallel_tasks.append("무기 생산")
	for facility: String in ["smelter","forge"]:
		var f: Dictionary=forecasts[facility]
		lines.append("%s · 다음 월 예상 %d배치 / 금%d · 작업%d (잔여%d) · %s" % ["철 조달" if facility=="smelter" else "무기 생산",f.batches.size(),f.gold_cost,f.work,f.remainder_before,"가동" if f.reason.is_empty() else f.reason])
	if missing>0 and tq.ok and not parallel_tasks.is_empty():
		out.parallel=true
		lines.append("병행 가능: "+parallel_tasks[0]+" + "+str(c.get_officer(trainer).name)+" 훈련 · 장비를 기다리지 않고 훈련할 수 있습니다.")
	elif level>=c.Army.RULES.target: lines.append("훈련 준비 완료 · 남은 장비 확보/지급 상태를 확인하세요." if missing>0 else "장비·훈련 준비 완료")
	elif missing==0: lines.append("장비 준비 완료 · 훈련 조건을 확인하세요.")
	else: lines.append("병행 가능 미확인: 훈련 담당·업무 충돌·선행 업무/가동·국고 조건을 확인하세요.")
	lines.append("현재 조건에 따른 예상입니다. 다른 지출·군량·담당 변경에 따라 달라집니다. 전체 완료일은 선행 업무와 재료 확보 후 다시 확인하세요.")
	out.text="\n".join(lines)
	return out
