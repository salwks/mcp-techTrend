# EventCrowd(제작 규칙 C60 · F-17 최소판) — 축제·잔치처럼 사건 때만 사람이 늘어나는 장면 채우기. 군중 시뮬레이션이 아니다.
#
#   선언(데이터): 배치 파일(placement_*.json)의 "crowds" 또는 사건 데이터의 "crowds" —
#     { id, preset, area:{ rects:{이름:[x0,z0,x1,z1]}, exclude:[{rect:[…]}|{circle:[x,z,r]}], dy:{이름: 높이} },
#       density:"low|medium|high", count(선택) 또는 density_start:{이름: 인원}(구역 몫), roles:{동작: 비율}(선택 — 없으면 preset),
#       bank:[[CHR, kind]…], watch_targets:{구역: 앵커}, seed, when, far_freeze_m(선택) }
#   preset(공통): festival(idle·talk·walk·watch) · banquet(sit·stand·serve·watch). 구역·인원·seed·when은 사건 데이터가 정한다.
#   density: low 6~10 · medium 10~18 · high 18~30 — 인원은 이 범위로 자른다(count/density_start 합이 없으면 가운데 값).
#   배치: seed 하나로 결정적(같은 seed → 같은 자리·사람·동작). 사각형 안, 빼는 곳(사각형·원) 밖, 서로 0.9m 이상. 세계 충돌체는 보지 않는다
#     (스트리밍 상태에 따라 달라지지 않게) — 가게·좌판·통로는 데이터의 exclude로 뺀다.
#   사람: generic bank만(GENERIC). 이야기 인물(사건 actor) 그림은 넣지 않는다 — 허용 목록 밖 kind는 버리고 알린다.
#   동작: idle · talk(마주 봄) · watch(구역의 앵커 쪽을 봄) · walk(제자리에서 2~5m 오가기) · sit · stand · serve(구역 안 두 점 오가기).
#     sit은 공용 자세 sit(data/frames_pose.json — 모든 사람 종류, SpriteChar.ensure_poses)를 그대로 쓴다. serve는 끝에서 잠깐 설 때
#     그 그림에 serve 동작(기생 — 술병 들고 따름)이 있으면 그것을.
#   짜임(선택, 잔치·제사처럼 누가 어디 앉는지 정해진 장면): rect_roles:{구역: ["sit:guest", "serve:gisaeng", …]}(구역 몫 순서대로
#     역할:묶음) + banks:{묶음: [[CHR, kind]…]}(묶음 안에서 돌아가며 — 같은 색 기생이 몰리지 않게) + seats:{구역: [[x, z, facing]…]}
#     (sit은 자리 순서대로 앉는다). 묶음 이름이 사람의 tag가 된다. 없으면 예전대로 roles 비율 + bank에서 고름.
#   자세 바꾸기(제자리, 같은 사람): set_pose(id, filter, pose) — filter는 역할·tag·kind(또는 그 배열, "" = 모두). 출두 반전처럼
#     서 있던·앉아 있던 사람이 그 자리에서 bow·kneel로. 노드·자리·사람은 그대로 두고(다시 짜지 않음) 오가기만 멈춘다.
#     apply_on_flag(id, flag): 선언의 on_flag:{flag: {역할: 자세}}를 한 번에. clear_pose(id)로 원래 동작.
#   보이기: when(placement_gate.gd — 같은 조건 언어, 사건·변수가 바뀔 때만)이 참일 때. force(id, on, density)는 when을 덮는다(시험·촬영).
#     디버그: --crowdshow=dano_market:high,byeon_banquet:medium
#   비용: LOD 거리 = min(플레이어까지, 지금 카메라의 땅 위 자리까지) — 카메라의 땅 위 자리는 카메라 자리(x,z)와 카메라가 겨냥한 점(x,z) 둘
#     (망원 각본 시점은 카메라 앞 70~85m까지 담는다 — 1A). 평소에는 겨냥점이 플레이어(+앞보기 1.2m)라 예전과 같고,
#     카메라만 멀리 가는 컷(각본 시점)에서는 카메라가 보는 군중이 살아 있다(플레이어를 옮기지 않는다).
#     그 거리가 far_freeze_m 밖이면 숨김(그림·갱신 없음), 화면 밖은 멈춤(갱신 없음), far_freeze_m의 절반 밖은 세 프레임에 한 번 갱신.
#   만들지 않는 것: AI·생활 스케줄·길찾기·충돌 회피·반응(제작 규칙 C60).
extends Node3D

