extends RefCounted
## Presentation history only; no command execution or economic prediction.
const KINDS={"agriculture":"농업 개발","commerce":"상업 개발","production":"생산 담당","research":"연구","build":"건설","training":"훈련"}
const STATES={"pending":"진행 중","paused":"중지","completed":"완료","cancelled":"취소"}

static func jobs(c: Node) -> Array[String]:
	var lines: Array[String]=[]
	for job: Dictionary in c.strategy_state.get("domestic",{}).get("jobs",{}).values():
		if str(job.get("faction_id",job.get("payer_faction_id","")))!=c.player_faction_id: continue
		if job.get("status","") not in ["pending","paused"]: continue
		var city: String=str(c.provinces.get(job.get("city_id",""),{}).get("name",""))
		var officer: String=str(c.get_officer(str(job.get("officer_id",""))).get("name","담당자 없음"))
		var progress: String=" · 작업량 %d/%d" % [job.progress,job.required] if job.has("required") and int(job.required)>0 else ""
		var detail: String=str(job.get("reason",""))
		lines.append("%s · %s · %s · %s%s" % [city,KINDS.get(job.kind,job.kind),officer,STATES.get(job.status,job.status),progress]+("\n"+detail if not detail.is_empty() else ""))
	return lines

static func record(c: Node, gold_before: int, messages: Array[String], before_jobs: Dictionary) -> void:
	var transitions: Array[String]=[]
	for id: String in c.strategy_state.get("domestic",{}).get("jobs",{}):
		var job: Dictionary=c.strategy_state.domestic.jobs[id]
		if str(job.get("faction_id",job.get("payer_faction_id","")))!=c.player_faction_id: continue
		var old: Dictionary=before_jobs.get(id,{})
		if old.get("status","")==job.status: continue
		transitions.append("%s · %s · %s → %s\n%s" % [c.provinces.get(job.get("city_id",""),{}).get("name",""),KINDS.get(job.kind,job.kind),STATES.get(old.get("status",""),"신규"),STATES.get(job.status,job.status),job.get("reason","")])
	if not c.strategy_state.has("ui_month_reports"): c.strategy_state["ui_month_reports"]=[]
	var reports: Array=c.strategy_state.ui_month_reports
	var stamp: int=c.year*12+c.month
	# Reopening the report never records it; protect against repeated completion callbacks.
	if not reports.is_empty() and int(reports.back().get("stamp",-1))==stamp: return
	reports.append({"stamp":stamp,"year":c.year,"month":c.month,"gold_before":gold_before,"gold_after":c.gold,"messages":messages.duplicate(),"transitions":transitions})
	while reports.size()>12: reports.pop_front()
