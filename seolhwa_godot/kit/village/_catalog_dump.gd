# kit-village 목록 생성기: 모든 모델을 기본 params로 만들어 삼각형 수·footprint·충돌체·조명·앵커를 재고 catalog.json을 쓴다.
#   godot --path . --headless -s res://kit/village/_catalog_dump.gd
extends SceneTree

const ENTRIES := [
	["choga", "초가(초가삼간) — 웹 choga 이식. 방 창·방문·부엌 널문·툇마루·댓돌·굴뚝, 둥근 이엉 지붕. interior=true면 들어갈 수 있는 외딴집(실내·호롱불, roof/front 숨김)", { seed = 1 }, [{ seed = 2, w = 5.4, gourd = true }, { seed = 3, interior = true }, { seed = 1, plan = "il", w = 7.2 }, { seed = 1, plan = "giyeok" }]],
	["giwa", "기와집 — 웹 giwa 이식. 높은 기단·계단, 5칸(대청·방·끝칸), 곡선 팔작 기와지붕. plain=true면 단청 없는 민가 기와집", { seed = 1 }, [{ seed = 2, plain = true, w = 7.2, bays = 3 }, { seed = 1, plan = "il", plain = true }, { seed = 1, plan = "giyeok", plain = true }]],
	["jeongja", "정자 — 웹 jeongja 이식. 사방 트인 마루·계자난간·사모 기와지붕·청사초롱. plain=true면 마을 모정", { seed = 1 }, [{ seed = 2, s = 3.0, plain = true }]],
	["well", "우물 — 웹 well 이식. 팔각 돌 우물·도르래 틀·두레박. roof=true면 이엉 덮개(가설)", { seed = 1 }, [{ seed = 2, roof = true }]],
	["jangdok", "장독대 — 웹 jangdok 이식. 돌 단 + 옹기 세 줄(n=[3,2,2])", { seed = 1 }, [{ seed = 2, w = 2.4, d = 2.0, n = [2, 2, 1] }]],
	["haystack", "짚가리 — 웹 haystack 이식. 볏짚 낟가리 + 주저리 + 새끼 띠", { seed = 1 }, [{ seed = 2, s = 0.85 }]],
	["jangseung", "장승 — 웹 jangseung 이식. 천하대장군(갓)/지하여장군(female=true)", { seed = 1 }, [{ seed = 2, female = true }]],
	["torch_post", "횃대 — 웹 torchPost 이식. 마을 어귀 화톳불 기둥(밤에 빛남)", { seed = 1 }, []],
	["stone_wall", "돌담 — 웹 stoneWall 이식. 두 점 (ax,az)→(bx,bz) 사이 막돌 허튼층 + 갓돌. 약 220 삼각형/m, lite ~90/m", { seed = 1 }, [{ seed = 2, ax = 0, az = 0, bx = 3, bz = -4, h = 1.15 }, { seed = 3, lite = true }, { seed = 3, lite = true, sparse = true }]],
	["fence", "싸리 울타리(바자울) — 웹 fence 이식. 두 점 사이. lite=true면 톱니 판(~100/m)", { seed = 1 }, [{ seed = 2, len = 6, lite = true }]],
	["stone_bridge", "돌다리(홍예교) — 웹 stoneBridge 이식. z방향으로 건넘, y=0 둑, 홍예 밑 y=-1.7", { seed = 1 }, [{ seed = 2, len = 8, hw = 1.1, arch = 0.45 }]],
	["cairn", "돌무더기(누석단) — 웹 cairn 이식. 제단·촛불(altar=false로 생략)", { seed = 1 }, [{ seed = 2, altar = false }]],
	["jumak", "주막 — 초가(방문 열림) + 평상(소반·술사발·술병) + 한데부뚜막 가마솥 + 용수 장대(흰 천) + 술독 + 장작", { seed = 1 }, [{ seed = 2, w = 6.0, flag = false }]],
	["market_shop", "장터 가게(가가) — 3칸 트인 초가 맞배 헛집 + 거적 차양 + 길 쪽 판매대 + 물건(goods)", { seed = 1 }, [{ seed = 2, goods = "onggi" }, { seed = 3, goods = "cloth", w = 4.5 }]],
	["jwapan", "장터 좌판 — 멍석 + 낮은 널 좌판 + 물건 + 뒤쪽 반만 덮는 흰 차일(awning)", { seed = 1 }, [{ seed = 2, goods = "fish", awning = false }]],
	["mulbang_a", "물레방앗간 — 흙벽 초가 맞배(용마루 남북), 남쪽 박공에 문 + 윗물레 바퀴(r 1.6) + 동쪽 홈통 + 바퀴 밑 도랑", { seed = 1 }, [{ seed = 2, wheel_r = 1.4 }]],
	["didil_bang_a", "디딜방앗간 — 뒷벽만 있는 초가 헛간 + Y자 디딜방아·볼씨·공이·돌확 + 곡식 자루·키", { seed = 1 }, []],
	["oeyanggan", "외양간 — 세 벽 흙벽 + 앞 살대 + 구유·깔짚·여물 짚단 (anchor cow)", { seed = 1 }, []],
	["heotgan", "헛간 — 앞이 트인 초가 맞배 + 볏단·지게·소쿠리·농기구", { seed = 1 }, [{ seed = 2, walls = "back", w = 3.2 }]],
	["dwitgan", "뒷간 — 작은 흙벽 초가 + 거적문 + 잿더미", { seed = 1 }, []],
	["daemun", "대문 — style tile(평대문·초롱) / soseul(솟을대문 + 행랑 두 칸) / thatch(초가 대문)", { seed = 1 }, [{ seed = 2, style = "soseul" }, { seed = 3, style = "thatch", open = false }]],
	["saripmun", "사립문 — 문기둥 둘 + 싸리 문짝(가새)", { seed = 1 }, [{ seed = 2, open = false }]],
	["todam", "토담 — 막돌 박은 흙담 + 갓(cap thatch 이엉 / tile 기와). 두 점 사이, ~50/m", { seed = 1 }, [{ seed = 2, cap = "tile" }]],
	["seonghwangdang", "성황당 — 돌무더기 + 신목(금줄·종이 술·오색 천) + (dangjip) 작은 기와 당집. tree=false면 nature 나무 자리만", { seed = 1 }, [{ seed = 2, dangjip = true }, { seed = 3, tree = false }]],
	["sotdae", "솟대 — 장대 끝 나무 오리, n개", { seed = 1 }, [{ seed = 2, n = 1, h = 5.0 }]],
	["jingeom", "징검다리 — 넓적한 디딤돌 줄(z방향, 물 면 y=0). 충돌체 없음", { seed = 1 }, [{ seed = 2, len = 8 }]],
	["seop_bridge", "섶다리 — Y자 다리발·멍에·장선·솔가지·흙 덮은 임시 나무다리(z방향)", { seed = 1 }, [{ seed = 2, len = 14, spans = 6 }]],
	["narutbae", "나룻배 — 평저 나룻배(이물 -z), 멍에·깔판·삿대. 원점 = 물 면", { seed = 1 }, [{ seed = 2, len = 5, pole = false }]],
	["ppallaeteo", "빨래터 — 냇가 빨랫돌 줄 + 방망이 + 젖은 빨래 + 광주리 (+ 물 판)", { seed = 1 }, [{ seed = 2, n = 2, water = false }]],
	["jige", "지게 — 서 있는 지게 + 작대기, load basket(바소쿠리)/wood(나뭇짐)/none", { seed = 1 }, [{ seed = 2, load = "wood" }]],
	["firewood", "장작더미 — row(벽 따라 쌓기, cover 이엉) / stack(井자 쌓기)", { seed = 1 }, [{ seed = 2, style = "stack" }]],
	["props", "작은 소품 — kind: pyeongsang 평상 / gamasot 한데부뚜막 / yongsu 용수 장대 / jeolgu 절구 / maetdol 맷돌 / dok 항아리 / soguri 소쿠리 / byeotdan 볏단 / scarecrow 허수아비 / meongseok 멍석", { seed = 1, kind = "pyeongsang" }, [{ seed = 1, kind = "gamasot" }, { seed = 1, kind = "yongsu" }, { seed = 1, kind = "jeolgu" }, { seed = 1, kind = "maetdol" }, { seed = 1, kind = "dok" }, { seed = 1, kind = "soguri", fill = "grain" }, { seed = 1, kind = "byeotdan" }, { seed = 1, kind = "scarecrow" }, { seed = 1, kind = "meongseok" }]],
	["house_compound", "집 한 채 프리셋 — small(초가+헛간+뒷간+장독+싸리울+사립문) / medium(초가 안채·사랑채+외양간+헛간+토담+초가대문) / large(기와 안채·사랑채+곳간+기와 토담+솟을대문). layout()·pieces로 건물별 조각, lod=1 가벼운 한 덩이", { seed = 1, size = "small" }, [{ seed = 1, size = "medium" }, { seed = 1, size = "large" }, { seed = 1, size = "small", lod = 1 }, { seed = 1, size = "medium", lod = 1 }, { seed = 1, size = "large", lod = 1 }, { seed = 1, size = "small", roof = "neowa", wall = "stone_terrace" }, { seed = 2, size = "medium", roof = "gulpi", wall = "stone" }, { seed = 3, size = "small", roof = "choga_low", wall = "stone" }, { seed = 4, size = "small", roof = "guitul", wall = "fence" }, { seed = 5, size = "medium", roof = "giwa", plan = "giyeok" }, { seed = 6, size = "medium", plan = "il", wall = "fence" }, { seed = 1, size = "medium", roof = "neowa", wall = "stone", lod = 1 }]],
	["stone_jangseung", "돌장승(석장승) — 실상사 해탈교 앞 석장승 참고: 벙거지·왕방울 눈·주먹코·송곳니·앞면 새김 띠. variant 0 벙거지 / 1 높은 관 / 2 민머리", { seed = 1, variant = 0 }, [{ seed = 2, variant = 1 }, { seed = 3, variant = 2, h = 2.9 }]],
	["wall_run", "담 긴 구간 — points 꺾은선 따라 kind stone_lite/stone/todam_thatch/todam_tile/fence_lite/fence, gaps로 구간 비우기, closed", { seed = 1 }, [{ seed = 2, kind = "todam_tile", points = [[-8, 0], [0, 0], [0, -6]] }, { seed = 3, kind = "fence_lite", points = [[-5, 0], [5, 0], [5, -4], [-5, -4]], closed = true, gaps = [0] }]],
	["teotbat", "텃밭 — 싸리울(lite)로 두른 채소밭: 두둑 + 배추·무·고추·파 + 울 위 호박 넝쿨", { seed = 1 }, [{ seed = 2, w = 3.5, d = 2.6, rows = 3, gourd = false }]],
	["yard_props", "마당 소품 묶음 — set manure_coop(거름더미+닭장) / jars(장독 모음) / work(멍석·절구·맷돌·키) / woodpile(장작·지게·볏단·모탕)", { seed = 1, set = "manure_coop" }, [{ seed = 1, set = "jars" }, { seed = 1, set = "work" }, { seed = 1, set = "woodpile" }]],
	["neowa_house", "너와집 — 산촌 민가. 흙벽 3칸 + 회갈색 나무판(너와) 맞배 지붕·누름돌·누름대·박공 까치구멍·통나무 굴뚝. plan il/giyeok, lod=1", { seed = 1 }, [{ seed = 2, plan = "giyeok" }, { seed = 1, lod = 1 }]],
	["gulpi_house", "굴피집 — 산촌 민가. 짙은 갈색 굴참나무 껍질 판 지붕 + 밝은 누름목 세 줄 + 용마루 통나무. plan il/giyeok, lod=1", { seed = 1 }, [{ seed = 2, plan = "il" }]],
	["guitul_house", "귀틀집 — 통나무 井자 귀틀 벽(네 귀 엇물림) + 억새 맞배(잿빛, 기본) 또는 roof neowa/gulpi. 북부·고산용", { seed = 1 }, [{ seed = 2, roof = "neowa" }, { seed = 1, lod = 1 }]],
	["choga_low", "낮은 해안 초가 — 낮은 몸체 + 납작한 잿빛 이엉 + 새끼 그물 격자 + 처마 둘레 매단 돌. 해안·섬용", { seed = 1 }, [{ seed = 2, plan = "il", grid = 5 }]],
	["stone_terrace", "계단식 돌축대 + 돌담 — 비탈 집터 받침. 두 점 사이, 원점 = 위 단 땅(origin bottom이면 맨 아래), tiers 단, drop 전체 높이", { seed = 1 }, [{ seed = 2, origin = "bottom" }, { seed = 3, tiers = 1, drop = 1.2, wall = false }]],
	["village_square", "마을 공동 마당 — 정자나무(nature/big_tree 느티 또는 own) + 둥근 돌 축대 + 평상 둘 + 돌 의자", { seed = 1 }, [{ seed = 2, tree = "own" }, { seed = 3, tree = "none", pyeongsang = 1, seats = 3 }]],
]

