# 권역 주변 인물·짐승(대화·전투·이야기 없음) — 고을이 살아 보이게, 고을 차이(사람·짐승)가 드러나게.
#
# 자리(site) 만들기 — 시작 때 작업 스레드에서 한 번
#   - 길(region.json roads)과 고샅(placement_*.json alleys)을 8m마다 잘라 '길 자리'를 만든다. 고을(settlements) 안이면
#     고을 성격(장시·도성 종로 > 읍치·도성 > 나루·포구·섬 > 들·산·절 마을)에 맞는 밀도(길 넓이 × m²당 사람 수)로 걷는 사람·선 사람,
#     고을 밖 대로·지선은 120m마다 나그네 한 명(있을 확률 0.45).
#   - 배치 항목(키트) 둘레 '닻 자리': 가게·좌판(상인·손님) · 주막(주모·나그네) · 나룻배(뱃사공) · 우물·빨래터(아낙/해녀) ·
#     마을 마당·큰 나무(노인·아이) · 향교(선비) · 관아·객사·성문(관속) · 절(스님·보살) · 텃밭·짚가리(농부, 소) · 집(닭·개).
#   - 고을 둘레 고리에서 토지이용을 보고 논밭(농부·소)·풀밭(말·소) 자리를 더한다. 바닷가 고을 위에는 갈매기.
#   - 어떤 사람이 나오는지는 고을 profile.people/animals(+유형 기본값, REGION_CONTRACTS §9)를 프레임 종류로 옮겨 고른다.
# 스트리밍 — 0.4초마다 플레이어 150m 안 자리의 칸(slot)을 보고(있을지·누구일지는 칸 번호 해시로 결정적)
#   날씨(비: 바깥 사람 줄고 도롱이, 눈: 줄고 들일 없음)·밤(거의 없음, 주막은 그대로)을 곱한 뒤 가까운 순으로 사람 110·짐승 36까지.
#   화면 안 가까운 곳에서는 새로 나타나거나 사라지지 않는다(처음 채울 때만 예외). SpriteChar는 종류별로 풀에 돌려 다시 쓴다.
# 비용 — 화면 밖 인물은 그림·높이 갱신을 건너뛰고, 35m 밖은 그림자를 끄고, 먹색 실루엣은 쓰지 않는다.
# 프레임: data/frames_npc.json(웹 마을 사람 9종) + data/frames_amb.json(tools/export_npc_frames.js가 구운 고을 사람·짐승).
#   frames_amb.json이 없으면 고을 사람은 가까운 기본 종류로 대신하고 짐승은 나오지 않는다.
extends Node3D

const R_ACTIVE := 150.0
const R_DROP := 175.0
const NEAR_POP := 70.0        # 이 안의 화면 속에서는 생기거나 사라지지 않는다
const MAX_PEOPLE := 150
const MAX_ANIMALS := 36
const CELL := 64.0
const SCAN := 0.4
const STEP := 8.0             # 길 자리 간격(m)
const SLOTS := 64             # 자리 하나의 최대 칸

# region.json people → 프레임 종류
const PEOPLE_KIND := {
	"농부": ["farmer", "farmwife", "farmer"], "채소 농부": ["farmer", "farmwife"], "아낙": ["farmwife", "villager_f"], "빨래하는 아낙": ["farmwife", "villager_f"],
	"장꾼": ["merchant", "peddler", "villager_f"], "상인": ["merchant"], "시전 상인": ["merchant", "merchant", "scholar"], "난전 상인": ["merchant", "villager_f"],
	"채소 장수": ["villager_f", "farmwife"], "어물 장수": ["merchant", "villager_f"], "소금 장수": ["peddler"], "젓갈 장수": ["villager_f", "merchant"], "명태 장수": ["peddler", "merchant"],
	"거간": ["merchant"], "객주": ["merchant"], "보부상": ["peddler"], "짐꾼": ["peddler", "villager_m"], "가마꾼": ["villager_m"],
	"뱃사공": ["boatman"], "선주": ["merchant", "boatman"], "어부": ["boatman"], "해녀": ["haenyeo"],
	"나그네": ["traveler", "peddler"], "주모": ["innkeeper"],
	"양반": ["scholar"], "유생": ["scholar"], "가난한 선비": ["scholar"], "남산골 딸깍발이": ["scholar"], "중인": ["scholar", "merchant"], "역관": ["scholar"], "의원": ["scholar"],
	"관속": ["official"], "관원": ["official", "scholar"], "감영 관속": ["official"], "역졸": ["official"], "포교": ["official"], "군관": ["official"], "진졸": ["official"], "능지기": ["villager_m"],
	"사신 행렬": ["official", "scholar"], "청지기": ["villager_m"], "몸종": ["villager_f"], "기생": ["villager_f"], "장인": ["miller", "villager_m"], "빙고 일꾼": ["villager_m"],
	"스님": ["monk"], "보살": ["bosal"], "무당": ["shaman"], "심방": ["shaman"],
	"목자": ["herder"], "말꾼": ["herder"], "사냥꾼": ["hunter"], "약초꾼": ["woodcutter"], "숯쟁이": ["woodcutter"],
	"김선달 같은 건달": ["traveler"],
}
const ANIMAL_KIND := { "소": "ox", "말": "horse", "개": "dog", "갈매기": "gull", "닭": "hen" }
const ANIMALS := ["ox", "horse", "dog", "hen", "rooster", "gull"]
# 구운 고을 사람이 없을 때 대신할 기본 종류
const FALLBACK := { scholar = "elder", merchant = "villager_m", peddler = "woodcutter", official = "hunter", monk = "villager_m", bosal = "villager_f",
	boatman = "villager_m", haenyeo = "villager_f", farmer = "villager_m", farmwife = "villager_f", herder = "hunter", raincape = "villager_m",
	traveler = "villager_m", shaman = "innkeeper" }
