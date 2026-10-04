# 권역 월드(지형 엔진) — 계약서 docs/REGION_CONTRACTS.md §6.
# 기존 World(scripts/world.gd)를 이어받아 같은 필드·함수(height_at, blocked, move_circle, interior_at, camera_zones,
# interiors, occluders, lights, npcs, spawn, update)를 그대로 쓰게 하고, landuse_at · focus · add_static을 더한다.
#
# 지형 표현
#   - 데이터: region.json + height.png(16비트) + landuse.png(8비트 인덱스). 경로는 data_dir 하나로 바꾼다.
#   - 타일 256m. 플레이어 타일 기준 체비셰프 반경 2 = 근경(1m 격자 + 아주 약한 잡음), 3~4 = 중경(4m 격자),
#     그 너머 = 원경(권역 전체 32m 격자, 먹빛 능선 셰이더, 근·중경 사각형은 구멍).
#   - 메시는 "평평한 정수 격자" 하나를 모든 타일이 같이 쓰고, 정점 셰이더가 높이맵 텍스처로 세운다
#     (shaders/region_common.gdshaderinc). 같은 식을 CPU(height_at)도 계산하므로 발이 땅에 붙고,
#     이웃 타일은 같은 월드 좌표의 같은 높이를 쓰므로 이음매가 없다. 근·중경 경계 틈은 치마(skirt)로 가린다.
#     → 타일을 붙이는 데 CPU 메시 굽기가 필요 없어 로딩 중 프레임 정지가 없다.
#   - 백그라운드(WorkerThreadPool): 시작 때 하천 물 메시·원경, 걷는 동안 타일별 식생(kit/nature/scatter.gd).
extends "res://scripts/world.gd"

const PngRaw := preload("res://scripts/region/png_raw.gd")
const Jobs := preload("res://scripts/region/jobs.gd")
const PropStates := preload("res://scripts/region/prop_states.gd")
const Decals := preload("res://scripts/region/decals.gd")
const Farm := preload("res://scripts/region/farm.gd")
var farm = null    # 논·밭 필지(parcels.bin) — 없으면 null(예전 칠한 필지 무늬)
# 사건용 세계 API(docs/reports/world-scenario.md): 프롭 상태(props)·데칼(decals)·장소 덧붙임(world_scenario.json)
var props          # PropStates — set_prop_state(id, 상태)
var indoor = null  # 실내 공간(scripts/region/interior_space.gd) — 들어가 있는 동안 높이·막힘·실내를 이것이 답하고 권역 지형·식생은 숨긴다
var decals         # Decals(Node3D) — 발자국·핏자국·그을림…
var _dyn_cols := []   # 상태가 더한 충돌체(add_dynamic_collider)

const TILE := 256
const NEAR_R := 2        # 근경 반경(타일)
const MID_R := 4         # 중경 반경(타일)
const KEEP := 1          # 근경에서 벗어나도 이만큼은 유지(경계에서 왔다 갔다 할 때 다시 짓지 않게)
const MID_STEP := 4
const CHUNK := 64        # 근경 메시 조각(화면 밖 조각은 그리지 않게)
const FAR_STEP := 32
const SKIRT := 6.0
const GRID := 32.0       # 충돌체 격자 칸(m)
const MAX_JOBS := 2
const MAX_JOBS_LOADING := 6   # 시작 불러오기 화면 동안은 프레임 예산을 따지지 않는다
var loading := false
const SCATTER_PATH := "res://kit/nature/scatter.gd"
const DEFAULT_DIRS := ["res://region_data/JL_NAMWON_UNBONG/", "res://shots/region/tmp_data/"]
# shaders/region_common.gdshaderinc의 LU_DETAIL과 같아야 한다
const LU_DETAIL := [1.0, 0.8, 0.12, 0.45, 0.35, 0.0, 0.35, 1.5, 0.3, 1.0]
const M32 := 0xffffffff

var data_dir := ""
var region := {}
var is_route := false       # 노정(route.json) 공간
var K := 0.30               # 압축(region.json projection.K) — 권역마다 다르다
var block_water := true
var markers := true
var use_scatter := true
var split_scatter := true   # 식생 묶음을 SUB m로 다시 나누기(시험용으로 끌 수 있음 --nosplit)

# 높이(부모의 hx0, hz0, hstep, hnx, hnz를 그대로 쓴다)
var hbytes: PackedByteArray
var hbpp := 2
var hy0 := 0.0
var hscale := 0.0
# 토지이용
var lbytes: PackedByteArray
var lx0 := 0.0; var lz0 := 0.0; var lcell := 2.0; var lw := 0; var lh := 0

var tile_min := Vector2i.ZERO
var tile_max := Vector2i.ZERO
var tiles := {}             # Vector2i → { lod, mi, scatter_nodes, scatter_lod, scatter_job }
var mat_near: ShaderMaterial
var mat_mid: ShaderMaterial
var mat_far: ShaderMaterial
var mat_water: ShaderMaterial
var mesh_near: ArrayMesh
var mesh_mid: ArrayMesh
var far_node: MeshInstance3D
var terrain_root: Node3D
var water_root: Node3D
var statics_root: Node3D
var scatter_root: Node3D
var height_tex: ImageTexture
# 칠하기 텍스처(높이 격자와 같은 2m, RGBA8): R = 가장 가까운 길 중심선까지 거리(×16, 0~16m), G = 그 길 반폭(×32, 0~8m),
# B = 가장 가까운 건물 footprint 바깥 거리(×16, 0~16m, 마당 흙), A = 길 등급(대로 4·지선 3·마을길 2·산길 1, ×60)
var pbytes: PackedByteArray
var _p_roads: PackedByteArray   # 길만 그린 상태(배치 다시 읽기 때 되돌림)
var paint_tex: ImageTexture
var _paint_dirty := false
var landuse_tex: ImageTexture
var lights_version := 0
var stats := { near = 0, mid = 0, jobs = 0, scatter_done = 0, statics = 0 }

var _center := Vector2i(1 << 20, 1 << 20)
var _pool := []
var _statics := {}          # Vector2i → [ entry ]  entry = { node, colliders, lights, occ, interior, attached, big }
var _static_grid := {}      # Vector2i(칸) → [collider]
var _scatter_grid := {}     # 타일 → { 칸 → [collider] }
var _scatter_script: Script = null
var _queue := []            # 식생 대기 타일
var _attach_q := []         # [타일, 묶음, 세대] 붙이기 대기
var _gen := 0
const ATTACH_PER_FRAME := 24
var _crossings := []
var _crossings_all := []
# 배치(§8): 터 고르기·식생 비우기·걷기 면
var _h_orig: PackedByteArray     # 손대기 전 높이·토지이용(다시 읽기 때 되돌림)
var _l_orig: PackedByteArray
var _terrain_dirty := false
var _veg_excl := []             # [{c: Vector2, ry, half: Vector2}] 월드
var _walk_grid := {}            # 칸 → [walk]
var _walks := []
var tile_listener := Callable()
var _ponds := []                # [{poly: PackedVector2Array(월드), bb: Rect2, y}] 못(걸어 들어가지 못함)   # 새 타일이 생길 때 불림(배치 지연 짓기)
var _river_grid := {}
var lod0_dist := 32.0       # 이 거리(플레이어→묶음 사각형) 안의 식생 묶음은 lod 0
var scatter_far := 220.0    # 이 너머 식생은 안개 속이라 그리지 않는다(region_main이 안개 농도로 정한다)
var _lod_dirty := false
var _lod_frame := 0
var _tall := {}             # 타일 → { 8m 칸 → [[MultiMesh, 번호, Transform3D, 수관 반지름]] } (가림 처리용 큰 식생)
var _cut := {}              # [타일, MultiMesh id, 번호] → { mm, i, xf, k(0..1 보이는 정도), want }
const CUT_CELL := 8.0
const SHADOW_MIN_H := 0.9  # 이보다 낮은 식생(풀·꽃·잔돌)은 그림자를 그리지 않는다
const SUB := 64.0           # 식생 묶음을 다시 나눌 칸(m)       # 칸 → [{seg:{a,b,r}}]

# ---------------------------------------------------------------------------
# 불러오기
# ---------------------------------------------------------------------------
static func find_data_dir(pref := "") -> String:
	if pref != "":
		return pref if pref.ends_with("/") else pref + "/"
	for d in DEFAULT_DIRS:
		if FileAccess.file_exists(d + "region.json") and FileAccess.file_exists(d + "height.png"): return d
	return ""

# 공간 정의 파일: 권역 region.json, 노정 route.json(같은 형식 + from_region·to_region·stops·portals — 계약서 §10)
static func space_file(dir: String) -> String:
	if FileAccess.file_exists(dir + "region.json"): return dir + "region.json"
	if FileAccess.file_exists(dir + "route.json"): return dir + "route.json"
	return ""

func load_region(dir := "") -> void:
	data_dir = find_data_dir(dir)
	if data_dir == "":
		push_error("권역 데이터가 없다: region_data/JL_NAMWON_UNBONG 또는 shots/region/tmp_data (scripts/region/tools/make_tmp_region.py)")
		return
	var t0 := Time.get_ticks_msec()
	var sf := space_file(data_dir)
	if sf == "":
		push_error("공간 파일(region.json/route.json)이 없다: " + data_dir)
		data_dir = ""
		return
	region = JSON.parse_string(FileAccess.get_file_as_string(sf))
	is_route = sf.ends_with("route.json")
	if is_route and not region.has("region_id"): region.region_id = String(region.get("route_id", region.get("id", "route")))
	_merge_overlay(data_dir + "world_scenario.json")
	var pj = region.get("projection")
	K = float(pj.get("K", 0.3)) if pj is Dictionary else 0.3
	var hm: Dictionary = region.height
	var hd := PngRaw.load_gray(ProjectSettings.globalize_path(data_dir + hm.file))
	hbytes = hd.bytes; hbpp = hd.bpp
	hnx = hd.w; hnz = hd.h
	hx0 = float(hm.x0); hz0 = float(hm.z0); hstep = float(hm.cell)
	hy0 = float(hm.y_min)
	hscale = (float(hm.y_max) - hy0) / (65535.0 if hbpp == 2 else 255.0 * 256.0)
	var lm: Dictionary = region.get("landuse", {})
	var lpath: String = data_dir + lm.get("file", "landuse.png")
	if FileAccess.file_exists(lpath):
		var ld := PngRaw.load_gray(ProjectSettings.globalize_path(lpath))
		lbytes = ld.bytes; lw = ld.w; lh = ld.h
	else:
		# 토지이용이 아직 없으면 전부 풀밭(1)으로
		push_warning("landuse.png 없음 — 전부 풀밭으로: " + lpath)
		lw = hnx; lh = hnz
		lbytes = PackedByteArray(); lbytes.resize(lw * lh); lbytes.fill(1)
	lx0 = float(lm.get("x0", hx0)); lz0 = float(lm.get("z0", hz0))
	lcell = float(lm.get("cell", hstep * float(hnx - 1) / maxf(1.0, lw - 1)))
	var sp: Dictionary = region.get("spawn", { x = 0.0, z = 0.0 })
	spawn = Vector2(float(sp.x), float(sp.z))
	_build_camera_zones()
	for c in region.get("crossings", []): _crossings.append(Vector2(float(c.x), float(c.z)))
	_crossings_all = _crossings.duplicate()
	_h_orig = hbytes.duplicate(); _l_orig = lbytes.duplicate()
	tile_min = Vector2i(floori(hx0 / TILE), floori(hz0 / TILE))
	tile_max = Vector2i(floori((hx0 + (hnx - 1) * hstep) / TILE), floori((hz0 + (hnz - 1) * hstep) / TILE))
	_roads_arg = region.get("roads", []) if region.get("roads") is Array else []
	var tp := Time.get_ticks_msec()
	_paint_roads()
	print("REGION roads painted ms=", Time.get_ticks_msec() - tp)
	_make_textures()
	_make_materials()
	terrain_root = Node3D.new(); terrain_root.name = "terrain"; add_child(terrain_root)
	water_root = Node3D.new(); water_root.name = "water"; add_child(water_root)
	statics_root = Node3D.new(); statics_root.name = "statics"; add_child(statics_root)
	scatter_root = Node3D.new(); scatter_root.name = "scatter"; add_child(scatter_root)
	props = PropStates.new(self)
	decals = Decals.new(); decals.setup(self); add_child(decals)
	mesh_near = _grid_mesh(CHUNK, 1)
	mesh_mid = _grid_mesh(TILE / MID_STEP, MID_STEP)
	_build_far()
	_build_rivers()
	farm = Farm.new()
	if not farm.setup(self, data_dir): farm = null
	if use_scatter and FileAccess.file_exists(SCATTER_PATH):
		var scr = load(SCATTER_PATH)
		# 다른 에이전트가 만드는 중이라 문법 오류일 수 있다 → 쓸 수 있을 때만
		var ok: bool = scr is GDScript and scr.can_instantiate()
		if ok:
			ok = false
			for m in scr.get_script_method_list():
				if m.name == "scatter": ok = true
		if ok:
			_scatter_script = scr
			# 모델 메시·재질을 메인 스레드에서 미리 만든다(작업 스레드에서 처음 만들면 느리고 위험)
			for m in scr.get_script_method_list():
				if m.name == "warm":
					var tw := Time.get_ticks_msec()
					scr.warm(0); scr.warm(1)
					print("REGION scatter warm ms=", Time.get_ticks_msec() - tw)
		else: push_warning("kit/nature/scatter.gd를 쓸 수 없어 식생을 건너뛴다")
	if markers: _place_markers()
	print("REGION data=%s %dx%d cell=%.1f tiles=%s..%s scatter=%s load_ms=%d" % [data_dir, hnx, hnz, hstep, tile_min, tile_max, _scatter_script != null, Time.get_ticks_msec() - t0])

const ROAD_CLASS := { "대로": 4, "지선": 3, "마을길": 2, "산길": 1 }

# region.json roads를 칠하기 텍스처에 그린다(선분 둘레 반폭+6m 안 픽셀만)
func _paint_roads() -> void:
	var img := Image.create(hnx, hnz, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 0))
	pbytes = img.get_data()
	var all_roads: Array = region.get("roads", []).duplicate()
	# 배치가 내보낸 마을 고샅(placement_*.json 최상위 alleys)도 마을길로 칠한다
	for f in DirAccess.get_files_at(data_dir):
		if f.begins_with("placement_") and f.ends_with(".json"):
			var pj = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join(f)))
			if pj is Dictionary:
				for al in pj.get("alleys", []):
					all_roads.append({ "width_m": float(al.get("width_m", 3.0)), "class": "마을길", "points": al.get("points", []) })
				for u in pj.get("urban", []): _urban.append(Rect2(float(u[0]), float(u[1]), float(u[2]) - float(u[0]), float(u[3]) - float(u[1])))
	for r in all_roads:
		var hw := float(r.get("width_m", 3.0)) * 0.5
		var cls: int = ROAD_CLASS.get(String(r.get("class", "")), 2)
		if cls == 4: hw += 0.4  # 대로는 조금 더 넓게
		var pts: Array = r.get("points", [])
		for q in pts.size() - 1:
			var a := Vector2(float(pts[q][0]), float(pts[q][1])); var b := Vector2(float(pts[q + 1][0]), float(pts[q + 1][1]))
			var R := hw + 6.0
			var i0 := clampi(floori((minf(a.x, b.x) - R - hx0) / hstep), 0, hnx - 1); var i1 := clampi(ceili((maxf(a.x, b.x) + R - hx0) / hstep), 0, hnx - 1)
			var j0 := clampi(floori((minf(a.y, b.y) - R - hz0) / hstep), 0, hnz - 1); var j1 := clampi(ceili((maxf(a.y, b.y) + R - hz0) / hstep), 0, hnz - 1)
			var ab := b - a; var l2 := maxf(ab.length_squared(), 1e-6)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var pp := Vector2(hx0 + i * hstep, hz0 + j * hstep)
					var t := clampf((pp - a).dot(ab) / l2, 0.0, 1.0)
					var d := pp.distance_to(a + ab * t)
					var k := (j * hnx + i) * 4
					var dq := clampi(roundi(d * 16.0), 0, 255)
					if dq < pbytes[k]:
						pbytes[k] = dq; pbytes[k + 1] = clampi(roundi(hw * 32.0), 0, 255); pbytes[k + 3] = cls * 60
	_paint_urban()
	_p_roads = pbytes.duplicate()