func _tris(node: Node3D) -> int:
	var n := 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for s in m.get_surface_count(): n += m.surface_get_array_len(s) / 3
	return n

func _measure(name: String, p: Dictionary) -> Dictionary:
	var r: Dictionary = load("res://kit/village/%s.gd" % name).build(p)
	var fp: Vector2 = r.get("footprint", Vector2.ZERO)
	var out := { params = p, tris = _tris(r.node), footprint = [snappedf(fp.x, 0.1), snappedf(fp.y, 0.1)],
		colliders = r.colliders.size(), lights = r.lights.size(), occluder = r.get("occluder", false),
		anchors = (r.get("anchors", {}) as Dictionary).keys(), interior = r.has("interior"),
		walk = r.has("walk"), pieces = (r.get("pieces", []) as Array).size(), layout = load("res://kit/village/%s.gd" % name).has_method("layout") }
	(r.node as Node3D).free()
	return out

func _init() -> void:
	var list := []
	for e in ENTRIES:
		var item := { name = e[0], file = "res://kit/village/%s.gd" % e[0], desc = e[1], shot = "shots/kit/village/%s.png" % e[0] }
		item.merge(_measure(e[0], e[2]))
		var vars := []
		for v in e[3]: vars.append(_measure(e[0], v))
		item.variants = vars
		list.append(item)
		print("%-16s tris=%5d fp=%s" % [e[0], item.tris, str(item.footprint)])
		for v in vars: print("    %-40s tris=%5d" % [JSON.stringify(v.params), v.tris])
	var doc := { kit = "village", region = "JL_NAMWON_UNBONG", era = "1870 전후 조선 후기",
		note = "build(params) → {node, colliders, lights, occluder, footprint, anchors, interior?}. 정면 +z. tris는 먹선 포함(kit_preview와 같은 셈)",
		budget = { house = 6000, prop = 800, compound = 15000, compound_lod = 4000, yard_set = 2000 }, models = list }
	var f := FileAccess.open("res://kit/village/catalog.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false))
	f.close()
	quit()
