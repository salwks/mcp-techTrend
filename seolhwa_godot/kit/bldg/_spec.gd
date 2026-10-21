# 건물 빌더 명세(spec) — 건물 한 채를 자료(사전, JSON으로 그대로 저장 가능)로 적는다. 프리셋이 type·region·cls·seed로 명세를 만든다.
#
# 명세 한 채(building):
#   type      "choga"|"jumak"|"sijeon"|"anchae"|"sarang"|"haengrang"|"sadang"|"gotgan"|"dongheon"|"gaeksa"|"daeseong"|"ganggdang"
#             |"jeongja"|"nugak"|"mill"|"smithy"|"daeung"|"araechae"|"shed"   (프리셋 이름 — 모양은 아래 칸들이 정한다)
#   region    "south"(호남·영남 홑집) | "central"(기호 ㄱ자) | "north"(관북·관서 겹집) | "jeju" | "mountain"(관동 산간)
#   cls       "poor" | "commoner" | "middle"(중농·향리) | "yangban" | "official"(관아·향교·절)
#   seed, wear(0 새 ~ 1 낡음: 빛바램·이엉 잿빛·용마루 처짐·창호지 얼룩), interior(true: 방 안 + 가구, 잘라 보기)
#   base      { kind "earth"|"stone"|"jangdae"|"none", h(기단 높이 m), tiers(장대석 단) }   floor_dh: 기단 위 방·마루 바닥 높이
#   cho       주춧돌 "dumbeong"(덤벙, 막돌) | "dressed"(다듬은 사각) | "round"(다듬은 원형) | "none"
#   column    "square"(각) | "round"(원)    col: 굵기(m)    wall: "mud"(흙벽) | "plaster"(회벽) | "board"(판벽) | "stone"(제주 돌벽)
#   wall_h    바닥에서 창방 밑까지    lattice: 기본 창살 "ddi"|"yong"|"a"|"gyo"|"kkot"    meoreum: 창 밑 머름    paint: "none"|"gachil"(뇌록 가칠)|"full"(단청)
#   wings     [ 날개(一자 몸채) … ] — 첫째가 몸채, 나머지는 ㄱ·ㄷ자로 꺾인 날개(x, z, ry로 놓음)
#     { id, x, z, ry, depth: [앞뒤 칸 깊이…](1개 = 홑집, 2개 = 겹집), toet: { kind "none"|"jjok"(쪽마루)|"toet"(툇마루 + 퇴기둥), d },
#       ends: [왼끝, 오른끝] 지붕 끝 꼴("hip"|"gable"|"hipgable"), open_end: [false,false](꺾여 붙는 끝은 벽 없음), lower(지붕 낮춤),
#       roof_up(지붕 올림 — 객사 정청), floor_up(바닥 더 올림 — 누각),
#       bays: [ { w, fn, role?, front: {kind, lattice?}, back: {kind}, side: {kind}, goods? } … ] }
#     fn: "room"|"hall"(대청)|"kitchen"|"store"(곳간)|"shop"|"maru"(트인 마루·누마루)|"shed"(헛간)|"stable"(외양간)|"gate"(대문간)
#         |"jeongju"(정주간)|"mill"(방앗간)|"forge"(대장간)|"shrine"(사당·감실)
#     면 kind: "door2"|"door1"|"door4"(분합 닫힘)|"bunhap_up"(분합 들어 올림)|"window"|"smallwin"|"plank"|"plank2"|"salchang"|"wall"
#              |"open"|"shop"(들창)|"gate"(판문 대문)|"board"(판벽)|"rail"(외양간 가로대)|"join"(날개가 붙음)
#   roof      { kind "thatch"|"giwa"|"neowa", form "hip"|"gable"|"hipgable", eave(처마 내밀기 m), rise_k(높이/반깊이), lift(앙곡), buyeon, net(새끼 그물 줄), rc }
#   chimney   { kind "mud"|"stone"|"log"|"pot"|"tile"|"none", wing, at "back_left"|"back_right"|"side_left"|"side_right" }
#   attach    [ { kind, x, z, ry, … } ] 몸에 붙은 것·곁 것: jangdok_s(작은 장독) | firewood | pyeongsang | yongsu | gamasot | sul_dok(술독)
#             | wheel(물레바퀴) | forge_out | anvil | trough | canopy(가가 차양) | gourd(박 넝쿨) | soguri | meongseok | laundry | tools | dwiju
#   refs      참고 그림 열쇠(docs/reports/building_refs.json 키)
#
# 명세 묶음(compound: kit/bldg/compound.gd)은 건물 명세 여럿 + 담·문·마당 것.
extends RefCounted

const REGION_ALIAS := { JL = "south", GS = "south", GG = "central", HY = "central", GW = "mountain", HG = "north", PA = "north", HH = "north", JJ = "jeju" }

static func region_of(r: String) -> String:
	if REGION_ALIAS.has(r): return REGION_ALIAS[r]
	return r if r in ["south", "central", "north", "jeju", "mountain"] else "south"

# params → 완성 명세. params.spec(그대로) 또는 { type, region, cls, seed, over(덮어쓸 칸) }
static func resolve(params: Dictionary) -> Dictionary:
	var sp: Dictionary
	if params.has("spec"): sp = (params.spec as Dictionary).duplicate(true)
	else: sp = generate(String(params.get("type", "choga")), String(params.get("region", "south")), String(params.get("cls", "")), int(params.get("seed", 1)), bool(params.get("rs", true)))
	for k in params.get("over", {}): sp[k] = params.over[k]
	if params.has("interior"): sp.interior = bool(params.interior)
	return normalize(sp)

static func normalize(sp: Dictionary) -> Dictionary:
	var d := { type = "choga", region = "south", cls = "commoner", seed = 1, wear = 0.4, interior = false,
		base = { kind = "earth", h = 0.3, tiers = 1 }, floor_dh = 0.28, cho = "dumbeong", column = "square", col = 0.19,
		wall = "mud", wall_h = 1.95, lattice = "ddi", meoreum = false, paint = "none",
		roof = { kind = "thatch", form = "hip", eave = 0.85, rise_k = 0.72, lift = 0.0, buyeon = false, net = 0, rc = 1.1 },
		chimney = { kind = "mud", wing = 0, at = "side_right" }, attach = [], refs = [] }
	for k in d:
		if not sp.has(k): sp[k] = d[k]
		elif d[k] is Dictionary:
			for kk in d[k]:
				if not (sp[k] as Dictionary).has(kk): sp[k][kk] = d[k][kk]
	if not sp.has("id"): sp.id = "%s_%s_%d" % [sp.type, sp.region, sp.seed]
	for w in sp.wings:
		for k in [["x", 0.0], ["z", 0.0], ["ry", 0.0], ["toet", { kind = "none", d = 0.0 }], ["ends", [sp.roof.form, sp.roof.form]], ["open_end", [false, false]],
				["lower", 0.0], ["roof_up", 0.0], ["floor_up", 0.0], ["depth", [2.4]], ["id", "w"]]:
			if not w.has(k[0]): w[k[0]] = k[1] if not (k[1] is Dictionary or k[1] is Array) else k[1].duplicate(true)
		for b in w.bays:
			if not b.has("front"): b.front = { kind = default_face(b.fn, "front", sp) }
			if not b.has("back"): b.back = { kind = default_face(b.fn, "back", sp) }
	return sp

