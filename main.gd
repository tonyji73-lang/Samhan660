extends Control

var turn: int = 1
var gold: int = 1000
var food: int = 3000

@onready var turn_label: Label = $Panel/VBox/TurnLabel
@onready var resource_label: Label = $Panel/VBox/ResourceLabel
@onready var log_label: Label = $Panel/VBox/LogLabel


func _ready() -> void:
	update_ui()


func _on_end_turn_button_pressed() -> void:
	turn += 1
	gold += 120
	food += 250

	log_label.text = "계절이 지나 세금과 군량을 확보했습니다."
	update_ui()


func update_ui() -> void:
	turn_label.text = "현재 턴: %d" % turn
	resource_label.text = "금: %d / 군량: %d" % [gold, food]
