# 건물 빌더 고을 배치 틀(town template) — 필지마다 어떤 묶음·건물을 고를지(표)와, 대문이 길·골목을 보게 놓는 규칙.
#   쓰는 곳: tools/bldg/gallery_place.gd --set=town(견본 다섯 틀) · tools/bldg/rollout.gd(세계 구역 대문 돌리기 `gate_ry`)
#   틀 하나 = 로컬 좌표(가운데 원점, 길은 x축 z = 0 위, 폭 W) 위의 항목 목록 [{ tag, kit, params, x, z, ry }] — place()로 월드에 놓는다.
#   고증 요지(building-reference-map.md · building_refs.json):
#     장터   김홍도 「장터길」·김준근 장시 그림 — 길 양쪽 시전 행랑(가게 칸이 길로 트임) + 길 가운데·가장자리 좌판, 주막이 장 끝에, 우물이 모퉁이에
#     골목   신윤복 「월하정인」·「야금모행」 — 담과 담 사이 좁은 골목(3~4m), 대문이 골목으로 열리고 대문 안 내외담이 시선을 끊는다
#     주막거리 김홍도 「주막」·신윤복 「주사거배」 — 큰길가에 주막 마당이 길로 트이고, 대장간·초가가 섞인다
#     관아   「경기감영도 병풍」·읍성도 — 홍살문 → 외삼문(솟을삼문) → 동헌, 남북 축 + 둘레 담
#     우물   우물을 가운데 두고 집들이 둘러앉음(대문이 우물 쪽) — 빨래·평상
#   필지 표(TABLE): 틀 · 신분(cls) → [ [묶음 type, 무게] … ]. region(권역)은 그대로 넘겨 지붕·담 재료가 권역을 따른다.
extends RefCounted
const CP := preload("res://kit/bldg/compound.gd")
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")

const TABLE := {
	"alley": {
		"poor": [["choga_house", 1.0]],
		"commoner": [["choga_house", 0.6], ["jungnong", 0.25], ["giwa_house", 0.15]],
		"middle": [["giwa_house", 0.5], ["jungnong", 0.3], ["choga_house", 0.2]],
		"yangban": [["yangban", 0.6], ["giwa_house", 0.4]],
	},
	"well": { "commoner": [["choga_house", 0.75], ["jungnong", 0.25]], "middle": [["giwa_house", 0.5], ["choga_house", 0.5]] },
	"jumak": { "commoner": [["jumak_yard", 0.5], ["choga_house", 0.35], ["smithy", 0.15]] },
}

static func pick(template: String, cls: String, r: Kit.Rng) -> String:
	var t: Dictionary = TABLE.get(template, TABLE.alley)
	var rows: Array = t.get(cls, t.values()[0])
	var tot := 0.0
	for e in rows: tot += float(e[1])
	var x := r.next() * tot
	for e in rows:
		x -= float(e[1])
		if x <= 0.0: return String(e[0])
	return String(rows[rows.size() - 1][0])

static func _fp(kit: String, params: Dictionary) -> Vector2:
	return CP.footprint(params) if kit == "bldg/compound" else B.footprint(params)

# 길 양쪽 줄 채우기: 북쪽 줄(z < 0)은 남향(ry 0 — 대문 +z가 길), 남쪽 줄은 북향(ry π). 길 가장자리에서 back만큼 물림, 필지 사이 gap
static func _row(L: Array, picks: Array, side: int, W: float, x0: float, x1: float, gap: float, back: float) -> void:
	var x := x0
	for p in picks:
		var fp := _fp(String(p.kit), p.params)
		if x + fp.x > x1: break
		var cz: float = -(W / 2 + back + fp.y / 2) if side < 0 else (W / 2 + back + fp.y / 2)
		L.append({ tag = p.tag, kit = p.kit, params = p.params, x = snappedf(x + fp.x / 2, 0.01), z = snappedf(cz, 0.01), ry = 0.0 if side < 0 else PI, fp = [fp.x, fp.y] })
		x += fp.x + gap

