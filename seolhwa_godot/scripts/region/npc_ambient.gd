# 권역 주변 인물·짐승(전투·사건 없음) — 고을이 살아 보이게, 고을 차이(사람·짐승)가 드러나게.
# 말 걸기(scripts/story/ambient_talk.gd): 사람은 E로 말을 건다 — 훑을 때마다 플레이어 12m 안 사람만 _near에 모아 두고
#   nearest_talkable()이 그 몇 명만 잰다. 말하는 동안 hold()로 멈춰 플레이어를 보고(놓이지도 않는다), unhold()로 하던 일로.
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
# 프레임: 사람은 인물 빌더 권역 묶음(data/chars/amb_<권역>.json — tools/export_char_frames.js, scripts/char_bank.gd)이 먼저다.
#   역할(농부·아낙·상인…)마다 시드가 다른 여러 사람(권역당 최대 36명, 페이지 공유)이 있어, 칸 번호 해시로 그중 하나를 고른다
#   (같은 칸 = 같은 사람). 묶음에 없는 역할(도롱이·포수·방앗간·나무꾼·목자·보살 등)과 짐승은 예전 그림:
#   data/frames_npc.json(웹 마을 사람 9종) + data/frames_amb.json(tools/export_npc_frames.js가 구운 고을 사람·짐승).
#   frames_amb.json이 없으면 고을 사람은 가까운 기본 종류로 대신하고 짐승은 나오지 않는다. --nobuilder면 빌더 묶음을 쓰지 않는다(비교·측정).
#   짐을 든 빌더 사람은 걸을 때 carry 동작(짐 든 팔)을 쓴다.
# 비우기 구역(제작 규칙 C63) — 사건이 길 한가운데를 잠시 비운다(행차·어사출두·관아 행사·상여 길): exclude(id, 구역) / release(id).
#   구역 안에는 새로 나오지 않고, 이미 있던 사람·짐승은 바로 풀(pool)로 돌린다(말 거는 중인 사람만 예외). 걷는 사람은 구역 앞에서 돌아선다.
#   풀면 아무것도 되돌리지 않는다 — 보통 스트리밍이 화면 밖에서 다시 채운다. 행렬 AI·길찾기·비켜서기는 만들지 않는다.
extends Node3D

const CharBank := preload("res://scripts/char_bank.gd")
# npc_ambient 역할 → 빌더 묶음의 역할들(섞어 고름). 없는 역할은 이름 그대로
const ROLE_VARIANTS := { elder = ["elder", "elder_f"], villager_m = ["villager_m", "cheonmin", "jungin"], villager_f = ["villager_f", "yangban_f"],
	scholar = ["scholar", "yangban"], official = ["official", "pojol"], merchant = ["merchant", "jungin"], farmwife = ["farmwife"], innkeeper = ["innkeeper"] }

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
# 앉은 사람 자리(seat) — 키트 앵커(키트 build의 m.anchor, world.props.anchor로 월드 자리)에서 저절로. 앵커가 없는 키트는 로컬 자리(loc)로.
#   kind: vendor(좌판·가가·시전 장꾼) · guest(주막 평상 손님) · platform(평상 소품·마을 마당) · boatman(나룻배 사공) · maru(툇마루·문간 노인)
#         rest(큰 나무 그늘) · pavilion(정자 마루) · petition(관아 앞 쪼그려 기다림)
#   sit: 그 자리의 앉음새 무게 — ground(땅·평상 위 sit) · seat(걸터앉기 sit_seat, 발은 땅) · squat · stand(서서 팔기)
#   앉음새마다 돌아가며 할 동작: SEAT_ANIMS. 장꾼은 물건(goods)에 맞는 사람(SEAT_GOODS)
const SEAT_GOODS := { fish = ["villager_f", "merchant", "farmwife"], cloth = ["merchant", "merchant", "villager_f"], onggi = ["merchant", "villager_m", "elder"],
	grain = ["farmwife", "farmer", "villager_f"], straw = ["farmer", "villager_m", "elder"], mixed = ["villager_f", "merchant", "farmwife", "elder"] }
