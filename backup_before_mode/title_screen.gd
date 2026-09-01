extends Control


class CampaignLoadBridge:
	extends Node

	var campaign_scene_path: String = ""


	func start() -> void:
		var change_error: Error = (
			get_tree().change_scene_to_file(
				campaign_scene_path
			)
		)

		if change_error != OK:
			push_error(
				"Could not open campaign scene: %s"
				% campaign_scene_path
			)
			queue_free()
			return

		# Wait until campaign_main.gd has completed _ready().
		await get_tree().process_frame
		await get_tree().process_frame

		var campaign_scene: Node = (
			get_tree().current_scene
		)

		if (
			campaign_scene != null
			and campaign_scene.has_method(
				"_on_load_button_pressed"
			)
		):
			campaign_scene.call_deferred(
				"_on_load_button_pressed"
			)
		else:
			push_warning(
				"Campaign scene has no load method."
			)

		queue_free()


@export_group("Title Content")
@export var background_texture: Texture2D
@export var title_text: String = "삼한 660"
@export var subtitle_text: String = "칼끝이 천명을 가른다"
@export var version_text: String = "v0.1"

@export_group("Project Paths")
@export_file("*.tscn") var new_game_scene_path: String = (
	"res://new_game_setup.tscn"
)
@export_file("*.tscn") var campaign_scene_path: String = (
	"res://campaign_main.tscn"
)
@export var save_path: String = (
	"user://campaign_save_9_regions.json"
)

@export_group("Optional Audio")
@export var title_music: AudioStream


var background_rect: TextureRect
var tone_overlay: ColorRect
var menu_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var new_game_button: Button
var load_game_button: Button
var quit_button: Button
var status_label: Label
var version_label: Label
var fade_rect: ColorRect
var music_player: AudioStreamPlayer

var menu_locked: bool = false


func _ready() -> void:
	clip_contents = true
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_build_interface()
	_apply_background_texture()
	_update_load_button()
	_start_background_motion()
	_start_music()

	call_deferred("_play_intro")


func _unhandled_input(event: InputEvent) -> void:
	if menu_locked:
		return

	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	_build_background()
	_build_menu()
	_build_footer()
	_build_fade_layer()
	_build_music_player()


func _build_background() -> void:
	background_rect = TextureRect.new()
	background_rect.name = "Background"
	background_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background_rect.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	background_rect.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	background_rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	background_rect.resized.connect(
		_update_background_pivot
	)
	add_child(background_rect)

	tone_overlay = ColorRect.new()
	tone_overlay.name = "ToneOverlay"
	tone_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	tone_overlay.color = Color(
		0.025,
		0.020,
		0.016,
		0.20
	)
	tone_overlay.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	add_child(tone_overlay)


func _build_menu() -> void:
	var center_container: CenterContainer = (
		CenterContainer.new()
	)
	center_container.name = "MenuCenter"
	center_container.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	center_container.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	add_child(center_container)

	menu_panel = PanelContainer.new()
	menu_panel.name = "MenuPanel"
	menu_panel.custom_minimum_size = Vector2(
		430.0,
		0.0
	)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	menu_panel.add_theme_stylebox_override(
		"panel",
		_create_panel_style()
	)
	center_container.add_child(menu_panel)

	var menu_vbox: VBoxContainer = VBoxContainer.new()
	menu_vbox.name = "MenuVBox"
	menu_vbox.add_theme_constant_override(
		"separation",
		12
	)
	menu_panel.add_child(menu_vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title_text
	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title_label.add_theme_font_size_override(
		"font_size",
		74
	)
	title_label.add_theme_color_override(
		"font_color",
		Color("#f3dfad")
	)
	title_label.add_theme_color_override(
		"font_outline_color",
		Color("#17120c")
	)
	title_label.add_theme_constant_override(
		"outline_size",
		4
	)
	menu_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = subtitle_text
	subtitle_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle_label.add_theme_font_size_override(
		"font_size",
		20
	)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color("#d8c9a6")
	)
	menu_vbox.add_child(subtitle_label)

	var title_spacer: Control = Control.new()
	title_spacer.custom_minimum_size = Vector2(
		0.0,
		28.0
	)
	menu_vbox.add_child(title_spacer)

	new_game_button = _create_menu_button(
		"시작하기",
		"NewGameButton"
	)
	new_game_button.pressed.connect(
		_on_new_game_pressed
	)
	menu_vbox.add_child(new_game_button)

	load_game_button = _create_menu_button(
		"불러오기",
		"LoadGameButton"
	)
	load_game_button.pressed.connect(
		_on_load_game_pressed
	)
	menu_vbox.add_child(load_game_button)

	quit_button = _create_menu_button(
		"종료",
		"QuitButton"
	)
	quit_button.pressed.connect(
		_on_quit_pressed
	)
	menu_vbox.add_child(quit_button)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.custom_minimum_size = Vector2(
		0.0,
		24.0
	)
	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	status_label.add_theme_font_size_override(
		"font_size",
		14
	)
	status_label.add_theme_color_override(
		"font_color",
		Color("#e7c77a")
	)
	menu_vbox.add_child(status_label)


func _build_footer() -> void:
	version_label = Label.new()
	version_label.name = "VersionLabel"
	version_label.text = version_text
	version_label.anchor_left = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -220.0
	version_label.offset_top = -44.0
	version_label.offset_right = -24.0
	version_label.offset_bottom = -16.0
	version_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	version_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	version_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	version_label.add_theme_font_size_override(
		"font_size",
		14
	)
	version_label.add_theme_color_override(
		"font_color",
		Color(1.0, 1.0, 1.0, 0.65)
	)
	add_child(version_label)


