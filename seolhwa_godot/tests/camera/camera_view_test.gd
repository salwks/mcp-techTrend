# 카메라 기본 각·깊이 흐림 손잡이 시험(2026-10 — 기본 40° · 도시 구역 40 · 깊이 흐림 · 1인칭 값) — 헤드리스, 저장 없음.
#   godot --headless --path . -s res://tests/camera/camera_view_test.gd
#   A 기본 각: CameraRig.DEFAULT pitch 40 · 권역 기본·고을 구역 40 · region.json camera_zones 전부 38~42(이전 45·47) · north.py 원본도 같은 값
#     마을 무대 구도(visual-pass): 짓는 고을·도시 구역만 RegionWorld.TOWN_FRAME(30~40°) — 숲·고개는 그대로
#   B 연출 값 그대로: 대화 TALK 38/13.5/38 · override(d.camera·각본)가 구역보다 이기고 값이 그대로 · shot(pos·look·fov)이 그대로 카메라에
#   C 깊이 흐림: PostEffect.tilt(옛 이름)와 dof가 같은 값 · 끄면 둘 다 꺼짐 · 1인칭 상수(눈높이 1.55 · 층 20 · ±70°) · 먼 산 대기 원근(150m 밖) · 땅 잔무늬 15m
#   끝 줄: CAMVIEWTEST PASS n / CAMVIEWTEST FAIL n
extends SceneTree

const RegionWorld := preload("res://scripts/region/region_world.gd")
const RegionMain := preload("res://scripts/region/region_main.gd")
const SPACES := ["JL_NAMWON_UNBONG", "GG_HANYANG", "GS_GYEONGJU", "GW_GANGNEUNG", "HH_HWANGJU", "PA_PYEONGYANG", "HG_HAMHEUNG", "JJ_JEJU"]

var n := 0
var fails := 0