const PlacementGate := preload("res://scripts/region/placement_gate.gd")

const DENSITY := { low = [6, 10], medium = [10, 18], high = [18, 30] }
const PRESETS := {
	festival = { roles = { idle = 0.3, talk = 0.25, walk = 0.2, watch = 0.25 }, far_freeze_m = 60.0 },
	banquet = { roles = { sit = 0.45, stand = 0.25, serve = 0.15, watch = 0.15 }, far_freeze_m = 40.0 },
}
const ACTIONS := ["idle", "talk", "watch", "walk", "sit", "stand", "serve"]
# 군중에 쓸 수 있는 바탕 그림(고을 사람과 같은 generic bank + 관속·포졸·서리·기생 generic). 이야기 인물 고유 그림은 여기 없다
const GENERIC := ["villager_m", "villager_f", "elder", "child_boy", "child_girl", "hunter", "innkeeper", "miller", "woodcutter",
	"scholar", "merchant", "peddler", "official", "monk", "bosal", "boatman", "haenyeo", "farmer", "farmwife", "herder", "traveler",
	"pojol", "py_clerk", "gisaeng", "gisaeng_b", "gisaeng_c"]
const BANK_FALLBACK := { gisaeng = "villager_f", gisaeng_b = "gisaeng", gisaeng_c = "gisaeng", py_clerk = "official", pojol = "official", farmer = "villager_m", farmwife = "villager_f",
	scholar = "elder", merchant = "villager_m", peddler = "woodcutter", official = "hunter", traveler = "villager_m" }
const MIN_GAP := 0.9
const SHADOW_M := 30.0

var main = null
var gate = null
var crowds := {}          # id → { spec, members:[], on, gated_on, forced, density, built }
var stats := { shown = 0, active = 0, frozen = 0, hidden = 0, reduced = 0 }
var _frame := 0
var _bank_src := {}

func setup(m) -> void:
	main = m
	name = "event_crowd"
	gate = m.placement.gate if m.get("placement") != null else PlacementGate.new()
	rebuild()

# 배치 파일·사건 데이터의 선언을 다시 읽는다(배치 다시 읽기 뒤에도)
func rebuild() -> void:
	for id in crowds: _free_members(crowds[id])
	crowds.clear()
	var specs: Array = []
	if main.get("placement") != null: specs.append_array(main.placement.crowds)
	var st = main.get("story")
	if st != null and st.data is Dictionary:
		for c in st.data.get("crowds", []):
			if c is Dictionary and c.has("id"):
				var cc: Dictionary = c.duplicate(true)
				if not cc.has("case"): cc["case"] = String(st.case_id)
				if not cc.has("_anchors"): cc["_anchors"] = st.data.get("anchors", {})
				specs.append(cc)
	for spec in specs:
		var id := String(spec.id)
		var all_bank: Array = (spec.get("bank", []) as Array).duplicate()
		for g in (spec.get("banks", {}) as Dictionary): all_bank.append_array(spec.banks[g])
		for b in all_bank:
			var kind := String(b[1]) if b is Array and b.size() > 1 else String(b)
			if not (kind in GENERIC): push_warning("EventCrowd %s: 이야기 인물·모르는 그림은 군중에 넣지 않는다 — 뺌: %s" % [id, kind])
		crowds[id] = { spec = spec, members = [], on = false, gated_on = false, forced = null, density = "", built = false }
		var cid := id
		gate.add("crowd:" + id, spec.get("when", ""), String(spec.get("case", "")), func(on: bool) -> void: _gated(cid, on))
	var arg := String(main.args.get("crowdshow", "")) if main.get("args") is Dictionary else ""
	for part in arg.split(",", false):
		var kv := part.split(":")
		force(kv[0], true, kv[1] if kv.size() > 1 else "")

