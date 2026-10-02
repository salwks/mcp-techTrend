# 타일별 식생 흩뿌리기 (계약서 §6) — 256m 타일 하나를 토지이용·고도·경사로 채워 MultiMeshInstance3D 묶음으로 돌려준다.
#
#   const Scatter := preload("res://kit/nature/scatter.gd")
#   Scatter.warm(0)   # (권장) 시작할 때 메인 스레드에서 한 번: 모델 메시·재질을 미리 만든다
#   var res := Scatter.scatter(Rect2(tx*256, tz*256, 256, 256), height_at, landuse_at, region_seed, lod)
#   for n in res.nodes: add_child(n)      # 좌표는 월드. 씬 트리 접근 없음 → 작업 스레드에서 불러도 된다
#   res.colliders → [{type:"circle", x, z, r}] (월드)
#
# 결정적: 같은 (tile_rect, seed, lod, 높이·토지이용) → 같은 결과. 난수는 타일 좌표와 seed로만 정한다.
# 토지이용 인덱스(계약서 §5): 0 숲, 1 풀밭, 2 논, 3 밭, 4 길, 5 물, 6 마을 터, 7 바위·벼랑, 8 모래톱, 9 대숲
# 고도(해발 m) = y / 0.3 + 60 (계약서 §1). 수종은 지리산 서부 해발대 식생(보고서 참고).
extends RefCounted

const CELL := 4.0        # 판정 격자(m)
const PAD := 3           # 타일 밖으로 더 보는 칸(길·물 거리, 길 북쪽 가림 판정)
const CHUNK := 128.0     # 묶음 크기(m) — 타일당 2×2. 화면(약 50×50m)은 보통 1~2묶음만 걸린다
const MAX_MM := 8        # 묶음마다 MultiMesh는 개수 많은 종류부터 이만큼은 꼭,
const MERGE_MAX := 16    # 그 밖에서 묶음 안 개수가 이 이하인 드문 것은 정적 메시 하나로 합친다(합치기는 꼭짓점 수에 비례해 느리므로 드문 것만)
const MERGE_VERTS := 12000  # 한 종류를 합칠 때 꼭짓점 상한(나무 몇 그루면 넘는다 → 그건 MultiMesh로)
const K := 0.30
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const HWIDE := 1.3      # 나무 가로 배율(수관 넓게)
const N := "res://kit/nature/"

