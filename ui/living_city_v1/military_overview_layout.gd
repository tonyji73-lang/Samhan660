extends RefCounted
## Selected supply-overview design. Owns layout only, never campaign commands.
const UI = preload("res://ui/living_city_v1/military_style.gd")
const ART = "res://ui/living_city_v1/assets/military_overview/"

static func panel(parent: Node, rect: Rect2, dark: bool = false) -> VBoxContainer:
	var node := PanelContainer.new()
	parent.add_child(node); node.position=rect.position; node.size=rect.size
	var skin := UI.City.panel(dark); skin.set_content_margin_all(18)
	node.add_theme_stylebox_override("panel",skin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); node.add_child(box)
	return box

static func heading(parent: Node, text: String, size: int=32) -> Label:
	var label := UI.label(parent,text,size)
	label.add_theme_font_override("font",UI.City.TITLE_FONT)
	return label

static func picture(parent: Node, file: String) -> TextureRect:
	var image := UI.portrait(parent,load(ART+file+".png"),Vector2(0,218))
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return image

static func meter(parent: Node) -> ProgressBar:
	var node := ProgressBar.new(); node.show_percentage=false; node.custom_minimum_size.y=16
	for part: String in ["background","fill"]:
		var skin := StyleBoxFlat.new(); skin.bg_color=UI.City.LINE if part=="background" else UI.City.GOLD
		node.add_theme_stylebox_override(part,skin)
	parent.add_child(node); return node

