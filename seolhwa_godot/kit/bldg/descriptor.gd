# 건물 서술자(WP7a, 감사 20 §5 · 계약 settlement-contract/1 Building) — 빌더가 실제로 그린 건물 한 채를 "해결된" 자료로 내보낸다.
#   describe(params, region_profile) → building-descriptor/1 사전(JSON으로 그대로 저장)
#   · 좌표: 건물 로컬(몸채 가운데 땅 = 원점, 앞 +z, 위 +y), 단위 world_m. 배율은 이미 들어가 있다(scale_applied: true) — 다시 곱하지 않는다.
#   · 배율 기록: RegionProfile.scale_policy.building.factor 하나(평면 = 높이, 굽기에서 한 번). 명세의 real_scale이 그 값과 같아야 한다(SCALE1).
#   · 기능 면(방·부엌·대청…)과 구조 칸(기둥 사이)을 따로 둔다(HOUSE-01): 한 기능 면이 여러 칸에 걸칠 수 있다(bay.room 열쇠, 트인 대청).
#   · 면(façade)은 막힌 구간/구멍 구간과 쓰임, 문은 머리 높이와 드나듦(player_use), 소켓은 아궁이·구들·굴뚝·마루 받침·부엌 일·출입.
#   · 지붕은 날개마다 처마 외곽·처마 높이(면마다)·용마루·물매·낙숫물 줄, 회첨(모퉁이) 표시.
#   · 부재 목록(members)·충돌 참조(collision)·상태(condition)·근거(type_basis.evidence — _calib.gd 보정 항목과 status).
#   기록은 building.gd의 REC(가장 가까운 단계 그리기)에서 받는다 — 서술자를 위해 형상을 따로 계산하지 않는다(그린 것과 어긋나지 않게).
extends RefCounted
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const CB := preload("res://kit/bldg/_calib.gd")
const RF := preload("res://kit/bldg/_roof.gd")
const RU := preload("res://kit/bldg/_ruin.gd")

const SCHEMA := "building-descriptor/1"
const RULE_VERSION := "bldg-descriptor/1"
const GENERATOR := "kit/bldg/descriptor.gd/1"
const MAX_STEP := 0.32   # world.MAX_STEP — 걸어 오르는 한 단

const ROLE := { door2 = "door", door1 = "door", door4 = "door", bunhap_up = "folding_door", plank = "plank_door", plank2 = "plank_door",
	window = "window", smallwin = "window", salchang = "vent_window", gate = "gate", shop = "shop_front", open = "open_bay", rail = "rail" }
const OPEN_KINDS := ["open", "rail"]

# region_profile: settlement 계획서의 region_profile(또는 RegionProfile 사전). 비어 있으면 규칙 파일에서 배율만 읽는다(출처 표시).
static func describe(params: Dictionary, region_profile: Dictionary = {}) -> Dictionary:
	var sp := S.resolve(params)
	var rz := RU.resolve(sp)
	if not rz.is_empty(): RU.plan(sp, rz); sp._rz = rz
	B.REC = { wings = [], faces = [], bases = [], marus = [], steps = [], chimney = null, cur_wing = 0 }
	var bp := params.duplicate(true); bp.lod = 0
	var res: Dictionary = B.build(bp)
	var rec: Dictionary = B.REC
	B.REC = null
	if res.has("node"): (res.node as Node).free()
	var d := _compose(params, sp, rec, res, region_profile)
	return d

