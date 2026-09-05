extends PanelContainer

signal domestic_requested(province_id: String)
signal production_requested(province_id: String)
signal recruit_requested(province_id: String)
signal sortie_requested(province_id: String)
signal move_requested(province_id: String)
signal detail_requested(province_id: String)

var province_id: String = ""

@onready var city_name_label: Label = %CityNameLabel
@onready var faction_label: Label = %FactionLabel
@onready var governor_label: Label = %GovernorLabel
@onready var population_value: Label = %PopulationValue
@onready var troops_value: Label = %TroopsValue
@onready var public_order_value: Label = %PublicOrderValue
@onready var fortress_value: Label = %FortressValue
@onready var food_stock_label: Label = %FoodStockLabel
@onready var domestic_button: Button = %DomesticButton
@onready var production_button: Button = %ProductionButton
@onready var recruit_button: Button = %RecruitButton
@onready var sortie_button: Button = %SortieButton
@onready var move_button: Button = %MoveButton
@onready var detail_button: Button = %DetailButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	domestic_button.pressed.connect(_emit_action.bind(domestic_requested))
	production_button.pressed.connect(_emit_action.bind(production_requested))
	recruit_button.pressed.connect(_emit_action.bind(recruit_requested))
	sortie_button.pressed.connect(_emit_action.bind(sortie_requested))
	move_button.pressed.connect(_emit_action.bind(move_requested))
	detail_button.pressed.connect(_emit_action.bind(detail_requested))


func configure(
	new_province_id: String,
	province: Dictionary,
	action_states: Dictionary = {}
) -> void:
	province_id = new_province_id
	city_name_label.text = _display_text(province, "name", "도시 정보")
	faction_label.text = "세력  %s" % _display_text(province, "faction")
	governor_label.text = "태수  %s" % _display_text(province, "governor")
	population_value.text = _display_number(province, "population")
	troops_value.text = _display_number(province, "troops")
	public_order_value.text = _display_number(province, "public_order")
	fortress_value.text = _display_number(province, "fortress")
	food_stock_label.text = "군량  %d / %d" % [
		int(province.get("food_stock", 0)),
		int(province.get("granary_capacity", 0)),
	]

	domestic_button.disabled = not bool(action_states.get("domestic", true))
	production_button.disabled = not bool(action_states.get("production", false))
	recruit_button.disabled = not bool(action_states.get("recruit", true))
	sortie_button.disabled = not bool(action_states.get("sortie", true))
	move_button.disabled = not bool(action_states.get("move", true))
	detail_button.disabled = not bool(action_states.get("detail", true))


func _display_text(data: Dictionary, key: String, fallback: String = "-") -> String:
	if not data.has(key) or str(data[key]).is_empty():
		return fallback
	return str(data[key])


func _display_number(data: Dictionary, key: String) -> String:
	if not data.has(key) or data[key] == null:
		return "-"
	return "%d" % int(data[key])


func _emit_action(action_signal: Signal) -> void:
	if province_id != "":
		action_signal.emit(province_id)


func _apply_style() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.047, 0.037, 0.92)
	panel_style.border_color = Color(0.72, 0.58, 0.31, 0.78)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	panel_style.shadow_size = 8
	add_theme_stylebox_override("panel", panel_style)

	for button: Button in [domestic_button, recruit_button, sortie_button, move_button, detail_button, production_button]:
		button.custom_minimum_size = Vector2(46.0, 30.0)
		button.focus_mode = Control.FOCUS_NONE
