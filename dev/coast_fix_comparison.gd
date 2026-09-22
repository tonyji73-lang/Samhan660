extends Control
const Map=preload("res://dev/coast_review_map.gd")
var map: Control
var toggle: Button
var mask: CheckButton
var castles: CheckButton
var cities: OptionButton
var status: Label
var manifest: Dictionary

func _ready() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string(Map.ASSETS+"tile_manifest.json"))
	var layout:=VBoxContainer.new(); layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(layout)
	var title:=Label.new(); title.text="해안 보정 v2 · c03_r02 검토용 / 기본 게임 지도 미적용"; layout.add_child(title)
	var bar:=HBoxContainer.new(); layout.add_child(bar)
	toggle=Button.new(); toggle.text="보정 후 → 보정 전"; bar.add_child(toggle); toggle.pressed.connect(func(): map.corrected=not map.corrected; toggle.text="보정 후 → 보정 전" if map.corrected else "보정 전 → 보정 후"; map._layout_city_buttons())
	mask=CheckButton.new(); mask.text="기존 영토 마스크·경계"; bar.add_child(mask); mask.toggled.connect(func(value): map.show_mask=value; map._layout_city_buttons())
	castles=CheckButton.new(); castles.text="성 표시"; castles.button_pressed=true; bar.add_child(castles); castles.toggled.connect(func(value): map.show_castles=value; map._layout_city_buttons())
	var routes:=CheckButton.new(); routes.text="경로"; routes.button_pressed=true; bar.add_child(routes); routes.toggled.connect(func(value): map.show_routes=value; map._layout_city_buttons())
	cities=OptionButton.new(); bar.add_child(cities)
	var frame:=Button.new(); frame.text="첫 구역"; bar.add_child(frame); frame.pressed.connect(func(): map.frame_tile())
	var overview:=Button.new(); overview.text="전체 지도"; bar.add_child(overview); overview.pressed.connect(func(): map.map_zoom=1; map.map_pan_offset=Vector2.ZERO; map._layout_city_buttons())
	map=Map.new(); map.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var bg:=TextureRect.new(); bg.name="CampaignMapBackground"; map.add_child(bg); layout.add_child(map)
	for entry: Dictionary in manifest.tiles:
		if entry.id!="c03_r02": continue
		for id: String in entry.anchor_ids: cities.add_item(map.WORLD_CITY_NAMES[id]); cities.set_item_metadata(cities.item_count-1,id)
	cities.item_selected.connect(func(n): var id: String=cities.get_item_metadata(n); map.selected=id; map.focus_on_province(id,4); update_status(id))
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; layout.add_child(status)
	var help:=Label.new(); help.text="휠: 확대/축소 · 빈 지도 왼쪽 드래그: 이동 · 성 클릭: 선택 · 흰점: 고정 UV 앵커\n마스크 색은 기존 지역 ID 구분용. 해안·영토 접합 미승인 / 성은 배치 확인용 시범 자산."; layout.add_child(help)
	map.anchor_selected.connect(update_status)
	await get_tree().process_frame; map.frame_tile(); update_status("geumgwan")

func update_status(id: String) -> void:
	for n: int in range(cities.item_count):
		if cities.get_item_metadata(n)==id: cities.select(n); break
	var index: int=map.mask_id(id)
	var region: String=map.Korea35Data.PROVINCE_IDS[index-1] if index>0 and index<=map.Korea35Data.PROVINCE_IDS.size() else "마스크 없음/바다"
	status.text="선택: %s · UV %s · 기존 마스크: %s (ID %d)" % [map.WORLD_CITY_NAMES[id],map.WORLD_CITY_MAP_UV[id],region,index]
