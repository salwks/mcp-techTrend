# 뗏목 — 강원 산판에서 벤 통나무를 칡·새끼로 엮어 남한강·북한강을 타고 한양(마포·뚝섬)까지 흘려보내던 뗏목(1865~ 경복궁 중건 때 성행 — 동시대).
# 통나무 한 줄(앞 떼·뒤 떼 두 동) + 가로 멍에 + 뗏사공 삿대·앞 노(그레) + 뒤 떼 위 작은 거적 움막.
# 원점 = 물 면(y=0) 가운데, 앞 = +z. params: seed, len(12.0), logs(9)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = float(params.get("len", 12.0)); var N: int = int(params.get("logs", 9))
	var R := m.rng
	var r0 := 0.17; var Wd := N * r0 * 2.0
	# 앞·뒤 두 동(사이를 조금 띄움)
	for part in 2:
		var z0 := -L / 2 + part * (L * 0.52); var pl := L * 0.48
		for i in N:
			var x := -Wd / 2 + r0 + i * r0 * 2.0
			var rr := r0 * R.between(0.85, 1.1)
			var ll := pl * R.between(0.92, 1.0)
			m.add("p", "wood", C.P(Kit.xf(Kit.cyl(rr, rr * 0.92, ll, 6), x, 0.04, z0 + pl / 2, PI / 2, 0, 0), 0x8a6a48, 0x5e4630, 0.06, R), 0.012)
		for k in 2:
			m.add("p", "wood", C.PA(Kit.box(Wd + 0.2, 0.09, 0.14, 0, 0.22, z0 + pl * (0.18 + 0.64 * k)), C.WOOD), 0.01)
	# 뒤 떼 위 거적 움막(뗏사공 잠자리)
	var hz := -L * 0.3
	var tt := Kit.Geo.new()
	var hw := Wd * 0.28; var hh := 0.9
	for k in 4:
		var a0 := PI * k / 4.0; var a1 := PI * (k + 1) / 4.0
		var p0 := Vector3(cos(a0) * hw, 0.22 + sin(a0) * hh, 0); var p1 := Vector3(cos(a1) * hw, 0.22 + sin(a1) * hh, 0)
		tt.quad(p0 + Vector3(0, 0, hz - 0.9), p1 + Vector3(0, 0, hz - 0.9), p1 + Vector3(0, 0, hz + 0.9), p0 + Vector3(0, 0, hz + 0.9))
	m.add("p", "thatch", C.PA(tt, C.STRAW, 0.05, R), 0.025)
	# 앞 그레(노) + 삿대
	m.add("p", "wood", C.P(C.beam(Vector3(0, 0.3, L / 2 - 0.4), Vector3(0, 0.1, L / 2 + 2.2), 0.08, 0.06), 0x8a6e50), 0.008)
	m.add("p", "wood", C.P(C.beam(Vector3(0, 0.25, L / 2 + 2.0), Vector3(0, 0.05, L / 2 + 2.6), 0.4, 0.04), 0x7a5e40), 0.006)
	m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.035, 0.035, 4.6, 5), Wd * 0.3, 1.9, -L * 0.05, 0.25, 0, 0.1), 0x9a8466), 0.008)
	m.anchor("raftsman", Vector3(0, 0.25, L / 2 - 1.0))
	return m.result("뗏목", Vector2(Wd + 0.3, L + 2.6), false)
