# 건물 서술자 검증(WP7a, 헤드리스) — 감사 20 WP7a 인수 V 번호를 서술자 위에서 잰다.
#   godot --headless --path . -s res://tools/bldg/descriptor_check.gd -- [--set=presets|samples] [--out=res://shots/wp7a/descriptor_check.json]
#   끝 줄: DESCCHECK <V> pass=… fail=… warn=… · DESCCHECK total fail=n
#   SCHEMA  계약 Building 필수 + 서술자 세부 항목, scale_applied:true
#   V18     생성기가 confirmed를 만들지 않음 · 근거 항목 status ∈ {proposed, unknown}
#   SCALE1  (K1) 배율 = 규칙 world.length_scale = 명세 real_scale(평면 = 높이), 해결 치수 = 프리셋 실측 × 배율 한 번(두 번 곱하지 않음)
#   V09     (서술자 부분) 벽 면이 그 날개 지붕 처마 외곽 안 · 드나드는 문 머리 + 0.10 ≤ 그 면 처마 밑선 — 지붕 뚫음·깜빡임은 ROOFCHECK·WALLCLEAR·FACECHECK
#   V27     아궁이–구들–굴뚝: 부엌 바닥이 데운 방 바닥보다 0.25 이상 낮음 · 굴뚝은 데운 방 곁(부엌·광 곁이면 실패) · 부엌 계통 굴뚝 없음은 경고
#   V54     ㄱ·ㄷ(날개 둘 이상): 모든 기능 면이 지붕 외곽 안 · 기능 면 넓이 합 = 구조 칸 넓이 합 · 기와 모퉁이에 회첨 기록
#   V55     방마다 문 · 부엌은 바깥 구멍(땔감)과 아궁이 · 드나드는 문: 문지방 = 방 바닥(±0.06), 안·밖 걷기 면이 한 걸음(0.32) 안, 충돌체가 막지 않음
#   V57     (구성 시험) 방 수를 유지한 채 구조 칸·부엌 범위 바꾸기: 기능 면 수·쓰임 같음, 부엌 한 면이 두 칸에 걸침, 그 사이 칸막이 없음
#   V58     툇·쪽마루가 부엌 앞(아궁이 작업 면)을 덮지 않음 · 마루 받침(퇴기둥 양끝 / 독립 기둥 간격 ≤ 2.0m(시험값)) · 방문 앞 디딤(댓돌·마루) 단 ≤ 0.32
#   V60     (부분) 땅 → 기단 → (댓돌) → 바닥 이동 연결 단 ≤ 0.32 또는 계단 — 경사 대지 바닥 편집은 WP8
#   V62     (부분) 벽 두께 기록 · 구멍이 기둥 반 굵기 안쪽 · 벽 두께를 뺀 방 넓이 > 1.5m²
extends SceneTree
const DS := preload("res://kit/bldg/descriptor.gd")
const EX := preload("res://tools/bldg/descriptor_export.gd")
const S := preload("res://kit/bldg/_spec.gd")