const CAPE := ["farmer", "villager_m", "peddler", "boatman", "woodcutter", "herder", "miller"]   # 비 오면 도롱이로 바꿔 입는 사람
const SPEED := { ox = 0.7, horse = 0.95, dog = 1.3, hen = 0.45, rooster = 0.45, gull = 6.0 }
const STRIDE_REAL := { ox = 1.4, horse = 1.6, dog = 0.75, hen = 0.3, rooster = 0.3, gull = 1.2 }
# 고을 밀도(길 m²당 사람)
const RHO := { market = 0.14, capital = 0.012, eupchi = 0.012, port = 0.014, village = 0.01, lane = 0.006 }
# 키트 → 닻 자리
const ANCHOR := {
	"village/market_shop": "stall", "village/jwapan": "stall", "landmark/hy_sijeon": "stall",
	"village/jumak": "inn", "village/narutbae": "ferry", "landmark/py_daedong_naru": "ferry",
	"village/well": "wash", "village/ppallaeteo": "wash",
	"village/village_square": "square", "nature/big_tree": "square",
	"landmark/hyanggyo": "scholars", "landmark/gn_chilsadang": "scholars",
	"landmark/gwana": "office", "landmark/dongheon": "office", "landmark/gaeksa": "office", "landmark/hj_gaeksa": "office", "landmark/naea": "office",
	"landmark/hyeon_gwana": "office", "landmark/gn_gwana": "office", "landmark/jj_mokgwana": "office", "landmark/hy_yukjo": "office", "landmark/samun": "gate",
	"landmark/seongmun": "gate", "landmark/hy_sungnyemun": "gate", "landmark/hy_heunginjimun": "gate", "landmark/hy_donuimun": "gate", "landmark/hy_sukjeongmun": "gate",
	"landmark/gj_eupseong_gate": "gate", "landmark/hh_eupseong_gate": "gate", "landmark/hj_eupseong_gate": "gate", "landmark/hy_gwanghwamun": "gate", "landmark/hy_palace_gate": "gate",
	"landmark/silsangsa": "temple", "landmark/gj_bulguksa": "temple", "landmark/gj_daeungjeon": "temple", "landmark/cheonwangmun": "temple", "landmark/bogwangjeon": "temple",
	"landmark/yaksajeon": "temple", "landmark/gj_seokguram": "temple",
	"village/haystack": "field", "nature/garden_plot": "field", "village/teotbat": "field", "nature/pumpkin_vine": "field",
	"village/seonghwangdang": "shrine", "village/cairn": "shrine", "village/jangseung": "shrine", "village/stone_jangseung": "shrine",
}
const HOUSE_HINT := ["compound", "choga", "giwa", "stone_house", "neowa_house", "guitul_house", "gulpi_house", "house_compound"]

var world
var weather
var cam: Camera3D
var placement
var hour := 12.0
var enabled := true
var stats := { sites = 0, agents = 0, people = 0, animals = 0, on_screen = 0, ms_build = 0 }

var sites: Array = []
var paths: Array = []        # { pts: PackedVector2Array, cum: PackedFloat32Array, len, hw }
var _grid := {}              # Vector2i → PackedInt32Array(자리 번호)
var agents := {}             # 칸 키 → 에이전트
var _pool := {}              # 종류 → [SpriteChar]
var _task := -1
var _built: Dictionary = {}
var _pending_pages: Array = []   # [[종류, 번호, Image]]
var _bank_src := {}              # 종류 → { pages:[파일], clips }
var _tex_cache := {}             # 파일 → ImageTexture
var _ready_kinds := {}
var _scan_t := 0.0
var _fill_until := 0.0           # 처음 채우기: 이때까지는 화면 안에서도 생긴다
var _clock := 0.0
var _player := Vector3.ZERO
var _amb := false                # frames_amb.json 있음
var _frame := 0
var _debug := OS.get_cmdline_user_args().has("--npcstats")
var _fail := {}               # 칸 키 → 다시 해 볼 시각(자리를 못 찾음)

func setup(w, wthr, camera: Camera3D, loader = null) -> void:
	world = w; weather = wthr; cam = camera; placement = loader
	name = "npc_ambient"
	var files: Array = []
	if placement != null:
		for f in placement.files(): files.append(ProjectSettings.globalize_path(f))
	var input := { region = world.region, files = files, seed = hash(String(world.region.get("region_id", "r"))) }
	_task = WorkerThreadPool.add_task(_build.bind(input), false, "npc_ambient sites")

func jobs_idle() -> bool:
	return _task < 0 or WorkerThreadPool.is_task_completed(_task)

func _exit_tree() -> void:
	if _task >= 0: WorkerThreadPool.wait_for_task_completion(_task); _task = -1