func ids() -> Array: return crowds.keys()
func is_shown(id: String) -> bool: return bool(crowds.get(id, {}).get("on", false))
func members(id: String) -> Array: return crowds.get(id, {}).get("members", [])

# 시험·촬영: when을 덮어 켜고 끈다(density를 주면 그 밀도로 다시 짠다). on = null이면 덮어쓰기를 풀고 when을 따른다
func force(id: String, on, density := "") -> void:
	if not crowds.has(id):
		push_warning("EventCrowd: 모르는 군중 " + id); return
	var c: Dictionary = crowds[id]
	if density != "" and density != c.density:
		_free_members(c); c.built = false; c.density = density
	c.forced = on
	_apply(id)

func _gated(id: String, on: bool) -> void:
	if not crowds.has(id): return
	crowds[id].gated_on = on
	_apply(id)

func _apply(id: String) -> void:
	var c: Dictionary = crowds[id]
	var want: bool = bool(c.forced) if c.forced != null else bool(c.gated_on)
	if want and not c.built: _build(c)
	c.on = want
	for m in c.members:
		if m.ch != null: m.ch.visible = false
		m.lod = "hidden"

# ---------------------------------------------------------------------------
# 결정적 배치(seed) — 노드 없이 계획만(시험에서 그대로 비교)
# ---------------------------------------------------------------------------
# 인원: 선언 밀도면 count(또는 density_start 합, 없으면 범위 가운데)를 범위로 자른 값.
# density에 다른 밀도 이름을 주면 그 범위의 위 끝(성능 시험용 최악), 숫자를 주면 그 수 그대로(시험·성능)
static func count_for(spec: Dictionary, density := "") -> int:
	if density.is_valid_int(): return int(density)
	var base := String(spec.get("density", "medium"))
	var dk := density if density != "" else base
	var rg: Array = DENSITY.get(dk, DENSITY.medium)
	if dk != base: return int(rg[1])
	var want := -1
	if spec.has("count"): want = int(spec.count)
	elif spec.get("density_start") is Dictionary:
		want = 0
		for k in spec.density_start: want += int(spec.density_start[k])
	if want < 0: want = (int(rg[0]) + int(rg[1])) / 2
	return clampi(want, int(rg[0]), int(rg[1]))