const SEAT_KIT := {
	"village/jwapan": { kind = "vendor", names = ["seller"], loc = Vector3(0, 0, -0.5), n = 1, pres = 0.95, sit = { ground = 0.7, seat = 0.1, stand = 0.2 }, night = 0.03 },
	"village/market_shop": { kind = "vendor", names = ["seller"], loc = Vector3(0, 0, -1.0), n = 1, pres = 0.95, sit = { ground = 0.55, seat = 0.25, stand = 0.2 }, night = 0.03 },
	"landmark/hy_sijeon": { kind = "vendor", names = ["counter_w", "counter_e"], n = 2, pres = 0.9, sit = { ground = 0.6, seat = 0.2, stand = 0.2 }, night = 0.03 },
	"village/jumak": { kind = "guest", names = ["guest_seat"], n = 3, spread = 0.75, pres = 0.85, sit = { ground = 1.0 }, night = 1.0,
		pool = ["traveler", "peddler", "villager_m", "elder", "merchant"] },
	"village/props:pyeongsang": { kind = "platform", names = ["seat"], n = 2, spread = 0.7, pres = 0.3, sit = { ground = 1.0 }, night = 0.05,
		pool = ["elder", "villager_m", "villager_f", "farmer", "elder"] },
	"village/village_square": { kind = "platform", names = ["pyeongsang0", "pyeongsang1", "seat0", "seat1", "seat2"], n = 3, pres = 0.5, sit = { ground = 1.0 }, night = 0.05,
		pool = ["elder", "elder", "villager_m", "villager_f", "child_boy", "child_girl"] },
	"village/narutbae": { kind = "boatman", names = ["boatman"], n = 1, pres = 0.6, sit = { ground = 1.0 }, night = 0.1, pool = ["boatman"] },
	"village/jeongja": { kind = "pavilion", names = ["floor"], n = 2, spread = 0.9, pres = 0.6, sit = { ground = 1.0 }, night = 0.0, pool = ["scholar", "elder", "elder"] },
	"nature/big_tree": { kind = "rest", loc = Vector3(1.5, 0, 1.3), n = 2, pres = 0.4, sit = { ground = 0.8, squat = 0.2 }, night = 0.0,
		pool = ["elder", "farmer", "villager_m", "villager_f", "elder"] },
	"house": { kind = "maru", suffix = "maru", front = 0.35, n = 1, pres = 0.1, sit = { seat = 1.0 }, night = 0.0, pool = ["elder", "elder", "villager_f"] },
	"office": { kind = "petition", front = 2.6, side = 1.6, n = 1, pres = 0.45, sit = { squat = 1.0 }, night = 0.0, pool = ["villager_m", "farmer", "elder"] },
}
const SEAT_ANIMS := { ground = ["sit", "sit_talk", "sit_work"], seat = ["sit_seat"], squat = ["squat"], stand = ["idle", "talk"] }
const OFFICE_KITS := ["landmark/gwana", "landmark/dongheon", "landmark/hyeon_gwana", "landmark/gn_gwana", "landmark/jj_mokgwana"]

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
var _bset := ""                  # 인물 빌더 권역 묶음(amb_JL …) — 없으면 ""
var _variants := {}              # 역할 → [빌더 인물 id]
var _no_builder := OS.get_cmdline_user_args().has("--nobuilder")
var _frame := 0
var _debug := OS.get_cmdline_user_args().has("--npcstats")
var _fail := {}               # 칸 키 → 다시 해 볼 시각(자리를 못 찾음)
var _sts: Array = []          # 고을 정보(_settle_info) — 말 걸기에서 어느 고을 사람인지
var _near: Array = []         # 말 걸 수 있는 사람 후보(플레이어 12m 안, 훑을 때마다)
var _excl := {}               # 비우기 구역 id → [[a: Vector2, b: Vector2, hw: float]] (선분 + 반폭, 사각형은 가운데 선분으로)
const NEAR_TALK := 12.0
const NO_TALK := ["gull"]     # 이 자리 사람은 말 걸지 않는다(짐승은 늘 아님)

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
		name = String(s.get("name", "")).split("(")[0].strip_edges(), typ = typ,
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
	var seats: Array = []
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
			if it.has("when"): continue   # 조건부 차림(F-11)은 늘 있지 않다 — 고을 사람 자리로 쓰지 않는다
			var kit := String(it.kit)
			var mode: String = ANCHOR.get(kit, "")
			if mode == "":
				for hh in HOUSE_HINT:
					if kit.ends_with(hh): mode = "yard"; break
			if mode != "": anchors.append([mode, Vector2(float(it.get("x", 0.0)), float(it.get("z", 0.0))), float(it.get("ry", 0.0)), kit])
			var sk := _seat_key(kit, it)
			if sk != "": seats.append([sk, it])
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
	# 앉은 사람 자리(장꾼·주막 손님·평상·사공·툇마루·나무 그늘·정자·관아 앞)
	for e in seats:
		var it: Dictionary = e[1]
		var d: Dictionary = SEAT_KIT[e[0]]
		var p := Vector2(float(it.get("x", 0.0)), float(it.get("z", 0.0)))
		var st = _settle_at(sts, p)
		if d.kind in ["maru", "platform", "rest"] and st == null: continue   # 고을 밖 집·나무는 비워 둔다
		var cls: String = st.cls if st != null else "village"
		var pool: Array = d.get("pool", [])
		var goods := String((it.get("params", {}) as Dictionary).get("goods", "mixed"))
		if d.kind == "vendor":
			pool = SEAT_GOODS.get(goods, SEAT_GOODS.mixed)
			if st != null and st.own.has("haenyeo") and goods == "fish": pool = ["haenyeo", "villager_f"]
		var pres: float = d.pres
		if d.kind == "maru" and cls == "capital": pres *= 0.5
		var fp: Array = it.get("footprint", []) if it.get("footprint") is Array else []
		out_sites.append({ p = p, ry = float(it.get("ry", 0.0)), mode = "seat", n = int(d.n), pres = pres, pool = pool, kind_cls = "people", out = true, r = 0.0,
			anim = "sit", night = float(d.night), seat = { key = e[0], id = String(it.get("id", "")), goods = goods,
				fd = float(fp[1]) if fp.size() > 1 else 6.0, fw = float(fp[0]) if fp.size() > 0 else 6.0 } })
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
	_built = { sites = out_sites, paths = out_paths, ms = Time.get_ticks_msec() - t0, sts = sts }

