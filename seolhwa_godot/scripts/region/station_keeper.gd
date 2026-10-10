# 역참 마부·길목 깃발 대화 — 역마 이동의 입구(2026-10 UX: 역참 둘레 넓은 E가 곁 사람 말 걸기를 가로채 말이 끌려오던 문제를 없앴다).
#   마부(역참 그림 station_life의 마부, 모든 역 region_data/stations.json): 곁(REACH m)에서 E → "어디로 가시오?" →
#     · 역마 — 가 본 역·깃발(역마 창 fast_travel._gather 목록 그대로 — 처음 가는 길·남원 첫 사건 막음도 같은 규칙, 못 가는 곳은 흐리게 까닭과 함께)
#     · 말을 빌린다 — 큰길 따라(horse_ride 자동 기승: 마부가 기다리는 말을 끌고 나옴) — 그 자리에서 말을 탈 수 있을 때만
#     · 가 본 다른 곳 — 역마 창(나루·절·노정 끝 등 역·깃발이 아닌 거점까지 보이는 창)
#     · 그만두겠소.
#     고른 뒤에야 말이 온다(역마: 마부가 말을 끌고 와 곁에 선 뒤 역마 창 · 말 빌리기: 마부가 말을 끌고 나와 태움). 말하는 동안 마부는 일손을 멈춘다.
#   깃발(scripts/region/waymarks.gd): 곁에서 E → 같은 목록(말 빌리기 없음 — 깃발에는 말이 없다), 고르면 바로 역마 창.
#   남원 v3.2 첫 방문 마부 안내(namwon_case.station_intro)는 끝에서 menu()로 이어진다.
# story_director가 쥐고 target(pp)을 고를 때 이야기 인물 다음으로 고을 사람·마부·깃발 가운데 가장 가까운 것을 고른다(넓은 구역 E 없음).
extends RefCounted

const Stations := preload("res://scripts/region/stations.gd")
const Waymarks := preload("res://scripts/region/waymarks.gd")

const REACH := 2.4          # 마부에게 E 닿는 거리 — 이야기 인물(2.2)·고을 사람(1.9)과 같은 결
const MAX_DEST := 7         # 목록에 바로 보이는 역마 갈 곳(넘치면 '가 본 다른 곳 — 역마 창'으로)

var d                       # story_director
var busy := false
var last := {}              # 시험: { from, labels, picked, action }
var log_lines := true

func _init(director) -> void:
	d = director

func _hr():
	return d.main.get("horse_ride")

# ---- 대상 ----
func target(pp: Vector2) -> Variant:
	if busy: return null
	var hr = _hr()
	if hr == null or hr.busy() or d.main.world.indoor != null: return null
	var best = null; var bd := INF
	if hr.life != null and hr.life.enabled():
		var k: Dictionary = hr.life.keeper_near(pp, REACH)
		if not k.is_empty():
			bd = pp.distance_to(k.p)
			best = { id = "keeper:" + String(k.st.id), kind = "keeper", st = k.st, p = k.p, r = REACH, label = "마부 · 말 걸기" }
	if hr.get("flags") != null and hr.flags.enabled():
		var f: Dictionary = hr.flags.near(pp, REACH)
		if not f.is_empty() and pp.distance_to(f.p) < bd:
			best = { id = "flag:" + String(f.id), kind = "flag", flag = f, p = f.p, r = REACH, label = "%s 깃발 · 역마" % String(f.name) }
	return best

# ---- E ----
func talk(t: Dictionary) -> void:
	if busy: return
	if String(t.kind) == "flag": await talk_flag(t.flag)
	else: await talk_keeper(t.st)

func talk_keeper(st: Dictionary) -> void:
	busy = true
	var hr = _hr()
	var life = hr.life
	life.hold(st, d.main.player_pos)
	var gp: Vector3 = life.groom_pos(st)
	if gp != Vector3.INF: d.face_actor("player", null, Vector2(gp.x, gp.z))
	d.ui.prompt(""); d._target = null
	if d.onboard != null: d.onboard.on_interact("actor")
	print("KEEPER talk %s" % st.id)
	await d.ui.say("마부", ["어디로 가시오?"])
	var a: Dictionary = await menu({ kind = "keeper", st = st })
	life.unhold(st)
	busy = false
	await act(a)

func talk_flag(f: Dictionary) -> void:
	busy = true
	d.ui.prompt(""); d._target = null
	d.face_actor("player", null, f.p)
	print("KEEPER flag %s" % f.id)
	var a: Dictionary = await menu({ kind = "flag", flag = f })
	busy = false
	await act(a)

