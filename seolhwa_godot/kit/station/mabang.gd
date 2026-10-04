# 역참 마방(驛 馬房) — 큰길 가 역(驛)의 말 우리 한 벌: 앞이 트인 마구간(칸막이·구유·깔짚) + 울타리 친 마당(말 놀이터) + 말 매는 가로대 +
#   짚가리·건초 시렁 + 마부 방(작은 채) + 안장 걸이·물통 + 역 깃발(驛旗)·현판 기둥. 말·마부(움직이는 것)는 scripts/region/station_life.gd가 놓는다.
# 고증(참고 — docs/reports/stations.md): 조선 역참은 역마를 기르는 마구(馬廐)·역졸 집·역리 청을 큰길 가 고을 밖에 두었다.
#   마구간은 칸마다 구유를 두고 말 머리를 구유 쪽으로 매며, 앞을 터서 바람을 통하게 했다. 지역마다 지붕·벽 재료가 다르다.
# 정면(+z)이 카메라 쪽(카메라는 남→북 고정이라 생성기가 ry를 작게(±30° 안) 두고 길 옆에 놓는다 — tools/region/make_stations.py).
#   길가 문 앞(말 매는 가로대·현판·역 깃발·도착 자리)은 따로 kit/station/hitch.gd — 길이 어느 쪽으로 지나도 길가에 놓이게.
# params: seed, style("honam"|"yeongnam"|"giho"|"gwanseo"|"haeseo"|"gwanbuk"|"gwandong"|"tamna"), hub(false: 대표 도시 역 — 기와·마구 6칸),
#         stalls(칸 수, 기본 hub 6 · 그 밖 5), lod(false)
# 앵커(plan()과 같은 값): stall_<i>(칸 말 자리), feed_<i>(구유 앞 마부 자리), pad_<i>(마당 말 자리), pad_min·pad_max(마당 사각형),
#   hay(짚가리 앞), home(마부 방 문 앞), yard_in(마당 가운데)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")
const HS := preload("res://kit/village/haystack.gd")
const DOL := preload("res://kit/culture/tamna/doldam.gd")
const TD := preload("res://kit/village/todam.gd")

const W := 27.0       # 터 폭(x)
const D := 21.0       # 터 깊이(z)

# 지역 차림: 지붕(CC.ROOF), 벽, 울타리, 마부 방 굴뚝
const STYLES := {
	honam = { roof = "thatch", hub_roof = "giwa", wall = "mud", fence = "rail", chim = "low" },
	yeongnam = { roof = "thatch", hub_roof = "giwa", wall = "red", fence = "rail", chim = "low" },
	giho = { roof = "thatch", hub_roof = "giwa", wall = "mud", hub_wall = "plaster", fence = "rail", chim = "" },
	gwanseo = { roof = "thatch_nw", hub_roof = "giwa_dark", wall = "mud", fence = "rail", chim = "log" },
	haeseo = { roof = "thatch_nw", hub_roof = "giwa_dark", wall = "mud", fence = "rail", chim = "log" },
	gwandong = { roof = "thatch", hub_roof = "giwa", wall = "mud", fence = "rail", chim = "log" },
	gwanbuk = { roof = "thatch_old", hub_roof = "giwa_dark", wall = "mud", fence = "heavy", chim = "tall", heavy = true },
	tamna = { roof = "thatch_sea", hub_roof = "thatch_sea", wall = "basalt", fence = "basalt", chim = "", rope = true },
}

static func style_of(params: Dictionary) -> Dictionary:
	return STYLES.get(String(params.get("style", "honam")), STYLES.honam)

