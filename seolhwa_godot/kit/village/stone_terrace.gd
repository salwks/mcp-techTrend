# 계단식 돌축대 + 돌담 — 비탈 마을(산촌·사찰 아래)의 집터를 받치는 막돌 축대. 두 점 (ax,az)→(bx,bz) 사이(축대 줄).
# 원점 높이 = 위 단(집터) 땅. 축대는 그 앞(+z 쪽, a→b 왼쪽→오른쪽 기준 앞)으로 tiers 단을 내려가며, 맨 위 단 끝에 낮은 돌담.
# 고증: 지리산 산간 마을은 비탈을 막돌 축대로 깎아 단을 만들고 집과 다랑이 밭을 앉혔다. 축대 위 돌담은 허리 높이(약 1m).
# origin: "top"(기본, 원점 = 위 단 땅) | "bottom"(원점 = 맨 아래 땅, 위 단 흙판 2m를 함께 그림 — 미리보기·평지 배치용)
# params: seed, ax,az,bx,bz (없으면 len(6) x축), drop(1.6: 전체 높이), tiers(2), step(0.9: 단 사이 들여쌓기 깊이), wall(true: 위 돌담), wall_h(1.0)
# 삼각형: 약 220/m(2단 + 담). 긴 비탈은 여러 토막.
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const SW := preload("res://kit/village/stone_wall.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 6.0)
	var ax: float = params.get("ax", -L / 2); var az: float = params.get("az", 0.0)
	var bx: float = params.get("bx", L / 2); var bz: float = params.get("bz", 0.0)
	var tiers: int = params.get("tiers", 2); var step: float = params.get("step", 0.9)
	var drop: float = params.get("drop", 1.6)
	if params.get("origin", "top") == "bottom":
		m.push(0, drop, 0)
		var old := m.xform
		m.xform = old * C.seg_xform(ax, az, bx, bz)
		var L2 := Vector2(bx - ax, bz - az).length()
		m.add("p", "mud", C.P(Kit.box(L2, drop, 2.0, 0, -drop / 2, -1.0), 0xa89470, 0x8f7c5c, 0.04, m.rng), 0.02)
		m.xform = old
	draw(m, ax, az, bx, bz, drop, tiers, step, params.get("wall", true), params.get("wall_h", 1.0))
	var dz := tiers * step + 0.6
	return m.result("돌축대", Vector2(absf(bx - ax) + 0.6, absf(bz - az) + dz), true)

static func draw(m: C.M, ax: float, az: float, bx: float, bz: float, drop := 1.6, tiers := 2, step := 0.9, wall := true, wall_h := 1.0) -> void:
	var len := Vector2(bx - ax, bz - az).length()
	var R := m.rng
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz)
	var th := drop / tiers
	var faces := []
	var stones := []
	for k in tiers:
		var zf := 0.0 + k * step          # 축대 면 z(앞으로 갈수록 낮음)
		var y1 := -k * th; var y0 := y1 - th
		# 면(살짝 뒤로 기운 막돌 벽) + 단 위 흙
		var g := Kit.Geo.new()
		var bat := 0.18
		C.qf(g, Vector3(-len / 2, y0, zf + bat), Vector3(len / 2, y0, zf + bat), Vector3(len / 2, y1, zf), Vector3(-len / 2, y1, zf), Vector3.BACK)
		for sx in [-1.0, 1.0]:
			C.tf(g, Vector3(sx * len / 2, y0, zf + bat), Vector3(sx * len / 2, y1, zf), Vector3(sx * len / 2, y0, zf - step), Vector3(sx, 0, 0))
			C.qf(g, Vector3(sx * len / 2, y1, zf), Vector3(sx * len / 2, y1, zf - step), Vector3(sx * len / 2, y0, zf - step), Vector3(sx * len / 2, y0, zf), Vector3(sx, 0, 0))
		faces.append(C.P(g, 0x9a9384, 0x77705f, 0.04, R))
		if k > 0:
			var e := Kit.Geo.new()
			C.qf(e, Vector3(-len / 2, y1, zf - step), Vector3(len / 2, y1, zf - step), Vector3(len / 2, y1, zf), Vector3(-len / 2, y1, zf), Vector3.UP)
			m.add("p", "mud", C.P(e, 0xa89470, 0x8f7c5c, 0.04, R), 0)
		# 막돌(면에 박힌 큰 돌, 엇갈려 두 줄)
		var rows := maxi(1, roundi(th / 0.45))
		for row in rows:
			var n := maxi(2, roundi(len / 0.6))
			for i in n:
				var x := -len / 2 + (i + 0.5 + (row % 2) * 0.45) * len / n
				if x > len / 2 - 0.2: continue
				var y := y0 + (row + 0.5) * th / rows
				var zz := zf + bat * (1.0 - (y - y0) / th) + 0.04
				var lg := Kit.lump(R.between(0.2, 0.27), 0, R, 0.35, 0.8)
				stones.append(C.P(Kit.xf(lg, x, y, zz, 0, R.next() * 3, 0, 1.2, 1.0, 0.5), 0xb6ae9e, 0x8a8374, 0.08, R))
	m.add("p", "stone", Kit.merge(faces), 0.03)
	m.add("p", "stone", Kit.merge(stones), 0.018)
	m.xform = old
	# 맨 위 단 끝 돌담(축대 바로 뒤)
	if wall:
		var off := Vector2(bx - ax, bz - az).normalized().orthogonal() * 0.35   # orthogonal() = 로컬 -z(뒤)
		SW.draw(m, ax + off.x, az + off.y, bx + off.x, bz + off.y, wall_h, true, true)
	else:
		SW.add_line_collider(m, ax, az, bx, bz, 0.3)
