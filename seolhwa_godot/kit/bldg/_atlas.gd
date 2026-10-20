# 건물 빌더 아틀라스 칸 — Kit 아틀라스(assets/kit/atlas.png)의 빈 자리에 tools/bldg/make_atlas.gd가 그린 무늬.
# Kit.KEY_REG(scripts/kit/kit.gd)를 고치지 않으려고(고치면 모든 키트 캐시 키가 바뀐다) UV 옮기기를 여기서 직접 한다.
# 같은 공용 재질(Kit.material("atlas")) 하나에 들어간다 — 건물마다 따로 재질을 만들지 않는다.
extends RefCounted

# 칸 자리 [x0, y0, x1, y1] (픽셀, 1024×512)
const REG := {
	ddi = [0, 384, 64, 512], yong = [64, 384, 128, 512], a = [128, 384, 192, 512], gyo = [192, 384, 256, 512],
	kkot = [256, 384, 320, 512], maru = [320, 384, 448, 512], jangpan = [448, 384, 576, 512], panbyeok = [576, 384, 704, 512],
	yongmareum = [704, 384, 832, 512], giwa = [832, 384, 960, 512], dancheong = [768, 256, 896, 384], soffit = [896, 256, 1024, 384],
}
# 면 법선(각진 음영)으로 둘 칸
const FACETED := ["ddi", "yong", "a", "gyo", "kkot", "maru", "jangpan", "panbyeok", "giwa", "dancheong", "soffit"]

# m(C.M)에 빌더 칸 재질로 조각을 더한다. key가 REG에 없으면 Kit 기본 키로(M.add와 같음)
static func add(m, part: String, key: String, g: Kit.Geo, outline := 0.0) -> void:
	if g.size() == 0: return
	if not REG.has(key):
		m.add(part, key, g, outline); return
	if m.xform != Transform3D.IDENTITY: Kit.apply(g, m.xform)
	var p: String = "all" if m.merge_parts else part
	if not m.parts.has(p):
		m.parts[p] = Kit.Batch.new(); m.order.append(p)
	var b: Kit.Batch = m.parts[p]
	if key in FACETED: Kit.face_normals(g)
	else: Kit.smooth_normals(g)
	remap_reg(g, REG[key])
	if not b.parts.has("atlas"): b.parts["atlas"] = []
	b.parts["atlas"].append(g)
	b.tris += g.size() / 3
	if outline > 0.0:
		var h := Kit.hull(g, outline * Kit.OUTLINE_SCALE)
		b.parts["atlas"].append(h)
		b.tris += h.size() / 3

# Kit.remap_uv와 같은 규칙(긴 면은 영역 안에서 반복), 영역만 직접 받는다
static func remap_reg(g: Kit.Geo, r: Array) -> void:
	var inset := 2.0
	var u0: float = (r[0] + inset) / Kit.ATLAS_W; var u1: float = (r[2] - inset) / Kit.ATLAS_W
	var v_top: float = (r[1] + inset) / Kit.ATLAS_H; var v_bot: float = (r[3] - inset) / Kit.ATLAS_H
	g.rect.resize(g.uv.size() * 4)
	var tu: float = (r[2] - r[0]) / 128.0 * Kit.TILE_M; var tv: float = (r[3] - r[1]) / 128.0 * Kit.TILE_M
	for t in range(0, g.uv.size() - 2, 3):
		var l := [Vector2(clampf(g.uv[t].x, 0, 1), 1.0 - clampf(g.uv[t].y, 0, 1)), Vector2(clampf(g.uv[t + 1].x, 0, 1), 1.0 - clampf(g.uv[t + 1].y, 0, 1)), Vector2(clampf(g.uv[t + 2].x, 0, 1), 1.0 - clampf(g.uv[t + 2].y, 0, 1))]
		var e1: Vector3 = g.pos[t + 1] - g.pos[t]; var e2: Vector3 = g.pos[t + 2] - g.pos[t]
		var d1: Vector2 = l[1] - l[0]; var d2: Vector2 = l[2] - l[0]
		var det := d1.x * d2.y - d2.x * d1.y
		var nu := 1.0; var nv := 1.0
		if absf(det) > 1e-8:
			var T := (e1 * d2.y - e2 * d1.y) / det; var B := (e2 * d1.x - e1 * d2.x) / det
			nu = maxf(1.0, roundf(T.length() / tu)); nv = maxf(1.0, roundf(B.length() / tv))
		for k in 3:
			var i := t + k
			var q: Vector2 = l[k]
			if nu <= 1.0 and nv <= 1.0:
				g.uv[i] = Vector2(u0 + (u1 - u0) * q.x, v_top + (v_bot - v_top) * q.y)
				g.rect[i * 4] = 0.0; g.rect[i * 4 + 1] = 0.0; g.rect[i * 4 + 2] = 0.0; g.rect[i * 4 + 3] = 0.0
			else:
				g.uv[i] = Vector2(0.0005 + q.x * (nu - 0.001), 0.0005 + q.y * (nv - 0.001))
				g.rect[i * 4] = u0; g.rect[i * 4 + 1] = v_top; g.rect[i * 4 + 2] = u1; g.rect[i * 4 + 3] = v_bot

