extends "res://tests/project_foundation_test.gd"
var measurements: Dictionary={}
func record(key: String, control: Control, ui: Control) -> void:
	var scale_factor: float=float(root.size.x)/ui.size.x
	measurements[key]={"logical":[control.size.x,control.size.y],"display":[control.size.x*scale_factor,control.size.y*scale_factor],"node":str(control.get_path())}
func _run() -> void:
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn")
	await settle()
	c=current_scene
	await finish_events()
	c._on_city_card_detail_requested("geumseong")
	c._on_develop_button_pressed()
	var ui: Node=c.domestic_overlay
	for width: int in [1280,1920]:
		root.size=Vector2i(width,width*9/16)
		ui._set_mode(false)
		await settle()
		var prefix: String=str(width)+":"
		for pair: Array in [["top",ui.header.get_parent().get_parent()],["header_text",ui.header],["footer",ui.month_button.get_parent().get_parent()],["menu",ui.navigation.domestic],["primary",ui.execute_button],["panel",ui.find_child("CityWorkPanel",true,false)],["title",ui.title_row],["effect_heading",ui.effect_heading],["city_heading",ui.city_title.get_parent().get_parent()]]:
			record(prefix+pair[0],pair[1],ui)
		ui._open_officers()
		await settle()
		record(prefix+"officer_card",ui.picker_cards.get_child(0),ui)
		ui._set_mode(true)
		await settle()
		record(prefix+"personnel_card",ui.candidate_row.get_child(0),ui)
		record(prefix+"personnel_name",ui.candidate_row.get_child(0).get_child(1),ui)
		record(prefix+"personnel_primary",ui.execute_button,ui)
	var fonts: Array=[]
	for path: String in ["res://ui/faction_selection_v1/assets/SamhanUISans-Medium.ttf","res://ui/faction_selection_v1/assets/SamhanUISans-SemiBold.ttf","res://addons/gut/fonts/LobsterTwo-Regular.ttf","res://addons/gut/fonts/AnonymousPro-Regular.ttf","res://addons/gut/fonts/CourierPrime-Regular.ttf"]:
		var font: FontFile=load(path)
		fonts.append({"path":path,"family":font.get_font_name(),"style":font.get_font_style_name(),"hangul_ga":font.has_char(0xAC00),"hangul_guk":font.has_char(0xAD6D)})
	measurements["fonts"]=fonts
	var file := FileAccess.open("res://tests/living_city_v1_3_asset_review/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t")); file.close()
	print("ASSET MEASUREMENT COMPLETE; no gameplay regression suite run")
	quit()