# 자리 계획(메시 없이) — 키트와 station_life.gd가 같이 쓴다. 로컬 좌표 Vector3(x, 0, z)
static func plan(params: Dictionary) -> Dictionary:
	var hub := bool(params.get("hub", false))
	var n: int = int(params.get("stalls", 6 if hub else 5))
	var bw := 2.6
	var L := bw * n
	var sx := -3.5          # 마구간 가운데 x
	var sz := -6.6          # 마구간 가운데 z
	var sd := 4.4           # 마구간 깊이
	var front := sz + sd / 2
	var p := { stalls = [], feed = [], pads = [], n = n, L = L, sx = sx, sz = sz, sd = sd, bw = bw, front = front }
	for i in n:
		var x := sx - L / 2 + (i + 0.5) * bw
		p.stalls.append(Vector3(x, 0, front - 0.45))
		p.feed.append(Vector3(x + 0.3, 0, front + 1.25))
	p.pad_min = Vector3(6.2, 0, -9.6); p.pad_max = Vector3(12.8, 0, 1.4)
	p.pads = [Vector3(8.4, 0, -5.8), Vector3(10.6, 0, -1.6), Vector3(9.2, 0, -8.0)]
	p.trough_pad = Vector3(7.4, 0, -0.4)
	p.hay = Vector3(-9.6, 0, -1.2)          # 짚가리 앞(마부가 건초를 안는 자리)
	p.home = Vector3(-9.8, 0, 6.9)          # 마부 방 문 앞
	p.yard_in = Vector3(-1.0, 0, 6.0)       # 마당 가운데(마부가 드나드는 길목)
	return p

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var st := style_of(params)
	var hub := bool(params.get("hub", false))
	var p := plan(params)
	var R := m.rng
	var roof: String = st.hub_roof if hub else st.roof
	var wall: String = st.get("hub_wall", st.wall) if hub else st.wall
	_stable(m, p, roof, wall, st)
	_paddock(m, p, st)
	_hay(m, p, st)
	_groom_house(m, p, roof if not hub else st.roof, st)
	_props(m, p, R)
	for k in ["hay", "home", "yard_in", "pad_min", "pad_max", "trough_pad"]: m.anchor(k, p[k])
	for i in p.n:
		m.anchor("stall_%d" % i, p.stalls[i]); m.anchor("feed_%d" % i, p.feed[i])
	for i in p.pads.size(): m.anchor("pad_%d" % i, p.pads[i])
	return m.result("역참 마방", Vector2(W, D), false)   # 터 전체가 한 키트라 occluder(가까이 가면 비침)는 끈다 — 마당에 서면 마방이 다 비쳐 보였다

