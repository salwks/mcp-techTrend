# 청계천(개천 開川) 석축 구간 모듈 — 태종 때 개천 공사, 영조 36년(1760) 경진준천으로 양안을 돌로 쌓음 → 1870년 돌 축대 개천.
# 로컬 x 방향 length m, 물길 너비 width(양 축대 사이), 축대 높이 height. 바닥은 모래·자갈, 가운데 얕은 물(water). 실제 너비 약 20~25m → 기본 16m(압축 가설).
# 원점 = 물길 가운데 바닥 높이(축대 위 = 땅 높이 height). params: seed, length(20), width(16), height(3.0), water(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const S = preload("res://kit/landmark/_seong.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 20.0)); var Wc: float = float(params.get("width", 16.0)); var H: float = float(params.get("height", 3.0))
	var b := Kit.Batch.new()
	# 바닥(모래·자갈)
	b.add("mud", Co.pnt(Kit.box(L, 0.2, Wc, 0, -0.1, 0), [0xa89c80, 0x8a7e64], 0.06, rng), 0.0)
	for k in roundi(L * Wc / 14.0):
		var g := Kit.lump(rng.between(0.12, 0.3), 0, rng, 0.3, 0.6); Kit.xf(g, rng.between(-L / 2, L / 2), 0.02, rng.between(-Wc / 2 + 0.5, Wc / 2 - 0.5))
		b.add("rock", Co.pnt(g, [0x9a958a, 0x7a756a], 0.08, rng), 0.0)
	# 양 축대(돌 쌓기, 약간 퇴물림) — 물 쪽 면만 면석
	for s in [-1, 1]:
		var zc: float = s * (Wc / 2 + 1.0)
		b.add("stone", Co.pnt(Kit.box(L, H + 0.3, 2.0, 0, (H - 0.3) / 2, zc), Co.SEONG, 0.03, rng), 0.03)
		var zf: float = s * (Wc / 2) - s * 0.02
		if s < 0: S.stone_face(b, rng, Vector2(-L / 2, zf), Vector2(L / 2, zf), 0.0, H, Vector2(0, 1), 0.15, 0.5)
		else: S.stone_face(b, rng, Vector2(L / 2, zf), Vector2(-L / 2, zf), 0.0, H, Vector2(0, -1), 0.15, 0.5)
		b.add("stone", Co.pnt(Kit.box(L, 0.18, 0.7, 0, H + 0.05, s * (Wc / 2 + 0.35)), [0xc2bcae, 0xa49e90], 0.04, rng), 0.015)
	var out := {
		node = null, colliders = [{ type = "box", minX = -L / 2, maxX = L / 2, minZ = -Wc / 2 - 2.0, maxZ = -Wc / 2 }, { type = "box", minX = -L / 2, maxX = L / 2, minZ = Wc / 2, maxZ = Wc / 2 + 2.0 }],
		lights = [], occluder = false, footprint = Vector2(L, Wc + 4.0), anchors = { bed = Vector3(0, 0, 0), bank_n = Vector3(0, H, -Wc / 2 - 2.5), bank_s = Vector3(0, H, Wc / 2 + 2.5) },
	}
	if params.get("water", true):
		var wy := 0.35
		var w := Kit.Geo.new()
		var ww := Wc * 0.55
		w.quad(Vector3(-L / 2, wy, ww / 2), Vector3(L / 2, wy, ww / 2), Vector3(L / 2, wy, -ww / 2), Vector3(-L / 2, wy, -ww / 2), Vector2(0, 0), Vector2(L / 4, 0), Vector2(L / 4, ww / 4), Vector2(0, ww / 4))
		b.add("water", Kit.paint(w, Kit.hex(0x7a9894), Kit.hex(0x7a9894), 0.0), 0.0)
		out.water = { y = wy, outline = PackedVector2Array([Vector2(-L / 2, -ww / 2), Vector2(L / 2, -ww / 2), Vector2(L / 2, ww / 2), Vector2(-L / 2, ww / 2)]), kind = "stream" }
	out.node = b.build("청계천석축")
	return out
