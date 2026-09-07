extends Node

# F6-only presentation fixture. Never loaded by campaign/new-game code.
# No resources, technologies, troops or rewards are assigned to the campaign.
const Campaign = preload("res://campaign_main.tscn")
const PAYLOADS: Dictionary = {
	"domestic_bountiful_harvest": {"province_name": "금성", "grain_delta": 1200, "public_order_delta": 0},
	"enemy_invasion_alert": {"target_province_id": "sabi", "target_province_name": "사비성", "enemy_faction_name": "신라", "enemy_troops": 15000},
	"battle_hwangsanbeol": {"attacker_name": "김유신", "defender_name": "계백", "attacker_troops": 15000, "defender_troops": 10000, "attacker_losses": 2800, "defender_losses": 9100, "battle_grade": "대승"},
}
var campaign: Node
var provinces: Dictionary:
	get:
		return campaign.provinces if campaign != null else {}
var selected_province_id: String:
	get:
		return campaign.selected_province_id if campaign != null else ""
var chooser: PanelContainer
var event_list: OptionButton
var province_name: LineEdit
var grain: SpinBox
var public_order: SpinBox


func _ready() -> void:
	campaign = Campaign.instantiate()
	add_child(campaign)
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	chooser = PanelContainer.new()
	chooser.position = Vector2(32, 86)
	chooser.custom_minimum_size = Vector2(470, 0)
	layer.add_child(chooser)
	var column := VBoxContainer.new()
	chooser.add_child(column)
	var heading := Label.new()
	heading.text = "컷씬 v1 검증 · 표시 전용 / 게임 자원 변경 없음"
	column.add_child(heading)
	event_list = OptionButton.new()
	for id: String in campaign.event_presentation.events:
		# This preview intentionally never mutates simulation resources. Required
		# decisions are exercised through real September turns / crop_failure_test.
		if campaign.event_presentation.events[id].get("requires_choice", false):
			continue
		event_list.add_item(id)
	column.add_child(event_list)
	province_name = LineEdit.new()
	province_name.text = "금성"
	province_name.placeholder_text = "풍년 지역명"
	column.add_child(province_name)
	grain = SpinBox.new()
	grain.max_value = 1000000
	grain.value = 1200
	grain.prefix = "군량 +"
	column.add_child(grain)
	public_order = SpinBox.new()
	public_order.max_value = 100
	public_order.value = PAYLOADS.domestic_bountiful_harvest.public_order_delta
	public_order.prefix = "치안 +"
	public_order.tooltip_text = "실제 증가량: 0이면 결과에 치안 100 · 최대치 표시"
	column.add_child(public_order)
	var play_button := Button.new()
	play_button.text = "선택한 컷씬 재생"
	play_button.pressed.connect(_play_selected)
	column.add_child(play_button)
	campaign.event_presentation.event_finished.connect(func(_id: String): chooser.show())


func _play_selected() -> void:
	var id: String = event_list.get_item_text(event_list.selected)
	var payload: Dictionary = PAYLOADS.get(id, {}).duplicate(true)
	if id == "domestic_bountiful_harvest":
		payload = {"province_name": province_name.text, "grain_delta": int(grain.value), "public_order_delta": int(public_order.value)}
	# Reset only the isolated preview's presentation history, never a real save.
	campaign.event_presentation.restore_state({})
	chooser.hide()
	campaign.event_presentation.play(id, payload)