func ok(c: bool, what: String) -> void:
	n += 1
	if c: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	await process_frame   # 카메라를 나무에 달려면 한 프레임 뒤(look_at)
	_pitch()
	await _overrides()
	_dof()
	print("CAMVIEWTEST %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)

func _pitch() -> void:
	ok(is_equal_approx(float(CameraRig.DEFAULT.pitch), 40.0), "CameraRig.DEFAULT pitch 40 (%.1f)" % float(CameraRig.DEFAULT.pitch))
	ok(is_equal_approx(float(RegionWorld.CAM_DEFAULT.pitch), 40.0) and is_equal_approx(float(RegionWorld.CAM_TOWN.pitch), 40.0), "권역 기본·고을 구역 40")
	var zones := 0
	for sp in SPACES:
		var f := "res://region_data/%s/region.json" % sp
		if not FileAccess.file_exists(f): continue
		var j = JSON.parse_string(FileAccess.get_file_as_string(f))
		for z in j.get("camera_zones", []):
			zones += 1
			var p := float(z.get("pitch", 40.0))
			ok(p >= 38.0 and p <= 42.0, "%s '%s' pitch %.0f (38~42)" % [sp, z.get("name", ""), p])
	ok(zones == 5, "도시 구역 다섯(한양 3 · 평양 1 · 함흥 1) — %d" % zones)
	# 마을 무대 구도(visual-pass 3단계): 원본 값(CAM_TOWN·region.json)은 40 그대로, 짓는 구역에만 TOWN_FRAME — 숲·고개·기본은 그대로
	var tf: Dictionary = RegionWorld.TOWN_FRAME
	var tc: Dictionary = RegionWorld.town_cam(RegionWorld.CAM_TOWN)
	ok(is_equal_approx(float(tc.pitch), float(tf.pitch)) and is_equal_approx(float(tc.distance), 22.0 * float(tf.dist_k)), "고을 구역 → 마을 무대 구도 %.0f° / %.1fm" % [float(tc.pitch), float(tc.distance)])
	ok(float(tf.pitch) >= 30.0 and float(tf.pitch) <= 40.0 and float(tf.dist_k) >= 0.7 and float(tf.dist_k) <= 1.0, "마을 무대 구도 범위(30~40° · 거리 0.7~1.0배)")
	var tforest: Dictionary = RegionWorld.town_cam(RegionWorld.CAM_FOREST)
	var tpass: Dictionary = RegionWorld.town_cam(RegionWorld.CAM_PASS)
	ok(float(tforest.pitch) == 48.0 and float(tpass.pitch) == 30.0 and float(RegionWorld.CAM_DEEP.pitch) == 55.0, "숲길 48 · 고개 30 · 길 밖 숲 55 그대로(마을 구도 안 받음)")
	var py := FileAccess.get_file_as_string("res://tools/placement/north.py")
	ok(py.find("\"pitch\": 45.0") < 0 and py.find("\"pitch\": 47.0") < 0, "north.py CAM_ZONES에도 45·47 없음(다시 만들어도 40)")

func _overrides():
	ok(float(CameraRig.TALK.pitch) == 38.0 and float(CameraRig.TALK.distance) == 13.5 and float(CameraRig.TALK.fov) == 38.0, "대화 카메라 TALK 38/13.5/38 그대로")
	var cam := Camera3D.new()
	root.add_child(cam)
	await process_frame
	var w := World.new()
	w.camera_zones = [{ name = "도성 안", minX = -100.0, maxX = 100.0, minZ = -100.0, maxZ = 100.0, pitch = 40.0, distance = 26.0 }]
	var rig := CameraRig.new(cam, w)
	var p := rig.params(Vector3.ZERO, null)
	ok(is_equal_approx(float(p.pitch), 40.0) and is_equal_approx(float(p.distance), 26.0), "구역 값이 기본을 덮음")
	# 남원 7A 같은 사건 카메라(d.camera {pitch 34, distance 17, fov 36})와 8A 공식 틀(가파른 값)은 구역·기본과 상관없이 그대로
	for spec in [{ pitch = 34.0, distance = 17.0, fov = 36.0 }, { pitch = 58.0, distance = 24.0 }, { pitch = 12.0, distance = 9.0, fov = 44.0 }]:
		rig.override = spec
		var q := rig.params(Vector3.ZERO, null)
		var same := true
		for k in spec: same = same and is_equal_approx(float(q[k]), float(spec[k]))
		ok(same, "override 그대로 %s" % str(spec))
	rig.override = null
	rig.shot = { pos = Vector3(3, 5, 10), look = Vector3(0, 1, 0), fov = 27.0 }
	rig.update(0.016, Vector3.ZERO, "up", null, true)
	ok(cam.position.is_equal_approx(Vector3(3, 5, 10)) and is_equal_approx(cam.fov, 27.0), "각본 shot: 자리·fov 그대로")
	rig.shot = null
	rig.update(0.016, Vector3.ZERO, "up", null, true)
	var dv := cam.position - rig.target
	var ang := rad_to_deg(asin(dv.y / dv.length()))
	ok(absf(ang - 40.0) < 0.01, "평소 시점 내려다보는 각 %.2f° (40)" % ang)
	w.free(); cam.free()

func _dof() -> void:
	var pe := PostEffect.new()
	ok(pe.dof and pe.tilt, "깊이 흐림 기본 켬")
	pe.tilt = false
	ok(not pe.dof, "옛 이름 tilt=false → dof 꺼짐(--notilt · P · 남원 _tilt)")
	pe.dof = true
	ok(pe.tilt, "dof=true → tilt도 켬")
	ok(pe.dof_far > 0.0 and pe.dof_far <= 0.6 and pe.dof_near <= 0.35, "기본 세기 약함(먼 %.2f · 앞 %.2f)" % [pe.dof_far, pe.dof_near])
	ok(RegionMain.DOF_WALK.far <= 0.6 and RegionMain.DOF_LOW.far < RegionMain.DOF_WALK.far, "배·말 낮은 시점은 덜 흐림")
	ok(is_equal_approx(RegionMain.FP_EYE, 1.55) and RegionMain.PLAYER_LAYER == 1 << 19, "1인칭 눈높이 1.55 · 플레이어 층 20")
	# 먼 산 대기 원근(C67 v2): 150m 안은 그대로, 밖에서만 흐림 한 단계 + 옅은 안개
	ok(pe.aerial_start >= 150.0 and pe.aerial_blur > 0.0 and pe.aerial_blur <= 0.25 and pe.aerial_haze <= 0.15, "먼 산 대기 원근: %.0fm 밖 · 흐림 +%.2f · 안개 %.2f" % [pe.aerial_start, pe.aerial_blur, pe.aerial_haze])
	ok(RegionMain.AERIAL_BLUR == pe.aerial_blur and RegionMain.AERIAL_HAZE == pe.aerial_haze, "region_main 대기 원근 값 = PostEffect 기본")
	ok(PostEffect.FINAL.contains("smoothstep(p.aerial.x, p.aerial.x + p.aerial.y, D)"), "대기 원근은 깊이로만(시작 거리 밖)")
	# 1인칭 v2(C68): 마우스 위아래 ±70° · 가까운 땅 잔무늬(0~15m, 지형 셰이더)
	ok(absf(rad_to_deg(RegionMain.FP_PITCH) - 70.0) < 0.1, "1인칭 위아래 ±70°")
	var ter := FileAccess.get_file_as_string("res://shaders/region_terrain.gdshader")
	ok(ter.contains("uniform float near_detail = 0.0") and ter.contains("smoothstep(9.0, 15.0, dist)"), "땅 잔무늬: 기본 끔 · 15m에서 사라짐")