static func _seat_key(kit: String, it: Dictionary) -> String:
	if SEAT_KIT.has(kit): return kit
	if kit == "village/props" and String((it.get("params", {}) as Dictionary).get("kind", "")) == "pyeongsang": return "village/props:pyeongsang"
	if kit in OFFICE_KITS: return "office"
	for hh in HOUSE_HINT:
		if kit.ends_with(hh): return "house"
	return ""

# 앉을 자리(월드 Vector3)와 바라볼 쪽(Vector2) — 키트가 놓인 뒤에만(world.props의 앵커·변환). 없으면 null
func _seat_world(site: Dictionary, i: int) -> Variant:
	var sd: Dictionary = site.seat
	var d: Dictionary = SEAT_KIT[sd.key]
	var props = world.get("props")
	if props == null or sd.id == "" or not props._props.has(sd.id): return null
	var xf: Transform3D = props._props[sd.id].xf
	var fwd3 := xf.basis.z.normalized()
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	var right := Vector2(-fwd.y, fwd.x)
	var pos = null
	var names: Array = d.get("names", [])
	if d.has("suffix"):
		for nm in (props._props[sd.id].info.get("anchors", {}) as Dictionary):
			if String(nm).ends_with(String(d.suffix)): pos = props.anchor(sd.id, nm); break
		if pos == null: pos = xf * Vector3(0, 0, float(sd.fd) * 0.5)   # 앵커 없는 집(초가): 앞면 가운데
	elif not names.is_empty():
		pos = props.anchor(sd.id, String(names[i % names.size()]))
		if pos == null and d.has("loc"): pos = xf * (d.loc as Vector3)
	elif d.has("loc"):
		pos = xf * (d.loc as Vector3)
	else:
		pos = xf * Vector3(float(d.get("side", 0.0)), 0, float(sd.fd) * 0.5 + float(d.get("front", 0.0)))
	if pos == null: return null
	var p3: Vector3 = pos
	var p2 := Vector2(p3.x, p3.z)
	var o2 := Vector2(xf.origin.x, xf.origin.z)
	# 여럿이 앉는 자리: 옆으로 벌려 앉는다(평상·정자). 나무 그늘은 줄기 둘레로 돌려 앉는다
	if d.kind == "rest": p2 = o2 + (p2 - o2).rotated(float(i) * 2.2)
	elif names.size() <= 1 and int(d.n) > 1: p2 += right * (float(i) - (float(d.n) - 1.0) * 0.5) * float(d.get("spread", 0.7))
	if d.kind == "maru": p2 += fwd * float(d.front)
	var face := fwd
	if d.kind == "rest": face = (p2 - o2).normalized()
	return [Vector3(p2.x, p3.y, p2.y), face]

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
	sites = _built.sites; paths = _built.paths; _sts = _built.get("sts", [])
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
	# 인물 빌더 권역 묶음: 역할마다 여러 사람
	_variants.clear()
	if not _no_builder and world != null and world.get("region") is Dictionary:
		_bset = CharBank.region_set(String(world.region.get("region_id", world.region.get("route_id", ""))))
	if _bset != "":
		var all_ids := []
		for k in kinds:
			var ids := []
			for r in ROLE_VARIANTS.get(k, [k]): ids.append_array(CharBank.ids(_bset, r))
			if not ids.is_empty(): _variants[k] = ids; all_ids.append_array(ids)
		var bs := CharBank.bank_src(_bset, all_ids)
		for id in bs:
			if not SpriteChar._banks.has(id): _bank_src[id] = bs[id]
	var src := {}
	for jf in ["frames_npc.json", "frames_amb.json"]:
		var path: String = "res://data/" + jf
		if not FileAccess.file_exists(path): continue
		var all = JSON.parse_string(FileAccess.get_file_as_string(path))
		if all is Dictionary:
			for k in all: src[k] = all[k]
			if jf == "frames_amb.json": _amb = true
	for k in kinds:
		if _variants.has(k): continue   # 빌더 사람이 대신한다
		var real := _real_kind(k, src)
		if real != "" and src.has(real) and not SpriteChar._banks.has(real): _bank_src[real] = src[real]
	var want := []
	for k in _bank_src:
		for p in _bank_src[k].pages:
			if not want.has(p) and not _tex_cache.has(p): want.append(p)
	_task = WorkerThreadPool.add_task(_load_pages.bind(want), false, "npc_ambient pages")
	print("NPC sites=%d paths=%d kinds=%d pages=%d build_ms=%d amb=%s builder=%s variants=%d" % [sites.size(), paths.size(), _bank_src.size(), want.size(), _built.ms, _amb, _bset,
		_variants.values().reduce(func(a, l): return a + l.size(), 0)])
	_built = {}