static func plan(spec: Dictionary, density := "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1))
	var area: Dictionary = spec.get("area", {})
	var rects: Dictionary = area.get("rects", {})
	var names: Array = rects.keys(); names.sort()
	if names.is_empty(): return []
	var n := count_for(spec, density)
	# 구역 몫: density_start 비율(없으면 넓이 비율) → 큰 나머지 순으로 반올림
	var w := {}; var tot := 0.0
	for nm in names:
		var r: Array = rects[nm]
		var share := float((spec.get("density_start", {}) as Dictionary).get(nm, -1.0))
		if share < 0.0: share = absf((float(r[2]) - float(r[0])) * (float(r[3]) - float(r[1])))
		w[nm] = share; tot += share
	var alloc := {}; var rem := []; var used := 0
	for nm in names:
		var exact := float(n) * float(w[nm]) / maxf(tot, 0.001)
		alloc[nm] = int(floor(exact)); used += int(alloc[nm])
		rem.append([exact - floor(exact), nm])
	rem.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and String(a[1]) < String(b[1])))
	var ri := 0
	while used < n and not rem.is_empty():
		alloc[rem[ri % rem.size()][1]] += 1; used += 1; ri += 1
	var roles: Dictionary = spec.get("roles", PRESETS.get(String(spec.get("preset", "festival")), PRESETS.festival).roles)
	var role_keys: Array = roles.keys(); role_keys.sort()
	var bank: Array = []
	for b in spec.get("bank", []):
		var kind := String(b[1]) if b is Array and b.size() > 1 else String(b)
		if kind in GENERIC: bank.append(kind)
	if bank.is_empty(): bank = ["villager_m", "villager_f"]
	var dys: Dictionary = area.get("dy", {})
	var out := []
	var pts: Array = []
	if spec.get("rect_roles") is Dictionary:
		_plan_cast(spec, rng, names, alloc, rects, dys, out, pts)
	for nm in names:
		if spec.get("rect_roles") is Dictionary: break
		var r: Array = rects[nm]
		for k in int(alloc[nm]):
			var p = null
			for tries in 80:
				var q := Vector2(lerpf(float(r[0]), float(r[2]), rng.randf()), lerpf(float(r[1]), float(r[3]), rng.randf()))
				if _excluded(area, q): continue
				var ok := true
				for o in pts:
					if (o as Vector2).distance_to(q) < MIN_GAP: ok = false; break
				if ok: p = q; break
			if p == null: continue
			pts.append(p)
			var role := _pick(rng, roles, role_keys)
			var kind: String = bank[rng.randi() % bank.size()]
			var m := { rect = nm, home = p, role = role, kind = kind, dy = float(dys.get(nm, 0.0)),
				facing = ["down", "left", "right", "up"][rng.randi() % 4], t0 = rng.randf() * 3.0 }
			if role in ["walk", "serve"]:
				var b2 = null
				for tries in 30:
					var q: Vector2
					if role == "walk":
						var a := rng.randf() * TAU
						q = p + Vector2(cos(a), sin(a)) * lerpf(2.0, 5.0, rng.randf())
					else:
						q = Vector2(lerpf(float(r[0]), float(r[2]), rng.randf()), lerpf(float(r[1]), float(r[3]), rng.randf()))
					if q.x < float(r[0]) or q.x > float(r[2]) or q.y < float(r[1]) or q.y > float(r[3]) or _excluded(area, q): continue
					b2 = q; break
				m.b = b2 if b2 != null else p
			out.append(m)
	_walk_ends(spec, rng, rects, out)
	# 마주 보기(talk: 가장 가까운 사람 쪽) · 구경(watch: 구역 앵커 쪽)
	var anchors: Dictionary = spec.get("_anchors", {})
	var targets: Dictionary = spec.get("watch_targets", {})
	for m in out:
		if m.role == "talk":
			var best = null; var bd := 1e9
			for o in out:
				if o == m: continue
				var dd: float = (o.home as Vector2).distance_to(m.home)
				if dd < bd: bd = dd; best = o
			if best != null and bd < 4.0: m.facing = _face((best.home as Vector2) - (m.home as Vector2), m.facing)
		elif m.has("seat"): continue                 # 정해진 자리는 그 자리의 방향
		elif m.role in ["watch", "sit", "stand"]:   # 구경·앉음·섬: 구역 앵커(씨름판·안마당 가운데) 쪽을 본다
			var tg = targets.get(m.rect)
			var at = anchors.get(tg, {}).get("at") if tg != null and anchors.get(tg) is Dictionary else null
			if at is Array: m.facing = _face(Vector2(float(at[0]), float(at[1])) - (m.home as Vector2), m.facing)
	return out

# 짜임 있는 군중(rect_roles): 구역 몫 순서대로 "역할:묶음", 묶음 안에서 돌아가며 kind, sit은 seats 순서대로
static func _plan_cast(spec: Dictionary, rng: RandomNumberGenerator, names: Array, alloc: Dictionary, rects: Dictionary, dys: Dictionary, out: Array, pts: Array) -> void:
	var rr: Dictionary = spec.rect_roles
	var banks: Dictionary = spec.get("banks", {})
	var seats: Dictionary = spec.get("seats", {})
	var turn := {}   # 묶음 → 다음 차례(seed로 시작점)
	var area: Dictionary = spec.get("area", {})
	for nm in names:
		var r: Array = rects[nm]
		var lst: Array = rr.get(nm, [])
		var seat_i := 0
		var todo := []
		for k in int(alloc[nm]):
			var ent := String(lst[k % lst.size()]) if not lst.is_empty() else "idle"
			var pr := ent.split(":")
			todo.append([pr[0], pr[1] if pr.size() > 1 else ""])
		# 앉는 사람(자리 있는 것) 먼저 — 나머지가 자리를 피해 선다
		todo.sort_custom(func(a, b): return int(a[0] == "sit") > int(b[0] == "sit"))
		for td in todo:
			var role: String = td[0]
			var grp: String = td[1]
			var lstb: Array = []
			for b in banks.get(grp, spec.get("bank", [])):
				var kind := String(b[1]) if b is Array and b.size() > 1 else String(b)
				if kind in GENERIC: lstb.append(kind)
			if lstb.is_empty(): lstb = ["villager_m", "villager_f"]
			if not turn.has(grp): turn[grp] = rng.randi() % lstb.size()
			var kind: String = lstb[int(turn[grp]) % lstb.size()]
			turn[grp] = int(turn[grp]) + 1
			var p = null
			var facing: String = ["down", "left", "right", "up"][rng.randi() % 4]
			var seat = null
			var sl: Array = seats.get(nm, [])
			if role == "sit" and seat_i < sl.size():
				seat = sl[seat_i]; seat_i += 1
				p = Vector2(float(seat[0]), float(seat[1]))
				if seat.size() > 2: facing = String(seat[2])
			else:
				for tries in 80:
					var q := Vector2(lerpf(float(r[0]), float(r[2]), rng.randf()), lerpf(float(r[1]), float(r[3]), rng.randf()))
					if _excluded(area, q): continue
					var ok := true
					for o in pts:
						if (o as Vector2).distance_to(q) < MIN_GAP: ok = false; break
					if ok: p = q; break
			if p == null: continue
			pts.append(p)
			var m := { rect = nm, home = p, role = role, kind = kind, tag = grp if grp != "" else role, dy = float(dys.get(nm, 0.0)),
				facing = facing, t0 = rng.randf() * 3.0 }
			if seat != null: m.seat = true
			out.append(m)

