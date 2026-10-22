# 고을 짜임 지표 보고(docs/reports/settlement-metrics.md §5) — 생성 결과를 실측 목표(세계 배율 ×1.2·×1.44)와 견준다(헤드리스).
#   godot --headless --path . -s res://tools/bldg/settle_metrics.gd -- --district=eup|west [--file=res://…json] [--settle=<견본>] [--json=out.json]
#   --district: tools/bldg/organic.gd DISTRICTS의 구역(넓이 다각형·큰길) + 남원 고을 짜임 파일
#   --settle:   shots/town_organic/_place_<이름>/placement_settle_<이름>.json(districts 넓이·큰길이 파일 안에)
# 끝 줄: METRICS <이름> pass=n fail=n
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const CP := preload("res://kit/bldg/compound.gd")
const OG := preload("res://kit/bldg/organic.gd")
const ODG := preload("res://tools/bldg/organic.gd")
const RDIR := "res://region_data/JL_NAMWON_UNBONG/"

# 목표(실측 × 세계 배율): 넓이 ㎡ ×1.44, 길이 ×1.2
const T_AREA := { arterial = [115.0, 360.0], side = [216.0, 576.0], rear = [475.0, 1150.0], market = [173.0, 504.0], out = [300.0, 900.0], minchon = [432.0, 1296.0], banchon = [864.0, 5760.0], sanchon = [360.0, 1008.0] }
const T_FRONT := { arterial = [7.2, 16.8], side = [12.0, 24.0], rear = [14.4, 28.8], market = [9.6, 19.2], out = [14.4, 36.0], minchon = [21.6, 42.0], banchon = [30.0, 60.0], sanchon = [18.0, 36.0] }
const T_NB := { poor = [1, 2], commoner = [2, 3], middle = [2, 4], shop = [1, 4], hyangri = [3, 4], yangban = [4, 7], garden = [0, 1] }
const T_ROOF := { arterial_band = [0.35, 0.50], walled = [0.22, 0.32], market_band = [0.25, 0.40], out = [0.10, 0.25], minchon = [0.04, 0.10], banchon = [0.03, 0.08] }   # 마을: 실측 밀도(3~9호/ha · 호당 1.5~2동 · 동당 지붕 약 50㎡)에서 — 문서 §3.4 고침
const T_W := { trunk = [6.0, 8.4], street = [4.1, 6.0], alley = [2.4, 3.6], lane = [1.8, 3.0] }
const T_W_VILLAGE := [3.0, 5.0]   # 마을 큰길(하회·외암 마을길 위계 위쪽 2.5~4m × 1.2)

var rows := []
var npass := 0; var nfail := 0
var fpc := {}

func _ok(name: String, val: String, target: String, ok: bool) -> void:
	rows.append([name, val, target, "PASS" if ok else "FAIL"])
	if ok: npass += 1
	else: nfail += 1

func _info(name: String, val: String) -> void:
	rows.append([name, val, "—", "info"])

static func _med(a: Array) -> float:
	if a.is_empty(): return 0.0
	var b := a.duplicate(); b.sort()
	return float(b[b.size() / 2])

static func _q(a: Array, q: float) -> float:
	if a.is_empty(): return 0.0
	var b := a.duplicate(); b.sort()
	return float(b[clampi(int(q * (b.size() - 1)), 0, b.size() - 1)])

func _bounds(params: Dictionary) -> Rect2:
	var k := JSON.stringify(params, "", true)
	if not fpc.has(k): fpc[k] = B.bounds(S.resolve(params))
	return fpc[k]