func _real_kind(k: String, src: Dictionary) -> String:
	if src.has(k) or SpriteChar._banks.has(k): return k
	if FALLBACK.has(k) and (src.has(FALLBACK[k]) or SpriteChar._banks.has(FALLBACK[k])): return FALLBACK[k]
	return ""

func _load_pages(files: Array) -> void:
	for f in files:
		var img := CharBank.load_page(String(f))   # 빌더 묶음 페이지는 S3TC로 압축
		if img == null: continue
		_pending_pages.append([f, img])   # Array.append은 메인이 읽는 동안에도 안전하게 끝에 붙는다(메인은 작업이 끝난 뒤 읽는다)

func _upload_pages() -> void:
	var n := 0
	while not _pending_pages.is_empty() and n < 3:
		var e: Array = _pending_pages.pop_front()
		_tex_cache[e[0]] = ImageTexture.create_from_image(e[1]); n += 1
		CharBank.put_texture(String(e[0]), _tex_cache[e[0]])   # 군중(EventCrowd)도 같은 페이지를 쓴다
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
	if site.mode == "seat":   # 앉은 자세는 빌더 사람만 갖는다
		pool = pool.filter(func(r): return _variants.has(r))
	if pool.is_empty(): return ""
	var k: String = pool[int(hk * pool.size()) % pool.size()]
	if site.mode == "seat": return k
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
		if not ag.get("hold", false) and ag.mode != "gull" and excluded(Vector2(ag.pos.x, ag.pos.z)):
			_release(key); continue   # 비우기 구역 안 — 화면 안이어도 바로 놓는다
		if ag.mode == "seat" and not ag.get("hold", false) and seat_taken(Vector2(ag.pos.x, ag.pos.z)):
			_release(key); continue   # 이야기 인물·군중이 그 자리에 왔다
		var keep: bool = want.get(key, "") == ag.kind or ag.get("hold", false)
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
	_near.clear()
	for key in agents:
		var ag: Dictionary = agents[key]
		if ag.animal or NO_TALK.has(ag.mode): continue
		if Vector2(ag.pos.x - _player.x, ag.pos.z - _player.z).length() < NEAR_TALK: _near.append(key)
	if _debug and int(_clock / 2.0) != int((_clock - SCAN) / 2.0):
		var hist := [0, 0, 0, 0, 0]
		for kk in agents:
			var dd: float = Vector2(agents[kk].pos.x - _player.x, agents[kk].pos.z - _player.z).length()
			hist[mini(4, int(dd / 20.0))] += 1
		print("NPC dist20=", hist, " modes=", agents.values().map(func(a): return a.mode).slice(0, 12))
		print("NPC agents=%d want=%d people=%d animals=%d on_screen=%d cand_p=%d cand_a=%d" % [agents.size(), want.size(), stats.people, stats.animals, stats.on_screen, want_p.size(), want_a.size()])