# ---------------------------------------------------------------------------
# 자리 만들기(작업 스레드) — world는 읽기만(landuse_at)
# ---------------------------------------------------------------------------
static func _h(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffffff) / 16777216.0

func _settle_info(s: Dictionary, arch: Dictionary) -> Dictionary:
	var pr: Dictionary = s.get("profile", {}) if s.get("profile") is Dictionary else {}
	var a := String(pr.get("archetype", "plain"))
	var base: Dictionary = arch.get(a, {}) if arch.get(a) is Dictionary else {}
	var people: Array = pr.get("people", base.get("people", []))
	var animals: Array = pr.get("animals", base.get("animals", []))
	var typ := String(s.get("type", ""))
	var cls := "village"
	if typ == "장시" or String(pr.get("district", "")) == "jongno": cls = "market"
	elif a == "capital": cls = "capital"
	elif a == "eupchi" or typ == "읍성": cls = "eupchi"
	elif a in ["river", "coast", "island"]: cls = "port"
	var pool: Array = []
	for p in people:
		for k in PEOPLE_KIND.get(String(p), []): pool.append(k)
	# 누구나: 마을 사람·노인·아이(도성·장시는 조금 덜)
	var gen := ["villager_m", "villager_f", "villager_m", "villager_f", "elder", "child_boy", "child_girl"]
	if cls in ["market", "capital"]: gen = ["villager_m", "villager_f", "villager_m", "elder", "peddler"]
	var mix: Array = pool.duplicate()
	for g in gen: mix.append(g)
	if pool.size() > 2: mix.append_array(pool)   # 고을 사람이 많으면 그쪽으로 기운다
	var an: Array = []
	for x in animals:
		if ANIMAL_KIND.has(String(x)): an.append(ANIMAL_KIND[String(x)])
	return { id = String(s.get("id", "")), c = Vector2(float(s.x), float(s.z)), r = clampf(float(s.get("radius_m", 60.0)) * 1.25, 45.0, 260.0),
		cls = cls, arch = a, pool = mix if not mix.is_empty() else gen, own = pool, animals = an,
		chickens = a in ["plain", "river", "island", "mountain", "coast", "temple"] and cls != "market" }