# 종류: 스크립트, 기본 params, 변형 수(seed 다름), 그림자, 줄기 충돌 반지름(배율 1 기준, 0=없음), 원거리(lod1)에서 뺄지
const KINDS := {
	pine = { s = "pine.gd", p = {}, v = 4, cast = true, col = 0.3, tree = true },
	fir = { s = "fir.gd", p = {}, v = 1, cast = true, col = 0.25, tree = true },
	sangsuri = { s = "oak.gd", p = { kind = "sangsuri" }, v = 3, cast = true, col = 0.4, tree = true },
	singal = { s = "oak.gd", p = { kind = "singal" }, v = 3, cast = true, col = 0.35, tree = true },
	gusang = { s = "korean_fir.gd", p = {}, v = 3, cast = true, col = 0.24, tree = true },
	deadwood = { s = "deadwood.gd", p = {}, v = 1, cast = true, col = 0.28, tree = true },
	snag = { s = "deadwood.gd", p = { kind = "snag" }, v = 1, cast = true, col = 0.28, tree = true },
	zelkova = { s = "big_tree.gd", p = { variant = "zelkova" }, v = 1, cast = true, col = 0.7, tree = true },
	willow = { s = "big_tree.gd", p = { variant = "willow" }, v = 1, cast = true, col = 0.45, tree = true },
	broadleaf = { s = "big_tree.gd", p = { variant = "broadleaf" }, v = 1, cast = true, col = 0.47, tree = true },
	persimmon = { s = "persimmon.gd", p = {}, v = 1, cast = true, col = 0.45, tree = true },
	chestnut = { s = "big_tree.gd", p = { variant = "chestnut" }, v = 1, cast = true, col = 0.45, tree = true },
	# 마을 생활 식생(§8): 텃밭·호박 넝쿨·마당 가 짧은 풀. mg = 제외 구역(건물·마당) 여유(m)
	garden = { s = "garden_plot.gd", p = { w = 6.0, d = 4.0 }, v = 2, cast = false, col = 0.0, mg = 3.7 },
	pumpkin = { s = "pumpkin_vine.gd", p = {}, v = 1, cast = false, col = 0.0, mg = 0.6 },
	cover_yard = { s = "cover.gd", p = { kind = "yard" }, v = 1, cast = false, col = 0.0 },
	bamboo = { s = "bamboo.gd", p = {}, v = 2, cast = true, col = 1.2, tree = true },
	# 어린나무: 원거리(LOD1) 메시를 작게(0.4~0.6배) — 숲 바닥을 싸게 메운다. 그림자·충돌 없음
	sapling_pine = { s = "pine.gd", p = {}, flod = 1, v = 2, cast = false, col = 0.0 },
	sapling_oak = { s = "oak.gd", p = { kind = "sangsuri" }, flod = 1, v = 2, cast = false, col = 0.0 },
	sapling_singal = { s = "oak.gd", p = { kind = "singal" }, flod = 1, v = 1, cast = false, col = 0.0 },
	sapling_gusang = { s = "korean_fir.gd", p = {}, flod = 1, v = 2, cast = false, col = 0.0 },
	# 숲 밑 덤불: 같은 덤불을 1.2~2배로 크게(배율은 삼각형이 들지 않으니 바닥을 싸게 덮는다)
	undergrowth = { s = "bush.gd", p = {}, v = 2, cast = false, col = 0.0 },
	bush = { s = "bush.gd", p = {}, v = 3, cast = false, col = 0.0 },
	jindallae = { s = "azalea.gd", p = { kind = "jindallae" }, v = 1, cast = false, col = 0.0 },
	cheoljjuk = { s = "azalea.gd", p = { kind = "cheoljjuk" }, v = 1, cast = false, col = 0.0 },
	rock = { s = "rock.gd", p = { s = 0.7 }, v = 3, cast = false, col = 0.6, far_skip = true },
	rock_big = { s = "rock.gd", p = { s = 1.5, mossy = false }, v = 1, cast = true, col = 1.25 },
	boulder = { s = "boulder.gd", p = { s = 2.2 }, v = 3, cast = true, col = -1.0 },
	cliff = { s = "cliff.gd", p = {}, v = 2, cast = true, col = -1.0 },
	slab = { s = "slab_rock.gd", p = {}, v = 1, cast = true, col = 0.0 },
	stones = { s = "stream_stones.gd", p = {}, v = 1, cast = false, col = 0.0, far_skip = true },
	rice = { s = "rice_tuft.gd", p = { patch = 4, spacing = 1.0 }, v = 1, cast = false, col = 0.0 },
	crop_bean = { s = "crop.gd", p = { kind = "bean", len = 3.6 }, v = 1, cast = false, col = 0.0, far_skip = true },
	crop_millet = { s = "crop.gd", p = { kind = "millet", len = 3.6 }, v = 1, cast = false, col = 0.0, far_skip = true },
	crop_barley = { s = "crop.gd", p = { kind = "barley", len = 3.6 }, v = 1, cast = false, col = 0.0, far_skip = true },
	cover_meadow = { s = "cover.gd", p = { kind = "meadow" }, v = 2, cast = false, col = 0.0, far_skip = true },
	cover_forest = { s = "cover.gd", p = { kind = "forest" }, v = 1, cast = false, col = 0.0, far_skip = true },
	cover_alpine = { s = "cover.gd", p = { kind = "alpine" }, v = 1, cast = false, col = 0.0, far_skip = true },
	cover_riverside = { s = "cover.gd", p = { kind = "riverside" }, v = 1, cast = false, col = 0.0 },
	cover_sandbar = { s = "cover.gd", p = { kind = "sandbar" }, v = 1, cast = false, col = 0.0, far_skip = true },
	cover_rocky = { s = "cover.gd", p = { kind = "rocky" }, v = 1, cast = false, col = 0.0, far_skip = true },
}
# 크기 배율 범위
const SCALE := {
	pine = [1.05, 1.45], fir = [1.0, 1.35], sangsuri = [1.0, 1.35], singal = [0.9, 1.25], gusang = [0.9, 1.3], deadwood = [0.8, 1.2], snag = [0.8, 1.3],
	zelkova = [0.95, 1.1], willow = [0.9, 1.15], broadleaf = [0.85, 1.1], persimmon = [0.85, 1.1], chestnut = [0.85, 1.15], garden = [1.0, 1.0], pumpkin = [0.8, 1.2], bamboo = [0.85, 1.15],
	bush = [0.7, 1.2], undergrowth = [1.6, 2.6], sapling_pine = [0.4, 0.6], sapling_oak = [0.4, 0.6], sapling_singal = [0.4, 0.6], sapling_gusang = [0.45, 0.65], jindallae = [0.7, 1.15], cheoljjuk = [0.7, 1.2], rock = [0.6, 1.3], rock_big = [0.8, 1.3], boulder = [0.75, 1.3], cliff = [0.8, 1.2], slab = [0.8, 1.2],
	stones = [0.8, 1.2], rice = [1.0, 1.0], crop_bean = [1.0, 1.0], crop_millet = [1.0, 1.0], crop_barley = [1.0, 1.0],
}

static var _cache := {}
static var _mtx := Mutex.new()
static var _names: PackedStringArray
static var _ids := {}
static var _kv := PackedInt32Array()
static var _kcol := PackedFloat32Array()
static var _ktree := PackedByteArray()
static var _kfar := PackedByteArray()
static var _ks0 := PackedFloat32Array()
static var _ks1 := PackedFloat32Array()
static var _kmg := PackedFloat32Array()

static func _init_tables() -> void:
	_mtx.lock()
	if _names.is_empty():
		var names := PackedStringArray(KINDS.keys())
		for i in names.size():
			var n := names[i]
			var sp: Dictionary = KINDS[n]
			_ids[n] = i
			_kv.append(int(sp.v)); _kcol.append(float(sp.col))
			_ktree.append(1 if sp.get("tree", false) else 0); _kfar.append(1 if sp.get("far_skip", false) else 0)
			var sr: Array = SCALE.get(n, [0.8, 1.25])
			_ks0.append(sr[0]); _ks1.append(sr[1]); _kmg.append(float(sp.get("mg", -1.0)))
		_names = names
	_mtx.unlock()

static func kid(name: String) -> int:
	return _ids[name]

# ---------------------------------------------------------------------------
# 모델 메시 캐시 (종류·변형·LOD) — 처음 한 번 GDScript로 만든다. 스레드에서 불릴 수 있어 잠근다.
# ---------------------------------------------------------------------------
static func model(kind: String, variant: int, lod: int) -> Dictionary:
	var key := "%s:%d:%d" % [kind, variant, lod]
	_mtx.lock()
	var hit = _cache.get(key)
	_mtx.unlock()
	if hit != null: return hit
	var spec: Dictionary = KINDS[kind]
	var p: Dictionary = (spec.p as Dictionary).duplicate()
	p.seed = 101 + variant * 7919 + kind.hash() % 1000
	p.lod = int(spec.get("flod", lod))   # flod: 어린나무처럼 늘 원거리 메시를 쓰는 종류
	var info: Dictionary = load(N + spec.s).build(p)
	var mesh: ArrayMesh = info.mesh
	var out := { mesh = mesh, arrays = mesh.surface_get_arrays(0), colliders = info.colliders, tris = info.get("tris", 0) }
	(info.node as Node).free()
	_mtx.lock()
	_cache[key] = out
	_mtx.unlock()
	return out