static func default_face(fn: String, side: String, sp: Dictionary) -> String:
	var hi: bool = sp.cls in ["yangban", "official"]
	if side == "front":
		match fn:
			"room": return "door2"
			"hall": return "bunhap_up" if hi else "open"
			"kitchen": return "plank"
			"store": return "plank2"
			"shop": return "shop"
			"maru", "shed", "mill", "forge": return "open"
			"stable": return "rail"
			"gate": return "gate"
			"jeongju": return "door1"
			"shrine": return "door2"
		return "wall"
	match fn:
		"room": return "smallwin" if not hi else "window"
		"hall": return "plank2"
		"kitchen": return "plank"
		"maru": return "open"
		"shop", "store", "stable", "shed", "gate", "mill", "forge", "shrine", "jeongju": return "wall"
	return "wall"

static func bay(w: float, fn: String, extra := {}) -> Dictionary:
	var b := { w = snappedf(w, 0.01), fn = fn }
	for k in extra: b[k] = extra[k]
	return b

static func _rng(type: String, region: String, seed: int) -> Kit.Rng:
	return Kit.Rng.new(seed * 7919 + hash(type + region) % 100003)

static func _pick(r: Kit.Rng, arr: Array):
	return arr[mini(arr.size() - 1, int(r.next() * arr.size()))]


# ㄱ·ㄷ자 날개 붙이기: 몸채(main, 길이 L, 깊이 D)의 sx 쪽 끝 옆에 날개를 앞(+z)으로 뻗게 놓는다.
#   날개 뒤 끝 = 몸채 뒷벽 줄, 첫 칸(모퉁이 칸, 길이 ≈ D)은 몸채 끝 벽과 맞닿아 앞면이 "join".
#   날개 칸 목록 wb는 뒤(모퉁이)부터 앞으로. 날개 지붕: 뒤 끝 우진각(바깥 모퉁이), 앞 끝 front_form.
#   기와 몸채는 날개 쪽 끝을 날개 용마루까지 늘려 맞배로 묻는다(ext) — 두 용마루가 ㄱ으로 만난다.
static func add_wing(main: Dictionary, wings: Array, sx: float, D: float, L: float, D2: float, wb: Array, front_form: String, giwa: bool, extra := {}) -> Dictionary:
	# 기와: 날개 깊이를 몸채 지붕 깊이(벽 + 툇간)와 같게 — 모퉁이 지붕이 정사각(회첨골·추녀가 45°)이 되게
	if giwa:
		var T: float = float(main.toet.d) if main.has("toet") and main.toet.kind == "toet" else 0.0
		D2 = D + T
	var bays: Array = wb.duplicate(true)
	if bays.size() > 0:
		bays[0].w = snappedf(D, 0.01)   # 모퉁이 칸 = 몸채 깊이(뒷벽~앞벽)
		bays[0].front = { kind = "join" }
	var wl := 0.0
	for b in bays: wl += b.w
	if sx < 0: bays.reverse()
	var ends := ["open" if giwa else "hip", front_form] if sx > 0 else [front_form, "open" if giwa else "hip"]
	var w := { id = "wing%d" % wings.size(), depth = [D2], x = sx * (L / 2 + D2 / 2), z = -D / 2 + wl / 2, ry = -sx * PI / 2, bays = bays,
		ends = ends, toet = { kind = "none", d = 0.0 }, roof_up = 0.0 if giwa else 0.05, joined = giwa }
	for k in extra: w[k] = extra[k]
	# 몸채 기단은 날개 쪽 끝에서 옆 여유를 두지 않는다(날개 기단과 겹치지 않게)
	if not main.has("base_cut"): main.base_cut = [false, false]
	main.base_cut[0 if sx < 0 else 1] = true
	if giwa:
		if not main.has("ends"): main.ends = ["hipgable", "hipgable"]
		var i := 0 if sx < 0 else 1
		main.ends[i] = "corner"
		if not main.has("corner_w"): main.corner_w = [0.0, 0.0]
		main.corner_w[i] = D2
	wings.append(w)
	return w

# 프리셋 ------------------------------------------------------------------------------------------------
static func generate(type: String, region: String, cls: String, seed: int, rs := true) -> Dictionary:
	region = region_of(region)
	var r := _rng(type, region, seed)
	var sp: Dictionary
	match type:
		"choga": sp = _choga(r, region, cls if cls != "" else "commoner")
		"jumak": sp = _jumak(r, region)
		"sijeon": sp = _sijeon(r, region, cls if cls != "" else "middle")
		"anchae": sp = _anchae(r, region, cls if cls != "" else "yangban")
		"sarang": sp = _sarang(r, region, cls if cls != "" else "yangban")
		"haengrang": sp = _haengrang(r, region, cls if cls != "" else "yangban")
		"sadang": sp = _sadang(r, region)
		"gotgan": sp = _gotgan(r, region, cls if cls != "" else "middle")
		"araechae": sp = _araechae(r, region, cls if cls != "" else "middle")
		"giwajip": sp = _giwajip(r, region, cls if cls != "" else "middle")
		"dongheon": sp = _dongheon(r, region)
		"gaeksa": sp = _gaeksa(r, region)
		"daeseong": sp = _daeseong(r, region)
		"gangdang": sp = _gangdang(r, region)
		"jeongja": sp = _jeongja(r, region)
		"nugak": sp = _nugak(r, region)
		"mill": sp = _mill(r, region)
		"smithy": sp = _smithy(r, region)
		"daeung": sp = _daeung(r, region)
		_: sp = _choga(r, region, "commoner")
	sp.type = type; sp.region = region; sp.seed = seed
	if not sp.has("cls"): sp.cls = cls if cls != "" else "commoner"
	sp.id = "%s_%s_%d" % [type, region, seed]
	if rs: real_scale(sp)
	return sp

