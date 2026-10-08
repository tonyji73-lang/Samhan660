extends SceneTree
const Report=preload("res://ui/living_city_v1/campaign_flow_report.gd")
const Overlay=preload("res://ui/living_city_v1/campaign_flow_overlay.gd")
const Campaign=preload("res://campaign_main.gd")
class Fixture extends Node:
	var year=632
	var month=2
	var gold=123
	var player_faction_id="silla"
	var provinces={"capital":{"name":"금성"}}
	var strategy_state={"domestic":{"jobs":{"a":{"kind":"agriculture","city_id":"capital","status":"completed","payer_faction_id":"silla","reason":"개발 완료 +5"},"b":{"kind":"research","city_id":"capital","status":"pending","faction_id":"silla","officer_id":"p","reason":""},"enemy":{"kind":"research","city_id":"capital","status":"pending","faction_id":"baekje","reason":""}}}}
	func get_officer(_id: String) -> Dictionary: return {"name":"담당자"}
var checks=0
var failures=0
func verify(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1
	print(("PASS: " if value else "FAIL: ")+label)
func _initialize() -> void:
	var c:=Fixture.new(); var initial: Dictionary=c.strategy_state.duplicate(true)
	verify(Report.jobs(c).size()==1,"current jobs exclude enemy and completed jobs")
	verify(c.strategy_state==initial,"query does not modify old save")
	var messages: Array[String]=["first","second","third","fourth","fifth","sixth","seventh"]
	Report.record(c,100,messages,{"a":{"status":"pending"}})
	var row: Dictionary=c.strategy_state.ui_month_reports[0]
	verify(row.messages.size()==7,"report keeps messages beyond old six-line limit")
	verify(row.gold_before==100 and row.gold_after==123,"actual treasury snapshots")
	verify(row.transitions.size()==2,"only own state transitions")
	messages.clear(); verify(row.messages.size()==7,"report owns immutable message snapshot")
	Report.record(c,0,[],{}); verify(c.strategy_state.ui_month_reports.size()==1,"same month is not recorded twice")
	for n: int in range(3,17): c.month=n; Report.record(c,123,[],{})
	verify(c.strategy_state.ui_month_reports.size()==12,"retention bounded to twelve months")
	verify(c.strategy_state.domestic==initial.domestic and c.gold==123,"report leaves game rules and resources unchanged")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(c.strategy_state))
	verify(restored.ui_month_reports.size()==12,"report is JSON save compatible")
	c.free(); print("V1.10 report model: %d checks / %d failures" % [checks,failures]); quit(failures)
