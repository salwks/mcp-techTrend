# 설화 장면 소품(남원 「해와 달이 된 오누이」 v3) — 하늘에서 내려오는 동아줄, 수수밭. 원점 = 바닥 중심(줄은 아래 끝).
# 이야기 총괄(story_director)의 소품(props)으로 세우거나, 사건 스크립트(namwon_case.gd)가 직접 build해 움직인다.
# params:
#   kind "rope"     동아줄. length(기본 60m), rotten(false: 새 줄 — 짚빛 꼰 줄, 밤에도 보이게 스스로 빛난다 / true: 썩은 줄 — 검누런 빛, 해진 올, 군데군데 가늘다)
#   kind "rope_end" 끊어진 썩은 줄 토막(범과 함께 떨어진다). length(기본 3m)
#   kind "step_stone" 쪽문 앞 디딤돌 · "oil_step" 디딤돌에 부은 참기름(번들거림 — B)
#   kind "sorghum"  수수밭. w·d(크기 m), rows(줄 수, 기본 5), row(-1이면 전부, 0..rows-1이면 그 줄만), red(true면 줄기가 붉게 물든 수수)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const STRAW_NEW := [0xe2c98a, 0xb8964e]
const STRAW_ROT := [0x6e5a3a, 0x4a3c26]
const STALK := [0x8aa04e, 0x5e7a34]
const STALK_RED := [0xb0302a, 0x6a1612]
const LEAF := [0x7f9848, 0x55702e]
const LEAF_RED := [0x9a3a2a, 0x5e1c14]
const HEAD := [0x9a4426, 0x5a2414]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 49)))
	var kind := String(params.get("kind", "rope"))
	var fp := Vector2(1.0, 1.0)
	match kind:
		"rope": _rope(m, float(params.get("length", 60.0)), bool(params.get("rotten", false)))
		"rope_end": _rope(m, float(params.get("length", 3.0)), true, true)
		"step_stone": _step(m, false)
		"oil_step": _step(m, true)
		"sorghum": fp = _sorghum(m, float(params.get("w", 5.0)), float(params.get("d", 5.0)), int(params.get("rows", 5)), int(params.get("row", -1)), bool(params.get("red", false)))
	return m.result("설화_" + kind, fp, false)

# 꼰 두 가닥(짧은 토막을 엇갈려 쌓는다). 새 줄은 lamp 재질로 스스로 빛나 밤하늘에서도 보인다
static func _rope(m: C.M, length: float, rotten: bool, frayed_end := false) -> void:
	var seg := 0.5
	var n := int(length / seg)
	var r := 0.075 if not rotten else 0.06
	var cols: Array = STRAW_ROT if rotten else STRAW_NEW
	for i in n:
		var y0 := i * seg
		var thin := rotten and (i % 7 == 3 or i % 11 == 5)
		for s in 2:
			var a := float(i) * 1.1 + PI * s
			var g := Kit.limb(Vector3(cos(a) * r * 0.6, y0, sin(a) * r * 0.6), Vector3(cos(a + 1.1) * r * 0.6, y0 + seg, sin(a + 1.1) * r * 0.6),
				r * (0.45 if thin else 0.85), r * (0.45 if thin else 0.85), 5)
			m.add("p", "organic" if rotten else "glow", C.PA(g, cols, 0.12, m.rng), 0.0)   # 새 줄은 스스로 빛난다(밤하늘에서 보이게)
		if rotten and i % 3 == 1:   # 해진 올
			var t := Kit.limb(Vector3(0, y0 + 0.2, 0), Vector3((m.r() - 0.5) * 0.3, y0 + 0.05, (m.r() - 0.5) * 0.3), 0.008, 0.004, 3)
			m.add("p", "organic", C.PA(t, cols, 0.1, m.rng), 0.0)
	if frayed_end:   # 끊어진 끝 — 올이 풀려 벌어진다
		for k in 6:
			var a := k * TAU / 6.0
			var t := Kit.limb(Vector3(0, length, 0), Vector3(cos(a) * 0.12, length + 0.18 + m.r() * 0.1, sin(a) * 0.12), 0.012, 0.004, 3)
			m.add("p", "organic", C.PA(t, cols, 0.1, m.rng), 0.0)