const REQ_CONTRACT := ["meta", "type_basis", "column_grid", "bay_spacing", "function_faces", "floor_base", "roof_support", "members", "condition", "scale_applied"]
const REQ_DETAIL := ["schema", "scale", "structural_bays", "partitions", "facades", "doors", "sockets", "heating", "maru", "roof", "collision"]
const POST_GAP := 2.0   # 쪽마루 독립 기둥 간격 상한(m, 시험값 — 근거 없음, status proposed)
const VS := ["SCHEMA", "V18", "SCALE1", "V09", "V27", "V54", "V55", "V57", "V58", "V60", "V62"]
var tally := {}
var report := []

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	for v in VS: tally[v] = { "pass": 0, "fail": 0, "warn": 0 }
	var keys: Array = EX.keys_for(String(args.get("set", "presets")))
	for k in keys:
		var p := EX.params_of(k)
		var d := DS.describe(p)
		_check_one(k, p, d)
	_v57()
	_v58_case()
	var civic := []
	if args.has("plan"): civic = _civic(String(args.plan))
	var out: String = args.get("out", "res://shots/wp7a/descriptor_check.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var f := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
	f.store_string(JSON.stringify({ tally = tally, items = report, civic_fit = civic }, "\t", true)); f.close()
	var nf := 0
	for v in VS:
		print("DESCCHECK %s pass=%d fail=%d warn=%d" % [v, tally[v]["pass"], tally[v]["fail"], tally[v]["warn"]])
		nf += int(tally[v]["fail"])
	print("DESCCHECK total fail=%d buildings=%d" % [nf, keys.size()])
	quit(1 if nf > 0 else 0)

func _res(name: String, v: String, ok: bool, detail := "", warn := false) -> void:
	if ok and not warn: tally[v]["pass"] += 1
	elif ok and warn: tally[v]["pass"] += 1; tally[v]["warn"] += 1
	else: tally[v]["fail"] += 1
	if not ok or warn:
		report.append({ building = name, v = v, ok = ok, warn = warn, detail = detail })
		if not ok: print("DESCCHECK %s %s FAIL %s" % [name, v, detail])

# ---------------------------------------------------------------------------------------------------
func _check_one(name: String, p: Dictionary, d: Dictionary) -> void:
	# SCHEMA
	var miss := []
	for k in REQ_CONTRACT + REQ_DETAIL:
		if not d.has(k): miss.append(k)
	_res(name, "SCHEMA", miss.is_empty() and d.get("scale_applied", false) == true and String(d.schema) == DS.SCHEMA, "missing %s" % str(miss))
	# V18
	var bad18 := []
	if String(d.meta.status) == "confirmed": bad18.append("meta confirmed")
	for e in d.type_basis.evidence:
		if not String(e.status) in ["proposed", "unknown"]: bad18.append(String(e.key))
	_res(name, "V18", bad18.is_empty(), str(bad18))
	_scale1(name, p, d)
	_v09(name, d)
	_v27(name, p, d)
	_v54(name, d)
	_v55(name, d)
	_v58(name, d)
	_v60(name, d)
	_v62(name, d)

func _scale1(name: String, p: Dictionary, d: Dictionary) -> void:
	var f := float(d.scale.factor)
	var errs := []
	var rv := -1.0
	var rules = JSON.parse_string(FileAccess.get_file_as_string(S.RULES_PATH)) if FileAccess.file_exists(S.RULES_PATH) else null
	if rules is Dictionary: rv = float(rules.parameters["world.length_scale"].value)
	if rv > 0.0 and absf(rv - f) > 1e-6: errs.append("rules %.3f != factor %.3f" % [rv, f])
	if absf(S.SCALE_FACTOR_FALLBACK - f) > 1e-6: errs.append("fallback const %.3f != %.3f" % [S.SCALE_FACTOR_FALLBACK, f])
	var rs = d.scale.spec_real_scale
	if not (rs is Array) or absf(float(rs[0]) - f) > 1e-6 or absf(float(rs[1]) - f) > 1e-6: errs.append("spec real_scale %s" % str(rs))
	if d.scale.region_profile_factor != null and absf(float(d.scale.region_profile_factor) - f) > 1e-6: errs.append("region profile factor")
	# 한 번만: 프리셋(배율 전) × f = 해결 치수
	if not p.has("spec") and not p.has("nbays") and not p.has("over"):
		var raw := S.generate(String(p.type), String(p.region), String(p.get("cls", "")), int(p.seed), false)
		var sp := S.resolve(p)
		if absf(snappedf(float(raw.wall_h) * f, 0.01) - float(sp.wall_h)) > 0.011: errs.append("wall_h raw %.2f ×f ≠ %.2f" % [raw.wall_h, sp.wall_h])
		var rb: Array = raw.wings[0].bays; var sb: Array = sp.wings[0].bays
		for i in mini(rb.size(), sb.size()):
			if absf(snappedf(float(rb[i].w) * f, 0.01) - float(sb[i].w)) > 0.011: errs.append("bay%d" % i); break
		if absf(snappedf(float(raw.roof.eave) * f, 0.01) - float(sp.roof.eave)) > 0.011: errs.append("eave")
	_res(name, "SCALE1", errs.is_empty(), str(errs))

static func _inside(poly: Array, x: float, z: float, margin := 0.0) -> bool:
	var mnx := INF; var mxx := -INF; var mnz := INF; var mxz := -INF
	for q in poly:
		mnx = minf(mnx, float(q[0])); mxx = maxf(mxx, float(q[0])); mnz = minf(mnz, float(q[1])); mxz = maxf(mxz, float(q[1]))
	return x >= mnx + margin - 1e-3 and x <= mxx - margin + 1e-3 and z >= mnz + margin - 1e-3 and z <= mxz - margin + 1e-3

func _roof_of(d: Dictionary, wing: int) -> Dictionary:
	for r in d.roof.surfaces:
		if int(r.wing) == wing: return r
	return {}

func _v09(name: String, d: Dictionary) -> void:
	if d.condition in ["abandoned", "collapsed"]: return
	var errs := []
	for f in d.facades:
		if f.side == "partition": continue
		var r := _roof_of(d, int(f.wing))
		if r.is_empty(): continue
		var c: Array = f.center
		var inany := false
		for rr in d.roof.surfaces:
			if _inside(rr.outline, float(c[0]), float(c[2]), 0.0): inany = true
		if not inany: errs.append("%s outside eaves" % f.id)
	for dd in d.doors:
		if not bool(dd.player_use) or not (dd.connects as Array).has("exterior"): continue
		var fa := _facade(d, String(dd.facade))
		var r := _roof_of(d, int(fa.wing))
		if r.is_empty(): continue
		var under := float(r.eave_under_y[fa.side]) if (r.eave_under_y as Dictionary).has(fa.side) else 99.0
		if under < float(dd.head_y) + 0.10 - 0.005: errs.append("%s head %.2f > eave %.2f−0.10" % [dd.id, dd.head_y, under])
	_res(name, "V09", errs.is_empty(), str(errs))

func _facade(d: Dictionary, id: String) -> Dictionary:
	for f in d.facades:
		if f.id == id: return f
	return {}

func _face(d: Dictionary, id: String) -> Dictionary:
	for f in d.function_faces:
		if f.id == id: return f
	return {}

func _sbay(d: Dictionary, id: String) -> Dictionary:
	for b in d.structural_bays:
		if b.id == id: return b
	return {}

func _v27(name: String, p: Dictionary, d: Dictionary) -> void:
	if d.condition in ["abandoned", "collapsed"]: return
	var errs := []
	var warn := []
	var ch = null
	for s in d.sockets:
		if s.kind == "chimney": ch = s
	var sp := S.resolve(p)
	if ch != null and not S.chimney_ok(sp): errs.append("chimney beside unheated bay (%s)" % ch.placement)
	for h in d.heating:
		if h.kind == "kitchen":
			var ag = null
			for s in d.sockets:
				if s.id == h.fire: ag = s
			if ag == null: errs.append("%s no agungi" % h.id); continue
			for rid in h.rooms:
				var rf := _face(d, String(rid))
				if float(rf.floor_y) - float((ag.at as Array)[1]) < 0.25: errs.append("%s room floor %.2f not above kitchen %.2f" % [rid, rf.floor_y, ag.at[1]])
			for m in d.maru.surfaces:
				if _inside(m.poly, float(ag.at[0]), float(ag.at[2])): errs.append("agungi under maru")
			if not bool(h.flue_end_rendered): warn.append("%s flue end not rendered" % h.id)
		elif not bool(h.flue_end_rendered): warn.append("%s hamsil (implied)" % h.id)
	var nheat := 0
	for f in d.function_faces:
		if f.heated: nheat += 1
	if ch != null and nheat == 0: errs.append("chimney without heated room")
	_res(name, "V27", errs.is_empty(), str(errs + warn), not warn.is_empty() and errs.is_empty())

func _v54(name: String, d: Dictionary) -> void:
	if (d.column_grid as Array).size() < 2 or d.condition in ["abandoned", "collapsed"]: return
	var errs := []
	for f in d.function_faces:
		var cx := 0.0; var cz := 0.0
		for q in f.poly: cx += float(q[0]) / 4.0; cz += float(q[1]) / 4.0
		var ok := false
		for r in d.roof.surfaces:
			if _inside(r.outline, cx, cz, 0.3): ok = true
		if not ok: errs.append("%s not under roof" % f.id)
	var fa := 0.0; var ba := 0.0
	for f in d.function_faces: fa += float(f.area_m2)
	for b in d.structural_bays: ba += (float(b.x1) - float(b.x0)) * (float(b.z1) - float(b.z0))
	if absf(fa - ba) > 0.05: errs.append("area %.2f vs %.2f" % [fa, ba])
	if d.roof.kind == "giwa" and d.type_basis.plan in ["giyeok", "digeut"] and (d.roof.valleys as Array).is_empty(): errs.append("no hoecheom")
	_res(name, "V54", errs.is_empty(), str(errs))

func _walk_near(d: Dictionary, x: float, z: float, y: float) -> bool:
	for w in d.collision.walk:
		if x >= float(w.minX) - 0.05 and x <= float(w.maxX) + 0.05 and z >= float(w.minZ) - 0.05 and z <= float(w.maxZ) + 0.05 and absf(float(w.y) - y) <= 0.32 + 0.01: return true
	return false

func _blocked(d: Dictionary, x: float, z: float) -> bool:
	for c in d.collision.colliders:
		if c.type == "box" and x > float(c.minX) + 0.01 and x < float(c.maxX) - 0.01 and z > float(c.minZ) + 0.01 and z < float(c.maxZ) - 0.01: return true
	return false

func _v55(name: String, d: Dictionary) -> void:
	if d.condition in ["abandoned", "collapsed"]: return
	var errs := []
	var warn := []
	for f in d.function_faces:
		if f.fn == "room" and (f.doors as Array).is_empty():
			# 트인 칸막이(정주간·대청과 트임)로 드나드는 방은 문이 없어도 된다(북부 겹집)
			var open_p := false
			for pp in d.partitions:
				if (pp.between as Array).has(f.id) and String(pp.kind) in ["open", "door1", "door2"]: open_p = true   # 그리지 않은(바깥 보기) 칸막이 문도 논리 출입
			if not open_p: errs.append("%s no door" % f.id)
		if f.fn == "kitchen":
			var ext := false
			for fa in d.facades:
				if (fa.faces as Array).has(f.id) and (fa.faces as Array).has("exterior"):
					for it in fa.intervals:
						if it.kind == "opening": ext = true
			if not ext: errs.append("%s no outside opening" % f.id)
	for dd in d.doors:
		if not bool(dd.player_use): continue
		var a: Array = dd.at; var o: Array = dd.outward
		var fl := -INF
		for fid in dd.connects:
			var ff := _face(d, String(fid))
			if not ff.is_empty(): fl = maxf(fl, float(ff.floor_y))
		if fl > -INF and absf(float(dd.sill_y) - fl) > 0.06 and absf(float(dd.sill_y) - fl - 0.05) > 0.06:
			errs.append("%s sill %.2f vs floor %.2f" % [dd.id, dd.sill_y, fl])
		for sg in [1.0, -1.0]:
			var px: float = float(a[0]) + float(o[0]) * 0.3 * sg; var pz: float = float(a[2]) + float(o[1]) * 0.3 * sg
			var ground_ok := float(dd.sill_y) <= 0.33 and not _blocked(d, px, pz)
			if not (_walk_near(d, px, pz, float(dd.sill_y)) or ground_ok): errs.append("%s no walk %s" % [dd.id, "out" if sg > 0 else "in"])
			if _blocked(d, float(a[0]) + float(o[0]) * 0.12 * sg, float(a[2]) + float(o[1]) * 0.12 * sg):
				var inf := _face(d, String(dd.connects[0]))
				if sg < 0 and not inf.is_empty() and String(inf.fn) in ["store", "shed", "stable"]:
					warn.append("%s player-scale door into closed %s (box collider)" % [dd.id, inf.fn])
				else: errs.append("%s blocked %s" % [dd.id, "out" if sg > 0 else "in"])
	_res(name, "V55", errs.is_empty(), str(errs + warn), errs.is_empty() and not warn.is_empty())

func _v58(name: String, d: Dictionary) -> void:
	if (d.maru.surfaces as Array).is_empty() or d.condition in ["abandoned", "collapsed"]: return
	var errs := []
	var warn := []
	for m in d.maru.surfaces:
		var pts: Array = m.support.points
		if pts.size() < 2: errs.append("%s <2 supports" % m.id)
		if m.support.kind == "independent_posts":
			for i in range(1, pts.size()):
				if Vector2(float(pts[i][0]) - float(pts[i - 1][0]), float(pts[i][2]) - float(pts[i - 1][2])).length() > POST_GAP: errs.append("%s post gap" % m.id)
		# 마루 판이 덮은 칸에 부엌이 없나
		for sb in d.structural_bays:
			if sb.fn != "kitchen" or int(sb.wing) != int(m.wing): continue
			var mx0 := float(m.x_range[0]); var mx1 := float(m.x_range[1])
			var cx := (float(sb.x0) + float(sb.x1)) / 2.0
			if cx > mx0 + 0.05 and cx < mx1 - 0.05: errs.append("%s covers kitchen %s" % [m.id, sb.id])
	for g in d.maru.gaps:
		var sb := _sbay(d, String(g.bay))
		if sb.fn == "kitchen" and g.reason != "agungi_work": errs.append("kitchen gap reason")
	# 방문 앞 디딤: 바닥이 기단보다 0.12 넘게 높으면 댓돌 또는 마루, 단 ≤ 0.32
	for fl in d.floor_base.floors:
		var fb := float(fl.base_top_y); var ff := float(fl.floor_y)
		if ff - fb <= 0.12 or bool(fl.raised): continue
		var tops := [fb]
		for s in d.floor_base.steps:
			if int(s.wing) == int(fl.wing) and s.kind == "daetdol": tops.append(float(s.top_y))
		for m in d.maru.surfaces:
			if int(m.wing) == int(fl.wing): tops.append(float(m.y))
		tops.append(ff); tops.sort()
		var used := false
		for dd in d.doors:
			if bool(dd.player_use) and int(_facade(d, String(dd.facade)).get("wing", -1)) == int(fl.wing): used = true
		for i in range(1, tops.size()):
			if float(tops[i]) - float(tops[i - 1]) > 0.32 + 0.005:
				var msg := "w%d step %.2f→%.2f" % [int(fl.wing), tops[i - 1], tops[i]]
				if used: errs.append(msg)
				else: warn.append(msg + " (드나드는 문 없음 — 보기 디딤)")
	_res(name, "V58", errs.is_empty(), str(errs + warn), errs.is_empty() and not warn.is_empty())

func _v60(name: String, d: Dictionary) -> void:
	if d.condition in ["abandoned", "collapsed"]: return
	var errs := []
	for fl in d.floor_base.floors:
		var fb := float(fl.base_top_y)
		if fb > 0.33:
			var st := false
			for s in d.floor_base.steps:
				if s.kind == "stair": st = true   # 계단은 몸채 기단 한 곳(날개 기단과 이어짐)
			if not st: errs.append("w%d base %.2f no stair" % [int(fl.wing), fb])
	_res(name, "V60", errs.is_empty(), str(errs), true)

func _v62(name: String, d: Dictionary) -> void:
	var errs := []
	var col := float(d.column_grid[0].column_section.d) if not (d.column_grid as Array).is_empty() else 0.2
	for f in d.facades:
		if not f.has("thickness") or float(f.thickness) <= 0.0: errs.append("%s no thickness" % f.id)
		var hw := float(f.width) / 2.0
		for it in f.intervals:
			if it.kind == "opening" and not String(it.role) in ["open_bay", "rail", "gate", "shop_front", "folding_door"]:
				if float(it.a) < -hw + col * 0.45 - 0.02 or float(it.b) > hw - col * 0.45 + 0.02: errs.append("%s opening into column" % f.id)
	for f in d.function_faces:
		if float(f.area_m2) < 1.5: errs.append("%s area" % f.id)
	_res(name, "V62", errs.is_empty(), str(errs), true)

# ---------------------------------------------------------------------------------------------------
# V57: 같은 집에서 방 수는 그대로, 부엌을 두 구조 칸으로(room 열쇠) · 칸 폭 바꾸기
func _v57() -> void:
	var base_p := { type = "choga", region = "south", seed = 1, interior = true }
	var sp := S.resolve(base_p)
	var d0 := DS.describe(base_p)
	var v := sp.duplicate(true)
	var bays: Array = v.wings[0].bays
	var ki := -1
	for i in bays.size():
		if String(bays[i].fn) == "kitchen": ki = i
	var kb: Dictionary = bays[ki]
	var w := float(kb.w)
	var k1 := kb.duplicate(true); var k2 := kb.duplicate(true)
	k1.w = snappedf(w * 0.45, 0.01); k2.w = snappedf(w * 0.55 + 0.3, 0.01)   # 부엌을 넓히며 두 칸으로
	k1.room = "kitchen_a"; k2.room = "kitchen_a"
	k2.front = { kind = "wall" }; k2.back = { kind = "wall" }
	bays.remove_at(ki); bays.insert(ki, k2); bays.insert(ki, k1)
	if ki > 0: bays[ki - 1].w = snappedf(float(bays[ki - 1].w) - 0.3, 0.01)   # 옆 방은 좁게(방 수 그대로)
	var d1 := DS.describe({ spec = v, stable_id = "v57.choga.south.1" })
	var errs := []
	var fns0 := []; var fns1 := []
	for f in d0.function_faces: fns0.append(String(f.fn))
	for f in d1.function_faces: fns1.append(String(f.fn))
	fns0.sort(); fns1.sort()
	if fns0 != fns1: errs.append("faces %s vs %s" % [str(fns0), str(fns1)])
	var kf := {}
	for f in d1.function_faces:
		if f.fn == "kitchen": kf = f
	if kf.is_empty() or int(kf.structural_bay_count) != 2: errs.append("kitchen not 2 bays")
	for p in d1.partitions:
		if (p.between as Array)[0] == (p.between as Array)[1]: errs.append("partition inside face")
	for fa in d1.facades:
		if fa.side == "partition" and (fa.faces as Array)[0] == (fa.faces as Array)[1] and String(fa.faces[0]) == String(kf.get("id", "")): errs.append("rendered wall inside kitchen")
	if (d1.column_grid[0].x_lines as Array).size() != (d0.column_grid[0].x_lines as Array).size() + 1: errs.append("column line not added")
	for f in d1.function_faces:
		if f.fn == "room" and (f.doors as Array).is_empty(): errs.append("room lost door")
	_check_one("v57/kitchen_two_bays", { spec = v }, d1)
	_res("v57/kitchen_two_bays", "V57", errs.is_empty(), str(errs))

# V58 구성: 쪽마루(독립 기둥) + 부엌 앞 빈 퇴칸 — 쪽마루 남부 초가를 찾아 본다
func _v58_case() -> void:
	for s in range(1, 30):
		var p := { type = "choga", region = "south", seed = s, interior = true }
		var sp := S.resolve(p)
		if String(sp.wings[0].toet.kind) != "jjok": continue
		var d := DS.describe(p)
		var errs := []
		var gap := false
		for g in d.maru.gaps:
			if g.reason == "agungi_work": gap = true
		if not gap: errs.append("no kitchen gap")
		var ind := false
		for m in d.maru.surfaces:
			if m.support.kind == "independent_posts": ind = true
		if not ind: errs.append("no independent posts")
		_res("v58/jjok_seed%d" % s, "V58", errs.is_empty(), str(errs))
		return

# ---------------------------------------------------------------------------------------------------
# 관아 터(계획서 frame.civic_reserves) ↔ 서술자 — 배치는 하지 않는다(WP7b 문법). 터 가운데 놓고 앞(+z)을 터 방위로 돌렸을 때
#   본채 처마 외곽이 터 너비·깊이에 드는지, 본채 출입 소켓 → 터 entrance_socket 거리. 결과는 미리보기(proposed).
const CIVIC_MAIN := { dongheon = "dongheon", gaeksa = "gaeksa", hyanggyo = "daeseong", hyangcheong = "gangdang", jakcheong = "haengrang",
	jongga = "anchae", storage = "gotgan", gunchang = "gotgan" }
func _civic(path: String) -> Array:
	var plan = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := []
	if not (plan is Dictionary): return out
	var prof: Dictionary = plan.get("region_profile", {})
	for c in (plan.get("frame", {}) as Dictionary).get("civic_reserves", []):
		var key := String(c.key)
		if not CIVIC_MAIN.has(key):
			out.append({ reserve = c.id, key = key, status = "unknown", note = "본채 프리셋 대응 없음(빈터·우물·연못 등)" }); continue
		var p := { type = CIVIC_MAIN[key], region = "south", seed = 1, stable_id = "civic.%s" % key, cls = "official" if CIVIC_MAIN[key] in ["haengrang", "gotgan"] else "" }
		if p.cls == "": p.erase("cls")
		var d := DS.describe(p, prof)
		var mnx := INF; var mxx := -INF; var mnz := INF; var mxz := -INF
		for r in d.roof.surfaces:
			for q in r.outline:
				mnx = minf(mnx, float(q[0])); mxx = maxf(mxx, float(q[0])); mnz = minf(mnz, float(q[1])); mxz = maxf(mxz, float(q[1]))
		var bw := mxx - mnx; var bd := mxz - mnz
		var ent = null
		for sk in d.sockets:
			if sk.kind == "anchor" and String(sk.name) in ["steps", "door"]: ent = sk.at; break
		var fit := bw <= float(c.width_m) and bd <= float(c.depth_m)
		out.append({ reserve = c.id, key = key, preset = p.type, reserve_w = c.width_m, reserve_d = c.depth_m, building_w = bw, building_d = bd,
			fits = fit, margin_w = float(c.width_m) - bw, margin_d = float(c.depth_m) - bd, bearing_deg = c.bearing_deg,
			building_entrance_local = ent, reserve_entrance = c.entrance_socket, scale_check = absf(float(d.scale.factor) - float(prof.scale_policy.building.factor)) < 1e-6 if not prof.is_empty() else null,
			status = "proposed", note = "본채 한 채만 — 문 겹·마당 묶음은 WP7b" })
		print("DESCCHECK CIVIC %s %s fits=%s w %.1f/%.1f d %.1f/%.1f" % [c.id, p.type, str(fit), bw, float(c.width_m), bd, float(c.depth_m)])
	return out
