# 시간대 팔레트 — 웹 fx/timeofday.js 이식(키프레임 보간). 색은 sRGB hex로 적고 선형으로 바꿔 쓴다.
class_name TimeOfDay
extends RefCounted

const RAW := [
	{ h = 0.0, skyTop = 0x0b1230, skyHor = 0x27365e, low = 0x1f2c4c, fog = 0x1d2946, dens = 0.017,
		sun = 0x8fa8e0, sunI = 0.95, hemiS = 0x4a5f96, hemiG = 0x151a26, hemiI = 1.05, glow = 0x3a4a7a, glowI = 0.15,
		lift = [0.035, 0.045, 0.085], gamma = [1.16, 1.16, 1.1], gain = [0.9, 0.97, 1.12], sat = 0.72, bloom = 0.45, thr = 0.8, night = 1.0, dayMix = 0.0 },
	{ h = 4.4, skyTop = 0x0d1534, skyHor = 0x2b3a62, low = 0x223050, fog = 0x202c4a, dens = 0.018,
		sun = 0x8fa8e0, sunI = 0.9, hemiS = 0x4a5f96, hemiG = 0x151a26, hemiI = 1.0, glow = 0x3a4a7a, glowI = 0.15,
		lift = [0.035, 0.045, 0.085], gamma = [1.16, 1.16, 1.1], gain = [0.9, 0.97, 1.12], sat = 0.72, bloom = 0.45, thr = 0.8, night = 1.0, dayMix = 0.0 },
	{ h = 5.6, skyTop = 0x4a5684, skyHor = 0xd9b7ae, low = 0xb4b4c8, fog = 0xb0b2c6, dens = 0.022,
		sun = 0xf6c0a8, sunI = 1.5, hemiS = 0xa0a8cc, hemiG = 0x55525c, hemiI = 1.25, glow = 0xf2a88e, glowI = 0.55,
		lift = [0.035, 0.035, 0.06], gamma = [1.06, 1.05, 1.03], gain = [0.99, 0.97, 1.0], sat = 0.78, bloom = 0.35, thr = 0.8, night = 0.35, dayMix = 0.6 },
	{ h = 7.0, skyTop = 0x7e9cc0, skyHor = 0xeed8c6, low = 0xd2ccd0, fog = 0xd2cacb, dens = 0.016,
		sun = 0xffd6b0, sunI = 2.5, hemiS = 0xb0bcdc, hemiG = 0x6e6258, hemiI = 1.15, glow = 0xf6c09a, glowI = 0.35,
		lift = [0.02, 0.02, 0.035], gamma = [1.04, 1.03, 1.02], gain = [1.03, 1.0, 0.98], sat = 0.88, bloom = 0.2, thr = 0.88, night = 0.0, dayMix = 1.0 },
	{ h = 9.0, skyTop = 0x84a9c6, skyHor = 0xe9e4cf, low = 0xd5d8cc, fog = 0xd0d5cb, dens = 0.0085,
		sun = 0xfff6ea, sunI = 3.1, hemiS = 0xb8cce6, hemiG = 0x86785a, hemiI = 1.2, glow = 0xfff0d0, glowI = 0.1,
		lift = [0.012, 0.012, 0.02], gamma = [1.02, 1.02, 1.0], gain = [1.03, 1.02, 0.99], sat = 0.92, bloom = 0.14, thr = 0.92, night = 0.0, dayMix = 1.0 },
	{ h = 15.6, skyTop = 0x84a9c6, skyHor = 0xece2c8, low = 0xd8d8c8, fog = 0xd3d4c6, dens = 0.009,
		sun = 0xfff6ea, sunI = 3.1, hemiS = 0xb8cce6, hemiG = 0x86785a, hemiI = 1.2, glow = 0xfff0d0, glowI = 0.12,
		lift = [0.012, 0.012, 0.02], gamma = [1.02, 1.02, 1.0], gain = [1.03, 1.02, 0.99], sat = 0.92, bloom = 0.14, thr = 0.92, night = 0.0, dayMix = 1.0 },
	{ h = 17.2, skyTop = 0x6d86ac, skyHor = 0xf2c98e, low = 0xdcb895, fog = 0xd4b69c, dens = 0.011,
		sun = 0xffca90, sunI = 3.1, hemiS = 0x9ca6d0, hemiG = 0x5e4c40, hemiI = 1.3, glow = 0xffa650, glowI = 0.55,
		lift = [0.03, 0.02, 0.03], gamma = [1.02, 1.0, 1.0], gain = [1.05, 0.99, 0.92], sat = 0.9, bloom = 0.28, thr = 0.84, night = 0.0, dayMix = 1.0 },
	{ h = 18.3, skyTop = 0x4f5d8e, skyHor = 0xf09a58, low = 0xb8949a, fog = 0xba948c, dens = 0.013,
		sun = 0xffb474, sunI = 3.1, hemiS = 0x8a90cc, hemiG = 0x4c4044, hemiI = 1.45, glow = 0xff7a3a, glowI = 0.85,
		lift = [0.03, 0.025, 0.05], gamma = [1.08, 1.05, 1.05], gain = [1.05, 0.98, 0.93], sat = 0.92, bloom = 0.4, thr = 0.78, night = 0.15, dayMix = 0.9 },
	{ h = 19.4, skyTop = 0x1f2a58, skyHor = 0x8a6a8a, low = 0x4c4f72, fog = 0x454a6c, dens = 0.016,
		sun = 0xa89ad0, sunI = 0.9, hemiS = 0x5d6394, hemiG = 0x1d1a26, hemiI = 1.0, glow = 0xc0708a, glowI = 0.45,
		lift = [0.04, 0.035, 0.07], gamma = [1.12, 1.1, 1.06], gain = [0.95, 0.95, 1.08], sat = 0.8, bloom = 0.45, thr = 0.78, night = 0.75, dayMix = 0.25 },
	{ h = 20.6, skyTop = 0x0c1332, skyHor = 0x29386a, low = 0x223052, fog = 0x1f2b4a, dens = 0.017,
		sun = 0x8fa8e0, sunI = 0.95, hemiS = 0x4a5f96, hemiG = 0x151a26, hemiI = 1.05, glow = 0x3a4a7a, glowI = 0.15,
		lift = [0.035, 0.045, 0.085], gamma = [1.16, 1.16, 1.1], gain = [0.9, 0.97, 1.12], sat = 0.72, bloom = 0.45, thr = 0.8, night = 1.0, dayMix = 0.0 },
]
const COLOR_KEYS := ["skyTop", "skyHor", "low", "fog", "sun", "hemiS", "hemiG", "glow"]
const NUM_KEYS := ["dens", "sunI", "hemiI", "glowI", "sat", "bloom", "thr", "night", "dayMix"]
const VEC_KEYS := ["lift", "gamma", "gain"]