func _build(input: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	var reg: Dictionary = input.region
	var arch: Dictionary = reg.get("archetypes", {}) if reg.get("archetypes") is Dictionary else {}
	var sts: Array = []
	for s in reg.get("settlements", []):
		if s is Dictionary and s.has("x"): sts.append(_settle_info(s, arch))
	var out_sites: Array = []
	var out_paths: Array = []
	var anchors: Array = []
	# 길·고샅
	var lines: Array = []
	for r in reg.get("roads", []):
		if r is Dictionary: lines.append({ pts = r.get("points", []), w = float(r.get("width_m", 4.0)), cls = String(r.get("class", "지선")), alley = false })
	for f in input.files:
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary): continue
		for al in d.get("alleys", []):
			if al is Dictionary: lines.append({ pts = al.get("points", []), w = float(al.get("width_m", 3.0)), cls = "마을길", alley = true })
		for it in d.get("items", []):
			if not (it is Dictionary) or not it.has("kit"): continue
			var kit := String(it.kit)
			var mode: String = ANCHOR.get(kit, "")
			if mode == "":
				for hh in HOUSE_HINT:
					if kit.ends_with(hh): mode = "yard"; break
			if mode != "": anchors.append([mode, Vector2(float(it.get("x", 0.0)), float(it.get("z", 0.0))), float(it.get("ry", 0.0)), kit])
	var route_acc := 0.0
	for L in lines:
		var raw: Array = L.pts
		if raw.size() < 2: continue
		var pts := PackedVector2Array()
		for q in raw: pts.append(Vector2(float(q[0]), float(q[1])))
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()): cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var total: float = cum[cum.size() - 1]
		if total < 4.0: continue
		var pi := out_paths.size()
		var hw := clampf(float(L.w) * 0.5, 0.8, 9.0)
		out_paths.append({ pts = pts, cum = cum, len = total, hw = hw })
		var s := STEP * 0.5
		while s < total:
			var p := _at(pts, cum, s)
			if world != null and world.landuse_at(p.x, p.y) == 5:   # 물 위 길(강 뱃길·선창)에는 사람을 세우지 않는다
				s += STEP
				continue
			var st = _settle_at(sts, p)
			if st != null:
				var rho: float = RHO[st.cls] if not L.alley or st.cls != "market" else RHO.capital
				var exp_n := rho * STEP * minf(hw * 2.0, 16.0)
				if exp_n > 0.02:
					var stand := 0.3 if st.cls == "market" else 0.15
					out_sites.append({ p = p, mode = "street", path = pi, s = s, n = mini(ceili(exp_n), SLOTS), pres = exp_n / ceilf(exp_n),
						pool = st.pool, stand = stand, hw = hw, kind_cls = "people", st = st.id, out = true })
			elif not L.alley:
				route_acc += STEP
				var every := 200.0 if L.cls == "산길" else 120.0
				if route_acc >= every:
					route_acc = 0.0
					var rp := ["traveler", "peddler", "villager_m", "farmer", "official", "traveler", "monk"] if L.cls != "산길" else ["woodcutter", "hunter", "traveler", "monk"]
					out_sites.append({ p = p, mode = "street", path = pi, s = s, n = 1, pres = 0.45 if L.cls != "산길" else 0.25, pool = rp, stand = 0.0, hw = hw,
						kind_cls = "people", st = "", out = true, roam = 90.0 })
			s += STEP
	# 닻 자리
	for a in anchors:
		var mode: String = a[0]; var p: Vector2 = a[1]
		var st = _settle_at(sts, p)
		var pool: Array = st.pool if st != null else ["villager_m", "villager_f"]
		var own: Array = st.own if st != null else []
		var an: Array = st.animals if st != null else []
		var cls: String = st.cls if st != null else "village"
		var site := { p = p, ry = a[2], mode = mode, n = 1, pres = 1.0, pool = pool, kind_cls = "people", out = true, r = 1.5, anim = "idle" }
		match mode:
			"stall":
				site.n = 2; site.pres = 0.9; site.anim = "talk"
				site.pool = _pick_pool(own, ["merchant", "villager_f", "merchant", "farmwife", "haenyeo"], ["merchant", "villager_f", "merchant"])
				site.night = 0.05
			"inn": site.n = 3; site.pres = 0.8; site.pool = ["innkeeper", "traveler", "peddler", "traveler", "official"]; site.night = 1.0; site.out = false; site.r = 3.0
			"ferry": site.n = 2; site.pres = 0.7; site.pool = ["boatman", "boatman", "traveler", "peddler"]; site.r = 2.0
			"wash":
				site.n = 2; site.pres = 0.6; site.anim = "talk"
				site.pool = ["haenyeo", "farmwife", "villager_f"] if own.has("haenyeo") else ["farmwife", "villager_f", "villager_f", "child_girl"]
			"square": site.n = 3; site.pres = 0.55; site.pool = ["elder", "elder", "child_boy", "child_girl", "villager_m", "villager_f"] + own; site.r = 4.0
			"scholars": site.n = 3; site.pres = 0.8; site.pool = ["scholar"]; site.r = 6.0
			"office": site.n = 2; site.pres = 0.8; site.pool = ["official", "official", "scholar"]; site.r = 5.0; site.night = 0.3
			"gate": site.n = 2; site.pres = 0.85; site.pool = ["official"]; site.r = 3.0; site.night = 0.6
			"temple": site.n = 3; site.pres = 0.8; site.pool = ["monk", "monk", "bosal"]; site.r = 6.0
			"shrine": site.n = 1; site.pres = 0.3; site.pool = ["traveler", "shaman", "villager_f"]; site.r = 3.0
			"field":
				site.n = 1; site.pres = 0.55; site.pool = _pick_pool(own, ["farmer", "farmwife", "haenyeo"], ["farmer", "farmwife", "farmer"]); site.r = 5.0; site.field = true; site.night = 0.0
				if an.has("ox") or (cls == "village" and an.is_empty()):
					out_sites.append({ p = p + Vector2(4, 3).rotated(a[2]), mode = "graze", n = 1, pres = 0.3, pool = ["ox"], kind_cls = "animal", out = false, r = 5.0, anim = "eat" })
			"yard":
				if st == null or cls in ["market"]: continue
				# 집 앞 사람(마당·문간에 서 있거나 거닐기)
				out_sites.append({ p = p, ry = a[2], mode = "home", n = 1, pres = 0.12 if cls == "capital" else 0.3, pool = st.pool, kind_cls = "people", out = true, r = 4.0,
					anim = "idle", night = 0.05 })
				var dog := an.has("dog") or cls in ["village", "port"]
				var hens: bool = st.chickens
				if not dog and not hens: continue
				site = { p = p, ry = a[2], mode = "yard", n = 4 if hens else 1, pres = 0.0, pool = [], kind_cls = "animal", out = false, r = 3.5, anim = "eat", hens = hens, dog = dog }
				if cls == "capital": site.n = 1
		out_sites.append(site)
	# 고을 둘레 들·풀밭, 바닷가 갈매기
	for st in sts:
		var c: Vector2 = st.c
		var n_ring := 10 if st.cls != "market" else 0
		for k in n_ring:
			var ang := _h(hash(st.id), k) * TAU
			var d: float = st.r * 0.8 + 30.0 + _h(hash(st.id), k + 100) * 140.0
			var p := c + Vector2(cos(ang), sin(ang)) * d
			var lu: int = world.landuse_at(p.x, p.y)
			if lu == 2 or lu == 3:
				out_sites.append({ p = p, mode = "field", n = 2, pres = 0.5, pool = _pick_pool(st.own, ["farmer", "farmwife", "haenyeo"], ["farmer", "farmwife", "farmer"]),
					kind_cls = "people", out = true, r = 7.0, anim = "idle", field = true, night = 0.0 })
				if st.animals.has("ox") or st.arch == "plain":
					out_sites.append({ p = p + Vector2(6, -4), mode = "graze", n = 1, pres = 0.4, pool = ["ox"], kind_cls = "animal", out = false, r = 6.0, anim = "eat" })
			elif lu == 1:
				if st.animals.has("horse"):
					out_sites.append({ p = p, mode = "graze", n = 4, pres = 0.75, pool = ["horse"], kind_cls = "animal", out = false, r = 14.0, anim = "eat" })
					out_sites.append({ p = p + Vector2(5, 5), mode = "field", n = 1, pres = 0.4, pool = ["herder"], kind_cls = "people", out = true, r = 8.0, anim = "idle", night = 0.0 })
				elif st.animals.has("ox"):
					out_sites.append({ p = p, mode = "graze", n = 2, pres = 0.5, pool = ["ox"], kind_cls = "animal", out = false, r = 10.0, anim = "eat" })
		if st.animals.has("gull"):
			for k in 2:
				out_sites.append({ p = c + Vector2(cos(k * 2.4 + 0.7), sin(k * 2.4 + 0.7)) * (st.r * 0.6), mode = "gull", n = 3, pres = 0.8, pool = ["gull"],
					kind_cls = "animal", out = false, r = 18.0 })
	_built = { sites = out_sites, paths = out_paths, ms = Time.get_ticks_msec() - t0 }