# 오가기(walk·serve)의 다른 끝(짜임 있는 군중 — 예전 길은 배치 때 바로 정한다)
static func _walk_ends(spec: Dictionary, rng: RandomNumberGenerator, rects: Dictionary, out: Array) -> void:
	var area: Dictionary = spec.get("area", {})
	for m in out:
		if m.has("b") or not (m.role in ["walk", "serve"]): continue
		var r: Array = rects[m.rect]
		var p: Vector2 = m.home
		var b2 = null
		for tries in 30:
			var q: Vector2
			if m.role == "walk":
				var a := rng.randf() * TAU
				q = p + Vector2(cos(a), sin(a)) * lerpf(2.0, 5.0, rng.randf())
			else:
				q = Vector2(lerpf(float(r[0]), float(r[2]), rng.randf()), lerpf(float(r[1]), float(r[3]), rng.randf()))
			if q.x < float(r[0]) or q.x > float(r[2]) or q.y < float(r[1]) or q.y > float(r[3]) or _excluded(area, q): continue
			b2 = q; break
		m.b = b2 if b2 != null else p

static func _pick(rng: RandomNumberGenerator, roles: Dictionary, keys: Array) -> String:
	var tot := 0.0
	for k in keys: tot += float(roles[k])
	var x := rng.randf() * tot
	for k in keys:
		x -= float(roles[k])
		if x <= 0.0: return String(k)
	return String(keys[keys.size() - 1])

static func _excluded(area: Dictionary, p: Vector2) -> bool:
	for e in area.get("exclude", []):
		if not (e is Dictionary): continue
		if e.get("rect") is Array:
			var r: Array = e.rect
			if p.x >= float(r[0]) and p.x <= float(r[2]) and p.y >= float(r[1]) and p.y <= float(r[3]): return true
		elif e.get("circle") is Array:
			var c: Array = e.circle
			if p.distance_to(Vector2(float(c[0]), float(c[1]))) <= float(c[2]): return true
	return false

static func _face(v: Vector2, prev: String) -> String:
	if v.length() < 0.01: return prev
	if absf(v.x) > absf(v.y) * 1.05: return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"

# ---------------------------------------------------------------------------
# 노드
# ---------------------------------------------------------------------------
func _build(c: Dictionary) -> void:
	c.built = true
	c.members = []
	for p in plan(c.spec, c.density):
		var m: Dictionary = p.duplicate()
		var bank := _ensure_bank(String(m.kind))
		m.ch = null
		m.bank = bank
		m.pos2 = m.home
		m.dir = 1.0
		m.wait = float(m.t0)
		m.lod = "hidden"
		m.acc = 0.0
		c.members.append(m)

