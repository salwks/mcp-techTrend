# 폐가 마당(묶음 ruin이 놓는 조각): 마당 전체 풀(단계만큼 높고 빽빽 — 쑥대·망초·마른 풀) · 덤불(단계 2~, 원 충돌) ·
#   깨진 독·쓰러진 장작·헌 빗자루(도깨비 이야기 소품 — 일부러 하나) · 대문 앞 짐승 길(풀 덜 남). 한 메시.
#   params: { seed, stage 0~4, w, d(마당 크기) }
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const RU := preload("res://kit/bldg/_ruin.gd")

static func build(params: Dictionary) -> Dictionary:
	var st := float(params.get("stage", 1.0))
	var W := float(params.get("w", 10.0)); var Dd := float(params.get("d", 8.0))
	var m := C.M.new(int(params.get("seed", 1)))
	var og := clampf(0.25 + 0.2 * st, 0.0, 1.0)
	var pts := []
	var n := int(W * Dd / 4.0 * og)
	for k in n:
		var p := Vector2((m.r() - 0.5) * W, (m.r() - 0.5) * Dd)
		if absf(p.x) < 0.7 and p.y > Dd / 2 - 3.0 and st < 3.0: continue   # 대문 앞 짐승 길
		pts.append(p)
	RU.grass(m, "p", pts, 0.0, og, st)
	if st >= 1.75:
		for k in int(st * 1.5):
			RU.shrub(m, "p", (m.r() - 0.5) * W * 0.85, (m.r() - 0.5) * Dd * 0.85, 0.0, 0.8 + m.r() * 0.6 * st / 2.0)
	# 잔해: 깨진 독(반쪽) · 쓰러진 장작 · 헌 빗자루
	for k in 1 + int(st):
		var g := Kit.cyl(0.22, 0.3, 0.5, 8, 0, 0, 0)
		Kit.xf(g, (m.r() - 0.5) * W * 0.8, 0.22, (m.r() - 0.5) * Dd * 0.8, PI / 2 * (1.0 if m.r() < 0.6 else 0.0), m.r() * 3, 0)
		m.add("p", "onggi", C.P(g, 0x6a4a34, 0x4a3426, 0.06, m.rng), 0.012)
	var bx := (m.r() - 0.5) * W * 0.6; var bz := (m.r() - 0.5) * Dd * 0.6
	var broom := Kit.merge([Kit.box(0.04, 0.04, 1.1, 0, 0, 0), Kit.xf(Kit.cyl(0.0, 0.16, 0.4, 6, 0, 0, 0, PI / 2, 0, 0), 0, 0, 0.7)])
	Kit.xf(broom, bx, 0.05, bz, 0.05, m.r() * 3, 0)
	m.add("p", "wood", C.P(broom, 0x8a7450, 0x5a4a34, 0.05), 0.008)
	m.anchor("broom_old", Vector3(bx, 0, bz))
	return m.result("폐가 마당", Vector2(W, Dd), false)
