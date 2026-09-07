extends CanvasLayer

# Campaign-scoped service, not an Autoload. Simulation commits results BEFORE
# calling play(); neither next, skip, filtering nor restore can apply rewards.
signal event_finished(event_id: String)
signal step_changed(event_id: String, index: int)

const View = preload("res://cutscenes/cutscene_view.gd")
const MapAdapter = preload("res://cutscenes/map_cinematic_adapter.gd")
const CATALOG_PATH: String = "res://cutscenes/cutscene_catalog_v1.json"
const LEVELS: Array[String] = ["all", "major", "minimal"]

var catalog: Dictionary = {}
var events: Dictionary = {}
var completed_ids: Dictionary = {}
var occurrence_ids: Dictionary = {}
var display_level: String = "all"
var queue: Array[Dictionary] = []
var current: Dictionary = {}
var step_index: int = -1
var active: bool = false
var auto_play: bool = false
var step_elapsed: float = 0.0
var campaign: Node
var view: Control
var adapter: Node2D
var saved_turn_disabled: bool = false
var music: AudioStreamPlayer
var sound: AudioStreamPlayer


func setup(host: Node) -> void:
	campaign = host
	name = "EventPresentation"
	layer = 150
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not parsed is Dictionary:
		push_error("Cutscene catalog must be a JSON object")
		return
	catalog = parsed
	for entry: Dictionary in catalog.get("cutscenes", []):
		events[str(entry.id)] = entry
	view = View.new()
	view.name = "CutsceneView"
	add_child(view)
	view.next_requested.connect(next)
	view.skip_requested.connect(skip)
	view.auto_changed.connect(set_auto)
	view.menu_requested.connect(open_menu)
	adapter = MapAdapter.new()
	adapter.setup(campaign, catalog.get("map_targets", {}))
	campaign.map_area.add_child(adapter)
	music = AudioStreamPlayer.new()
	sound = AudioStreamPlayer.new()
	add_child(music)
	add_child(sound)
	var popup: PopupMenu = campaign.navigation_menu.get_popup()
	popup.add_separator("이벤트 연출")
	for index: int in range(LEVELS.size()):
		popup.add_radio_check_item(["전체", "중요 이벤트만", "최소"][index], 100 + index)
	popup.id_pressed.connect(_on_menu_choice)
	popup.about_to_popup.connect(_refresh_menu)


func _refresh_menu() -> void:
	var popup: PopupMenu = campaign.navigation_menu.get_popup()
	for index: int in range(LEVELS.size()):
		popup.set_item_checked(popup.get_item_index(100 + index), display_level == LEVELS[index])


func _on_menu_choice(id: int) -> void:
	if id >= 100 and id < 103:
		display_level = LEVELS[id - 100]


func open_menu() -> void:
	if active:
		campaign.navigation_menu.get_popup().popup_centered()


func menu_open() -> bool:
	return campaign.navigation_menu.get_popup().visible or campaign.navigation_menu.confirmation_dialog.visible


func play(event_id: String, payload: Dictionary = {}, occurrence_id: String = "") -> bool:
	if not events.has(event_id):
		return false
	var event: Dictionary = events[event_id]
	var steps: Array = substitute(event.get("steps", []), payload)
	var unresolved := RegEx.new()
	unresolved.compile("\\{[A-Za-z_][A-Za-z0-9_]*\\}")
	if steps.is_empty() or unresolved.search(JSON.stringify(steps)) != null:
		return false
	if bool(event.get("once_per_campaign", false)) and completed_ids.has(event_id):
		return false
	if not occurrence_id.is_empty() and occurrence_ids.has(occurrence_id):
		return false
	# Reserve on acceptance, including filtered/queued scenes. A save during an
	# opening must not replay it on load. No mid-scene simulation is replayed.
	if bool(event.get("once_per_campaign", false)):
		completed_ids[event_id] = true
	if not occurrence_id.is_empty():
		occurrence_ids[occurrence_id] = true
	if display_level == "minimal" or (display_level == "major" and event.get("importance", "normal") != "major"):
		event_finished.emit(event_id)
		return true
	queue.append({"id": event_id, "steps": steps})
	if not active:
		_start_next()
	return true