# ---- 마구간: 앞이 트인 긴 채(높은 처마 — 고정 카메라에서 칸 안 말이 보이게), 칸막이, 구유, 깔짚 ----
static func _stable(m: C.M, p: Dictionary, roof: String, wall: String, st: Dictionary) -> void:
	var R := m.rng
	var L: float = p.L; var Dd: float = p.sd
	var heavy := bool(st.get("heavy", false))
	var basalt := wall == "basalt"
	var wc: Array = C.MUD
	var wkey := "mud"
	match wall:
		"plaster": wc = C.PLASTER
		"red": wc = CC.MUD_RED
		"basalt": wc = CC.BASALT; wkey = "stone"
	var F := 0.3
	var wallH := 2.9
	var top := F + wallH
	var old := m.push(p.sx, 0, p.sz)
	var hl := L / 2; var hd := Dd / 2
	var t := 0.5 if (heavy or basalt) else 0.18
	# 기단(흙 다짐) + 깔짚
	m.add("p", "stone", C.PA(Kit.box(L + 0.6, F, Dd + 0.5, 0, F / 2, 0), C.STONE if not basalt else CC.BASALT_L, 0.05, R), 0.02)
	m.add("p", "thatch", C.PA(Kit.box(L - 0.2, 0.05, Dd - 0.6, 0, F + 0.025, -0.2), C.STRAW, 0.06, R), 0)
	# 뒷벽·옆벽(뒷벽 안쪽은 그늘이라 어둡게 한 겹)
	m.add("p", wkey, C.PA(Kit.box(L, wallH, t, 0, F + wallH / 2, -hd + t / 2), wc, 0.04, R), 0.02)
	m.add("p", "flat", C.P(Kit.box(L - 0.3, wallH - 0.2, 0.03, 0, F + wallH / 2, -hd + t + 0.02), 0x3e3128, 0x2a211a), 0)
	for s in [-1, 1]: m.add("p", wkey, C.PA(Kit.box(t, wallH, Dd, s * (hl - t / 2), F + wallH / 2, 0), wc, 0.04, R), 0.02)
	if basalt:
		var sg := []
		for i in int(L / 0.9):
			for row in 3:
				if R.next() < 0.4: continue
				var lg := Kit.lump(R.between(0.22, 0.3), 0, R, 0.35, 0.8)
				sg.append(C.PA(Kit.xf(lg, -hl + (i + 0.5) * 0.9, F + 0.4 + row * 0.8, -hd - 0.02, 0, R.next() * 3, 0, 1.2, 1, 0.45), CC.BASALT_L, 0.08, R))
		if sg.size() > 0: m.add("p", "stone", Kit.merge(sg), 0)
	# 기둥(앞) + 칸막이 널(낮게 — 말 몸이 보이게) + 북부는 칸마다 허리 높이 판벽(바람막이, 반문)
	var n: int = p.n
	var bw: float = p.bw
	for i in n + 1:
		var x := -hl + i * bw
		if not basalt or i == 0 or i == n:
			m.add("p", "wood", C.PA(Kit.box(0.22, wallH, 0.22, x, F + wallH / 2, hd), C.WOOD), 0.015)
		if i > 0 and i < n:
			m.add("p", "wood", C.P(Kit.box(0.08, 1.45, Dd - 0.9, x, F + 0.72, -0.35), 0x7a5c3e, 0x5a4430, 0.04, R), 0.012)
			if basalt: m.add("p", "stone", C.PA(Kit.box(0.4, wallH, 0.4, x, F + wallH / 2, hd), CC.BASALT, 0.05, R), 0.02)
	m.add("p", "wood", C.PA(Kit.box(L + 0.3, 0.2, 0.24, 0, top + 0.05, hd), C.WOOD), 0.015)
	if heavy:
		# 칸 사이 앞 판벽 반 칸씩(말 머리가 나오는 가운데는 트임) — 관북 겨울 바람막이
		for i in n:
			var x := -hl + (i + 0.5) * bw
			for s in [-1, 1]:
				m.add("p", "wood", C.P(Kit.box(0.55, 1.2, 0.1, x + s * (bw / 2 - 0.4), F + 0.6, hd - 0.05), 0x6a5038, 0x4d3826, 0.04, R), 0.01)
	# 구유(통나무를 판 긴 구유) — 칸 앞, 말 머리 아래. 칸마다 건초
	var tz := hd + 0.25
	m.add("p", "wood", C.P(Kit.box(L - 0.4, 0.42, 0.55, 0, F + 0.5, tz), 0x6b5038, 0x4d3826, 0.04, R), 0.015)
	m.add("p", "flat", C.P(Kit.box(L - 0.55, 0.02, 0.36, 0, F + 0.72, tz), 0x3a2e22), 0)
	for i in n:
		var x := -hl + (i + 0.5) * bw
		if R.next() < 0.85:
			m.add("p", "thatch", C.PA(Kit.xf(Kit.lump(0.26, 1, R, 0.3, 0.4), x + R.between(-0.4, 0.4), F + 0.7, tz, 0, 0, 0, 1.6, 1, 0.7), C.STRAW, 0.06, R), 0)
		for s in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.12, 0.32, 0.5, x + s * (bw / 2 - 0.1), F + 0.16, tz), C.WOOD), 0)
	m.box_c(-hl - 0.3, hl + 0.3, -hd - 0.3, tz + 0.35)
	m.pop(old)
	# 지붕(맞배 — 처마를 짧게 내밀어 칸 안이 보이게)
	var ov := 0.55
	var r := { x0 = p.sx - hl - ov, x1 = p.sx + hl + ov, z0 = p.sz - hd - ov, z1 = p.sz + hd + ov, axis = "x",
		eave = top + (0.35 if roof.begins_with("giwa") else 0.08), k = 1.9 if roof.begins_with("giwa") else 1.2, gable = true }
	r.rise = (hd + ov) * (0.5 if roof.begins_with("giwa") else 0.55)
	var ro := { ov = ov }
	if bool(st.get("rope", false)): ro.rope = 0.6
	CC.env_roof(m, [r], roof, ro)

