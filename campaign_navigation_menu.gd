extends Control

signal navigation_requested(destination: String)
signal quit_requested

const DESTINATION_SETUP: String = "setup"
const DESTINATION_TITLE: String = "title"

var pending_destination: String = ""

@onready var menu_button: Button = %MenuButton
@onready var menu_panel: PanelContainer = %MenuPanel
@onready var continue_button: Button = %ContinueButton
@onready var setup_button: Button = %SetupButton
@onready var title_button: Button = %TitleButton
@onready var quit_button: Button = %QuitButton
@onready var confirmation_dialog: ConfirmationDialog = %ConfirmationDialog


func _ready() -> void:
	menu_panel.visible = false
	menu_button.pressed.connect(_toggle_menu)
	continue_button.pressed.connect(close_menu)
	setup_button.pressed.connect(_request_confirmation.bind(DESTINATION_SETUP))
	title_button.pressed.connect(_request_confirmation.bind(DESTINATION_TITLE))
	quit_button.pressed.connect(_request_quit)
	confirmation_dialog.confirmed.connect(_confirm_navigation)
	confirmation_dialog.canceled.connect(_cancel_navigation)


func close_menu() -> void:
	menu_panel.visible = false


func _toggle_menu() -> void:
	menu_panel.visible = not menu_panel.visible


func _request_confirmation(destination: String) -> void:
	pending_destination = destination
	close_menu()
	confirmation_dialog.popup_centered(Vector2i(430, 150))


func _confirm_navigation() -> void:
	var destination: String = pending_destination
	pending_destination = ""
	if destination != "":
		navigation_requested.emit(destination)


func _cancel_navigation() -> void:
	pending_destination = ""


func _request_quit() -> void:
	close_menu()
	quit_requested.emit()
