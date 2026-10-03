# 반월성(半月城, 월성) 터 — 신라 왕성 터. 1870년에는 성벽·건물 없이 반달 모양 흙 둔덕(토성)과 그 위 평평한 들, 남쪽은 남천.
# 실제 동서 약 860m·남북 약 250m → 게임 압축(K≈0.3) 근사로 동서 240m·남북 80m 반달 대지, 둘레 비탈 높이 6m(가설).
# 북쪽 안에 석빙고(1741 이전)를 둔다(seokbinggo=true). 원점 = 대지 가운데 바닥, 남(+z)이 오목한 쪽(남천).
# params: seed, length(240), width(80), height(6), seokbinggo(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const SB = preload("res://kit/landmark/gj_seokbinggo.gd")

static func outline(L: float, Wd: float, inset: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var n := 24
	var a := L / 2 - inset; var bn := Wd * 0.75 - inset; var bs := Wd * 0.25 - inset * 0.6
	for i in n + 1:
		var t := PI * i / n
		p.append(Vector2(-cos(t) * a, -sin(t) * bn))   # 북쪽 볼록
	for i in range(1, n):
		var t := PI * i / n
		p.append(Vector2(cos(t) * a, bs - sin(t) * Wd * 0.12))  # 남쪽 살짝 오목(남천 쪽)
	return p

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 240.0)); var Wd: float = float(params.get("width", 80.0)); var H: float = float(params.get("height", 6.0))
	var b := Kit.Batch.new()
	var lo := outline(L, Wd, 0.0); var hi := outline(L, Wd, H * 2.2)
	var g := Kit.Geo.new()
	var n := lo.size()
	for i in n:
		var j := (i + 1) % n
		var a0 := Vector3(lo[i].x, -0.5, lo[i].y); var a1 := Vector3(lo[j].x, -0.5, lo[j].y)
		var b0 := Vector3(hi[i].x, H, hi[i].y); var b1 := Vector3(hi[j].x, H, hi[j].y)
		var mid := (lo[i] + lo[j]) / 2
		var out := Vector3(mid.x, 0, mid.y).normalized()
		var e := (lo[j] - lo[i])
		out = Vector3(e.y, 0, -e.x).normalized()
		# 비탈(가운데 볼록하게 두 줄)
		var m0 := (a0 + b0) / 2 + out * 0.8; var m1 := (a1 + b1) / 2 + out * 0.8
		Co.Roof.quad_facing(g, a0, a1, m1, m0, out + Vector3(0, 0.5, 0))
		Co.Roof.quad_facing(g, m0, m1, b1, b0, out + Vector3(0, 1, 0))
	var idx := Geometry2D.triangulate_polygon(hi)
	for k in range(0, idx.size(), 3):
		var A := hi[idx[k]]; var B := hi[idx[k + 1]]; var C := hi[idx[k + 2]]
		Co.Roof.tri_facing(g, Vector3(A.x, H, A.y), Vector3(B.x, H, B.y), Vector3(C.x, H, C.y), Vector3.UP)
	var ga := Kit.paint(g, Kit.hex(0x9aa462), Kit.hex(0x7e7a52), 0.05, rng)
	b.add("organic", ga, 0.04)
	# 비탈에 드러난 흙·돌(토성 흔적) 몇 군데
	for k in 14:
		var i := rng.next() * (n - 1)
		var p := lo[int(i)].lerp(hi[int(i)], 0.5)
		var rr := Kit.lump(rng.between(0.6, 1.4), 0, rng, 0.3, 0.6)
		Kit.xf(rr, p.x, H * 0.5, p.y)
		b.add("rock", Co.pnt(rr, Hub.EARTH, 0.08, rng), 0.02)
	var root := Node3D.new(); root.name = "반월성터"
	root.add_child(b.build("둔덕"))
	var cols := []
	var lights := []
	var anchors := { top = Vector3(0, H, -Wd * 0.2), south_foot = Vector3(0, 0, Wd * 0.3 + 4.0) }
	if params.get("seokbinggo", true):
		var sb := SB.build({ seed = int(params.get("seed", 1)) + 3 })
		var sn: Node3D = sb.node
		sn.position = Vector3(-L * 0.22, H, -Wd * 0.3)
		root.add_child(sn)
		anchors.seokbinggo = sn.position + (sb.anchors.entrance as Vector3)
	# 둔덕 자체는 지형(배치 flatten 대신 이 메시) — 충돌은 비탈 아래 테두리 대신 열어 둠(걸어 올라갈 수 있게, 지형 엔진이 걷기 높이 처리)
	return {
		node = root, colliders = cols, lights = lights, occluder = false, footprint = Vector2(L, Wd),
		anchors = anchors, walk_top = { y = H, outline = hi },
	}