# 도시 땅(placement_*.json 최상위 urban: [[x0,z0,x1,z1],…] — 도성·평양 내성 골목 구역): 마을 터(6)·길(4) 칸을 모두 마당 흙(B=0)으로,
# 그 사각형 안 식생(풀·꽃·나무)은 비운다. 궁궐·종묘·정원 자리는 배치가 사각형에서 뺐다. 지형 셰이더 urban_ground=1이면 길섶 풀 띠도 흙 위에선 끈다.
var _urban: Array = []
func _paint_urban() -> void:
	for u: Rect2 in _urban:
		var i0 := clampi(floori((u.position.x - hx0) / hstep), 0, hnx - 1); var i1 := clampi(ceili((u.end.x - hx0) / hstep), 0, hnx - 1)
		var j0 := clampi(floori((u.position.y - hz0) / hstep), 0, hnz - 1); var j1 := clampi(ceili((u.end.y - hz0) / hstep), 0, hnz - 1)
		for j in range(j0, j1 + 1):
			var lj := clampi(roundi((hz0 + j * hstep - lz0) / lcell), 0, lh - 1) * lw
			var k := (j * hnx + i0) * 4 + 2
			for i in range(i0, i1 + 1):
				var lu := lbytes[lj + clampi(roundi((hx0 + i * hstep - lx0) / lcell), 0, lw - 1)] & 127
				if lu == 6 or lu == 4: pbytes[k] = 0   # 마을 터 + 길 칸(길 칸은 셰이더가 둘레 풀빛으로 바꾸므로)
				k += 4
	_urban_veg()

func _urban_veg() -> void:
	for u: Rect2 in _urban: add_veg_exclusion(u.get_center(), 0.0, u.size * 0.5)

# 건물 둘레 마당 흙: 회전 사각형(반폭 half) 바깥 거리를 B에 최소값으로
func paint_yard(c: Vector2, ry: float, half: Vector2) -> void:
	var ca := cos(ry); var sa := sin(ry)
	var R := half.length() + 16.0
	var i0 := clampi(floori((c.x - R - hx0) / hstep), 0, hnx - 1); var i1 := clampi(ceili((c.x + R - hx0) / hstep), 0, hnx - 1)
	var j0 := clampi(floori((c.y - R - hz0) / hstep), 0, hnz - 1); var j1 := clampi(ceili((c.y + R - hz0) / hstep), 0, hnz - 1)
	# 안쪽 고리를 줄였다(결과 같음 — 부동소수 끝자리 차이뿐): 회전을 펼쳐 한 칸씩 더하고, 255(≈16m) 넘는 칸은 제곱근 없이 건너뛴다
	var hxh := half.x; var hzh := half.y
	var far2 := (254.5 / 16.0) * (254.5 / 16.0)
	var sx := hstep * ca; var sz := hstep * sa
	for j in range(j0, j1 + 1):
		var dz := hz0 + j * hstep - c.y
		var dx0 := hx0 + i0 * hstep - c.x
		var lx := dx0 * ca - dz * sa; var lz := dx0 * sa + dz * ca
		var k := (j * hnx + i0) * 4 + 2
		for i in range(i0, i1 + 1):
			var ax := maxf(absf(lx) - hxh, 0.0); var az := maxf(absf(lz) - hzh, 0.0)
			var d2 := ax * ax + az * az
			if d2 < far2:
				var dq := clampi(roundi(sqrt(d2) * 16.0), 0, 255)
				if dq < pbytes[k]: pbytes[k] = dq
			lx += sx; lz += sz; k += 4
	_paint_dirty = true

# 카메라 구역(웹 마을과 같은 값): 권역 기본 22m·40°, 고을·장터 22/40, 숲·산길 20/48(플레이어 둘레 숲을 보고 움직이는 구역),
# 고개 22/30(웹 고갯마루). 뒤에 있는 구역이 이긴다(CameraRig). region.json.camera_zones가 있으면 맨 뒤에 붙인다.
const CAM_DEFAULT := { pitch = 40.0, distance = 22.0 }
const CAM_TOWN := { pitch = 40.0, distance = 22.0 }
const CAM_FOREST := { pitch = 48.0, distance = 20.0 }       # 숲길(길 위)
const CAM_DEEP := { pitch = 55.0, distance = 17.0 }         # 길 밖 숲 한가운데: 잎덩이 위로 내려다본다
var forest_active := false   # 숲 구역 안(region_main이 가림 점무늬를 넓힌다)
const CAM_PASS := { pitch = 30.0, distance = 22.0 }
var _forest_zone := {}
var _settle_boxes := []
var _cz_frame := 0

func _build_camera_zones() -> void:
	camera_zones = []
	var big := 1e6
	camera_zones.append(_zone("권역", -big, big, -big, big, CAM_DEFAULT))
	_settle_boxes = []
	for s in region.get("settlements", []):
		var r := clampf(float(s.get("radius_m", 60.0)), 30.0, 220.0)
		var z := _zone(String(s.get("name", "")), float(s.x) - r, float(s.x) + r, float(s.z) - r, float(s.z) + r, CAM_TOWN)
		camera_zones.append(z); _settle_boxes.append(z)
	_forest_zone = _zone("숲·산길", big, big, big, big, CAM_FOREST)
	camera_zones.append(_forest_zone)
	for p in region.get("passes", []):
		var r := 45.0
		camera_zones.append(_zone(String(p.get("name", "고개")), float(p.x) - r, float(p.x) + r, float(p.z) - r, float(p.z) + r, CAM_PASS))
	for z in region.get("camera_zones", []): camera_zones.append(z)

static func _zone(name: String, x0: float, x1: float, z0: float, z1: float, cam: Dictionary) -> Dictionary:
	return { name = name, minX = x0, maxX = x1, minZ = z0, maxZ = z1, pitch = cam.pitch, distance = cam.distance }

# 플레이어 둘레(반경 14m 9점) 반 넘게 숲·대숲이고 고을 안이 아니면 숲 구역을 플레이어에 씌운다(10프레임마다)
func update_camera_zone(pos: Vector3) -> void:
	if indoor != null: forest_active = false; return
	_cz_frame += 1
	if _cz_frame % 10 != 0: return
	var n := 0
	for dz in [-14.0, 0.0, 14.0]:
		for dx in [-14.0, 0.0, 14.0]:
			var c := landuse_at(pos.x + dx, pos.z + dz)
			if c == 0 or c == 9: n += 1
	var in_town := false
	for b in _settle_boxes:
		if in_box(b, pos.x, pos.z): in_town = true; break
	if n >= 5 and not in_town:
		_forest_zone.minX = pos.x - 40.0; _forest_zone.maxX = pos.x + 40.0; _forest_zone.minZ = pos.z - 40.0; _forest_zone.maxZ = pos.z + 40.0
		var cam: Dictionary = CAM_DEEP if road_distance(pos.x, pos.z) > 6.0 else CAM_FOREST
		_forest_zone.pitch = cam.pitch; _forest_zone.distance = cam.distance
	elif not in_box(_forest_zone, pos.x, pos.z) or n <= 2 or in_town:
		_forest_zone.minX = 1e6; _forest_zone.maxX = 1e6
	forest_active = in_box(_forest_zone, pos.x, pos.z)

# 가장 가까운 길(region.json roads) 가장자리까지 거리(m, 칠하기 텍스처 R·G)
func road_distance(x: float, z: float) -> float:
	var i := clampi(roundi((x - hx0) / hstep), 0, hnx - 1); var j := clampi(roundi((z - hz0) / hstep), 0, hnz - 1)
	var k := (j * hnx + i) * 4
	return pbytes[k] / 16.0 - pbytes[k + 1] / 32.0

func _make_textures() -> void:
	var himg := Image.create_from_data(hnx, hnz, false, Image.FORMAT_RG8 if hbpp == 2 else Image.FORMAT_R8, hbytes)
	height_tex = ImageTexture.create_from_image(himg)
	var limg := Image.create_from_data(lw, lh, false, Image.FORMAT_R8, lbytes)
	landuse_tex = ImageTexture.create_from_image(limg)
	paint_tex = ImageTexture.create_from_image(Image.create_from_data(hnx, hnz, false, Image.FORMAT_RGBA8, pbytes))

func _common_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("hmap", height_tex)
	m.set_shader_parameter("lumap", landuse_tex)
	m.set_shader_parameter("h_meta", Vector4(hx0, hz0, 1.0 / hstep, 0.0))
	m.set_shader_parameter("h_range", Vector2(hy0, hscale))
	m.set_shader_parameter("h_size", Vector2i(hnx, hnz))
	m.set_shader_parameter("lu_meta", Vector4(lx0, lz0, 1.0 / lcell, 0.0))
	m.set_shader_parameter("lu_size", Vector2i(lw, lh))
	m.set_shader_parameter("paint_tex", paint_tex)

func _make_materials() -> void:
	var sh: Shader = load("res://shaders/region_terrain.gdshader")
	var ground: Texture2D = Kit.texture("ground")
	mat_near = ShaderMaterial.new(); mat_near.shader = sh
	_common_params(mat_near)
	mat_near.set_shader_parameter("ground_tex", ground)
	mat_near.set_shader_parameter("ramp_tex", Materials.ramp_texture())
	mat_near.set_shader_parameter("grid_step", 1.0)
	mat_near.set_shader_parameter("noise_tex", _noise_texture())
	mat_near.set_shader_parameter("skirt", SKIRT)
	mat_near.set_shader_parameter("urban_ground", 1.0 if not _urban.is_empty() else 0.0)
	mat_mid = mat_near.duplicate()
	mat_mid.set_shader_parameter("grid_step", float(MID_STEP))
	mat_mid.set_shader_parameter("detail_amp", 0.0)
	mat_mid.set_shader_parameter("skirt", SKIRT * 2.0)
	mat_far = ShaderMaterial.new(); mat_far.shader = load("res://shaders/region_far.gdshader")
	_common_params(mat_far)
	mat_far.set_shader_parameter("grid_step", float(FAR_STEP))
	mat_water = ShaderMaterial.new(); mat_water.shader = load("res://shaders/region_water.gdshader")
	mat_water.set_shader_parameter("water_tex", Kit.texture("water"))
	mat_water.set_shader_parameter("ramp_tex", Materials.ramp_texture())