func _build_fade_layer() -> void:
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeLayer"
	fade_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	fade_rect.z_index = 1000
	add_child(fade_rect)


func _build_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "TitleMusic"
	music_player.stream = title_music
	add_child(music_player)


func _create_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.020, 0.015, 0.60)
	style.border_color = Color(0.72, 0.54, 0.22, 0.78)

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10

	style.content_margin_left = 46.0
	style.content_margin_top = 38.0
	style.content_margin_right = 46.0
	style.content_margin_bottom = 28.0

	return style


func _create_menu_button(
	button_text: String,
	button_name: String
) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.text = button_text
	button.custom_minimum_size = Vector2(
		330.0,
		54.0
	)
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	button.focus_mode = Control.FOCUS_ALL

	button.add_theme_font_size_override(
		"font_size",
		20
	)
	button.add_theme_color_override(
		"font_color",
		Color("#f0e5cb")
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color("#fff0bd")
	)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.65, 0.65, 0.65, 0.55)
	)

	button.add_theme_stylebox_override(
		"normal",
		_create_button_style(
			Color(0.045, 0.040, 0.032, 0.86),
			Color(0.64, 0.48, 0.20, 0.70),
			1
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_button_style(
			Color(0.38, 0.27, 0.10, 0.94),
			Color("#e2b84f"),
			2
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_button_style(
			Color(0.25, 0.17, 0.06, 0.98),
			Color("#f0c964"),
			2
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_create_button_style(
			Color(0.20, 0.15, 0.08, 0.92),
			Color.WHITE,
			2
		)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_create_button_style(
			Color(0.05, 0.05, 0.05, 0.58),
			Color(0.35, 0.35, 0.35, 0.45),
			1
		)
	)

	return button


func _create_button_style(
	background_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color

	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	style.content_margin_left = 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0

	return style


func _apply_background_texture() -> void:
	background_rect.texture = background_texture

	if background_texture == null:
		status_label.text = (
			"Inspector에서 Background Texture를 지정하세요."
		)


func _update_background_pivot() -> void:
	if background_rect == null:
		return

	background_rect.pivot_offset = (
		background_rect.size * 0.5
	)


func _start_background_motion() -> void:
	_update_background_pivot()
	background_rect.scale = Vector2(1.035, 1.035)

	var background_tween: Tween = create_tween()
	background_tween.set_loops()
	background_tween.set_trans(
		Tween.TRANS_SINE
	)
	background_tween.set_ease(
		Tween.EASE_IN_OUT
	)
	background_tween.tween_property(
		background_rect,
		"scale",
		Vector2.ONE,
		18.0
	)
	background_tween.tween_property(
		background_rect,
		"scale",
		Vector2(1.035, 1.035),
		18.0
	)


func _start_music() -> void:
	if title_music == null:
		return

	music_player.play()


func _play_intro() -> void:
	fade_rect.color.a = 1.0
	menu_panel.modulate.a = 0.0
	version_label.modulate.a = 0.0

	var intro_tween: Tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.set_trans(Tween.TRANS_SINE)
	intro_tween.set_ease(Tween.EASE_OUT)

	intro_tween.tween_property(
		fade_rect,
		"color:a",
		0.0,
		0.85
	)
	intro_tween.tween_property(
		menu_panel,
		"modulate:a",
		1.0,
		0.70
	).set_delay(0.20)
	intro_tween.tween_property(
		version_label,
		"modulate:a",
		1.0,
		0.50
	).set_delay(0.40)

	await intro_tween.finished
	new_game_button.grab_focus()


func _update_load_button() -> void:
	var save_exists: bool = FileAccess.file_exists(
		save_path
	)

	load_game_button.disabled = not save_exists

	if save_exists:
		load_game_button.tooltip_text = (
			"저장한 게임을 이어서 시작합니다."
		)
	else:
		load_game_button.tooltip_text = (
			"저장된 게임이 없습니다."
		)


func _set_menu_enabled(enabled: bool) -> void:
	menu_locked = not enabled
	new_game_button.disabled = not enabled
	quit_button.disabled = not enabled

	if enabled:
		_update_load_button()
	else:
		load_game_button.disabled = true


func _fade_to_black() -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_tween: Tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(
		fade_rect,
		"color:a",
		1.0,
		0.42
	)

	await fade_tween.finished


func _fade_from_black() -> void:
	var fade_tween: Tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(
		fade_rect,
		"color:a",
		0.0,
		0.35
	)

	await fade_tween.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_new_game_pressed() -> void:
	if menu_locked:
		return

	_set_menu_enabled(false)
	status_label.text = "새로운 역사를 준비합니다."
	await _fade_to_black()

	var change_error: Error = (
		get_tree().change_scene_to_file(
			new_game_scene_path
		)
	)

	if change_error != OK:
		status_label.text = (
			"새 게임 설정 화면을 열 수 없습니다."
		)
		await _fade_from_black()
		_set_menu_enabled(true)


func _on_load_game_pressed() -> void:
	if menu_locked:
		return

	if not FileAccess.file_exists(save_path):
		status_label.text = "저장된 게임이 없습니다."
		_update_load_button()
		return

	_set_menu_enabled(false)
	status_label.text = "저장된 역사를 불러옵니다."
	await _fade_to_black()

	var load_bridge: CampaignLoadBridge = (
		CampaignLoadBridge.new()
	)
	load_bridge.name = "CampaignLoadBridge"
	load_bridge.campaign_scene_path = (
		campaign_scene_path
	)

	get_tree().root.add_child(load_bridge)
	load_bridge.call_deferred("start")


func _on_quit_pressed() -> void:
	if menu_locked:
		return

	_set_menu_enabled(false)
	status_label.text = "게임을 종료합니다."
	await _fade_to_black()
	get_tree().quit()