# 모든 종류·변형을 미리 만든다(메인 스레드에서 부르면 Kit 재질·텍스처 생성도 여기서 끝난다). 걸린 시간(µs)
static func warm(lod := 0) -> int:
	_init_tables()
	var t := Time.get_ticks_usec()
	for kind in KINDS:
		for v in int(KINDS[kind].v):
			var tr: bool = KINDS[kind].get("tree", false)
			model(kind, v, lod if tr else 0)
			if tr: model(kind, v, 1)   # 그림자 전용 대리(LOD1)
	return Time.get_ticks_usec() - t

# 해발(m)에 따른 숲 수종 비율 [종류, 가중치] — 지리산 서부: 저지대 소나무·상수리/굴참, 중턱 신갈나무, 1,300m 위 구상나무·고사목
static func forest_mix(alt: float) -> Array:
	if alt < 350.0: return [["pine", 0.8], ["sangsuri", 0.2]]
	if alt < 800.0:
		var t := (alt - 350.0) / 450.0
		return [["pine", lerpf(0.58, 0.33, t)], ["sangsuri", lerpf(0.3, 0.1, t)], ["singal", lerpf(0.12, 0.55, t)]]
	if alt < 1300.0:
		var t := (alt - 800.0) / 500.0
		return [["singal", lerpf(0.6, 0.45, t)], ["pine", lerpf(0.22, 0.05, t)], ["gusang", lerpf(0.0, 0.35, t)], ["deadwood", lerpf(0.0, 0.05, t)]]
	return [["gusang", 0.5], ["singal", 0.3], ["deadwood", 0.15], ["snag", 0.05]]

# forest_mix를 종류 id로 바꿔 50m 단위로 캐시
static var _mix_cache := {}
static func mix_ids(alt: float) -> Array:
	var q := int(alt / 50.0)
	var hit = _mix_cache.get(q)
	if hit != null: return hit
	var out := []
	for m in forest_mix(q * 50.0 + 25.0): out.append([kid(m[0]), m[1]])
	_mtx.lock(); _mix_cache[q] = out; _mtx.unlock()
	return out

static func ids(mix: Array) -> Array:
	var out := []
	for m in mix: out.append([kid(m[0]), m[1]])
	return out

# 칸 거리(체스판 거리, 2-pass, 최대 255) — 두 마스크(a, b)를 한 번에 돈다(루프 비용을 반으로)
static func _dist2(ma: PackedByteArray, mb: PackedByteArray, w: int, h: int) -> Array:
	var da := PackedByteArray(); da.resize(w * h)
	var db := PackedByteArray(); db.resize(w * h)
	for i in w * h:
		da[i] = 0 if ma[i] else 255
		db[i] = 0 if mb[i] else 255
	for j in range(1, h):
		var k := j * w
		for i in range(1, w - 1):
			k = j * w + i
			var va := da[k]; var vb := db[k]
			if va != 0: da[k] = mini(mini(va, da[k - 1] + 1), mini(mini(da[k - w], da[k - w - 1]), da[k - w + 1]) + 1)
			if vb != 0: db[k] = mini(mini(vb, db[k - 1] + 1), mini(mini(db[k - w], db[k - w - 1]), db[k - w + 1]) + 1)
	for j in range(h - 2, -1, -1):
		for i in range(w - 2, 0, -1):
			var k := j * w + i
			var va := da[k]; var vb := db[k]
			if va != 0: da[k] = mini(mini(va, da[k + 1] + 1), mini(mini(da[k + w], da[k + w + 1]), da[k + w - 1]) + 1)
			if vb != 0: db[k] = mini(mini(vb, db[k + 1] + 1), mini(mini(db[k + w], db[k + w + 1]), db[k + w - 1]) + 1)
	return [da, db]

