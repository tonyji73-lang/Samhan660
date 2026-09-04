extends MenuButton

signal navigation_requested(destination: String)
signal quit_requested

const DESTINATION_SETUP: String = "setup"
const DESTINATION_TITLE: String = "title"
const ITEM_CONTINUE: int = 0
const ITEM_SETUP: int = 1
const ITEM_TITLE: int = 2
const ITEM_QUIT: int = 3

var pending_destination: String = ""

@onready var confirmation_dialog: ConfirmationDialog = %ConfirmationDialog


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var popup: PopupMenu = get_popup()
	popup.clear()
	popup.add_item("계속하기", ITEM_CONTINUE)
	popup.add_separator()
	popup.add_item("세력 선택으로", ITEM_SETUP)
	popup.add_item("타이틀 화면으로", ITEM_TITLE)
	popup.add_separator()
	popup.add_item("게임 종료", ITEM_QUIT)
	popup.id_pressed.connect(_on_item_pressed)
	confirmation_dialog.confirmed.connect(_confirm_navigation)
	confirmation_dialog.canceled.connect(_cancel_navigation)


func _on_item_pressed(item_id: int) -> void:
	match item_id:
		ITEM_CONTINUE:
			get_popup().hide()
		ITEM_SETUP:
			_request_confirmation(DESTINATION_SETUP)
		ITEM_TITLE:
			_request_confirmation(DESTINATION_TITLE)
		ITEM_QUIT:
			_request_quit()


func _request_confirmation(destination: String) -> void:
	pending_destination = destination
	get_popup().hide()
	confirmation_dialog.popup_centered(Vector2i(430, 150))


func _confirm_navigation() -> void:
	var destination: String = pending_destination
	pending_destination = ""
	if destination != "":
		navigation_requested.emit(destination)


func _cancel_navigation() -> void:
	pending_destination = ""


func _request_quit() -> void:
	get_popup().hide()
	quit_requested.emit()