func _kind_bank(k: String) -> String:
	if _variants.has(k): return String(_variants[k][0])
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
	elif site.mode == "seat":
		if not _tile_ready(site.p): return false
		var sw = _seat_world(site, i)
		if sw == null: return false
		var sp3: Vector3 = sw[0]
		p = Vector2(sp3.x, sp3.z)
		if seat_taken(p): return false   # 이야기 인물·사건 군중이 이미 쓰는 자리
		var d: Dictionary = SEAT_KIT[site.seat.key]
		var way := "ground"
		var tot := 0.0
		for w in d.sit: tot += float(d.sit[w])
		var x := _h(key, 71) * tot
		for w in d.sit:
			x -= float(d.sit[w])
			if x <= 0.0: way = w; break
		ag.sit = way
		ag.anims = SEAT_ANIMS[way]
		ag.anim = String(ag.anims[0])
		ag.face = sw[1]
		ag.home = p; ag.r = 0.0
		ag.t = 2.0 + _h(key, 72) * 6.0
		var gy: float = world.height_at(p.x, p.y)
		ag.seat_y = sp3.y if way == "ground" and sp3.y > gy + 0.05 else gy
		ag.mode = "seat"
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
	if site.mode != "gull" and excluded(p, 0.4): return false              # 비우기 구역(사건이 잠시 비운 길)
	var pos := Vector3(p.x, 0.0, p.y)
	if not filling and site.mode != "gull" and _visible_near(Vector3(p.x, world.height_at(p.x, p.y), p.y)): return false
	var ch := _take(_bank_for(kind, key))
	if ch == null: return false
	ag.carry = not ag.animal and ch.has_anim("carry")
	ag.ch = ch
	ag.pos = pos
	_place(ag, p)
	ch.facing = ["down", "left", "right", "up"][int(_h(key, 21) * 4.0) % 4]
	if ag.mode == "seat":
		ch.facing = _facing(ag.face.x, ag.face.y, "down")   # 길·손님 쪽
		if not ch.has_anim(ag.anim): ag.anim = 'idle'
	if ag.animal and ch.facing in ["up", "down"]: ch.facing = "left" if _h(key, 22) < 0.5 else "right"
	ch.set_anim(ag.anim if ag.state == "idle" else "walk")
	ch.anim_time = _h(key, 23) * 3.0
	ch.t = _h(key, 24) * 5.0
	agents[key] = ag
	return true

