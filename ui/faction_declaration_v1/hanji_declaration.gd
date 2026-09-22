extends Control
## Transparent text layer placed inside the EXISTING hanji paper control.
## Each source line is a column; line 0 is rightmost. Spaces are retained.

@export var declaration_font: Font
@export var max_font_size: int = 23
@export var ink_color: Color = Color("47321d")
@export var seconds_per_character: float = 0.055
@export var seconds_between_columns: float = 0.16
@export var ink_fade_seconds: float = 0.10
@export var reduce_motion: bool = false

var _entry: Dictionary = {}
var _signature: String = ""
var _elapsed: float = 0.0
var _duration: float = 0.0
var _glyphs: Array[Dictionary] = []
var _face: Font
var _font_pixels: int = 23
var _seal_text: String = ""
var _seal_box: Rect2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_rebuild)
	_rebuild()


func present_declaration(entry: Dictionary, force_restart: bool = false) -> void:
	var columns: Array = entry.get("columns", [])
	if not entry.is_empty() and columns.size() != 5:
		push_error("Faction declarations require exactly five source columns.")
		entry = {}
		columns = []
	var next_signature := JSON.stringify([
		entry.get("key", ""), columns, entry.get("seal_text", "")
	])
	if next_signature == _signature and not force_restart:
		if reduce_motion:
			finish_reveal()
		return
	_signature = next_signature
	_entry = entry.duplicate(true)
	_elapsed = 0.0
	_rebuild()
	if reduce_motion:
		finish_reveal()


func capture_state() -> Dictionary:
	return {"signature": _signature, "elapsed": _elapsed}


func restore_state(state: Dictionary) -> void:
	# A rebuilt parent can preserve progress when only difficulty/mode changed.
	# A different year/faction/text never inherits the old animation.
	if str(state.get("signature", "")) != _signature:
		return
	_elapsed = clampf(float(state.get("elapsed", 0.0)), 0.0, _duration)
	if reduce_motion:
		_elapsed = _duration
	_update_ink()
	set_process(_elapsed < _duration)


func finish_reveal() -> void:
	_elapsed = _duration
	_update_ink()
	set_process(false)


func replay() -> void:
	_elapsed = 0.0
	if reduce_motion:
		_elapsed = _duration
	_update_ink()
	set_process(_elapsed < _duration)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed = minf(_elapsed + delta, _duration)
	_update_ink()
	if _elapsed >= _duration:
		set_process(false)


func _column_units(phrase: String) -> float:
	var units := 0.0
	for index in range(phrase.length()):
		units += 0.45 if phrase.substr(index, 1) == " " else 1.0
	return units


func _rebuild() -> void:
	_glyphs.clear()
	_seal_text = ""
	_duration = 0.0
	queue_redraw()
	if not is_node_ready() or _entry.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		set_process(false)
		return
	var columns: Array = _entry.get("columns", [])
	if columns.size() != 5:
		set_process(false)
		return
	_face = declaration_font
	if _face == null:
		_face = get_theme_default_font()
	var inner := Rect2(Vector2(18.0, 20.0), size - Vector2(36.0, 66.0))
	var longest := 1.0
	for phrase: Variant in columns:
		longest = maxf(longest, _column_units(str(phrase)))
	var font_pixels := maxi(1, max_font_size)
	while font_pixels > 1:
		var needed_height := float(font_pixels) * 1.18 * longest
		var needed_width := float(font_pixels) * 8.0
		if needed_height <= inner.size.y and needed_width <= inner.size.x:
			break
		font_pixels -= 1
	_font_pixels = font_pixels
	var row_step := float(font_pixels) * 1.18
	var column_step := float(font_pixels) * 1.65
	var glyph_width := float(font_pixels) * 1.4
	var group_width := column_step * 4.0 + glyph_width
	var group_height := row_step * longest
	var origin := inner.position + (inner.size - Vector2(group_width, group_height)) * 0.5
	var reveal_at := 0.0
	for column_index in range(5):
		var phrase := str(columns[column_index])
		var x := origin.x + float(4 - column_index) * column_step
		var y := origin.y
		for character_index in range(phrase.length()):
			var character := phrase.substr(character_index, 1)
			if character == " ":
				y += row_step * 0.45
				reveal_at += maxf(seconds_per_character, 0.0) * 0.45
				continue
			var baseline := y + row_step * 0.5
			baseline += (_face.get_ascent(font_pixels) - _face.get_descent(font_pixels)) * 0.5
			_glyphs.append({
				"text": character, "position": Vector2(x, baseline),
				"width": glyph_width, "at": reveal_at
			})
			y += row_step
			reveal_at += maxf(seconds_per_character, 0.0)
		if column_index < 4:
			reveal_at += maxf(seconds_between_columns, 0.0)
	_duration = reveal_at + maxf(ink_fade_seconds, 0.001) + 0.20
	_seal_text = str(_entry.get("seal_text", ""))
	_seal_box = Rect2(Vector2(18.0, size.y - 44.0), Vector2(42.0, 30.0))
	if reduce_motion:
		_elapsed = _duration
	_update_ink()
	set_process(_elapsed < _duration)


func _update_ink() -> void:
	queue_redraw()


func _draw() -> void:
	if _face == null or _entry.is_empty():
		return
	var fade := maxf(ink_fade_seconds, 0.001)
	for item: Dictionary in _glyphs:
		var tint := ink_color
		tint.a *= clampf((_elapsed - float(item["at"])) / fade, 0.0, 1.0)
		if tint.a > 0.0:
			# The source is NFC Korean: each cell is one complete Hangul syllable.
			draw_string(_face, item["position"], str(item["text"]),
				HORIZONTAL_ALIGNMENT_CENTER, float(item["width"]), _font_pixels, tint)
	if not _seal_text.is_empty():
		var opacity := clampf((_elapsed - (_duration - 0.20)) / 0.20, 0.0, 1.0)
		var stamp_color := Color("89372a")
		stamp_color.a = opacity
		draw_rect(_seal_box, stamp_color)
		var text_color := Color("f1d7b6")
		text_color.a = opacity
		var baseline := _seal_box.position + Vector2(0.0, _seal_box.size.y * 0.5)
		baseline.y += (_face.get_ascent(13) - _face.get_descent(13)) * 0.5
		draw_string(_face, baseline, _seal_text,
			HORIZONTAL_ALIGNMENT_CENTER, _seal_box.size.x, 13, text_color)
