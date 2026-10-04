# 끝내기 정리 — 스크립트 static 캐시(재질·셰이더·텍스처·그림 묶음·식생 원본 메시)를 렌더 서버가 내려가기 전에 비운다.
# static 값은 GDScript가 내려갈 때(렌더 서버 정리 뒤) 풀려 "RID allocations leaked at exit"가 나고, 헤드리스에서는
# 이미 사라진 서버에 자원을 돌려주다 signal 11 / 종료 코드 134로 끝났다. region_main._quit()이 get_tree().quit() 직전에 부른다.
extends RefCounted

const SCRIPTS := {
	"res://scripts/materials.gd": ["_shaders", "_ramp"],
	"res://scripts/sprite_char.gd": ["_banks", "_shaders", "_merged"],
	"res://scripts/kit/kit.gd": ["_tex", "_mats"],
	"res://scripts/combat/combat_fx.gd": ["_shaders"],
	"res://scripts/region/state_fx.gd": ["_shader_mix", "_shader_add", "_quad"],
	"res://scripts/region/prop_states.gd": ["_tint_mats"],
	"res://kit/nature/scatter.gd": ["_cache", "_mix_cache"],
	"res://kit/story/park_mark.gd": ["_mat"],
	"res://scripts/ui_fonts.gd": ["_raw", "_main", "_classic", "_sys"],
	"res://scripts/story/journal_view.gd": ["_hanji"],
}

static func run() -> void:
	if ResourceLoader.has_cached("res://scripts/ui_fonts.gd"):
		ThemeDB.fallback_font = null   # 테마 기본 글꼴로 꽂아 둔 덕온공주체도 놓아 준다
	for path in SCRIPTS:
		if not ResourceLoader.has_cached(path): continue   # 이번 실행에서 안 쓴 스크립트는 건드리지 않는다
		var s: Script = load(path)
		if s == null: continue
		for nm in SCRIPTS[path]:
			var v = s.get(nm)
			if v is Dictionary: (v as Dictionary).clear()
			elif v is Array: (v as Array).clear()
			elif v is Object: s.set(nm, null)
