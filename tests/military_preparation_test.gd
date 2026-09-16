extends "res://tests/military_preparation_playtest.gd"

const Guide=preload("res://military_preparation_guide.gd")

func quote(label: String, trainer: String="historical:004") -> Dictionary:
	var before: Dictionary=full_state()
	var result: Dictionary=Guide.model(c,"geumseong",unit_id,trainer)
	check(full_state()==before,"read-only model "+label)
	return result

func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PREP_DIR+"normal.json"))
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	unit_id=normal.unit_id
	c._on_load_button_pressed(normal.checkpoints.progress.slot)
	check(quote("normal progress").parallel,"valid independent training and production")
	check(not quote("busy manager","historical:003").parallel,"production manager cannot train simultaneously")
	for balance: int in [49,50,77,78]:
		c.strategy_state.faction_economy.accounts.silla.balance=balance
		check(quote("balance"+str(balance)).parallel==(balance>=78),"combined training50 and actual next batch28 affordability "+str(balance))
	c._on_load_button_pressed(normal.checkpoints.progress.slot)
	c.officer_registry.people["historical:004"].alive=false
	check(not quote("dead trainer").parallel,"dead trainer excluded by shared validation")
	c._on_load_button_pressed(normal.checkpoints.progress.slot)
	c.provinces.geumseong.food_shortage=true
	check(not quote("food shortage").parallel,"upkeep shortage prevents training")
	c._on_load_button_pressed(normal.checkpoints.progress.slot)
	c.provinces.geumseong.faction="백제"
	check(not quote("lost city").parallel,"lost city cannot advertise preparation")
	c._on_load_button_pressed(normal.checkpoints.progress.slot)
	c.strategy_state.city_production.geumseong.iron_sword.enabled=false
	check(not quote("stopped production").parallel,"completed facilities alone do not imply enabled production")
	c.strategy_state.city_inventory.geumseong.sword=10
	check(quote("available stock").parallel,"existing stock permits issue alongside valid training")
	c._on_load_button_pressed(normal.checkpoints.progress.slot)
	c.strategy_state.erase("domestic")
	quote("legacy without jobs")
	check(not c.strategy_state.has("domestic"),"quote normalization never mutates legacy input")
	c._on_load_button_pressed(normal.checkpoints.progress.slot)
	c.open_industry("geumseong","build","forge")
	select_value(c.industry_overlay.officer_selector,"historical:003")
	check(c.industry_overlay.execute_button.disabled and not c.industry_overlay.details.text.contains("완료 (현재 선택 담당자 유지 시)"),"busy industry candidate gets no misleading completion date")
	c.industry_overlay.hide()
	c._on_load_button_pressed(normal.checkpoints.ready.slot)
	var ready: Dictionary=quote("ready")
	check(ready.text.contains("장비·훈련 준비 완료") and not ready.parallel,"completed unit needs no extra preparation")
	c.open_army("geumseong"); select_value(c.army_overlay.selector,unit_id)
	c.open_preparation_destination("geumseong",unit_id,"historical:004","production")
	c._on_load_button_pressed(normal.checkpoints.progress.slot)
	check(c.preparation_return.is_empty(),"load clears obsolete UI return context")
	c._on_city_card_production_requested("geumseong")
	check(not c.production_overlay.preparation_back.visible,"ordinary production has no stale unit return")
	c.close_preparation_destination(c.production_overlay)
	check(not c.army_overlay.visible and not c.map_area.modal_input_locked,"ordinary close returns to map")
	var out:=FileAccess.open(PREP_DIR+"boundaries.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"failures":failures,"kind":"separate controlled fixtures; not normal play"},"\t")); out.close()
	print("MILITARY PREPARATION BOUNDARIES: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