func _make_char(m: Dictionary) -> void:
	if m.bank == "": return
	var ch := SpriteChar.new(String(m.bank))
	add_child(ch)
	ch.set_silhouette(false)
	ch.facing = String(m.facing)
	var anim := _role_anim(String(m.role))
	if m.get("pose", "") != "": anim = String(m.pose)
	ch.play(anim if ch.has_anim(anim) else "idle", true)
	ch.anim_time = float(m.t0)
	ch.t = float(m.t0) * 1.7
	ch.visible = false
	m.ch = ch
	_place(m)

func _place(m: Dictionary) -> void:
	var w = main.world
	var p: Vector2 = m.pos2
	m.ch.position = Vector3(p.x, (w.ground_at(p.x, p.y) if float(m.dy) > 0.0 else w.height_at(p.x, p.y)) + float(m.dy), p.y)

static func _role_anim(role: String) -> String:
	match role:
		"talk": return "talk"
		"sit": return "sit"
	return "idle"

# ---------------------------------------------------------------------------
# 자세 바꾸기(제자리, 같은 사람) — 출두 반전: stand/sit → bow/kneel. 노드를 새로 만들지 않는다
# ---------------------------------------------------------------------------
static func member_match(m: Dictionary, filter) -> bool:
	if filter is Array:
		for f in filter:
			if member_match(m, f): return true
		return false
	var f := String(filter)
	return f == "" or f == "*" or f == String(m.role) or f == String(m.get("tag", "")) or f == String(m.kind)

# filter에 맞는 사람의 자세를 pose로. 돌려주는 값: 바뀐 사람 수
func set_pose(id: String, filter, pose: String) -> int:
	if not crowds.has(id): return 0
	var n := 0
	for m in crowds[id].members:
		if not member_match(m, filter): continue
		m.pose = pose
		n += 1
		if m.get("ch") != null and is_instance_valid(m.ch):
			m.ch.play(pose if m.ch.has_anim(pose) else "idle", true)
	return n

func clear_pose(id: String, filter = "") -> int:
	if not crowds.has(id): return 0
	var n := 0
	for m in crowds[id].members:
		if not member_match(m, filter) or not m.has("pose"): continue
		m.erase("pose")
		n += 1
		if m.get("ch") != null and is_instance_valid(m.ch): m.ch.play(_role_anim(String(m.role)), true)
	return n

# 선언의 on_flag:{flag: {역할: 자세}} — 예: byeon_banquet royal_inspector_reveal {sit: kneel, stand: bow, serve: bow, watch: bow}
func apply_on_flag(id: String, flag: String) -> int:
	if not crowds.has(id): return 0
	var mp = crowds[id].spec.get("on_flag", {}).get(flag)
	if not (mp is Dictionary): return 0
	var n := 0
	for role in mp: n += set_pose(id, String(role), String(mp[role]))
	return n

func _free_members(c: Dictionary) -> void:
	for m in c.get("members", []):
		if m.get("ch") != null and is_instance_valid(m.ch): m.ch.queue_free()
	c.members = []

func _ensure_bank(kind: String) -> String:
	if SpriteChar._banks.has(kind): return kind
	if _bank_src.is_empty():
		for jf in preload("res://scripts/story/story_director.gd").BANK_FILES:
			var path: String = "res://data/" + jf
			if not FileAccess.file_exists(path): continue
			var all = JSON.parse_string(FileAccess.get_file_as_string(path))
			if all is Dictionary:
				for k in all:
					if not _bank_src.has(k): _bank_src[k] = all[k]
	if _bank_src.has(kind):
		var pages := []
		for pg in _bank_src[kind].pages:
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://data/" + pg))
			if img == null or img.is_empty(): continue
			img.generate_mipmaps()
			pages.append(ImageTexture.create_from_image(img))
		SpriteChar._banks[kind] = { pages = pages, clips = _bank_src[kind].clips }
		return kind
	if BANK_FALLBACK.has(kind): return _ensure_bank(BANK_FALLBACK[kind])
	return "villager_m" if kind != "villager_m" and _bank_src.has("villager_m") else ""

