# 1인칭 마우스 잡기(C68 — region_main.fp_mouse_wanted): 눈높이에서 플레이어가 움직일 수 있을 때만 커서를 잡아 숨기고,
#   대화·선택지·카드·문서·지도·역마 창·Esc 멈춤(get_tree().paused)·창이 포커스를 잃었을 때는 놓는다. 닫히면 다시 잡는다.
#   멈춤 동안에도 돌아야 하므로 PROCESS_MODE_ALWAYS. 시험·촬영(region_main._view_automation)은 사용자 커서를 건드리지 않는다.
extends Node

var main

func _init(m) -> void:
	main = m
	name = "fp_mouse"
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_dt: float) -> void:
	if main == null or main._view_automation(): return
	var want: bool = main.fp_mouse_wanted() and not get_tree().paused and DisplayServer.window_is_focused()
	var mode := Input.MOUSE_MODE_CAPTURED if want else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode: Input.mouse_mode = mode

func _exit_tree() -> void:
	if main != null and not main._view_automation(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
