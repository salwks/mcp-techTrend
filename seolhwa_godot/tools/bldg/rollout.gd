# 건물 빌더 세계 반영(rollout) — 남원 배치(placement_namwon.json)의 정한 구역에서 옛 village/house_compound를 bldg/compound로 바꾼다(헤드리스).
#   tools/bldg/rollout.sh west [--revert]   (= godot --headless --path . -s res://tools/bldg/rollout.gd -- --district=west → python3 tools/bldg/rollout_apply.py)
#   · 구역 표(DISTRICTS)에 든 항목만 바꾼다. 세계 전체를 바꾸지 않는다.
#   · 같은 자리·같은 필지(옛 footprint = lot) 안에서: 옛 small(초가) → choga_house, small(기와) → giwa_house, medium → jungnong(기와면 giwa_house)
#     시드는 옛 시드에서 시작해 필지 안에 드는 첫 시드를 고른다(결정적).
#   · 바꾼 항목에 was(옛 kit·params)·rollout 표시를 남긴다 → --revert로 되돌린다.
#   · 이야기 인물 집(STORY_IDS)은 건드리지 않는다. 손대야 하면 spec을 통째로 적어(시드 고정) 바뀌지 않게 한다.
#   · namwon.py로 배치를 다시 만들면 이 변경이 지워진다 → 그 뒤 이 도구를 다시 돌린다.
extends SceneTree
const CP := preload("res://kit/bldg/compound.gd")
const B := preload("res://kit/bldg/building.gd")
const TW := preload("res://kit/bldg/town.gd")

