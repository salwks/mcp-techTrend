# trees-khs 나무 자산 짓기 — 곰솔 5종(국가유산청 스캔, 공공누리 1유형) + 참나무 stand-in 4종(CC0 잎·껍질, 절차 가지)
#   godot --path . -s res://tools/trees_khs/build.gd -- --stage=tex,mesh,bake   (창 필요 — 헤드리스는 텍스처·렌더 자료를 남기지 않는다)
#   python3 -I tools/trees_khs/prep_textures.py imp
#   godot --path . -s res://tools/trees_khs/build.gd -- --stage=pack
#   (tools/trees_khs/build.sh가 차례로 돌린다)
# 산출(깃에 들어감): assets/trees/*.res(압축 텍스처·메시·임포스터 배열), *.tres(재질), meta.json(변형 표·임포스터 틀), manifest.json(출처)
extends SceneTree

const OUT := "res://assets/trees/"
const KHS := "res://assets/trees/khs_gomsol/src/"
const WORK := "res://assets/trees/_work/"
const CELL := Vector2i(512, 1024)     # 굽는 칸(파이썬이 반으로 줄여 256×512 — 층 1024²)
const CARD_K := [1.22, 1.8]          # 곰솔 잎 카드 키움(LOD0, LOD1 — LOD1은 복제가 적어 더 키운다)

# 변형 표 — 층 번호 = 순서(kit/nature/khs_trees.gd VARIANTS와 같다)
const GOMSOL := [
	{ name = "gomsol_A_natural", dup0 = 0.2, dup1 = 0.0 },
	{ name = "gomsol_B_umbrella", dup0 = 0.45, dup1 = 0.1 },
	{ name = "gomsol_C_tall_layered", dup0 = 0.3, dup1 = 0.0 },
	{ name = "gomsol_D_windswept", dup0 = 0.2, dup1 = 0.0 },
	{ name = "gomsol_E_young", dup0 = 0.15, dup1 = 0.0 },
]
# 참나무 stand-in: H 키, bole 첫 갈래 높이, tr 밑동 반지름, ns 큰 가지 수, cr 수관 반지름, sy 수관 납작함, cs 잎 카드 크기, nc 카드 수(LOD0)
const OAKS := [
	{ name = "oak_sangsuri_a", H = 14.0, bole = 3.6, tr = 0.3, ns = 4, cr = 5.2, sy = 0.62, cs = 1.7, nc = 520, seed = 11, lean = 0.3 },
	{ name = "oak_sangsuri_b", H = 12.0, bole = 2.6, tr = 0.27, ns = 5, cr = 4.6, sy = 0.7, cs = 1.6, nc = 460, seed = 23, lean = 0.6 },
	{ name = "oak_singal", H = 10.5, bole = 2.2, tr = 0.26, ns = 4, cr = 4.0, sy = 0.66, cs = 1.5, nc = 400, seed = 37, lean = 1.0 },
	{ name = "oak_broad", H = 15.0, bole = 3.0, tr = 0.45, ns = 6, cr = 7.0, sy = 0.55, cs = 1.9, nc = 680, seed = 51, lean = 0.2 },
	# 마을·들 나무(두 번째 잎 아틀라스 broad2 — q 분면: 0 버드나무 1 감나무 2 밤나무 3 느티나무). hang: 잎 카드를 아래로 매단다(버드나무)
	{ name = "willow_a", H = 10.0, bole = 2.0, tr = 0.36, ns = 5, cr = 4.6, sy = 0.8, cs = 2.4, nc = 460, seed = 61, lean = 0.9, leaf = "broad2", q = 0, hang = true, blen = 0.8, crop = [0.3, 0.7], el = [48.0, 72.0] },
	{ name = "willow_b", H = 8.0, bole = 1.6, tr = 0.3, ns = 4, cr = 3.8, sy = 0.85, cs = 2.0, nc = 380, seed = 67, lean = 1.4, leaf = "broad2", q = 0, hang = true, blen = 0.8, crop = [0.3, 0.7], el = [45.0, 70.0] },
	{ name = "persimmon", H = 7.5, bole = 1.7, tr = 0.24, ns = 4, cr = 3.5, sy = 0.78, cs = 1.25, nc = 420, seed = 71, lean = 0.7, leaf = "broad2", q = 1 },
	{ name = "chestnut", H = 11.0, bole = 2.4, tr = 0.32, ns = 5, cr = 5.0, sy = 0.66, cs = 1.5, nc = 520, seed = 79, lean = 0.4, leaf = "broad2", q = 2 },
	{ name = "zelkova_dangsan", H = 17.0, bole = 2.6, tr = 0.85, ns = 7, cr = 9.0, sy = 0.56, cs = 1.8, nc = 900, seed = 83, lean = 0.2, leaf = "broad2", q = 3, el = [24.0, 50.0] },
	# 덤불(숲 밑·울타리 가): 밑에서 여러 줄기
	{ name = "shrub_oak", H = 1.9, bole = 0.15, tr = 0.045, ns = 6, cr = 1.15, sy = 0.8, cs = 0.8, nc = 60, seed = 89, lean = 0.5, el = [40.0, 72.0], sub = 1, sides = 3 },
	{ name = "shrub_twig", H = 1.4, bole = 0.1, tr = 0.035, ns = 5, cr = 0.9, sy = 0.85, cs = 0.68, nc = 52, seed = 97, lean = 0.6, leaf = "broad2", q = 3, el = [45.0, 75.0], sub = 1, sides = 3 },
]

