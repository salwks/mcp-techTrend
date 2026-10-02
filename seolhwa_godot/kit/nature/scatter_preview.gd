# 흩뿌리기 미리보기: 가짜 높이·토지이용으로 256m 타일 하나를 만들고 scatter()로 채운다.
#   godot --path . res://scenes/kit_preview.tscn -- --scene=res://kit/nature/scatter_preview.gd --ground=0 --shot=shots/kit/nature/scatter_overview.png --pitch=55
#   게임 시점: ... --fit=0 --focus=-20,10 --dist=23 --pitch=35
# 추가 인자: --alt=해발(m, 타일 남쪽 기준, 기본 120) --lod=0|1 --seed=7 --focus=x,z(그 점을 원점으로 옮김)
# 생성 시간(차가운/데운 캐시)·결정성·그리기 호출 수를 콘솔에 찍는다(SCATTER …).
extends RefCounted
const Scatter := preload("res://kit/nature/scatter.gd")

const RES := 1.0   # 높이 격자(m)
const LRES := 2.0  # 토지이용 격자(m)

static func _args() -> Dictionary:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--").split("=", true, 1)
		a[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return a

class Fake:
	var x0 := -128.0
	var z0 := -128.0
	var n := 257 + 40      # 타일 + 둘레 20m
	var h := PackedFloat32Array()
	var ln := 0
	var lu := PackedByteArray()
	var base := 0.0

	func river_z(x: float) -> float: return 18.0 + sin(x * 0.025) * 14.0
	func road_x(z: float) -> float: return -18.0 + sin(z * 0.03) * 16.0

	func setup(alt: float) -> void:
		base = (alt - 60.0) * 0.3
		var o := -20.0
		h.resize(n * n)
		for j in n:
			var z := z0 + o + j * RES
			for i in n:
				var x := x0 + o + i * RES
				var y := Kit.fbm(x * 0.012, z * 0.012, 3) * 6.0
				var m := clampf((-z - 5.0) / 120.0, 0.0, 1.0)   # 북쪽으로 산
				y += m * m * 70.0 + m * Kit.fbm(x * 0.03 + 5.0, z * 0.03, 3) * 14.0
				var dr := absf(z - river_z(x))
				y -= maxf(0.0, 6.0 - dr) * 0.35                # 냇바닥
				if z > 34.0: y = lerpf(y, -0.5 + Kit.fbm(x * 0.01, z * 0.01, 2) * 1.0, clampf((z - 34.0) / 10.0, 0, 1))  # 남쪽 들
				h[j * n + i] = base + y
		ln = int((n - 1) * RES / LRES) + 1
		lu.resize(ln * ln)
		for j in ln:
			var z := z0 + o + j * LRES
			for i in ln:
				var x := x0 + o + i * LRES
				lu[j * ln + i] = classify(x, z)

	func classify(x: float, z: float) -> int:
		var rz := river_z(x)
		var dr := z - rz
		if absf(dr) < 4.0: return 5
		if absf(x - road_x(z)) < 2.2 and z > -110.0: return 4
		if absf(dr) < 7.5 and dr < 0 and x > -60 and x < 40: return 8
		var y := height(x, z) - base
		var sl := absf(height(x + 2, z) - height(x - 2, z)) / 4.0 + absf(height(x, z + 2) - height(x, z - 2)) / 4.0
		if x > 40 and x < 100 and z > 44 and z < 100: return 6
		if x > 45 and x < 100 and z > 30 and z < 44: return 9
		if z > 40 and x < -30: return 2
		if z > 40 and x > -10 and x < 30: return 3
		if z > 40 and x > -30 and x < -10: return 2 if z > 70 else 1
		if sl > 1.0 or (y > 55 and Kit.vnoise(x * 0.05, z * 0.05) > 0.25): return 7
		if z < -10.0 or (z < 5 and Kit.vnoise(x * 0.04, z * 0.04) > 0.0): return 0
		return 1

	func height(x: float, z: float) -> float:
		var fx := (x - (x0 - 20.0)) / RES; var fz := (z - (z0 - 20.0)) / RES
		var i := clampi(int(fx), 0, n - 2); var j := clampi(int(fz), 0, n - 2)
		var tx := clampf(fx - i, 0, 1); var tz := clampf(fz - j, 0, 1)
		var k := j * n + i
		return lerpf(lerpf(h[k], h[k + 1], tx), lerpf(h[k + n], h[k + n + 1], tx), tz)

	func landuse(x: float, z: float) -> int:
		var i := clampi(int(roundf((x - (x0 - 20.0)) / LRES)), 0, ln - 1); var j := clampi(int(roundf((z - (z0 - 20.0)) / LRES)), 0, ln - 1)
		return lu[j * ln + i]

const LU_COL := [0x7f8f58, 0x9aa86a, 0x8fa48c, 0xa8916a, 0xcdb88a, 0x7f9ea2, 0xc2b08a, 0x9a968a, 0xd6cba8, 0x8a9f5c]

static func ground_mesh(f: Fake) -> Node3D:
	var g := Kit.Geo.new()
	var step := 2.0
	var cnt := int(256.0 / step)
	for j in cnt:
		for i in cnt:
			var x := -128.0 + i * step; var z := -128.0 + j * step
			var a := Vector3(x, f.height(x, z), z); var b := Vector3(x + step, f.height(x + step, z), z)
			var c := Vector3(x + step, f.height(x + step, z + step), z + step); var d := Vector3(x, f.height(x, z + step), z + step)
			# 위를 보는 반시계(three 규칙): d-c-b-a 순서
			g.quad(d, c, b, a)
			var col := Kit.hex(LU_COL[f.landuse(x + step / 2, z + step / 2)])
			for q in 6: g.col[g.col.size() - 6 + q] = col
	var bt := Kit.Batch.new()
	bt.add("mud", g, 0.0)
	return bt.build("가짜지형", false)

static func make() -> Node3D:
	var a := _args()
	var f := Fake.new()
	f.setup(float(a.get("alt", "120")))
	var lod := int(a.get("lod", "0"))
	var seed := int(a.get("seed", "7"))
	var rect := Rect2(-128, -128, 256, 256)
	var hcall := Callable(f, "height"); var lcall := Callable(f, "landuse")
	# 차가운 캐시(모델 메시 생성 포함) → 데운 캐시 두 번(결정성 비교)
	var t := Time.get_ticks_usec()
	var warm_us := Scatter.warm(lod)
	# 제외 구역 시험: --exclude 이면 마을 터 안쪽 사각형 하나 + 원 하나
	var excl := []
	if a.has("exclude"): excl = [Rect2(50, 50, 30, 25), { x = -40.0, z = -45.0, r = 10.0 }]
	# 마을 터에 kit-village 집 묶음(읽기만)을 놓고 그 자리를 exclude로 넘긴다(--nohouses면 생략)
	var houses := []
	if not a.has("nohouses") and not a.has("exclude"):
		for hp in [[52.0, 60.0, "small", 11], [76.0, 58.0, "medium", 12], [58.0, 86.0, "small", 13], [86.0, 84.0, "small", 14]]:
			var info: Dictionary = load("res://kit/village/house_compound.gd").build({ seed = hp[3], size = hp[2] })
			var fp: Vector2 = info.footprint
			(info.node as Node3D).position = Vector3(hp[0], f.height(hp[0], hp[1]), hp[1])
			houses.append(info.node)
			excl.append(Rect2(hp[0] - fp.x / 2, hp[1] - fp.y / 2, fp.x, fp.y))
		# 마을 안 고샅길(동서로 하나)
		excl.append(Rect2(40, 71, 60, 3.5))
	var r1 := Scatter.scatter(rect, hcall, lcall, seed, lod, excl, [])
	var r2 := Scatter.scatter(rect, hcall, lcall, seed, lod, excl, [])
	var same: bool = r1.colliders.size() == r2.colliders.size() and r1.nodes.size() == r2.nodes.size()
	for i in r1.nodes.size():
		if not same: break
		if r1.nodes[i] is MultiMeshInstance3D: same = r1.nodes[i].multimesh.buffer == r2.nodes[i].multimesh.buffer
		else: same = r1.nodes[i].mesh.surface_get_arrays(0)[0] == r2.nodes[i].mesh.surface_get_arrays(0)[0]
	# 다른 타일 하나 더(데운 캐시) — 시간 표본
	var r3 := Scatter.scatter(Rect2(-128, -384, 256, 256), hcall, lcall, seed, lod, [], [])
	var inst := 0; var tris := 0
	for n in r1.nodes:
		if n is MultiMeshInstance3D:
			if n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
			var mm: MultiMesh = n.multimesh
			inst += mm.instance_count
			for s in mm.mesh.get_surface_count(): tris += mm.instance_count * mm.mesh.surface_get_array_len(s) / 3
		else:
			tris += n.mesh.surface_get_array_len(0) / 3
	print("SCATTER warm_models_ms=%.1f tile_ms=%.1f (grid %.1f, place %.1f) tile2_ms=%.1f tile3_ms=%.1f deterministic=%s nodes=%d mm_instances=%d merged_instances=%d tris=%d colliders=%d" % [
		warm_us / 1000.0, r1.stats.usec / 1000.0, r1.stats.grid_usec / 1000.0, r1.stats.place_usec / 1000.0, r2.stats.usec / 1000.0, r3.stats.usec / 1000.0,
		same, r1.nodes.size(), inst, r1.stats.merged_instances, tris, r1.colliders.size()])
	print("SCATTER tris main=%d shadow=%d effective=%d | tile3 main=%d shadow=%d effective=%d | buffers=%d" % [r1.stats.tris_main, r1.stats.tris_shadow, r1.stats.tris_main + r1.stats.tris_shadow, r3.stats.tris_main, r3.stats.tris_shadow, r3.stats.tris_main + r3.stats.tris_shadow, r1.buffers.filter(func(b): return b != null).size()])
	print("SCATTER counts ", r1.stats.counts, " sample_ms=", r1.stats.sample_usec / 1000.0)
	print("SCATTER tile3 (산) grid=%.1f place=%.1f total=%.1f nodes=%d merged=%d counts=%s" % [r3.stats.grid_usec / 1000.0, r3.stats.place_usec / 1000.0, r3.stats.usec / 1000.0, r3.nodes.size(), r3.stats.merged_instances, r3.stats.counts])
	for n in r2.nodes: n.free()
	for n in r3.nodes: n.free()

	var root := Node3D.new()
	root.name = "scatter_preview"
	root.add_child(ground_mesh(f))
	for hn in houses: root.add_child(hn)
	var veg := Node3D.new(); veg.name = "veg"
	root.add_child(veg)
	for n in r1.nodes: veg.add_child(n)
	if a.has("colliders"):
		var b := Kit.Batch.new()
		for c in r1.colliders:
			b.add("flat", Kit.paint(Kit.cyl(c.r, c.r, 0.3, 8, c.x, f.height(c.x, c.z) + 0.2, c.z), Kit.hex(0xd04030)), 0.0)
		root.add_child(b.build("colliders"))
	if a.has("exclude"):   # 제외 구역을 붉은 판으로 표시 (excl_vis)
		var eb := Kit.Batch.new()
		eb.add("flat", Kit.paint(Kit.box(30, 0.2, 25, 65, f.height(65, 62.5) + 0.3, 62.5), Kit.hex(0xc04030)), 0.0)
		eb.add("flat", Kit.paint(Kit.cyl(10, 10, 0.2, 24, -40, f.height(-40, -45) + 0.3, -45), Kit.hex(0xc04030)), 0.0)
		root.add_child(eb.build("excl_vis", false))
	if a.has("focus"):
		var p: PackedStringArray = str(a.focus).split(",")
		var fx := float(p[0]); var fz := float(p[1])
		root.position = -Vector3(fx, f.height(fx, fz), fz)
	# 그리기 호출 측정: 4프레임 뒤 식생 포함, 8프레임 뒤 식생 숨김
	var probe := Node.new()
	var sc := GDScript.new()
	sc.source_code = """extends Node
var veg: Node3D
var f := 0
var a := 0
var b := 0
var sun: DirectionalLight3D
func _process(_d):
	f += 1
	var n := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	if f == 3:
		a = n
		veg.visible = false
	elif f == 5:
		b = n
		veg.visible = true
		var l := get_viewport().find_children('*', 'DirectionalLight3D', true, false)
		if l.size() > 0:
			sun = l[0]
			sun.shadow_enabled = false
	elif f == 7:
		print('SCATTER draw_calls total_with_shadow=%d veg_with_shadow=%d veg_main_pass=%d' % [a, a - b, n - 3])
		if sun: sun.shadow_enabled = true
"""
	sc.reload()
	probe.set_script(sc)
	probe.set("veg", veg)
	root.add_child(probe)
	return root
