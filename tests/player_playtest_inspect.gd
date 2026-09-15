extends "res://tests/player_playtest_base.gd"
func _run() -> void:
 await boot(); await screen("before-title-load-disabled")
 print("TITLE_LOAD_DISABLED ",c.load_game_button.disabled)
 await fresh(); await menu("저장 파일 선택"); await screen("before-save-menu")
 print("FILE_VISIBLE ",c.ending_load_dialog.visible," POWER_VISIBLE ",c.power_dialog.visible)
 print("MENU_ITEMS ")
 var popup: PopupMenu=c.navigation_menu.get_popup()
 for n: int in range(popup.item_count): print(popup.get_item_text(n)," ID ",popup.get_item_id(n))
 quit()