# ---- 목록 ----
# 역마로 갈 곳: 역마 창 목록(_gather) 가운데 역·깃발 — 같은 막힘 규칙. [{label, disabled, hint, space, node, station_id}]
func destinations() -> Array:
	var FT = load("res://scripts/region/fast_travel.gd")
	var ft = FT.new(d.main)
	ft._gather()
	var out := []
	var rest := 0
	for it in ft.items:
		if not (bool(it.get("station", false)) or bool(it.get("flag", false))):
			if bool(it.ok): rest += 1
			continue
		var what := "역마" if bool(it.station) else "깃발"
		var lab := "%s — %s" % [what, String(it.name)]
		if not bool(it.same): lab += " (%s)" % String(it.space_name)
		out.append({ label = lab, disabled = not bool(it.ok), hint = String(it.why), space = String(it.space), node = String(it.id),
			station_id = String(it.get("station_id", "")), ok = bool(it.ok) })
	ft.free()
	# 갈 수 있는 곳 먼저(역마 창 정렬 그대로), MAX_DEST 넘치면 창으로
	var oks := out.filter(func(o): return o.ok)
	var nos := out.filter(func(o): return not o.ok)
	var shown := oks.slice(0, MAX_DEST)
	rest += maxi(0, oks.size() - MAX_DEST)
	shown.append_array(nos.slice(0, 2))   # 못 가는 곳은 둘까지만(까닭을 보여 준다)
	for o in shown: o.erase("ok")
	return [shown, rest]

func menu(from: Dictionary) -> Dictionary:
	var hr = _hr()
	var dl: Array = destinations()
	var opts: Array = []
	for o in dl[0]: opts.append(o.merged({ act = "warp" }))
	if String(from.kind) == "keeper":
		var rc: Array = hr.station_ride_choices(from.st) if hr != null else []
		if not rc.is_empty(): opts.append({ label = "말을 빌린다 — 큰길 따라", act = "ride", choices = rc })
	if int(dl[1]) > 0: opts.append({ label = "가 본 다른 곳 — 역마 창", act = "window" })
	opts.append({ label = "그만두겠소.", act = "end" })
	var q := "어디로 가겠소?" if String(from.kind) == "keeper" else "깃발 — 어디로 갈까"
	if dl[0].is_empty() and opts.size() == 1:
		q = "아직 역마로 갈 만한 곳을 모른다. (가 본 역·깃발이 생기면 여기서 간다)"
	var labels := opts.map(func(o): return String(o.label))
	last = { from = String(from.kind), labels = labels, picked = "", action = {} }
	if log_lines: print("KEEPER menu %s %s" % [from.kind, labels])
	var i: int = await d.ui.choice(q, opts)
	var o: Dictionary = opts[i] if i >= 0 and i < opts.size() else { act = "end" }
	last.picked = String(o.get("label", ""))
	var a := { act = String(o.act), from = from }
	match String(o.act):
		"warp":
			a.space = o.space; a.node = o.node; a.station_id = o.station_id
			if String(from.kind) == "keeper": await d.ui.say("마부", ["말을 내 오리다."])
		"ride":
			var rc: Array = o.choices
			var ro := []
			for c in rc: ro.append({ label = "%s 쪽으로 (약 %d분)" % [String(c.name), int(c.mins)] })
			ro.append({ label = "그만두겠소." })
			var j: int = await d.ui.choice("어느 쪽으로 가시오?", ro)
			if j < 0 or j >= rc.size(): a.act = "end"
			else: a.choice = rc[j]
	last.action = a
	print("KEEPER pick %s → %s" % [last.picked, a.act])
	return a

# ---- 고른 뒤에야 말이 온다 ----
func act(a: Dictionary) -> void:
	var hr = _hr()
	var from: Dictionary = a.get("from", {})
	match String(a.get("act", "end")):
		"warp":
			if String(from.get("kind", "")) == "keeper" and hr.life != null:
				var st: Dictionary = from.st
				var sec: float = hr.life.bring(st, d.main.player_pos)
				if sec > 0.0: await d.wait(sec + 0.3)
				var r: Dictionary = Stations.warp_node(String(a.space), String(a.node))
				if not bool(r.ok):
					hr.life.bring_end(st); d.ui.toast("역마 — " + String(r.why)); return
				# 역마 창이 닫힐 때(같은 공간 도착 · 막힘) 말을 다시 매어 둔다(다른 공간이면 장면이 바뀐다)
				while d.main.fast_ui != null and is_instance_valid(d.main.fast_ui):
					await d.get_tree().process_frame
				if is_instance_valid(hr.life.main): hr.life.bring_end(st)
			else:
				var r2: Dictionary = Stations.warp_node(String(a.space), String(a.node))
				if not bool(r2.ok): d.ui.toast("역마 — " + String(r2.why))
		"ride":
			var st2: Dictionary = from.st
			var y: Array = st2.yard
			var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
			if pp.distance_to(Vector2(float(y[0]), float(y[1]))) > 5.0:
				# 마방 안쪽에서 말을 걸었으면 문 앞 길로 나간다(짧은 암전)
				await d.ui.fade(true, 0.25)
				d.main.teleport(float(y[0]), float(y[1]))
				await d.ui.fade(false, 0.25)
			hr.begin_ride(a.choice, st2)
		"window":
			d.main.open_fast_travel()