var stages := PackedStringArray()
var meta := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="): stages = a.substr(8).split(",")
	if stages.is_empty(): stages = PackedStringArray(["tex", "mesh", "bake"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK))
	if FileAccess.file_exists(OUT + "meta.json"): meta = JSON.parse_string(FileAccess.get_file_as_string(OUT + "meta.json"))
	if not meta.has("variants"): meta.variants = []
	_run.call_deferred()

func _run() -> void:
	if stages.has("tex"): _stage_tex()
	if stages.has("mesh"): _stage_mesh()
	if stages.has("bake"): await _stage_bake()
	if stages.has("pack"): _stage_pack()
	var f := FileAccess.open(OUT + "meta.json", FileAccess.WRITE); f.store_string(JSON.stringify(meta, " ", false)); f.close()
	print("TREES done ", stages)
	quit()

# ------------------------------------------------------------------ 텍스처
func _load_mip(path: String) -> Image:
	var b := FileAccess.get_file_as_bytes(path)
	var w := b.decode_u32(4); var h := b.decode_u32(8)
	return Image.create_from_data(w, h, true, Image.FORMAT_RGBA8, b.slice(16))

func _save_tex(img: Image, path: String, mode: String) -> void:
	match mode:
		"rgb":
			img.convert(Image.FORMAT_RGB8)
			if not img.has_mipmaps(): img.generate_mipmaps()
			img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_SRGB)
		"rgba":
			if not img.has_mipmaps(): img.generate_mipmaps()
			img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_SRGB)
		"normal":
			img.convert(Image.FORMAT_RGB8)
			if not img.has_mipmaps(): img.generate_mipmaps(true)
			img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL)
		"lin":
			img.convert(Image.FORMAT_RGB8)
			if not img.has_mipmaps(): img.generate_mipmaps()
			img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC)
	var t := ImageTexture.create_from_image(img)
	print("TREES tex ", path, " ", img.get_format(), " ", img.get_width(), " err=", ResourceSaver.save(t, path, ResourceSaver.FLAG_COMPRESS))

func _png(p: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(p))

func _stage_tex() -> void:
	var gt := KHS + "gomsol_textures/"
	_save_tex(_load_mip(WORK + "gomsol_leaf_bca.mip"), OUT + "pine_leaf_bca.res", "rgba")
	_save_tex(_png(gt + "gomsol_bark_bc_2048.png"), OUT + "pine_bark_bc.res", "rgb")
	_save_tex(_png(gt + "gomsol_bark_normal_1024.png"), OUT + "pine_bark_nrm.res", "normal")
	_save_tex(_png(gt + "gomsol_bark_orm_1024.png"), OUT + "pine_bark_orm.res", "lin")
	_save_tex(_png(gt + "gomsol_leaf_orm_1024.png"), OUT + "pine_leaf_orm.res", "lin")
	_save_tex(_load_mip(WORK + "oak_leaf_bca.mip"), OUT + "oak_leaf_bca.res", "rgba")
	_save_tex(_png(WORK + "oak_bark_bc_1k.png"), OUT + "oak_bark_bc.res", "rgb")
	_save_tex(_png(WORK + "oak_bark_nrm_1k.png"), OUT + "oak_bark_nrm.res", "normal")
	var ao := _png(WORK + "oak_bark_ao_1k.png"); var ro := _png(WORK + "oak_bark_rough_1k.png")
	var orm := Image.create(1024, 1024, false, Image.FORMAT_RGB8)
	for y in 1024:
		for x in 1024:
			orm.set_pixel(x, y, Color(ao.get_pixel(x, y).r, ro.get_pixel(x, y).r, 0.0))
	_save_tex(orm, OUT + "oak_bark_orm.res", "lin")
	# 재질(.tres) — 이미 있으면 보정 값은 그대로 두고 텍스처만 다시 건다
	_mat("pine_leaf", "res://shaders/tree_leaf.gdshader", { albedo_tex = OUT + "pine_leaf_bca.res", orm_tex = OUT + "pine_leaf_orm.res" })
	_mat("pine_bark", "res://shaders/tree_bark.gdshader", { albedo_tex = OUT + "pine_bark_bc.res", orm_tex = OUT + "pine_bark_orm.res", normal_tex = OUT + "pine_bark_nrm.res" },
		{ normal_flip_y = 1.0 })   # 곰솔 껍질 법선은 DirectX식(초록 뒤집힘) — 바탕색 밝기 기울기와 견줘 확인(trees-khs 보고서)
	_mat("oak_leaf", "res://shaders/tree_leaf.gdshader", { albedo_tex = OUT + "oak_leaf_bca.res" },
		{ leaf_tint = Color(0.5, 0.6, 0.4), leaf_sat = 0.8, leaf_bright = 0.7, leaf_var = 0.4, leaf_trans = 0.4 })
	_save_tex(_load_mip(WORK + "broad2_leaf_bca.mip"), OUT + "broad2_leaf_bca.res", "rgba")
	_mat("broad2_leaf", "res://shaders/tree_leaf.gdshader", { albedo_tex = OUT + "broad2_leaf_bca.res" },
		{ leaf_tint = Color(0.74, 0.8, 0.68), leaf_sat = 0.88, leaf_bright = 0.82, leaf_var = 0.35, leaf_trans = 0.42 })
	_mat("oak_bark", "res://shaders/tree_bark.gdshader", { albedo_tex = OUT + "oak_bark_bc.res", orm_tex = OUT + "oak_bark_orm.res", normal_tex = OUT + "oak_bark_nrm.res" },
		{ bark_low = Color(0.8, 0.78, 0.74), bark_high = Color(0.85, 0.82, 0.76), bark_bright = 1.25 })

