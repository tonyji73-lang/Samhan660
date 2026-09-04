extends Control

signal transfer_requested(request: Dictionary)
signal canceled

var source_province_id: String = ""

const TARGET_PANEL_SIZE: Vector2 = Vector2(460.0, 500.0)
const VIEWPORT_MARGIN: float = 16.0

@onready var modal_panel: PanelContainer = $Center/Panel
@onready var source_value: Label = %SourceValue
@onready var destination_option: OptionButton = %DestinationOption
@onready var troop_spin: SpinBox = %TroopSpin
@onready var food_row: HBoxContainer = %FoodRow
@onready var food_spin: SpinBox = %FoodSpin
@onready var gold_row: HBoxContainer = %GoldRow
@onready var gold_spin: SpinBox = %GoldSpin
@onready var officer_list: ItemList = %OfficerList
@onready var status_label: Label = %StatusLabel
@onready var execute_button: Button = %ExecuteButton
@onready var cancel_button: Button = %CancelButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	execute_button.pressed.connect(_on_execute_pressed)
	cancel_button.pressed.connect(close_panel)
	close_button.pressed.connect(close_panel)
	resized.connect(_fit_panel_to_viewport)
	_fit_panel_to_viewport()


func open_for_transfer(
	province_id: String,
	province_name: String,
	destinations: Array[Dictionary],
	available_troops: int,
	available_officers: Array[String],
	governor_name: String,
	supports_food: bool = false,
	supports_gold: bool = false
) -> void:
	source_province_id = province_id
	source_value.text = province_name
	destination_option.clear()
	for destination: Dictionary in destinations:
		destination_option.add_item(str(destination.get("name", "-")))
		destination_option.set_item_metadata(
			destination_option.item_count - 1,
			str(destination.get("id", ""))
		)

	troop_spin.max_value = maxi(0, available_troops)
	troop_spin.value = 0
	food_row.visible = supports_food
	food_spin.value = 0
	gold_row.visible = supports_gold
	gold_spin.value = 0

	officer_list.clear()
	for officer_name: String in available_officers:
		var display_name: String = officer_name
		if officer_name == governor_name:
			display_name += " (태수)"
		officer_list.add_item(display_name)
		officer_list.set_item_metadata(officer_list.item_count - 1, officer_name)

	status_label.text = ""
	execute_button.disabled = destinations.is_empty()
	visible = true
	_fit_panel_to_viewport()
	execute_button.grab_focus()


func close_panel() -> void:
	visible = false
	status_label.text = ""
	canceled.emit()


func show_error(message: String) -> void:
	status_label.text = message


func _fit_panel_to_viewport() -> void:
	if modal_panel == null:
		return
	var available_size: Vector2 = Vector2(
		maxf(1.0, size.x - VIEWPORT_MARGIN * 2.0),
		maxf(1.0, size.y - VIEWPORT_MARGIN * 2.0)
	)
	modal_panel.custom_minimum_size = Vector2(
		minf(TARGET_PANEL_SIZE.x, available_size.x),
		minf(TARGET_PANEL_SIZE.y, available_size.y)
	)


func _on_execute_pressed() -> void:
	if destination_option.selected < 0:
		show_error("이동할 목적지를 선택하세요.")
		return
	var selected_officers: Array[String] = []
	for index: int in officer_list.get_selected_items():
		selected_officers.append(str(officer_list.get_item_metadata(index)))
	transfer_requested.emit(
		{
			"source_id": source_province_id,
			"target_id": str(
				destination_option.get_item_metadata(destination_option.selected)
			),
			"troops": int(troop_spin.value),
			"food": int(food_spin.value) if food_row.visible else 0,
			"gold": int(gold_spin.value) if gold_row.visible else 0,
			"officers": selected_officers,
		}
	)