# 세운 판(xy 평면, +z를 봄) UV 0..1 — 창호·판벽
static func panel(w: float, h: float, x := 0.0, y := 0.0, z := 0.0, ry := 0.0) -> Kit.Geo:
	var g := Kit.Geo.new()
	var hw := w / 2; var hh := h / 2
	g.quad(Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0), Vector3(hw, hh, 0), Vector3(-hw, hh, 0))
	return Kit.xf(g, x, y, z, 0, ry)

# 누운 판(위를 봄) UV 0..1 — 장판·마루
static func floor_quad(w: float, d: float, x := 0.0, y := 0.0, z := 0.0) -> Kit.Geo:
	var g := Kit.Geo.new()
	var hw := w / 2; var hd := d / 2
	g.quad(Vector3(x - hw, y, z + hd), Vector3(x + hw, y, z + hd), Vector3(x + hw, y, z - hd), Vector3(x - hw, y, z - hd))
	return g

# 반복 칸(rect 모드): g.uv = 그림 좌표(1 = 칸 한 장, x 오른쪽·y 아래, 1을 넘으면 되풀이). 지붕 기와골·막새·이엉처럼
# 여러 조각에 걸쳐 무늬가 이어져야 하는 면. key는 빌더 칸 또는 Kit 키(thatch·makse·wood·stone·mud…)
static func add_tiled(m, part: String, key: String, g: Kit.Geo, outline := 0.0) -> void:
	if g.size() == 0: return
	var r: Array = REG[key] if REG.has(key) else Kit.REG[Kit.KEY_REG.get(key, "white")]
	if m.xform != Transform3D.IDENTITY: Kit.apply(g, m.xform)
	var p: String = "all" if m.merge_parts else part
	if not m.parts.has(p):
		m.parts[p] = Kit.Batch.new(); m.order.append(p)
	var b: Kit.Batch = m.parts[p]
	if key in FACETED or key in Kit.FACETED: Kit.face_normals(g)
	else: Kit.smooth_normals(g)
	var inset := 2.0
	var u0: float = (r[0] + inset) / Kit.ATLAS_W; var u1: float = (r[2] - inset) / Kit.ATLAS_W
	var v0: float = (r[1] + inset) / Kit.ATLAS_H; var v1: float = (r[3] - inset) / Kit.ATLAS_H
	g.rect.resize(g.uv.size() * 4)
	for i in g.uv.size():
		g.rect[i * 4] = u0; g.rect[i * 4 + 1] = v0; g.rect[i * 4 + 2] = u1; g.rect[i * 4 + 3] = v1
	if not b.parts.has("atlas"): b.parts["atlas"] = []
	b.parts["atlas"].append(g)
	b.tris += g.size() / 3
	if outline > 0.0:
		var h := Kit.hull(g, outline * Kit.OUTLINE_SCALE)
		b.parts["atlas"].append(h)
		b.tris += h.size() / 3