func _mat(nm: String, shader: String, texs: Dictionary, defaults := {}) -> void:
	var p := OUT + nm + ".tres"
	var m: ShaderMaterial = load(p) if ResourceLoader.exists(p) else null
	if m == null:
		m = ShaderMaterial.new()
		for k in defaults: m.set_shader_parameter(k, defaults[k])
	m.shader = load(shader)
	for k in texs: m.set_shader_parameter(k, load(texs[k]))
	print("TREES mat ", p, " err=", ResourceSaver.save(m, p))

# ------------------------------------------------------------------ 메시
func _stage_mesh() -> void:
	var vlist := []
	for gi in GOMSOL.size():
		var g: Dictionary = GOMSOL[gi]
		var info := { name = g.name, family = "pine", bark = "pine", layer = vlist.size() }
		for lod in 2:
			var src := _gltf_mesh(KHS + g.name + "/" + g.name + "_LOD%d.gltf" % lod, "_LOD%d" % lod)
			var res := _process_khs(src, g.dup0 if lod == 0 else g.dup1, 1000 + gi * 17 + lod, CARD_K[lod], 1.0 if lod == 0 else 0.62)
			var p := OUT + "%s_lod%d.res" % [g.name, lod]
			print("TREES mesh ", p, " tris=", res.tris, " err=", ResourceSaver.save(res.mesh, p, ResourceSaver.FLAG_COMPRESS))
			info["tris%d" % lod] = res.tris
			info.height = res.height
			info.crown_r = res.crown_r
		vlist.append(info)
	for oi in OAKS.size():
		var o: Dictionary = OAKS[oi]
		var info := { name = o.name, family = String(o.get("leaf", "oak")), bark = "oak", layer = vlist.size() }
		for lod in 2:
			var res := _oak(o, lod)
			var p := OUT + "%s_lod%d.res" % [o.name, lod]
			print("TREES mesh ", p, " tris=", res.tris, " err=", ResourceSaver.save(res.mesh, p, ResourceSaver.FLAG_COMPRESS))
			info["tris%d" % lod] = res.tris
			info.height = res.height
			info.crown_r = res.crown_r
		vlist.append(info)
	# 임포스터 틀은 굽기에서 채운다(있던 값 보존)
	for v in vlist:
		for old in meta.variants:
			if old.name == v.name and old.has("box"): v.box = old.box
	meta.variants = vlist

func _gltf_mesh(path: String, tag: String) -> ArrayMesh:
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(path), st)
	var sc: Node = doc.generate_scene(st)
	var out: ArrayMesh = null
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).ends_with(tag): out = mi.mesh
	sc.free()
	return out

class Isl:
	var verts := PackedInt32Array()
	var c := Vector3.ZERO

# 섬(이어진 카드) 나누기 — 인덱스로 합집합 찾기
func _islands(idx: PackedInt32Array, nv: int) -> Array:
	var par := PackedInt32Array(); par.resize(nv)
	for i in nv: par[i] = i
	var find := func(x: int) -> int:
		while par[x] != x:
			par[x] = par[par[x]]; x = par[x]
		return x
	for t in range(0, idx.size(), 3):
		var a: int = find.call(idx[t]); var b: int = find.call(idx[t + 1]); var c: int = find.call(idx[t + 2])
		if a != b: par[a] = b
		b = find.call(b)
		if c != b: par[find.call(c)] = b
	var groups := {}
	for i in nv:
		var r: int = find.call(i)
		if not groups.has(r): groups[r] = Isl.new()
		(groups[r] as Isl).verts.append(i)
	return groups.values()

# 줄기 축: 1m 띠마다 앞 축에 가까운 껍질 꼭짓점들의 가운데
func _axis(bark_v: PackedVector3Array, H: float) -> PackedVector2Array:
	var n := int(ceil(H)) + 2
	var ax := PackedVector2Array(); ax.resize(n)
	var prev := Vector2.ZERO
	var cnt := 0; var acc := Vector2.ZERO
	for p in bark_v:
		if p.y < 0.6: acc += Vector2(p.x, p.z); cnt += 1
	if cnt > 0: prev = acc / cnt
	for b in n:
		acc = Vector2.ZERO; cnt = 0
		for p in bark_v:
			if p.y >= b and p.y < b + 1.0 and Vector2(p.x, p.z).distance_to(prev) < 0.7: acc += Vector2(p.x, p.z); cnt += 1
		if cnt > 0: prev = acc / cnt
		ax[b] = prev
	return ax

func _ax_at(ax: PackedVector2Array, y: float) -> Vector2:
	var i := clampi(int(y), 0, ax.size() - 2)
	return ax[i].lerp(ax[i + 1], clampf(y - i, 0.0, 1.0))