# 실제 크기(town-organic, 2026-10-21): 프리셋 치수는 사람 키 1.6m 남짓 기준 옛 키트 비례였다. 게임 인물 그림은 갓까지 약 2.0m(웹 rigs —
#   sprite_char.height 2.06)라 집이 인물보다 작아 보였다(초가 벽 1.8~2.0m < 인물 키, 문 1.6~1.7m). 실제 조선 집 치수(초가 칸 7~8자 2.1~2.4m ·
#   기둥 7자 2.1m 안팎 · 양반가 칸 8~10자 · 기둥 8~9자 · 기단 2~3자)에 인물 비(2.0/1.62 ≈ 1.23)를 곱한 쪽으로 키운다 — 고증은 참고(정확히 맞추지 않음).
#   가로(칸 너비·깊이·툇마루·처마·날개 자리·곁 것 자리) × kh, 세로(벽 높이·기단·마루 높이·지붕 올림) × kv. 문·창 높이는 building.gd가 벽 높이 비로 따라간다.
#   kh = kv(한 배율)로 둔다: 가로·세로를 달리 키우면(1.16/1.24) 이엉 처마 밑 여유(벽 위 0.3m 고정)가 ㄱ자 날개 이음에서 깨졌다(roof_check WALLCLEAR).
#   기둥 굵기(col)는 키우지 않는다(실제 굵기 0.2~0.3m 그대로 — 굵히면 끝 칸 모서리 문틀과 겹쳐 corner_check 틈이 났다).
#   발 걸음(0.32)·문지방(0.18)·가구·장독은 사람 크기라 그대로. 명세를 통째로 적은 집(params.spec — 이야기 집 잠금)은 다시 키우지 않는다.
const SCALE_CLS := { poor = [1.16, 1.16], commoner = [1.22, 1.22], middle = [1.22, 1.22], yangban = [1.22, 1.22], official = [1.2, 1.2] }
static func real_scale(sp: Dictionary) -> void:
	var k: Array = SCALE_CLS.get(String(sp.get("cls", "commoner")), [1.22, 1.22])
	var kh: float = k[0]; var kv: float = k[1]
	sp.real_scale = [kh, kv]
	if sp.has("wall_h"): sp.wall_h = snappedf(float(sp.wall_h) * kv, 0.01)
	# 기단 위 바닥 높이: 칸막이 문지방 밑(걷기 바닥이 끊긴 띠)에서 한 걸음(MAX_STEP 0.32m)을 넘으면 방↔대청을 못 지나므로 0.3 안으로
	if sp.has("floor_dh"):
		var fd := float(sp.floor_dh)
		sp.floor_dh = snappedf(fd * kv, 0.01) if fd > 0.32 or fd * kv <= 0.3 else maxf(fd, 0.3)
	if sp.get("base") is Dictionary and (sp.base as Dictionary).has("h"): sp.base.h = snappedf(float(sp.base.h) * kv, 0.01)
	if sp.get("roof") is Dictionary:
		for kk in ["eave", "lift", "rc"]:
			if (sp.roof as Dictionary).has(kk): sp.roof[kk] = snappedf(float(sp.roof[kk]) * kh, 0.01)
	for w in sp.get("wings", []):
		for kk in ["x", "z"]:
			if w.has(kk): w[kk] = snappedf(float(w[kk]) * kh, 0.01)
		if w.has("depth"):
			var dd := []
			for d in w.depth: dd.append(snappedf(float(d) * kh, 0.01))
			w.depth = dd
		if w.get("toet") is Dictionary and (w.toet as Dictionary).has("d"): w.toet.d = snappedf(float(w.toet.d) * kh, 0.01)
		if w.has("corner_w"):
			var cw := []
			for c in w.corner_w: cw.append(snappedf(float(c) * kh, 0.01))
			w.corner_w = cw
		for kk in ["roof_up", "floor_up", "lower"]:
			if w.has(kk): w[kk] = snappedf(float(w[kk]) * kv, 0.01)
		for b in w.get("bays", []):
			b.w = snappedf(float(b.w) * kh, 0.01)
			# 칸 사이 바닥 단(방↔대청)은 한 걸음(MAX_STEP 0.32m) 안이어야 걸어 넘는다 — 옛 값이 한 걸음 안이면 0.3을 넘기지 않는다
			if b.has("floor_up"):
				var fu := float(b.floor_up)
				b.floor_up = snappedf(fu * kv, 0.01) if fu > 0.32 or fu * kv <= 0.3 else maxf(fu, 0.3)
	for a in sp.get("attach", []):
		for kk in ["x", "z"]:
			if a.has(kk): a[kk] = snappedf(float(a[kk]) * kh, 0.01)
		if String(a.get("kind", "")) == "wheel" and a.has("r"): a.r = snappedf(float(a.r) * kv, 0.01)

# 낡음 → 이엉 빛(새 이엉 금빛 ~ 묵은 이엉 잿빛 갈색)
static func thatch_cols(wear: float) -> Array:
	var fresh := [Color.hex(0xe0cc98ff), Color.hex(0xa18a5eff)]
	var old := [Color.hex(0x9c8f78ff), Color.hex(0x6a5f4cff)]
	return [fresh[0].lerp(old[0], wear).to_rgba32() >> 8, fresh[1].lerp(old[1], wear).to_rgba32() >> 8]