const FILE := "res://region_data/JL_NAMWON_UNBONG/placement_namwon.json"
const DISTRICTS := {
	# 서문 밖 장터길 민가 구역 — 남문 밖 장터에서 서문으로 돌아가는 장터길(namwon_market_lane) 서쪽과 성황사 오솔길 둘레
	#   gates(③): 대문(+z)을 길·골목 쪽으로 돌린다(kit/bldg/town.gd gate_ry — 대문 앞 띠가 비고 길이 가까운 쪽). 길 위에 앉은 옛 필지는 한 채로 비켜 앉힌다
	west = { bbox = [-3420.0, 200.0, -3322.0, 365.0], tag = "building-rollout-1/west", gates = true },
}
const STORY_IDS := []   # 이 구역엔 이야기 인물 집이 없다(이겸 거처 −3192,700 · 월매 집 둘레 −3213,450 · 옥 −3175,230 은 구역 밖)

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var dname: String = args.get("district", "west")
	var D: Dictionary = DISTRICTS[dname]
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	var n := 0
	var roads := _roads(D.bbox)
	var rects := []   # 다른 항목 자리(옛 필지 기준) — 대문 앞 띠가 막히나
	for it in d.items:
		var fp = (it.was.footprint if it.has("was") else it.get("footprint", null))
		if fp == null: continue
		rects.append([String(it.id), Vector2(float(it.x), float(it.z)), Vector2(float(fp[0]), float(fp[1])) / 2, float(it.was.get("ry", it.get("ry", 0.0))) if it.has("was") else float(it.get("ry", 0.0))])
	for it in d.items:
		var x := float(it.x); var z := float(it.z)
		var bb: Array = D.bbox
		if x < bb[0] or x > bb[2] or z < bb[1] or z > bb[3]: continue
		if String(it.id) in STORY_IDS: continue
		if args.has("revert"):
			if it.has("was"):
				it.kit = it.was.kit; it.params = it.was.params; it.footprint = it.was.footprint
				if it.was.has("ry"): it.ry = it.was.ry
				if it.was.has("x"): it.x = it.was.x; it.z = it.was.z
				it.erase("was"); it.erase("rollout"); it.reverted = true; n += 1
			continue
		# 늘 옛 항목(was)에서 다시 시작한다(여러 번 돌려도 같은 결과)
		var W0: Dictionary = it.was if it.has("was") else { kit = it.kit, params = it.params, footprint = it.get("footprint"), ry = float(it.get("ry", 0.0)), x = x, z = z }
		if not W0.has("ry"): W0.ry = float(it.get("ry", 0.0))
		if not W0.has("x"): W0.x = x; W0.z = z
		if String(W0.kit) != "village/house_compound": continue
		var old: Dictionary = W0.params
		var lot := Vector2(float(W0.footprint[0]), float(W0.footprint[1]))
		var c0 := Vector2(float(W0.x), float(W0.z))
		var giwa := String(old.get("roof", "")) == "giwa"
		var type := "giwa_house" if giwa else ("jungnong" if String(old.get("size", "small")) != "small" else "choga_house")
		var cls := "middle" if type != "choga_house" else "commoner"
		var ry_g := 0.0
		var single := {}
		if D.get("gates", false):
			# ③ 길 위에 앉은 필지(옛 배치가 길을 덮음): 묶음 대신 길을 비켜 앉는 한 채(길을 보게)
			var me := String(it.id)
			var blocked := func(px: float, pz: float) -> bool:
				for rc in rects:
					if rc[0] == me: continue
					var lp := (Vector2(px, pz) - (rc[1] as Vector2)).rotated(float(rc[3]))
					if absf(lp.x) < (rc[2] as Vector2).x + 0.3 and absf(lp.y) < (rc[2] as Vector2).y + 0.3: return true
				return false
			if _lot_hits_road(c0, lot / 2, float(W0.ry), roads):
				# 먼저 필지를 2m 안에서 길 밖으로 옮겨 본다(이웃 필지와 겹치지 않게) — 안 되면 한 채로
				var moved := false
				for rr in [0.5, 1.0, 1.5, 2.0]:
					for k in 8:
						var off := Vector2(cos(k * PI / 4), sin(k * PI / 4)) * float(rr)
						var c1 := c0 + off
						if _lot_hits_road(c1, lot / 2, float(W0.ry), roads): continue
						var clash := false
						for sx in [-1.0, 1.0]:
							for sz in [-1.0, 1.0]:
								var corner := c1 + Vector2(sx * lot.x / 2, sz * lot.y / 2).rotated(-float(W0.ry))
								if blocked.call(corner.x, corner.y): clash = true
						if not clash:
							c0 = c1; W0.x = W0.x; moved = true; break
					if moved: break
				if not moved: single = _single_off_road(c0, lot, float(W0.ry), roads, int(old.seed))
			if single.is_empty():
				var rp := []
				for line in roads: rp.append(line.slice(0, line.size() - 1))
				ry_g = TW.gate_ry(c0, lot / 2, rp, blocked)
		var pick := {}
		if single.is_empty():
			var llot := lot if int(round(ry_g / (PI / 2))) % 2 == 0 else Vector2(lot.y, lot.x)
			for tt in ([type] + (["choga_house"] if type == "jungnong" else []) + (["giwa_house", "choga_house"] if type == "giwa_house" else [])):
				pick = _fit(tt, "middle" if tt != "choga_house" else "commoner", int(old.seed), llot)
				if not pick.is_empty(): type = tt; break
			if pick.is_empty():
				print("ROLLOUT %s 필지 %.1f×%.1f에 드는 %s 시드 없음 — 그대로 둠" % [it.id, lot.x, lot.y, type]); continue
		it.was = W0
		if single.is_empty():
			it.kit = "bldg/compound"
			it.params = pick.params
			it.footprint = [snappedf(pick.fp.x, 0.1), snappedf(pick.fp.y, 0.1)]
			it.ry = snappedf(float(W0.ry) + ry_g, 0.0001)
			it.x = snappedf(c0.x, 0.01); it.z = snappedf(c0.y, 0.01)
		else:
			it.kit = "bldg/building"; it.params = single.params; it.footprint = [snappedf(single.fp.x, 0.1), snappedf(single.fp.y, 0.1)]
			it.ry = snappedf(single.ry, 0.0001); it.x = snappedf(single.x, 0.01); it.z = snappedf(single.z, 0.01)
		it.rollout = D.tag
		n += 1
		print("ROLLOUT %s %s → %s seed=%d fp=%s ry=%.0f° (필지 %.1f×%.1f)%s" % [it.id, "giwa" if giwa else String(old.get("size", "")), String(it.params.type), int(it.params.seed), str(it.footprint), rad_to_deg(float(it.ry)), lot.x, lot.y, " — 길 위 필지: 한 채로 비켜 앉음" if not single.is_empty() else ""])
	# 바뀐 항목만 따로 적는다 → tools/bldg/rollout_apply.py가 원본 json 형식(들여쓰기 1, 키 순서) 그대로 끼워 넣는다
	var ch := []
	for it in d.items:
		if it.has("was") or it.has("reverted"): ch.append(it)
	var out: String = args.get("out", "res://tools/bldg/rollout_%s.json" % dname)
	if not args.has("dry"):
		var f := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
		f.store_string(JSON.stringify({ district = dname, revert = args.has("revert"), items = ch }, " ", false))
		f.close()
	print("ROLLOUT done district=%s changed=%d%s" % [dname, n, " (dry)" if args.has("dry") else ""])
	quit()