# ---------------------------------------------------------------------------
# 배치 작업 하나(타일 하나). 타입 있는 멤버로 사전 조회를 줄인다.
# ---------------------------------------------------------------------------
class Job:
	var x0 := 0.0
	var z0 := 0.0
	var nch := 2
	var lod := 0
	var hcall: Callable
	var lcall: Callable
	var rng: RandomNumberGenerator   # 엔진 내장 PCG32(같은 seed → 같은 수열). Kit.Rng(GDScript)는 개당 ~1µs라 여기선 너무 느리다
	var groups := {}        # int 키((종류*8+변형)*64+묶음) → Array(12 float/개)
	var colliders := []
	var counts := PackedInt32Array()
	var K_ROAD := 4
	var salt := 0
	var ex_rects: Array[Rect2] = []
	var ex_circles := PackedFloat32Array()   # x, z, r 반복
	var pure := false       # 지금 칸과 네 이웃의 토지이용이 같으면 점마다 다시 묻지 않는다
	var ks0_: PackedFloat32Array
	var ks1_: PackedFloat32Array
	var ktree_: PackedByteArray
	var kfar_: PackedByteArray
	var kcol_: PackedFloat32Array
	var kv_: PackedInt32Array
	var kmg_: PackedFloat32Array
	var names_: PackedStringArray
	var model_fn: Callable

	# 기대 개수 ex만큼(정수부 + 확률) 칸 안 아무 데나
	func emit(k: int, ex: float, cx: float, cz: float, slope: float, r_d: int) -> void:
		var n := _count(ex)
		for q in n:
			var px := cx + (rng.randf() - 0.5) * CELL; var pz := cz + (rng.randf() - 0.5) * CELL
			put(k, px, pz, rng.randf() * TAU, lerpf(ks0_[k], ks1_[k], rng.randf()), slope, r_d, true)

	# 고르게(4×4 베이어 문턱): 확률 대신 칸 위치로 개수를 정해 뭉침·빈터 없이 퍼뜨린다
	var even := -1.0
	func emit_even(k: int, ex: float, cx: float, cz: float, slope: float, r_d: int, bi: int) -> void:
		even = (BAYER[bi] + 0.5) / 16.0
		emit(k, ex, cx, cz, slope, r_d)
		even = -1.0

	func _count(ex: float) -> int:
		var n := int(ex)
		var f := ex - n
		if even >= 0.0:
			if even < f: n += 1
		elif rng.randf() < f: n += 1
		return n

	# 집(제외 사각형) 뒤: 이 점의 남쪽 10m 안에 사각형이 있고 x가 겹치면(북쪽 = -z, 카메라 반대편)
	# 단, 그 점이 어느 exclude 안이나 둘레 2m 안이면, 또는 북쪽 12m 안에 다른 사각형이 있으면(= 그 건물의 앞마당) 아니다
	func behind_house(x: float, z: float) -> bool:
		var pt := Vector2(x, z)
		var hit := false
		for rr in ex_rects:
			if rr.grow(2.0).has_point(pt): return false
			if x > rr.position.x - 2.0 and x < rr.end.x + 2.0:
				if z < rr.position.y and z > rr.position.y - 10.0: hit = true
				elif z > rr.end.y and z < rr.end.y + 12.0: return false   # 이 점의 북쪽에 건물 → 남향 건물의 앞마당
		return hit

	# 울타리 가: 사각형 테두리 바깥 0~4m
	func near_fence(x: float, z: float) -> bool:
		for rr in ex_rects:
			if rr.grow(4.0).has_point(Vector2(x, z)) and not rr.has_point(Vector2(x, z)): return true
		return false

	# 섞인 수종에서 골라 ex개
	func emit_mix(mix: Array, ex: float, cx: float, cz: float, slope: float, r_d: int, bi := -1) -> void:
		if bi >= 0: even = (BAYER[bi] + 0.5) / 16.0
		var n := _count(ex)
		even = -1.0
		for q in n:
			var px := cx + (rng.randf() - 0.5) * CELL; var pz := cz + (rng.randf() - 0.5) * CELL
			var u := rng.randf()
			var tot := 0.0
			for m in mix: tot += float(m[1])
			var a := u * tot
			var k: int = mix[mix.size() - 1][0]
			for m in mix:
				a -= float(m[1])
				if a <= 0.0:
					k = m[0]
					break
			put(k, px, pz, rng.randf() * TAU, lerpf(ks0_[k], ks1_[k], rng.randf()), slope, r_d, true)

	# 하나 놓기: 길 가장자리 정밀 검사 → 높이 → 변환 → 묶음에 추가 → 충돌체
	func put(k: int, px: float, pz: float, ry: float, sc: float, slope: float, r_d: int, check: bool, sink := -999.0) -> bool:
		var tree := ktree_[k] == 1
		if lod >= 1 and kfar_[k] == 1: return false
		# 타일 밖으로 지터된 것은 버림(이웃 타일과 겹치지 않게)
		if px < x0 or pz < z0 or px >= x0 + nch * CHUNK or pz >= z0 + nch * CHUNK: return false
		if check:
			# 길 옆 칸(1칸 안)이면 실제 점과 둘레가 길이 아닌지 본다. 나무는 점 자체의 토지이용도 확인
			if r_d <= 1:
				var cl := maxf(3.0, 1.0 + 2.0 * sc) if tree else (0.7 if kcol_[k] == 0.0 else 1.4)
				if int(lcall.call(px, pz)) == K_ROAD: return false
				if int(lcall.call(px + cl, pz)) == K_ROAD or int(lcall.call(px - cl, pz)) == K_ROAD: return false
				if int(lcall.call(px, pz + cl)) == K_ROAD or int(lcall.call(px, pz - cl)) == K_ROAD: return false
			if tree and not pure:
				var lp := int(lcall.call(px, pz))
				if lp == 4 or lp == 5 or lp == 2: return false
		if not ex_rects.is_empty() or not ex_circles.is_empty():
			# 제외 구역 안(나무는 수관이 걸치지 않게 2m, 큰 바위·벼랑 1.5m, 나머지 0.3m 여유)이면 놓지 않는다
			var mg := kmg_[k] if kmg_[k] >= 0.0 else (2.0 if tree else (1.5 if (kcol_[k] >= 1.0 or kcol_[k] < 0.0) else 0.3))
			var pt := Vector2(px, pz)
			for rr in ex_rects:
				if rr.grow(mg).has_point(pt): return false
			for q in range(0, ex_circles.size(), 3):
				var dx := px - ex_circles[q]; var dz := pz - ex_circles[q + 1]; var lim := ex_circles[q + 2] + mg
				if dx * dx + dz * dz < lim * lim: return false
		var y: float = hcall.call(px, pz)
		if sink <= -999.0:   # 기본: 경사·종류로 자동
			sink = 0.05 + minf(slope, 1.5) * (0.25 if tree else 0.12) * sc
			if kcol_[k] >= 1.0: sink += 0.3 * sc
		y -= sink
		var c := cos(ry) * sc; var s := sin(ry) * sc
		var ci := clampi(int((px - x0) / CHUNK), 0, nch - 1); var cj := clampi(int((pz - z0) / CHUNK), 0, nch - 1)
		# 변형은 묶음마다 하나(그리기 호출 절약) — 이웃 묶음끼리는 다른 변형이 나오게
		var ch := cj * nch + ci
		var nv := kv_[k]
		var v := (k * 7 + ch * 13 + salt) % nv if nv > 1 else 0
		var key := (k * 8 + v) * 64 + ch
		var arr = groups.get(key)
		if arr == null:
			arr = []
			groups[key] = arr
		# MultiMesh 버퍼: 기저 행 우선 3×4
		# 나무는 수관을 가로로 더 넓힌다(삼각형 없이 숲을 덮는 면적을 키움, 가로 HWIDE배·세로 그대로)
		var hw := HWIDE if tree else 1.0
		(arr as Array).append_array([c * hw, 0.0, s * hw, px, 0.0, sc, 0.0, y, -s * hw, 0.0, c * hw, pz])
		counts[k] += 1
		var cr := kcol_[k]
		if cr > 0.0:
			colliders.append({ type = "circle", x = px, z = pz, r = cr * sc })
		elif cr < 0.0:
			var m: Dictionary = model_fn.call(names_[k], v, lod if tree else 0)
			for cc in m.colliders:
				if cc.type != "circle": continue
				# 로컬(x,z) → 월드: y축 회전 ry, 배율 sc (x' = cos·x + sin·z, z' = -sin·x + cos·z)
				var lx: float = cc.x; var lz: float = cc.z
				colliders.append({ type = "circle", x = px + c * lx + s * lz, z = pz - s * lx + c * lz, r = float(cc.r) * sc })
		return true