# 서민 초가 ---------------------------------------------------------------------------------------------
static func _choga(r: Kit.Rng, region: String, cls: String) -> Dictionary:
	var wear := r.between(0.15, 0.9)
	var poor := cls == "poor"
	var bw := r.between(2.0, 2.5) if not poor else r.between(1.9, 2.2)
	var kl := r.next() < 0.5   # 부엌이 왼쪽
	var sp := { cls = cls, wear = wear, base = { kind = "earth" if (poor or r.next() < 0.5) else "stone", h = snappedf(r.between(0.22, 0.4), 0.01) },
		floor_dh = snappedf(r.between(0.2, 0.32), 0.01), wall_h = snappedf(r.between(1.8, 2.0), 0.01), lattice = _pick(r, ["ddi", "ddi", "yong"]),
		roof = { kind = "thatch", form = "hip", eave = snappedf(r.between(0.75, 0.95), 0.01), rise_k = r.between(0.68, 0.85), rc = r.between(1.5, 2.2) },
		chimney = { kind = _pick(r, ["mud", "pot", "mud"]), at = "side_right" if kl else "side_left" }, attach = [], refs = ["choga"] }
	var wings := []
	match region:
		"central":
			# 중부 ㄱ자: 몸채 [방 (마루) 방] + 앞으로 꺾인 부엌 날개(모퉁이 칸이 부엌)
			var n := 2 if (poor or r.next() < 0.5) else 3
			var bays := [bay(bw, "room", { role = "witbang" })]
			if n == 3: bays.append(bay(bw, "hall"))
			bays.append(bay(bw, "room", { role = "anbang" }))
			var sx := -1.0 if kl else 1.0
			if sx < 0: bays.reverse()
			var D := r.between(2.3, 2.6)
			var L := bw * n
			var main := { id = "main", depth = [D], toet = { kind = "jjok", d = 0.55 }, bays = bays, ends = ["hip", "hip"] }
			wings = [main]
			add_wing(main, wings, sx, D, L, D * 0.95, [bay(D, "kitchen"), bay(r.between(1.8, 2.6), "store" if r.next() < 0.6 else "room", { role = "geonneon" })], "hip", false)
			sp.chimney.at = "side_left" if sx > 0 else "side_right"
		"north":
			# 북부 겹집(田자): 앞뒤 두 줄 방 + 정주간(부엌과 트인 칸) + 외양간
			var bays := [bay(bw * 1.15, "kitchen"), bay(bw, "jeongju"), bay(bw, "room", { role = "anbang" }), bay(bw * 0.95, "room", { role = "witbang" })]
			if r.next() < 0.55: bays.push_front(bay(bw * 0.9, "stable"))
			if kl: bays.reverse()
			for b in bays:
				if b.fn == "room": b.front = { kind = "window" if r.next() < 0.6 else "smallwin" }
			sp.base = { kind = "earth", h = 0.18 }; sp.floor_dh = 0.22
			sp.roof.eave = r.between(0.6, 0.75); sp.roof.rise_k = r.between(0.55, 0.7)
			sp.chimney = { kind = "log", at = "side_right" if kl else "side_left" }
			wings = [{ id = "main", depth = [2.2, 2.0], toet = { kind = "none", d = 0.0 }, bays = bays }]
			sp.refs = ["choga"]
		"jeju":
			# 제주 3칸 一자: 정지(부엌) · 상방(마루) · 구들(방) + 고팡(곳간). 돌벽, 새끼 그물 지붕, 굴뚝 없음
			var bays := [bay(bw, "kitchen", { role = "jeongji" }), bay(bw * 1.1, "hall", { front = { kind = "door4" } }), bay(bw * 0.95, "room", { role = "gudeul" })]
			if r.next() < 0.5: bays.append(bay(bw * 0.8, "store", { role = "gopang" }))
			if kl: bays.reverse()
			sp.wall = "stone"; sp.base = { kind = "stone", h = 0.2 }; sp.floor_dh = 0.2; sp.wall_h = 1.7
			sp.roof = { kind = "thatch", form = "hip", eave = 0.55, rise_k = 0.5, rc = 1.4, net = 7 + int(r.next() * 3) }
			sp.chimney = { kind = "none" }
			wings = [{ id = "main", depth = [r.between(2.6, 3.0)], toet = { kind = "jjok", d = 0.5 }, bays = bays }]
		"mountain":
			var bays := [bay(bw, "kitchen"), bay(bw, "room", { role = "anbang" }), bay(bw, "room", { role = "witbang" })]
			if kl: bays.reverse()
			sp.roof = { kind = "neowa", form = "gable", eave = 0.8, rise_k = 0.75 }
			sp.chimney = { kind = "log", at = "side_right" if kl else "side_left" }
			wings = [{ id = "main", depth = [r.between(2.4, 2.8)], toet = { kind = "jjok", d = 0.55 }, bays = bays, ends = ["gable", "gable"] }]
		_:
			# 남부 一자 홑집: 부엌 · 안방 · 윗방 (넉넉하면 마루 칸, 가난하면 두 칸 오두막, 부엌 옆 외양간)
			var bays := [bay(bw * r.between(1.0, 1.15), "kitchen"), bay(bw, "room", { role = "anbang" })]
			var shape := r.next()
			if poor and shape < 0.5:
				pass   # 두 칸(부엌 + 방)
			elif shape < 0.55:
				bays.append(bay(bw * r.between(0.85, 1.0), "room", { role = "witbang" }))
			else:
				bays.append(bay(bw * 0.95, "hall"))
				bays.append(bay(bw * r.between(0.85, 1.0), "room", { role = "witbang" }))
			if r.next() < 0.3: bays.push_front(bay(r.between(2.0, 2.4), "stable"))   # 부엌 옆 외양간
			elif r.next() < 0.25: bays.append(bay(r.between(1.6, 2.0), "store"))      # 끝 칸 광
			if kl: bays.reverse()
			var tk: String = _pick(r, ["toet", "toet", "jjok", "none"]) if not poor else _pick(r, ["jjok", "none"])
			wings = [{ id = "main", depth = [r.between(2.2, 2.8)], toet = { kind = tk, d = snappedf(r.between(0.75, 0.95), 0.01) if tk == "toet" else 0.55 }, bays = bays }]
			sp.roof.eave = r.between(0.75, 1.0)
			sp.roof.rise_k = r.between(0.6, 0.95)
			sp.wall_tint = r.next()
	sp.wings = wings
	sp.roof.cols = thatch_cols(wear)
	# 곁 것: 장작·장독·박 넝쿨·소쿠리
	var L := 0.0
	for b in wings[0].bays: L += b.w
	var D: float = wings[0].depth.reduce(func(a, b): return a + b, 0.0)
	var ks := -1.0 if kl else 1.0
	sp.attach.append({ kind = "firewood", x = -ks * (L / 2 + 0.8), z = -0.2, ry = PI / 2 * ks, len = r.between(1.6, 2.6) })
	sp.attach.append({ kind = "jangdok_s", x = ks * (L / 2 - 1.0), z = -D / 2 - 1.3, n = 3 + int(r.next() * 3) })
	if region != "jeju" and region != "mountain" and r.next() < 0.45: sp.attach.append({ kind = "gourd" })
	if r.next() < 0.6: sp.attach.append({ kind = "soguri", x = r.between(-L / 3, L / 3), z = D / 2 + 1.6 })
	if r.next() < 0.4: sp.attach.append({ kind = "tools", x = -ks * (L / 2 - 0.6), z = -D / 2 - 0.35, ry = PI })
	return sp

# 주막: 부엌이 마당으로 트인 초가(술청) + 봉놋방 + 마루 + 평상·용수·술독·한데부뚜막
static func _jumak(r: Kit.Rng, region: String) -> Dictionary:
	var wear := r.between(0.3, 0.8)
	var bw := r.between(2.2, 2.6)
	var kl := r.next() < 0.5
	var bays := [bay(bw * 1.2, "kitchen", { role = "jumak", front = { kind = "open" } }), bay(bw, "room", { role = "jumo" }), bay(bw * 1.1, "maru", { role = "sulcheong", front = { kind = "open" } }), bay(bw * 1.15, "room", { role = "bongno" })]
	if r.next() < 0.4: bays.append(bay(bw, "room", { role = "bongno" }))
	if kl: bays.reverse()
	var L := 0.0
	for b in bays: L += b.w
	var D := r.between(2.4, 2.8)
	var plan: String = _pick(r, ["il", "il", "giyeok"])
	var wings := [{ id = "main", depth = [D], toet = { kind = "toet", d = 0.9 }, bays = bays }]
	var sx := -1.0 if kl else 1.0
	if plan == "giyeok":
		# 꺾인 날개(부엌 반대쪽): 헛간·외양간(길손 말·나귀)
		add_wing(wings[0], wings, -sx, D, L, 2.4, [bay(D, "shed"), bay(r.between(2.2, 3.0), "stable")], "hip", false)
	var sp := { cls = "commoner", wear = wear, base = { kind = "stone", h = 0.3 }, floor_dh = 0.25, wall_h = 1.95, lattice = "ddi",
		roof = { kind = "thatch", form = "hip", eave = 1.0, rise_k = 0.7, rc = 1.8, cols = thatch_cols(wear) },
		chimney = { kind = "mud", at = "side_left" if not kl else "side_right" }, wings = wings, refs = ["jumak"], attach = [] }
	if region == "central" or region == "north": sp.roof.eave = 0.85
	var kx := sx * (L / 2 - bw * 0.6)
	sp.attach.append({ kind = "pyeongsang", x = r.between(-L / 4, L / 6), z = D / 2 + 3.0 + r.between(0, 1.0), ry = r.between(-0.2, 0.2), w = r.between(1.9, 2.4), soban = true })
	if r.next() < 0.65: sp.attach.append({ kind = "pyeongsang", x = -sx * (L / 2 - 0.4) + r.between(-0.5, 0.5), z = D / 2 + 4.6, ry = PI / 2 + r.between(-0.2, 0.2), w = 1.8, soban = r.next() < 0.5 })
	sp.attach.append({ kind = "yongsu", x = sx * (L / 2 + 1.2), z = D / 2 + 3.6 })
	sp.attach.append({ kind = "sul_dok", x = kx, z = D / 2 + 1.4, n = 3 + int(r.next() * 3) })
	if r.next() < 0.7: sp.attach.append({ kind = "gamasot", x = sx * (L / 2 + 1.0), z = D / 2 + 1.0 })
	sp.attach.append({ kind = "firewood", x = sx * (L / 2 + 0.8), z = -0.4, ry = PI / 2 * sx, len = 2.2 })
	sp.attach.append({ kind = "jangdok_s", x = -sx * (L / 2 - 1.2), z = -D / 2 - 1.3, n = 5 })
	return sp