# ---- 마당(말 놀이터): 가로대 울타리(관북: 굵은 통나무 세 단 / 제주: 현무암 돌담) + 돌 물구유 ----
static func _paddock(m: C.M, p: Dictionary, st: Dictionary) -> void:
	var R := m.rng
	var a: Vector3 = p.pad_min; var b: Vector3 = p.pad_max
	var gate_x0 := a.x + 1.0; var gate_x1 := a.x + 3.2   # 남쪽 변의 드나드는 틈
	var segs := [[a.x, a.z, b.x, a.z], [b.x, a.z, b.x, b.z], [a.x, a.z, a.x, b.z], [gate_x1, b.z, b.x, b.z], [a.x, b.z, gate_x0, b.z]]
	var fence: String = st.fence
	for s in segs:
		if fence == "basalt":
			DOL.draw(m, s[0], s[1], s[2], s[3], 1.25, true)
		else:
			_rail(m, s[0], s[1], s[2], s[3], fence == "heavy")
		var x0 := minf(s[0], s[2]); var x1 := maxf(s[0], s[2]); var z0 := minf(s[1], s[3]); var z1 := maxf(s[1], s[3])
		m.box_c(x0 - 0.15, x1 + 0.15, z0 - 0.15, z1 + 0.15)
	# 돌 물구유
	var tp: Vector3 = p.trough_pad
	m.add("p", "stone", C.P(Kit.box(1.6, 0.5, 0.6, tp.x, 0.25, tp.z), 0x9d978b, 0x77726a, 0.05, R), 0.02)
	m.add("p", "flat", C.P(Kit.box(1.4, 0.02, 0.42, tp.x, 0.49, tp.z), 0x4a5a5e, 0x3a474a), 0)
	m.box_c(tp.x - 0.85, tp.x + 0.85, tp.z - 0.35, tp.z + 0.35)
	# 밟힌 흙 바닥(풀이 듬성한 마당)
	m.add("p", "mud", C.P(Kit.box(b.x - a.x - 0.4, 0.03, b.z - a.z - 0.4, (a.x + b.x) / 2, 0.015, (a.z + b.z) / 2), 0xb39a72, 0x9a845e, 0.06, R), 0)

static func _rail(m: C.M, ax: float, az: float, bx: float, bz: float, heavy: bool) -> void:
	var len := Vector2(bx - ax, bz - az).length()
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz, false)
	var np := maxi(1, roundi(len / 2.1))
	var h := 1.45 if heavy else 1.25
	for i in np + 1:
		m.add("p", "wood", C.PA(Kit.cyl(0.07 if not heavy else 0.1, 0.08 if not heavy else 0.11, h, 6, float(i) / np * len, h / 2, 0), C.WOOD), 0.012)
	var rails := [0.55, 1.05] if not heavy else [0.45, 0.9, 1.32]
	for y in rails:
		m.add("p", "wood", C.P(Kit.cyl(0.045 if not heavy else 0.07, 0.045 if not heavy else 0.07, len, 5, len / 2, y, 0.06, 0, 0, PI / 2), 0x8a6a48, 0x6e5238), 0.01)
	m.xform = old