static func _noise_texture() -> ImageTexture:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	fn.seed = 1870
	fn.frequency = 1.0 / 32.0
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	var img := fn.get_seamless_image(256, 256, false, false, 0.1, true)
	img.convert(Image.FORMAT_L8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# 지형 재질 전부에 같은 값 넣기(시간대·안개 기준 높이 등 — region_main이 부른다)
func set_terrain_param(name: String, v: Variant) -> void:
	for m in [mat_near, mat_mid, mat_water] + _water_mats:
		if m: m.set_shader_parameter(name, v)

func set_far_param(name: String, v: Variant) -> void:
	if mat_far: mat_far.set_shader_parameter(name, v)

# ---------------------------------------------------------------------------
# 높이·토지이용 (셰이더와 같은 식)
# ---------------------------------------------------------------------------
func _hraw(i: int, j: int) -> float:
	i = clampi(i, 0, hnx - 1); j = clampi(j, 0, hnz - 1)
	var k := j * hnx + i
	if hbpp == 2: return hy0 + float(hbytes[k * 2] * 256 + hbytes[k * 2 + 1]) * hscale
	return hy0 + float(hbytes[k] * 256) * hscale

# 데이터 높이(쌍선형, 잡음 없음)
func data_height(x: float, z: float) -> float:
	var fx := clampf((x - hx0) / hstep, 0.0, hnx - 1.001)
	var fz := clampf((z - hz0) / hstep, 0.0, hnz - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	return lerpf(lerpf(_hraw(i, j), _hraw(i + 1, j), tx), lerpf(_hraw(i, j + 1), _hraw(i + 1, j + 1), tx), tz)

# 토지이용 바이트의 128 비트 = "터 고르기 한 땅"(배치 로더가 켬): 분류는 아래 7비트, 잡음 디테일은 0
func _lu_raw(i: int, j: int) -> int:
	return lbytes[clampi(j, 0, lh - 1) * lw + clampi(i, 0, lw - 1)]

func _lu(i: int, j: int) -> int:
	return _lu_raw(i, j) & 127

func _lu_det(i: int, j: int) -> float:
	var v := _lu_raw(i, j)
	return 0.0 if v >= 128 else LU_DETAIL[v]

func landuse_at(x: float, z: float) -> int:
	return _lu(roundi((x - lx0) / lcell), roundi((z - lz0) / lcell))

static func _hash(ix: int, iz: int) -> float:
	var h := ((ix & M32) * 374761393 + (iz & M32) * 668265263) & M32
	h = ((h ^ (h >> 13)) * 1274126177) & M32
	h = h ^ (h >> 16)
	return float(h) / 4294967295.0

static func _vnoise(x: float, z: float) -> float:
	var fx := floorf(x); var fz := floorf(z)
	var ix := int(fx); var iz := int(fz)
	var u := x - fx; var v := z - fz
	u = u * u * (3.0 - 2.0 * u); v = v * v * (3.0 - 2.0 * v)
	return lerpf(lerpf(_hash(ix, iz), _hash(ix + 1, iz), u), lerpf(_hash(ix, iz + 1), _hash(ix + 1, iz + 1), u), v)

func _detail_mask(x: float, z: float) -> float:
	var fx := clampf((x - lx0) / lcell, 0.0, lw - 1.001)
	var fz := clampf((z - lz0) / lcell, 0.0, lh - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	return lerpf(lerpf(_lu_det(i, j), _lu_det(i + 1, j), tx), lerpf(_lu_det(i, j + 1), _lu_det(i + 1, j + 1), tx), tz)

static func _detail(x: float, z: float) -> float:
	return (_vnoise(x * 0.14, z * 0.14) - 0.5) * 0.36 + (_vnoise(x * 0.45 + 31.0, z * 0.45 + 17.0) - 0.5) * 0.10

# 근경 격자점(정수 m)의 높이 = 셰이더 r_height()
func lattice_height(x: float, z: float) -> float:
	return data_height(x, z) + _detail(x, z) * _detail_mask(x, z)

# 식생 흩뿌리기용 빠른 높이(약 3µs): 격자 삼각형 보간 대신 그 자리에서 바로 데이터+잡음 — height_at과 차이 2cm 안팎
func height_fast(x: float, z: float) -> float:
	var fx := clampf((x - hx0) / hstep, 0.0, hnx - 1.001)
	var fz := clampf((z - hz0) / hstep, 0.0, hnz - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	var k := j * hnx + i
	var h: float
	if hbpp == 2:
		var a := hbytes[k * 2] * 256 + hbytes[k * 2 + 1]; var b := hbytes[k * 2 + 2] * 256 + hbytes[k * 2 + 3]
		var k2 := k + hnx
		var c := hbytes[k2 * 2] * 256 + hbytes[k2 * 2 + 1]; var d := hbytes[k2 * 2 + 2] * 256 + hbytes[k2 * 2 + 3]
		h = hy0 + lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz) * hscale
	else:
		h = data_height(x, z)
	var m: float = _lu_det(roundi((x - lx0) / lcell), roundi((z - lz0) / lcell))
	if m == 0.0: return h
	return h + _detail(x, z) * m

# 걸을 수 있는 높이: 지형 + 걷기 면(다리 상판 등, §8 walk)
func height_at(x: float, z: float) -> float:
	if indoor != null: return indoor.height_at(x, z)
	var h := ground_at(x, z)
	for it in interiors:
		if it.has("floor_world") and in_box(it, x, z): h = maxf(h, it.floor_world)
	if _walk_grid.is_empty(): return h
	var w = walk_at(x, z)
	return maxf(h, w) if w != null else h

# 보이는 땅: 논·밭 필지 안이면 필지 면(논바닥·물·둑, 밭 이랑), 아니면 지형
func ground_at(x: float, z: float) -> float:
	if indoor != null: return indoor.height_at(x, z)
	if farm != null:
		var fh: float = farm.height(x, z)
		if not is_nan(fh): return fh
	return terrain_at(x, z)

# 렌더 면과 같은 삼각형 보간(대각선 (i+1,j)–(i,j+1), _grid_mesh와 같음) — 필지를 모르는 지형만
func terrain_at(x: float, z: float) -> float:
	var fx := floorf(x); var fz := floorf(z)
	var tx := x - fx; var tz := z - fz
	var b := lattice_height(fx + 1.0, fz); var c := lattice_height(fx, fz + 1.0)
	if tx + tz <= 1.0:
		var a := lattice_height(fx, fz)
		return a + (b - a) * tx + (c - a) * tz
	var d := lattice_height(fx + 1.0, fz + 1.0)
	return d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)

# ---------------------------------------------------------------------------
# 메시
# ---------------------------------------------------------------------------
# n×n 칸, 간격 step의 평평한 격자(+ 가장자리 치마: y=-1로 표시, 셰이더가 내린다)
static func _grid_mesh(n: int, step: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var row := n + 1
	v.resize(row * row)
	for j in row:
		for i in row:
			v[j * row + i] = Vector3(i * step, 0, j * step)
	idx.resize(n * n * 6)
	var k := 0
	for j in n:
		for i in n:
			var a := j * row + i; var b := a + 1; var c := a + row; var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	# 치마: 네 변을 따라 아래로 내린 띠(양면)
	var edges := []
	for i in row: edges.append([Vector2i(i, 0), 0])
	for i in row: edges.append([Vector2i(i, n), 1])
	for j in row: edges.append([Vector2i(0, j), 2])
	for j in row: edges.append([Vector2i(n, j), 3])
	for side in 4:
		var top := []; var bot := []
		for e in edges:
			if e[1] != side: continue
			var g: Vector2i = e[0]
			top.append(g.y * row + g.x)
			bot.append(v.size())
			v.append(Vector3(g.x * step, -1, g.y * step))
		for q in top.size() - 1:
			var a: int = top[q]; var b: int = top[q + 1]; var c: int = bot[q]; var d: int = bot[q + 1]
			idx.append_array(PackedInt32Array([a, b, c, b, d, c, a, c, b, b, c, d]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var nrm := PackedVector3Array(); nrm.resize(v.size()); nrm.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _build_far() -> void:
	var x0 := floorf(hx0 / FAR_STEP) * FAR_STEP; var z0 := floorf(hz0 / FAR_STEP) * FAR_STEP
	var nx := int(ceil((hx0 + (hnx - 1) * hstep - x0) / FAR_STEP)); var nz := int(ceil((hz0 + (hnz - 1) * hstep - z0) / FAR_STEP))
	var v := PackedVector3Array(); var idx := PackedInt32Array()
	for j in nz + 1:
		for i in nx + 1:
			v.append(Vector3(i * FAR_STEP, 0, j * FAR_STEP))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i; var b := a + 1; var c := a + nx + 1; var d := c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	far_node = MeshInstance3D.new(); far_node.name = "far"
	far_node.mesh = m
	far_node.material_override = mat_far
	far_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_node.position = Vector3(x0, 0, z0)
	far_node.custom_aabb = AABB(Vector3(0, hy0 - 10, 0), Vector3(nx * FAR_STEP, hscale * 65535.0 + 20, nz * FAR_STEP))
	add_child(far_node)

# ---------------------------------------------------------------------------
# 하천 물: region.json.rivers의 수면 높이·폭으로 띠 메시(약 250m씩 잘라 화면 밖은 그리지 않게)
# ---------------------------------------------------------------------------
# 바다·호수(region.json sea {y}, lakes [{y, outline}]) — shaders/region_sea.gdshader
# 물 가림 텍스처(토지이용 격자, RG8): R = 바다 칸(물(5) 칸 중 바다 수면 +0.15m 아래이고 호수 윤곽 밖), G = 뭍(물 아닌 칸).
# 바다 판은 R로 호수 바닥·낮은 뭍을 버리고, G의 밉맵(흐림)으로 '물가 가까움'을 낸다. 지도(region_map)도 R을 쓴다.
var sea_y := NAN
var lakes: Array = []            # [{name, y, poly: PackedVector2Array, bb: Rect2}]
var water_mask: Image            # lw×lh RG8 (바다가 없으면 null)
var sea_map: Image               # 같은 격자 LA8 — 지도(region_map)가 바다 색으로 물들여 그린다
var _water_mats: Array = []      # mist_base 등 공용 값을 같이 받을 물 재질

func _build_sea() -> void:
	var sea = region.get("sea")
	if sea is Dictionary:
		sea_y = float(sea.get("y", 0.0))
		sea_is_river = String(sea.get("kind", "sea")) == "river"
	for l in region.get("lakes", []):
		var poly := PackedVector2Array()
		for q in l.get("outline", []): poly.append(Vector2(float(q[0]), float(q[1])))
		if poly.size() < 3: continue
		var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
		for q in poly: lo = lo.min(q); hi = hi.max(q)
		lakes.append({ name = String(l.get("name", l.get("id", "호수"))), y = float(l.get("y", 0.0)), poly = poly, bb = Rect2(lo, hi - lo) })
	if is_nan(sea_y) and lakes.is_empty(): return
	var t0 := Time.get_ticks_msec()
	_make_water_mask()
	var mimg: Image = water_mask.duplicate(); mimg.generate_mipmaps()
	var mtex_blur := ImageTexture.create_from_image(mimg)
	var sh: Shader = load("res://shaders/region_sea.gdshader")
	var proto := ShaderMaterial.new(); proto.shader = sh
	_common_params(proto)
	proto.set_shader_parameter("water_tex", Kit.texture("water"))
	proto.set_shader_parameter("ramp_tex", Materials.ramp_texture())
	proto.set_shader_parameter("mask_blur", mtex_blur)
	proto.set_shader_parameter("mask_meta", Vector4(lx0 - lcell * 0.5, lz0 - lcell * 0.5, 1.0 / (lcell * lw), 1.0 / (lcell * lh)))
	if not is_nan(sea_y):
		# 높이맵 범위 + 3km 여유. 지도 밖은 가장자리 칸이 이어지므로 바다 쪽 가장자리에서만 수평선까지 물이 보인다.
		# 큰 강(sea.kind="river")은 지도 밖으로 물 띠가 허공에 뻗지 않게 높이맵 범위까지만
		var mg := 0.0 if sea_is_river else 3000.0
		var x0 := hx0 - mg; var z0 := hz0 - mg
		var x1 := hx0 + (hnx - 1) * hstep + mg; var z1 := hz0 + (hnz - 1) * hstep + mg
		if sea_is_river:
			# 강물 결: 흐름 방향 지도(큰 강 중심선 → 32m 칸) + 강 빛깔, 바다 물결 띠·흰 파도 없음
			proto.set_shader_parameter("is_river", 1.0)
			proto.set_shader_parameter("deep_col", Vector3(0.24, 0.34, 0.31))
			proto.set_shader_parameter("shallow_col", Vector3(0.42, 0.53, 0.45))
			var fm := _make_flow_map()
			if fm != null:
				proto.set_shader_parameter("flow_tex", ImageTexture.create_from_image(fm))
				proto.set_shader_parameter("flow_meta", Vector4(hx0 - FLOW_CELL * 0.5, hz0 - FLOW_CELL * 0.5, 1.0 / (FLOW_CELL * fm.get_width()), 1.0 / (FLOW_CELL * fm.get_height())))
		var v := PackedVector3Array(); var idx := PackedInt32Array()
		var n := 16
		for j in n + 1:
			for i in n + 1:
				v.append(Vector3(lerpf(x0, x1, float(i) / n), sea_y, lerpf(z0, z1, float(j) / n)))
		for j in n:
			for i in n:
				var a := j * (n + 1) + i
				idx.append_array(PackedInt32Array([a, a + n + 1, a + 1, a + 1, a + n + 1, a + n + 2]))
		var aabb := AABB(Vector3(x0, sea_y - 1.0, z0), Vector3(x1 - x0, 2.0, z1 - z0))
		if sea_is_river and not OS.get_cmdline_user_args().has("--nowatersplit"):
			# 큰 강: 안쪽(거의 불투명)은 불투명 판, 물가 띠만 반투명 판 — 낮은 배 시점에서 반투명 물이 화면 절반이면 무거웠다
			# (노량진 나루 78.6 → 아래 보고). 두 판은 같은 식으로 맞물려 고른다(region_sea_body.gdshaderinc SEA_SPLIT).
			# 32m 칸으로 나눠 한가운데 칸(둘레까지 모두 바다)은 discard 없는 불투명 판 — 물 아래 땅을 GPU가 건너뛴다.
			var parts := _river_cells()
			if not parts.inner.is_empty():
				_flat_water("sea_river_inner", parts.inner, _quad_idx(parts.inner.size() / 4), _mat_like(proto, "res://shaders/region_sea_interior.gdshader"))
			if not parts.edge.is_empty():
				var ei := _quad_idx(parts.edge.size() / 4)
				_flat_water("sea_river_opaque", parts.edge, ei, _mat_like(proto, "res://shaders/region_sea_opaque.gdshader"))
				_flat_water("sea_river_edge", parts.edge, ei, _mat_like(proto, "res://shaders/region_sea_split.gdshader"))
			print("REGION river water cells inner=%d edge=%d" % [parts.inner.size() / 4, parts.edge.size() / 4])
		else:
			_flat_water("sea", v, idx, proto).custom_aabb = aabb
	for l in lakes:
		var tri := Geometry2D.triangulate_polygon(l.poly)
		if tri.is_empty(): push_warning("호수 윤곽을 삼각형으로 나누지 못했다: " + l.name); continue
		var v := PackedVector3Array()
		for q in l.poly: v.append(Vector3(q.x, l.y, q.y))
		var mat: ShaderMaterial = proto.duplicate()
		mat.set_shader_parameter("is_lake", 1.0)
		mat.set_shader_parameter("deep_col", Vector3(0.27, 0.40, 0.42))
		mat.set_shader_parameter("shallow_col", Vector3(0.45, 0.60, 0.56))
		_flat_water("lake_" + l.name, v, tri, mat)
	print("REGION sea y=%s kind=%s lakes=%d mask_ms=%d" % [sea_y, "river" if sea_is_river else "sea", lakes.size(), Time.get_ticks_msec() - t0])

# 큰 강 물면 칸 나누기: 물 가림 밉맵(상자 평균)에서 칸 크기가 RIVER_CELL에 가장 가까운 단을 읽는다.
# R = 255(칸 안이 모두 바다)이고 둘레 8칸도 그러면 '한가운데', 둘레에 바다가 조금이라도 있으면 '물가'(셰이더가 고른다), 없으면 판 없음.
const RIVER_CELL := 32.0
func _river_cells() -> Dictionary:
	var k := clampi(roundi(log(RIVER_CELL / lcell) / log(2.0)), 0, 8)
	# 크기를 2^k의 배수로 채운 그림에 옮겨 밉맵을 만든다 — 그래야 k단까지 정확히 2×2 상자 평균(홀수 크기면 다시 표본을 떠 칸이 어긋난다)
	var n := 1 << k
	var w := (lw + n - 1) / n; var h := (lh + n - 1) / n
	var pad := Image.create(w * n, h * n, false, Image.FORMAT_RG8)
	pad.blit_rect(water_mask, Rect2i(0, 0, lw, lh), Vector2i.ZERO)
	pad.generate_mipmaps()
	var C := lcell * float(n)
	var data := pad.get_data()
	var off := pad.get_mipmap_offset(k)
	var r := func(i: int, j: int) -> int:
		if i < 0 or j < 0 or i >= w or j >= h: return 0
		return data[off + (j * w + i) * 2]
	var inner := PackedVector3Array(); var edge := PackedVector3Array()
	var x0 := lx0 - lcell * 0.5; var z0 := lz0 - lcell * 0.5
	for j in h:
		for i in w:
			var lo := 255; var hi := 0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var v: int = r.call(i + di, j + dj)
					lo = mini(lo, v); hi = maxi(hi, v)
			if hi == 0: continue
			var ax := x0 + i * C; var az := z0 + j * C
			var q := [Vector3(ax, sea_y, az), Vector3(ax + C, sea_y, az), Vector3(ax + C, sea_y, az + C), Vector3(ax, sea_y, az + C)]
			if lo == 255: inner.append_array(q)
			else: edge.append_array(q)
	return { inner = inner, edge = edge }

static func _quad_idx(n: int) -> PackedInt32Array:
	var idx := PackedInt32Array(); idx.resize(n * 6)
	for q in n:
		var a := q * 4
		# 위에서 볼 때 앞면이 되게(옛 격자와 같은 감김) — 뒷면이면 cull_disabled에서 NORMAL이 뒤집혀 빛이 달라진다
		idx[q * 6] = a; idx[q * 6 + 1] = a + 3; idx[q * 6 + 2] = a + 1
		idx[q * 6 + 3] = a + 1; idx[q * 6 + 4] = a + 3; idx[q * 6 + 5] = a + 2
	return idx

# 같은 값을 가진 다른 셰이더 재질(물 판 나누기)
static func _mat_like(src: ShaderMaterial, shader_path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = load(shader_path)
	for u in src.shader.get_shader_uniform_list():
		var v = src.get_shader_parameter(u.name)
		if v != null: m.set_shader_parameter(u.name, v)
	return m

func _flat_water(nm: String, v: PackedVector3Array, idx: PackedInt32Array, mat: ShaderMaterial) -> MeshInstance3D:
	var nrm := PackedVector3Array(); nrm.resize(v.size()); nrm.fill(Vector3.UP)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nrm; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new(); mi.name = nm; mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water_mats.append(mat)
	water_root.add_child(mi)
	return mi

# 물 가림(토지이용 격자 lw×lh, RG8). 처음 데이터(_l_orig 전, 배치 손대기 전) 기준
func _make_water_mask() -> void:
	var out := PackedByteArray(); out.resize(lw * lh * 2)
	var la := PackedByteArray(); la.resize(lw * lh * 2)   # 지도용 LA8(바다 칸만 L·A 255)
	var ratio := lcell / hstep
	var lim := INF
	if not is_nan(sea_y): lim = (sea_y + 0.15 - hy0) / hscale   # 원시 높이 값으로 비교
	for j in lh:
		var hj := clampi(roundi((lz0 + j * lcell - hz0) / hstep), 0, hnz - 1)
		var hrow := hj * hnx
		var hi0 := (lx0 - hx0) / hstep
		var row := j * lw
		for i in lw:
			var lu := lbytes[row + i] & 127
			if lu != 5:
				out[(row + i) * 2 + 1] = 255
				continue
			var hk := hrow + clampi(roundi(hi0 + i * ratio), 0, hnx - 1)
			var hv: float = float(hbytes[hk * 2] * 256 + hbytes[hk * 2 + 1]) if hbpp == 2 else float(hbytes[hk] * 256)
			if hv <= lim: out[(row + i) * 2] = 255; la[(row + i) * 2] = 255; la[(row + i) * 2 + 1] = 255
	# 호수 윤곽 안은 바다가 아니다
	for l in lakes:
		var bb: Rect2 = l.bb
		var i0 := clampi(floori((bb.position.x - lx0) / lcell), 0, lw - 1); var i1 := clampi(ceili((bb.end.x - lx0) / lcell), 0, lw - 1)
		var j0 := clampi(floori((bb.position.y - lz0) / lcell), 0, lh - 1); var j1 := clampi(ceili((bb.end.y - lz0) / lcell), 0, lh - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if Geometry2D.is_point_in_polygon(Vector2(lx0 + i * lcell, lz0 + j * lcell), l.poly):
					out[(j * lw + i) * 2] = 0; la[(j * lw + i) * 2 + 1] = 0
	# 열림(opening) 비슷하게: 32m 밉(평균)에서 바다 비율이 낮은 칸 = 좁은 물길(하구 쪽 하천 바닥이 해수면 아래)은 바다가 아니다.
	# 하천 띠(y≈0.01)와 바다 판(0)이 겹쳐 깜박이지 않게, 지도에 하천이 굵은 바다 줄로 그려지지 않게
	var mi := Image.create_from_data(lw, lh, false, Image.FORMAT_RG8, out)
	mi.generate_mipmaps()
	var lv := 3
	var mo := mi.get_mipmap_offset(lv)
	var mw := maxi(lw >> lv, 1); var mh := maxi(lh >> lv, 1)
	var md := mi.get_data()
	var sc := float(1 << lv)
	for j in lh:
		var fz := clampf((j + 0.5) / sc - 0.5, 0.0, mh - 1.001)
		var j0 := int(fz); var tz := fz - j0
		var row := j * lw
		for i in lw:
			if out[(row + i) * 2] == 0: continue
			var fx := clampf((i + 0.5) / sc - 0.5, 0.0, mw - 1.001)
			var i0 := int(fx); var tx := fx - i0
			var a := mo + (j0 * mw + i0) * 2
			var v := lerpf(lerpf(md[a], md[a + 2], tx), lerpf(md[a + mw * 2], md[a + mw * 2 + 2], tx), tz)
			if v < 70.0: out[(row + i) * 2] = 0; la[(row + i) * 2] = 0; la[(row + i) * 2 + 1] = 0
	water_mask = Image.create_from_data(lw, lh, false, Image.FORMAT_RG8, out)
	sea_map = Image.create_from_data(lw, lh, false, Image.FORMAT_LA8, la)

# ---------------------------------------------------------------------------
# 6단계: 큰 강(sea.kind="river") 흐름 지도 · 건천(dry) · 나루 뱃길 · 성곽(walls) 대신 벽
# ---------------------------------------------------------------------------
const FLOW_CELL := 32.0
var sea_is_river := false        # region.json sea.kind == "river" (한강·대동강 물면 — terrain-data-north §3.2)
var big_river_ids := {}          # render:false / spec_grade S 하천 id (중심선은 흐름 방향에만 쓰고 리본은 그리지 않는다)

static func _is_big_river(r: Dictionary) -> bool:
	return r.get("render") == false or String(r.get("spec_grade", "")) == "S"

# 큰 강 중심선(점 순서 = 하류 방향)을 32m 칸에 찍고, 가까운 칸으로 번지게(BFS) 한 뒤 두 번 흐려 RG8(방향*0.5+0.5)로
func _make_flow_map() -> Image:
	var W := int(ceil((hnx - 1) * hstep / FLOW_CELL)) + 1; var H := int(ceil((hnz - 1) * hstep / FLOW_CELL)) + 1
	var fx := PackedFloat32Array(); fx.resize(W * H)
	var fz := PackedFloat32Array(); fz.resize(W * H)
	var seen := PackedByteArray(); seen.resize(W * H)
	var q := PackedInt32Array()
	for r in region.get("rivers", []):
		if not _is_big_river(r): continue
		var pts := []
		for p in r.points: pts.append(Vector3(float(p[0]), 0.0, float(p[1])))
		if pts.size() < 2: continue
		pts = _resample(pts, FLOW_CELL * 0.5)
		for k in pts.size():
			var a: Vector3 = pts[maxi(k - 2, 0)]; var b: Vector3 = pts[mini(k + 2, pts.size() - 1)]
			var d := Vector2(b.x - a.x, b.z - a.z).normalized()
			var i := clampi(roundi((pts[k].x - hx0) / FLOW_CELL), 0, W - 1); var j := clampi(roundi((pts[k].z - hz0) / FLOW_CELL), 0, H - 1)
			var c := j * W + i
			fx[c] += d.x; fz[c] += d.y
			if seen[c] == 0: seen[c] = 1; q.append(c)
	if q.is_empty(): return null
	var head := 0
	while head < q.size():
		var c := q[head]; head += 1
		var i := c % W; var j := c / W
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ii: int = i + o.x; var jj: int = j + o.y
			if ii < 0 or jj < 0 or ii >= W or jj >= H: continue
			var n := jj * W + ii
			if seen[n] != 0: continue
			seen[n] = 1; fx[n] = fx[c]; fz[n] = fz[c]; q.append(n)
	for pass_i in 3:
		var ax := fx.duplicate(); var az := fz.duplicate()
		for j in H:
			for i in W:
				var sx := 0.0; var sz := 0.0
				for dj in range(-1, 2):
					for di in range(-1, 2):
						var n := clampi(j + dj, 0, H - 1) * W + clampi(i + di, 0, W - 1)
						sx += ax[n]; sz += az[n]
				fx[j * W + i] = sx; fz[j * W + i] = sz
	var out := PackedByteArray(); out.resize(W * H * 2)
	for c in W * H:
		var d := Vector2(fx[c], fz[c]).normalized()
		out[c * 2] = clampi(roundi(d.x * 127.5 + 127.5), 0, 255); out[c * 2 + 1] = clampi(roundi(d.y * 127.5 + 127.5), 0, 255)
	return Image.create_from_data(W, H, false, Image.FORMAT_RG8, out)

# ---- 건천(rivers[].dry = true, 제주): 물 띠 대신 마른 돌 바닥. 토지이용 물(5) 칸 중 건천 중심선 가까운 칸을 표시(dry_mask) →
# 지형 셰이더가 현무암 자갈·바위 바닥으로 칠하고, 걷기는 막지 않는다. 비가 오면(wet) 가는 물줄기 리본만 드러난다.
var dry_mask: PackedByteArray     # lw×lh, 1 = 건천 바닥
var _dry_ribbons: Array = []
var _mat_dry: ShaderMaterial
var wet_level := 0.0              # region_main이 weather.wet을 넣는다

func _mark_dry(pts: Array, ws: PackedFloat32Array) -> void:
	if dry_mask.is_empty(): dry_mask.resize(lw * lh)
	for k in pts.size():
		var rr := ws[k] * 0.5 + 6.0
		var p: Vector3 = pts[k]
		var i0 := clampi(floori((p.x - rr - lx0) / lcell), 0, lw - 1); var i1 := clampi(ceili((p.x + rr - lx0) / lcell), 0, lw - 1)
		var j0 := clampi(floori((p.z - rr - lz0) / lcell), 0, lh - 1); var j1 := clampi(ceili((p.z + rr - lz0) / lcell), 0, lh - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var c := j * lw + i
				if lbytes[c] & 127 != 5: continue
				if Vector2(lx0 + i * lcell - p.x, lz0 + j * lcell - p.z).length() <= rr: dry_mask[c] = 1

func is_dry_bed(x: float, z: float) -> bool:
	if dry_mask.is_empty(): return false
	return dry_mask[clampi(roundi((z - lz0) / lcell), 0, lh - 1) * lw + clampi(roundi((x - lx0) / lcell), 0, lw - 1)] == 1

func _finish_dry() -> void:
	if dry_mask.is_empty(): return
	var tex := ImageTexture.create_from_image(Image.create_from_data(lw, lh, false, Image.FORMAT_R8, dry_mask))
	for m in [mat_near, mat_mid]:
		m.set_shader_parameter("dry_tex", tex)
		m.set_shader_parameter("has_dry", 1.0)

# 비 올 때만: 젖음 0.35 넘으면 건천 돌 바닥 가운데에 물줄기가 드러난다(셰이더 gate)
var _dry_gate := -1.0
func _update_dry() -> void:
	if _mat_dry == null: return
	var g := snappedf(smoothstep(0.35, 0.85, wet_level), 0.01)
	if g != _dry_gate:
		_dry_gate = g
		_mat_dry.set_shader_parameter("gate", g)

# ---- 나루 뱃길(큰 강, 다리 없음 — 명세 §6): crossings type "나루" + ends[2]. 물 위 걷기 면은 없다 — 나룻배(kit/village/narutbae)
# 한 척이 나루에 묶여 있고, 사공이 저어 건넨다(scripts/region/boat_ride.gd: 나루 끝에서 E "건너간다").
var ferries: Array = []          # [{id, name, a: Vector2, b: Vector2, len, dir: Vector2, boat: Node3D, s}]
const FERRY_HW := 1.9            # 뱃길 반폭(배 폭 1.7 + 여유)
const FERRY_DECK := 0.32         # 물 면 위 갑판 높이

func _build_ferries() -> void:
	if is_nan(sea_y): return
	var drop := {}
	for c in region.get("crossings", []):
		if String(c.get("type", "")) != "나루" or not (c.get("ends") is Array) or c.ends.size() < 2: continue
		# 바다(강 아님)에서는 노정 바다 뱃길(sea_lane)만 — 제주 권역 등 바다 나루 표지는 그대로
		if not sea_is_river and not bool(c.get("sea_lane", false)): continue
		var bk := String(c.get("boat_kit", "village/narutbae"))
		var boat_scr: Script = load("res://kit/%s.gd" % bk) if FileAccess.file_exists("res://kit/%s.gd" % bk) else null
		var a := Vector2(float(c.ends[0][0]), float(c.ends[0][1])); var b := Vector2(float(c.ends[1][0]), float(c.ends[1][1]))
		var L := a.distance_to(b)
		if L < 4.0: continue
		var d := (b - a) / L
		drop[String(c.get("id", ""))] = true
		var ry := atan2(d.x, d.y)
		var f := { id = String(c.get("id", "")), name = String(c.get("name", "나루")), a = a, b = b, len = L, dir = d, ry = ry, boat = null, s = 6.0,
			auto = bool(c.get("auto", false)), sail = 0, sea = bool(c.get("sea_lane", false)), kit = bk }
		if boat_scr != null and boat_scr.can_instantiate():
			var info = boat_scr.build({ seed = hash(f.id) & 0xffff })
			if info is Dictionary and info.get("node") is Node3D:
				f.boat = info.node
				f.boat.name = "나룻배_" + f.id
				water_root.add_child(f.boat)
		ferries.append(f)
		_place_boat(f, f.s)
	# 나루 표지점(뱃길 가운데 part_of 포함)은 '물에 걸어 들어가기 허용' 자리에서 뺀다 — 큰 강 바닥으로 빠지지 않게
	if not drop.is_empty():
		var keep := []
		for c in region.get("crossings", []):
			if drop.has(String(c.get("id", ""))) or drop.has(String(c.get("part_of", ""))): continue
			keep.append(Vector2(float(c.x), float(c.z)))
		_crossings = keep
		_crossings_all = keep.duplicate()
	if not ferries.is_empty(): print("REGION ferries=%s" % [ferries.map(func(f): return "%s(%.0fm)" % [f.id, f.len])])

func _place_boat(f: Dictionary, s: float, lat := 0.0) -> void:
	f.s = clampf(s, 3.4, f.len - 3.4)
	if f.boat == null: return
	var p: Vector2 = f.a + f.dir * f.s + Vector2(-f.dir.y, f.dir.x) * clampf(lat, -0.6, 0.6)
	var bs := Basis(Vector3.UP, f.ry)
	var bob := 0.0
	if f.get("sea", false):   # 바다: 너울에 조금 흔들림(갑판 걷기 면은 그대로)
		var t := Time.get_ticks_msec() / 1000.0
		bs = bs * Basis(Vector3(0, 0, 1), sin(t * 0.9) * 0.035) * Basis(Vector3(1, 0, 0), sin(t * 0.63 + 1.0) * 0.02)
		bob = sin(t * 1.1) * 0.06
	f.boat.transform = Transform3D(bs, Vector3(p.x, sea_y + 0.02 + bob, p.y))

# 예전 API(읽기 전용): 지금 나루·바다 뱃길 배를 타고 있으면 {dir, speed, name, start, to, id}, 아니면 {} — 배는 boat_ride.gd가 몬다
var boat_ride = null
func ferry_auto(_player: Vector3) -> Dictionary:
	return boat_ride.legacy("ferry") if boat_ride != null else {}

# (예전) 플레이어가 뱃길 물 위에 있으면 배가 발밑으로 온다 — 이제 region_main은 부르지 않는다(boat_ride가 배를 놓는다)
func update_ferries(player: Vector3) -> void:
	for f in ferries:
		var rel := Vector2(player.x, player.z) - (f.a as Vector2)
		var s: float = rel.dot(f.dir)
		var lat: float = rel.dot(Vector2(-f.dir.y, f.dir.x))
		if absf(lat) > FERRY_HW + 0.5 or s < -2.0 or s > f.len + 2.0: continue
		if ground_at(player.x, player.z) > sea_y + 0.1: continue
		_place_boat(f, s, lat)

# ---- 성곽(region.json walls): 배치(키트)가 그 구간에 성벽·문을 놓았으면 그대로 두고, 안 놓인 구간만 싼 돌벽(대신 벽)을 깐다.
# 문(gates의 랜드마크 자리)·길이 지나는 곳·물(토지이용 5) 위는 비운다. 배치를 다시 읽으면 다시 계산한다.
const WALL_TAG := "wall_proxy"
const WALL_STEP := 4.0
const WALL_T := 4.0
var wall_stats := {}

func build_wall_proxies(loader = null) -> void:
	remove_tagged(WALL_TAG)
	wall_stats = { walls = 0, proxy_m = 0.0, covered_m = 0.0, gap_m = 0.0, chunks = 0 }
	var walls = region.get("walls")
	if not (walls is Array) or walls.is_empty(): return
	var t0 := Time.get_ticks_msec()
	# 배치가 놓은 성벽·문 키트 자리(+반경): 이 안의 성벽 선은 이미 덮였다
	var cover := []
	if loader != null and "_pending" in loader:
		for t in loader._pending:
			for r in loader._pending[t]:
				var k := String(r.kit)
				if not (k.contains("wall") or k.contains("seong") or k.contains("gate") or k.ends_with("mun") or k.contains("eupseong")): continue
				if k.contains("gwana_wall") or k.contains("basalt_wall") or k == "village/wall_run": continue   # 관아·집 담은 성벽이 아니다
				var fp: Vector2 = r.fp if r.fp is Vector2 else Vector2.ZERO
				cover.append([Vector2(r.x, r.z), maxf(fp.x, fp.y) * 0.5 + 3.0])
	var gate_pts := []
	var lm_by_id := {}
	for l in region.get("landmarks", []): lm_by_id[String(l.get("id", ""))] = l
	for w in walls:
		for g in w.get("gates", []):
			var l = lm_by_id.get(String(g))
			if l != null: gate_pts.append(Vector2(float(l.x), float(l.z)))
	for w in walls:
		var pts := []
		for p in w.get("points", []): pts.append(Vector3(float(p[0]), 0.0, float(p[1])))
		if pts.size() < 2: continue
		if bool(w.get("closed", false)) and (pts[0] as Vector3).distance_to(pts[pts.size() - 1]) > 1.0: pts.append(pts[0])
		wall_stats.walls += 1
		# 바깥 방향: 닫힌 선이면 넓이 부호로(바깥에 여장), 열린 선이면 오른쪽
		var area := 0.0
		for k in pts.size() - 1: area += pts[k].x * pts[k + 1].z - pts[k + 1].x * pts[k].z
		var out_sign := 1.0 if area < 0.0 else -1.0
		var hm = w.get("height_m", [5.0, 7.0])
		var h_lo := float(hm[0]) if hm is Array else float(hm); var h_hi := float(hm[hm.size() - 1]) if hm is Array else float(hm)
		var sp := _resample(pts, WALL_STEP)
		var keep := PackedByteArray(); keep.resize(sp.size())
		for k in sp.size():
			var q := Vector2(sp[k].x, sp[k].z)
			var ok := true
			for gp in gate_pts:
				if q.distance_to(gp) < 9.0: ok = false; break
			if ok and (road_distance(q.x, q.y) < 2.5 or landuse_at(q.x, q.y) == 5): ok = false
			if ok:
				for c in cover:
					if q.distance_to(c[0]) < c[1]: ok = false; wall_stats.covered_m += WALL_STEP; break
			else: wall_stats.gap_m += WALL_STEP
			keep[k] = 1 if ok else 0
		# 이어진 구간을 48m 조각으로(타일 스트리밍에 맞춰 붙였다 뗀다)
		var k := 0
		while k < sp.size() - 1:
			if keep[k] == 0 or keep[k + 1] == 0: k += 1; continue
			var e := k
			while e < sp.size() - 1 and keep[e + 1] == 1 and e - k < 12: e += 1
			_wall_chunk(sp, k, e, out_sign, h_lo, h_hi, String(w.get("name", w.get("id", "성벽"))))
			wall_stats.proxy_m += (e - k) * WALL_STEP
			k = e
	print("REGION walls=%d proxy=%.0fm covered=%.0fm gaps=%.0fm chunks=%d ms=%d" % [wall_stats.walls, wall_stats.proxy_m, wall_stats.covered_m, wall_stats.gap_m, wall_stats.chunks, Time.get_ticks_msec() - t0])

func _wall_chunk(sp: Array, s: int, e: int, out_sign: float, h_lo: float, h_hi: float, nm: String) -> void:
	var o: Vector3 = sp[s]
	var oy := ground_at(o.x, o.z)
	var org := Vector3(o.x, oy, o.z)
	var body := Kit.Geo.new(); var para := Kit.Geo.new()
	var cols := []
	var L := []   # [바깥 아래, 바깥 위, 안 아래, 안 위, 여장 안 위] 점마다
	for k in range(s, e + 1):
		var p: Vector3 = sp[k]
		var a: Vector3 = sp[maxi(k - 1, 0)]; var b: Vector3 = sp[mini(k + 1, sp.size() - 1)]
		var d := Vector2(b.x - a.x, b.z - a.z).normalized()
		var n := Vector2(-d.y, d.x) * out_sign
		var g0 := ground_at(p.x + n.x * WALL_T * 0.5, p.z + n.y * WALL_T * 0.5); var g1 := ground_at(p.x - n.x * WALL_T * 0.5, p.z - n.y * WALL_T * 0.5)
		var gl := minf(g0, g1); var gh := maxf(g0, g1)
		var slope := absf(ground_at(b.x, b.z) - ground_at(a.x, a.z)) / maxf(Vector2(b.x - a.x, b.z - a.z).length(), 1.0)
		var top := gh + lerpf(h_hi, h_lo, smoothstep(0.06, 0.3, slope)) - oy
		var c := Vector3(p.x, 0.0, p.z) - Vector3(org.x, 0.0, org.z)
		var no := Vector3(n.x, 0.0, n.y)
		L.append([c + no * WALL_T * 0.5 + Vector3(0, gl - 1.2 - oy, 0), c + no * WALL_T * 0.5 + Vector3(0, top, 0),
			c - no * WALL_T * 0.5 + Vector3(0, gl - 1.2 - oy, 0), c - no * WALL_T * 0.5 + Vector3(0, top, 0), c + no * (WALL_T * 0.5 - 0.6) + Vector3(0, top, 0), no])
		cols.append({ type = "circle", x = c.x, z = c.z, r = WALL_T * 0.5 + 0.2 })
		if k < e:
			var m: Vector3 = (sp[k] + sp[k + 1]) * 0.5 - Vector3(org.x, 0.0, org.z)
			cols.append({ type = "circle", x = m.x, z = m.z, r = WALL_T * 0.5 + 0.2 })
			# 성벽 둘레 식생 비우기(성 밑 6m씩 — 나무가 성벽을 뚫고 나오지 않게)
			var q0: Vector3 = sp[k]; var q1: Vector3 = sp[k + 1]
			add_veg_exclusion(Vector2((q0.x + q1.x) * 0.5, (q0.z + q1.z) * 0.5), atan2(q1.z - q0.z, q1.x - q0.x) * -1.0, Vector2(WALL_STEP * 0.5 + 1.0, WALL_T * 0.5 + 6.0))
	for i in L.size() - 1:
		var A: Array = L[i]; var B: Array = L[i + 1]
		var u0 := float(i) * WALL_STEP / 4.0; var u1 := u0 + WALL_STEP / 4.0
		body.quad(A[0], B[0], B[1], A[1], Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1))   # 바깥 면
		body.quad(B[2], A[2], A[3], B[3], Vector2(u1, 0), Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1))   # 안 면
		body.quad(A[1], B[1], B[3], A[3])                                                                  # 윗면
		# 여장(바깥 가장자리 1.1m 담, 2m마다 타구 틈)
		var up := Vector3(0, 1.1, 0)
		var na: Vector3 = A[5]
		for half in 2:
			var t0 := half * 0.5; var t1 := t0 + 0.38
			var p0: Vector3 = (A[1] as Vector3).lerp(B[1], t0); var p1: Vector3 = (A[1] as Vector3).lerp(B[1], t1)
			var q0: Vector3 = (A[4] as Vector3).lerp(B[4], t0); var q1: Vector3 = (A[4] as Vector3).lerp(B[4], t1)
			para.quad(p0, p1, p1 + up, p0 + up)
			para.quad(q1, q0, q0 + up, q1 + up)
			para.quad(p0 + up, p1 + up, q1 + up, q0 + up)
			para.quad(q0, p0, p0 + up, q0 + up)
			para.quad(p1, q1, q1 + up, p1 + up)
	# 웹 Geo는 반시계 앞면 — 바깥 방향이 뒤집힌 선이면 면을 뒤집는다
	if out_sign < 0.0:
		for g in [body, para]:
			for i in range(0, g.pos.size(), 3):
				var tp: Vector3 = g.pos[i + 1]; g.pos[i + 1] = g.pos[i + 2]; g.pos[i + 2] = tp
				var tu: Vector2 = g.uv[i + 1]; g.uv[i + 1] = g.uv[i + 2]; g.uv[i + 2] = tu
	var rng := Kit.Rng.new(hash(nm) + s)
	var bt := Kit.Batch.new()
	bt.add("stone", Kit.paint(body, Kit.hex(0xc9c2b0), Kit.hex(0x9d968a), 0.04, rng), 0.03)
	bt.add("stone", Kit.paint(para, Kit.hex(0xb9b2a2), Kit.hex(0xa8a091), 0.03, rng), 0.02)
	var node := bt.build("%s_대신벽_%d" % [nm, s])
	add_static(node, Transform3D(Basis(), org), { colliders = cols, footprint = Vector2((e - s) * WALL_STEP, WALL_T), occluder = true }, WALL_TAG)
	wall_stats.chunks += 1

# 바다 칸인가(물 가림 R) — 지도·걷기 판정용
func is_sea(x: float, z: float) -> bool:
	if water_mask == null: return false
	var i := clampi(roundi((x - lx0) / lcell), 0, lw - 1); var j := clampi(roundi((z - lz0) / lcell), 0, lh - 1)
	return water_mask.get_pixel(i, j).r > 0.5

func lake_at(x: float, z: float) -> Variant:
	var p := Vector2(x, z)
	for l in lakes:
		if l.bb.has_point(p) and Geometry2D.is_point_in_polygon(p, l.poly): return l
	return null

# 하천 폭: widths(점별, 새 권역 — 명세 v0.3 §5 상류 좁고 하류 넓게)가 있으면 그것, 없으면 width_m 하나(남원).
# 물 메시 폭은 terrain-data 권고대로 max(폭, 5.2) — 단 widths가 있으면 데이터가 그 폭으로 바닥을 깎았으므로 1.6까지 좁힌다.
func _river_widths(r: Dictionary, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array(); out.resize(n)
	var ws = r.get("widths")
	if ws is Array and ws.size() == n:
		for i in n: out[i] = maxf(float(ws[i]), 1.6)
		# 데이터 폭은 구간별 계단(2.5 → 7 → 15) — 앞뒤 ±8점(약 60m) 상자 평균 두 번으로 조금씩 넓어지게
		for pass_i in 2:
			var src := out.duplicate()
			var acc := 0.0; var R := 8
			for i in mini(R, n): acc += src[i]
			for i in n:
				if i + R < n: acc += src[i + R]
				if i - R - 1 >= 0: acc -= src[i - R - 1]
				out[i] = acc / float(mini(i + R, n - 1) - maxi(i - R, 0) + 1)
	else:
		out.fill(maxf(float(r.get("width_m", 6.0)), 5.2))
	return out

func _build_rivers() -> void:
	_build_sea()
	for r in region.get("rivers", []):
		# 큰 강(render:false·S급): 물면은 sea(kind river) 판이 그리고 걷기도 그쪽이 막는다 — 중심선은 흐름 지도에만
		if _is_big_river(r):
			big_river_ids[String(r.get("id", ""))] = true
			continue
		var pts := []
		for p in r.points: pts.append(Vector3(float(p[0]), float(p[2]) if p.size() > 2 else data_height(p[0], p[1]), float(p[1])))
		if pts.size() < 2: continue
		var ws := _river_widths(r, pts.size())
		var dry: bool = r.get("dry") == true or String(r.get("flow", "")) == "intermittent"
		if dry:
			# 건천: 바닥 표시(걷기 허용·지형 셰이더 돌 바닥) + 마른 돌 바닥 리본(비 오면 가운데에 물줄기)
			_mark_dry(pts, ws)
			for k in ws.size(): ws[k] = maxf(ws[k] * 0.8, 2.4)
		# 걷기 막기용 선분 격자: 중심선에서 폭의 80% 안쪽이고 땅이 수면보다 낮으면 물 속
		for k in (0 if dry else pts.size() - 1):
			var rr := maxf(ws[k], ws[k + 1]) * 0.8
			var sg := { a = Vector2(pts[k].x, pts[k].z), b = Vector2(pts[k + 1].x, pts[k + 1].z), r = rr, ya = pts[k].y, yb = pts[k + 1].y }
			_grid_insert(_river_grid, { type = "box", minX = minf(sg.a.x, sg.b.x) - sg.r, maxX = maxf(sg.a.x, sg.b.x) + sg.r,
				minZ = minf(sg.a.y, sg.b.y) - sg.r, maxZ = maxf(sg.a.y, sg.b.y) + sg.r, seg = sg })
		# 호수 안 구간은 물 띠를 그리지 않는다(호수 수면이 덮는다 — 하천 띠가 호수 바닥에 비치지 않게). 한 점씩 겹쳐 잇는다
		var runs := []
		var cur := []
		for k in pts.size():
			var inl := not lakes.is_empty() and lake_at(pts[k].x, pts[k].z) != null
			if not inl: cur.append(k)
			elif not cur.is_empty():
				cur.append(k); runs.append(cur); cur = []
			if inl and k + 1 < pts.size() and lake_at(pts[k + 1].x, pts[k + 1].z) == null: cur = [k]
		if cur.size() >= 2: runs.append(cur)
		for run in runs:
			if run.size() < 2: continue
			var rp := []; var wp := []
			for k in run:
				rp.append(pts[k]); wp.append(Vector3(pts[k].x, ws[k], pts[k].z))  # 폭을 y 자리에 실어 같은 간격으로 다시 뽑는다
			rp = _resample(rp, 3.0)
			wp = _resample(wp, 3.0)
			var chunk := 84
			var s := 0
			while s < rp.size() - 1:
				var e := mini(s + chunk, rp.size() - 1)
				var ch := _river_chunk(rp, wp, s, e, String(r.get("id", "river")))
				if dry:
					if _mat_dry == null:
						_mat_dry = mat_water.duplicate()
						_mat_dry.set_shader_parameter("gate", 0.0)
						_mat_dry.set_shader_parameter("dry", 1.0)
					ch.material_override = _mat_dry
					_dry_ribbons.append(ch)
				water_root.add_child(ch)
				s = e
	_finish_dry()
	_build_ferries()

static func _chaikin(p: Array) -> Array:
	var o := [p[0]]
	for i in p.size() - 1:
		var a: Vector3 = p[i]; var b: Vector3 = p[i + 1]
		o.append(a.lerp(b, 0.25)); o.append(a.lerp(b, 0.75))
	o.append(p[p.size() - 1])
	return o

static func _resample(p: Array, step: float) -> Array:
	var o := [p[0]]
	var acc := 0.0
	for i in p.size() - 1:
		var a: Vector3 = p[i]; var b: Vector3 = p[i + 1]
		var l := Vector2(b.x - a.x, b.z - a.z).length()
		var t := step - acc
		while t <= l:
			o.append(a.lerp(b, t / l)); t += step
		acc = l - (t - step)
	o.append(p[p.size() - 1])
	return o

func _river_chunk(pts: Array, wp: Array, s: int, e: int, name: String) -> MeshInstance3D:
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var col := PackedColorArray(); var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	var dist := 0.0
	for i in range(0, s): dist += Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
	for i in range(s, e + 1):
		var p: Vector3 = pts[i]
		var a: Vector3 = pts[maxi(i - 1, 0)]; var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var t := Vector2(b.x - a.x, b.z - a.z).normalized()
		var n := Vector2(-t.y, t.x)
		# 여울/소: 수면 기울기(하류로 떨어지는 정도)
		var a2: Vector3 = pts[maxi(i - 4, 0)]; var b2: Vector3 = pts[mini(i + 4, pts.size() - 1)]
		var run := maxf(1.0, Vector2(b2.x - a2.x, b2.z - a2.z).length())
		var slope := (a2.y - b2.y) / run
		var rapid := smoothstep(0.006, 0.03, slope)
		var pool := (1.0 - smoothstep(0.0, 0.004, slope)) * clampf(0.4 + _vnoise(dist * 0.01, 3.0), 0.0, 1.0)
		var w: float = wp[mini(i, wp.size() - 1)].y
		var hw := w * 0.5 * 1.18 + 0.6
		var c := Color(rapid, pool, w / 40.0)
		for k in 2:
			var sgn := -1.0 if k == 0 else 1.0
			v.append(Vector3(p.x + n.x * hw * sgn, p.y, p.z + n.y * hw * sgn))
			uv.append(Vector2(dist / 7.0, float(k)))
			col.append(c); nrm.append(Vector3.UP)
		if i < e:
			var q := (i - s) * 2
			idx.append_array(PackedInt32Array([q, q + 2, q + 1, q + 1, q + 2, q + 3]))
			dist += Vector2(pts[i + 1].x - p.x, pts[i + 1].z - p.z).length()
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_COLOR] = col; arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new(); mi.name = name
	mi.mesh = m; mi.material_override = mat_water
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = TILE * (MID_R + 0.5)  # 원경(먹빛 능선) 위에는 물을 그리지 않는다
	return mi

# ---------------------------------------------------------------------------
# 타일 스트리밍
# ---------------------------------------------------------------------------
func _tile_ok(t: Vector2i) -> bool:
	return t.x >= tile_min.x and t.x <= tile_max.x and t.y >= tile_min.y and t.y <= tile_max.y

static func _ring(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func tile_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / TILE), floori(z / TILE))

# 스트리밍 중심 갱신(플레이어 위치). 타일이 바뀔 때만 일한다.
# 근경 반경(타일)을 바꾼다 — 배 위 낮은 시점은 기슭이 멀리까지 보여 근경 칸이 많이 그려지므로 1로 줄인다(boat_ride/region_main)
var near_r := NEAR_R
func set_near_r(n: int) -> void:
	if n == near_r: return
	near_r = n
	_center = Vector2i(1 << 20, 1 << 20)   # 다음 focus에서 다시 고른다

func focus(pos: Vector3) -> void:
	if indoor != null: return   # 실내 공간 안: 권역 타일은 그대로 둔다(다시 읽지 않는다)
	var c := tile_of(pos.x, pos.z)
	if c == _center: return
	_center = c
	if OS.get_cmdline_user_args().has("--trace"): print("  RETILE f=%d center=%s" % [Engine.get_process_frames(), c])
	var want := {}
	for dz in range(-MID_R, MID_R + 1):
		for dx in range(-MID_R, MID_R + 1):
			var t := c + Vector2i(dx, dz)
			if not _tile_ok(t): continue
			var ring := maxi(absi(dx), absi(dz))
			var lod := 0 if ring <= near_r else 1
			# 이미 근경인 타일은 한 칸 더 멀어질 때까지 근경 유지
			if lod == 1 and tiles.has(t) and tiles[t].lod == 0 and ring <= near_r + KEEP: lod = 0
			want[t] = lod
	for t in tiles.keys():
		if not want.has(t): _drop_tile(t)
	for t in want: _set_tile(t, want[t])
	var lo := Vector2i(maxi(c.x - MID_R, tile_min.x), maxi(c.y - MID_R, tile_min.y))
	var hi := Vector2i(mini(c.x + MID_R, tile_max.x), mini(c.y + MID_R, tile_max.y))
	mat_far.set_shader_parameter("hole", Vector4(lo.x * TILE, lo.y * TILE, (hi.x + 1) * TILE, (hi.y + 1) * TILE))
	# 식생 대기열: 가까운 타일부터
	_queue_scatter()
	if farm != null: farm.refocus(c)
	stats.near = 0; stats.mid = 0
	for t in tiles:
		if tiles[t].lod == 0: stats.near += 1
		else: stats.mid += 1

func _set_tile(t: Vector2i, lod: int) -> void:
	var st: Dictionary
	if tiles.has(t):
		st = tiles[t]
		if st.lod == lod: return
	else:
		var node: Node3D = _pool.pop_back() if not _pool.is_empty() else _new_tile_node()
		node.position = Vector3(t.x * TILE, 0, t.y * TILE)
		node.name = "tile_%d_%d" % [t.x, t.y]
		# 칸(64m)마다 높이 범위 → 화면 밖 칸은 그리지 않는다(고정 시점이라 근경 대부분이 걸러진다)
		var all := Vector2(INF, -INF)
		var n := TILE / CHUNK
		for cj in n:
			for ci in n:
				var yr := _chunk_y(t.x * TILE + ci * CHUNK, t.y * TILE + cj * CHUNK)
				all = Vector2(minf(all.x, yr.x), maxf(all.y, yr.y))
				var mi: MeshInstance3D = node.get_child(1 + cj * n + ci)
				mi.custom_aabb = AABB(Vector3(-1, yr.x - SKIRT - 2.0, -1), Vector3(CHUNK + 2, yr.y - yr.x + SKIRT + 4.0, CHUNK + 2))
		node.get_child(0).custom_aabb = AABB(Vector3(-1, all.x - SKIRT * 2.0 - 2.0, -1), Vector3(TILE + 2, all.y - all.x + SKIRT * 2.0 + 4.0, TILE + 2))
		terrain_root.add_child(node)
		if tile_listener.is_valid(): tile_listener.call(t)
		_gen += 1
		st = { lod = -1, node = node, scatter_nodes = [], scatter_job = -1, scatter_hold = null, has0 = false, has1 = false, gen = _gen }
		tiles[t] = st
	st.lod = lod
	if farm != null: farm.tile_lod(t, lod)
	var kids: Array = st.node.get_children()
	kids[0].visible = lod != 0
	for i in range(1, kids.size()): kids[i].visible = lod == 0
	if lod != 0: _unscatter(t)
	_attach_statics(t, lod)

func _new_tile_node() -> Node3D:
	var node := Node3D.new()
	var mid := MeshInstance3D.new()
	mid.mesh = mesh_mid; mid.material_override = mat_mid
	mid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mid)
	var n := TILE / CHUNK
	for cj in n:
		for ci in n:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh_near; mi.material_override = mat_near
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(ci * CHUNK, 0, cj * CHUNK)
			node.add_child(mi)
	return node

# 64m 칸의 데이터 높이 범위(16m 간격 표본 + 여유)
func _chunk_y(x0: float, z0: float) -> Vector2:
	var lo := INF; var hi := -INF
	var i0 := floori((x0 - hx0) / hstep); var j0 := floori((z0 - hz0) / hstep)
	var n := int(CHUNK / hstep)
	var st := maxi(1, int(16.0 / hstep))
	for j in range(j0 - st, j0 + n + st + 1, st):
		for i in range(i0 - st, i0 + n + st + 1, st):
			var h := _hraw(i, j)
			lo = minf(lo, h); hi = maxf(hi, h)
	return Vector2(lo - 8.0, hi + 8.0)

func _drop_tile(t: Vector2i) -> void:
	var st: Dictionary = tiles[t]
	if st.scatter_job >= 0:
		# 진행 중 식생 작업: 타일을 지워도 결과(트리 밖 MultiMeshInstance3D)는 끝난 뒤 지워야 한다 — 안 그러면 노드·RID가 샌다
		_scatter_orphans.append([st.scatter_job, st.scatter_hold])
		st.scatter_job = -1; st.scatter_hold = null
	if farm != null: farm.tile_lod(t, -1)
	_unscatter(t)
	_attach_statics(t, 2)
	terrain_root.remove_child(st.node)
	_pool.append(st.node)
	tiles.erase(t)

# ---- 식생(kit/nature/scatter.gd) — 백그라운드 ----
func _unscatter(t: Vector2i) -> void:
	_queue.erase(t)
	var st: Dictionary = tiles[t]
	for e in st.scatter_nodes:
		if e.node != null: e.node.queue_free()
	st.scatter_nodes = []
	st.has0 = false; st.has1 = false
	_gen += 1
	st.gen = _gen
	_scatter_grid.erase(t)
	_tall.erase(t)
	for k in _cut.keys():
		if k[0] == t: _cut.erase(k)
	# 진행 중 작업은 끝나면 버린다(_poll_jobs)

# 작업 스레드: 같은 타일을 lod 0(가까운 묶음용)과 lod 1(먼 묶음용) 두 벌로 흩뿌린다.
# 묶음마다 차지하는 xz 사각형을 미리 계산해 두고, 메인 스레드는 거리만 보고 어느 벌을 보일지 고른다(_update_scatter_lod).
# 작업 스레드에서는 렌더링 서버를 거의 건드리지 않는다: 원본 MultiMesh 버퍼를 묶음마다 한 번만 읽어
# SUB m 칸으로 나눈 "자료"만 만들고, MultiMesh·노드 생성은 메인 스레드가 프레임마다 조금씩 한다(_poll_jobs).
# (작업 스레드에서 MultiMesh를 수백 개 만들거나 버퍼를 여러 번 읽으면 렌더 스레드와 엉켜 프레임이 100ms 넘게 튄다)
static func _scatter_job(scr: Script, rect: Rect2, ha: Callable, la: Callable, seed: int, lods: Array, split: bool, excl: Array, hold: Dictionary, roads: Array = []) -> void:
	var out := []
	var cols = null
	var tall := {}
	var temps := []
	var ex_arg := []   # scatter(…, exclude)용: 축 정렬 Rect2 또는 {x,z,r} 원
	for e in excl:
		# 회전 반영 축 정렬 사각형(kit-nature 요청)
		var ca := absf(cos(e.ry)); var sa := absf(sin(e.ry))
		var hb := Vector2(e.half.x * ca + e.half.y * sa, e.half.x * sa + e.half.y * ca)
		ex_arg.append(Rect2(e.c - hb, hb * 2.0))
	var takes_ex := false
	var takes_roads := false
	for m in scr.get_script_method_list():
		if m.name == "scatter" and m.args.size() >= 6: takes_ex = true
		if m.name == "scatter" and m.args.size() >= 7: takes_roads = true
	for lod in lods:
		if cancel_all: break   # 끝내기·넘어가기 — 남은 건 버린다(hold는 아래에서 채워 정리되게)
		# 길은 이 공간의 roads를 넘긴다(scatter가 남원 region.json을 직접 읽지 않게 — 여러 권역·노정)
		var res: Dictionary = scr.scatter(rect, ha, la, seed, lod, ex_arg, roads) if takes_roads else (scr.scatter(rect, ha, la, seed, lod, ex_arg) if takes_ex else scr.scatter(rect, ha, la, seed, lod))
		if lod == 0 or cols == null:
			cols = []
			for c in res.get("colliders", []):
				if not _excluded(excl, Vector2(float(c.get("x", 0.0)), float(c.get("z", 0.0))), 0.0): cols.append(c)
		for n0 in res.get("nodes", []):
			if cancel_all:
				temps.append(n0); continue   # 노드만 모아 shutdown이 지우게
			if not (n0 is MultiMeshInstance3D) or n0.multimesh == null or n0.multimesh.transform_format != MultiMesh.TRANSFORM_3D:
				out.append({ node = n0, lod = lod, rect = Rect2(n0.position.x, n0.position.z, 0, 0) if n0 is Node3D else Rect2() })
				continue
			temps.append(n0)
			var mm: MultiMesh = n0.multimesh
			var buf: PackedFloat32Array = mm.buffer
			var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var base: Transform3D = n0.transform
			var ab := mm.mesh.get_aabb() if mm.mesh else AABB()
			var is_tall := ab.size.y >= 2.5
			var cr := maxf(ab.size.x, ab.size.z) * 0.5
			var cast: bool = n0.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and lod == 0 and ab.size.y >= SHADOW_MIN_H
			var groups := {}
			for i in mm.instance_count:
				var o := i * stride
				if o + stride > buf.size(): break
				var w := base * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
				if not excl.is_empty() and _excluded(excl, Vector2(w.x, w.z), 0.5): continue  # 배치 자리 식생 비우기
				var k := Vector2i(floori(w.x / SUB), floori(w.z / SUB)) if split else Vector2i.ZERO
				if not groups.has(k): groups[k] = { buf = PackedFloat32Array(), lo = Vector2(INF, INF), hi = Vector2(-INF, -INF), n = 0 }
				var g: Dictionary = groups[k]
				g.buf.append_array(buf.slice(o, o + stride))
				g.lo = Vector2(minf(g.lo.x, w.x), minf(g.lo.y, w.z)); g.hi = Vector2(maxf(g.hi.x, w.x), maxf(g.hi.y, w.z))
				g.n += 1
			for k in groups:
				var g: Dictionary = groups[k]
				var e := { xf = base, mat = n0.material_override, mesh = mm.mesh, colors = mm.use_colors, custom = mm.use_custom_data, buf = g.buf, count = g.n,
					lod = lod, rect = Rect2(g.lo, g.hi - g.lo), cast = cast, mm = null, node = null }
				out.append(e)
				if is_tall and lod == 0:
					for i in int(g.n):
						var o: int = i * stride
						var bx := Vector3(g.buf[o], g.buf[o + 4], g.buf[o + 8]); var by := Vector3(g.buf[o + 1], g.buf[o + 5], g.buf[o + 9]); var bz := Vector3(g.buf[o + 2], g.buf[o + 6], g.buf[o + 10])
						var xf := Transform3D(Basis(bx, by, bz), Vector3(g.buf[o + 3], g.buf[o + 7], g.buf[o + 11]))
						var w := base * xf.origin
						var ck := Vector2i(floori(w.x / CUT_CELL), floori(w.z / CUT_CELL))
						if not tall.has(ck): tall[ck] = []
						tall[ck].append([e, i, xf, cr * bx.length(), Vector2(w.x, w.z)])
	hold.entries = out
	hold.colliders = cols
	hold.lods = lods
	hold.tall = tall
	hold.temps = temps

# 메인 스레드: 자료 → MultiMeshInstance3D
static func _make_node(e: Dictionary) -> Node3D:
	if e.node != null: return e.node
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = e.colors; m.use_custom_data = e.custom
	m.mesh = e.mesh
	m.instance_count = e.count
	m.buffer = e.buf
	var c := MultiMeshInstance3D.new()
	c.transform = e.xf
	c.material_override = e.mat
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if e.cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.multimesh = m
	e.mm = m
	e.node = c
	e.buf = PackedFloat32Array()
	return c

func _scatter_need(t: Vector2i) -> Array:
	var st: Dictionary = tiles[t]
	var need := []
	if _ring(t, _center) <= 1 and not st.has0: need.append(0)
	if not st.has1: need.append(1)
	return need

func _queue_scatter() -> void:
	if _scatter_script == null: return
	for t in tiles:
		var st: Dictionary = tiles[t]
		if st.lod != 0 or st.scatter_job >= 0 or _queue.has(t): continue
		if not _scatter_need(t).is_empty(): _queue.append(t)
	_queue.sort_custom(func(a, b): return _ring(a, _center) < _ring(b, _center))

var _roads_arg: Array = []

func _start_jobs() -> void:
	var running := 0
	for t in tiles:
		if tiles[t].scatter_job >= 0: running += 1
	while running < (MAX_JOBS_LOADING if loading else MAX_JOBS) and not _queue.is_empty():
		var t: Vector2i = _queue.pop_front()
		if not tiles.has(t) or tiles[t].lod != 0: continue
		var need := _scatter_need(t)
		if need.is_empty(): continue
		var hold := { tile = t }
		var rect := Rect2(t.x * TILE, t.y * TILE, TILE, TILE)
		var seed := String(region.get("region_id", "region")).hash() & 0x7fffffff  # 권역 시드(타일 구분은 scatter가 rect로)
		var ha := Callable(self, "height_fast"); var la := Callable(self, "landuse_scatter" if farm != null else "landuse_at")
		tiles[t].scatter_job = Jobs.add(_scatter_job.bind(_scatter_script, rect, ha, la, seed, need, split_scatter, _excl_for(rect), hold, _roads_arg), "scatter")
		tiles[t].scatter_hold = hold
		running += 1
	stats.jobs = running + _queue.size() + (1 if not _attach_q.is_empty() else 0) + (farm.pending() if farm != null else 0)

# 반경 r 타일 안에 아직 식생 짓기·붙이기가 남았나(시작 화면 — 화면에 드는 둘레만 기다린다)
func scatter_busy_near(c: Vector2i, r: int) -> bool:
	if farm != null and farm.busy_near(c, r): return true
	for t in tiles:
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= r and tiles[t].scatter_job >= 0: return true
	for t in _queue:
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= r: return true
	for it in _attach_q:
		var t: Vector2i = it[0]
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= r: return true
	return false

var _scatter_orphans := []   # [작업 번호, hold] — 버린 타일의 진행 중 식생 작업

static func _free_scatter_hold(hold) -> void:
	if hold == null: return
	for tn in hold.get("temps", []):
		if is_instance_valid(tn) and not tn.is_inside_tree(): tn.free()
	for e in hold.get("entries", []):
		if e.node != null and is_instance_valid(e.node) and not e.node.is_inside_tree(): e.node.free()
	hold.clear()

func _poll_orphans(wait: bool) -> void:
	for q in range(_scatter_orphans.size() - 1, -1, -1):
		var o: Array = _scatter_orphans[q]
		if not wait and not Jobs.done(o[0]): continue
		Jobs.wait(o[0])
		_free_scatter_hold(o[1])
		_scatter_orphans.remove_at(q)

func _poll_jobs() -> void:
	_poll_orphans(false)
	# 붙이기는 프레임당 ATTACH_PER_FRAME 묶음까지(한 번에 수백 개를 붙이면 프레임이 튄다)
	var n := 0
	while not _attach_q.is_empty() and n < (ATTACH_PER_FRAME * 8 if loading else ATTACH_PER_FRAME):
		var it: Array = _attach_q.pop_front()
		var t: Vector2i = it[0]; var e: Dictionary = it[1]
		if not tiles.has(t) or tiles[t].lod != 0 or tiles[t].gen != it[2]:
			if e.node != null and not e.node.is_inside_tree(): e.node.free()
			continue
		_make_node(e)
		e.node.visible = false
		e.shown = false
		scatter_root.add_child(e.node)
		tiles[t].scatter_nodes.append(e)
		n += 1
		_lod_dirty = true
	for t in tiles:
		var st: Dictionary = tiles[t]
		if st.scatter_job < 0 or not Jobs.done(st.scatter_job): continue
		Jobs.wait(st.scatter_job)
		st.scatter_job = -1
		var hold: Dictionary = st.scatter_hold
		st.scatter_hold = null
		var entries: Array = hold.get("entries", [])
		for tn in hold.get("temps", []): tn.free()  # 원본 묶음 노드(자료만 빼 썼다)
		if st.lod != 0:
			for e in entries:
				if e.node != null: e.node.free()
			continue
		var lods: Array = hold.get("lods", [])
		if lods.has(0):
			st.has0 = true
			_tall[t] = hold.get("tall", {})
		if lods.has(1): st.has1 = true
		if lods.has(0) or not _scatter_grid.has(t):
			var g := {}
			for c in hold.get("colliders", []): _grid_insert(g, c)
			_scatter_grid[t] = g
		for e in entries: _attach_q.append([t, e, st.gen])
		stats.scatter_done += 1
		if OS.get_cmdline_user_args().has("--trace"): print("  JOB f=%d tile=%s lods=%s nodes=%d" % [Engine.get_process_frames(), t, lods, entries.size()])
	_start_jobs()

# 식생 묶음 고르기: 플레이어에서 lod0_dist 안은 자세한 벌, scatter_far 안은 거친 벌, 그 너머(안개 속)는 그리지 않는다
func update_scatter_lod(player: Vector3, force := false) -> void:
	if indoor != null: return
	if farm != null: farm.update(player)
	_lod_frame += 1
	if not force and not _lod_dirty and _lod_frame % 6 != 0: return
	_lod_dirty = false
	var p := Vector2(player.x, player.z)
	for t in tiles:
		for e in tiles[t].scatter_nodes:
			var r: Rect2 = e.rect
			var d := Vector2(maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x), maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)).length()
			var on: bool = (d < lod0_dist) if e.lod == 0 else (d >= lod0_dist and d < scatter_far)
			if on != e.shown:
				e.shown = on
				e.node.visible = on

# ---------------------------------------------------------------------------
# 정적 물체(키트 build() 결과)
# ---------------------------------------------------------------------------
# node: 키트 node(원점 = 바닥 중심), world_xform: 놓을 자리, info: build()가 돌려준 사전(colliders/lights/occluder/interior…)
# 돌려주는 값: 정적 물체 항목 { node, colliders, lights, occ, interior, attached … } (프롭 상태가 불빛을 더할 때 쓴다)
func add_static(node: Node3D, world_xform: Transform3D, info: Dictionary = {}, tag := "") -> Dictionary:
	node.transform = world_xform
	var cols := []
	for c in info.get("colliders", []):
		var wc := _xf_collider(c, world_xform)
		cols.append(wc)
		_grid_insert(_static_grid, wc)
		colliders.append(wc)
	var ls := []
	for l in info.get("lights", []):
		var p := world_xform * Vector3(float(l.x), float(l.y), float(l.z))
		ls.append({ x = p.x, y = p.y, z = p.z, kind = l.get("kind", "lantern") })
	var occ = null
	if info.get("occluder", false):
		var meshes := []
		for m in node.find_children("*", "MeshInstance3D", true, false):
			for s in m.mesh.get_surface_count():
				if m.get_surface_override_material(s) == null and m.mesh.surface_get_material(s) is ShaderMaterial:
					m.set_surface_override_material(s, m.mesh.surface_get_material(s))
			meshes.append(m)
		if not meshes.is_empty():
			occ = { node = node, aabb = AABB(), meshes = meshes, alpha = 1.0, target = 1.0, faded = false }
	var interior = null
	if info.has("interior"):
		var it: Dictionary = info.interior.duplicate()
		var b := _xf_box(it, world_xform)
		it.merge(b, true)
		it.id = String(node.name)
		# 같은 키트를 두 번째부터 instantiate로 놓으면 hide가 첫 노드를 가리킨다 → 이 노드의 같은 경로로
		var src = info.get("node")
		if src is Node and src != node and it.get("hide") is Array:
			var hs := []
			for h in it.hide:
				if h is Node and is_instance_valid(h) and (src as Node).is_ancestor_of(h):
					var nn := node.get_node_or_null((src as Node).get_path_to(h))
					if nn != null: hs.append(nn)
				else: hs.append(h)
			it.hide = hs
		if it.has("floor_y"): it.floor_world = world_xform.origin.y + float(it.floor_y)  # 마루 높이(§4 보완)
		interior = it
	var fp := to_v2(info.get("footprint", Vector2.ZERO))
	var t := tile_of(world_xform.origin.x, world_xform.origin.z)
	var e := { node = node, colliders = cols, lights = ls, occ = occ, interior = interior, attached = false, big = fp.length() > 40.0, tag = tag, tile = t }
	if not _statics.has(t): _statics[t] = []
	_statics[t].append(e)
	stats.statics += 1
	if tiles.has(t): _attach_one(e, tiles[t].lod)
	return e

# n의 변환을 root(포함)까지 곱한다 — 트리 밖에서도 쓰려고(global_transform 대신)
static func _xf_to(n: Node3D, root: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while n != root and p != null and p is Node3D:
		if n == root: break
		xf = (p as Node3D).transform * xf if p != root else root.transform * xf
		if p == root: return xf
		n = p; p = p.get_parent()
	return xf

static func to_v2(v) -> Vector2:
	if v is Vector2: return v
	if v is Array and v.size() >= 2: return Vector2(float(v[0]), float(v[1]))
	if v is Dictionary: return Vector2(float(v.get("x", 0.0)), float(v.get("y", v.get("z", 0.0))))
	return Vector2.ZERO

# 꼬리표(tag)가 같은 정적 물체를 모두 지운다(배치 다시 읽기용)
func remove_tagged(tag: String) -> void:
	for t in _statics.keys():
		var keep := []
		for e in _statics[t]:
			if e.tag != tag: keep.append(e); continue
			_attach_one(e, 2)
			if is_instance_valid(e.node): e.node.free()
			stats.statics -= 1
		_statics[t] = keep
	# 충돌체 격자 다시
	_static_grid.clear(); colliders.clear()
	for t in _statics:
		for e in _statics[t]:
			for c in e.colliders:
				_grid_insert(_static_grid, c); colliders.append(c)
	for c in _dyn_cols:
		_grid_insert(_static_grid, c); colliders.append(c)

func _attach_statics(t: Vector2i, lod: int) -> void:
	for e in _statics.get(t, []): _attach_one(e, lod)

# lod 0: 근경(전부), 1: 중경(큰 것만), 2: 없음
func _attach_one(e: Dictionary, lod: int) -> void:
	var on: bool = lod == 0 or (lod == 1 and e.big)
	if on == e.attached: return
	e.attached = on
	if on:
		statics_root.add_child(e.node)
		lights.append_array(e.lights)
		if e.occ != null:
			var box := AABB(); var first := true
			for m in e.occ.meshes:
				var bb: AABB = _xf_to(m, e.node) * m.get_aabb()
				box = bb if first else box.merge(bb); first = false
			e.occ.aabb = box
			occluders.append(e.occ)
		if e.interior != null: interiors.append(e.interior)
	else:
		if e.occ != null:
			if e.occ.alpha < 1.0:
				e.occ.alpha = 1.0; e.occ.target = 1.0
				set_occluder_alpha(e.occ, 1.0)
			occluders.erase(e.occ)
		for l in e.lights: lights.erase(l)
		if e.interior != null: interiors.erase(e.interior)
		statics_root.remove_child(e.node)
	lights_version += 1

static func _xf_collider(c: Dictionary, xf: Transform3D) -> Dictionary:
	if c.get("type", "circle") == "circle":
		var p := xf * Vector3(float(c.x), 0, float(c.z))
		return { type = "circle", x = p.x, z = p.z, r = float(c.r) * xf.basis.get_scale().x }
	# 돌린 상자는 방향 있는 상자(obox)로 — 축 정렬로 감싸면 다리 난간 상자가 다리 가운데까지 덮는다
	var bs := xf.basis.orthonormalized()
	var ang := atan2(-bs.x.z, bs.x.x)
	if absf(sin(ang * 2.0)) < 1e-3:
		var b := _xf_box(c, xf)
		b.type = "box"
		return b
	var sc := xf.basis.get_scale().x
	var cl := Vector3((float(c.minX) + float(c.maxX)) * 0.5, 0, (float(c.minZ) + float(c.maxZ)) * 0.5)
	var cw := xf * cl
	var o := { type = "obox", cx = cw.x, cz = cw.z, hx = (float(c.maxX) - float(c.minX)) * 0.5 * sc, hz = (float(c.maxZ) - float(c.minZ)) * 0.5 * sc,
		ca = cos(ang), sa = sin(ang) }
	var bb := _xf_box(c, xf)
	o.minX = bb.minX; o.maxX = bb.maxX; o.minZ = bb.minZ; o.maxZ = bb.maxZ
	return o

static func _xf_box(b: Dictionary, xf: Transform3D) -> Dictionary:
	var mnx := INF; var mxx := -INF; var mnz := INF; var mxz := -INF
	for cx in [float(b.minX), float(b.maxX)]:
		for cz in [float(b.minZ), float(b.maxZ)]:
			var p := xf * Vector3(cx, 0, cz)
			mnx = minf(mnx, p.x); mxx = maxf(mxx, p.x); mnz = minf(mnz, p.z); mxz = maxf(mxz, p.z)
	return { minX = mnx, maxX = mxx, minZ = mnz, maxZ = mxz }

static func _grid_insert(g: Dictionary, c: Dictionary) -> void:
	var lo: Vector2; var hi: Vector2
	if c.get("type", "circle") == "circle":
		lo = Vector2(c.x - c.r, c.z - c.r); hi = Vector2(c.x + c.r, c.z + c.r)
	else:
		lo = Vector2(c.minX, c.minZ); hi = Vector2(c.maxX, c.maxZ)
	for j in range(floori(lo.y / GRID), floori(hi.y / GRID) + 1):
		for i in range(floori(lo.x / GRID), floori(hi.x / GRID) + 1):
			var k := Vector2i(i, j)
			if not g.has(k): g[k] = []
			g[k].append(c)

# ---------------------------------------------------------------------------
# 충돌(부모 move_circle이 이걸 부른다)
# ---------------------------------------------------------------------------
static func _hit(c: Dictionary, x: float, z: float, r: float) -> bool:
	if c.type == "circle":
		var dx: float = x - c.x; var dz: float = z - c.z; var rr: float = r + c.r
		return dx * dx + dz * dz < rr * rr
	if c.type == "obox":
		var l := _to_local(Vector2(x - c.cx, z - c.cz), c.ca, c.sa)
		var ox := maxf(absf(l.x) - c.hx, 0.0); var oz := maxf(absf(l.y) - c.hz, 0.0)
		return ox * ox + oz * oz < r * r
	var nx := clampf(x, c.minX, c.maxX); var nz := clampf(z, c.minZ, c.maxZ)
	var dx := x - nx; var dz := z - nz
	return dx * dx + dz * dz < r * r

func blocked(x: float, z: float, r: float) -> bool:
	if indoor != null: return indoor.blocked(x, z, r)
	if x < hx0 + 2.0 or z < hz0 + 2.0 or x > hx0 + (hnx - 1) * hstep - 2.0 or z > hz0 + (hnz - 1) * hstep - 2.0: return true
	if block_water and _in_river(x, z, r) and not _near_crossing(x, z): return true
	if not _ponds.is_empty() and in_pond(x, z) and (_walk_grid.is_empty() or walk_at(x, z) == null): return true
	var ci := floori(x / GRID); var cj := floori(z / GRID)
	var t := tile_of(x, z)
	var sg = _scatter_grid.get(t)
	for j in range(cj - 1, cj + 2):
		for i in range(ci - 1, ci + 2):
			var k := Vector2i(i, j)
			for c in _static_grid.get(k, []):
				if _hit(c, x, z, r): return true
			if sg != null:
				for c in sg.get(k, []):
					if _hit(c, x, z, r): return true
	# 타일 경계 근처면 옆 타일 식생도
	var lx := x - t.x * TILE; var lz := z - t.y * TILE
	if lx < GRID or lz < GRID or lx > TILE - GRID or lz > TILE - GRID:
		for dt in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
			var g2 = _scatter_grid.get(t + dt)
			if g2 == null: continue
			for j in range(cj - 1, cj + 2):
				for i in range(ci - 1, ci + 2):
					for c in g2.get(Vector2i(i, j), []):
						if _hit(c, x, z, r): return true
	return false

func _in_river(x: float, z: float, r: float) -> bool:
	if not _walk_grid.is_empty() and walk_at(x, z) != null: return false  # 다리·징검다리 위
	if landuse_at(x, z) == 5 and not is_dry_bed(x, z): return true
	if not is_nan(sea_y) and ground_at(x, z) < sea_y - 0.15: return true   # 바다 밑 바위·모래(토지이용이 물이 아닌 칸)
	if not lakes.is_empty():
		var lk = lake_at(x, z)
		if lk != null and ground_at(x, z) < float(lk.y) - 0.05: return true
	var p := Vector2(x, z)
	for c in _river_grid.get(Vector2i(floori(x / GRID), floori(z / GRID)), []):
		var sg: Dictionary = c.seg
		var ab: Vector2 = sg.b - sg.a
		var t := clampf((p - sg.a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if p.distance_to(sg.a + ab * t) < sg.r:
			# 물가: 땅이 수면보다 낮으면 물 속
			if ground_at(x, z) < lerpf(sg.ya, sg.yb, t) + 0.05: return true
	return false

# 나루·여울·다리 근처는 물에 들어갈 수 있다(다리 상판은 아직 없음 — kit-village 다리가 놓이면 높이를 넘겨받아야 한다)
func _near_crossing(x: float, z: float) -> bool:
	for c in _crossings:
		if absf(c.x - x) < 14.0 and absf(c.y - z) < 14.0: return true
	return false

func interior_at(x: float, z: float) -> Variant:
	if indoor != null: return indoor.interior
	for it in interiors:
		if in_box(it, x, z): return it
	return null

# 트리에 붙어 있지 않은 것(풀에 넣은 타일, 떼어 둔 정적 물체)은 직접 지운다
# 끝내기 전에(작업 스레드 풀이 살아 있을 때) 부른다: 대기열 비우고 진행 중 식생 작업을 기다린다.
# (트리가 지워지는 도중에 기다리면 macOS 종료 경로에서 풀이 이미 멈춰 영원히 기다릴 수 있다)
# 끝내기·넘어가기 때 진행 중 식생 작업을 일찍 끝내게(작업 스레드가 읽는다; shutdown()이 되돌린다)
static var cancel_all := false

func jobs_idle() -> bool:
	if farm != null and not farm.jobs_idle(): return false
	for o in _scatter_orphans:
		if not Jobs.done(o[0]): return false
	for t in tiles:
		if tiles[t].scatter_job >= 0 and not Jobs.done(tiles[t].scatter_job): return false
	return true

func shutdown() -> void:
	_queue.clear()
	if farm != null: farm.shutdown()
	_poll_orphans(true)
	for t in tiles:
		if tiles[t].scatter_job >= 0:
			Jobs.wait(tiles[t].scatter_job)
			tiles[t].scatter_job = -1
			var hold = tiles[t].scatter_hold
			tiles[t].scatter_hold = null
			if hold != null:
				for tn in hold.get("temps", []): tn.free()
				for e in hold.get("entries", []):
					if e.node != null and not e.node.is_inside_tree(): e.node.free()
	for it in _attach_q:
		if it[1].node != null and not it[1].node.is_inside_tree(): it[1].node.free()
	_attach_q.clear()
	cancel_all = false

# 트리에 붙어 있지 않은 것(풀에 넣은 타일, 떼어 둔 정적 물체)은 직접 지운다
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for n in _pool: n.free()
		_pool.clear()
		for t in _statics:
			for e in _statics[t]:
				if not e.attached and is_instance_valid(e.node): e.node.free()

var use_cutaway := false   # 키트 재질 점무늬 가림(occ_*)이 생겨 기본은 끔(--cutaway로 켬)

func update(_dt: float, _time: float) -> void:
	_poll_jobs()
	_update_dry()
	if decals != null: decals.update(_dt)

# ---------------------------------------------------------------------------
# 실내 공간(scripts/region/interior_space.gd) — 권역을 그대로 둔 채 지형·물·정적 물체·식생·원경을 숨기고 실내 키트만 세운다
# ---------------------------------------------------------------------------
func enter_indoor(sp: Dictionary) -> void:
	if indoor != null: exit_indoor()
	var I = load("res://scripts/region/interior_space.gd").new()
	I.build(self, sp)
	indoor = I
	for n in [terrain_root, water_root, statics_root, scatter_root, far_node]:
		if n != null: n.visible = false
	if farm != null and farm.get("root") is Node3D: farm.root.visible = false

func exit_indoor() -> void:
	if indoor == null: return
	indoor.teardown(self)
	indoor = null
	for n in [terrain_root, water_root, statics_root, scatter_root, far_node]:
		if n != null: n.visible = true
	if farm != null and farm.get("root") is Node3D: farm.root.visible = true
	_center = Vector2i(1 << 20, 1 << 20)

# ---------------------------------------------------------------------------
# 사건용 세계 API (이야기 쪽이 부른다 — docs/reports/world-scenario.md)
# ---------------------------------------------------------------------------
# 프롭 상태: key = 배치 id 또는 "배치 id/그룹", state = NORMAL USED EMPTY BROKEN FALLEN WET BLOODY BURNT MOVED SEALED OPEN (+FIRE_1..3)
func set_prop_state(key: String, state: String) -> bool:
	return props.set_state(key, state) if props != null else false

func get_prop_state(key: String) -> String:
	return props.get_state(key) if props != null else "NORMAL"

# 배치 항목의 키트 앵커(문·책상·숨은 바닥…)를 월드 좌표로(없으면 null)
func prop_anchor(id: String, anchor_name: String) -> Variant:
	return props.anchor(id, anchor_name) if props != null else null

# 실내 id(배치 id)로 찾기 — { id, minX…, floor_world, camera }
func interior_by_id(id: String) -> Variant:
	for t in _statics:
		for e in _statics[t]:
			if e.interior != null and String(e.interior.get("id", "")) == id: return e.interior
	return null

# 상태가 더하는 충돌체(로컬 c를 xf로) — 돌려준 사전을 remove_dynamic_collider에 넘겨 지운다
func add_dynamic_collider(c: Dictionary, xf: Transform3D) -> Dictionary:
	var wc := _xf_collider(c, xf)
	_grid_insert(_static_grid, wc)
	colliders.append(wc)
	_dyn_cols.append(wc)
	return wc

func remove_dynamic_collider(wc: Dictionary) -> void:
	_dyn_cols.erase(wc)
	colliders.erase(wc)
	for k in _static_grid:
		(_static_grid[k] as Array).erase(wc)

# world_scenario.json(권역·노정 폴더, 선택): 파이프라인이 만든 region.json/route.json을 건드리지 않고 장소를 덧붙인다.
# 배열 키(settlements landmarks sights roads crossings river_lanes)는 뒤에 이어 붙이고, 같은 id가 있으면 덮어쓴다.
func _merge_overlay(path: String) -> void:
	if not FileAccess.file_exists(path): return
	var ov = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (ov is Dictionary): push_warning("world_scenario.json 형식 오류: " + path); return
	var n := 0
	for k in ["settlements", "landmarks", "sights", "roads", "crossings", "river_lanes"]:
		if not (ov.get(k) is Array): continue
		var arr: Array = region.get(k, []) if region.get(k) is Array else []
		for it in ov[k]:
			if not (it is Dictionary): continue
			var dup := -1
			for i in arr.size():
				if arr[i] is Dictionary and it.has("id") and String(arr[i].get("id", "")) == String(it.id): dup = i
			if dup >= 0: arr[dup] = it
			else: arr.append(it)
			n += 1
		region[k] = arr
	print("REGION world_scenario +%d" % n)

# ---------------------------------------------------------------------------
# 식생 가림 처리: 카메라와 플레이어 사이의 키 큰 식생(나무·대숲)을 잠시 줄여 숨긴다.
# 식생은 MultiMesh라 기존 occluders(물체 반투명)로는 못 하므로 인스턴스 단위로 처리한다.
# ---------------------------------------------------------------------------
func update_cutaway(dt: float, player: Vector3, cam: Vector3) -> void:
	if indoor != null: return
	if not use_cutaway and _cut.is_empty(): return
	for k in _cut: _cut[k].want = 1.0
	var lo := Vector2(minf(player.x, cam.x) - 6.0, player.z - 1.0)
	var hi := Vector2(maxf(player.x, cam.x) + 6.0, cam.z + 2.0)
	var pc := Vector2(player.x, player.z); var cc := Vector2(cam.x, cam.z)
	for j in range(floori(lo.y / CUT_CELL), floori(hi.y / CUT_CELL) + 1):
		for i in range(floori(lo.x / CUT_CELL), floori(hi.x / CUT_CELL) + 1):
			var cell := Vector2i(i, j)
			var t := tile_of(i * CUT_CELL + 1.0, j * CUT_CELL + 1.0)
			var g = _tall.get(t)
			if g == null: continue
			for e in g.get(cell, []):
				var p: Vector2 = e[4]
				# 카메라→플레이어 선분(xz)까지 거리가 수관 반지름+여유보다 가까우면
				var ab := pc - cc
				var tt := clampf((p - cc).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.05)
				if p.distance_to(cc + ab * tt) > e[3] + 0.9: continue
				if p.y < player.z - 0.6: continue
				var ent: Dictionary = e[0]
				if ent.mm == null: continue  # 아직 안 붙음
				var key := [t, ent.mm.get_instance_id(), e[1]]
				if not _cut.has(key): _cut[key] = { mm = ent.mm, i = e[1], xf = e[2], k = 1.0, want = 0.0 }
				else: _cut[key].want = 0.0
	var a := 1.0 - exp(-dt * 10.0)
	for key in _cut.keys():
		var c: Dictionary = _cut[key]
		var nk: float = c.k + (c.want - c.k) * a
		if absf(nk - c.want) < 0.02: nk = c.want
		if nk != c.k:
			c.k = nk
			var xf: Transform3D = c.xf
			var s := maxf(nk, 0.001)
			c.mm.set_instance_transform(c.i, Transform3D(xf.basis.scaled_local(Vector3(s, s, s)), xf.origin))
		if c.k >= 1.0 and c.want >= 1.0: _cut.erase(key)

# ---------------------------------------------------------------------------
# 배치 지원(§8): 터 고르기 · 식생 비우기 · 걷기 면. placement_loader.gd가 부른다.
# ---------------------------------------------------------------------------
# 손댄 높이·토지이용·걷기 면·식생 제외를 처음 상태로
func reset_edits() -> void:
	# 작업 스레드(필지 짓기·식생)가 hbytes·lbytes를 읽는 중에 배열을 갈아 끼우면 해제된 메모리를 읽는다 — 먼저 기다린다
	if farm != null: farm.wait_jobs()
	for t in tiles:
		if tiles[t].scatter_job >= 0:
			Jobs.wait(tiles[t].scatter_job); tiles[t].scatter_job = -1
			_free_scatter_hold(tiles[t].scatter_hold); tiles[t].scatter_hold = null
	_poll_orphans(true)
	_walk_grid.clear()
	_ponds.clear()
	hbytes = _h_orig.duplicate(); lbytes = _l_orig.duplicate()
	pbytes = _p_roads.duplicate(); _paint_dirty = true
	_veg_excl.clear(); _walk_grid.clear(); _walks.clear()
	_urban_veg()
	_crossings = _crossings_all.duplicate()
	_terrain_dirty = true
	if farm != null: farm.reset_excl()

# 회전된 사각형(중심 c, y축 회전 ry, 반폭 half) 안을 높이 y로 고른다. 바깥 edge m에 걸쳐 원래 땅으로 부드럽게.
# 안쪽 토지이용 칸에는 "고른 땅" 비트를 켜 잡음 디테일을 없앤다. y가 NAN이면 사각형 안 데이터 높이의 평균.
func flatten_rect(c: Vector2, ry: float, half: Vector2, y: float, edge := 5.0) -> float:
	var ca := cos(ry); var sa := sin(ry)
	var R := half.length() + edge
	var i0 := floori((c.x - R - hx0) / hstep); var i1 := ceili((c.x + R - hx0) / hstep)
	var j0 := floori((c.y - R - hz0) / hstep); var j1 := ceili((c.y + R - hz0) / hstep)
	i0 = clampi(i0, 0, hnx - 1); i1 = clampi(i1, 0, hnx - 1); j0 = clampi(j0, 0, hnz - 1); j1 = clampi(j1, 0, hnz - 1)
	if is_nan(y):
		var sum := 0.0; var n := 0
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var l := _to_local(Vector2(hx0 + i * hstep, hz0 + j * hstep) - c, ca, sa)
				if absf(l.x) <= half.x and absf(l.y) <= half.y:
					sum += _hraw(i, j); n += 1
		y = sum / n if n > 0 else data_height(c.x, c.y)
	var yq := clampf((y - hy0) / hscale, 0.0, 65535.0 if hbpp == 2 else 255.0 * 256.0)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var l := _to_local(Vector2(hx0 + i * hstep, hz0 + j * hstep) - c, ca, sa)
			var d := Vector2(maxf(absf(l.x) - half.x, 0.0), maxf(absf(l.y) - half.y, 0.0)).length()
			if d >= edge: continue
			var w := 1.0 - smoothstep(0.0, edge, d)
			var k := j * hnx + i
			if hbpp == 2:
				var v0 := float(hbytes[k * 2] * 256 + hbytes[k * 2 + 1])
				var v := clampi(roundi(lerpf(v0, yq, w)), 0, 65535)
				hbytes[k * 2] = v >> 8; hbytes[k * 2 + 1] = v & 255
			else:
				var v0 := float(hbytes[k] * 256)
				hbytes[k] = clampi(roundi(lerpf(v0, yq, w) / 256.0), 0, 255)
	# 토지이용 칸: 사각형 안쪽(+1칸)은 잡음 없음
	var li0 := clampi(floori((c.x - R - lx0) / lcell), 0, lw - 1); var li1 := clampi(ceili((c.x + R - lx0) / lcell), 0, lw - 1)
	var lj0 := clampi(floori((c.y - R - lz0) / lcell), 0, lh - 1); var lj1 := clampi(ceili((c.y + R - lz0) / lcell), 0, lh - 1)
	for j in range(lj0, lj1 + 1):
		for i in range(li0, li1 + 1):
			var l := _to_local(Vector2(lx0 + i * lcell, lz0 + j * lcell) - c, ca, sa)
			if absf(l.x) <= half.x + lcell and absf(l.y) <= half.y + lcell:
				lbytes[j * lw + i] = lbytes[j * lw + i] | 128
	_terrain_dirty = true
	return y

static func _to_local(d: Vector2, ca: float, sa: float) -> Vector2:
	# 월드 → 로컬(Basis(UP, ry)의 역회전): x' = x·cos − z·sin … Godot y축 회전 규칙과 같게
	return Vector2(d.x * ca - d.y * sa, d.x * sa + d.y * ca)

# 고친 높이·토지이용을 GPU 텍스처에 올리고, 타일(높이 범위·식생)을 다시 만든다
func commit_terrain() -> void:
	if farm != null: farm.commit()
	if _paint_dirty:
		_paint_dirty = false
		paint_tex.update(Image.create_from_data(hnx, hnz, false, Image.FORMAT_RGBA8, pbytes))
	if not _terrain_dirty: return
	_terrain_dirty = false
	height_tex.update(Image.create_from_data(hnx, hnz, false, Image.FORMAT_RG8 if hbpp == 2 else Image.FORMAT_R8, hbytes))
	landuse_tex.update(Image.create_from_data(lw, lh, false, Image.FORMAT_R8, lbytes))
	reset_tiles()

# 모든 타일을 내렸다가 다시 올린다(높이 범위·식생 다시)
func reset_tiles() -> void:
	for t in tiles.keys():
		if tiles[t].scatter_job >= 0:
			Jobs.wait(tiles[t].scatter_job)
			tiles[t].scatter_job = -1
			var hold = tiles[t].scatter_hold
			tiles[t].scatter_hold = null
			if hold != null:
				for tn in hold.get("temps", []): tn.free()
				for e in hold.get("entries", []):
					if e.node != null and not e.node.is_inside_tree(): e.node.free()
		_drop_tile(t)
	for it in _attach_q:
		if it[1].node != null and not it[1].node.is_inside_tree(): it[1].node.free()
	_attach_q.clear()
	for n in _pool: n.free()
	_pool.clear()
	var c := _center
	_center = Vector2i(1 << 20, 1 << 20)
	if c.x < (1 << 19): focus(Vector3(c.x * TILE + TILE * 0.5, 0, c.y * TILE + TILE * 0.5))

# 못 파기: 물체 변환 xf, 로컬 테두리(x,z), 로컬 물면 높이 wy. 테두리 안 땅을 물면 - depth로 낮추고(텍스처·height_at 둘 다)
# 걸어 들어가지 못하게 등록한다(걷기 면 위는 예외)
func carve_water(xf: Transform3D, outline: PackedVector2Array, wy: float, depth := 0.95) -> void:
	if outline.size() < 3: return
	var poly := PackedVector2Array()
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for q in outline:
		var w := xf * Vector3(q.x, 0, q.y)
		poly.append(Vector2(w.x, w.z))
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.z)); hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.z))
	var target := xf.origin.y + wy - depth
	var yq := clampf((target - hy0) / hscale, 0.0, 65535.0 if hbpp == 2 else 255.0 * 256.0)
	var i0 := clampi(floori((lo.x - hx0) / hstep) - 1, 0, hnx - 1); var i1 := clampi(ceili((hi.x - hx0) / hstep) + 1, 0, hnx - 1)
	var j0 := clampi(floori((lo.y - hz0) / hstep) - 1, 0, hnz - 1); var j1 := clampi(ceili((hi.y - hz0) / hstep) + 1, 0, hnz - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var pp := Vector2(hx0 + i * hstep, hz0 + j * hstep)
			if not Geometry2D.is_point_in_polygon(pp, poly): continue
			var k := j * hnx + i
			if hbpp == 2:
				var v0 := hbytes[k * 2] * 256 + hbytes[k * 2 + 1]
				var v := mini(v0, roundi(yq))
				hbytes[k * 2] = v >> 8; hbytes[k * 2 + 1] = v & 255
			else:
				hbytes[k] = mini(hbytes[k], roundi(yq / 256.0))
	var li0 := clampi(floori((lo.x - lx0) / lcell) - 1, 0, lw - 1); var li1 := clampi(ceili((hi.x - lx0) / lcell) + 1, 0, lw - 1)
	var lj0 := clampi(floori((lo.y - lz0) / lcell) - 1, 0, lh - 1); var lj1 := clampi(ceili((hi.y - lz0) / lcell) + 1, 0, lh - 1)
	for j in range(lj0, lj1 + 1):
		for i in range(li0, li1 + 1):
			if Geometry2D.is_point_in_polygon(Vector2(lx0 + i * lcell, lz0 + j * lcell), poly): lbytes[j * lw + i] = lbytes[j * lw + i] | 128
	_ponds.append({ poly = poly, bb = Rect2(lo, hi - lo), y = xf.origin.y + wy })
	_terrain_dirty = true

func in_pond(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for pd in _ponds:
		if pd.bb.has_point(p) and Geometry2D.is_point_in_polygon(p, pd.poly): return true
	return false

func add_veg_exclusion(c: Vector2, ry: float, half: Vector2) -> void:
	_veg_excl.append({ c = c, ry = ry, half = half })
	if farm != null: farm.exclude(c, ry, half)   # 배치 자리에 걸린 필지는 뺀다(그 자리 땅은 원래대로)

# 식생용 토지이용: 필지가 덮은 논·밭 칸은 12(식생 없음 — 벼·작물은 farm.gd), 필지 밖에 남은 논·밭 칸은 풀밭(1)
func landuse_scatter(x: float, z: float) -> int:
	var l := landuse_at(x, z)
	if l == 5: return l
	if farm.sdf_at(x, z) < 1.0: return 12   # 필지가 덮은 칸(토지이용과 상관없이 — 4m 칸 가장자리의 숲·풀 칸도)
	if l == 2 or l == 3: return 1
	return l

func _excl_for(rect: Rect2) -> Array:
	var out := []
	var r2 := rect.grow(4.0)
	for e in _veg_excl:
		var R: float = e.half.length()
		if Rect2(e.c - Vector2(R, R), Vector2(R, R) * 2.0).intersects(r2): out.append(e)
	return out

static func _excluded(excl: Array, p: Vector2, pad: float) -> bool:
	for e in excl:
		var l := _to_local(p - e.c, cos(e.ry), sin(e.ry))
		if absf(l.x) <= e.half.x + pad and absf(l.y) <= e.half.y + pad: return true
	return false

# 걷기 면(§8 walk): xf = 물체의 월드 변환, w = { minX, maxX, minZ, maxZ, z:[…], y:[…] } (로컬, y는 원점 기준) 또는 axis:"x"와 x:[…]
func add_walk(xf: Transform3D, w: Dictionary) -> void:
	var axis: String = w.get("axis", "z")
	var ks := PackedFloat32Array(w.get(axis, [])); var ys := PackedFloat32Array(w.get("y", []))
	if ks.size() < 2 or ks.size() != ys.size(): return
	var e := { inv = xf.affine_inverse(), y0 = xf.origin.y, minX = float(w.minX), maxX = float(w.maxX), minZ = float(w.minZ), maxZ = float(w.maxZ), axis = axis, ks = ks, ys = ys, c = Vector2(xf.origin.x, xf.origin.z) }
	_walks.append(e)
	var bb := _xf_box(w, xf)
	_grid_insert(_walk_grid, { type = "box", minX = bb.minX, maxX = bb.maxX, minZ = bb.minZ, maxZ = bb.maxZ, walk = e })
	# 다리가 놓인 나루·여울 자리에서는 물을 걸어 건너는 임시 허용을 끈다
	var keep := []
	for cr in _crossings:
		if cr.distance_to(e.c) > 25.0: keep.append(cr)
	_crossings = keep

# 걷기 면 높이(없으면 null)
func walk_at(x: float, z: float) -> Variant:
	var best = null
	for c in _walk_grid.get(Vector2i(floori(x / GRID), floori(z / GRID)), []):
		var e: Dictionary = c.walk
		var l: Vector3 = e.inv * Vector3(x, e.y0, z)
		if l.x < e.minX or l.x > e.maxX or l.z < e.minZ or l.z > e.maxZ: continue
		var k: float = l.z if e.axis == "z" else l.x
		var ks: PackedFloat32Array = e.ks; var ys: PackedFloat32Array = e.ys
		var y: float = ys[0] if k <= ks[0] else ys[ys.size() - 1]
		for i in ks.size() - 1:
			if k >= ks[i] and k <= ks[i + 1]:
				y = lerpf(ys[i], ys[i + 1], (k - ks[i]) / maxf(ks[i + 1] - ks[i], 1e-5)); break
		var wy: float = e.y0 + y
		if best == null or wy > best: best = wy
	return best

# 가까운 하천 수면 높이(radius m 안, 없으면 NAN)
func river_surface_at(x: float, z: float, radius := 40.0) -> float:
	var p := Vector2(x, z)
	var best := INF; var by := NAN
	var ci := floori(x / GRID); var cj := floori(z / GRID)
	var n := ceili(radius / GRID)
	for j in range(cj - n, cj + n + 1):
		for i in range(ci - n, ci + n + 1):
			for c in _river_grid.get(Vector2i(i, j), []):
				var sg: Dictionary = c.seg
				var ab: Vector2 = sg.b - sg.a
				var t := clampf((p - sg.a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
				var d := p.distance_to(sg.a + ab * t)
				if d < best and d < radius: best = d; by = lerpf(sg.ya, sg.yb, t)
	# 호수 안이면 호수 면
	var lk = lake_at(x, z) if not lakes.is_empty() else null
	if lk != null: return float(lk.y)
	# 바다·큰 강 물면(sea): 그 자리나 가까이(반경 안 8방향)가 바다 칸이고 작은 하천이 더 가깝지 않으면 sea.y
	# (배치 로더가 나룻배·배를 물 면에 앉힐 때 — 노정 포구 배도)
	if not is_nan(sea_y) and water_mask != null:
		var near := is_sea(x, z)
		var dd := 4.0
		while not near and dd <= radius:
			for a in 8:
				if is_sea(x + cos(a * PI / 4.0) * dd, z + sin(a * PI / 4.0) * dd): near = true; break
			dd *= 2.0
		if near and (is_nan(by) or best > dd * 0.5): return sea_y
	return by

# ---------------------------------------------------------------------------
# 임시 표지: 마을·랜드마크·고개 자리에 장승 같은 기둥(위치 확인용, 키트 배치는 이번 범위 밖)
# ---------------------------------------------------------------------------
func _place_markers() -> void:
	var items := []
	for s in region.get("settlements", []): items.append([s, Kit.hex(0x8a5a3c)])
	for s in region.get("landmarks", []): items.append([s, Kit.hex(0xa04a36)])
	for s in region.get("passes", []): items.append([s, Kit.hex(0x5a6a7a)])
	for it in items:
		var s: Dictionary = it[0]
		var x := float(s.x); var z := float(s.z)
		var r := Kit.Rng.new(hash(s.get("id", s.name)))
		var b := Kit.Batch.new()
		b.add("wood", Kit.paint(Kit.cyl(0.22, 0.26, 2.6, 7, 0, 1.3, 0), it[1], Kit.hex(0x5a3a28), 0.04, r))
		b.add("wood", Kit.paint(Kit.cyl(0.3, 0.24, 0.7, 7, 0, 2.9, 0), Kit.hex(0xd8c8a8), Kit.hex(0xb0a080), 0.03, r))
		b.add("flat", Kit.paint(Kit.box(0.5, 0.08, 0.06, 0, 2.95, 0.29), Kit.hex(0x2b2622)), 0.0)
		var node := b.build("표지_" + String(s.get("name", "")))
		var lab := Label3D.new()
		lab.text = String(s.get("name", ""))
		lab.font_size = 64; lab.pixel_size = 0.01
		lab.position = Vector3(0, 3.9, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.modulate = Color(0.12, 0.1, 0.09); lab.outline_modulate = Color(0.95, 0.92, 0.85); lab.outline_size = 12
		node.add_child(lab)
		var y := height_at(x, z)
		add_static(node, Transform3D(Basis(), Vector3(x, y, z)), { colliders = [{ type = "circle", x = 0.0, z = 0.0, r = 0.3 }], footprint = Vector2(1, 1) }, "marker")