# ---------------------------------------------------------------------------------------------------
static func _compose(params: Dictionary, sp: Dictionary, rec: Dictionary, res: Dictionary, prof: Dictionary) -> Dictionary:
	var ctx := B._ctx(sp)
	var wings: Array = sp.wings
	var wrec := {}
	for wr in rec.wings: wrec[int(wr.wing)] = wr

	# --- 기둥 줄 · 칸 간격 ---------------------------------------------------------------------
	var column_grid := []
	var bay_spacing := []
	var sbays := []
	for wi in wings.size():
		var w: Dictionary = wings[wi]
		if not wrec.has(wi): continue
		var wr: Dictionary = wrec[wi]
		var xf: Transform3D = wr.xform
		var cols := []
		for c in wr.cols: cols.append(_v2(xf * Vector3(float(c[0]), 0, float(c[1]))) + [float(c[2]), float(wr.top)])
		column_grid.append({ wing = wi, wing_id = String(w.id), place = { x = float(w.x), z = float(w.z), ry_deg = rad_to_deg(float(w.ry)) },
			x_lines = wr.xs, z_lines = _sorted(wr.zlines), toet_line = float(wr.zcol) if String(wr.tk) == "toet" else null,
			columns = cols, column_section = { kind = String(sp.column), d = float(sp.col) }, column_top = float(wr.top) })
		var ws := []
		for b in w.bays: ws.append(float(b.w))
		bay_spacing.append({ wing = wi, widths = ws, depths = (w.depth as Array).duplicate(), toet = { kind = String(wr.tk), d = float(wr.T) } })
		for i in (w.bays as Array).size():
			var b: Dictionary = w.bays[i]
			sbays.append({ id = "w%d.b%d" % [wi, i], wing = wi, index = i, fn = String(b.fn), role = String(b.get("role", "")),
				x0 = float(wr.xs[i]), x1 = float(wr.xs[i + 1]), z0 = float(wr.zb), z1 = float(wr.zf), width = float(b.w),
				floor_y = float(wr.floors[i]), poly = _poly(xf, float(wr.xs[i]), float(wr.xs[i + 1]), float(wr.zb), float(wr.zf)),
				collapsed = (wr.collapsed as Array).has(i) })

	# --- 기능 면(방) ---------------------------------------------------------------------------
	var faces := []
	var face_of := {}     # "wi.bi" → face id
	for wi in wings.size():
		if not wrec.has(wi): continue
		var w: Dictionary = wings[wi]
		var wr: Dictionary = wrec[wi]
		var bays: Array = w.bays
		var i := 0
		while i < bays.size():
			var j := i
			while j + 1 < bays.size() and _same_face(bays[j], bays[j + 1]): j += 1
			var fn := String(bays[i].fn)
			var roles := []
			var ids := []
			var area := 0.0
			var D: float = float(wr.D)
			for k in range(i, j + 1):
				ids.append("w%d.b%d" % [wi, k])
				var rl := String(bays[k].get("role", ""))
				if rl != "" and not roles.has(rl): roles.append(rl)
				area += float(bays[k].w) * D
			var fid := "room:w%d.%s%d" % [wi, fn, i]
			var heated := S.is_heated(sp, w, bays[i])
			faces.append({ id = fid, fn = fn, roles = roles, bays = ids, structural_bay_count = ids.size(),
				explicit_room = String(bays[i].get("room", "")), area_m2 = area, floor_y = float(wr.floors[i]),
				poly = _poly(wr.xform, float(wr.xs[i]), float(wr.xs[j + 1]), float(wr.zb), float(wr.zf)), heated = heated, doors = [] })
			for k in range(i, j + 1): face_of["%d.%d" % [wi, k]] = fid
			i = j + 1

	# 칸막이(논리): 다른 기능 면 사이 — 그렸는지(rendered)와 함께
	var partitions := []
	for wi in wings.size():
		if not wrec.has(wi): continue
		var bays: Array = wings[wi].bays
		var wr: Dictionary = wrec[wi]
		for i in range(1, bays.size()):
			var fa: String = face_of["%d.%d" % [wi, i - 1]]; var fb: String = face_of["%d.%d" % [wi, i]]
			var kind := B._partition_kind(bays[i - 1], bays[i])
			if fa == fb:
				continue
			partitions.append({ wing = wi, x = float(wr.xs[i]), between = [fa, fb], kind = kind, rendered = false })

	# --- 면(façade): 막힌 구간 / 구멍 구간 -----------------------------------------------------
	var facades := []
	var doors := []
	var ndoor := 0
	for fr in rec.faces:
		var wi := int(fr.wing)
		var w: Dictionary = wings[wi]
		var bi := int(fr.bay)
		var side := String(fr.side)
		var kind := String(fr.kind)
		var wdt := float(fr.w)
		var c: Vector3 = fr.c; var ax: Vector3 = fr.ax; var out: Vector3 = fr.out
		var y0 := float(fr.y0); var y1 := float(fr.y1)
		var op: Array = fr.op
		var iv := []
		if kind in OPEN_KINDS:
			iv.append({ a = -wdt / 2, b = wdt / 2, kind = "opening", role = ROLE[kind], y0 = y0, y1 = y1 })
		elif op.size() == 4:
			if float(op[0]) > -wdt / 2 + 0.005: iv.append({ a = -wdt / 2, b = float(op[0]), kind = "solid" })
			iv.append({ a = float(op[0]), b = float(op[1]), kind = "opening", role = ROLE.get(kind, kind), y0 = float(op[2]), y1 = float(op[3]) })
			if float(op[1]) < wdt / 2 - 0.005: iv.append({ a = float(op[1]), b = wdt / 2, kind = "solid" })
		else:
			iv.append({ a = -wdt / 2, b = wdt / 2, kind = "solid", material = "board" if kind == "board" else String(sp.wall) })
		var fid := "facade:%d:w%d.b%d.%s" % [facades.size(), wi, bi, side]
		var inside := String(face_of.get("%d.%d" % [wi, bi], ""))
		var other := "exterior"
		if side == "partition":
			# 칸막이: b는 오른쪽(+x) 칸 — 왼쪽 칸의 기능 면과 잇는다(겹집 가운데 줄은 같은 칸 앞뒤)
			var lk := "%d.%d" % [wi, bi - 1]
			other = String(face_of.get(lk, inside)) if absf(absf(float(fr.ry)) - PI / 2) < 0.01 else inside
			for p in partitions:
				if int(p.wing) == wi and (p.between as Array).has(inside) and (p.between as Array).has(other): p.rendered = true
		facades.append({ id = fid, wing = wi, bay = "w%d.b%d" % [wi, bi], side = side, kind = kind, center = _v3(c), axis = _v2(ax), outward = _v2(out),
			width = wdt, base_y = y0, top_y = y1, thickness = float(fr.t), intervals = iv, faces = [inside, other], part = String(fr.part) })
		for it in iv:
			if it.kind != "opening": continue
			if not String(it.role) in ["door", "folding_door", "plank_door", "gate"]: continue
			var mid := (float(it.a) + float(it.b)) / 2.0
			var p := c + ax * mid
			var did := "door:%d" % ndoor; ndoor += 1
			# 드나듦: 그 문이 사람 키(놀이 배율)로 그려졌고(pdoor) 걸어 들어가는 집(interior)이며, 칸막이 문이면 두 쪽 바닥 차가 한 걸음 안
			var use := bool(fr.pdoor) and bool(sp.interior)
			var note := ""
			if use and other != "exterior":
				var fa0 := _face_by(faces, inside); var fa1 := _face_by(faces, other)
				if not fa0.is_empty() and not fa1.is_empty() and absf(float(fa0.floor_y) - float(fa1.floor_y)) > MAX_STEP:
					use = false; note = "floor_step %.2f > %.2f (부엌 쪽 문턱 — 사람 길 아님)" % [absf(float(fa0.floor_y) - float(fa1.floor_y)), MAX_STEP]
			var dd := { id = did, facade = fid, kind = kind, role = it.role, width = float(it.b) - float(it.a), sill_y = float(it.y0), head_y = float(it.y1),
				at = _v3(Vector3(p.x, float(it.y0), p.z)), outward = _v2(out), player_use = use, height_class = "player" if bool(fr.pdoor) else "measured",
				connects = [inside, other], note = note }
			doors.append(dd)
			for f in faces:
				if f.id == inside or f.id == other: (f.doors as Array).append(did)

	# --- 기단 · 바닥 ---------------------------------------------------------------------------
	var floors := []
	for wi in wings.size():
		if not wrec.has(wi): continue
		var wr: Dictionary = wrec[wi]
		floors.append({ wing = wi, base_top_y = float(wr.Fb), floor_y = float(wr.Ff), raised = bool(wr.raised), bay_floors = wr.floors, front_margin = float(wr.mfront) })
	var foundation := []
	for bs in rec.bases:
		foundation.append({ wing = int(bs.wing), kind = String(bs.kind), top_y = float(bs.top), bottom_y = 0.0, poly = bs.poly, bays = bs.bays, corner = bool(bs.corner) })
	var floor_base := { ground_ref = "building origin y = 0 (placement ground)", base_kind = String(sp.base.kind), base_h = float(ctx.Fb), floor_dh = float(sp.floor_dh),
		foundation = foundation, floors = floors, steps = _steps(rec.steps), site_fit = { status = "unknown", note = "경사 대지 맞춤(건물별 바닥 편집)은 WP8 — 지금은 평평한 원점 기준" } }

	# --- 마루(툇·쪽마루) · 끊김 ----------------------------------------------------------------
	var marus := []
	var covered := {}
	for mr in rec.marus:
		var posts := []
		for p in mr.posts: posts.append(_v3(p))
		var sup := "toet_columns" if String(mr.kind) == "toet" else "independent_posts"
		marus.append({ id = "maru:w%d.%d-%d" % [int(mr.wing), int(mr.bays[0]), int(mr.bays[1])], wing = int(mr.wing), kind = String(mr.kind), y = float(mr.y),
			poly = mr.poly, x_range = [float(mr.x0), float(mr.x1)], bays = ["w%d.b%d" % [int(mr.wing), int(mr.bays[0])], "w%d.b%d" % [int(mr.wing), int(mr.bays[1])]],
			support = { kind = sup, points = posts, bears_on = "base_top" } })
		for k in range(int(mr.bays[0]), int(mr.bays[1]) + 1): covered["%d.%d" % [int(mr.wing), k]] = true
	var maru_gaps := []
	for wi in wings.size():
		if not wrec.has(wi): continue
		var wr: Dictionary = wrec[wi]
		if String(wr.tk) == "none" or bool(wr.raised): continue
		var bays: Array = wings[wi].bays
		for i in bays.size():
			if covered.has("%d.%d" % [wi, i]): continue
			var b: Dictionary = bays[i]
			var why := "no_maru"
			if String(b.fn) == "kitchen": why = "agungi_work"        # 아궁이·연료 넣기·재 치우기·부엌 드나듦
			elif String(b.front.kind) == "join": why = "wing_join"
			elif String(b.fn) in ["shed", "stable", "store", "gate", "mill", "forge"]: why = "service_front"
			maru_gaps.append({ wing = wi, bay = "w%d.b%d" % [wi, i], x0 = float(wr.xs[i]), x1 = float(wr.xs[i + 1]), reason = why })

	# --- 불(아궁이–구들–굴뚝) · 소켓 -----------------------------------------------------------
	var sockets := []
	var heating := []
	var ch = rec.chimney
	var chid = null
	if ch != null:
		chid = "socket:chimney"
		sockets.append({ id = chid, kind = "chimney", at = _v3(ch.base), top_y = float(ch.top), placement = String(ch.at), chimney_kind = String(ch.kind),
			moved = String(sp.chimney.get("moved", "")) })
	var cbay := S.chimney_bay(sp)
	var sysn := 0
	for hs in S.heat_systems(sp):
		var rooms := []
		var gud := []
		for rb in hs.rooms:
			var wi := int(rb[0]); var bi := int(rb[1])
			if not wrec.has(wi): continue
			var wr: Dictionary = wrec[wi]
			var gid := "socket:gudeul:w%d.b%d" % [wi, bi]
			gud.append(gid)
			if not rooms.has(face_of["%d.%d" % [wi, bi]]): rooms.append(face_of["%d.%d" % [wi, bi]])
			sockets.append({ id = gid, kind = "gudeul", bay = "w%d.b%d" % [wi, bi], poly = _poly(wr.xform, float(wr.xs[bi]), float(wr.xs[bi + 1]), float(wr.zb), float(wr.zf)),
				y_range = [float(wr.Fb), float(wr.floors[bi])] })
		var fire = null
		if hs.kind == "kitchen":
			var fw := int(hs.fire[0]); var fb := int(hs.fire[1]); var r0: Array = hs.rooms[0]
			if wrec.has(fw):
				var wr: Dictionary = wrec[fw]
				var p := Vector3.ZERO
				if int(r0[0]) == fw:
					var xb: float = float(wr.xs[maxi(fb, int(r0[1]))])
					var sgn := 1.0 if int(r0[1]) > fb else -1.0
					p = (wr.xform as Transform3D) * Vector3(xb - sgn * 0.35, 0, 0)
				else:
					# ㄱ·ㄷ 모퉁이 부엌: 몸채 끝 벽(방) 쪽
					var m0: Dictionary = wrec.get(0, wr)
					var sx := 1.0 if float(wings[fw].x) > 0.0 else -1.0
					p = (m0.xform as Transform3D) * Vector3(sx * (float(m0.L) / 2 + 0.35), 0, 0)
				fire = "socket:agungi:w%d.b%d" % [fw, fb]
				sockets.append({ id = fire, kind = "agungi", bay = "w%d.b%d" % [fw, fb], at = _v3(Vector3(p.x, float(wr.floors[fb]), p.z)), feeds = gud,
					work_face = face_of["%d.%d" % [fw, fb]], fuel_from = "kitchen_front" })
		else:
			fire = "socket:hamsil:%d" % sysn
			sockets.append({ id = fire, kind = "hamsil_agungi", bay = "w%d.b%d" % [int(hs.far[0]), int(hs.far[1])], feeds = gud, rendered = false,
				status = "proposed", note = "부엌에 닿지 않는 데운 방 — 밖에서 불 때는 함실 아궁이를 가정(형상 없음)" })
		var serves: bool = not cbay.is_empty() and _sys_has(hs, int(cbay[0]), int(cbay[1]))
		heating.append({ id = "heat:%d" % sysn, kind = String(hs.kind), fire = fire, gudeul = gud, rooms = rooms,
			far_bay = "w%d.b%d" % [int(hs.far[0]), int(hs.far[1])], chimney = chid if serves else null,
			flue_end_rendered = serves, status = "proposed" })
		sysn += 1
	# 마루 받침 · 부엌 일 · 출입 · 곁 것
	for mr in marus:
		sockets.append({ id = "socket:maru_support:%s" % String(mr.id).trim_prefix("maru:"), kind = "maru_support", maru = mr.id, points = mr.support.points, support = mr.support.kind })
	for dd in doors:
		var ext: bool = (dd.connects as Array).has("exterior")
		if not ext and not bool(dd.player_use): continue
		var o: Array = dd.outward
		var a: Array = dd.at
		sockets.append({ id = "socket:entrance:%s" % String(dd.id).trim_prefix("door:"), kind = "entrance" if bool(dd.player_use) or String(dd.role) == "gate" else "service_door",
			door = dd.id, at = [float(a[0]) + float(o[0]) * 0.6, float(a[1]), float(a[2]) + float(o[1]) * 0.6], player_use = bool(dd.player_use) })
	var svc := { firewood = "fuel_store", jangdok_s = "jangdok", gamasot = "outdoor_hearth", sul_dok = "jar_store", yongsu = "sign", pyeongsang = "yard_platform",
		tools = "tool_rack", soguri = "yard_item", trough = "water_trough", forge_out = "forge_yard", anvil = "forge_yard", wheel = "water_wheel" }
	for a in sp.get("attach", []):
		if not a.has("x"): continue
		sockets.append({ id = "socket:service:%s:%d" % [String(a.kind), sockets.size()], kind = "service", role = svc.get(String(a.kind), "yard_item"),
			at = [float(a.x), 0.0, float(a.get("z", 0.0))] })
	for k in res.get("anchors", {}):
		var v: Vector3 = res.anchors[k]
		sockets.append({ id = "socket:anchor:%s" % String(k), kind = "anchor", name = String(k), at = _v3(v) })

	# --- 지붕 받침 · 지붕 ------------------------------------------------------------------------
	var roof_support := []
	var roof_surfaces := []
	var drips := []
	var valleys := []
	var rgeo := {}
	for rg in B.roof_geos(sp): rgeo[String(rg.wing)] = rg
	for wi in wings.size():
		if not wrec.has(wi): continue
		var w: Dictionary = wings[wi]
		var wr: Dictionary = wrec[wi]
		var xf: Transform3D = wr.xform
		var top := float(wr.top)
		roof_support.append({ wing = wi, column_top_y = top, changbang = [top, top + 0.22], dori_top_y = top + (0.48 if bool(ctx.hi) else 0.4),
			bearing_lines_z = [float(wr.zb), float(wr.zcol)], roof_up = float(w.get("roof_up", 0.0)), lower = float(w.get("lower", 0.0)) })
		var fr := B._roof_frame(sp, ctx, w)
		var kind := String(sp.roof.kind)
		var eave := { front = 0.0, back = 0.0, left = 0.0, right = 0.0 }
		var under := {}
		if kind == "thatch":
			var dr := B._thatch_droop(sp, ctx, w, top)
			var up := top + 0.3 - float(w.get("lower", 0.0))
			eave = { front = up, back = up, left = up, right = up }
			under = { front = up - B.THATCH_T - float(dr.zp), back = up - B.THATCH_T - float(dr.zn), left = up - B.THATCH_T - float(dr.xn), right = up - B.THATCH_T - float(dr.xp) }
		else:
			var e := float(fr.eave)
			eave = { front = e, back = e, left = e, right = e }
			var th := B.GIWA_THICK if kind == "giwa" else 0.1
			under = { front = e - th, back = e - th, left = e - th, right = e - th }
		# 실제 지붕 조각(날개)에서 잰 용마루·가장 낮은 끝
		var meas := {}
		var gg = rgeo.get(String(w.id), null)
		if gg != null:
			var ymax := -INF; var ymin := INF
			var g: Kit.Geo = gg.geo
			for pp in g.pos:
				ymax = maxf(ymax, pp.y); ymin = minf(ymin, pp.y)
			meas = { ridge_y = ymax, lowest_y = ymin }
		var ridge := float(meas.get("ridge_y", float(fr.eave) + float(fr.rise)))
		var outline := _poly(xf, float(fr.xa), float(fr.xb), float(fr.za), float(fr.zb2))
		var ends: Array = fr.ends
		roof_surfaces.append({ id = "roof:w%d" % wi, wing = wi, kind = kind, form = String(sp.roof.form), ends = ends, outline = outline,
			eave_y = eave, eave_under_y = under, ridge_y = ridge, rise = float(fr.rise), half_depth = float(fr.hd),
			pitch_deg = rad_to_deg(atan2(ridge - float(eave.front), float(fr.hd))), eave_to_ridge = ridge - float(eave.front),
			overhang = float(sp.roof.eave), droop = float(sp.roof.get("droop", 0.0)), eave_dy = float(sp.roof.get("eave_dy", 0.26)) if kind == "giwa" else null,
			measured = meas })
		# 낙숫물 줄: 처마 외곽 네 변(옆 끝이 다른 지붕에 묻히는 변은 joined)
		var cor := [Vector3(fr.xa, 0, fr.zb2), Vector3(fr.xb, 0, fr.zb2), Vector3(fr.xb, 0, fr.za), Vector3(fr.xa, 0, fr.za)]
		var sides := [["front", 0, 1], ["right", 1, 2], ["back", 2, 3], ["left", 3, 0]]
		for sd in sides:
			var nm := String(sd[0])
			var joined := false
			if nm == "left" and (String(ends[0]) == "corner" or float((fr.ext as Array)[0]) > 0.0): joined = true
			if nm == "right" and (String(ends[1]) == "corner" or float((fr.ext as Array)[1]) > 0.0): joined = true
			if bool(w.get("joined", false)) and nm == ("left" if -signf(sin(float(w.ry))) > 0 else "right"): joined = true
			var gable := (nm == "left" and String(ends[0]) == "gable") or (nm == "right" and String(ends[1]) == "gable")
			drips.append({ roof = "roof:w%d" % wi, side = nm, p0 = _v2(xf * cor[int(sd[1])]), p1 = _v2(xf * cor[int(sd[2])]), y = float(under[nm]),
				drains = not gable and not joined, note = "박공 끝(낙숫물 없음)" if gable else ("다른 지붕에 묻힘(회첨·이음)" if joined else "") })
		for k in 2:
			if String(ends[k]) == "corner":
				valleys.append({ roof = "roof:w%d" % wi, end = "left" if k == 0 else "right", kind = "hoecheom", corner_w = float((w.get("corner_w", [0.0, 0.0]) as Array)[k]) })

	# --- 부재 목록 -----------------------------------------------------------------------------
	var members := _members(sp, column_grid, facades, doors, marus, floor_base, roof_surfaces, sockets, rec)

	# --- 충돌 참조 -----------------------------------------------------------------------------
	var colliders := []
	var ci := 0
	for c in res.get("colliders", []):
		var cc: Dictionary = (c as Dictionary).duplicate()
		cc.id = "col:%d" % ci; ci += 1
		colliders.append(cc)
	var walks := []
	var wi2 := 0
	for wk in res.get("walk", []):
		walks.append({ id = "walk:%d" % wi2, minX = float(wk.minX), maxX = float(wk.maxX), minZ = float(wk.minZ), maxZ = float(wk.maxZ), y = float((wk.y as Array)[0]) })
		wi2 += 1
	for fa in facades: fa.collision_refs = _hits(colliders, fa)

	# --- 근거 · 배율 · 상태 ------------------------------------------------------------------------
	var factor := S.profile_factor()
	var rp_id := "region:rules-default"
	var rp_factor = null
	if prof.has("scale_policy"):
		rp_factor = float(prof.scale_policy.building.factor)
		rp_id = String((prof.get("meta", {}) as Dictionary).get("stable_id", "region:unknown"))
	var locked := params.has("spec")
	var ev := CB.applied(sp)
	var srcs := ["kit/bldg/_spec.gd:%s" % String(sp.type)]
	for e in ev:
		if not bool(e.applied): continue
		for s in e.sources:
			if not srcs.has(s): srcs.append(s)
	var plan := "il"
	if wings.size() == 2 and bool(wings[1].get("joined", false)): plan = "giyeok"
	elif wings.size() == 3 and bool(wings[1].get("joined", false)): plan = "digeut"
	elif wings.size() > 1: plan = "multi"
	var cond := "normal" if float(sp.wear) < 0.6 else "worn"
	if sp.has("_rz"):
		var st := float(sp._rz.stage)
		cond = "partly_damaged" if st < 1.75 else ("abandoned" if st < 3.75 else "collapsed")
	var body := {
		schema = SCHEMA,
		type_basis = { preset = String(sp.type), region = String(sp.region), cls = String(sp.cls), seed = int(sp.seed), plan = plan, spec_locked = locked,
			refs = sp.get("refs", []), evidence = ev, period = { label = "조선 후기 제작 제안", status = "proposed" },
			note = "프리셋 집 — 실측 사례 복제가 아님. 보정 항목의 status는 근거 수준(_calib.gd)" },
		scale_applied = true,
		scale = { factor = factor, axes = ["plan", "height"], source = "RegionProfile.scale_policy.building.factor", region_profile = rp_id,
			region_profile_factor = rp_factor, spec_real_scale = sp.get("real_scale", null), applied_at = "_spec.real_scale (preset resolve, once)",
			rules_value_path = S.RULES_PATH + "#parameters.world.length_scale", not_rescaled = locked },
		units = "world_m",
		frame = { origin = "main wing center at ground", forward = "+z", up = "+y" },
		column_grid = column_grid,
		bay_spacing = bay_spacing,
		structural_bays = sbays,
		function_faces = faces,
		partitions = partitions,
		floor_base = floor_base,
		maru = { surfaces = marus, gaps = maru_gaps },
		facades = facades,
		doors = doors,
		sockets = sockets,
		heating = heating,
		roof_support = roof_support,
		roof = { kind = String(sp.roof.kind), surfaces = roof_surfaces, drip_lines = drips, valleys = valleys },
		members = members,
		collision = { colliders = colliders, walk = walks, footprint = _v2v(res.get("footprint", Vector2.ZERO)) },
		condition = cond,
		wear = float(sp.wear),
	}
	body = _clean(body)
	var sid := "building:" + _sid(String(params.get("stable_id", sp.id)))
	var meta := { stable_id = sid,
		provenance = { sources = srcs, generator = GENERATOR, rules_hash = _rules_hash(), inputs = _clean(_inputs(params)) },
		rule_version = RULE_VERSION, status = "proposed", lock_scope = ["shape"] if locked else [],
		revision = JSON.stringify(body, "", true).sha256_text(), hypothesis = false }
	body.meta = meta
	return body

