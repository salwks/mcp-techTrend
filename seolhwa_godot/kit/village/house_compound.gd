# 집 한 채(집 묶음 프리셋) — 안채·사랑채·헛간 등을 마당 둘레로 묶고 담·문을 두른다. 마당 가운데가 원점, 대문이 +z(남).
# size:
#   "small"  초가 3칸 안채 + 헛간 + 뒷간 + 작은 장독대 + 장작 + 싸리울 + 사립문            (가난한 소작농·산간 화전민 집)
#   "medium" 초가 안채(넓게) + 초가 사랑채 + 외양간 + 헛간 + 장독대 + 뒷간 + 이엉 토담 + 초가 대문  (자작농·중농)
#   "large"  기와 안채 + 기와 사랑채 + 곳간(헛간) + 장독대 + 뒷간 + 기와 토담 + 솟을대문       (향반·이서층 기와집, 남원 읍내)
# 고증: 남부 민가는 一자형 안채가 남향하고, 사랑채·헛간·외양간이 마당 둘레에 따로 선다(트인 ㅁ자·튼 ㄷ자). 장독대는 부엌(안채
#   오른쪽) 뒤편, 뒷간은 마당 구석·대문 가까이. 기와 안채에 단청은 쓰지 않는다(plain) — 단청은 관아·사찰·정자.
# 성능: 묶음은 '큰 건물' 예산(≤ 15,000) — 건물 지붕 격자를 줄이고 울타리는 lite 판.
# params: seed, size("small"|"medium"|"large")
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CH := preload("res://kit/village/choga.gd")
const GW := preload("res://kit/village/giwa.gd")
const HG := preload("res://kit/village/heotgan.gd")
const OY := preload("res://kit/village/oeyanggan.gd")
const DG := preload("res://kit/village/dwitgan.gd")
const JD := preload("res://kit/village/jangdok.gd")
const FW := preload("res://kit/village/firewood.gd")
const FE := preload("res://kit/village/fence.gd")
const TD := preload("res://kit/village/todam.gd")
const DM := preload("res://kit/village/daemun.gd")
const SR := preload("res://kit/village/saripmun.gd")

const E := -PI / 2   # 서쪽을 보게(오른쪽 건물)
const Wf := PI / 2   # 동쪽을 보게(왼쪽 건물)

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var size: String = params.get("size", "small")
	var fp := Vector2.ZERO
	match size:
		"medium": fp = medium(m)
		"large": fp = large(m)
		_: fp = small(m)
	var res := m.result("집_" + size, fp)
	res.yard = { minX = -fp.x / 2 + 1.0, maxX = fp.x / 2 - 1.0, minZ = -fp.y / 2 + 1.0, maxZ = fp.y / 2 - 1.0 }
	return res

static func place(m: C.M, prefix: String, x: float, z: float, ry: float) -> Transform3D:
	m.prefix = prefix
	return m.push(x, 0, z, ry)

static func done(m: C.M, old: Transform3D) -> void:
	m.pop(old); m.prefix = ""

# 둘레 담: x0..x1, z0..z1, 남쪽 가운데 문 자리 반폭 gh. kind: "fence"|"todam_thatch"|"todam_tile"
static func enclose(m: C.M, x0: float, x1: float, z0: float, z1: float, gh: float, kind: String) -> void:
	var segs := [[x0, z0, x1, z0], [x0, z0, x0, z1], [x1, z0, x1, z1], [x0, z1, -gh, z1], [gh, z1, x1, z1]]
	for sgm in segs:
		match kind:
			"fence": FE.draw(m, sgm[0], sgm[1], sgm[2], sgm[3], 1.15, true)
			"todam_thatch": TD.draw(m, sgm[0], sgm[1], sgm[2], sgm[3], 1.5, "thatch")
			"todam_tile": TD.draw(m, sgm[0], sgm[1], sgm[2], sgm[3], 1.6, "tile", 0.5)