# 곰솔: 잎 카드 섬을 복제해 수관을 채우고(줄기 축 둘레로 돌리고 조금 줄임), 법선을 수관 바깥쪽으로 섞고, 바람·그늘 자료를 넣는다
func _process_khs(src: ArrayMesh, dup: float, seed: int, card_k: float, keep := 1.0) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var ab := src.surface_get_arrays(0)
	var al := src.surface_get_arrays(1)
	var bv: PackedVector3Array = ab[Mesh.ARRAY_VERTEX]
	var H := 0.0
	for p in bv: H = maxf(H, p.y)
	var lv0: PackedVector3Array = al[Mesh.ARRAY_VERTEX]
	for p in lv0: H = maxf(H, p.y)
	var ax := _axis(bv, H)
	# 잎 복제
	var lv := PackedVector3Array(lv0); var ln := PackedVector3Array(al[Mesh.ARRAY_NORMAL]); var luv := PackedVector2Array(al[Mesh.ARRAY_TEX_UV])
	var li := PackedInt32Array(al[Mesh.ARRAY_INDEX])
	var isl := _islands(li, lv.size())
	var isl_of := PackedInt32Array(); isl_of.resize(lv.size())
	for k in isl.size():
		for v in (isl[k] as Isl).verts: isl_of[v] = k
	var tri_of := {}   # 섬 → 삼각형 시작들
	for t in range(0, li.size(), 3):
		var k := isl_of[li[t]]
		if not tri_of.has(k): tri_of[k] = PackedInt32Array()
		tri_of[k].append(t)
	var nisl := isl.size()
	var isl_ph := PackedFloat32Array()
	for k in nisl: isl_ph.append(rng.randf())
	# LOD1: 섬을 솎는다(남은 카드를 더 키워 덮임을 맞춘다 — 잎 겹침·삼각형을 줄이려고)
	if keep < 1.0:
		var li2 := PackedInt32Array()
		var drop := {}
		for k in nisl:
			if rng.randf() > keep: drop[k] = true
		for t in range(0, li.size(), 3):
			if not drop.has(isl_of[li[t]]): li2.append_array([li[t], li[t + 1], li[t + 2]])
		li = li2
		tri_of.clear()
		for t in range(0, li.size(), 3):
			var k := isl_of[li[t]]
			if not tri_of.has(k): tri_of[k] = PackedInt32Array()
			tri_of[k].append(t)
	var Htop := H
	for k in nisl:
		if not tri_of.has(k): continue
		if rng.randf() >= dup: continue
		var I: Isl = isl[k]
		var c := Vector3.ZERO
		for v in I.verts: c += lv0[v]
		c /= I.verts.size()
		var a0 := _ax_at(ax, c.y)
		var ang := (rng.randf() * 2.0 - 1.0) * deg_to_rad(40.0)
		if absf(ang) < deg_to_rad(15.0): ang = signf(ang + 1e-4) * deg_to_rad(15.0)
		var sc := rng.randf_range(0.82, 1.0)
		var inward := rng.randf_range(0.0, 0.1)
		var dy := rng.randf_range(-0.35, 0.35)
		var rot := Basis(Vector3.UP, ang)
		# 위쪽 수관(높이 55% 위)의 복제는 카드를 위로 눕힌다 — 위에서 내려다볼 때(들·산 구도) 수관이 성기지 않게
		var tilt := Basis.IDENTITY
		var piv := c
		if c.y > Htop * 0.55:
			var nav := Vector3.ZERO
			for v in I.verts: nav += ln[v]
			nav = nav.normalized()
			if nav.y < 0.0: nav = -nav
			var tgt := (nav + Vector3.UP * 1.6).normalized()
			var axv := nav.cross(tgt)
			if axv.length() > 1e-3: tilt = Basis(axv.normalized(), nav.angle_to(tgt) * rng.randf_range(0.6, 1.0))
			var bd2 := INF
			for v in I.verts:
				var dd := Vector2(lv0[v].x, lv0[v].z).distance_to(a0)
				if dd < bd2: bd2 = dd; piv = lv0[v]
		var map := {}
		for v in I.verts:
			var p := piv + tilt * (lv0[v] - piv)
			var q := (p - c) * sc + c
			var rel := Vector3(q.x - a0.x, q.y + dy, q.z - a0.y)
			rel = rot * rel
			rel.x *= 1.0 - inward; rel.z *= 1.0 - inward
			map[v] = lv.size()
			lv.append(Vector3(rel.x + a0.x, rel.y, rel.z + a0.y))
			ln.append(rot * (tilt * ln[v]))
			luv.append(luv[v])
		isl_ph.append(rng.randf())
		for t in tri_of[k]:
			li.append(map[li[t]]); li.append(map[li[t + 1]]); li.append(map[li[t + 2]])
		var nk := isl_ph.size() - 1
		isl_of.resize(lv.size())
		for v in I.verts: isl_of[map[v]] = nk
	# 카드 키우기: 섬마다 줄기 쪽 꼭짓점을 밑으로 CARD_K배(삼각형 없이 수관이 두툼해진다 — 원본은 위에서 보면 성기다)
	var nk0 := isl_ph.size()
	var bpt := PackedVector3Array(); bpt.resize(nk0)
	var bd := PackedFloat32Array(); bd.resize(nk0); bd.fill(INF)
	for v in lv.size():
		var a1 := _ax_at(ax, lv[v].y)
		var dd := Vector2(lv[v].x, lv[v].z).distance_to(a1)
		if dd < bd[isl_of[v]]: bd[isl_of[v]] = dd; bpt[isl_of[v]] = lv[v]
	for v in lv.size(): lv[v] = bpt[isl_of[v]] + (lv[v] - bpt[isl_of[v]]) * card_k
	# 수관 반지름(높이 띠마다 축에서 가장 먼 잎)
	var band_r := PackedFloat32Array(); band_r.resize(int(H) + 2)
	var ylo := INF; var yhi := -INF
	for p in lv:
		var a := _ax_at(ax, p.y)
		var r := Vector2(p.x, p.z).distance_to(a)
		var b := clampi(int(p.y), 0, band_r.size() - 1)
		band_r[b] = maxf(band_r[b], r)
		ylo = minf(ylo, p.y); yhi = maxf(yhi, p.y)
	var crown_r := 0.0
	for r in band_r: crown_r = maxf(crown_r, r)
	var cy := (ylo + yhi) * 0.5; var ch := maxf((yhi - ylo) * 0.5, 0.5)
	# 섬마다 중심·밑(축에 가장 가까운 꼭짓점)
	var nk_all := isl_ph.size()
	var cen := PackedVector3Array(); cen.resize(nk_all)
	var cnt := PackedInt32Array(); cnt.resize(nk_all)
	for v in lv.size():
		cen[isl_of[v]] += lv[v]; cnt[isl_of[v]] += 1
	for k in nk_all: cen[k] /= maxi(cnt[k], 1)
	var isl_sz := PackedFloat32Array(); isl_sz.resize(nk_all)
	for v in lv.size(): isl_sz[isl_of[v]] = maxf(isl_sz[isl_of[v]], lv[v].distance_to(cen[isl_of[v]]))
	var lc := PackedColorArray(); lc.resize(lv.size())
	var lcu := PackedFloat32Array(); lcu.resize(lv.size() * 4)
	for v in lv.size():
		var p := lv[v]
		var k := isl_of[v]
		var a := _ax_at(ax, p.y)
		var d2 := Vector2(p.x - a.x, p.z - a.y)
		var rb: float = maxf(band_r[clampi(int(p.y), 0, band_r.size() - 1)], 0.6)
		var rn := clampf(d2.length() / rb, 0.0, 1.0)
		var radial := Vector3(d2.x / maxf(crown_r, 0.5), clampf((p.y - cy) / ch, -1.0, 1.0) * 0.7 + 0.3, d2.y / maxf(crown_r, 0.5)).normalized()
		var n := ln[v].normalized()
		if n.dot(radial) < 0.0: n = -n
		ln[v] = n.lerp(radial, 0.68).normalized()
		var ao := lerpf(0.55, 1.0, smoothstep(0.15, 0.95, rn)) * lerpf(0.8, 1.0, clampf((p.y - ylo) / maxf(yhi - ylo, 0.1), 0.0, 1.0))
		lc[v] = Color(ao, isl_ph[k], 1.0, 1.0)
		lcu[v * 4] = p.y / H
		lcu[v * 4 + 1] = clampf(d2.length() / maxf(crown_r, 0.5), 0.0, 1.0) * smoothstep(0.15, 0.5, p.y / H)
		lcu[v * 4 + 2] = isl_ph[k]
		lcu[v * 4 + 3] = clampf(p.distance_to(cen[k]) / maxf(isl_sz[k], 0.05), 0.0, 1.0)
	# 껍질: 높이·가지 흔들림·그늘
	var bn: PackedVector3Array = ab[Mesh.ARRAY_NORMAL]
	var bc := PackedColorArray(); bc.resize(bv.size())
	var bcu := PackedFloat32Array(); bcu.resize(bv.size() * 4)
	for v in bv.size():
		var p := bv[v]
		var a := _ax_at(ax, p.y)
		var dd := Vector2(p.x, p.z).distance_to(a)
		var inside := 1.0 - smoothstep(ylo - 1.0, ylo + 1.5, p.y) * 0.4
		bc[v] = Color(clampf(inside * lerpf(0.75, 1.0, clampf(dd / maxf(crown_r, 0.5), 0.0, 1.0)), 0.0, 1.0), 0.5, 0.0, 1.0)
		bcu[v * 4] = p.y / H
		bcu[v * 4 + 1] = clampf((dd - 0.25) / maxf(crown_r * 0.8, 0.5), 0.0, 1.0)
		bcu[v * 4 + 2] = 0.0
		bcu[v * 4 + 3] = 0.0
	var am := ArrayMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var barr := []; barr.resize(Mesh.ARRAY_MAX)
	barr[Mesh.ARRAY_VERTEX] = bv; barr[Mesh.ARRAY_NORMAL] = bn; barr[Mesh.ARRAY_TANGENT] = ab[Mesh.ARRAY_TANGENT]
	barr[Mesh.ARRAY_TEX_UV] = ab[Mesh.ARRAY_TEX_UV]; barr[Mesh.ARRAY_COLOR] = bc; barr[Mesh.ARRAY_CUSTOM0] = bcu; barr[Mesh.ARRAY_INDEX] = ab[Mesh.ARRAY_INDEX]
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, barr, [], {}, flags)
	var larr := []; larr.resize(Mesh.ARRAY_MAX)
	larr[Mesh.ARRAY_VERTEX] = lv; larr[Mesh.ARRAY_NORMAL] = ln; larr[Mesh.ARRAY_TEX_UV] = luv
	larr[Mesh.ARRAY_COLOR] = lc; larr[Mesh.ARRAY_CUSTOM0] = lcu; larr[Mesh.ARRAY_INDEX] = li
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, larr, [], {}, flags)
	am.surface_set_name(0, "bark"); am.surface_set_name(1, "leaf")
	var tris := ((ab[Mesh.ARRAY_INDEX] as PackedInt32Array).size() + li.size()) / 3
	return { mesh = am, tris = tris, height = H, crown_r = crown_r }

