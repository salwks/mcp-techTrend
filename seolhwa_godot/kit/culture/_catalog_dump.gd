# kit-culture 목록 생성기: 모든 모델·변형을 지어 삼각형 수·footprint·충돌체·조명·앵커를 재고 catalog.json을 쓴다.
#   godot --path . --headless -s res://kit/culture/_catalog_dump.gd
# 묶음(compound·jongga)은 tris = 조각 합(한 덩이로 지었을 때), pieces = 조각 수. 조각별 예산은 각 모델 항목 참고.
extends SceneTree

const ENTRIES := [
	["chae", "", "채 하나(一자) 범용 — 사랑채·행랑채·밖거리·곳간채. bays 글자(_cc.gd), roof giwa/giwa_dark/thatch/thatch_old/thatch_sea/thatch_nw/tti, wall mud/plaster/red/basalt/urban", { seed = 1 }, [{ seed = 1, bays = "bcbgbbc", l = 16, d = 3.2, F = 0.4 }, { seed = 2, roof = "thatch", bays = "kdd", l = 7.5 }]],
	["yeongnam/tteuljip", "영남", "ㅁ자 뜰집(안동형) — 안채·익랑·사랑대문채가 안마당을 막은 ㅁ자, 지붕 한 덩이(가운데 하늘 구멍). roof giwa/choga", { seed = 1 }, [{ seed = 2, roof = "choga" }]],
	["yeongnam/jongga", "영남", "종가 — ㅁ자 기와 뜰집 + 동북 뒤 사당(담·일각문) + 앞 행랑채 + 곳간 + 기와 토담. 배치형(layout/pieces)", { seed = 1 }, []],
	["yeongnam/sadang", "영남", "사당 — 3칸 맞배 기와(높은 기단) + 기와 토담 + 일각문. 종가 조각", { seed = 1 }, [{ seed = 2, wall = false }]],
	["yeongnam/choga", "영남", "영남 초가 — 一자 4칸(붉은 흙벽·넓은 마루·낮은 굴뚝) / ㄱ자(plan giyeok)", { seed = 1 }, [{ seed = 1, plan = "giyeok" }]],
	["yeongnam/compound", "영남", "영남 집 프리셋 — small 초가 一자+토담 / medium ㅁ자 초가 뜰집(담 없음) / large 종가", { seed = 1, size = "small" }, [{ seed = 1, size = "medium" }, { seed = 1, size = "large" }, { seed = 2, size = "medium", roof = "giwa" }]],
	["giho/giyeok", "기호", "ㄱ자집 — ㄱ자 안채(서쪽 부엌칸 꺾임) + 앞 오른쪽 一자 사랑채. roof giwa/choga, sarang", { seed = 1 }, [{ seed = 2, roof = "choga" }, { seed = 3, sarang = false }]],
	["giho/choga_giyeok", "기호", "기호 초가 ㄱ자 — 몸채 3칸 + 앞으로 꺾인 부엌·외양간 칸", { seed = 1 }, []],
	["giho/hanok_city", "기호", "한양 도시 한옥 — 좁은 필지 ㄷ자(길에 붙은 화방벽+평대문, 기본) / ㅁ자(문간채가 길, 사괴석 바깥벽·들창)", { seed = 1 }, [{ seed = 2, shape = "ㅁ" }]],
	["giho/compound", "기호", "기호 집 프리셋 — small 초가 ㄱ자+싸리울 / medium ㄱ자 초가+사랑+토담 / large ㄱ자 기와+사랑+행랑+기와 토담 / city 도시 한옥", { seed = 1, size = "small" }, [{ seed = 1, size = "medium" }, { seed = 1, size = "large" }, { seed = 1, size = "city" }]],
	["gwandong/banga", "관동", "강릉 반가 — 높은 기단 긴 一자 기와 안채 + 나란한 긴 행랑채(위에서 二)", { seed = 1 }, [{ seed = 2, haengrang = false }]],
	["gwandong/haean", "관동", "영동 해안 ㄱ자 초가 — 잿빛 이엉을 새끼 그물로 얽고 처마에 돌을 매닮", { seed = 1 }, []],
	["gwandong/compound", "관동", "관동 집 프리셋 — small 산간(너와 ㄱ자+귀틀 곳간+돌축대) / medium 해안 ㄱ자 초가+돌담 / large 강릉 반가+기와 토담", { seed = 1, size = "small" }, [{ seed = 1, size = "medium" }, { seed = 1, size = "large" }]],
	["haeseo/gyeopjip", "해서", "해서 겹집 — 방 두 줄의 깊은 一자/ㄱ자 초가(툇마루 없음, 따로 선 높은 굴뚝). roof thatch/giwa", { seed = 1 }, [{ seed = 1, plan = "giyeok" }, { seed = 2, roof = "giwa" }]],
	["haeseo/compound", "해서", "해서 집 프리셋 — small 一자 겹집+바자울 / medium 넓은 一자 겹집+헛간+바자울 / large 一자 겹집 기와+곳간+기와 토담", { seed = 1, size = "small" }, [{ seed = 1, size = "medium" }, { seed = 1, size = "large" }]],
	["gwanseo/pyeongyang_giwa", "관서", "평양 도시 기와집 — 깊은 一자/ㄱ자, 아주 넓은 처마, 짙은 기와", { seed = 1 }, [{ seed = 1, plan = "giyeok" }]],
	["gwanseo/choga", "관서", "서북 초가 — 낮고 넓은 잿빛 겹집 초가 + 가로 새끼 띠 + 따로 선 높은 굴뚝", { seed = 1 }, []],
	["gwanseo/city_wall", "관서", "도시 담 둘레 — 사괴석 아랫단+회벽+기와 갓, 남쪽 평대문(gate_x). 평양·한양 골목", { seed = 1 }, [{ seed = 2, gate_x = null, sides = "s" }]],
	["gwanseo/compound", "관서", "관서 집 프리셋 — small/medium 서북 초가 / large 평양 기와집 ㄱ자+곳간+도시 담", { seed = 1, size = "small" }, [{ seed = 1, size = "medium" }, { seed = 1, size = "large" }]],
	["gwanbuk/jeonja", "관북", "田자 겹집 — 방 두 줄+부엌·정주간·외양간이 한 지붕, 두꺼운 짙은 이엉, 작은 창, 따로 선 높은 굴뚝", { seed = 1 }, [{ seed = 2, w = 13.2, d = 10.0 }]],
	["gwanbuk/compound", "관북", "관북 집 프리셋 — small 田자+장작더미+바자울 / medium +헛간·뒷간 / large 큰 田자+곳간채+이엉 토담", { seed = 1, size = "small" }, [{ seed = 1, size = "medium" }, { seed = 1, size = "large" }]],
	["tamna/stone_house", "탐라", "제주 돌집 — 현무암 돌벽+낮은 띠지붕 집줄 격자+상방 풍채. kind an(안거리 5칸)/bak(밖거리 3칸)", { seed = 1 }, [{ seed = 2, kind = "bak" }]],
	["tamna/doldam", "탐라", "현무암 돌담 — 한 겹 검은 구멍돌, 위 덩이 줄. 두 점 또는 points, lite(기본) ~70/m", { seed = 1 }, [{ seed = 2, points = [[-4, 0], [0, 0.6], [4, -0.4]], lite = false }]],
	["tamna/jeongnang", "탐라", "정낭 — 정주석 둘+정낭 셋(across 걸친 수 0~3 = 집 비운 정도)", { seed = 1 }, [{ seed = 2, across = 3 }, { seed = 3, across = 0 }]],
	["tamna/compound", "탐라", "탐라 집 프리셋 — 안거리+밖거리(동쪽 서향)+현무암 집담+굽은 올레+정낭+돗통시+우영밭. size small(외거리)/medium/large(+모커리)", { seed = 1 }, [{ seed = 2, size = "small" }, { seed = 3, size = "large" }]],
]