# 역할 → 이 칸의 사람(빌더 묶음이면 칸 번호 해시로 여러 사람 중 하나 — 다시 와도 같은 사람)
func _bank_for(kind: String, key: int) -> String:
	if not _variants.has(kind): return kind
	var ids: Array = _variants[kind]
	return String(ids[int(_h(key, 61) * ids.size()) % ids.size()])

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
	elif ag.has("seat_y"):
		y = ag.seat_y   # 평상·배·정자 위
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
		if ag.get("hold", false):   # 말하는 중: 멈춰 플레이어를 본다
			var lk: Vector2 = ag.look - old
			ch.facing = _facing(lk.x, lk.y, ch.facing)
			if ag.mode == "seat": ch.set_anim("sit_talk" if ag.get("sit", "") == "ground" and ch.has_anim("sit_talk") else String(ag.anim))
			else: ch.set_anim("talk" if ch.has_anim("talk") else "idle")
			if vis:
				on += 1
				ch.update_char(dt, cam)
			np += 1
			continue
		match ag.mode:
			"walk":
				if ag.state == "walk":
					var P: Dictionary = paths[ag.path]
					var ns: float = ag.s + ag.dir * ag.speed * dt
					var turn: bool = ns <= 0.0 or ns >= P.len or absf(ns - ag.s0) > ag.roam
					var nxt := _at(P.pts, P.cum, ns)
					if Vector2(_player.x, _player.z).distance_to(nxt) < 0.9: ag.state = "idle"; ag.t = 0.6   # 플레이어 앞에서 멈칫
					elif turn or _walk_blocked(P, ns, float(ag.lat)):   # 길 끝·거닐 범위 끝·비우기 구역 앞에서 돌아선다
						ag.dir = -ag.dir; ag.state = "idle"; ag.t = 1.0 + _h(key, int(_clock)) * 3.0
					else:
						ag.s = ns
						p = _path_pos(ag)
				elif ag.t <= 0.0:
					ag.state = "walk"
					if _h(key, int(_clock * 3.0)) < 0.15: ag.state = "idle"; ag.t = 2.0 + _h(key, 31) * 5.0
			"stand":
				pass
			"seat":
				# 앉은 채로 하던 일을 바꾼다(부르기·매만지기·쉬기) — 자리를 떠나지 않는다
				if ag.t <= 0.0:
					var lst: Array = ag.anims
					ag.anim = String(lst[int(_h(key, int(_clock * 3.0) + 9) * lst.size()) % lst.size()])
					if not ch.has_anim(ag.anim): ag.anim = String(lst[0]) if ch.has_anim(String(lst[0])) else "idle"
					ag.t = 3.0 + _h(key, int(_clock) + 5) * 6.0
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
					if r > 0.5 and not world.blocked(tgt.x, tgt.y, rad) and world.interior_at(tgt.x, tgt.y) == null and not excluded(tgt, rad):
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
		elif moved: want_anim = "carry" if ag.get("carry", false) else "walk"
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

# ---------------------------------------------------------------------------
# 말 걸기(scripts/story/ambient_talk.gd)
# ---------------------------------------------------------------------------
# p에서 r 안의 가장 가까운 사람(없으면 -1) — 훑을 때 모아 둔 _near 몇 명만 본다
func nearest_talkable(p: Vector2, r: float) -> int:
	var best := -1; var bd := r
	for key in _near:
		var ag = agents.get(key)
		if ag == null or ag.animal or not ag.ch.visible: continue
		var dd := Vector2(ag.pos.x - p.x, ag.pos.z - p.y).length()
		if dd < bd: bd = dd; best = key
	return best

# 이 사람 정보: 종류·자리·고을
func info(key: int) -> Dictionary:
	var ag: Dictionary = agents[key]
	var site: Dictionary = sites[key / SLOTS]
	var p := Vector2(ag.pos.x, ag.pos.z)
	var st = _settle_at(_sts, p)
	return { key = key, kind = String(ag.kind), mode = String(site.mode), p = p,
		settle = String(st.id) if st != null else "", arch = String(st.arch) if st != null else "", cls = String(st.cls) if st != null else "",
		place = String(st.name) if st != null else "" }

# 이야기 인물·사건 군중이 그 자리(1.4m 안)를 쓰고 있나 — 앉은 고을 사람이 겹치지 않게(region_main이 story_ref·crowd_ref를 넣는다)
var story_ref = null
var crowd_ref = null
func seat_taken(p: Vector2) -> bool:
	if story_ref != null and story_ref.get("actors") is Dictionary:
		for id in story_ref.actors:
			var a = story_ref.actors[id]
			if a is Dictionary and a.get("shown", true) and a.get("pos") is Vector3 and Vector2(a.pos.x, a.pos.z).distance_to(p) < 1.4: return true
	if crowd_ref != null and crowd_ref.get("crowds") is Dictionary:
		for cid in crowd_ref.crowds:
			var c: Dictionary = crowd_ref.crowds[cid]
			if not c.get("on", false): continue
			for m in c.get("members", []):
				if (m.get("home", Vector2.INF) as Vector2).distance_to(p) < 1.2: return true
	return false