# ------------------------------------------------------------------ 참나무 stand-in(절차 가지 + CC0 잎 뭉치 카드)
class Tube:
	var v := PackedVector3Array(); var n := PackedVector3Array(); var t := PackedFloat32Array(); var uv := PackedVector2Array()
	var col := PackedColorArray(); var cu := PackedFloat32Array(); var idx := PackedInt32Array()

# 굽은 가지 하나(점 목록·반지름 목록) → 관
func _tube(T: Tube, pts: Array, rad: Array, sides: int, H: float, crown_r: float, axis_xz: Vector2) -> void:
	var base := T.v.size()
	var prev_u := Vector3.RIGHT
	var vacc := 0.0
	for i in pts.size():
		var p: Vector3 = pts[i]
		var dir: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var u := prev_u - dir * prev_u.dot(dir)
		if u.length() < 1e-3: u = dir.cross(Vector3.FORWARD)
		u = u.normalized(); prev_u = u
		var w := dir.cross(u)
		if i > 0: vacc += (p - (pts[i - 1] as Vector3)).length() / maxf(TAU * float(rad[i]) * 0.9, 0.15)
		var dd := Vector2(p.x, p.z).distance_to(axis_xz)
		for s in sides + 1:
			var a := TAU * s / sides
			var nn := u * cos(a) + w * sin(a)
			T.v.append(p + nn * float(rad[i])); T.n.append(nn)
			var tg := (-u * sin(a) + w * cos(a))
			T.t.append_array([tg.x, tg.y, tg.z, 1.0])
			T.uv.append(Vector2(float(s) / sides * maxf(1.0, round(float(rad[i]) * 6.0)), vacc))
			T.col.append(Color(lerpf(0.7, 1.0, clampf(dd / maxf(crown_r, 0.5), 0.0, 1.0)), 0.5, 0.0, 1.0))
			T.cu.append_array([p.y / H, clampf((dd - 0.3) / maxf(crown_r * 0.8, 0.5), 0.0, 1.0), 0.0, 0.0])
	for i in pts.size() - 1:
		for s in sides:
			var a := base + i * (sides + 1) + s
			var b := a + sides + 1
			T.idx.append_array([a, b, a + 1, a + 1, b, b + 1])