static func small(m: C.M) -> Vector2:
	var X := 7.0; var Z0 := -6.5; var Z1 := 6.5
	var old := place(m, "anchae_", 0, -2.6, 0)
	CH.draw(m, { w = 6.0, d = 4.0, hump = (m.r() - 0.5) * 0.3, gourd = m.r() < 0.5 })
	done(m, old)
	old = place(m, "heotgan_", 5.2, 1.6, E)
	HG.draw(m, 3.2, 2.4, "three")
	done(m, old)
	old = place(m, "dwitgan_", -5.6, 4.9, Wf)
	DG.draw(m, 1.4)
	done(m, old)
	old = place(m, "jangdok_", 4.6, -4.7, 0)
	JD.draw(m, { w = 2.4, d = 1.8, n = [2, 2, 1] })
	done(m, old)
	old = place(m, "firewood_", -4.7, -2.8, Wf)
	FW.row(m, 2.4, 4)
	done(m, old)
	enclose(m, -X, X, Z0, Z1, 0.75, "fence")
	old = place(m, "gate_", 0, Z1, 0)
	SR.draw(m, 1.4, true)
	done(m, old)
	m.anchor("yard", Vector3(0, 0, 2.6))
	return Vector2(X * 2 + 0.6, Z1 - Z0 + 1.0)

static func medium(m: C.M) -> Vector2:
	var X := 9.6; var Z0 := -8.2; var Z1 := 7.6
	var old := place(m, "anchae_", 0, -3.8, 0)
	CH.draw(m, { w = 7.2, d = 4.4, hump = (m.r() - 0.5) * 0.3, gourd = m.r() < 0.5 })
	done(m, old)
	old = place(m, "sarang_", -6.3, 1.8, Wf)
	CH.draw(m, { w = 5.4, d = 3.6, hump = (m.r() - 0.5) * 0.3 })
	done(m, old)
	old = place(m, "oeyang_", 7.0, 3.6, E)
	OY.draw(m, 3.4, 2.8)
	done(m, old)
	old = place(m, "heotgan_", 7.0, -1.4, E)
	HG.draw(m, 3.4, 2.6, "three")
	done(m, old)
	old = place(m, "jangdok_", 5.9, -6.6, 0)
	JD.draw(m, { w = 3.0, d = 2.0 })
	done(m, old)
	old = place(m, "dwitgan_", -8.3, -6.8, Wf)
	DG.draw(m, 1.4)
	done(m, old)
	old = place(m, "firewood_", -4.9, -4.5, Wf)
	FW.row(m, 2.4, 4)
	done(m, old)
	enclose(m, -X, X, Z0, Z1, 1.25, "todam_thatch")
	old = place(m, "gate_", 0, Z1, 0)
	DM.draw(m, "thatch", true, false)
	done(m, old)
	m.anchor("yard", Vector3(0, 0, 3.0))
	return Vector2(X * 2 + 0.8, Z1 - Z0 + 1.6)

static func large(m: C.M) -> Vector2:
	var X := 12.0; var Z0 := -10.0; var Z1 := 9.2
	var old := place(m, "anchae_", 0, -4.9, 0)
	GW.draw(m, { w = 9.0, d = 5.4, plain = true, roof_nx = 18, roof_nz = 9 })
	done(m, old)
	old = place(m, "sarang_", -7.4, 2.6, Wf)
	GW.draw(m, { w = 6.6, d = 4.2, bays = 3, plain = true, roof_nx = 14, roof_nz = 7 })
	done(m, old)
	old = place(m, "gotgan_", 8.6, 1.8, E)
	HG.draw(m, 4.4, 2.8, "three")
	done(m, old)
	old = place(m, "jangdok_", 7.4, -7.4, 0)
	JD.draw(m, { w = 3.0, d = 2.2, n = [3, 2, 1] })
	done(m, old)
	old = place(m, "dwitgan_", 10.6, 7.4, E)
	DG.draw(m, 1.5)
	done(m, old)
	enclose(m, -X, X, Z0, Z1, 3.3, "todam_tile")
	old = place(m, "gate_", 0, Z1 + 0.6, 0)
	DM.draw(m, "soseul", true, true)
	done(m, old)
	m.anchor("yard", Vector3(0, 0, 3.4))
	return Vector2(X * 2 + 0.8, Z1 - Z0 + 2.6)
