extends "res://tests/officer_registry_test.gd"

const D = preload("res://domestic_assignment.gd")
const RESULTS = "res://.godot/domestic-results/"
var evidence: Array=[]

func roundtrip(label: String) -> void:
	var before: Dictionary=snapshot()
	var path: String=RESULTS+label+".json"
	c._on_save_button_pressed(path)
	for n: int in range(3):
		c._on_load_button_pressed(path)
		check(snapshot()==before,label+" repeated load "+str(n))

func _run() -> void:
	create_timer(180).timeout.connect(func(): push_error("DOMESTIC TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(RESULTS)
	for faction: String in ["silla","baekje","goguryeo"]:
		await start(Scenarios.SCENARIOS[0],faction,"historical")
		var city: String={"silla":"geumseong","baekje":"sabi","goguryeo":"pyongyang"}[faction]
		ability_cases(city)
		governor_cases(city)
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	conflict_cases()
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	await actual_month_and_save()
	var file:=FileAccess.open(RESULTS+"comparisons.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t")); file.close()
	print("DOMESTIC ASSIGNMENT TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func ability_cases(city: String) -> void:
	var id: String=c.get_city_officer_ids(city)[0]
	for ability: int in [90,30]:
		Registry.set_stats(c.officer_registry,id,{"politics":ability,"intelligence":ability})
		c.provinces[city].agriculture=40; c.gold=1000
		var q: Dictionary=c.get_domestic_quote(city,"agriculture",id)
		var gain: int=5 if ability==90 else 2
		check(q.ok and q.gain==gain,c.player_faction+" ability "+str(ability)+" quote")
		var result: Dictionary=c.start_domestic(city,"agriculture",id)
		check(result.ok and c.gold==900 and c.provinces[city].agriculture==40,"100 charged once; no immediate stat change")
		check(not c.start_domestic(city,"commerce",id).ok and c.gold==900,"city and person duplicate rejected without charge")
		D.process(c.strategy_state,c.provinces,c.year*12+c.month)
		check(c.provinces[city].agriculture==40,"acceptance month cannot finish")
		Registry.set_stats(c.officer_registry,id,{"politics":1,"intelligence":1})
		D.process(c.strategy_state,c.provinces,c.year*12+c.month+1)
		check(c.provinces[city].agriculture==40+gain,"snapshot outcome applies next month")
		check(not c.cancel_domestic(result.job_id).ok and c.gold==900,"completed job cannot refund")
		D.process(c.strategy_state,c.provinces,c.year*12+c.month+1)
		check(c.provinces[city].agriculture==40+gain,"repeated processing applies no second gain")
		evidence.append({"faction":c.player_faction,"city":city,"politics":ability,"intelligence":ability,"gold_before":1000,"gold_after":c.gold,"agriculture_before":40,"agriculture_after":c.provinces[city].agriculture})
	Registry.set_stats(c.officer_registry,id,{"politics":90,"intelligence":90})
	c.provinces[city].commerce=99; c.gold=99
	check(not c.get_domestic_quote(city,"commerce",id).ok,"insufficient gold blocked")
	c.gold=1000
	check(c.get_domestic_quote(city,"commerce",id).gain==1,"actual quote clamps remaining headroom")
	var capped: Dictionary=c.start_domestic(city,"commerce",id)
	D.process(c.strategy_state,c.provinces,c.year*12+c.month+1)
	check(c.provinces[city].commerce==100 and not c.get_domestic_quote(city,"commerce",id).ok and c.gold==900,"cap applied and future charge blocked")
	check(D.ensure(c.strategy_state).jobs[capped.job_id].applied_gain==1,"receipt records actual gain")
	c.provinces[city].commerce=50

func governor_cases(city: String) -> void:
	var id: String=c.get_city_officer_ids(city)[0]
	c.provinces[city].merge({"population":100000,"agriculture":50,"commerce":50,"public_order":100},true)
	c.dismiss_governor(city)
	check(c.city_operation_quote(city).tax==100 and c.city_operation_quote(city).annual_harvest==5000,"vacancy uses original base")
	Registry.set_stats(c.officer_registry,id,{"politics":80})
	check(c._apply_governor_appointment(city,id).ok,"governor assigned through actual authority validation")
	var q: Dictionary=c.city_operation_quote(city)
	check(q.tax==116 and q.annual_harvest==5800,"politics80 gives 16 percent once to tax and harvest")
	var task: Dictionary=c.start_domestic(city,"commerce",id)
	check(task.ok and c.get_governor_id(city)==id and c.city_operation_quote(city).tax==116,"governor can work locally without losing governor bonus")
	check(c.cancel_domestic(task.job_id).ok and c.gold==900,"normal cancel returns its 100")
	check(not c.cancel_domestic(task.job_id).ok and c.gold==900,"second cancel cannot refund")
	var replacement: String=c.get_city_officer_ids(city)[1]
	Registry.set_stats(c.officer_registry,replacement,{"politics":30})
	c._apply_governor_appointment(city,replacement)
	check(c.city_operation_quote(city).tax==106 and c.city_operation_quote(city).annual_harvest==5300,"replacement governor immediately changes both outcomes")
	var appointment: Dictionary=c.officer_registry.post_history.back()
	check(appointment.previous_id==id and appointment.new_id==replacement and appointment.month==c.year*12+c.month,"replacement receipt includes both IDs and date")
	c._apply_governor_appointment(city,id)
	Registry.set_stats(c.officer_registry,id,{"politics":100})
	check(c.city_operation_quote(city).tax==120 and c.city_operation_quote(city).annual_harvest==6000,"politics100 gives20percent")
	var gold_before: int=c.gold
	c.process_monthly_commerce_income()
	var receipt: Dictionary=D.ensure(c.strategy_state).settlements[city]
	check(receipt.base_tax==100 and receipt.tax_bonus==20 and receipt.tax==120,"actual settlement separates base and bonus")
	var gold_after: int=c.gold
	c.process_monthly_commerce_income()
	check(c.gold==gold_after,"same-month tax settlement cannot duplicate")
	c.month=9
	c.crop_failure_events.years[str(c.year)]={"evaluated":true,"province_id":""}
	c.harvest_events.years[str(c.year)]={"evaluated":true,"province_id":""}
	var stock: int=c.provinces[city].food_stock
	c.process_seasonal_harvest()
	check(c.provinces[city].food_stock-stock==1890,"actual September collects45percent then70percent with governor")
	c.process_seasonal_harvest()
	check(c.provinces[city].food_stock-stock==1890,"same harvest month cannot duplicate")
	evidence.append({"faction":c.player_faction,"city":city,"base_tax":100,"governor_tax":120,"faction_gold_delta":gold_after-gold_before,"base_annual_harvest":5000,"governor_annual_harvest":6000,"september_stock_delta":c.provinces[city].food_stock-stock})
	Registry.set_location(c.officer_registry,id,"")
	check(c.get_governor_id(city).is_empty() and c.city_operation_quote(city).tax==100,"moving governor removes post and bonus")
	var last: Dictionary=c.officer_registry.post_history.back()
	check(last.officer_id==id and last.city_id==city and last.new_id=="","dismissal history retains identity, city, previous/new IDs and date")

func conflict_cases() -> void:
	var city: String="geumseong"
	var id: String=c.get_city_officer_ids(city)[0]
	var task: Dictionary=c.start_domestic(city,"agriculture",id)
	check(task.ok,"conflict fixture starts")
	check(not c.get_diplomatic_action_quote("baekje","gift",id).ok,"busy person cannot be envoy")
	check(not c.validate_province_transfer({"source_id":city,"target_id":"geumgwan","officer_ids":[id]}).ok,"busy person cannot move")
	check(Registry.action_available(c.officer_registry,id,c.provinces,"defense",city),"busy person remains available to defend")
	for other: String in c.get_city_officer_ids(city):
		if other!=id: Registry.set_location(c.officer_registry,other,"")
	c._sync_officer_labels()
	check(not c.validate_attack_staff(city).ok and c.get_best_commander(city,"attack").officer_id=="","all busy prevents attack; automatic commander agrees")
	check(c.get_best_commander(city,"defense").officer_id==id,"defensive commander preserved")
	var troops: int=c.provinces[city].troops
	c.resolve_attack(city,"sabi")
	check(c.provinces[city].troops==troops,"direct attack handler blocks before combat")
	c.resolve_ai_attack(city,"sabi")
	check(c.provinces[city].troops==troops,"AI attack uses identical guard")
	roundtrip("pending-cancel")
	check(c.cancel_domestic(task.job_id).ok and c.gold==1000,"loaded pending job refunds once")
	roundtrip("cancelled")
	check(not c.cancel_domestic(task.job_id).ok and c.gold==1000,"loaded cancellation cannot refund again")
	task=c.start_domestic(city,"agriculture",id)
	var before: int=c.provinces[city].agriculture
	c.provinces[city].faction="백제"
	check(not c.cancel_domestic(task.job_id).ok and c.gold==900,"city loss cannot use normal refund")
	D.process(c.strategy_state,c.provinces,c.year*12+c.month+1)
	check(c.provinces[city].agriculture==before and D.ensure(c.strategy_state).jobs[task.job_id].status=="interrupted","lost city no gain; reason recorded")
	c.provinces[city].faction="신라"
	task=c.start_domestic(city,"commerce",id)
	Registry.set_alive(c.officer_registry,id,false)
	D.process(c.strategy_state,c.provinces,c.year*12+c.month+1)
	check(D.ensure(c.strategy_state).jobs[task.job_id].status=="interrupted" and c.gold==800,"lost officer qualification interrupts without gain or refund")

func actual_month_and_save() -> void:
	var city: String="geumseong"
	var id: String=c.get_city_officer_ids(city)[0]
	Registry.set_stats(c.officer_registry,id,{"politics":90,"intelligence":90})
	c.provinces[city].commerce=40
	var accepted: Dictionary=c.start_domestic(city,"commerce",id)
	roundtrip("pending-month")
	c._on_end_turn_button_pressed()
	check(c.month==2 and c.provinces[city].commerce==45,"actual month handler completes before settlement")
	var receipt: Dictionary=D.ensure(c.strategy_state).settlements[city]
	check(receipt.commerce==45 and receipt.tax>0,"same month settlement uses completed commerce before later public-order processing")
	check(D.ensure(c.strategy_state).jobs[accepted.job_id].status=="completed","completion saved as terminal status")
	roundtrip("completed-month")
	var gold_before: int=c.gold
	check(not c.cancel_domestic(accepted.job_id).ok and c.gold==gold_before,"loaded completion cannot refund")
	c._on_end_turn_button_pressed()
	check(c.provinces[city].commerce==45,"later month cannot repeat development")
	# Real previous registry save lacks domestic data; isolate it before mutation.
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RESULTS+"pending-month.json"))
	legacy.strategy_state.erase("domestic")
	for p: Dictionary in legacy.strategy_state.officer_registry.people.values(): p.duties=[]
	var path: String=RESULTS+"old-no-domestic.json"
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(legacy)); file.close()
	c._on_load_button_pressed(path)
	check(D.ensure(c.strategy_state).jobs.is_empty() and c.gold==legacy.gold,"old save gets empty jobs without new charge")
	check(canonical(c.strategy_state.city_inventory)==legacy.strategy_state.city_inventory and canonical(c.strategy_state.relations)==legacy.strategy_state.relations,"old inventory and diplomacy preserved")