func _curve(a: Vector3, d: Vector3, L: float, n: int, up: float, rng: RandomNumberGenerator, wob: float) -> Array:
	var pts := [a]
	var p := a; var dir := d.normalized()
	for i in n:
		dir = (dir + Vector3(rng.randf_range(-wob, wob), up + rng.randf_range(-wob, wob) * 0.5, rng.randf_range(-wob, wob))).normalized()
		p += dir * (L / n)
		pts.append(p)
	return pts

func _oak(o: Dictionary, lod: int) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = int(o.seed)
	var H: float = o.H; var cr: float = o.cr; var tr: float = o.tr
	var T := Tube.new()
	var sides0 := int(o.get("sides", 9 if lod == 0 else 6)) if lod == 0 else mini(int(o.get("sides", 6)), 6)
	# 줄기(밑동 퍼짐 + 기울기)
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * float(o.lean) * 0.12
	var trunk := _curve(Vector3(0, -0.3, 0), Vector3(0, 1, 0) + lean, float(o.bole) + 0.3, 6, 0.05, rng, 0.08)
	var trad := []
	for i in trunk.size(): trad.append(tr * (1.0 + 0.45 * exp(-float(i) * 1.6)) * lerpf(1.0, 0.8, float(i) / trunk.size()))
	var top: Vector3 = trunk[trunk.size() - 1]
	var axis := Vector2(top.x, top.z)
	var cy := float(o.bole) + (H - float(o.bole)) * 0.55
	# 줄기는 수관 속으로 조금 더(중심 줄기)
	var leader := _curve(top, Vector3(0, 1, 0) + lean * 0.5, (H - float(o.bole)) * 0.55, 5, 0.05, rng, 0.12)
	var lrad := []
	for i in leader.size(): lrad.append(tr * 0.8 * lerpf(1.0, 0.25, float(i) / leader.size()))
	_tube(T, trunk, trad, sides0, H, cr, axis)
	_tube(T, leader, lrad, maxi(3, sides0 - 2), H, cr, axis)
	var ends := []   # 잎 붙일 자리: [점, 방향]
	var ns: int = o.ns
	for s in ns:
		var az := TAU * (float(s) + rng.randf_range(-0.25, 0.25)) / ns
		var hstart := float(o.bole) * rng.randf_range(0.85, 1.0) + float(s % 2) * 0.5
		var src: Vector3 = trunk[trunk.size() - 1] if s % 3 != 2 else leader[mini(2, leader.size() - 1)]
		src.y = minf(src.y, hstart + 0.6)
		var elr: Array = o.get("el", [32.0, 58.0])
		var el := deg_to_rad(rng.randf_range(elr[0], elr[1]))
		var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var L := cr * rng.randf_range(0.95, 1.2) / cos(el) * 0.85 * float(o.get("blen", 1.0))
		var sc := _curve(src, dir, L, 6, 0.04, rng, 0.14)
		var srad := []
		for i in sc.size(): srad.append(tr * 0.55 * lerpf(1.0, 0.18, float(i) / (sc.size() - 1)))
		_tube(T, sc, srad, maxi(3, sides0 - 3), H, cr, axis)
		# 곁가지
		var nsub := (int(o.get("sub", 5)) if lod == 0 else 3) + rng.randi_range(0, 2)
		for k in nsub:
			var t := rng.randf_range(0.3, 0.95)
			var ii := int(t * (sc.size() - 1))
			var p0: Vector3 = sc[ii]
			var bd: Vector3 = ((sc[mini(ii + 1, sc.size() - 1)] as Vector3) - (sc[maxi(ii - 1, 0)] as Vector3)).normalized()
			var side := bd.cross(Vector3.UP).normalized() * (1.0 if k % 2 == 0 else -1.0)
			var d2 := (bd * 0.6 + side * rng.randf_range(0.5, 0.9) + Vector3(0, rng.randf_range(0.1, 0.6), 0)).normalized()
			var L2 := L * rng.randf_range(0.3, 0.5) * (1.1 - t * 0.4)
			var sb := _curve(p0, d2, L2, 3, 0.06, rng, 0.2)
			if lod == 0 or k % 2 == 0:
				var r0: float = float(srad[ii]) * 0.6
				_tube(T, sb, [r0, r0 * 0.6, r0 * 0.35, r0 * 0.15], mini(4, sides0), H, cr, axis)
			for q in range(1, sb.size()): ends.append([sb[q], d2])
		for q in range(2, sc.size()): ends.append([sc[q], dir])
	# 잎 카드: 가지 끝 둘레에 흩고, 수관 껍질(타원체) 안쪽으로 묶는다
	var lv := PackedVector3Array(); var ln := PackedVector3Array(); var luv := PackedVector2Array(); var lc := PackedColorArray(); var lcu := PackedFloat32Array(); var li := PackedInt32Array()
	var nc: int = int(int(o.nc) * 1.5) if lod == 0 else int(int(o.nc) * 0.6)
	var cs: float = float(o.cs) * (1.12 if lod == 0 else 1.5)
	var ctr := Vector3(axis.x, cy, axis.y)
	var ry := (H - float(o.bole)) * 0.5 * 1.05
	var hang: bool = o.get("hang", false)
	var b2: bool = String(o.get("leaf", "oak")) == "broad2"
	var q2: int = int(o.get("q", 0))
	var crop: Array = o.get("crop", [0.0, 1.0])
	for c in nc:
		var e: Array = ends[rng.randi() % ends.size()]
		var p: Vector3 = (e[0] as Vector3) + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.8), rng.randf_range(-1, 1)) * cs * 0.6
		if rng.randf() < 0.4:
			# 수관 껍질을 고르게 메운다(가지 끝만 따라가면 수관 가운데·사이가 빈다) — 위쪽 반구에 더
			var dv := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.55, 1), rng.randf_range(-1, 1)).normalized()
			var rr := rng.randf_range(0.62, 1.0)
			p = ctr + Vector3(dv.x * cr, dv.y * ry, dv.z * cr) * rr
			e = [p, (dv + Vector3(0, 0.4, 0)).normalized()]
		# 수관 타원체 안으로 당김
		var rel := (p - ctr); var q := Vector3(rel.x / cr, rel.y / ry, rel.z / cr)
		if q.length() > 1.0: p = ctr + rel / q.length() * rng.randf_range(0.9, 1.0)
		var out := Vector3((p.x - ctr.x) / cr, (p.y - ctr.y) / ry * 0.8 + 0.35, (p.z - ctr.z) / cr).normalized()
		# 카드 위쪽(잎 끝 방향) = 가지 방향과 바깥쪽 사이, 카드 면은 그 축 둘레로 아무렇게나
		var upv := ((e[1] as Vector3) * 0.5 + out * 0.5 + Vector3(0, 0.3, 0)).normalized()
		if hang: p += Vector3(0, cs * 0.35, 0)   # 늘어진 가지는 가지 끝 위에서 시작(가지 끝이 수관 위로 삐죽 나오지 않게)
		if hang: upv = (Vector3(0, -1, 0) + out * Vector3(0.25, 0, 0.25) + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))).normalized()   # 버드나무: 늘어진 가지
		var side := upv.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
		if side.length() < 0.1: side = upv.cross(Vector3.RIGHT)
		side = side.normalized()
		var fn := side.cross(upv).normalized()
		var s := cs * rng.randf_range(0.8, 1.15)
		var cell := rng.randi() % 4
		var cw := 0.5 if not b2 else 0.25
		var u0 := float(cell % 2) * cw; var v0 := float(cell / 2) * cw
		if b2: u0 += float(q2 % 2) * 0.5; v0 += float(q2 / 2) * 0.5
		var ua := u0 + cw * float(crop[0]); var ub := u0 + cw * float(crop[1])
		var sw := s * (float(crop[1]) - float(crop[0]))
		# 카드 밑(잎자루 모임)은 칸 (0.5, 0.9) — 그 점이 p에 오게
		var b0 := p - upv * s * 0.1
		var corners := [b0 - side * sw * 0.5, b0 + side * sw * 0.5, b0 + side * sw * 0.5 + upv * s, b0 - side * sw * 0.5 + upv * s]
		var uvs := [Vector2(ua, v0 + cw * 0.92), Vector2(ub, v0 + cw * 0.92), Vector2(ub, v0), Vector2(ua, v0)]
		var ph := rng.randf()
		var base := lv.size()
		for k in 4:
			var cp: Vector3 = corners[k]
			lv.append(cp)
			var dd := Vector2(cp.x - axis.x, cp.z - axis.y)
			var radial := Vector3(dd.x / cr, (cp.y - cy) / ry * 0.7 + 0.3, dd.y / cr).normalized()
			var nn := fn if fn.dot(radial) >= 0.0 else -fn
			ln.append(nn.lerp(radial, 0.7).normalized())
			luv.append(uvs[k])
			var rn := clampf(Vector3(dd.x / cr, (cp.y - cy) / ry, dd.y / cr).length(), 0.0, 1.0)
			lc.append(Color(lerpf(0.55, 1.0, smoothstep(0.25, 0.95, rn)), ph, 1.0, 1.0))
			lcu.append_array([cp.y / H, clampf(dd.length() / cr, 0.0, 1.0), ph, 0.0 if k < 2 else 1.0])
		li.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var am := ArrayMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var barr := []; barr.resize(Mesh.ARRAY_MAX)
	barr[Mesh.ARRAY_VERTEX] = T.v; barr[Mesh.ARRAY_NORMAL] = T.n; barr[Mesh.ARRAY_TANGENT] = T.t; barr[Mesh.ARRAY_TEX_UV] = T.uv
	barr[Mesh.ARRAY_COLOR] = T.col; barr[Mesh.ARRAY_CUSTOM0] = T.cu; barr[Mesh.ARRAY_INDEX] = T.idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, barr, [], {}, flags)
	var larr := []; larr.resize(Mesh.ARRAY_MAX)
	larr[Mesh.ARRAY_VERTEX] = lv; larr[Mesh.ARRAY_NORMAL] = ln; larr[Mesh.ARRAY_TEX_UV] = luv; larr[Mesh.ARRAY_COLOR] = lc; larr[Mesh.ARRAY_CUSTOM0] = lcu; larr[Mesh.ARRAY_INDEX] = li
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, larr, [], {}, flags)
	am.surface_set_name(0, "bark"); am.surface_set_name(1, "leaf")
	var hh := 0.0
	for p in lv: hh = maxf(hh, p.y)
	return { mesh = am, tris = (T.idx.size() + li.size()) / 3, height = hh, crown_r = cr }