# ---------------------------------------------------------------------------------------------------
static func _same_face(a: Dictionary, b: Dictionary) -> bool:
	var ra := String(a.get("room", "")); var rb := String(b.get("room", ""))
	if ra != "" or rb != "": return ra == rb
	return String(a.fn) == String(b.fn) and String(a.fn) in ["hall", "maru", "shrine"] and B._partition_kind(a, b) == "open"

static func _face_by(faces: Array, id: String) -> Dictionary:
	for f in faces:
		if String(f.id) == id: return f
	return {}

static func _bay_index(w: Dictionary, b) -> int:
	var bays: Array = w.bays
	for i in bays.size():
		if is_same(bays[i], b): return i
	return -1

static func _sys_has(hs: Dictionary, wi: int, bi: int) -> bool:
	for rb in hs.rooms:
		if int(rb[0]) == wi and int(rb[1]) == bi: return true
	return false

static func _steps(steps: Array) -> Array:
	var out := []
	for s in steps:
		var o := { wing = int(s.wing), kind = String(s.kind), bay = "w%d.b%d" % [int(s.wing), int(s.bay)], top_y = float(s.top), at = _v3(s.at) }
		if s.has("n"): o.n = int(s.n); o.rise = float(s.rise)
		out.append(o)
	return out

static func _members(sp: Dictionary, grid: Array, facades: Array, doors: Array, marus: Array, fb: Dictionary, roofs: Array, sockets: Array, rec: Dictionary) -> Array:
	var out := []
	var ncol := 0; var lcol := 0.0
	for g in grid:
		for c in g.columns:
			ncol += 1; lcol += float(c[3]) - float(c[2])
	if String(sp.cho) != "none": out.append({ part = "chochumdol", ko = "주춧돌", count = ncol, kind = String(sp.cho) })
	out.append({ part = "column", ko = "기둥", count = ncol, length_m = lcol, section = String(sp.column), d = float(sp.col) })
	var lbeam := 0.0
	for g in grid:
		var xl: Array = g.x_lines
		lbeam += 2.0 * (float(xl[xl.size() - 1]) - float(xl[0]))
	out.append({ part = "changbang", ko = "창방", count = 2 * grid.size(), length_m = lbeam })
	out.append({ part = "dori", ko = "도리", count = 2 * grid.size(), length_m = lbeam })
	var wall_a := 0.0; var nwall := 0
	var opening := {}
	for f in facades:
		for it in f.intervals:
			if it.kind == "solid":
				nwall += 1
				wall_a += (float(it.b) - float(it.a)) * (float(f.top_y) - float(f.base_y))
			else:
				var k := String(f.kind)
				opening[k] = int(opening.get(k, 0)) + 1
				if not String(it.role) in ["open_bay", "rail", "shop_front"]:
					wall_a += (float(it.b) - float(it.a)) * maxf(0.0, (float(f.top_y) - float(f.base_y)) - (float(it.y1) - float(it.y0)))
	out.append({ part = "wall_infill", ko = "벽체(" + String(sp.wall) + ")", count = nwall, area_m2 = wall_a })
	for k in opening: out.append({ part = "opening:" + String(k), ko = "창호·문(" + String(k) + ")", count = int(opening[k]) })
	var ma := 0.0; var nposts := 0
	for m in marus:
		var p: Array = m.poly
		ma += _area(p)
		if String(m.support.kind) == "independent_posts": nposts += (m.support.points as Array).size()
	if not marus.is_empty(): out.append({ part = "toetmaru", ko = "툇마루·쪽마루", count = marus.size(), area_m2 = ma, independent_posts = nposts })
	var nd := 0; var ns := 0
	for s in fb.steps:
		if s.kind == "daetdol": nd += 1
		else: ns += int(s.get("n", 1)) - 1
	if nd > 0: out.append({ part = "daetdol", ko = "댓돌", count = nd })
	if ns > 0: out.append({ part = "stair_step", ko = "돌계단 단", count = ns })
	var ba := 0.0
	for f in fb.foundation: ba += _area(f.poly)
	out.append({ part = "gidan", ko = "기단(" + String(sp.base.kind) + ")", count = (fb.foundation as Array).size(), area_m2 = ba, height_m = float(fb.base_h) })
	var ra := 0.0
	for r in roofs: ra += _area(r.outline)
	out.append({ part = "roof", ko = { thatch = "이엉 지붕", giwa = "기와 지붕", neowa = "너와 지붕" }.get(String(sp.roof.kind), "지붕"), count = roofs.size(), plan_area_m2 = ra, form = String(sp.roof.form) })
	if rec.chimney != null: out.append({ part = "chimney", ko = "굴뚝", count = 1, kind = String(rec.chimney.kind), height_m = float(rec.chimney.top) })
	var nag := 0
	for s in sockets:
		if s.kind == "agungi": nag += 1
	if nag > 0: out.append({ part = "agungi", ko = "아궁이(부뚜막)", count = nag })
	return out

