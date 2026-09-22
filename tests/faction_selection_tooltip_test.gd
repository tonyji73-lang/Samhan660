extends "res://tests/faction_selection_ui_v1_test.gd"
func _run() -> void:
	create_timer(60).timeout.connect(func():quit(2))
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	await enter_setup()
	var v: Control=setup.faction_view
	var found: bool=false
	for label: Node in v._details.get_child(0).get_children():
		if not label.tooltip_text.is_empty():
			check(label.mouse_filter==Control.MOUSE_FILTER_PASS,"age tooltip receives hover")
			var e:=InputEventMouseMotion.new();e.position=label.get_global_rect().get_center();root.push_input(e,true)
			await create_timer(2).timeout;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/faction-ui-polish/1280-age-tooltip.png")
			found=true
	check(found,"age tooltip available")
	print("TOOLTIP: ",checks," checks, ",failures," failures");quit(0 if failures==0 else 1)
