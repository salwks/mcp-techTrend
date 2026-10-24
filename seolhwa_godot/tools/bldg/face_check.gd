# 겹친 면(z-fighting) 검사 — 같은 평면(법선 같은 쪽, 거리 차 3mm 안)에 놓여 서로 겹치는 삼각형 짝을 찾는다(헤드리스).
#   godot --headless --path . -s res://tools/bldg/face_check.gd -- [--types=a,b] [--seeds=2] [--interior=both|1|0] [--dbg]
# 실내(벽 안팎 껍질·도배 판·장판·마루·기둥·잘라 보기 껍질)와 바깥을 모두 본다. 먹선 껍질(뒤집힌 감김·먹색)은 뺀다.
# 끝 줄: FACECHECK <이름> pass|FAIL pairs=n … · FACECHECK total fail=n
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const C := preload("res://kit/village/_common.gd")

const DTOL := 0.003
const ATOL := 1e-4   # 겹친 넓이(m²) — 1cm² 넘으면 센다
const BIG := 0.01    # 10cm×10cm 넘게 겹친 짝은 실패(눈에 보이는 깜빡임) — 그보다 작은 짝은 부재 맞춤(속에 묻힌 이음) 조각으로 따로 센다

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var types: PackedStringArray = String(args.get("types", "choga,jumak,sijeon,anchae,sarang,haengrang,sadang,gotgan,araechae,dongheon,gaeksa,daeseong,gangdang,jeongja,nugak,mill,smithy,daeung,giwajip")).split(",")
	var regions: PackedStringArray = String(args.get("regions", "south,central,north,jeju")).split(",")
	var seeds := int(args.get("seeds", "2"))
	var modes: Array = [true, false] if String(args.get("interior", "both")) == "both" else [String(args.interior) == "1"]
	var fails := 0; var n := 0
	var report := []
	for t in types:
		for rg in regions:
			for s in seeds:
				for inside in modes:
					var sp := S.resolve({ type = t, region = rg, seed = s + 1, interior = inside })
					if args.has("ruin"):
						# 폐가 단계(--ruin=2): 잔해·떨어진 문짝·외엮기가 바닥·벽과 한 평면에 겹치지 않나
						const RUI := preload("res://kit/bldg/_ruin.gd")
						sp.ruin = { stage = float(args.ruin), seed = 5 }
						var rz := RUI.resolve(sp); RUI.plan(sp, rz); sp._rz = rz
						if not rz.interior_ok: sp.interior = false
					var r := _check(sp, args.has("dbg"))
					var name := "%s/%s/%d%s" % [t, rg, s + 1, "/int" if inside else ""]
					report.append({ name = name, pairs = r.pairs, minor = r.minor, area = snappedf(r.area, 0.0001), at = r.at, tris = r.tris })
					n += 1
					if r.pairs > 0:
						fails += 1
						print("FACECHECK %s FAIL pairs=%d area=%.4f at=%s" % [name, r.pairs, r.area, str(r.at)])
	var out: String = args.get("out", "res://shots/building_builder/face_check.json")
	var f := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t")); f.close()
	print("FACECHECK total fail=%d checked=%d" % [fails, n])
	quit(1 if fails > 0 else 0)

func _check(sp: Dictionary, dbg: bool) -> Dictionary:
	var m := C.M.new(int(sp.seed) * 31 + 7, false)
	B.draw(m, sp, 0)
	var ink := Kit.hex(Kit.INK)
	var tris := []   # [a, b, c, n, d]
	for p in m.parts:
		if p == "giwa_lo": continue   # 기와 줄을 켠 지붕의 아틀라스 겉: giwa_hi와 같은 면이지만 거리로 갈려 함께 그려지지 않는다(building.GIWA_NEAR)
		var bt: Kit.Batch = m.parts[p]
		for mk in bt.parts:
			for g in bt.parts[mk]:
				for i in range(0, g.pos.size() - 2, 3):
					if g.col.size() > i and g.col[i].is_equal_approx(ink) and g.col[i + 1].is_equal_approx(ink) and g.col[i + 2].is_equal_approx(ink): continue
					var a: Vector3 = g.pos[i]; var b: Vector3 = g.pos[i + 1]; var c: Vector3 = g.pos[i + 2]
					var nn := (b - a).cross(c - a)
					var L := nn.length()
					if L < 1e-7: continue
					nn /= L
					if nn.y < -0.9: continue   # 아래를 보는 면(밑면·받침에 닿은 면)은 위·옆에서 보이지 않는다 — 처마 밑면은 지붕 검사가 본다
					tris.append([a, b, c, nn, nn.dot(a), p])
	var buckets := {}
	for i in tris.size():
		var t: Array = tris[i]
		var nn: Vector3 = t[3]
		var k := Vector4i(roundi(nn.x * 40), roundi(nn.y * 40), roundi(nn.z * 40), floori(float(t[4]) / DTOL))
		if not buckets.has(k): buckets[k] = []
		buckets[k].append(i)
	var pairs := 0; var area := 0.0; var at := []; var minor := 0
	for k in buckets:
		for dd in [0, 1]:
			var k2 := Vector4i(k.x, k.y, k.z, k.w + dd)
			if not buckets.has(k2): continue
			var A: Array = buckets[k]; var Bk: Array = buckets[k2]
			for ii in A.size():
				var j0 := ii + 1 if dd == 0 else 0
				for jj in range(j0, Bk.size()):
					var ta: Array = tris[A[ii]]; var tb: Array = tris[Bk[jj]]
					if (ta[3] as Vector3).dot(tb[3]) < 0.999 or absf(float(ta[4]) - float(tb[4])) > DTOL: continue
					var ar := _overlap(ta, tb)
					if ar > ATOL and ar <= BIG: minor += 1
					if ar > BIG:
						pairs += 1; area += ar
						if at.size() < 4: at.append([snappedf(ta[0].x, 0.01), snappedf(ta[0].y, 0.01), snappedf(ta[0].z, 0.01)])
						if dbg and pairs <= 40: print("  PAIR n=%s A(%s)=%s %s %s | B(%s)=%s %s %s" % [str(ta[3]), ta[5], ta[0], ta[1], ta[2], tb[5], tb[0], tb[1], tb[2]])
	return { pairs = pairs, area = area, at = at, tris = tris.size(), minor = minor }

# 같은 평면 두 삼각형의 겹친 넓이(평면에 투영)
static func _overlap(ta: Array, tb: Array) -> float:
	var nn: Vector3 = ta[3]
	var u := nn.cross(Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := nn.cross(u)
	var pa := PackedVector2Array(); var pb := PackedVector2Array()
	for q in 3:
		pa.append(Vector2((ta[q] as Vector3).dot(u), (ta[q] as Vector3).dot(v)))
		pb.append(Vector2((tb[q] as Vector3).dot(u), (tb[q] as Vector3).dot(v)))
	var res := Geometry2D.intersect_polygons(pa, pb)
	var s := 0.0
	for poly in res:
		var ar := 0.0
		for i in poly.size(): ar += poly[i].cross(poly[(i + 1) % poly.size()])
		s += absf(ar) * 0.5
	return s