func dispatch(context: Dictionary, payload: Dictionary = {}, occurrence_id: String = "") -> int:
	var count: int = 0
	for id: String in events:
		var trigger: Dictionary = events[id].get("trigger", {})
		var matches: bool = not trigger.is_empty()
		for key: String in trigger:
			if context.get(key) != trigger[key]:
				matches = false
		if matches and play(id, payload, occurrence_id + ":" + id if not occurrence_id.is_empty() else ""):
			count += 1
	return count


static func substitute(value: Variant, payload: Dictionary) -> Variant:
	if value is String:
		var text: String = value
		for key: Variant in payload:
			text = text.replace("{%s}" % str(key), str(payload[key]))
		return text
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(substitute(item, payload))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = substitute(value[key], payload)
		return result
	return value


func _start_next() -> void:
	if queue.is_empty():
		return
	active = true
	saved_turn_disabled = campaign.end_turn_button.disabled
	campaign.end_turn_button.disabled = true
	adapter.begin()
	current = queue.pop_front()
	step_index = 0
	set_auto(false)
	_show_step()


func _show_step() -> void:
	if step_index >= current.steps.size():
		_finish()
		return
	var step: Dictionary = current.steps[step_index]
	step_elapsed = 0.0
	adapter.clear_step()
	view.show_step(step, catalog)
	if step.get("mode", "") == "map":
		adapter.play_step(step)
	play_audio(music, str(step.get("music", "")))
	play_audio(sound, str(step.get("sfx", "")))
	step_changed.emit(str(current.id), step_index)


func play_audio(player: AudioStreamPlayer, id: String) -> void:
	player.stop()
	# The handoff has symbolic cue IDs but no audio assets. Empty/unregistered
	# cues are intentionally silent. Add actual res:// paths in audio_cues later.
	var path: String = str(catalog.get("audio_cues", {}).get(id, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		player.stream = load(path) as AudioStream
		player.play()


func next() -> void:
	if not active or menu_open():
		return
	if view.complete_text():
		return
	step_index += 1
	_show_step()


func skip() -> void:
	if active and not menu_open():
		_finish()


func set_auto(enabled: bool) -> void:
	auto_play = enabled
	if view != null:
		view.auto_button.set_pressed_no_signal(enabled)


func _process(delta: float) -> void:
	if not active:
		return
	var paused: bool = menu_open()
	adapter.set_paused(paused)
	if paused:
		return
	view.tick(delta)
	step_elapsed += delta
	if auto_play and step_elapsed >= maxf(float(current.steps[step_index].get("duration", 4.0)), float(view.body_label.text.length()) / 45.0):
		step_index += 1
		_show_step()


func _finish() -> void:
	var id: String = str(current.get("id", ""))
	active = false
	view.hide()
	current.clear()
	step_index = -1
	music.stop()
	sound.stop()
	campaign.end_turn_button.disabled = saved_turn_disabled
	adapter.finish()
	set_auto(false)
	event_finished.emit(id)
	_start_next()


func export_state() -> Dictionary:
	return {"version": 1, "completed_ids": completed_ids.duplicate(), "occurrence_ids": occurrence_ids.duplicate(), "display_level": display_level}


func restore_state(data: Dictionary) -> void:
	queue.clear()
	if active:
		_finish()
	completed_ids = data.get("completed_ids", {}).duplicate() if data.get("completed_ids", {}) is Dictionary else {}
	occurrence_ids = data.get("occurrence_ids", {}).duplicate() if data.get("occurrence_ids", {}) is Dictionary else {}
	display_level = str(data.get("display_level", "all"))
	if not LEVELS.has(display_level):
		display_level = "all"
	# Restoring never calls dispatch/play and never resumes a pending result.


func _exit_tree() -> void:
	if is_instance_valid(adapter):
		adapter.queue_free()