# 시전 행랑: 긴 줄행랑 가게 칸(기와 맞배, 읍내장은 초가) — 칸마다 물건이 다르다
static func _sijeon(r: Kit.Rng, region: String, cls: String) -> Dictionary:
	var giwa := region == "central" or cls == "yangban" or r.next() < 0.35
	var n := 6 + int(r.next() * 7)   # 6~12칸
	var bw := r.between(2.3, 2.8)
	var goods := ["cloth", "onggi", "grain", "straw", "fish", "mixed", "silk", "paper", "shoes", "brass"]
	var bays := []
	var gi := int(r.next() * goods.size())
	for i in n:
		if i > 1 and i < n - 2 and r.next() < 0.12:
			bays.append(bay(bw * 0.8, "gate", { front = { kind = "gate", passage = true }, back = { kind = "gate", passage = true } }))   # 골목 통로
			continue
		if r.next() < 0.1:
			bays.append(bay(bw, "store"))
			continue
		gi = (gi + 1 + int(r.next() * 3)) % goods.size()
		bays.append(bay(bw * r.between(0.9, 1.1), "shop", { goods = goods[gi], canopy = r.next() < 0.45 }))
	var sp := { cls = cls, wear = r.between(0.2, 0.7), base = { kind = "stone", h = 0.25 }, floor_dh = 0.35, wall_h = 2.1, lattice = "yong",
		wall = "plaster" if giwa else "mud", column = "square",
		roof = { kind = "giwa", form = "gable", eave = 0.95, rise_k = 0.55, lift = 0.2 } if giwa else { kind = "thatch", form = "hip", eave = 1.0, rise_k = 0.62, rc = 1.0 },
		chimney = { kind = "none" }, refs = ["sijeon"], attach = [] }
	if not giwa: sp.roof.cols = thatch_cols(sp.wear)
	sp.wings = [{ id = "main", depth = [r.between(2.6, 3.2)], toet = { kind = "none", d = 0.0 }, bays = bays,
		ends = ["gable", "gable"] if giwa else ["hip", "hip"] }]
	# 2층 다락 가게(서울 시전 일부): 지붕을 올리고 위 창 — 칸 수가 많을 때 반쯤
	if giwa and r.next() < 0.4: sp.wings[0].roof_up = 0.6; sp.dara = true
	return sp

# 양반가 건물 ------------------------------------------------------------------------------------------
static func _anchae(r: Kit.Rng, region: String, cls: String) -> Dictionary:
	var bw := r.between(2.5, 2.9)
	var plan: String = _pick(r, ["giyeok", "giyeok", "digeut", "il"]) if region != "south" else _pick(r, ["il", "giyeok", "il"])
	var kl := r.next() < 0.5
	var hall_n := 2 if r.next() < 0.6 else 1
	var bays := [bay(bw, "room", { role = "anbang" })]
	for i in hall_n: bays.append(bay(bw * 1.05, "hall"))
	bays.append(bay(bw, "room", { role = "geonneon" }))
	if r.next() < 0.5: bays.push_front(bay(bw * 0.9, "room", { role = "witbang" }))
	var D := r.between(2.6, 3.0)
	var sp := { cls = cls, wear = r.between(0.1, 0.6), base = { kind = "jangdae", h = snappedf(r.between(0.55, 0.85), 0.01), tiers = 2 }, floor_dh = 0.3,
		cho = "dressed", column = "square" if r.next() < 0.6 else "round", col = 0.22, wall = "plaster", wall_h = 2.3, lattice = _pick(r, ["ddi", "a", "yong"]), meoreum = true,
		roof = { kind = "giwa", form = "hipgable" if r.next() < 0.6 else "gable", eave = r.between(1.15, 1.4), rise_k = r.between(0.55, 0.66), lift = r.between(0.3, 0.5) },
		chimney = { kind = "stone" }, refs = ["yangban"], attach = [] }
	var L := 0.0
	for b in bays: L += b.w
	var sx := 1.0 if not kl else -1.0
	var wings := [{ id = "main", depth = [D], toet = { kind = "toet", d = 0.9 }, bays = bays }]
	var D2 := D * 0.92
	if plan == "il":
		# 一자: 부엌을 몸채 끝 칸으로
		if kl: wings[0].bays.push_front(bay(bw * 1.1, "kitchen"))
		else: wings[0].bays.append(bay(bw * 1.1, "kitchen"))
	else:
		wings[0].ends = [sp.roof.form if sp.roof.form != "gable" else "hipgable", sp.roof.form if sp.roof.form != "gable" else "hipgable"]
		for s2 in ([sx] if plan == "giyeok" else [sx, -sx]):
			# 날개는 몸채 앞 처마 줄 너머로 두 칸 이상 나와야 ㄱ·ㄷ자로 읽힌다(모퉁이 칸 + 두 칸)
			var wb: Array = [bay(D, "kitchen"), bay(bw, "store"), bay(bw * 0.9, "room", { role = "haengrang" })] if s2 == sx else [bay(D, "room", { role = "geonneon" }), bay(bw * 0.9, "maru", { front = { kind = "open" } }), bay(bw * 0.9, "store")]
			add_wing(wings[0], wings, s2, D, L, D2, wb, "hipgable", true, { toet = { kind = "jjok", d = 0.5 } })
	sp.wings = wings
	if sp.roof.form == "gable" and plan != "il":
		sp.roof.form = "hipgable"
	sp.chimney.at = "back_left" if kl else "back_right"
	return sp