func _pick_pool(own: Array, prefer: Array, dflt: Array) -> Array:
	var p: Array = []
	for k in own:
		if prefer.has(k): p.append(k)
	return p if not p.is_empty() else dflt

func _settle_at(sts: Array, p: Vector2) -> Variant:
	var best = null; var bd := INF
	for st in sts:
		var d: float = p.distance_to(st.c)
		if d < st.r and d / st.r < bd: bd = d / st.r; best = st
	return best

static func _at(pts: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	var n := pts.size()
	s = clampf(s, 0.0, cum[n - 1])
	var lo := 0; var hi := n - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if cum[m] <= s: lo = m
		else: hi = m
	var seg := maxf(cum[hi] - cum[lo], 1e-4)
	return pts[lo].lerp(pts[hi], (s - cum[lo]) / seg)

static func _dir_at(pts: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	var n := pts.size()
	var i := 0
	while i < n - 2 and cum[i + 1] < s: i += 1
	return (pts[i + 1] - pts[i]).normalized()

# ---------------------------------------------------------------------------
# 프레임 뱅크(작업 스레드에서 PNG 읽기 → 메인에서 텍스처, 프레임당 2장)
# ---------------------------------------------------------------------------
func _finish_build() -> void:
	sites = _built.sites; paths = _built.paths
	stats.sites = sites.size(); stats.ms_build = _built.ms
	for i in sites.size():
		var c := Vector2i(floori(sites[i].p.x / CELL), floori(sites[i].p.y / CELL))
		if not _grid.has(c): _grid[c] = PackedInt32Array()
		_grid[c].append(i)
	# 쓸 종류
	var kinds := {}
	for s in sites:
		for k in s.pool: kinds[k] = true
		if s.mode == "yard":
			if s.hens: kinds.hen = true; kinds.rooster = true
			if s.dog: kinds.dog = true
		if s.get("out", false):
			for k in s.pool:
				if k in CAPE: kinds.raincape = true
	var src := {}
	for jf in ["frames_npc.json", "frames_amb.json"]:
		var path: String = "res://data/" + jf
		if not FileAccess.file_exists(path): continue
		var all = JSON.parse_string(FileAccess.get_file_as_string(path))
		if all is Dictionary:
			for k in all: src[k] = all[k]
			if jf == "frames_amb.json": _amb = true
	for k in kinds:
		var real := _real_kind(k, src)
		if real != "" and src.has(real) and not SpriteChar._banks.has(real): _bank_src[real] = src[real]
	var want := []
	for k in _bank_src:
		for p in _bank_src[k].pages:
			if not want.has(p) and not _tex_cache.has(p): want.append(p)
	_task = WorkerThreadPool.add_task(_load_pages.bind(want), false, "npc_ambient pages")
	print("NPC sites=%d paths=%d kinds=%d pages=%d build_ms=%d amb=%s" % [sites.size(), paths.size(), _bank_src.size(), want.size(), _built.ms, _amb])
	_built = {}

func _real_kind(k: String, src: Dictionary) -> String:
	if src.has(k) or SpriteChar._banks.has(k): return k
	if FALLBACK.has(k) and (src.has(FALLBACK[k]) or SpriteChar._banks.has(FALLBACK[k])): return FALLBACK[k]
	return ""

func _load_pages(files: Array) -> void:
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://data/" + f))
		if img == null or img.is_empty(): continue
		img.generate_mipmaps()
		_pending_pages.append([f, img])   # Array.append은 메인이 읽는 동안에도 안전하게 끝에 붙는다(메인은 작업이 끝난 뒤 읽는다)

func _upload_pages() -> void:
	var n := 0
	while not _pending_pages.is_empty() and n < 3:
		var e: Array = _pending_pages.pop_front()
		_tex_cache[e[0]] = ImageTexture.create_from_image(e[1]); n += 1
	if _pending_pages.is_empty():
		for k in _bank_src.keys():
			var ok := true
			var pages := []
			for p in _bank_src[k].pages:
				if not _tex_cache.has(p): ok = false; break
				pages.append(_tex_cache[p])
			if ok:
				SpriteChar._banks[k] = { pages = pages, clips = _bank_src[k].clips }
				_bank_src.erase(k)

# ---------------------------------------------------------------------------
# 매 프레임
# ---------------------------------------------------------------------------
func update(dt: float, player: Vector3, h: float, loading: bool) -> void:
	_frame += 1
	_clock += dt
	hour = h; _player = player
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task): return
		WorkerThreadPool.wait_for_task_completion(_task); _task = -1
		if not _built.is_empty():
			_finish_build(); return
		_pending_pages = _pending_pages   # 페이지 읽기 끝
	if not _pending_pages.is_empty() or not _bank_src.is_empty():
		_upload_pages()
		if not _pending_pages.is_empty(): return
	if sites.is_empty() or not enabled: return
	if loading:
		_fill_until = _clock + 2.5
		return
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = SCAN
		_scan()
	_step_agents(dt)

func _presence(site: Dictionary) -> float:
	var f: float = site.pres
	var night := TimeOfDay.night_factor(hour)
	var rain: float = weather.cur.rain if weather != null else 0.0
	var snow: float = weather.cur.snowfall if weather != null else 0.0
	if site.kind_cls == "people":
		f *= lerpf(1.0, float(site.get("night", 0.12)), night)
		if site.get("out", false):
			if site.get("field", false): f *= (1.0 - 0.85 * rain) * (1.0 - 0.95 * snow)
			else: f *= (1.0 - 0.55 * rain) * (1.0 - 0.5 * snow)
	elif site.mode == "yard":
		f = 0.35 * (1.0 - 0.8 * rain) * (1.0 - 0.9 * snow) * (1.0 - night)
	elif site.mode == "gull":
		f *= (1.0 - 0.7 * rain) * (1.0 - snow) * (1.0 - night)
	else:
		f *= 1.0 - 0.6 * night
	return f

func _slot_kind(site: Dictionary, si: int, i: int) -> String:
	var hk := _h(si * 7 + 11, i * 13 + 5)
	if site.mode == "yard":
		if i == 0 and site.dog and (not site.hens or _h(si, 91) < 0.4): return "dog"
		if not site.hens: return ""
		return "rooster" if i == 1 else "hen"
	var pool: Array = site.pool
	if pool.is_empty(): return ""
	var k: String = pool[int(hk * pool.size()) % pool.size()]
	if site.get("out", false) and k in CAPE and weather != null and weather.cur.rain > 0.3 and _h(si, i + 300) < 0.75: k = "raincape"
	return k

func _scan() -> void:
	var p2 := Vector2(_player.x, _player.z)
	var c := Vector2i(floori(p2.x / CELL), floori(p2.y / CELL))
	var rc := ceili(R_ACTIVE / CELL)
	var want_p: Array = []; var want_a: Array = []
	for dz in range(-rc, rc + 1):
		for dx in range(-rc, rc + 1):
			var g = _grid.get(c + Vector2i(dx, dz))
			if g == null: continue
			for si in g:
				var site: Dictionary = sites[si]
				var d: float = p2.distance_to(site.p)
				if d > R_ACTIVE: continue
				var pres := _presence(site)
				if pres <= 0.0: continue
				for i in site.n:
					if _h(si, i) >= pres: continue
					var k := _slot_kind(site, si, i)
					if k == "" or not SpriteChar._banks.has(_kind_bank(k)): continue
					var e := [d + i * 0.01, si * SLOTS + i, k]
					if site.kind_cls == "people": want_p.append(e)
					else: want_a.append(e)
	want_p.sort_custom(func(a, b): return a[0] < b[0])
	want_a.sort_custom(func(a, b): return a[0] < b[0])
	var want := {}
	for j in mini(want_p.size(), MAX_PEOPLE): want[want_p[j][1]] = want_p[j][2]
	for j in mini(want_a.size(), MAX_ANIMALS): want[want_a[j][1]] = want_a[j][2]
	var filling := _clock < _fill_until
	# 놓기 — 화면 안 가까운 곳은 처음 채울 때만
	for key in agents.keys():
		var ag: Dictionary = agents[key]
		var keep: bool = want.get(key, "") == ag.kind
		if keep: continue
		var site: Dictionary = sites[key / SLOTS]
		var far: bool = p2.distance_to(site.p) > R_DROP or p2.distance_to(Vector2(ag.pos.x, ag.pos.z)) > R_DROP
		if far or filling or not _visible_near(ag.pos):
			_release(key)
	var budget := 400 if filling else 30
	for key in want:
		if agents.has(key) or _fail.get(key, -1.0) > _clock: continue
		if not _spawn(key, want[key], filling): _fail[key] = _clock + 3.0 + _h(key, 55) * 3.0
		budget -= 1
		if budget <= 0: break
	stats.agents = agents.size()
	stats.want = want.size()
	if _debug and int(_clock / 2.0) != int((_clock - SCAN) / 2.0):
		var hist := [0, 0, 0, 0, 0]
		for kk in agents:
			var dd: float = Vector2(agents[kk].pos.x - _player.x, agents[kk].pos.z - _player.z).length()
			hist[mini(4, int(dd / 20.0))] += 1
		print("NPC dist20=", hist, " modes=", agents.values().map(func(a): return a.mode).slice(0, 12))
		print("NPC agents=%d want=%d people=%d animals=%d on_screen=%d cand_p=%d cand_a=%d" % [agents.size(), want.size(), stats.people, stats.animals, stats.on_screen, want_p.size(), want_a.size()])

func _kind_bank(k: String) -> String:
	if SpriteChar._banks.has(k): return k
	return FALLBACK.get(k, k)

func _visible_near(pos: Vector3) -> bool:
	return Vector2(pos.x - _player.x, pos.z - _player.z).length() < NEAR_POP and cam.is_position_in_frustum(pos + Vector3(0, 1.0, 0))

func _tile_ready(p: Vector2) -> bool:
	var t: Vector2i = world.tile_of(p.x, p.y)
	if not world.tiles.has(t) or world.tiles[t].lod != 0: return false
	return placement == null or not placement.busy_near(t, 0)

func _free_near(c: Vector2, r: float, seed: int, rad: float) -> Variant:
	for ring in [0.0, 1.5, 3.0, 4.5, 6.5, 9.0]:
		var rr: float = ring + (r * _h(seed, 3) if ring == 0.0 else 0.0)
		for k in 8:
			var a := (_h(seed, 7) + k / 8.0) * TAU
			var p := c + Vector2(cos(a), sin(a)) * rr
			if not world.blocked(p.x, p.y, rad) and world.interior_at(p.x, p.y) == null: return p
			if rr == 0.0: break
	return null

func _spawn(key: int, kind: String, filling: bool) -> bool:
	var si := key / SLOTS; var i := key % SLOTS
	var site: Dictionary = sites[si]
	var ag := { key = key, kind = kind, mode = site.mode, state = "idle", t = 0.5 + _h(key, 1) * 3.0, home = site.p, target = site.p, speed = 1.0,
		animal = kind in ANIMALS, anim = String(site.get("anim", "idle")), on = false, yt = 0 }
	var p: Vector2
	if site.mode == "street":
		var P: Dictionary = paths[site.path]
		var stand: bool = _h(key, 77) < float(site.stand)
		ag.path = site.path
		ag.s = clampf(float(site.s) + (_h(key, 5) - 0.5) * STEP, 0.0, P.len)
		ag.s0 = ag.s
		ag.lat = (_h(key, 9) - 0.5) * 2.0 * float(site.hw) * 0.75
		ag.dir = 1.0 if _h(key, 4) < 0.5 else -1.0
		ag.roam = float(site.get("roam", 35.0 + _h(key, 6) * 40.0))
		ag.speed = 1.0 + _h(key, 8) * 0.45
		ag.mode = "stand" if stand else "walk"
		ag.state = "idle" if stand else "walk"
		ag.anim = "talk" if stand and _h(key, 12) < 0.5 else "idle"
		p = _path_pos(ag)
		if site.kind_cls == "people" and not world.tiles.has(world.tile_of(p.x, p.y)): return false
	elif site.mode == "gull":
		ag.ang = _h(key, 2) * TAU; ag.rad = float(site.r) * (0.6 + _h(key, 3) * 0.6); ag.alt = 9.0 + _h(key, 4) * 7.0
		ag.w = (0.25 + _h(key, 5) * 0.2) * (1.0 if _h(key, 6) < 0.5 else -1.0)
		p = site.p + Vector2(cos(ag.ang), sin(ag.ang)) * ag.rad
	else:
		if not _tile_ready(site.p): return false
		var rad := 0.6 if kind in ["ox", "horse"] else 0.3
		var q = _free_near(site.p, float(site.get("r", 2.0)), key, rad)
		if q == null: return false
		p = q
		ag.home = p
		ag.r = float(site.get("r", 2.0))
		if ag.animal:
			ag.speed = SPEED.get(kind, 1.0) * (0.85 + _h(key, 8) * 0.3)
		else:
			ag.speed = 0.7 + _h(key, 8) * 0.3
			if site.mode in ["stall", "wash", "inn", "square", "office", "gate"]: ag.anim = "talk" if _h(key, 12) < 0.5 else "idle"
	if p.distance_to(Vector2(_player.x, _player.z)) < 1.2: return false   # 플레이어 자리에 겹쳐 나타나지 않게
	var pos := Vector3(p.x, 0.0, p.y)
	if not filling and site.mode != "gull" and _visible_near(Vector3(p.x, world.height_at(p.x, p.y), p.y)): return false
	var ch := _take(kind)
	if ch == null: return false
	ag.ch = ch
	ag.pos = pos
	_place(ag, p)
	ch.facing = ["down", "left", "right", "up"][int(_h(key, 21) * 4.0) % 4]
	if ag.animal and ch.facing in ["up", "down"]: ch.facing = "left" if _h(key, 22) < 0.5 else "right"
	ch.set_anim(ag.anim if ag.state == "idle" else "walk")
	ch.anim_time = _h(key, 23) * 3.0
	ch.t = _h(key, 24) * 5.0
	agents[key] = ag
	return true

func _take(kind: String) -> SpriteChar:
	var bank := _kind_bank(kind)
	if not SpriteChar._banks.has(bank): return null
	var ch: SpriteChar
	var lst: Array = _pool.get(bank, [])
	if not lst.is_empty():
		ch = lst.pop_back()
		ch.visible = true
	else:
		ch = SpriteChar.new(bank)
		add_child(ch)
		ch.set_silhouette(false)
		ch._sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if bank == "gull": ch._blob.visible = false
		if bank in ["hen", "rooster"]: ch._blob.scale = Vector3(0.45, 1, 0.3)
		elif bank == "dog": ch._blob.scale = Vector3(0.9, 1, 0.4)
		elif bank in ["ox", "horse"]: ch._blob.scale = Vector3(2.4, 1, 0.8)
	ch.move_speed = -1.0
	return ch

func _release(key: int) -> void:
	var ag: Dictionary = agents[key]
	agents.erase(key)
	var ch: SpriteChar = ag.ch
	ch.visible = false
	var bank := ch.kind
	if not _pool.has(bank): _pool[bank] = []
	_pool[bank].append(ch)

func _path_pos(ag: Dictionary) -> Vector2:
	var P: Dictionary = paths[ag.path]
	var p := _at(P.pts, P.cum, ag.s)
	var d := _dir_at(P.pts, P.cum, ag.s)
	return p + Vector2(-d.y, d.x) * float(ag.lat)

func _place(ag: Dictionary, p: Vector2) -> void:
	var y: float
	if ag.mode == "gull":
		var g: float = world.height_at(p.x, p.y)
		if not is_nan(world.sea_y): g = maxf(g, world.sea_y)
		y = g + ag.alt
	else:
		y = world.height_at(p.x, p.y)
	ag.pos = Vector3(p.x, y, p.y)
	ag.ch.position = ag.pos

static func _facing(dx: float, dz: float, prev: String) -> String:
	if dx == 0.0 and dz == 0.0: return prev
	if absf(dx) > absf(dz) * 1.15: return "right" if dx > 0.0 else "left"
	return "down" if dz > 0.0 else "up"

func _step_agents(dt: float) -> void:
	var on := 0
	var np := 0
	for key in agents:
		var ag: Dictionary = agents[key]
		var ch: SpriteChar = ag.ch
		var vis: bool = cam.is_position_in_frustum(ag.pos + Vector3(0, 1.0, 0))
		var old := Vector2(ag.pos.x, ag.pos.z)
		var p := old
		ag.t -= dt
		match ag.mode:
			"walk":
				if ag.state == "walk":
					var P: Dictionary = paths[ag.path]
					var ns: float = ag.s + ag.dir * ag.speed * dt
					var turn: bool = ns <= 0.0 or ns >= P.len or absf(ns - ag.s0) > ag.roam
					var nxt := _at(P.pts, P.cum, ns)
					if Vector2(_player.x, _player.z).distance_to(nxt) < 0.9: ag.state = "idle"; ag.t = 0.6   # 플레이어 앞에서 멈칫
					elif turn:
						ag.dir = -ag.dir; ag.state = "idle"; ag.t = 1.0 + _h(key, int(_clock)) * 3.0
					else:
						ag.s = ns
						p = _path_pos(ag)
				elif ag.t <= 0.0:
					ag.state = "walk"
					if _h(key, int(_clock * 3.0)) < 0.15: ag.state = "idle"; ag.t = 2.0 + _h(key, 31) * 5.0
			"stand":
				pass
			"gull":
				ag.ang += ag.w * dt
				p = ag.home + Vector2(cos(ag.ang), sin(ag.ang)) * ag.rad
				if ag.t <= 0.0:
					ag.t = 1.5 + _h(key, int(_clock)) * 3.0
					ch.set_anim("idle" if ch.anim == "walk" else "walk")
			_:
				# 둘레 거닐기(닻·들·짐승)
				if ag.state == "walk":
					var to: Vector2 = ag.target - p
					var step: float = ag.speed * dt
					if to.length() <= step or ag.t <= 0.0:
						ag.state = "idle"; ag.t = (2.0 if ag.animal else 3.0) + _h(key, int(_clock * 7.0)) * (6.0 if ag.animal else 9.0)
					else:
						p += to.normalized() * step
				elif ag.t <= 0.0:
					var r: float = ag.r
					var a := _h(key, int(_clock * 5.0) + 1) * TAU
					var tgt: Vector2 = ag.home + Vector2(cos(a), sin(a)) * r * sqrt(_h(key, int(_clock * 5.0) + 2))
					var rad := 0.6 if ag.kind in ["ox", "horse"] else 0.3
					if r > 0.5 and not world.blocked(tgt.x, tgt.y, rad) and world.interior_at(tgt.x, tgt.y) == null:
						ag.target = tgt; ag.state = "walk"; ag.t = tgt.distance_to(p) / maxf(0.1, ag.speed) + 1.0
					else:
						ag.t = 2.0 + _h(key, 41) * 4.0
		var moved := p != old
		if moved:
			var dx := p.x - old.x; var dz := p.y - old.y
			if ag.animal:
				if absf(dx) > 1e-4: ch.facing = "right" if dx > 0.0 else "left"
			else:
				ch.facing = _facing(dx, dz, ch.facing)
			# 높이: 화면 안이면 매 프레임, 밖이면 가끔
			if vis or (_frame + key) % 8 == 0 or ag.mode == "gull":
				_place(ag, p)
			else:
				ag.pos = Vector3(p.x, ag.pos.y, p.y); ch.position = ag.pos
		var want_anim: String
		if ag.mode == "gull": want_anim = ch.anim
		elif moved: want_anim = "walk"
		else: want_anim = ag.anim
		ch.set_anim(want_anim)
		if ag.animal and moved and ag.mode != "gull":
			ch.move_speed = ag.speed * 1.6987 / float(STRIDE_REAL.get(ag.kind, 1.0))
		if vis:
			on += 1
			ch.update_char(dt, cam)
			var near: bool = ag.pos.distance_squared_to(_player) < 35.0 * 35.0
			if near != ag.on:
				ag.on = near
				ch._sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not ag.animal: np += 1
	stats.on_screen = on
	stats.people = np
	stats.animals = agents.size() - np
