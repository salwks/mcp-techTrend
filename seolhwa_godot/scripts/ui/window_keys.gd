# 창 키 — F11 · Alt+Enter: 전체 화면 켜고 끄기(어느 화면·메뉴가 열려 있어도 먼저 받는다).
#   region_main이 루트 창 맨 뒤 자식으로 단다(입력은 뒤 자식부터 받으므로 이야기 UI의 Enter 확인보다 먼저).
extends Node

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	var k: int = ev.physical_keycode
	if k == KEY_F11 or (ev.alt_pressed and k in [KEY_ENTER, KEY_KP_ENTER]):
		var win := get_window()
		win.mode = Window.MODE_WINDOWED if win.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