static func _w(base: Vector2, bry: float, lp: Vector2) -> Vector2:
	return base + OG.rot(lp, bry)

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var name := String(args.get("district", args.get("settle", "?")))
	var area := []
	var trunks := []   # [pts(Vector2), w]
	var file := String(args.get("file", ""))
	var walled := false
	if args.has("district"):
		var D: Dictionary = ODG.DISTRICTS[name]
		for q in D.area: area.append(Vector2(float(q[0]), float(q[1])))
		if file == "": file = RDIR + "placement_namwon_town.json"
		var reg = JSON.parse_string(FileAccess.get_file_as_string(RDIR + "region.json"))
		for rd in reg.roads:
			if (D.get("trunk_ids", {}) as Dictionary).has(String(rd.get("id", ""))):
				var pts := []
				for q in rd.points: pts.append(Vector2(float(q[0]), float(q[1])))
				trunks.append([pts, float(D.trunk_ids[String(rd.id)]), String(rd.id)])
		for et in D.get("extra_trunks", []):
			var pts := []
			for q in et.pts: pts.append(Vector2(float(q[0]), float(q[1])))
			trunks.append([pts, float(et.w), String(et.id)])
		walled = name == "eup"
	var szone_s := {}
	if args.has("settle"):
		# 견본: 파일 안 districts(넓이) · 큰길(alleys kind=trunk, 칠한 폭 + 0.4)
		if file == "": file = "res://shots/town_organic/_place_%s/placement_settle_%s.json" % [name, name]
		var ds0 = JSON.parse_string(FileAccess.get_file_as_string(file))
		var did := String(args.get("dist", ""))
		for dd0 in ds0.districts:
			if String(dd0.id) == did:
				for q in dd0.area: area.append(Vector2(float(q[0]), float(q[1])))
		walled = did.begins_with("in")
		for al in ds0.alleys:
			if String(al.get("kind", "")) != "trunk": continue
			var pts := []
			for q in al.points: pts.append(Vector2(float(q[0]), float(q[1])))
			var tid := String(al.id).get_slice("_", String(al.id).get_slice_count("_") - 1)
			var full_id := String(al.id)
			trunks.append([pts, float(al.width_m) + 0.4, full_id])
			if full_id.contains("_ring_") or full_id.ends_with("_n_gate") or full_id.ends_with("_w_lane") or full_id.ends_with("_e_lane") or full_id.ends_with("to_hyanggyo") or full_id.contains("_out_ew"): szone_s[full_id] = "side"
		name = "%s/%s" % [name, did]
	var d = JSON.parse_string(FileAccess.get_file_as_string(file))
	var pref := String(args.get("prefix", "org"))
	if args.has("district"): pref = String(ODG.DISTRICTS[name].prefix)
	if args.has("settle"): pref = ""
	# --- 길 ---
	var streets := []   # [pts, w, kind]
	var szone: Dictionary = ODG.DISTRICTS[name].get("street_zone", {}) if args.has("district") else szone_s
	for t in trunks: streets.append([t[0], t[1], "trunk" if not szone.has(t[2]) else "ring"])
	for al in d.get("alleys", []):
		var pts := []
		for q in al.points: pts.append(Vector2(float(q[0]), float(q[1])))
		if pts.is_empty() or not OG.pip(area, pts[pts.size() / 2]) and not OG.pip(area, pts[0]): continue
		var dup := String(al.get("kind", "")) == "trunk"
		for t in trunks: if String(al.get("id", "")).ends_with("_" + String(t[2])): dup = true
		if dup: continue
		streets.append([pts, float(al.width_m), String(al.get("kind", "alley"))])
	var wk := {}
	for st in streets:
		var k: String = st[2]
		if not wk.has(k): wk[k] = []
		wk[k].append(float(st[1]))
	for k in wk:
		if k == "trunk" and args.has("tier_village"):
			var inv := 0
			for v in wk[k]: if float(v) >= T_W_VILLAGE[0] - 0.05 and float(v) <= T_W_VILLAGE[1] + 0.05: inv += 1
			_ok("길 폭 마을 큰길", "%d개 · 가운데 %.1fm" % [wk[k].size(), _med(wk[k])], "%.1f~%.1fm" % [T_W_VILLAGE[0], T_W_VILLAGE[1]], float(inv) / wk[k].size() >= 0.9)
			continue
		if args.has("tier_village") and k in ["street", "alley"]:
			var tv: Array = [3.0, 5.2] if k == "street" else [1.2, 3.6]   # 마을길·고샅(1~6m 위계 × 1.2)
			var inv2 := 0
			for v in wk[k]: if float(v) >= tv[0] - 0.05 and float(v) <= tv[1] + 0.05: inv2 += 1
			_ok("길 폭 마을 %s" % k, "%d개 · 가운데 %.1fm" % [wk[k].size(), _med(wk[k])], "%.1f~%.1fm" % [tv[0], tv[1]], float(inv2) / wk[k].size() >= 0.9)
			continue
		if not T_W.has(k):
			_info("길 폭 %s(있던 길)" % k, "%d개 · 가운데 %.1fm" % [wk[k].size(), _med(wk[k])]); continue
		if k == "trunk" and args.has("district"):
			_info("길 폭 큰길(세계에 있던 길 — 바꾸지 않음)", "%d개 · 가운데 %.1fm · 실측 목표 %.1f~%.1fm" % [wk[k].size(), _med(wk[k]), T_W[k][0], T_W[k][1]]); continue
		var inr := 0
		for v in wk[k]: if float(v) >= T_W[k][0] - 0.05 and float(v) <= T_W[k][1] + 0.05: inr += 1
		_ok("길 폭 %s" % k, "%d개 · 가운데 %.1fm" % [wk[k].size(), _med(wk[k])], "%.1f~%.1fm 안 ≥90%%" % [T_W[k][0], T_W[k][1]], float(inr) / wk[k].size() >= 0.9)
	var lane_len := []
	for st in streets:
		if st[2] == "lane": lane_len.append(OG.length(st[0]))
	if not lane_len.is_empty(): _ok("막다른 골목 길이", "%d개 · 최대 %.0fm" % [lane_len.size(), lane_len.max()], "≤36m", float(lane_len.max()) <= 37.0)
	# --- 필지 · 집 ---
	var lots := []
	var brect := []     # [월드 다각형, 바닥 넓이]
	var walls := []     # [a, b, lot id]
	var mains := []     # 안채 남쪽에서 벗어난 각(도)
	var nb_ok := 0; var nb_n := 0
	var by_zone := {}
	var gates := []
	for it in d.items:
		var base := Vector2(float(it.x), float(it.z)); var bry := float(it.get("ry", 0.0))
		var kit := String(it.kit)
		if kit == "bldg/lot" and String(it.id).begins_with(pref) and (it.params as Dictionary).has("poly"):
			var poly := []
			for q in it.params.poly: poly.append(_w(base, bry, Vector2(float(q[0]), float(q[1]))))
			if not OG.pip(area, OG._centroid(poly)): continue
			var og: Dictionary = it.get("organic", {})
			var zn := String(og.get("zone_name", "?")); var cls := String(og.get("cls", "?"))
			var nbld := 0
			for e in it.params.pieces:
				var pc := _w(base, bry, Vector2(float(e.x), float(e.z))); var pr := bry + float(e.get("ry", 0.0))
				match String(e.kit):
					"bldg/building":
						nbld += 1
						var bb := _bounds(e.params)
						brect.append(OG._rect_world(bb, pc, pr, 0.0))
						if String(e.get("tag", "")).begins_with("main"):
							var face := Vector2(sin(pr), cos(pr))
							mains.append(rad_to_deg(acos(clampf(face.y, -1.0, 1.0))))
					"bldg/compound":
						for ce in CP.layout(e.params):
							if String(ce.kit) != "bldg/building": continue
							nbld += 1
							var cc := _w(pc, pr, Vector2(float(ce.x), float(ce.z)))
							brect.append(OG._rect_world(_bounds(ce.params), cc, pr + float(ce.get("ry", 0.0)), 0.0))
					"bldg/wall":
						var wp := []
						for q in e.params.pts: wp.append(_w(pc, pr, Vector2(float(q[0]), float(q[1]))))
						for i in wp.size() - 1: walls.append([wp[i], wp[i + 1], String(it.id)])
						if bool(e.params.get("closed", false)) and wp.size() > 2: walls.append([wp[wp.size() - 1], wp[0], String(it.id)])
					"bldg/gate": gates.append(pc)
			if not by_zone.has(zn): by_zone[zn] = { area = [], front = [], ratio = [] }
			var la := absf(OG.area(poly))
			if String(og.get("kind", "")) == "gap": zn = "gap"   # 길가 틈 메움 필지는 틈 길이대로라 분포 판정에서 뺀다(채 수·덮임엔 든다)
			if not by_zone.has(zn): by_zone[zn] = { area = [], front = [], ratio = [] }
			by_zone[zn].area.append(la)
			if float(og.get("flen", 0.0)) > 0.0:
				by_zone[zn].front.append(float(og.flen))
				by_zone[zn].ratio.append(la / maxf(float(og.flen), 1.0) / maxf(float(og.flen), 1.0))
			if T_NB.has(cls):
				nb_n += 1
				if nbld >= int(T_NB[cls][0]) and nbld <= int(T_NB[cls][1]): nb_ok += 1
				elif args.has("verbose"): print("NBMISS %s %s n=%d area=%.0f" % [it.id, cls, nbld, absf(OG.area(poly))])
			lots.append({ poly = poly, zone = zn, cls = cls, n = nbld })
		elif kit == "bldg/building":
			if OG.pip(area, base): brect.append(OG._rect_world(_bounds(it.params), base, bry, 0.0))
		elif kit == "bldg/wall" and String(it.id).begins_with(pref):
			var wp2 := []
			for q in it.params.pts: wp2.append(_w(base, bry, Vector2(float(q[0]), float(q[1]))))
			for i in wp2.size() - 1: walls.append([wp2[i], wp2[i + 1], String(it.id)])
	# 남긴 옛 집(다른 배치 파일 — 갈음되지 않은 것): 바닥 사각(footprint)으로
	if args.has("district"):
		var sup0 := {}
		for s0 in d.get("supersede", []): sup0[String(s0)] = true
		for f in DirAccess.get_files_at(RDIR):
			if not (f.begins_with("placement_") and f.ends_with(".json")) or f == "placement_namwon_town.json": continue
			var d3 = JSON.parse_string(FileAccess.get_file_as_string(RDIR + f))
			for it in d3.get("items", []):
				if sup0.has(String(it.get("id", ""))): continue
				var k3 := String(it.kit)
				if not (k3 in ["village/choga", "village/giwa", "village/jumak", "village/market_shop", "village/neowa_house", "village/choga_low", "village/heotgan", "village/house_compound", "bldg/building", "bldg/compound"]): continue
				var p3 := Vector2(float(it.x), float(it.z))
				if not OG.pip(area, p3): continue
				var fp3 = it.get("footprint")
				if fp3 is Array: brect.append(OG._rect_world(Rect2(-float(fp3[0]) / 2, -float(fp3[1]) / 2, float(fp3[0]), float(fp3[1])), p3, float(it.get("ry", 0.0)), 0.0))
	for zn in by_zone:
		var Z: Dictionary = by_zone[zn]
		if T_AREA.has(zn) and Z.area.size() < 3:
			_info("필지 넓이 %s(표본 %d — 판정 안 함)" % [zn, Z.area.size()], "가운데 %.0f㎡ · 목표 %.0f~%.0f㎡" % [_med(Z.area), T_AREA[zn][0], T_AREA[zn][1]])
		elif T_AREA.has(zn):
			var m := _med(Z.area)
			_ok("필지 넓이 %s" % zn, "%d필지 · 가운데 %.0f㎡ (사분위 %.0f~%.0f)" % [Z.area.size(), m, _q(Z.area, 0.25), _q(Z.area, 0.75)], "%.0f~%.0f㎡" % [T_AREA[zn][0], T_AREA[zn][1]], m >= T_AREA[zn][0] * 0.9 and m <= T_AREA[zn][1] * 1.1)
		if T_FRONT.has(zn) and Z.front.size() >= 3:
			var mf := _med(Z.front)
			_ok("앞너비 %s" % zn, "가운데 %.1fm" % mf, "%.1f~%.1fm" % [T_FRONT[zn][0], T_FRONT[zn][1]], mf >= T_FRONT[zn][0] * 0.9 and mf <= T_FRONT[zn][1] * 1.1)
			_info("깊이/앞너비 %s" % zn, "가운데 %.2f" % _med(Z.ratio))
	if nb_n > 0: _ok("필지당 채 수(계층 표 안)", "%d / %d" % [nb_ok, nb_n], "≥80%", float(nb_ok) / nb_n >= 0.8)
	if not mains.is_empty():
		var s45 := 0
		for a in mains: if float(a) <= 46.0: s45 += 1
		_ok("안채 남향(±45°)", "%d / %d" % [s45, mains.size()], "≥80%", float(s45) / mains.size() >= 0.8)
	# --- 덮임(0.5m 격자) ---
	var bb := OG._bbox(area)
	var cell := 0.5
	var nx := int(bb.size.x / cell) + 1; var nz := int(bb.size.y / cell) + 1
	var land := PackedByteArray(); land.resize(nx * nz)   # 0 밖 · 1 땅 · 2 큰길·광장(뺌)
	var roof := PackedByteArray(); roof.resize(nx * nz)
	var band := PackedByteArray(); band.resize(nx * nz)   # 1 = 큰길 가장자리 20m 띠
	for j in nz:
		for i in nx:
			var p := bb.position + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
			if not OG.pip(area, p): continue
			var k := j * nx + i
			land[k] = 1
			if not walled:
				# 성 밖·마을: 길에서 30m 넘는 산·숲·물가는 마을 땅이 아니다(마을 넓이 = 길 둘레 땅, 실측 호/ha와 같은 잣대)
				var near := false
				for st in streets:
					if float(OG.line_near(p, st[0]).d) < 30.0: near = true; break
				if not near: land[k] = 0; continue
			for t in trunks:
				if szone.has(t[2]): continue
				var dd: float = float(OG.line_near(p, t[0]).d) - float(t[1]) / 2.0
				if dd < 0.0: land[k] = 2
				elif dd < 20.0: band[k] = 1
	# 큰 건물 일곽(관아·객사·향교 등 settlement 빌더 majors)은 구역 땅에서 뺀다(문서 §3.4 — 구역 땅 = 다각형 − 큰길·관아 일곽·광장)
	for it in d.items:
		if not (it as Dictionary).has("settlement") or not (it.get("footprint") is Array): continue
		var fpm: Array = it.footprint
		if float(fpm[0]) * float(fpm[1]) < 60.0: continue
		# 일곽 + 둘레 6m(관아 앞마당·담 밖 길 — 문서 §3.4 "관아 앞")
		var mrc := OG._rect_world(Rect2(-float(fpm[0]) / 2, -float(fpm[1]) / 2, float(fpm[0]), float(fpm[1])), Vector2(float(it.x), float(it.z)), float(it.get("ry", 0.0)), 6.0)
		var mb := OG._bbox(mrc)
		var i0m := maxi(0, int((mb.position.x - bb.position.x) / cell)); var i1m := mini(nx - 1, int((mb.end.x - bb.position.x) / cell))
		var j0m := maxi(0, int((mb.position.y - bb.position.y) / cell)); var j1m := mini(nz - 1, int((mb.end.y - bb.position.y) / cell))
		for j in range(j0m, j1m + 1):
			for i in range(i0m, i1m + 1):
				if land[j * nx + i] == 1 and OG.pip(mrc, bb.position + Vector2((i + 0.5) * cell, (j + 0.5) * cell)): land[j * nx + i] = 2
	for rc in brect:
		var rb := OG._bbox(rc)
		var i0 := maxi(0, int((rb.position.x - bb.position.x) / cell)); var i1 := mini(nx - 1, int((rb.end.x - bb.position.x) / cell))
		var j0 := maxi(0, int((rb.position.y - bb.position.y) / cell)); var j1 := mini(nz - 1, int((rb.end.y - bb.position.y) / cell))
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := bb.position + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
				if OG.pip(rc, p): roof[j * nx + i] = 1
	var inlot := PackedByteArray(); inlot.resize(nx * nz)
	for L0 in lots:
		var rb := OG._bbox(L0.poly)
		var i0 := maxi(0, int((rb.position.x - bb.position.x) / cell)); var i1 := mini(nx - 1, int((rb.end.x - bb.position.x) / cell))
		var j0 := maxi(0, int((rb.position.y - bb.position.y) / cell)); var j1 := mini(nz - 1, int((rb.end.y - bb.position.y) / cell))
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if OG.pip(L0.poly, bb.position + Vector2((i + 0.5) * cell, (j + 0.5) * cell)): inlot[j * nx + i] = 1
	var bll := 0; var tll := 0; var trl := 0
	for k in land.size():
		if land[k] != 1: continue
		if inlot[k] == 1: tll += 1; trl += roof[k]
		if band[k] == 1 and inlot[k] == 1: bll += 1
	var tl := 0; var tr := 0; var bl := 0; var br := 0
	for k in land.size():
		if land[k] != 1: continue
		tl += 1; tr += roof[k]
		if band[k] == 1 and inlot[k] == 1: bl += 1; br += roof[k]   # 큰길 띠 덮임은 집터(필지) 땅으로 잰다 — 광장·장터 좌판·관아 앞은 뺌(문서 §3.4)
	var whole := float(tr) / maxf(tl, 1)
	if args.has("dump_band"):
		var img := Image.create(nx, nz, false, Image.FORMAT_RGB8)
		for j in nz:
			for i in nx:
				var k := j * nx + i
				var col := Color(0, 0, 0)
				if land[k] == 2: col = Color(0.6, 0.5, 0.3)
				elif land[k] == 1:
					col = Color(0.25, 0.25, 0.25) if band[k] == 1 else Color(0.12, 0.12, 0.12)
					if inlot[k] == 1: col = Color(0.2, 0.45, 0.2)
					if roof[k] == 1: col = Color(0.9, 0.8, 0.4)
				img.set_pixel(i, j, col)
		img.save_png(String(args.dump_band))
	_info("필지가 덮은 땅", "전체 %.0f%% · 큰길 띠 %.0f%% · 필지 안 지붕 덮임 %.0f%%" % [100.0 * tll / maxf(tl, 1), 100.0 * bll / maxf(bl, 1), 100.0 * trl / maxf(tll, 1)])
	var bandc := float(br) / maxf(bl, 1)
	var wkey := "walled" if walled else "out"
	if args.has("tier_village"): wkey = String(args.tier_village)
	_ok("지붕 덮임 전체(%s)" % wkey, "%.1f%%" % (whole * 100.0), "%.0f~%.0f%% (±10%%)" % [T_ROOF[wkey][0] * 100, T_ROOF[wkey][1] * 100], whole >= T_ROOF[wkey][0] * 0.9 and whole <= T_ROOF[wkey][1] * 1.1)
	if args.has("tier_village"):
		# 집 밀도(호/ha): 실측 3~9호/ha(낙안 8.9 · 외암 3.4 · 왕곡 2.8 · 양동 1.7) ÷ 1.44(세계 넓이 배율)
		var nh := 0
		for L1 in lots: if String(L1.cls) in ["poor", "commoner", "middle", "hyangri", "yangban", "shop"]: nh += 1
		var ha: float = absf(OG.area(area)) / 10000.0   # 마을 구역 전체(실측 지정구역 넓이와 같은 잣대)
		var dens: float = nh / maxf(ha, 0.01)
		_ok("집 밀도", "%.1f호/ha (집 %d · 마을 구역 %.1fha)" % [dens, nh, ha], "%.1f~%.1f호/ha (±10%%)" % [1.2, 6.3], dens >= 1.2 * 0.9 and dens <= 6.3 * 1.1)
	var bkey := "arterial_band" if walled else "market_band"
	if bl > 0 and args.has("tier_village"): _info("지붕 덮임 큰길 20m 띠(마을 — 판정 안 함)", "%.1f%%" % (bandc * 100.0))
	elif bl > 0: _ok("지붕 덮임 큰길 20m 띠(필지 땅)", "%.1f%%" % (bandc * 100.0), "%.0f~%.0f%% (±10%%)" % [T_ROOF[bkey][0] * 100, T_ROOF[bkey][1] * 100], bandc >= T_ROOF[bkey][0] * 0.9 and bandc <= T_ROOF[bkey][1] * 1.1)
	# --- 길가 앞면 막힘: 길 따라 1m, 길 가장자리 안 1.5m 점이 건물·담·대문·다른 것에 막혔나 ---
	var others := []   # 필지 밖 다른 항목(좌판·옛 집·큰 건물) 대략 원
	for it in d.items:
		if String(it.kit) == "bldg/lot": continue
		var fp = it.get("footprint")
		var rr := 1.2
		if fp is Array: rr = maxf(float(fp[0]), float(fp[1])) * 0.5
		others.append([Vector2(float(it.x), float(it.z)), rr])
	for f in DirAccess.get_files_at(RDIR):
		if not (f.begins_with("placement_") and f.ends_with(".json")) or f == "placement_namwon_town.json" or not args.has("district"): continue
		var d2 = JSON.parse_string(FileAccess.get_file_as_string(RDIR + f))
		var sup := {}
		for s in d.get("supersede", []): sup[String(s)] = true
		for it in d2.get("items", []):
			if sup.has(String(it.get("id", ""))): continue
			var p2 := Vector2(float(it.x), float(it.z))
			if not bb.grow(5.0).has_point(p2): continue
			var fp = it.get("footprint")
			# 바닥 크기 없는 것(나무·우물·장승·이야기 자리)은 생성기가 비운 반지름과 같게(이야기 4m · 그 밖 2m)
			var rr2: float = maxf(float(fp[0]), float(fp[1])) * 0.5 if fp is Array else (4.0 if f.begins_with("placement_story_") or f.begins_with("placement_stations") else 2.0)
			others.append([p2, rr2])
	var plz := []   # 광장(문 앞·우물·갈림목 — 일부러 둔 빈 땅)
	if args.has("district"):
		for pz in ODG.DISTRICTS[name].get("plazas", []): plz.append([Vector2(float(pz.c[0]), float(pz.c[1])), float(pz.r)])
		for pz in ((d.get("districts", {}) as Dictionary).get(name, {}) as Dictionary).get("plazas", []): plz.append([Vector2(float(pz.c[0]), float(pz.c[1])), float(pz.r)])
	for pz in d.get("plazas", []): plz.append([Vector2(float(pz.c[0]), float(pz.c[1])), float(pz.r)])
	var fr_n := 0; var fr_b := 0; var fr_bld := 0
	for st in streets:
		if st[2] == "lane": continue
		var pts: Array = st[0]
		var L := OG.length(pts)
		var s := 1.0
		while s < L - 1.0:
			var a: Array = OG.at(pts, s)
			s += 1.0
			for side in [-1.0, 1.0]:
				var nrm: Vector2 = Vector2(-(a[1] as Vector2).y, (a[1] as Vector2).x) * float(side)
				var P: Vector2 = (a[0] as Vector2) + nrm * (float(st[1]) / 2.0 + 1.5)
				if not OG.pip(area, P) or not OG.pip(area, P + nrm * 4.5): continue   # 성벽·구역 끝 자투리(깊이 6m 안 됨)는 뺀다
				var on_street := false
				for st2 in streets:
					if OG.line_near(P, st2[0]).d < float(st2[1]) / 2.0 + 0.3: on_street = true; break
				if on_street: continue
				var in_pz := false
				for pz in plz:
					if P.distance_to(pz[0]) < float(pz[1]) + 2.0: in_pz = true; break
				if in_pz: continue
				fr_n += 1
				var blk := false; var isb := false
				for rc in brect:
					if OG.pip(rc, P): blk = true; isb = true; break
				if not blk:
					for w in walls:
						if OG.seg_dist(P, w[0], w[1]) < 1.6: blk = true; break
				if not blk:
					for g in gates:
						if P.distance_to(g) < 2.2: blk = true; break
				if not blk:
					for o in others:
						if P.distance_to(o[0]) < float(o[1]) + 0.5: blk = true; break
				if blk: fr_b += 1
				elif args.has("voids"): print("VOID %.1f %.1f" % [P.x, P.y])
				if isb: fr_bld += 1
	if fr_n > 0:
		_ok("길가 앞면 막힘(담·건물·대문·다른 것)", "%.0f%% (%d점)" % [100.0 * fr_b / fr_n, fr_n], "≥85%", float(fr_b) / fr_n >= 0.85)
		_info("길가 앞면 중 건물 벽", "%.0f%%" % (100.0 * fr_bld / fr_n))
	# --- 맞담 두 겹: 다른 필지 담이 나란히 1.3m 안 ---
	var dbl := 0.0
	for i in walls.size():
		var A: Array = walls[i]
		var ua: Vector2 = ((A[1] as Vector2) - A[0]).normalized()
		for j in range(i + 1, walls.size()):
			var Bw: Array = walls[j]
			if A[2] == Bw[2]: continue
			if absf(ua.dot(((Bw[1] as Vector2) - Bw[0]).normalized())) < 0.9: continue
			if OG.seg_dist(((A[0] as Vector2) + A[1]) / 2.0, Bw[0], Bw[1]) < 1.3: dbl += (A[0] as Vector2).distance_to(A[1])
	_ok("두 겹 담(나란한 이웃 담 1.3m 안)", "%.0fm" % dbl, "0m(±10)", dbl <= 10.0)
	# --- 보고 ---
	print("METRICS %s 필지 %d · 건물 %d · 담 마디 %d" % [name, lots.size(), brect.size(), walls.size()])
	for rw in rows: print("METRIC | %s | %s | %s | %s" % rw)
	print("METRICS %s pass=%d fail=%d" % [name, npass, nfail])
	if args.has("json"):
		var f := FileAccess.open(String(args.json), FileAccess.WRITE)
		f.store_string(JSON.stringify({ "name": name, "rows": rows, "pass": npass, "fail": nfail }, "  "))
	quit()