static var _keys: Array = []

static func _lin(hex: int) -> Vector3:
	var c := Color.hex((hex << 8) | 0xff).srgb_to_linear()
	return Vector3(c.r, c.g, c.b)

static func _prepare() -> void:
	if not _keys.is_empty():
		return
	for k in RAW:
		var o := { h = k.h }
		for c in COLOR_KEYS: o[c] = _lin(k[c])
		for n in NUM_KEYS: o[n] = float(k[n])
		for v in VEC_KEYS: o[v] = Vector3(k[v][0], k[v][1], k[v][2])
		_keys.append(o)

# hour(0~24) → 상태 사전
static func sample(hour: float) -> Dictionary:
	_prepare()
	var h := fposmod(hour, 24.0)
	var n := _keys.size()
	var a: Dictionary = _keys[n - 1]
	var b: Dictionary = _keys[0]
	var t := 0.0
	var found := false
	for i in n - 1:
		if h >= _keys[i].h and h < _keys[i + 1].h:
			a = _keys[i]; b = _keys[i + 1]; found = true
			t = (h - a.h) / (b.h - a.h)
			break
	if not found:
		var span: float = 24.0 - a.h + b.h
		t = ((h - a.h) if h >= a.h else (h + 24.0 - a.h)) / span
	t = t * t * (3.0 - 2.0 * t)
	var out := {}
	for c in COLOR_KEYS: out[c] = (a[c] as Vector3).lerp(b[c], t)
	for k in NUM_KEYS: out[k] = lerpf(a[k], b[k], t)
	for v in VEC_KEYS: out[v] = (a[v] as Vector3).lerp(b[v], t)
	return out

static func _arc(theta: float, max_elev: float, south: float) -> Vector3:
	var s := sin(theta)
	var x := cos(theta)
	var y := maxf(0.3, s * max_elev)
	var z := south + maxf(0.0, s) * 0.55
	return Vector3(x * 0.9, y, z).normalized()

# 해/달 방향(빛이 오는 쪽)
static func light_direction(hour: float, day_mix: float) -> Vector3:
	var h := fposmod(hour, 24.0)
	var sun := _arc(((h - 6.0) / 12.0) * PI, 1.05, 0.45)
	var hm := h + 24.0 if h < 12.0 else h
	var moon := _arc(((hm - 18.0) / 12.0) * PI, 0.85, 0.6)
	return moon.lerp(sun, day_mix).normalized()

# 등불 켜짐(18.5~19.5 켜짐, 5~6시 꺼짐)
static func lamp_factor(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	return smoothstep(18.5, 19.5, h) if h >= 12.0 else 1.0 - smoothstep(5.0, 6.0, h)

# 창호지·초롱 빛(웹 main.js nightFactor)
static func night_factor(h: float) -> float:
	return smoothstep(18.5, 19.5, h) if h >= 12.0 else 1.0 - smoothstep(5.0, 6.5, h)