static func build(v: Control) -> void:
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter=Control.MOUSE_FILTER_STOP; v.theme=UI.City.make_theme()
	var bg := ColorRect.new(); bg.color=UI.City.DARK; v.add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.stage=Control.new(); v.add_child(v.stage); v.stage.size=Vector2(1920,1080)
	var scenery := TextureRect.new(); scenery.texture=load("res://ui/living_city_v1/assets/city.png")
	scenery.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; scenery.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.mouse_filter=Control.MOUSE_FILTER_IGNORE; scenery.modulate=Color(0.65,0.65,0.65)
	v.stage.add_child(scenery); scenery.position=Vector2(0,78); scenery.size=Vector2(1920,918)
	var top := panel(v.stage,Rect2(0,0,1920,78),true)
	var top_skin := UI.City.panel(true); top_skin.content_margin_left=48; top_skin.content_margin_right=48; top_skin.content_margin_top=14; top_skin.content_margin_bottom=14
	top.get_parent().add_theme_stylebox_override("panel",top_skin)
	top.get_parent().move_child(UI.City.Decoration.attach(top.get_parent(),"top"),0)
	var top_row := HBoxContainer.new(); top.add_child(top_row)
	var brand := heading(top_row,"삼한660",36); brand.add_theme_color_override("font_color",UI.City.GOLD)
	v.header=UI.label(top_row,"",24); v.header.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; v.header.add_theme_color_override("font_color",UI.City.LIGHT)
	var title_box := panel(v.stage,Rect2(24,104,1200,100)); UI.City.Decoration.attach(title_box.get_parent(),"city_heading")
	v.screen_title=heading(title_box,"군수",42)
	v.overview=Control.new(); v.stage.add_child(v.overview); v.overview.position=Vector2(24,224); v.overview.size=Vector2(1200,472)
	var stock := panel(v.overview,Rect2(0,0,432,472)); heading(stock,"현지 창고")
	var stock_row := HBoxContainer.new(); stock_row.add_theme_constant_override("separation",14); stock.add_child(stock_row)
	var warehouse := picture(stock_row,"warehouse"); warehouse.custom_minimum_size=Vector2(190,268)
	v.local_stock=UI.label(stock_row,"",26)
	UI.label(stock,"국고와 별개인 현지 재고입니다.\n그림은 물자 종류를 나타냅니다.",20)
	var production := panel(v.overview,Rect2(448,0,368,472)); heading(production,"진행 중 생산")
	v.production_art=picture(production,"forge")
	v.production_status=UI.label(UI.scroll(production),"",23)
	v.preparation_buttons.production=v.button(production,"생산 보기",func(): v.campaign.open_preparation_destination(v.city,v.id(),v.officer(),"production"))
	var arrival := panel(v.overview,Rect2(832,0,368,472)); heading(arrival,"도착 예정 수송")
	picture(arrival,"transport")
	v.arrivals=UI.label(UI.scroll(arrival),"",22)
	UI.label(arrival,"이동 중 화물은 현재 재고에서 제외",18)
	v.transport_button=v.button(arrival,"수송 보기",v.open_transport)
	var unit := panel(v.stage,Rect2(24,714,1200,266))
	var unit_top := HBoxContainer.new(); unit.add_child(unit_top); heading(unit_top,"부대 현황",32)
	v.selector=OptionButton.new(); v.selector.custom_minimum_size.x=430; v.selector.clip_text=true; unit_top.add_child(v.selector)
	v.selector.item_selected.connect(func(_n): v.refresh())
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",22); row.size_flags_vertical=Control.SIZE_EXPAND_FILL; unit.add_child(row)
	var portrait_box := VBoxContainer.new(); row.add_child(portrait_box)
	v.commander_portrait=UI.portrait(portrait_box,null,Vector2(145,146)); v.commander_name=UI.label(portrait_box,"미지정",21)
	var summary := VBoxContainer.new(); summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(summary)
	v.unit_summary=UI.label(summary,"",24)
	var metrics := HBoxContainer.new(); metrics.add_theme_constant_override("separation",20); summary.add_child(metrics)
	for key: String in ["equipment","training"]:
		var column := VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; metrics.add_child(column)
		v.metric_labels[key]=UI.label(column,"",23); v.metric_bars[key]=meter(column)
	var links := HBoxContainer.new(); summary.add_child(links)
	v.manage_button=v.button(links,"편성·이동·상세",v.open_management)
	v.button(links,"훈련 보기",func(): v.show_mode("training"))
	# Training candidates replace the upper overview only; unit context remains.
	v.training_surface=panel(v.stage,Rect2(24,224,1200,472)).get_parent()
	var trainer_box: VBoxContainer=v.training_surface.get_child(0); heading(trainer_box,"훈련 담당자 후보")
	v.training_box=UI.scroll(trainer_box); v.candidate_list=v.training_box
	v.officers=OptionButton.new(); v.add_child(v.officers); v.officers.hide(); v.officers.item_selected.connect(func(_n):v.refresh())
	var tabs := HBoxContainer.new(); v.stage.add_child(tabs); tabs.position=Vector2(1248,104); tabs.size=Vector2(648,68)
	for key: String in ["formation","training"]:
		v.mode_buttons[key]=v.button(tabs,{"formation":"편성 · 장비","training":"훈련 · 지휘관"}[key],func():v.show_mode(key))
	var work := panel(v.stage,Rect2(1248,190,648,790)); UI.City.Decoration.attach(work.get_parent(),"work_panel")
	v.action_title=heading(work,"장비 지급",36)
	var work_scroll := UI.scroll(work)
	v.formation_actions=VBoxContainer.new(); v.formation_actions.add_theme_constant_override("separation",10); work_scroll.add_child(v.formation_actions)
	v.equip_stock=UI.label(v.formation_actions,"",26)
	UI.label(v.formation_actions,"1묶음 = 100명분 · 도착 예정 물자는 지급 불가",20)
	v.formation_actions.add_child(HSeparator.new()); heading(v.formation_actions,"지급 수량",28)
	var quantity := HBoxContainer.new(); v.formation_actions.add_child(quantity)
	v.button(quantity,"−",func():v.bundles.value=maxf(1,v.bundles.value-1))
	v.bundles=SpinBox.new(); v.bundles.min_value=1; v.bundles.max_value=10000; v.bundles.value=1; v.bundles.custom_minimum_size=Vector2(180,52); quantity.add_child(v.bundles)
	v.bundles.add_theme_font_size_override("font_size",28); v.bundles.value_changed.connect(func(_x):v.refresh())
	var input: LineEdit=v.bundles.get_line_edit()
	input.add_theme_stylebox_override("normal",UI.City.panel())
	input.add_theme_color_override("font_color",UI.City.INK)
	v.button(quantity,"+",func():v.bundles.value+=1); UI.label(quantity,"묶음",24)
	heading(v.formation_actions,"지급 결과 · 미리보기",28)
	v.equip_summary=UI.label(v.formation_actions,"",26)
	v.training_actions=VBoxContainer.new(); v.training_actions.add_theme_constant_override("separation",12); work_scroll.add_child(v.training_actions)
	v.training_summary=UI.label(v.training_actions,"",25)
	v.commander_button=v.button(v.training_actions,"선택 후보를 지휘관으로 임명",func():v.run("commander"))
	v.stop_button=v.button(v.training_actions,"훈련 중지",func():v.run("stop"))
	v.cancel_selection=v.button(v.training_actions,"후보 선택 취소",func():v.select_officer(v.selection_before))
	v.status=UI.label(work,"",22); v.status.add_theme_color_override("font_color",UI.City.RED)
	v.equip_button=v.button(work,"장비 지급 확정",func():v.run("equip")); UI.City.button(v.equip_button,false,true)
	v.train_button=v.button(work,"훈련 시작 · 담당자 교체",func():v.run("train")); UI.City.button(v.train_button,false,true)
	var bottom := HBoxContainer.new(); work.add_child(bottom)
	v.reset_button=v.button(bottom,"수량 초기화",func():v.bundles.value=1)
	v.close_button=v.button(bottom,"닫기 (Esc)",v.hide)
	# Full editing commands remain in an explicit, scrollable secondary panel.
	v.management_panel=Control.new(); v.stage.add_child(v.management_panel); v.management_panel.size=Vector2(1920,1080)
	var shade := ColorRect.new(); shade.color=Color(0,0,0,0.7); shade.size=Vector2(1920,1080); v.management_panel.add_child(shade)
	var editing := panel(v.management_panel,Rect2(280,110,1360,850)); heading(editing,"편성 · 이동 · 상세",36)
	v.formation_box=UI.scroll(editing)
	var adjust := UI.section(v.formation_box,"편성 조정")
	var amount_row := HBoxContainer.new(); adjust.add_child(amount_row)
	v.amount=SpinBox.new(); v.amount.min_value=1; v.amount.max_value=100000; v.amount.value=1000; v.amount.custom_minimum_size.x=220; amount_row.add_child(v.amount)
	v.split_button=v.button(amount_row,"명 분리 편성",func():v.run("split")); v.amount.value_changed.connect(func(_n):v.refresh())
	v.disband_button=v.button(adjust,"선택 인원 현지 해산",func():v.run("disband"))
	v.join_selector=OptionButton.new(); adjust.add_child(v.join_selector)
	v.merge_button=v.button(adjust,"선택한 부대에 합류·보충",func():v.run("merge"))
	var movement := UI.section(v.formation_box,"이동 · 출정")
	v.destination=OptionButton.new(); movement.add_child(v.destination)
	v.move_button=v.button(movement,"선택 부대 이동",func():v.run("move"))
	v.attack_button=v.button(movement,"도시 가용 부대 출정",func():v.hide();v.campaign.select_province(v.city);v.campaign._on_attack_button_pressed())
	var preparation := UI.section(v.formation_box,"부족 물자 준비")
	for key: String in ["build","research"]:
		v.preparation_buttons[key]=v.button(preparation,{"build":"시설 건설 보기","research":"기술 연구 보기"}[key],func():v.campaign.open_preparation_destination(v.city,v.id(),v.officer(),key))
	v.preparation=UI.label(preparation,"",22); v.details=UI.label(UI.section(v.formation_box,"세부 기록"),"",21)
	v.button(editing,"군수 현황으로 (Esc)",v.close_management)
	v.management_panel.hide()
	var footer := panel(v.stage,Rect2(0,996,1920,84),true)
	footer.get_parent().move_child(UI.City.Decoration.attach(footer.get_parent(),"bottom"),0)
	var nav := HBoxContainer.new(); footer.add_child(nav)
	for item: Array in [["내정","domestic"],["인사","personnel"],["군수","army"],["생산","production"],["건설","build"],["연구","research"],["조정","court"],["외교","diplomacy"],["지도","map"],["다음 달 →","month"]]:
		var b: Button=v.button(nav,item[0],func():v.navigate(item[1])); b.set_meta("dark",true); UI.City.button(b,item[1]=="army"); v.navigation[item[1]]=b
	# Existing command receipts remain visible without replacing the screen title.
	v.result=UI.label(work,"",18); v.result.clip_text=true; v.result.autowrap_mode=TextServer.AUTOWRAP_OFF
	v.resized.connect(v.fit_stage); v.visibility_changed.connect(func():
		if not v.visible: v.management_panel.hide()
	)
	v.fit_stage(); v.show_mode("formation"); v.hide()