static func _hits(cols: Array, fa: Dictionary) -> Array:
	var c: Array = fa.center; var ax: Array = fa.axis
	var hw := float(fa.width) / 2.0
	var p0 := Vector2(float(c[0]) - float(ax[0]) * hw, float(c[2]) - float(ax[1]) * hw)
	var p1 := Vector2(float(c[0]) + float(ax[0]) * hw, float(c[2]) + float(ax[1]) * hw)
	var mn := Vector2(minf(p0.x, p1.x) - 0.15, minf(p0.y, p1.y) - 0.15); var mx := Vector2(maxf(p0.x, p1.x) + 0.15, maxf(p0.y, p1.y) + 0.15)
	var out := []
	for k in cols:
		if String(k.type) != "box": continue
		if float(k.maxX) < mn.x or float(k.minX) > mx.x or float(k.maxZ) < mn.y or float(k.minZ) > mx.y: continue
		out.append(k.id)
	return out

static func _inputs(params: Dictionary) -> Dictionary:
	var o := {}
	for k in params:
		if k == "spec": o.spec_id = String((params.spec as Dictionary).get("id", "")); continue
		if k == "lod": continue
		o[k] = params[k]
	return o

static func _rules_hash():
	if not FileAccess.file_exists(S.RULES_PATH): return null
	return FileAccess.get_file_as_string(S.RULES_PATH).sha256_text()