static func _sarang(r: Kit.Rng, region: String, cls: String) -> Dictionary:
	var bw := r.between(2.5, 2.9)
	var bays := [bay(bw, "room", { role = "sarang" }), bay(bw * 1.05, "hall"), bay(bw, "room", { role = "chaekbang" })]
	if r.next() < 0.55: bays.append(bay(bw * 1.1, "maru", { role = "numaru", front = { kind = "open" }, floor_up = 0.55 }))
	if r.next() < 0.4: bays.push_front(bay(bw * 0.9, "kitchen", { role = "hamsil" }))   # 사랑 부엌(함실)
	if r.next() < 0.5: bays.reverse()
	return { cls = cls, wear = r.between(0.1, 0.5), base = { kind = "jangdae", h = snappedf(r.between(0.6, 0.95), 0.01), tiers = 2 }, floor_dh = 0.32,
		cho = "dressed", column = _pick(r, ["round", "square"]), col = 0.23, wall = "plaster", wall_h = 2.35, lattice = _pick(r, ["a", "yong", "ddi"]), meoreum = true,
		roof = { kind = "giwa", form = "hipgable", eave = r.between(1.2, 1.45), rise_k = r.between(0.55, 0.65), lift = r.between(0.35, 0.55) },
		chimney = { kind = "stone", at = "back_right" }, refs = ["yangban"], attach = [],
		wings = [{ id = "main", depth = [r.between(2.6, 3.0)], toet = { kind = "toet", d = 0.95 }, bays = bays }] }

static func _haengrang(r: Kit.Rng, region: String, cls: String) -> Dictionary:
	var n := 5 + int(r.next() * 4)
	var gate_i := n / 2 + (int(r.next() * 3) - 1 if n > 5 else 0)
	var bays := []
	for i in n:
		if i == gate_i: bays.append(bay(2.9, "gate", { soseul = cls == "yangban", front = { kind = "gate" }, back = { kind = "open" } }))
		else: bays.append(bay(r.between(2.2, 2.5), _pick(r, ["room", "store", "stable", "room", "store"]) if abs(i - gate_i) > 0 else "room", { role = "haengrang" }))
	for b in bays:
		if b.fn == "room": b.front = { kind = "smallwin" }; b.back = { kind = "door1" }
		if b.fn == "store": b.front = { kind = "wall" }; b.back = { kind = "plank" }
		if b.fn == "stable": b.front = { kind = "wall" }; b.back = { kind = "rail" }
	var giwa := cls == "yangban" or r.next() < 0.3
	var sp := { cls = cls, wear = r.between(0.2, 0.7), base = { kind = "stone", h = 0.3 }, floor_dh = 0.25, wall = "plaster" if giwa else "mud",
		wall_h = 2.05, lattice = "yong", cho = "dressed" if giwa else "dumbeong",
		roof = { kind = "giwa", form = "gable", eave = 0.95, rise_k = 0.55, lift = 0.15 } if giwa else { kind = "thatch", form = "hip", eave = 0.9, rise_k = 0.66, rc = 1.0 },
		chimney = { kind = "mud", at = "back_left" }, refs = ["yangban"], attach = [],
		wings = [{ id = "main", depth = [2.4], bays = bays, ends = ["gable", "gable"] if giwa else ["hip", "hip"] }], gate_i = gate_i }
	if not giwa: sp.roof.cols = thatch_cols(sp.wear)
	return sp

static func _sadang(r: Kit.Rng, region: String) -> Dictionary:
	var bw := r.between(2.2, 2.5)
	var bays := [bay(bw, "shrine", { front = { kind = "door2", lattice = "ddi" } }), bay(bw * 1.1, "shrine", { front = { kind = "door2" }, role = "sindo" }), bay(bw, "shrine", { front = { kind = "door2" } })]
	return { cls = "yangban", wear = r.between(0.1, 0.4), base = { kind = "jangdae", h = 0.7, tiers = 2 }, floor_dh = 0.3, cho = "dressed", column = "round", col = 0.22,
		wall = "plaster", wall_h = 2.2, lattice = "ddi", paint = "gachil",
		roof = { kind = "giwa", form = "gable", eave = 1.1, rise_k = 0.62, lift = 0.3 }, chimney = { kind = "none" }, refs = ["yangban"], attach = [],
		wings = [{ id = "main", depth = [2.5], toet = { kind = "toet", d = 1.0 }, bays = bays, ends = ["gable", "gable"] }] }

static func _gotgan(r: Kit.Rng, region: String, cls: String) -> Dictionary:
	var n := 2 + int(r.next() * 2)
	var bays := []
	for i in n: bays.append(bay(r.between(2.2, 2.6), "store" if i > 0 or r.next() < 0.5 else "shed"))
	var giwa := cls == "yangban"
	var sp := { cls = cls, wear = r.between(0.3, 0.8), base = { kind = "earth", h = 0.2 }, floor_dh = 0.0, wall = "board" if giwa else "mud", wall_h = 2.0,
		roof = { kind = "giwa", form = "gable", eave = 0.8, rise_k = 0.52, lift = 0.1 } if giwa else { kind = "thatch", form = "gable", eave = 0.7, rise_k = 0.6 },
		chimney = { kind = "none" }, attach = [], wings = [{ id = "main", depth = [2.4], bays = bays, ends = ["gable", "gable"] }] }
	if not giwa: sp.roof.cols = thatch_cols(sp.wear)
	return sp

# 읍내 기와집(중인·향리·아전): 一자 3~4칸(부엌·안방·대청·건넌방), 막돌 기단, 각기둥, 흙벽/회벽, 맞배·팔작 — 양반가 안채보다 작고 낮다.
#   고을 배치에서 작은 필지(15×14m)에 들도록 칸 2.1~2.45m. 참고: 김홍도·김준근 읍내 풍속(기와집 몸채 + 초가 곳간이 섞임)
static func _giwajip(r: Kit.Rng, region: String, cls: String) -> Dictionary:
	var bw := r.between(2.1, 2.45)
	var kl := r.next() < 0.5
	var bays := [bay(bw * 1.1, "kitchen"), bay(bw, "room", { role = "anbang" })]
	if r.next() < 0.65: bays.append(bay(bw * r.between(1.0, 1.15), "hall"))
	bays.append(bay(bw * r.between(0.85, 1.0), "room", { role = "geonneon" }))
	if kl: bays.reverse()
	var form: String = _pick(r, ["gable", "hipgable", "gable"])
	var tk: String = _pick(r, ["toet", "jjok", "toet"])
	var sp := { cls = cls, wear = r.between(0.2, 0.7), base = { kind = "stone", h = snappedf(r.between(0.38, 0.55), 0.01) }, floor_dh = 0.3,
		cho = "dumbeong" if r.next() < 0.6 else "dressed", column = "square", col = 0.2, wall = "plaster" if r.next() < 0.45 else "mud", wall_h = snappedf(r.between(2.0, 2.15), 0.01),
		lattice = _pick(r, ["ddi", "ddi", "yong"]), meoreum = r.next() < 0.3,
		roof = { kind = "giwa", form = form, eave = r.between(0.95, 1.12), rise_k = r.between(0.52, 0.62), lift = r.between(0.15, 0.3) },
		chimney = { kind = _pick(r, ["pot", "stone", "mud"]), at = "side_right" if kl else "side_left" }, refs = ["yangban"], attach = [] }
	sp.wings = [{ id = "main", depth = [r.between(2.4, 2.7)], toet = { kind = tk, d = snappedf(r.between(0.75, 0.9), 0.01) if tk == "toet" else 0.55 }, bays = bays, ends = [form, form] }]
	var L := 0.0
	for b in bays: L += b.w
	var ks := -1.0 if kl else 1.0
	sp.attach.append({ kind = "jangdok_s", x = ks * (L / 2 - 1.0), z = -1.3 - 1.3, n = 3 + int(r.next() * 3) })
	if r.next() < 0.5: sp.attach.append({ kind = "firewood", x = ks * (L / 2 + 0.8), z = -0.2, ry = PI / 2 * ks, len = r.between(1.4, 2.0) })
	return sp