static func layout(template: String, params: Dictionary) -> Dictionary:
	var region: String = params.get("region", "south")
	var cls: String = params.get("cls", "commoner")
	var seed: int = int(params.get("seed", 1))
	var len: float = float(params.get("len", 60.0))
	var r := Kit.Rng.new(seed * 7907 + hash(template) % 9973)
	var L := []
	var W := 4.0
	match template:
		"market":
			# 장터: 길 폭 7m, 북쪽 시전 행랑 두 채(가게 칸이 길로), 남쪽 시전 한 채 + 주막(장 끝), 길 가장자리 좌판 줄, 모퉁이 우물
			W = 7.0
			var picks_n := []
			for i in 3: picks_n.append({ tag = "sijeon_n%d" % i, kit = "bldg/building", params = { type = "sijeon", region = region, cls = "middle", seed = seed * 10 + i } })
			_row(L, picks_n, -1, W, -len / 2, len / 2, 2.2, 0.6)
			var picks_s := [{ tag = "sijeon_s0", kit = "bldg/building", params = { type = "sijeon", region = region, cls = "middle", seed = seed * 10 + 5 } },
				{ tag = "jumak", kit = "bldg/compound", params = { type = "jumak_yard", region = region, seed = seed * 10 + 6 } }]
			_row(L, picks_s, 1, W, -len / 2 + 4.0, len / 2, 3.0, 0.6)
			var goods := ["cloth", "onggi", "grain", "straw", "fish", "mixed"]
			var k := 0
			for side in [-1.0, 1.0]:
				var x := -len / 2 + 3.0
				while x < len / 2 - 3.0:
					if r.next() < 0.7:
						L.append({ tag = "jwapan%d" % k, kit = "village/jwapan", params = { seed = seed * 100 + k, goods = goods[k % goods.size()], awning = r.next() < 0.6 }, x = snappedf(x, 0.01), z = snappedf(side * (W / 2 - 1.1), 0.01), ry = 0.0 if side > 0 else PI })
						k += 1
					x += 3.4 + r.next() * 1.6
			L.append({ tag = "well", kit = "village/well", params = { seed = seed * 10 + 9, roof = true }, x = snappedf(len / 2 + 3.0, 0.01), z = 0.0, ry = 0.0 })
		"alley":
			# 골목: 폭 3.6m, 양쪽 담 집(대문이 골목으로) — 담과 담 사이 1.2~2m 틈(뒷길·처마 물받이), 골목 끝은 막힌 담 또는 다른 길
			W = 3.6
			var picks := [[], []]
			for side in 2:
				for i in 6:
					var t := pick("alley", cls, r)
					var p: Dictionary = { type = t, region = region, cls = cls if t != "choga_house" else "commoner", seed = seed * 20 + side * 10 + i }
					if t == "choga_house": p.wall = "todam_thatch" if r.next() < 0.75 else "stone"   # 읍내 골목은 흙담·돌담(싸리울은 마을 밖)
					picks[side].append({ tag = "%s%d_%d" % [t, side, i], kit = "bldg/compound", params = p })
			_row(L, picks[0], -1, W, -len / 2, len / 2, 1.4, 0.0)
			_row(L, picks[1], 1, W, -len / 2 + 5.0, len / 2, 1.6, 0.0)
		"jumak":
			# 주막거리: 큰길(폭 6m) 북쪽에 주막 마당 둘(길로 트임) + 대장간, 남쪽에 초가 집 + 주막
			W = 6.0
			var picks_n := []
			for i in 3:
				var t := pick("jumak", "commoner", r)
				if i == 0: t = "jumak_yard"
				picks_n.append({ tag = "%s_n%d" % [t, i], kit = "bldg/building" if t == "smithy" else "bldg/compound", params = { type = t, region = region, seed = seed * 10 + i } if t != "smithy" else { type = "smithy", region = region, seed = seed * 10 + i } })
			_row(L, picks_n, -1, W, -len / 2, len / 2, 2.5, 0.8)
			var picks_s := [{ tag = "choga_s0", kit = "bldg/compound", params = { type = "choga_house", region = region, seed = seed * 10 + 5 } },
				{ tag = "jumak_s1", kit = "bldg/compound", params = { type = "jumak_yard", region = region, seed = seed * 10 + 6 } }]
			_row(L, picks_s, 1, W, -len / 2 + 6.0, len / 2, 3.0, 0.8)
		"gwana":
			# 관아 구역(남북 축 — 길이 z축): 홍살문(z +34) → 외삼문(z +16, 둘레 담) → 동헌(담 안 북쪽, 남향) · 양옆 행랑
			var Wx := 34.0
			var zg := 16.0; var zb := -26.0
			L.append({ tag = "hongsal", kit = "bldg/gate", params = { type = "hongsal", seed = seed }, x = 0.0, z = 34.0, ry = 0.0 })
			var gp := { type = "samun", seed = seed, wall_h = 2.2 }
			L.append({ tag = "samun", kit = "bldg/gate", params = gp, x = 0.0, z = zg, ry = 0.0 })
			var hf := preload("res://kit/bldg/gate.gd").half(gp)
			for seg in [[-Wx / 2, zg, -hf, zg], [hf, zg, Wx / 2, zg], [-Wx / 2, zb, Wx / 2, zb], [-Wx / 2, zb, -Wx / 2, zg], [Wx / 2, zb, Wx / 2, zg]]:
				L.append({ tag = "wall%d" % L.size(), kit = "village/todam", params = { seed = seed + L.size(), ax = seg[0], az = seg[1], bx = seg[2], bz = seg[3], h = 2.2, cap = "tile", tile_seg = 0.5 }, x = 0.0, z = 0.0, ry = 0.0 })
			var dh := { type = "dongheon", region = region, seed = seed }
			var db := B.bounds(S.resolve(dh))
			L.append({ tag = "dongheon", kit = "bldg/building", params = dh, x = snappedf(-db.get_center().x, 0.01), z = snappedf(zb + 3.0 - db.position.y, 0.01), ry = 0.0 })
			for sx in [-1.0, 1.0]:
				var hp := { type = "haengrang", region = region, cls = "official", seed = seed + (3 if sx > 0 else 4) }
				var hb := B.bounds(S.resolve(hp))
				L.append({ tag = "haengrang%d" % int(sx), kit = "bldg/building", params = hp, x = snappedf(sx * (Wx / 2 - 1.2 - hb.size.y / 2), 0.01), z = snappedf((zg + zb) / 2 + 2.0, 0.01), ry = -sx * PI / 2 })
		"well":
			# 우물 블록: 가운데 우물 + 평상, 둘레 네 집이 우물을 보고 앉음(대문이 우물 쪽 — 마당 앞이 우물 마당)
			L.append({ tag = "well", kit = "village/well", params = { seed = seed, roof = r.next() < 0.5 }, x = 0.0, z = 0.0, ry = 0.0 })
			L.append({ tag = "pyeongsang", kit = "village/props", params = { seed = seed + 1, kind = "pyeongsang" }, x = 3.2, z = 2.0, ry = 0.4 })
			L.append({ tag = "laundry", kit = "village/yard_props", params = { seed = seed + 2, set = "jars" }, x = -3.0, z = -2.4, ry = 0.0 })
			var ang := [0.0, PI / 2, PI, -PI / 2]
			var ps := []; var hwmax := 0.0
			for i in 4:
				var t := pick("well", cls, r)
				var p: Dictionary = { type = t, region = region, cls = cls if t == "giwa_house" else "commoner", seed = seed * 10 + i }
				ps.append([t, p, CP.footprint(p)])
				hwmax = maxf(hwmax, (ps[i][2] as Vector2).x / 2)
			# 우물 마당 안쪽 거리: 이웃(90° 돌린) 집 반폭보다 멀어야 모서리끼리 겹치지 않는다
			var inner := maxf(6.5, hwmax + 0.8)
			for i in 4:
				var t: String = ps[i][0]; var p: Dictionary = ps[i][1]; var fp: Vector2 = ps[i][2]
				var d := inner + fp.y / 2
				# 집 대문(+z)이 우물(원점)을 보게: 자리 = 방향 a로 d만큼, ry = a + π(뒤가 바깥)
				var a: float = ang[i]
				var px := sin(a) * d; var pz := cos(a) * d
				L.append({ tag = "%s%d" % [t, i], kit = "bldg/compound", params = p, x = snappedf(px, 0.01), z = snappedf(pz, 0.01), ry = snappedf(a + PI, 0.0001), fp = [fp.x, fp.y] })
	return { items = L, road_w = W }

