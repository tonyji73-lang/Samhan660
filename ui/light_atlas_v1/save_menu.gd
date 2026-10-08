extends Control
## Presentation only: reuse the existing PopupMenu IDs and signal handlers.
const Atlas = preload("res://ui/light_atlas_v1/atlas_theme.gd")
var source: PopupMenu
var stage: Control
var panel: PanelContainer
var entries: Dictionary = {}
var opener: Control
var scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Atlas.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_menu())
	resized.connect(_fit)
	hide()

func open_menu(popup: PopupMenu, return_focus: Control) -> void:
	source = popup
	source.about_to_popup.emit()
	opener = return_focus
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	entries.clear()
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(1920,1080)
	add_child(stage)
	panel = PanelContainer.new()
	panel.position = Vector2(1400,88)
	panel.size = Vector2(488,884)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", Atlas.panel())
	stage.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "저장·메뉴"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", Atlas.BOLD_FONT)
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(42,42)
	Atlas.apply_button(close)
	close.tooltip_text = "닫기 (Esc)"
	close.pressed.connect(close_menu)
	header.add_child(close)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var included: Array[int] = [0]
	for group: Array in [["저장과 불러오기", [15,9]], ["국정과 현황", [4,13,12,6,7,5,8,10]], ["화면 이동", [1,2,3]], ["연출 표시", [100,101,102]]]:
		var caption := Label.new()
		caption.text = group[0]
		caption.custom_minimum_size.y = 36
		caption.add_theme_font_override("font", Atlas.BOLD_FONT)
		list.add_child(caption)
		for id: int in group[1]:
			if source.get_item_index(id) >= 0:
				_add_entry(list, id)
				included.append(id)
	# Keep future or scenario-specific commands reachable without duplicating rules.
	for index in source.item_count:
		var id := source.get_item_id(index)
		if not source.is_item_separator(index) and id not in included:
			_add_entry(list, id)
	_add_entry(column, 0)
	show()
	_fit()
	entries[0].grab_focus()

func _add_entry(parent: Control, id: int) -> void:
	var index := source.get_item_index(id)
	var item := Button.new()
	item.text = source.get_item_text(index)
	item.disabled = source.is_item_disabled(index)
	item.tooltip_text = source.get_item_tooltip(index)
	item.custom_minimum_size.y = 60 if id == 0 else 42
	item.alignment = HORIZONTAL_ALIGNMENT_CENTER if id == 0 else HORIZONTAL_ALIGNMENT_LEFT
	var checkable := source.is_item_checkable(index) or source.is_item_radio_checkable(index)
	var selected := checkable and source.is_item_checked(index)
	item.toggle_mode = checkable
	item.button_pressed = selected
	Atlas.apply_button(item, selected, "primary" if id == 0 else "default")
	if id != 0 and not selected:
		var normal := Atlas.panel(Atlas.SURFACE, Atlas.LINE, 0)
		normal.border_width_bottom = 1
		item.add_theme_stylebox_override("normal", normal)
	if id == 3:
		item.add_theme_color_override("font_color", Atlas.ACCENT)
	var icons := {15:"floppy-disk",9:"book-open",4:"users-three",13:"warning-circle",12:"sword",6:"buildings",7:"plant",5:"users-three",8:"book-open",10:"book-open",1:"list",2:"arrow-left",3:"arrow-right",0:"arrow-right"}
	item.icon = Atlas.icon(icons.get(id,"list"))
	item.add_theme_font_size_override("font_size", 22)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := item.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_top = 4; style.content_margin_bottom = 4
		item.add_theme_stylebox_override(state, style)
	item.pressed.connect(func():
		hide()
		source.id_pressed.emit(id)
		if id == 0: _restore_focus.call_deferred())
	parent.add_child(item)
	entries[id] = item

func _fit() -> void:
	if not is_instance_valid(stage): return
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - Vector2(1920,1080) * factor) * 0.5

func close_menu() -> void:
	hide()
	_restore_focus.call_deferred()

func _restore_focus() -> void:
	await get_tree().process_frame
	if is_instance_valid(opener) and opener.is_visible_in_tree(): opener.grab_focus()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()