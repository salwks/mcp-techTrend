# 사실적 재질·빛(material-lighting) 공용 — 재질 층 표, 아틀라스 칸 → 재질 번호 지도, 전역 셰이더 값.
#
# 짜임(키트 기하·UV·캐시 키를 건드리지 않는다):
#   - 키트는 그대로 아틀라스(assets/kit/atlas.png) 칸 UV를 쓴다. 셰이더가 칸(아틀라스 좌표 64px 격자)을 보고 재질 번호를 고른다
#     → 전역 텍스처 pbr_ids(16×8). 칸 이름 → 재질은 아래 ATLAS_MAT, 칸 자리는 assets/kit/atlas.json REG(건물 빌더 b_* 칸 포함)에서 읽는다.
#     그래서 건물 빌더(kit/bldg)가 아틀라스에 칸을 더해도 이름만 여기 적으면 된다(없으면 회벽 기본).
#   - 재질마다 512² 디테일 두 장(Texture2DArray): pbr_a(바탕색 배율 + 높이), pbr_b(거칠기·법선·오목) — tools/matlight/bake_pbr.gd가 굽는다.
#   - 조명은 shaders/pbr_common.gdshaderinc(키트·glTF 재질 Materials.world_shader, 지형 region_terrain)가 같은 식으로 계산한다.
#   - look_pbr 0이면 예전 붓 바림(툰) 그대로(--look=ink).
class_name Pbr
extends RefCounted

# 층: 이름, 한국어, 한 장 크기(m), 깊이(m) — 순서 = 층 번호 = pbr_common.gdshaderinc M_*
const LAYERS := [
	{ name = "plaster", ko = "회벽", tile = 2.0, depth = 0.008 },
	{ name = "mud", ko = "흙벽", tile = 1.5, depth = 0.04 },
	{ name = "thatch", ko = "이엉", tile = 1.0, depth = 0.05 },
	{ name = "tile", ko = "기와", tile = 1.0, depth = 0.004 },
	{ name = "wood", ko = "나무(닳음)", tile = 1.0, depth = 0.012 },
	{ name = "maru", ko = "마루", tile = 1.0, depth = 0.004 },
	{ name = "paper", ko = "한지", tile = 0.5, depth = 0.0015 },
	{ name = "stone", ko = "돌(기단·담)", tile = 1.2, depth = 0.06 },
	{ name = "rock", ko = "자연석", tile = 2.0, depth = 0.05 },
	{ name = "paving", ko = "박석", tile = 2.5, depth = 0.035 },
	{ name = "dirt", ko = "흙 마당", tile = 2.0, depth = 0.03 },
	{ name = "path", ko = "다진 길", tile = 2.0, depth = 0.02 },
	{ name = "grass", ko = "풀", tile = 1.0, depth = 0.03 },
	{ name = "jangpan", ko = "장판", tile = 0.6, depth = 0.001 },
	{ name = "bark", ko = "나무껍질", tile = 1.0, depth = 0.03 },
	{ name = "foliage", ko = "잎", tile = 0.5, depth = 0.004 },
	{ name = "cloth", ko = "천", tile = 0.25, depth = 0.0015 },
	{ name = "snow", ko = "눈", tile = 1.5, depth = 0.015 },
]
const M := { plaster = 0, mud = 1, thatch = 2, tile = 3, wood = 4, maru = 5, paper = 6, stone = 7, rock = 8, paving = 9,
	dirt = 10, path = 11, grass = 12, jangpan = 13, bark = 14, foliage = 15, cloth = 16, snow = 17 }