func _tris(node: Node3D) -> int:
	var n := 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for s in m.get_surface_count(): n += m.surface_get_array_len(s) / 3
	return n

func _measure(name: String, p: Dictionary) -> Dictionary:
	var scr = load("res://kit/culture/%s.gd" % name)
	var r: Dictionary = scr.build(p)
	var fp: Vector2 = r.get("footprint", Vector2.ZERO)
	var pieces: Array = r.get("pieces", [])
	var maxp := 0
	if pieces.size() > 0:
		for c in (r.node as Node3D).get_children(): maxp = maxi(maxp, _tris(c))
	var out := { params = p, tris = _tris(r.node), footprint = [snappedf(fp.x, 0.1), snappedf(fp.y, 0.1)],
		colliders = r.colliders.size(), lights = r.lights.size(), occluder = r.get("occluder", false),
		anchors = (r.get("anchors", {}) as Dictionary).keys(), pieces = pieces.size(), max_piece_tris = maxp, layout = scr.has_method("layout") }
	(r.node as Node3D).free()
	return out

func _init() -> void:
	var list := []
	for e in ENTRIES:
		var item := { name = e[0], culture = e[1], file = "res://kit/culture/%s.gd" % e[0], desc = e[2], shot = "shots/kit/culture/%s.png" % e[0].replace("/", "_") }
		item.merge(_measure(e[0], e[3]))
		var vars := []
		for v in e[4]: vars.append(_measure(e[0], v))
		item.variants = vars
		list.append(item)
		print("%-26s tris=%6d pieces=%2d maxpiece=%5d fp=%s" % [e[0], item.tris, item.pieces, item.max_piece_tris, str(item.footprint)])
		for v in vars: print("    %-50s tris=%6d pieces=%2d maxpiece=%5d" % [JSON.stringify(v.params), v.tris, v.pieces, v.max_piece_tris])
	var doc := { kit = "culture", era = "1870 전후 조선 후기",
		note = "build(params) → {node, colliders, lights, occluder, footprint, anchors, pieces?}. 정면 +z. tris는 먹선 포함. 묶음은 layout(params)로 조각 배치(§8), 조각마다 예산 안",
		budget = { house = 6000, big_house = 15000, prop = 800 },
		cultures = { 영남 = "yeongnam", 기호 = "giho", 관동 = "gwandong", 해서 = "haeseo", 관서 = "gwanseo", 관북 = "gwanbuk", 탐라 = "tamna", 호남 = "village(기존 kit/village)" },
		compare = ["shots/kit/culture/compare.png", "shots/kit/culture/compare_large.png"],
		models = list }
	var f := FileAccess.open("res://kit/culture/catalog.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false))
	f.close()
	quit()