static func _step(m: C.M, oil: bool) -> void:
	if not oil:
		m.add("p", "rock", C.PA(Kit.xf(Kit.lump(0.42, 1, m.rng, 0.15, 0.32), 0, 0.08, 0), C.STONE, 0.06, m.rng), 0.02)
		return
	m.add("p", "smooth", C.P(Kit.cyl(0.5, 0.5, 0.012, 12, 0.05, 0.19, 0.0), 0x7a5a20, 0x5a3e14, 0.02), 0)
	m.add("p", "glow", C.P(Kit.xf(Kit.box(0.5, 0.006, 0.05), 0.0, 0.2, 0.08, 0, 0.4, 0), 0xf0d27a, 0xc8a24a), 0)   # 번들거리는 빛줄
	m.add("p", "smooth", C.P(Kit.cyl(0.35, 0.35, 0.01, 10, 0.3, 0.012, 0.45), 0x7a5a20, 0x5a3e14, 0.02), 0)        # 흘러내린 기름

# 수수밭: 줄(z 방향)마다 수숫대. 같은 자리·같은 모양을 붉은 판에서도 그대로 쓴다(줄 단위로 바꿔 끼워 번지게)
static func _sorghum(m: C.M, w: float, d: float, rows: int, only_row: int, red: bool) -> Vector2:
	var per := int(maxf(3.0, w / 0.55))
	for ri in rows:
		if only_row >= 0 and ri != only_row: continue
		var z := -d * 0.5 + d * (ri + 0.5) / rows
		for k in per:
			var R := Kit.Rng.new(4900 + ri * 97 + k * 13)
			var x := -w * 0.5 + w * (k + 0.5) / per + (R.next() - 0.5) * 0.25
			var zz := z + (R.next() - 0.5) * 0.3
			var h := 1.9 + R.next() * 0.6
			var lean := (R.next() - 0.5) * 0.12
			var top := Vector3(x + lean * h, h, zz + lean * 0.5 * h)
			m.add("p", "organic", C.PA(Kit.limb(Vector3(x, 0, zz), top, 0.034, 0.022, 5), STALK_RED if red else STALK, 0.08, R), 0.0)
			var nl := 2 + (1 if R.next() > 0.55 else 0)   # 잎 2~3장 — 줄기에서 비스듬히 솟았다가 끝이 처지는 넓은 잎
			for l in nl:
				var ly := 0.45 + l * (1.1 / nl) + R.next() * 0.15
				var base := Vector3(x + lean * ly, ly, zz + lean * 0.5 * ly)
				var lg := _blade(0.72 + R.next() * 0.2, 0.11, R)
				Kit.xf(lg, base.x, base.y, base.z, 0.5 + R.next() * 0.4, float(l) * PI + (R.next() - 0.5) * 1.4, 0)
				m.add("p", "leaf", C.PA(lg, LEAF_RED if red else LEAF, 0.08, R), 0.0)
			# 고개 숙인 이삭 — 줄기 끝이 한쪽으로 휘어 넘어가고, 그 끝에 낟알 덩이가 아래로 늘어진다
			var ha := R.next() * TAU
			var hd := Vector3(cos(ha), 0, sin(ha))
			var n1 := top + hd * 0.07 + Vector3(0, 0.13, 0)
			var n2 := top + hd * 0.19 + Vector3(0, 0.1, 0)
			m.add("p", "organic", C.PA(Kit.limb(top, n1, 0.022, 0.018, 5), STALK_RED if red else STALK, 0.08, R), 0.0)
			m.add("p", "organic", C.PA(Kit.limb(n1, n2, 0.018, 0.015, 5), STALK_RED if red else STALK, 0.08, R), 0.0)
			for j in 7:   # 낟알 덩이: 위가 굵고 아래로 가늘게, 조금씩 바깥으로
				var r := 0.09 - j * 0.009
				var c := n2 + hd * (0.03 + 0.025 * j) + Vector3((R.next() - 0.5) * 0.05, -0.02 - 0.075 * j, (R.next() - 0.5) * 0.05)
				m.add("p", "organic", C.PA(Kit.xf(Kit.lump(r, 0, R, 0.4, 1.25), c.x, c.y, c.z, 0, R.next() * TAU, 0), HEAD, 0.12, R), 0.0)
	return Vector2(w, d)

# 수수 잎 한 장(밑동 = 원점, +x로 뻗음): 네 토막이 비스듬히 솟았다가 끝으로 갈수록 처지고 가늘어진다. 두께 있는 판이라 먹선이 둘러진다
static func _blade(length: float, width: float, R: Kit.Rng) -> Kit.Geo:
	var segs := []
	var p := Vector2.ZERO
	var n := 4
	var droop := 0.5 + R.next() * 0.2
	for i in n:
		var th := 0.75 - i * droop
		var L := length / n
		var dir := Vector2(cos(th), sin(th))
		var c := p + dir * L * 0.5
		var seg := Kit.box(L * 1.08, 0.014, width * (1.0 - i * 0.2), 0, 0, 0)
		segs.append(Kit.xf(seg, c.x, c.y, 0, 0, 0, th))
		p += dir * L
	return Kit.merge(segs)