# ---------------------------------------------------------------------------
# 프레임: 먼 사람 숨김 · 화면 밖 멈춤 · 중간 거리 세 프레임에 한 번
# ---------------------------------------------------------------------------
func update(dt: float) -> void:
	_frame += 1
	var shown := 0; var act := 0; var frz := 0; var hid := 0; var red := 0
	var cam: Camera3D = main.cam
	var pp: Vector3 = main.player_pos
	var cg := cam_ground()   # 카메라의 땅 위 자리 둘(카메라 x,z · 겨냥점 x,z)
	for id in crowds:
		var c: Dictionary = crowds[id]
		if not c.on: continue
		var far := float(c.spec.get("far_freeze_m", PRESETS.get(String(c.spec.get("preset", "festival")), PRESETS.festival).far_freeze_m))
		for m in c.members:
			var p2: Vector2 = m.pos2
			var d := lod_dist(p2, Vector2(pp.x, pp.z), cg)
			if d > far:
				if m.ch != null and m.ch.visible: m.ch.visible = false
				m.lod = "hidden"; hid += 1
				continue
			if m.ch == null: _make_char(m)
			if m.ch == null: continue
			if not m.ch.visible:
				m.ch.visible = true
				m.ch._sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if d < SHADOW_M else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				m.ch.update_char(0.0, cam)   # 첫 그림(화면 밖에서 멈춰 있어도 들어올 때 빈 판이 아니게)
			shown += 1
			if not _in_view(cam, m.ch.position + Vector3(0, 1.0, 0)):
				m.lod = "frozen"; frz += 1
				continue
			m.acc += dt
			if d > far * 0.5 and (_frame + int(m.t0 * 10.0)) % 3 != 0:
				m.lod = "reduced"; red += 1
				continue
			m.lod = "active"; act += 1
			var a: float = m.acc
			m.acc = 0.0
			_step(m, a)
			m.ch.update_char(a, cam)
	stats = { shown = shown, active = act, frozen = frz, hidden = hid, reduced = red }

# LOD 거리(C60): min(플레이어까지, 카메라의 땅 위 자리까지)
static func lod_dist(p2: Vector2, player: Vector2, cam_pts: Array) -> float:
	var d := p2.distance_to(player)
	for c in cam_pts: d = minf(d, p2.distance_to(c))
	return d

# 지금 카메라의 땅 위 자리: 카메라 자리(x,z)와 겨냥점(x,z — 각본 시점이면 look, 아니면 rig.target)
func cam_ground() -> Array:
	var out := []
	var cam: Camera3D = main.cam
	if cam == null: return out
	var cpos := cam.global_position
	out.append(Vector2(cpos.x, cpos.z))
	var rig = main.rig
	if rig != null:
		var lk = rig.shot.look if rig.shot != null else rig.target
		if lk is Vector3: out.append(Vector2(lk.x, lk.z))
	return out

# 화면 안인가: 카메라 앞 원뿔(세로 fov의 절반 × 가로 비율 + 여유) — 렌더러(헤드리스 포함)와 무관하게 같은 답
static func _in_view(cam: Camera3D, p: Vector3) -> bool:
	var xf := cam.global_transform
	var v := p - xf.origin
	var l := v.length()
	if l < 2.0: return true
	var fwd := -xf.basis.z
	var half := deg_to_rad(cam.fov * 0.5) * 1.45 + deg_to_rad(6.0)
	return fwd.dot(v / l) > cos(half)

# 오가기(walk·serve): 두 점 사이를 걷고 끝에서 잠깐 선다. 길찾기·피하기 없음
func _step(m: Dictionary, dt: float) -> void:
	if not (m.role in ["walk", "serve"]) or not m.has("b") or m.has("pose"): return
	if m.wait > 0.0:
		m.wait -= dt
		if m.wait <= 0.0: m.ch.play("walk")
		return
	var to: Vector2 = m.b if m.dir > 0.0 else m.home
	var p: Vector2 = m.pos2
	var v := to - p
	var step := 1.05 * dt
	if v.length() <= step:
		m.pos2 = to
		m.dir = -m.dir
		m.wait = 1.5 + fmod(float(m.t0) * 7.0, 2.5)
		m.ch.play("serve" if m.role == "serve" and m.ch.has_anim("serve") else "idle")
	else:
		m.pos2 = p + v.normalized() * step
		m.ch.facing = _face(v, m.ch.facing)
	_place(m)