# ---------------------------------------------------------------------------
static func scatter(tile_rect: Rect2, height_at: Callable, landuse_at: Callable, seed: int, lod: int, exclude: Array = []) -> Dictionary:
	_init_tables()
	var t0 := Time.get_ticks_usec()
	var x0 := tile_rect.position.x; var z0 := tile_rect.position.y
	var nx := int(ceil(tile_rect.size.x / CELL)); var nz := int(ceil(tile_rect.size.y / CELL))
	var W := nx + PAD * 2; var H := nz + PAD * 2
	var gx0 := x0 - PAD * CELL; var gz0 := z0 - PAD * CELL
	# 1) 격자 표본: 토지이용·높이 (칸 중심)
	var lu := PackedByteArray(); lu.resize(W * H)
	var hg := PackedFloat32Array(); hg.resize(W * H)
	var road := PackedByteArray(); road.resize(W * H)
	var water := PackedByteArray(); water.resize(W * H)
	var land := PackedByteArray(); land.resize(W * H)
	var vil := PackedByteArray(); vil.resize(W * H)
	for j in H:
		var cz := gz0 + (j + 0.5) * CELL
		for i in W:
			var cx := gx0 + (i + 0.5) * CELL
			var k := j * W + i
			var l := int(landuse_at.call(cx, cz))
			lu[k] = l
			if (i % 2 == 0 and j % 2 == 0) or i == W - 1 or j == H - 1: hg[k] = height_at.call(cx, cz)
			if l == 4: road[k] = 1
			elif l == 5: water[k] = 1
			elif l == 6: vil[k] = 1
			if l != 5: land[k] = 1
	var t_sample := Time.get_ticks_usec() - t0
	# 높이는 짝수 칸(8m 간격)만 묻고 나머지는 이웃 평균(경사·해발 판정용이라 충분)
	for j in range(0, H - 1):
		for i in range(0, W - 1):
			if i % 2 == 0 and j % 2 == 0: continue
			var k := j * W + i
			if j % 2 == 0: hg[k] = (hg[k - 1] + hg[k + 1]) * 0.5
			elif i % 2 == 0: hg[k] = (hg[k - W] + hg[k + W]) * 0.5
	for j in range(1, H - 1, 2):
		for i in range(1, W - 1, 2):
			var k := j * W + i
			hg[k] = (hg[k - 1] + hg[k + 1]) * 0.5
	var dd := _dist2(road, water, W, H)
	var rd: PackedByteArray = dd[0]
	var wd: PackedByteArray = dd[1]
	var t_grid := Time.get_ticks_usec() - t0

	# 2) 배치
	var J := Job.new()
	J.x0 = x0; J.z0 = z0; J.lod = lod; J.hcall = height_at; J.lcall = landuse_at
	J.nch = int(ceil(tile_rect.size.x / CHUNK))
	J.rng = RandomNumberGenerator.new()
	J.rng.seed = hash([seed, roundi(x0), roundi(z0)])
	J.rng.state = 0x2545F4914F6CDD1D ^ J.rng.seed
	J.salt = absi(seed + roundi(x0 / 256.0) * 3 + roundi(z0 / 256.0) * 5) % 97
	J.counts.resize(_names.size())
	# 제외 구역(건물·광장): 월드 xz Rect2 또는 {x, z, r}. 타일(+8m)에 걸치는 것만 남긴다
	var big := tile_rect.grow(8.0)
	for e in exclude:
		if e is Rect2:
			if (e as Rect2).intersects(big): J.ex_rects.append(e)
		elif e is Dictionary:
			var ex: float = e.x; var ez: float = e.z; var er: float = e.r
			if big.grow(er).has_point(Vector2(ex, ez)): J.ex_circles.append_array([ex, ez, er])
	J.ks0_ = _ks0; J.ks1_ = _ks1; J.ktree_ = _ktree; J.kfar_ = _kfar; J.kcol_ = _kcol; J.kv_ = _kv; J.kmg_ = _kmg; J.names_ = _names
	J.model_fn = model
	var rng := J.rng
	var crop_axis := 0.0 if rng.randf() < 0.5 else PI / 2
	var zelkova_done := false
	var k_cyard := kid("cover_yard"); var k_chest := kid("chestnut"); var k_pump := kid("pumpkin"); var k_garden := kid("garden")
	var k_under := kid("undergrowth"); var k_bush := kid("bush"); var k_jin := kid("jindallae"); var k_cheol := kid("cheoljjuk"); var k_rock := kid("rock"); var k_rockb := kid("rock_big")
	var k_cf := kid("cover_forest"); var k_cm := kid("cover_meadow"); var k_ca := kid("cover_alpine"); var k_cr := kid("cover_riverside")
	var k_cs := kid("cover_sandbar"); var k_ck := kid("cover_rocky"); var k_snag := kid("snag"); var k_stones := kid("stones"); var k_slab := kid("slab")
	var k_pers := kid("persimmon"); var k_broad := kid("broadleaf"); var k_zel := kid("zelkova"); var k_cliff := kid("cliff"); var k_boul := kid("boulder")
	var k_pine := kid("pine"); var k_gus := kid("gusang"); var k_dead := kid("deadwood"); var k_wil := kid("willow"); var k_bam := kid("bamboo"); var k_rice := kid("rice")
	# 원거리(lod1) 타일은 나무 0.6배, 덤불 0.5배
	var tree_k := 1.0 if lod == 0 else 0.6
	var bush_k := 1.0 if lod == 0 else 0.5
	var sap_lo := ids([["sapling_pine", 1.0]])   # 묶음당 종류 수(그리기 호출)를 아끼려 한 가지씩
	var sap_hi := ids([["sapling_gusang", 1.0]])
	var gtree_lo := ids([["pine", 0.5], ["sangsuri", 0.3], ["broadleaf", 0.2]])
	var gtree_hi := ids([["singal", 0.6], ["pine", 0.25], ["deadwood", 0.15]])
	var k_crops := [kid("crop_bean"), kid("crop_millet"), kid("crop_barley")]

	for j in range(PAD, PAD + nz):
		for i in range(PAD, PAD + nx):
			var k := j * W + i
			var l := lu[k]
			if l == 4: continue
			var cx := gx0 + (i + 0.5) * CELL; var cz := gz0 + (j + 0.5) * CELL
			var alt := hg[k] / K + 60.0
			var gxv := (hg[k + 1] - hg[k - 1]) / (2.0 * CELL); var gzv := (hg[k + W] - hg[k - W]) / (2.0 * CELL)
			var slope := sqrt(gxv * gxv + gzv * gzv)   # tan(경사각)
			var r_d := rd[k]; var w_d := wd[k]
			# 길 북쪽(카메라 반대편, -z) 12m 안에 길이 있으면 이 칸의 큰 나무는 길을 가린다 → 나무 대신 낮은 것(§32 시각 간격)
			var road_n := road[k - W] == 1   # 3단계: 바로 북쪽 칸(4m)에 길이 있을 때만 — 길 3m 밖부터 빽빽하게
			# 나무: 길 칸 바로 옆(1칸)도 허용하되 put()이 줄기에서 3m 안에 길이 있으면 버린다
			var tree_ok := r_d >= 1 and not road_n and w_d >= 1
			J.pure = lu[k - 1] == l and lu[k + 1] == l and lu[k - W] == l and lu[k + W] == l
			match l:
				0: # 숲
					# 3단계: 큰 나무 0.22/칸으로 되올리고, 어린나무·덤불·덮개로 바닥을 메운다(길 3m 밖부터 빽빽)
					if tree_ok: J.emit_mix(mix_ids(alt), (0.28 if slope < 1.0 else 0.18) * tree_k, cx, cz, slope, r_d, (j % 4) * 4 + (i % 4))
					if r_d >= 1: J.emit_mix(sap_lo if alt < 800.0 else sap_hi, 0.05 * bush_k, cx, cz, slope, r_d)
					if not tree_ok and r_d >= 1: 
						J.emit(k_bush, 0.3, cx, cz, slope, r_d)
						J.emit(k_cf, 0.18, cx, cz, slope, r_d)
					# 큰 나무를 줄인 빈자리는 덤불·풀로 채운다(2단계: 숲 삼각형 절반 이하)
					J.emit_even(k_under, 0.22 * bush_k, cx, cz, slope, r_d, ((j + 2) % 4) * 4 + ((i + 1) % 4))
					J.emit(k_jin if alt < 900.0 else k_cheol, (0.02 if alt < 900.0 else 0.05) * bush_k, cx, cz, slope, r_d)
					J.emit(k_cf, 0.05, cx, cz, slope, r_d)
					J.emit(k_rock, 0.05 + (0.12 if slope > 0.8 else 0.0), cx, cz, slope, r_d)
					if alt > 600.0 and alt < 1300.0: J.emit(k_snag, 0.012, cx, cz, slope, r_d)
				1: # 풀밭·초지
					if tree_ok: J.emit_mix(gtree_lo if alt < 800.0 else gtree_hi, 0.03, cx, cz, slope, r_d)
					J.emit(k_bush, 0.07, cx, cz, slope, r_d)
					J.emit(k_rock, 0.03, cx, cz, slope, r_d)
					if alt > 850.0: 
						J.emit(k_cheol, 0.22, cx, cz, slope, r_d)
						J.emit(k_ca, 0.35, cx, cz, slope, r_d)
					else: J.emit(k_cm, 0.45, cx, cz, slope, r_d)
				2: # 논 — 칸마다 벼 4×4 포기(1m 간격, 칸 가득 → 줄이 이어짐)
					_rice(J, lu, W, i, j, cx, cz, k_rice)
					continue
				3: # 밭 — 고랑 작물 약간 + 가장자리 덤불
					var ck: int = k_crops[int((Kit.vnoise(cx * 0.02, cz * 0.02) * 0.5 + 0.5) * 2.99)]
					if rng.randf() < 0.55: J.put(ck, cx + (rng.randf() - 0.5) * 0.4, cz + (rng.randf() - 0.5) * 1.2, crop_axis, 1.0, 1.0, r_d, false)
					if rng.randf() < 0.35: J.put(ck, cx + (rng.randf() - 0.5) * 0.4, cz + 1.3 + (rng.randf() - 0.5) * 0.3, crop_axis, 1.0, 1.0, r_d, false)
					J.emit(k_bush, 0.015, cx, cz, slope, r_d)
				5: # 물 — 기슭 가까이 여울 돌, 산골 개울엔 너럭바위
					if land[k - 1] == 1 or land[k + 1] == 1 or land[k - W] == 1 or land[k + W] == 1:
						J.emit(k_stones, 0.35 if (slope > 0.12 or alt > 300.0) else 0.12, cx, cz, slope, r_d)
						if alt > 250.0: J.emit(k_slab, 0.04, cx, cz, slope, r_d)
				6: # 마을 터 — 생활 식생(§8). 건물·마당·길은 exclude가 비운다
					var behind := J.behind_house(cx, cz)
					var fence := J.near_fence(cx, cz)
					J.emit(k_cyard, 0.8, cx, cz, slope, r_d)
					if behind:
						# 집 뒤: 대숲·감나무·밤나무
						if tree_ok:
							J.emit(k_bam, 0.25, cx, cz, slope, r_d)
							J.emit(k_pers, 0.15, cx, cz, slope, r_d)
							J.emit(k_chest, 0.08, cx, cz, slope, r_d)
					elif tree_ok:
						J.emit(k_pers, 0.05, cx, cz, slope, r_d)
						J.emit(k_chest, 0.02, cx, cz, slope, r_d)
					if fence:
						# 울타리·담 따라 덤불·호박 넝쿨
						J.emit(k_bush, 0.4, cx, cz, slope, r_d)
						J.emit(k_pump, 0.25, cx, cz, slope, r_d)
					# 텃밭: 축에 맞춰(0°/90°), 길에서 8m 밖
					if r_d >= 2 and rng.randf() < (0.18 if behind or fence else 0.06):
						var gx := cx + (rng.randf() - 0.5) * 2.0; var gz := cz + (rng.randf() - 0.5) * 2.0
						var rot := rng.randf() < 0.6
						# 흙판이 지형에 묻히지 않게 네 귀퉁이 중 가장 높은 곳에 맞춘다(sink 음수 = 올림)
						var hw0 := 3.15 if rot else 2.15; var hd0 := 2.15 if rot else 3.15
						var yc: float = J.hcall.call(gx, gz)
						var ym := yc
						for o in [Vector2(-hw0, -hd0), Vector2(hw0, -hd0), Vector2(-hw0, hd0), Vector2(hw0, hd0)]:
							ym = maxf(ym, float(J.hcall.call(gx + o.x, gz + o.y)))
						if J.put(k_garden, gx, gz, 0.0 if rot else PI / 2, 1.0, slope, r_d, true, yc - ym - 0.02):
							# 놓인 텃밭 자리는 뒤에 오는 것들이 피하게 제외 구역에 더한다
							var hw := 3.15 if rot else 2.15; var hd := 2.15 if rot else 3.15
							J.ex_rects.append(Rect2(gx - hw, gz - hd, hw * 2, hd * 2))
					if _edge(vil, W, k):
						J.emit(k_bush, 0.06, cx, cz, slope, r_d)
						if not zelkova_done and tree_ok and r_d <= 4 and rng.randf() < 0.08:
							# 어귀 느티나무: 타일마다 최대 한 그루
							zelkova_done = true
							J.emit(k_zel, 1.0, cx, cz, slope, r_d)
				7: # 바위·벼랑
					if slope > 0.7 and r_d >= 3 and rng.randf() < 0.07:
						var ry := atan2(-gxv, -gzv)   # 정면(+z)을 내리막으로
						J.put(k_cliff, cx + (rng.randf() - 0.5) * 2, cz + (rng.randf() - 0.5) * 2, ry, lerpf(0.8, 1.2, rng.randf()), slope, r_d, false, 0.4 + slope * 1.2)
					J.emit(k_boul, 0.04, cx, cz, slope, r_d)
					J.emit(k_rockb, 0.07, cx, cz, slope, r_d)
					J.emit(k_rock, 0.2, cx, cz, slope, r_d)
					J.emit(k_ck, 0.07, cx, cz, slope, r_d)
					if tree_ok:
						J.emit(k_pine if alt < 1100.0 else k_gus, 0.07, cx, cz, slope, r_d)
						if alt > 1000.0: J.emit(k_dead, 0.04, cx, cz, slope, r_d)
				8: # 모래톱·자갈
					J.emit(k_cs, 0.3, cx, cz, slope, r_d)
					J.emit(k_stones, 0.06, cx, cz, slope, r_d)
					if w_d <= 1: J.emit(k_cr, 0.15, cx, cz, slope, r_d)
					if tree_ok: J.emit(k_wil, 0.005, cx, cz, slope, r_d)
				9: # 대숲
					if r_d >= 1 and w_d >= 1: J.emit(k_bam, (0.35 if r_d >= 2 else 0.15) * tree_k, cx, cz, slope, r_d)
					J.emit(k_cf, 0.08, cx, cz, slope, r_d)
			# 물가(땅 칸): 갈대·버드나무, 산골이면 너럭바위·큰 바위
			if l != 5 and l != 8 and w_d >= 1 and w_d <= 2:
				var mountain := alt > 300.0 or slope > 0.25
				if mountain:
					J.emit(k_boul, 0.04, cx, cz, slope, r_d)
					if w_d == 1: 
						J.emit(k_slab, 0.05, cx, cz, slope, r_d)
						J.emit(k_stones, 0.08, cx, cz, slope, r_d)
				else:
					J.emit(k_cr, 0.4 if w_d == 1 else 0.15, cx, cz, slope, r_d)
					if tree_ok and l != 3: J.emit(k_wil, 0.05, cx, cz, slope, r_d)
			# 마을 뒤(북쪽) 대밭: 마을이 남쪽 1~3칸 안
			if (l == 0 or l == 1) and tree_ok and (vil[k + W] == 1 or vil[k + 2 * W] == 1 or vil[k + 3 * W] == 1):
				J.emit(k_bam, 0.18, cx, cz, slope, r_d)
	var t_place := Time.get_ticks_usec() - t0 - t_grid

	# 3) 묶기: 묶음마다 개수 많은 종류 MAX_MM개는 MultiMesh, 나머지 드문 것은 정적 메시 하나로 합친다
	var by_chunk := {}
	for key in J.groups:
		var ch: int = key % 64
		if not by_chunk.has(ch): by_chunk[ch] = []
		by_chunk[ch].append(key)
	var nodes := []
	var buffers := []     # nodes와 같은 순서: MultiMeshInstance3D면 그 버퍼(PackedFloat32Array, 12 float/개), 합친 메시면 null
	var chunks := by_chunk.keys(); chunks.sort()
	var merged_inst := 0
	var tris_main := 0; var tris_shadow := 0
	for ch in chunks:
		var keys: Array = by_chunk[ch]
		keys.sort_custom(func(a, b):
			var na: int = J.groups[a].size(); var nb: int = J.groups[b].size()
			return na > nb or (na == nb and a < b))
		var rest_cast := []; var rest_flat := []
		for idx in keys.size():
			var key: int = keys[idx]
			var kk := key / 64 / 8; var v := (key / 64) % 8
			var tree := _ktree[kk] == 1
			var cast: bool = KINDS[_names[kk]].cast
			var m := model(_names[kk], v, lod if tree else 0)
			var n_inst: int = J.groups[key].size() / 12
			var mtris: int = m.tris
			var verts: int = n_inst * (m.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if idx >= MAX_MM and n_inst <= MERGE_MAX and verts <= MERGE_VERTS:
				(rest_cast if cast else rest_flat).append([m, J.groups[key]])
				merged_inst += n_inst
				tris_main += n_inst * mtris
				if cast: tris_shadow += n_inst * mtris
				continue
			var buf := PackedFloat32Array(J.groups[key])
			var mmi := _mmi(m.mesh, buf, "%s_v%d_c%d" % [_names[kk], v, ch])
			tris_main += n_inst * mtris
			if tree and cast and lod == 0:
				# 나무: 본 그림은 그림자를 끄고, 같은 버퍼로 LOD1 메시를 그림자 전용으로(그림자 패스 삼각형 ≈1/7)
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var sm := model(_names[kk], v, 1)
				var smi := _mmi(sm.mesh, buf, "%s_v%d_c%d_shadow" % [_names[kk], v, ch])
				smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				nodes.append(mmi); buffers.append(buf)
				nodes.append(smi); buffers.append(buf)
				tris_shadow += n_inst * int(sm.tris)
				continue
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if cast: tris_shadow += n_inst * mtris
			nodes.append(mmi); buffers.append(buf)
		for pair in [[rest_cast, true], [rest_flat, false]]:
			if (pair[0] as Array).is_empty(): continue
			var mi := MeshInstance3D.new()
			mi.name = "merged_c%d%s" % [ch, "" if pair[1] else "_noshadow"]
			mi.mesh = _merge(pair[0])
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pair[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			nodes.append(mi); buffers.append(null)
	var total := Time.get_ticks_usec() - t0
	var counts := {}
	for i in _names.size():
		if J.counts[i] > 0: counts[_names[i]] = J.counts[i]
	return { nodes = nodes, buffers = buffers, colliders = J.colliders, stats = { tris_main = tris_main, tris_shadow = tris_shadow, usec = total, grid_usec = t_grid, sample_usec = t_sample, place_usec = t_place, counts = counts, draw_nodes = nodes.size(), merged_instances = merged_inst } }

static func _mmi(mesh: Mesh, buf: PackedFloat32Array, name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = buf.size() / 12
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	return mmi

# 드문 것들을 한 메시로: 캐시한 표면 배열을 인스턴스 변환으로 옮겨 이어 붙인다(엔진 내장 배열 연산이라 빠르다)
static func _merge(items: Array) -> ArrayMesh:
	var V := PackedVector3Array(); var Nn := PackedVector3Array(); var U := PackedVector2Array(); var Cc := PackedColorArray()
	for it in items:
		var arrays: Array = it[0].arrays
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nrms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var b: Array = it[1]
		for q in range(0, b.size(), 12):
			var basis := Basis(Vector3(b[q], b[q + 4], b[q + 8]), Vector3(b[q + 1], b[q + 5], b[q + 9]), Vector3(b[q + 2], b[q + 6], b[q + 10]))
			V.append_array(Transform3D(basis, Vector3(b[q + 3], b[q + 7], b[q + 11])) * verts)
			Nn.append_array(Transform3D(basis.orthonormalized(), Vector3.ZERO) * nrms)
			U.append_array(uvs); Cc.append_array(cols)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V; arr[Mesh.ARRAY_NORMAL] = Nn; arr[Mesh.ARRAY_TEX_UV] = U; arr[Mesh.ARRAY_COLOR] = Cc
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, Kit.material("atlas"))
	return am

static func _edge(mask: PackedByteArray, W: int, k: int) -> bool:
	return mask[k - 1] == 0 or mask[k + 1] == 0 or mask[k - W] == 0 or mask[k + W] == 0

# 벼: 칸 하나에 4×4 포기. 논 가장자리 칸은 네 귀퉁이가 다 논일 때만
static func _rice(J: Job, lu: PackedByteArray, W: int, i: int, j: int, cx: float, cz: float, k_rice: int) -> void:
	var k := j * W + i
	if lu[k - 1] != 2 or lu[k + 1] != 2 or lu[k - W] != 2 or lu[k + W] != 2:
		for o in [Vector2(-1.6, -1.6), Vector2(1.6, -1.6), Vector2(-1.6, 1.6), Vector2(1.6, 1.6)]:
			if int(J.lcall.call(cx + o.x, cz + o.y)) != 2: return
	J.put(k_rice, cx, cz, 0.0, 1.0, 0.0, 255, false)