# ------------------------------------------------------------------ 임포스터 굽기(8방향 · 바탕색/법선)
func _bake_mats(fam: String, bark_fam: String, mode: float) -> Array:
	var out := []
	for part in ["bark", "leaf"]:
		var src: ShaderMaterial = load(OUT + "%s_%s.tres" % [bark_fam if part == "bark" else fam, part])
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/tree_bake.gdshader")
		for p in ["albedo_tex", "orm_tex", "leaf_tint", "leaf_sat", "leaf_bright", "leaf_var", "leaf_alpha", "bark_low", "bark_high", "bark_red", "bark_bright"]:
			var v = src.get_shader_parameter(p)
			if v != null: m.set_shader_parameter(p, v)
		m.set_shader_parameter("is_leaf", 1.0 if part == "leaf" else 0.0)
		m.set_shader_parameter("mode", mode)
		out.append(m)
	return out

func _stage_bake() -> void:
	var vp := SubViewport.new()
	vp.size = CELL
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	vp.add_child(mi)
	for v in meta.variants:
		var mesh: ArrayMesh = load(OUT + "%s_lod0.res" % v.name)
		mi.mesh = mesh
		var ab := mesh.get_aabb()
		var c := Vector2(ab.position.x + ab.size.x * 0.5, ab.position.z + ab.size.z * 0.5)
		var rad := 0.5
		for s in mesh.get_surface_count():
			for p in (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array): rad = maxf(rad, Vector2(p.x, p.z).distance_to(c))
		var ww := rad * 2.0 * 1.04
		var wh := maxf(ab.end.y * 1.03, ww * 2.0)
		cam.size = wh
		cam.near = 0.1; cam.far = rad * 8.0 + 80.0
		var albs := []; var nrms := []
		for mode in [0.0, 1.0]:
			var mats := _bake_mats(v.family, String(v.get("bark", v.family)), mode)
			for s in 2: mi.set_surface_override_material(s, mats[s])
			for i in 8:
				var a := i * PI / 4.0
				var d := Vector3(sin(a), 0.0, cos(a))
				var ctr := Vector3(c.x, wh * 0.5, c.y)
				cam.position = ctr + d * (rad * 3.0 + 30.0)
				cam.look_at(ctr, Vector3.UP)
				await process_frame
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				(albs if mode == 0.0 else nrms).append(img)
		for pair in [["alb", albs], ["nrm", nrms]]:
			var atlas := Image.create(CELL.x * 4, CELL.y * 2, false, Image.FORMAT_RGBA8)
			for i in 8:
				atlas.blit_rect(pair[1][i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 4) * CELL.x, (i / 4) * CELL.y))
			atlas.save_png(ProjectSettings.globalize_path(WORK + "imp_%02d_%s_%s.png" % [int(v.layer), v.name, pair[0]]))
		v.box = [c.x, c.y, ww, wh]
		print("TREES baked ", v.name, " box=", v.box)
	vp.queue_free()