# ---- 짚가리 둘 + 건초 시렁(경사 받침에 짚단) ----
static func _hay(m: C.M, p: Dictionary, st: Dictionary) -> void:
	var R := m.rng
	var hy: Vector3 = p.hay
	var old := m.push(hy.x - 1.6, 0, hy.z - 1.4)
	HS.draw(m, 1.15)
	m.pop(old)
	m.circle(hy.x - 1.6, hy.z - 1.4, 1.35)
	old = m.push(hy.x - 2.0, 0, hy.z + 1.6)
	HS.draw(m, 0.85)
	m.pop(old)
	m.circle(hy.x - 2.0, hy.z + 1.6, 1.0)
	# 건초 시렁: 마구간 서쪽 박공 옆, 나무 받침에 짚단을 기대 세움
	var rx: float = p.sx - p.L / 2 - 1.6; var rz: float = p.sz + 0.3
	for s in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.1, 2.1, 0.1), rx, 1.0, rz + s * 1.3, 0, 0, 0.25), C.WOOD), 0.01)
	m.add("p", "wood", C.PA(Kit.box(0.1, 0.1, 2.9, rx + 0.26, 2.0, rz), C.WOOD), 0.01)
	for i in 6:
		m.add("p", "thatch", C.PA(Kit.xf(Kit.cyl(0.13, 0.19, 1.5, 6), rx - 0.25, 0.75, rz - 1.1 + i * 0.44, 0, 0, 0.22), C.STRAW, 0.05, R), 0.01)
	m.box_c(rx - 0.6, rx + 0.4, rz - 1.5, rz + 1.5)
	# 낱 짚단 몇
	for i in 4:
		m.add("p", "thatch", C.PA(Kit.xf(Kit.cyl(0.14, 0.16, 0.8, 6), hy.x + 0.8 + R.between(-0.3, 0.3), 0.15, hy.z + R.between(-0.6, 0.6), 0, R.next() * 3, PI / 2), C.STRAW, 0.05, R), 0.008)

# ---- 마부 방: 작은 채(방·부엌), 지역 지붕 ----
static func _groom_house(m: C.M, p: Dictionary, roof: String, st: Dictionary) -> void:
	var hm: Vector3 = p.home
	var cx := hm.x; var cz := hm.z - 3.0
	var w := { x0 = cx - 2.7, x1 = cx + 2.7, z0 = cz - 1.7, z1 = cz + 1.7, face = "s", bays = "dk" if st.get("heavy", false) else "wdk",
		wall = st.wall, chimney = st.chim }
	if st.wall == "basalt": w.bays = "jk"
	var ro := { }
	if bool(st.get("rope", false)): ro.rope = 0.55
	if st.get("heavy", false): w.wall_h = 1.75
	CC.house(m, [w], roof, ro)

# ---- 안장 걸이·물동이·수레바퀴 같은 소품 ----
static func _props(m: C.M, p: Dictionary, R: Kit.Rng) -> void:
	# 안장 걸이(나무 틀 + 안장 둘·언치)
	var ax := -2.4; var az := 3.0
	for s in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.08, 1.1, 0.08), ax + s * 0.7, 0.5, az - 0.25, 0.25, 0, 0), C.WOOD), 0.008)
		m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.08, 1.1, 0.08), ax + s * 0.7, 0.5, az + 0.25, -0.25, 0, 0), C.WOOD), 0.008)
	m.add("p", "wood", C.PA(Kit.box(1.6, 0.08, 0.08, ax, 1.0, az), C.WOOD), 0.008)
	for s in [-1, 1]:
		m.add("p", "cloth", C.P(Kit.box(0.5, 0.5, 0.62, ax + s * 0.4, 0.85, az), 0x8e3a2c, 0x6e2a20, 0.03), 0.01)
		m.add("p", "wood", C.P(Kit.xf(Kit.lump(0.25, 0, R, 0.15, 0.6), ax + s * 0.4, 1.12, az), 0x4a2e1e, 0x3a2216), 0.01)
	m.box_c(ax - 0.85, ax + 0.85, az - 0.4, az + 0.4)
	# 물동이·여물통 몇
	for q in [[-5.2, 2.2], [3.6, -2.6]]:
		m.add("p", "wood", C.P(Kit.cyl(0.26, 0.22, 0.44, 8, q[0], 0.22, q[1]), 0x7a5c3e, 0x5a4430, 0.04), 0.01)
		m.circle(q[0], q[1], 0.3)
	# 여물 써는 작두(받침 + 날)
	m.add("p", "wood", C.P(Kit.box(1.0, 0.18, 0.3, -7.4, 0.09, 1.6), 0x6b5038, 0x4d3826, 0.04), 0.01)
	m.add("p", "flat", C.P(Kit.xf(Kit.box(0.9, 0.05, 0.08), -7.3, 0.32, 1.6, 0, 0, 0.3), 0x5a5a5e), 0.006)