static func _fit(type: String, cls: String, seed0: int, lot: Vector2) -> Dictionary:
	for k in 300:
		var p := { type = type, region = "south", cls = cls, seed = seed0 * 7 + k, lot = [lot.x, lot.y] }
		var fp: Vector2 = CP.footprint(p)
		if fp.x <= lot.x + 0.05 and fp.y <= lot.y + 0.05:
			return { params = p, fp = fp }
	return {}

# region.json 길(범위 + 40m 안 점이 있는 줄): [[ [x,z]… ], 폭] 대신 점 줄만(폭은 _lot_hits_road에서 따로)
static func _roads(bb: Array) -> Array:
	var r = JSON.parse_string(FileAccess.get_file_as_string("res://region_data/JL_NAMWON_UNBONG/region.json"))
	var out := []
	for rd in r.get("roads", []):
		var pts: Array = rd.get("points", [])
		var keep := false
		for p in pts:
			if float(p[0]) > float(bb[0]) - 40 and float(p[0]) < float(bb[2]) + 40 and float(p[1]) > float(bb[1]) - 40 and float(p[1]) < float(bb[3]) + 40: keep = true
		if keep:
			var line := []
			for p in pts: line.append([float(p[0]), float(p[1])])
			line.append(float(rd.get("width_m", 3.0)))   # 끝 칸 = 폭
			out.append(line)
	return out

static func _seg_dist_rect(a: Vector2, b: Vector2, c: Vector2, h: Vector2, ry: float) -> float:
	# 선분 ab와 돌린 사각(가운데 c, 반폭 h) 사이 거리(어림: 선분을 0.25m 간격으로 찍어 사각까지 거리 최소)
	var n := maxi(2, int(a.distance_to(b) / 0.25) + 1)
	var best := INF
	for i in n:
		var p := a.lerp(b, float(i) / (n - 1))
		var lp := (p - c).rotated(ry)
		var dx := maxf(absf(lp.x) - h.x, 0.0); var dz := maxf(absf(lp.y) - h.y, 0.0)
		best = minf(best, Vector2(dx, dz).length())
	return best

static func _lot_hits_road(c: Vector2, h: Vector2, ry: float, roads: Array) -> bool:
	for line in roads:
		var w: float = line[line.size() - 1]
		for i in range(line.size() - 2):
			if _seg_dist_rect(Vector2(line[i][0], line[i][1]), Vector2(line[i + 1][0], line[i + 1][1]), c, h, ry) < w / 2 + 0.3: return true
	return false

# 길 위 필지: 초가 한 채(남부 서민)를 필지 안 길을 비킨 자리에, 대문(앞)이 길을 보게. 0.5m 격자로 찾는다
static func _single_off_road(c: Vector2, lot: Vector2, ry0: float, roads: Array, seed0: int) -> Dictionary:
	var best := {}; var best_d := INF
	for k in 12:
		var params := { type = "choga", region = "south", cls = "commoner", seed = seed0 * 7 + k }
		var fp: Vector2 = B.footprint(params)
		for gx in range(-14, 15):
			for gz in range(-14, 15):
				var p := c + Vector2(gx, gz) * 0.5
				for q in 4:
					var ry := ry0 + q * PI / 2
					var hf := (fp / 2) if q % 2 == 0 else Vector2(fp.y, fp.x) / 2
					# 필지 안
					var lp := (p - c).rotated(ry0)
					if absf(lp.x) + hf.x > lot.x / 2 or absf(lp.y) + hf.y > lot.y / 2: continue
					if _lot_hits_road(p, fp / 2 + Vector2(0.6, 0.6), ry, roads): continue
					# 앞(+z 돌림)이 가장 가까운 길을 보나 · 길까지 거리
					var dir := Vector2(sin(ry), cos(ry))
					var g := p + dir * (fp.y / 2 + 1.0)
					var dmin := INF; var face := 0.0
					for line in roads:
						for i in range(line.size() - 2):
							var a := Vector2(line[i][0], line[i][1]); var b := Vector2(line[i + 1][0], line[i + 1][1])
							var ab := b - a
							var t := clampf((g - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0, 1)
							var qq := a + ab * t
							if g.distance_to(qq) < dmin: dmin = g.distance_to(qq); face = dir.dot((qq - p).normalized())
					var score := dmin - face * 6.0
					if score < best_d: best_d = score; best = { params = params, fp = fp, x = p.x, z = p.y, ry = ry }
		if not best.is_empty() and k >= 3: break
	return best
