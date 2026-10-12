# 개발용 '전국 이동 열림'(2026-10-13 사용자 "테스트용이니깐 전국을 열어줘") — 시험 플레이 전용, 실행 중에만 켜지는 덮어쓰기.
#   켜기: 명령줄 `--devtravel`(예: godot --path seolhwa_godot -- --savefile=user://play_chunhyang.json --devtravel)
#         또는 디버그 실행(에디터·`godot --path .` — OS.is_debug_build())에서 F9로 켜고 끈다. 내보낸 판(release)에서는 F9가 없다.
#   켜지면(역마 고르기 지도·역마 창·Travel.stations 모두 같은 규칙):
#     · 가 본 곳이 아니어도 모든 역·깃발·거점이 갈 곳(fast_travel._gather)
#     · 처음 가는 길(안 지난 노정)도 건너뛴다(reachable_from)
#     · 이야기 막음도 푼다 — 남원 첫 사건 고을 막음(gate_why)과 남원 밤 먼 길 막음(lock_why). 이야기 차례가 깨질 수 있다(개발용)
#   저장을 바꾸지 않는다: 켜진 동안 travel_nodes '가 봄'(HorseRide.discover)과 지도 '가 봄'(Discovery.visit)을 적지 않는다.
#   화면 왼쪽 위 "개발: 전국 이동 열림"(scripts/region/travel_overlay.gd).
extends RefCounted

static var on := false

static func set_on(v: bool) -> void:
	if on == v: return
	on = v
	print("DEVTRAVEL %s" % ("on" if v else "off"))