# 로컬 틀 → 월드(가운데 cx, cz, 돌림 ry)
static func place(items: Array, cx: float, cz: float, ry: float) -> Array:
	var out := []
	for e in items:
		var q: Dictionary = e.duplicate(true)
		var x := float(e.x); var z := float(e.z)
		q.x = snappedf(cx + x * cos(ry) + z * sin(ry), 0.01)
		q.z = snappedf(cz - x * sin(ry) + z * cos(ry), 0.01)
		q.ry = snappedf(float(e.ry) + ry, 0.0001)
		# 담 토막(점 params)은 조각 자리 0에 점이 들어 있으므로 점을 돌려 옮긴다
		# 담 토막(점 params): 항목 자리 = 토막 가운데(월드), 점은 그 자리 기준 상대 좌표로
		if (q.params as Dictionary).has("ax") and String(q.kit) in ["village/todam", "village/stone_wall", "village/fence"]:
			var w := []
			for k in ["a", "b"]:
				var px := float(e.params[k + "x"]); var pz := float(e.params[k + "z"])
				w.append(Vector2(cx + px * cos(ry) + pz * sin(ry), cz - px * sin(ry) + pz * cos(ry)))
			var mid: Vector2 = (w[0] + w[1]) / 2
			q.x = snappedf(mid.x, 0.01); q.z = snappedf(mid.y, 0.01); q.ry = 0.0
			q.params.ax = snappedf(w[0].x - mid.x, 0.01); q.params.az = snappedf(w[0].y - mid.y, 0.01)
			q.params.bx = snappedf(w[1].x - mid.x, 0.01); q.params.bz = snappedf(w[1].y - mid.y, 0.01)
		out.append(q)
	return out