func hold(key: int, toward: Vector3) -> void:
	var ag = agents.get(key)
	if ag == null: return
	ag.hold = true
	ag.look = Vector2(toward.x, toward.z)
	if ag.mode == "walk": ag.state = "idle"

func unhold(key: int) -> void:
	var ag = agents.get(key)
	if ag == null: return
	ag.erase("hold")
	ag.t = 0.8 + _h(key, int(_clock)) * 1.5

# ---------------------------------------------------------------------------
# 비우기 구역(제작 규칙 C63) — 사건의 행렬·행사가 지나는 길 한가운데를 잠시 비운다
# ---------------------------------------------------------------------------
# zone: { "rect": [x0, z0, x1, z1] } — 땅 위 사각형(축 정렬)
#       { "path": [[x, z], ...], "width": w } — 꺾인 길(선분들), 폭 w(m)의 띠
# 같은 id로 다시 부르면 바꾼다. 구역 안 사람·짐승(말 거는 중 제외)은 바로 놓고, 구역 안에는 새로 나오지 않는다.
func exclude(id: String, zone: Dictionary) -> void:
	var segs := zone_segs(zone)
	if segs.is_empty(): return
	_excl[id] = segs
	for key in agents.keys():
		var ag: Dictionary = agents[key]
		if ag.get("hold", false) or ag.mode == "gull": continue
		if excluded(Vector2(ag.pos.x, ag.pos.z)): _release(key)

# 풀기 — 아무것도 되돌리지 않는다. 다시 해 볼 시각만 지워 보통 스트리밍이 곧(화면 밖에서) 채우게
func release(id: String) -> void:
	if not _excl.has(id): return
	_excl.erase(id)
	_fail.clear()

func zone_ids() -> Array: return _excl.keys()

func excluded(p: Vector2, pad := 0.0) -> bool:
	if _excl.is_empty(): return false
	for id in _excl:
		for sg in _excl[id]:
			if _seg_dist(p, sg[0], sg[1]) <= float(sg[2]) + pad: return true
	return false

# 구역 안 주변 인물 수(시험·디버그) — id가 풀린 뒤에도 같은 모양으로 셀 수 있게 zone을 직접 받는다
func count_in(zone: Dictionary) -> int:
	var segs := zone_segs(zone)
	var n := 0
	for key in agents:
		var ag: Dictionary = agents[key]
		if ag.mode == "gull": continue
		var q := Vector2(ag.pos.x, ag.pos.z)
		for sg in segs:
			if _seg_dist(q, sg[0], sg[1]) <= float(sg[2]): n += 1; break
	return n

func _walk_blocked(P: Dictionary, s: float, lat: float) -> bool:
	if _excl.is_empty(): return false
	var d := _dir_at(P.pts, P.cum, s)
	return excluded(_at(P.pts, P.cum, s) + Vector2(-d.y, d.x) * lat, 0.3)

static func zone_segs(zone: Dictionary) -> Array:
	var out := []
	if zone.has("rect"):
		var r: Array = zone.rect
		var x0 := minf(float(r[0]), float(r[2])); var x1 := maxf(float(r[0]), float(r[2]))
		var z0 := minf(float(r[1]), float(r[3])); var z1 := maxf(float(r[1]), float(r[3]))
		var c := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
		# 사각형 = 긴 쪽 가운데 선분 + 짧은 쪽 반폭(모서리는 둥글게 — 길 비우기에는 충분)
		if x1 - x0 >= z1 - z0: out.append([Vector2(x0 + (z1 - z0) * 0.5, c.y), Vector2(x1 - (z1 - z0) * 0.5, c.y), (z1 - z0) * 0.5])
		else: out.append([Vector2(c.x, z0 + (x1 - x0) * 0.5), Vector2(c.x, z1 - (x1 - x0) * 0.5), (x1 - x0) * 0.5])
	elif zone.has("path"):
		var pts: Array = zone.path
		var hw := float(zone.get("width", 4.0)) * 0.5
		for i in pts.size() - 1:
			out.append([Vector2(float(pts[i][0]), float(pts[i][1])), Vector2(float(pts[i + 1][0]), float(pts[i + 1][1])), hw])
		if pts.size() == 1: out.append([Vector2(float(pts[0][0]), float(pts[0][1])), Vector2(float(pts[0][0]), float(pts[0][1])), hw])
	return out

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-6: return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))