# 아틀라스 칸 이름 → 재질. b_* 는 건물 빌더(kit/bldg/_atlas.gd, tools/bldg/make_atlas.gd) 칸 — 기본 아틀라스에는 없어도 해롭지 않다.
const ATLAS_MAT := {
	lattice = "paper", thatch = "thatch", tile = "tile", makse = "tile", rock = "rock", mud = "mud",
	needle = "foliage", leaf = "foliage", bark = "bark", face0 = "wood", face1 = "wood", white = "plaster", lamp = "paper",
	wood = "wood", stone = "stone", cloth = "cloth",
	b_ddi = "paper", b_yong = "paper", b_a = "paper", b_gyo = "paper", b_kkot = "paper", b_maru = "maru", b_jangpan = "jangpan",
	b_panbyeok = "wood", b_yongmareum = "thatch", b_giwa = "tile", b_dancheong = "wood", b_soffit = "wood",
}
# 건물 빌더 칸 자리(그 갈래가 합쳐지기 전에도 표가 맞게 — atlas.json에 있으면 그쪽이 이긴다)
const BLDG_REG := {
	b_ddi = [0, 384, 64, 512], b_yong = [64, 384, 128, 512], b_a = [128, 384, 192, 512], b_gyo = [192, 384, 256, 512],
	b_kkot = [256, 384, 320, 512], b_maru = [320, 384, 448, 512], b_jangpan = [448, 384, 576, 512], b_panbyeok = [576, 384, 704, 512],
	b_yongmareum = [704, 384, 832, 512], b_giwa = [832, 384, 960, 512], b_dancheong = [768, 256, 896, 384], b_soffit = [896, 256, 1024, 384],
}

static var _ids: ImageTexture
# 사실 재질·빛을 쓸까(--look=ink면 false). 재질 셰이더를 만들기 전에(region_main._ready 맨 앞) 정한다 — 셰이더에 컴파일 때 들어간다
static var real := true
static var _terrain_keep: Shader

# --look=ink: 지형 셰이더의 #define LOOK_PBR 줄을 빼 둔다(불러온 자원을 고쳐 캐시에 남긴다 — 지형이 이 자원을 쓰기 전에)
static func set_real(on: bool) -> void:
	real = on
	if not on and _terrain_keep == null:
		_terrain_keep = load("res://shaders/region_terrain.gdshader")
		_terrain_keep.code = _terrain_keep.code.replace("#define LOOK_PBR", "// (ink)")

# 아틀라스 64px 칸마다 재질 번호(R8). 셰이더: texelFetch(pbr_ids, ivec2(atlas_uv * vec2(16, 8)), 0).r * 255
static func id_texture() -> ImageTexture:
	if _ids != null: return _ids
	var img := Image.create(16, 8, false, Image.FORMAT_R8)
	img.fill(Color(M.plaster / 255.0, 0, 0))
	var reg := {}
	for k in BLDG_REG: reg[k] = BLDG_REG[k]
	for k in Kit.REG: reg[k] = Kit.REG[k]
	var jp := "res://assets/kit/atlas.json"
	if FileAccess.file_exists(jp):
		var j = JSON.parse_string(FileAccess.get_file_as_string(jp))
		if j is Dictionary and j.get("REG") is Dictionary:
			for k in j.REG: reg[k] = j.REG[k]
	for k in reg:
		var mat: String = ATLAS_MAT.get(k, "")
		if mat == "": continue
		var r: Array = reg[k]
		for cy in range(int(r[1]) / 64, int(r[3]) / 64):
			for cx in range(int(r[0]) / 64, int(r[2]) / 64):
				img.set_pixel(cx, cy, Color(M[mat] / 255.0, 0, 0))
	_ids = ImageTexture.create_from_image(img)
	return _ids

static var _ok := false
# 전역 셰이더 값(텍스처) — project.godot [shader_globals]에 이름은 있고, 여기서 실제 텍스처를 넣는다
static func ensure() -> void:
	if _ok: return
	_ok = true
	RenderingServer.global_shader_parameter_set("pbr_ids", id_texture())
	var a = load("res://assets/pbr/pbr_a.res")
	var b = load("res://assets/pbr/pbr_b.res")
	if a != null: RenderingServer.global_shader_parameter_set("pbr_a", a)
	if b != null: RenderingServer.global_shader_parameter_set("pbr_b", b)
	if a == null or b == null:
		push_warning("PBR textures missing — run tools/matlight/bake_pbr.gd")
		RenderingServer.global_shader_parameter_set("look_pbr", 0.0)