# 대문 방향: 묶음 가운데 c(월드)에서 네 방향(0·90·180·270°, +z = ry 0) 중 대문 앞(문 앞 1~2.2m 띠)이 다른 필지에 막히지 않고
#   길(roads: [[x,z]…] 줄들)까지 가장 가까운 쪽. blocked(x, z) → 막힘이면 true. 반환 ry(라디안)
static func gate_ry(c: Vector2, half_d: Vector2, roads: Array, blocked: Callable) -> float:
	var best := 0.0; var best_score := INF
	for k in 4:
		var ry := k * PI / 2
		var dir := Vector2(sin(ry), cos(ry))
		var hd: float = half_d.y if k % 2 == 0 else half_d.x   # 그 방향 반깊이
		var free := true
		for s in [1.0, 2.2]:
			var p: Vector2 = c + dir * (hd + s)
			if blocked.call(p.x, p.y): free = false
		# 길까지: 대문 앞 점에서 가장 가까운 길 점까지 거리 + 방향이 길을 향하는지
		var g: Vector2 = c + dir * (hd + 1.0)
		var dmin := INF; var face := 0.0
		for line in roads:
			for i in range(line.size() - 1):
				var a := Vector2(line[i][0], line[i][1]); var b := Vector2(line[i + 1][0], line[i + 1][1])
				var ab := b - a
				var t := clampf((g - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0, 1)
				var q := a + ab * t
				var dd := g.distance_to(q)
				if dd < dmin: dmin = dd; face = dir.dot((q - c).normalized())
		var score := dmin - face * 6.0 + (0.0 if free else 1000.0)
		if score < best_score: best_score = score; best = ry
	return best