# 중농 아래채: 사랑방 + 외양간 + 헛간(곳간)
static func _araechae(r: Kit.Rng, region: String, cls: String) -> Dictionary:
	var bays := [bay(r.between(2.2, 2.5), "room", { role = "sarang" }), bay(r.between(2.4, 2.8), "stable"), bay(r.between(2.2, 2.6), "shed")]
	if r.next() < 0.4: bays.insert(1, bay(2.1, "kitchen", { role = "soe" }))   # 쇠죽 끓이는 부엌
	if r.next() < 0.5: bays.reverse()
	var wear := r.between(0.3, 0.9)
	return { cls = cls, wear = wear, base = { kind = "earth", h = 0.25 }, floor_dh = 0.25, wall_h = 1.85,
		roof = { kind = "thatch", form = "hip", eave = 0.85, rise_k = 0.68, rc = 1.0, cols = thatch_cols(wear) },
		chimney = { kind = "mud", at = "back_left" }, attach = [], refs = ["jungnong"],
		wings = [{ id = "main", depth = [r.between(2.2, 2.5)], toet = { kind = "jjok", d = 0.5 }, bays = bays }] }

# 관아·향교·서원·정자·절 --------------------------------------------------------------------------------
static func _dongheon(r: Kit.Rng, region: String) -> Dictionary:
	var n := 5 + int(r.next() * 2)
	var bays := []
	var ri := 0 if r.next() < 0.5 else n - 1
	for i in n:
		if i == ri or (n == 6 and i == (1 if ri == 0 else n - 2)): bays.append(bay(2.7, "room", { role = "office", front = { kind = "door4" } }))
		else: bays.append(bay(3.0, "hall", { role = "office", front = { kind = "bunhap_up" } }))
	return { cls = "official", wear = r.between(0.15, 0.5), base = { kind = "jangdae", h = snappedf(r.between(0.9, 1.2), 0.01), tiers = 3 }, floor_dh = 0.35,
		cho = "dressed", column = "round", col = 0.27, wall = "plaster", wall_h = 2.75, lattice = "ddi", meoreum = true, paint = "gachil",
		roof = { kind = "giwa", form = "hipgable", eave = 1.55, rise_k = 0.62, lift = 0.6, buyeon = r.next() < 0.5 },
		chimney = { kind = "stone", at = "back_left" if ri == 0 else "back_right" }, refs = ["gwana"], attach = [],
		wings = [{ id = "main", depth = [2.6, 2.4], toet = { kind = "toet", d = 1.2 }, bays = bays }] }

# 객사: 가운데 정청(높은 맞배, 전패) + 좌우 익헌(낮은 팔작) — 세 날개를 한 줄로
static func _gaeksa(r: Kit.Rng, region: String) -> Dictionary:
	var cb := [bay(2.8, "hall", { role = "jeongcheong", front = { kind = "door4", lattice = "ddi" } }), bay(3.2, "hall", { role = "jeongcheong", front = { kind = "door4" } }), bay(2.8, "hall", { role = "jeongcheong", front = { kind = "door4" } })]
	var Lc := 8.8
	var nw := 3 + int(r.next() * 2)
	var wb := []
	for i in nw: wb.append(bay(2.7, "room" if i == nw - 1 else "hall", { role = "ikheon", front = { kind = "bunhap_up" if i < nw - 1 else "door4" } }))
	var Lw := 2.7 * nw
	var wbr: Array = wb.duplicate(true); wbr.reverse()
	return { cls = "official", wear = r.between(0.15, 0.45), base = { kind = "jangdae", h = 0.9, tiers = 3 }, floor_dh = 0.35, cho = "dressed", column = "round", col = 0.28,
		wall = "plaster", wall_h = 2.7, lattice = "ddi", meoreum = true, paint = "full",
		roof = { kind = "giwa", form = "hipgable", eave = 1.5, rise_k = 0.62, lift = 0.55, buyeon = true }, chimney = { kind = "none" }, refs = ["gaeksa"], attach = [],
		wings = [
			{ id = "jeongcheong", depth = [3.0, 2.8], toet = { kind = "toet", d = 1.2 }, bays = cb, ends = ["gable", "gable"], roof_up = 1.3, floor_up = 0.3 },
			{ id = "west", x = -(Lc / 2 + Lw / 2 + 0.6), depth = [2.6, 2.4], toet = { kind = "toet", d = 1.1 }, bays = wbr, ends = ["hipgable", "gable"], butt = [false, true] },
			{ id = "east", x = Lc / 2 + Lw / 2 + 0.6, depth = [2.6, 2.4], toet = { kind = "toet", d = 1.1 }, bays = wb, ends = ["gable", "hipgable"], butt = [true, false] }] }

# 향교 대성전: 맞배 5칸 + 앞 퇴칸 트임(퇴기둥) — 제향 공간
static func _daeseong(r: Kit.Rng, region: String) -> Dictionary:
	var bays := []
	for i in 5: bays.append(bay(2.8 if i != 2 else 3.2, "shrine", { front = { kind = "door2" if i != 2 else "door4", lattice = "ddi" } }))
	return { cls = "official", wear = r.between(0.2, 0.5), base = { kind = "jangdae", h = 1.0, tiers = 3 }, floor_dh = 0.25, cho = "dressed", column = "round", col = 0.28,
		wall = "plaster", wall_h = 2.8, lattice = "ddi", paint = "gachil", roof = { kind = "giwa", form = "gable", eave = 1.3, rise_k = 0.64, lift = 0.35 },
		chimney = { kind = "none" }, refs = ["hyanggyo"], attach = [],
		wings = [{ id = "main", depth = [2.8, 2.6], toet = { kind = "toet", d = 1.5 }, bays = bays, ends = ["gable", "gable"] }] }

