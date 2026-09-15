extends SceneTree
var c: Node
var failures: int=0
var actions: Array=[]
const OUT="res://.godot/player-playtest-results/"
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
 await process_frame; await process_frame; await create_timer(0.12).timeout
func check(ok: bool,label: String) -> void:
 print("PASS: " if ok else "FAIL: ",label)
 if not ok: failures+=1
func screen(label: String) -> void:
 await settle(); await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label+".png")
func key(target: Viewport,code: Key,ctrl: bool=false,unicode: int=0) -> void:
 for pressed: bool in [true,false]:
  var e:=InputEventKey.new(); e.keycode=code; e.ctrl_pressed=ctrl; e.unicode=unicode; e.pressed=pressed
  if target is PopupMenu: Input.parse_input_event(e)
  else: target.push_input(e,true)
 await settle()
func click(button: Control) -> void:
 await settle()
 if button.get_viewport()!=root:
  button.get_viewport().grab_focus(); button.grab_focus(); await key(button.get_viewport(),KEY_ENTER); return
 var parent: Node=button.get_parent()
 while parent!=null:
  if parent is ScrollContainer: parent.ensure_control_visible(button)
  parent=parent.get_parent()
 await settle()
 var point: Vector2=button.get_global_transform_with_canvas()*(button.size/2)
 for pressed: bool in [true,false]:
  var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=pressed; e.position=point; button.get_viewport().push_input(e,true)
 await settle()
func choose(button: Control,index: int) -> void:
 await click(button)
 var popup: PopupMenu=button.get_popup()
 if not popup.visible:
  button.grab_focus(); await key(button.get_viewport(),KEY_SPACE)
 popup.grab_focus(); await settle()
 for n: int in range(popup.item_count+2):
  if popup.get_focused_item()==index: break
  await key(popup,KEY_DOWN)
 print("POPUP TARGET ",index," ACTUAL ",popup.get_focused_item()," VISIBLE ",popup.visible)
 check(popup.get_focused_item()==index,"popup selection "+popup.get_item_text(index))
 popup.id_pressed.connect(func(id): print("POPUP ACTIVATED ",id),CONNECT_ONE_SHOT)
 await key(popup,KEY_ENTER)
func menu(label: String) -> void:
 var popup: PopupMenu=c.navigation_menu.get_popup()
 for n: int in range(popup.item_count):
  if popup.get_item_text(n)==label: await choose(c.navigation_menu,n); return
 check(false,"missing menu "+label)
func type_into(line: LineEdit,value: String) -> void:
 line.get_viewport().grab_focus(); line.grab_focus(); await settle()
 await key(line.get_viewport(),KEY_A,true)
 for character: String in value:
  for down: bool in [true,false]:
   var e:=InputEventKey.new(); e.pressed=down; e.keycode=character.to_upper().unicode_at(0) as Key; e.unicode=character.unicode_at(0); line.get_viewport().push_input(e,true)
  await process_frame
 await settle()
func pick_file(dialog: FileDialog,file: String) -> void:
 await type_into(dialog.get_line_edit(),file); print("FILE INPUT ",dialog.get_line_edit().text," DIR ",dialog.current_dir," FILE ",dialog.current_file," DISABLED ",dialog.get_ok_button().disabled); dialog.file_selected.connect(func(path): print("UI FILE SELECTED ",path),CONNECT_ONE_SHOT); await key(dialog,KEY_ENTER); await create_timer(1).timeout; await settle(); c=current_scene; await screen("after-file-pick"); print("CURRENT SCENE ",c.name)
func boot() -> void:
 change_scene_to_file("res://title_screen.tscn"); await create_timer(2).timeout; c=current_scene
 check(ProjectSettings.globalize_path("user://").contains("player-playtest-profile"),"launcher uses review profile")
func fresh() -> void:
 await click(c.new_game_button); await create_timer(1.5).timeout; c=current_scene
 await click(c.start_button); await create_timer(2).timeout; c=current_scene
func _run() -> void: quit()