func _stage_pack() -> void:
	var albs: Array[Image] = []; var nrms: Array[Image] = []
	var box := []
	for v in meta.variants:
		var base := WORK + "imp_%02d_%s_" % [int(v.layer), v.name]
		var a := _load_mip(base + "alb.mip"); a.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_SRGB); albs.append(a)
		var n := _load_mip(base + "nrm.mip"); n.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC); nrms.append(n)
		box.append(v.box)
	for pair in [["imp_alb", albs], ["imp_nrm", nrms]]:
		var t := Texture2DArray.new()
		t.create_from_images(pair[1])
		print("TREES pack ", pair[0], " layers=", pair[1].size(), " err=", ResourceSaver.save(t, OUT + pair[0] + ".res", ResourceSaver.FLAG_COMPRESS))
	var m := ShaderMaterial.new()
	var mp := OUT + "impostor.tres"
	if ResourceLoader.exists(mp): m = load(mp)
	m.shader = load("res://shaders/tree_impostor.gdshader")
	m.set_shader_parameter("imp_alb", load(OUT + "imp_alb.res"))
	m.set_shader_parameter("imp_nrm", load(OUT + "imp_nrm.res"))
	var arr := PackedVector4Array()
	for b in box: arr.append(Vector4(b[0], b[1], b[2], b[3]))
	while arr.size() < 24: arr.append(Vector4(0, 0, 1, 1))
	m.set_shader_parameter("imp_box", arr)
	print("TREES mat ", mp, " err=", ResourceSaver.save(m, mp))