# 서원·향교 강당(명륜당): 가운데 대청 + 양 끝 협실
static func _gangdang(r: Kit.Rng, region: String) -> Dictionary:
	var n := 5 if r.next() < 0.7 else 4
	var bays := []
	for i in n:
		var end := i == 0 or i == n - 1
		bays.append(bay(2.7, "room" if end else "hall", { role = "hyeopsil" if end else "gangdang", front = { kind = "door4" if end else "open" } }))
	return { cls = "official", wear = r.between(0.2, 0.55), base = { kind = "jangdae", h = 0.75, tiers = 2 }, floor_dh = 0.35, cho = "dressed", column = "round", col = 0.25,
		wall = "plaster", wall_h = 2.5, lattice = "ddi", meoreum = true, roof = { kind = "giwa", form = _pick(r, ["hipgable", "gable"]), eave = 1.35, rise_k = 0.6, lift = 0.45 },
		chimney = { kind = "stone", at = "back_left" }, refs = ["seowon"], attach = [],
		wings = [{ id = "main", depth = [2.6, 2.2], toet = { kind = "toet", d = 1.0 }, bays = bays }] }

# 정자: 사방 트인 마루 + 계자난간(1칸 사모 또는 2×2칸 팔작)
static func _jeongja(r: Kit.Rng, region: String) -> Dictionary:
	var big := r.next() < 0.5
	var s := r.between(2.6, 3.2)
	var bays := [bay(s, "maru", { front = { kind = "open" }, back = { kind = "open" } })] if not big else [bay(s, "maru", { front = { kind = "open" }, back = { kind = "open" } }), bay(s, "maru", { front = { kind = "open" }, back = { kind = "open" } })]
	var rail := true
	var gi := region != "jeju" and r.next() < 0.75
	var sp := { cls = "yangban", wear = r.between(0.2, 0.6), base = { kind = "stone", h = 0.35 }, floor_dh = r.between(0.55, 0.9), cho = "dressed", column = "round", col = 0.2,
		wall = "plaster", wall_h = 2.3, paint = "gachil" if r.next() < 0.5 else "none",
		roof = { kind = "giwa", form = "hip" if not big else "hipgable", eave = 1.1, rise_k = 0.8 if not big else 0.62, lift = 0.5 } if gi else { kind = "thatch", form = "hip", eave = 0.9, rise_k = 0.75, rc = 1.2 },
		chimney = { kind = "none" }, refs = ["jeongja"], attach = [], rail = rail,
		wings = [{ id = "main", depth = [s] if not big else [s, s], bays = bays, ends = ["hip", "hip"] if not big else ["hipgable", "hipgable"] }] }
	if not gi: sp.roof.cols = thatch_cols(sp.wear)
	return sp

# 누각: 아래층 높은 기둥 + 위층 마루(계자난간) + 팔작, 나무 계단
static func _nugak(r: Kit.Rng, region: String) -> Dictionary:
	var n := 3 + int(r.next() * 2)
	var bays := []
	for i in n: bays.append(bay(2.8, "maru", { front = { kind = "open" }, back = { kind = "open" } }))
	return { cls = "official", wear = r.between(0.2, 0.5), base = { kind = "stone", h = 0.25 }, floor_dh = r.between(2.2, 2.6), cho = "dressed", column = "round", col = 0.28,
		wall = "plaster", wall_h = 2.5, paint = "gachil", roof = { kind = "giwa", form = "hipgable", eave = 1.5, rise_k = 0.62, lift = 0.6, buyeon = true },
		chimney = { kind = "none" }, refs = ["jeongja"], attach = [], rail = true, stair = true,
		wings = [{ id = "main", depth = [2.6, 2.6], bays = bays, ends = ["hipgable", "hipgable"] }] }

# 물레방앗간: 맞배 초가 2칸(방아 칸 트임) + 물레바퀴 + 홈통
static func _mill(r: Kit.Rng, region: String) -> Dictionary:
	var wear := r.between(0.4, 0.95)
	var bays := [bay(r.between(2.6, 3.2), "mill", { front = { kind = "open" } }), bay(r.between(2.2, 2.6), "store", { front = { kind = "plank" } })]
	var wl := r.next() < 0.5
	if wl: bays.reverse()
	var L := 0.0
	for b in bays: L += b.w
	var D := r.between(3.0, 3.6)
	var sp := { cls = "commoner", wear = wear, base = { kind = "stone", h = 0.25 }, floor_dh = 0.0, wall_h = 2.1, wall = "mud",
		roof = { kind = "thatch", form = "gable", eave = 0.75, rise_k = 0.7, cols = thatch_cols(wear) }, chimney = { kind = "none" }, refs = ["mill"],
		wings = [{ id = "main", depth = [D], bays = bays, ends = ["gable", "gable"] }], attach = [] }
	var sx := -1.0 if wl else 1.0
	sp.attach.append({ kind = "wheel", x = sx * (L / 2 + 0.55), z = 0.0, r = r.between(1.4, 1.8), overshot = r.next() < 0.6 })
	return sp

# 대장간: 트인 맞배 초가 + 화덕·풀무·모루·물통·숯 더미
static func _smithy(r: Kit.Rng, region: String) -> Dictionary:
	var wear := r.between(0.4, 0.9)
	var n := 2 + int(r.next() * 2)
	var bays := [bay(r.between(2.6, 3.0), "forge", { front = { kind = "open" } })]
	if n >= 2: bays.append(bay(r.between(2.2, 2.6), "forge" if r.next() < 0.5 else "store", { front = { kind = "open" } }))
	if n == 3: bays.append(bay(2.3, "room", { role = "smith", front = { kind = "door1" } }))
	if r.next() < 0.5: bays.reverse()
	var sp := { cls = "commoner", wear = wear, base = { kind = "earth", h = 0.15 }, floor_dh = 0.0, wall_h = 2.0, wall = "mud",
		roof = { kind = "thatch", form = _pick(r, ["gable", "hip"]), eave = 0.9, rise_k = 0.65, rc = 1.0, cols = thatch_cols(wear) }, chimney = { kind = "none" }, refs = ["smithy"],
		wings = [{ id = "main", depth = [r.between(2.8, 3.4)], bays = bays }], attach = [] }
	sp.wings[0].ends = [sp.roof.form, sp.roof.form]
	return sp

# 절 대웅전: 3칸 팔작 + 꽃살문 + 단청 + 부연
static func _daeung(r: Kit.Rng, region: String) -> Dictionary:
	var bays := [bay(3.0, "shrine", { front = { kind = "door4", lattice = "kkot" } }), bay(3.6, "shrine", { front = { kind = "door4", lattice = "kkot" }, role = "buddha" }), bay(3.0, "shrine", { front = { kind = "door4", lattice = "kkot" } })]
	return { cls = "official", wear = r.between(0.2, 0.5), base = { kind = "jangdae", h = 1.05, tiers = 3 }, floor_dh = 0.3, cho = "round", column = "round", col = 0.32,
		wall = "plaster", wall_h = 3.2, lattice = "kkot", paint = "full", roof = { kind = "giwa", form = "hipgable", eave = 1.7, rise_k = 0.66, lift = 0.75, buyeon = true },
		chimney = { kind = "none" }, refs = ["temple"], attach = [],
		wings = [{ id = "main", depth = [3.0, 3.0], bays = bays, ends = ["hipgable", "hipgable"] }] }
