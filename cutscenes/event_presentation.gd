extends CanvasLayer

# Campaign-scoped service, not an Autoload. Simulation commits results BEFORE
# calling play(); choice mode delegates a decision to the campaign resolver.
# Next, skip, filtering and restore never apply simulation effects.
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
	events["noble_personnel_demand"]={"id":"noble_personnel_demand","requires_choice":true,"importance":"major","steps":[
		{"mode":"choice","title":"귀족의 인사 요구 · 게임용 정무 사건","text":"{group}의 {candidate}이(가) {position} 자리를 요구합니다. 실제 역사적 반란을 재현하는 사건이 아닙니다.","choices":[
			{"id":"accept","label":"인사 수락","description":"실제 임명과 기존 담당자 해임","preview":["일반 인사 반응만 적용"]},
			{"id":"gift","label":"포상으로 타협","description":"직책 유지 · 국고 금100","preview":["충성 +5 / 협력 +6"]},
			{"id":"reject","label":"요구 거절","description":"국고·직책 유지","preview":["충성 -6 / 협력 -6"]}]},
		{"mode":"result","title":"정무 결정","results":[{"label":"결과","value":"{result_text}"}],"duration":1.0}]}
	view = View.new()
	view.name = "CutsceneView"
	add_child(view)
	view.next_requested.connect(next)
	view.skip_requested.connect(skip)
	view.auto_changed.connect(set_auto)
	view.menu_requested.connect(open_menu)
	view.choice_requested.connect(_choose)
	view.save_requested.connect(func(): campaign._on_save_button_pressed())
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
	# Required decisions need an authoritative campaign pending record.
	if bool(event.get("requires_choice", false)):
		return false
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


func play_choice(pending: Dictionary, resuming: bool = false) -> bool:
	var id: String = str(pending.get("event_id", ""))
	var occurrence: String = str(pending.get("occurrence_id", ""))
	if not events.has(id) or not bool(events[id].get("requires_choice", false)) or occurrence.is_empty():
		return false
	if current.get("occurrence", "") == occurrence:
		return false
	for entry: Dictionary in queue:
		if entry.get("occurrence", "") == occurrence:
			return false
	# Campaign pending state is the authority for resumption; a presentation
	# receipt alone must never discard an unresolved decision after loading.
	var templates: Array = events[id].get("steps", []).duplicate(true)
	var choice_index: int = -1
	for index: int in range(templates.size()):
		if templates[index].get("mode", "") == "choice":
			choice_index = index
	if choice_index < 0:
		return false
	var valid_pending: bool = false
	for choice: Dictionary in templates[choice_index].get("choices", []):
		if campaign.get_event_choice_reason(id, occurrence, str(choice.id)).is_empty():
			valid_pending = true
	if not valid_pending:
		return false
	occurrence_ids[occurrence] = true
	var payload: Dictionary = pending.get("payload", {}).duplicate(true)
	queue.append({"id": id, "occurrence": occurrence, "requires_choice": true, "resolved": false,
		"templates": templates, "payload": payload, "steps": substitute(templates, payload),
		"start_index": choice_index if resuming or display_level == "minimal" else 0})
	if not active:
		_start_next()
	return true


func awaiting_choice() -> bool:
	return active and bool(current.get("requires_choice", false)) and not bool(current.get("resolved", false))


func _choose(choice_id: String) -> void:
	if not awaiting_choice() or menu_open() or current.steps[step_index].get("mode", "") != "choice":
		return
	var result: Dictionary = campaign.resolve_event_choice(str(current.id), str(current.occurrence), choice_id)
	if result.is_empty():
		_show_step()
		return
	current.resolved = true
	current.payload.merge(result, true)
	current.steps = substitute(current.templates, current.payload)
	step_index += 1
	_show_step()


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
	# Close lower-layer modals before taking a turn/map input snapshot.
	campaign.production_overlay.hide()
	for property: String in ["domestic_overlay","recruitment_overlay","industry_overlay", "supply_overlay","army_overlay","politics_overlay"]:
		var overlay: Variant=campaign.get(property)
		if overlay!=null: overlay.hide()
	campaign._close_diplomacy()
	active = true
	saved_turn_disabled = campaign.end_turn_button.disabled
	campaign.end_turn_button.disabled = true
	adapter.begin()
	current = queue.pop_front()
	step_index = int(current.get("start_index", 0))
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
	view.skip_button.disabled = awaiting_choice()
	view.auto_button.disabled = awaiting_choice()
	view.next_button.disabled = step.get("mode", "") == "choice"
	view.save_button.visible = awaiting_choice()
	if step.get("mode", "") == "choice":
		var choices: Array = step.get("choices", []).duplicate(true)
		for choice: Dictionary in choices:
			choice["reason"] = campaign.get_event_choice_reason(str(current.id), str(current.occurrence), str(choice.id))
		view.show_choices(choices)
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
	if current.steps[step_index].get("mode", "") == "choice":
		return
	if view.complete_text():
		return
	step_index += 1
	_show_step()


func skip() -> void:
	if active and not menu_open() and not awaiting_choice():
		_finish()


func set_auto(enabled: bool) -> void:
	auto_play = enabled and not awaiting_choice()
	if view != null:
		view.auto_button.set_pressed_no_signal(auto_play)


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
	# Campaign resumes authoritative pending choices AFTER restoring resources.
	# This presentation restore never replays simulation or resolved results.


func _exit_tree() -> void:
	if is_instance_valid(adapter):
		adapter.queue_free()