static func _sid(s: String) -> String:
	var out := ""
	for ch in s:
		var u := ch.unicode_at(0)
		out += ch if (u >= 48 and u <= 57) or (u >= 65 and u <= 90) or (u >= 97 and u <= 122) or ch in ["_", ".", "-"] else "_"
	return out

static func _poly(xf: Transform3D, x0: float, x1: float, z0: float, z1: float) -> Array:
	var out := []
	for q in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]:
		var p: Vector3 = xf * q
		out.append([p.x, p.z])
	return out

static func _area(p: Array) -> float:
	var a := 0.0
	for i in p.size():
		var q: Array = p[i]; var r: Array = p[(i + 1) % p.size()]
		a += float(q[0]) * float(r[1]) - float(r[0]) * float(q[1])
	return absf(a) / 2.0

static func _sorted(a: Array) -> Array:
	var b := a.duplicate(); b.sort(); return b

static func _v3(v: Vector3) -> Array: return [v.x, v.y, v.z]
static func _v2(v: Vector3) -> Array: return [v.x, v.z]
static func _v2v(v: Vector2) -> Array: return [v.x, v.y]

# 소수 셋째 자리로 · Vector → 배열 · -0 → 0 (같은 내용이면 같은 revision)
static func _clean(v):
	if v is Dictionary:
		var o := {}
		for k in v: o[String(k)] = _clean(v[k])
		return o
	if v is Array:
		var o := []
		for x in v: o.append(_clean(x))
		return o
	if v is Vector3: return _clean([v.x, v.y, v.z])
	if v is Vector2: return _clean([v.x, v.y])
	if v is float:
		var f := snappedf(v, 0.001)
		return 0.0 if absf(f) < 0.0005 else f
	if v is StringName: return String(v)
	return v
