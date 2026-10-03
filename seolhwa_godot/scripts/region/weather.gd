# 기후대·날씨(docs/TOWN_IDENTITY_CLIMATE_PLAN.md B2·B3·B4) — 권역 climate.png(4m 격자, 0 남부·1 중부·2 북부·3 고산·4 해안섬)를 읽어
#   - 플레이어 자리의 기후대 → 날씨 출현 확률표에서 날씨를 고른다(맑음·흐림·비·안개·눈·강풍). 일정 시간마다, 기후대가 바뀌면 다시 고른다.
#   - 날씨 값(구름·비·눈·안개 배율·바람)은 천천히 옮겨 가고(전환 약 10s), 젖음 `wet`·눈 덮기 `snow`는 쌓이고 마른다(전역 셰이더 값).
#   - 기후대별 하늘·빛 보정(남부 따뜻·습함, 북부 차갑고 해 낮음, 고산 차갑고 맑음, 해안 해무)을 시간대 상태(TimeOfDay.sample)에 덧씌운다.
#   - 비·눈·바람 티끌 입자: 카메라 둘레 상자 하나(shaders/region_precip.gdshader, 그리기 1번).
# 시험: U 키로 날씨 돌리기(맑음→흐림→비→안개→눈→강풍→자동), 명령줄 --weather=clear|cloudy|rain|fog|snow|wind (쌓임도 바로 채움).
extends Node3D

const PngRaw := preload("res://scripts/region/png_raw.gd")

const ZONES := ["south", "central", "north", "alpine", "coast"]
const ZONE_KO := { south = "남부", central = "중부", north = "북부", alpine = "고산", coast = "해안섬" }
const KINDS := ["clear", "cloudy", "rain", "fog", "snow", "wind"]
const KIND_KO := { clear = "맑음", cloudy = "흐림", rain = "비", fog = "안개", snow = "눈", wind = "강풍" }
# 기후대별 날씨 출현 확률(합 1)
const PROB := {
	south = { clear = 0.42, cloudy = 0.22, rain = 0.24, fog = 0.12 },
	central = { clear = 0.42, cloudy = 0.22, rain = 0.17, fog = 0.08, snow = 0.08, wind = 0.03 },
	north = { clear = 0.25, cloudy = 0.2, rain = 0.04, fog = 0.05, snow = 0.4, wind = 0.06 },
	alpine = { clear = 0.2, cloudy = 0.15, fog = 0.25, snow = 0.28, wind = 0.12 },
	coast = { clear = 0.3, cloudy = 0.15, rain = 0.15, fog = 0.3, wind = 0.1 },
}
# 날씨 → 목표 값. cloud 0~1(해 가림·하늘 회색), rain/snowfall 0~1(입자), fogm 안개 농도 배율, wind 0~1
const TARGET := {
	clear = { cloud = 0.0, rain = 0.0, snowfall = 0.0, fogm = 1.0, wind = 0.1 },
	cloudy = { cloud = 0.6, rain = 0.0, snowfall = 0.0, fogm = 1.3, wind = 0.25 },
	rain = { cloud = 0.85, rain = 1.0, snowfall = 0.0, fogm = 1.4, wind = 0.3 },
	fog = { cloud = 0.5, rain = 0.0, snowfall = 0.0, fogm = 2.8, wind = 0.0 },
	snow = { cloud = 0.75, rain = 0.0, snowfall = 1.0, fogm = 1.9, wind = 0.2 },
	wind = { cloud = 0.35, rain = 0.0, snowfall = 0.0, fogm = 1.1, wind = 1.0 },
}
# 기후대 빛 보정(B3): sun 색 곱, sunI 곱, 해 높이 곱, 안개 곱, 안개색 곱, 반구광 하늘색 곱, 후처리 gain 곱·채도 곱, 바탕 눈(snow base)
const LOOK := {
	south = { sun = Vector3(1.04, 1.0, 0.92), sunI = 1.0, elev = 1.0, dens = 1.12, fog = Vector3(1.02, 1.0, 0.96), sky = Vector3(1.02, 1.0, 0.97), gain = Vector3(1.02, 1.0, 0.97), sat = 1.04, snow = 0.0 },
	central = { sun = Vector3(1.0, 1.0, 1.0), sunI = 1.0, elev = 0.92, dens = 1.0, fog = Vector3(1.0, 1.0, 1.0), sky = Vector3(1.0, 1.0, 1.0), gain = Vector3(1.0, 1.0, 1.0), sat = 1.0, snow = 0.0 },
	north = { sun = Vector3(0.9, 0.96, 1.08), sunI = 0.9, elev = 0.62, dens = 0.95, fog = Vector3(0.94, 0.98, 1.06), sky = Vector3(0.92, 0.98, 1.08), gain = Vector3(0.96, 0.99, 1.05), sat = 0.88, snow = 0.0 },   # 맑은 날 바탕 눈 없음 — 눈은 눈 날씨와 눈선 위(고산)만
	alpine = { sun = Vector3(0.96, 0.99, 1.05), sunI = 1.05, elev = 0.9, dens = 1.2, fog = Vector3(0.96, 0.99, 1.04), sky = Vector3(0.95, 0.99, 1.05), gain = Vector3(0.98, 1.0, 1.03), sat = 0.9, snow = 0.0 },
	coast = { sun = Vector3(1.0, 1.0, 0.98), sunI = 0.97, elev = 1.0, dens = 1.25, fog = Vector3(0.95, 0.99, 1.04), sky = Vector3(0.97, 1.0, 1.04), gain = Vector3(0.99, 1.0, 1.02), sat = 0.95, snow = 0.0 },
}
const PERIOD_MIN := 120.0   # 날씨가 바뀌는 간격(초, 실제 시간)
const PERIOD_MAX := 260.0
const N_RAIN := 5000
const N_SNOW := 4500
const N_DUST := 600

var world
var codes: PackedByteArray
var cx0 := 0.0; var cz0 := 0.0; var ccell := 4.0; var cw := 0; var ch := 0
var default_zone := "south"
var zone := "south"            # 지금 플레이어 자리 기후대
var zone_mix := {}             # 기후대 → 가중(천천히 옮겨 감)
var kind := "clear"
var forced := ""               # --weather 또는 U 키
var cur := { cloud = 0.0, rain = 0.0, snowfall = 0.0, fogm = 1.0, wind = 0.1 }
var wet := 0.0
var snow := 0.0
var snow_line := 1e5
var dirty := true              # 빛 보정이 바뀌어 region_main이 다시 칠해야 함
var _rng := RandomNumberGenerator.new()
var _next_roll := 0.0
var _t := 0.0
var _zone_t := 0.0
var _rain_mi: MeshInstance3D
var _snow_mi: MeshInstance3D
var _dust_mi: MeshInstance3D
var _mats := []
var _wind_dir := Vector2(1, 0.3).normalized()
var _indoor := false

func setup(w, data_dir: String, forced_kind := "") -> void:
	world = w
	var reg: Dictionary = w.region
	var cm = reg.get("climate")
	# 기본 기후대: regions.json/region.json climate 문자열 → 위도
	default_zone = _zone_from_any(reg.get("climate_zone", cm if cm is String else ""))
	# 위도 띠 덮어쓰기: climate.rule.band(또는 climate.band) — terrain-data-north §5 요청(황주 38.7°N → 중부)
	if default_zone == "" and cm is Dictionary:
		var rule = cm.get("rule", {})
		default_zone = _zone_from_any(cm.get("band", rule.get("band", "") if rule is Dictionary else ""))
	if default_zone == "":
		var lat0 := float(reg.get("projection", {}).get("lat0", 35.5)) if reg.get("projection") is Dictionary else 35.5
		default_zone = "south" if lat0 < 36.0 else ("central" if lat0 < 38.0 else "north")
	if cm is Dictionary and FileAccess.file_exists(data_dir.path_join(String(cm.get("file", "climate.png")))):
		var d := PngRaw.load_gray(ProjectSettings.globalize_path(data_dir.path_join(String(cm.get("file", "climate.png")))))
		if not d.is_empty() and d.bpp == 1:
			codes = d.bytes; cw = d.w; ch = d.h
			cx0 = float(cm.get("x0", w.hx0)); cz0 = float(cm.get("z0", w.hz0)); ccell = float(cm.get("cell", 4.0))
		# 덮어쓰기 표시가 없으면 climate.png의 남부·중부·북부 칸 중 가장 많은 것을 기본 기후대로(데이터가 이미 칠해 둔 띠를 따른다)
		if not _zone_given(reg, cm) and cw > 0:
			var cnt := [0, 0, 0]
			for j in range(0, ch, 8):
				for i in range(0, cw, 8):
					var c := codes[j * cw + i]
					if c < 3: cnt[c] += 1
			var best := 0
			for b in 3:
				if cnt[b] > cnt[best]: best = b
			if cnt[best] > 0: default_zone = ZONES[best]
		snow_line = _snow_line(reg, cm)
	elif reg.get("projection") is Dictionary:
		snow_line = _snow_line(reg, {})
	zone = default_zone
	for z in ZONES: zone_mix[z] = 1.0 if z == zone else 0.0
	_rng.seed = String(reg.get("region_id", reg.get("route_id", "r"))).hash()
	_rain_mi = _make_particles(N_RAIN, 0.0)
	_snow_mi = _make_particles(N_SNOW, 1.0)
	_dust_mi = _make_particles(N_DUST, 2.0)
	if forced_kind != "" and KINDS.has(forced_kind):
		forced = forced_kind
		kind = forced
		_snap()
	else:
		_roll(true)
		_snap()
	print("WEATHER zone=%s kind=%s snow_line=%.0f climate=%s" % [zone, kind, snow_line, "%dx%d" % [cw, ch] if cw > 0 else "없음"])

func _zone_given(reg: Dictionary, cm) -> bool:
	if _zone_from_any(reg.get("climate_zone", "")) != "": return true
	if cm is Dictionary:
		var rule = cm.get("rule", {})
		if _zone_from_any(cm.get("band", rule.get("band", "") if rule is Dictionary else "")) != "": return true
	return false

static func _zone_from_any(v) -> String:
	var s := String(v).to_lower()
	if s == "": return ""
	for z in ZONES:
		if s.begins_with(z): return z
	for z in ZONE_KO:
		if s.contains(ZONE_KO[z]): return z
	return ""

# 눈선: climate.rule.alpine_alt_m(위도대별 고산 해발) → 게임 y. 없으면 climate.png 고산 칸 높이의 최솟값
func _snow_line(reg: Dictionary, cm: Dictionary) -> float:
	var pj: Dictionary = reg.get("projection", {}) if reg.get("projection") is Dictionary else {}
	var K := float(pj.get("K", 0.3)); var base := float(pj.get("y_base_alt", 60.0))
	var rule = cm.get("rule", {})
	if rule is Dictionary and rule.get("alpine_alt_m") is Dictionary:
		var lat0 := float(pj.get("lat0", 35.5))
		var band := "0" if lat0 < 36.0 else ("1" if lat0 < 38.0 else "2")
		var zi := ZONES.find(default_zone)   # 위도 띠 덮어쓰기(band·climate.png 다수)를 눈선에도
		if zi >= 0 and zi < 3: band = str(zi)
		var alt = rule.alpine_alt_m.get(band)
		if alt != null: return (float(alt) - base) * K - 15.0   # 눈 덮기는 눈선 위 30m에 걸쳐 짙어지므로 조금 아래서 시작
	if cw > 0:
		var lo := INF
		for j in range(0, ch, 3):
			for i in range(0, cw, 3):
				if codes[j * cw + i] == 3: lo = minf(lo, world.data_height(cx0 + i * ccell, cz0 + j * ccell))
		if lo < INF: return lo
	return 1e5

func zone_at(x: float, z: float) -> String:
	if cw == 0: return default_zone
	var i := clampi(roundi((x - cx0) / ccell), 0, cw - 1); var j := clampi(roundi((z - cz0) / ccell), 0, ch - 1)
	var c := codes[j * cw + i]
	return ZONES[c] if c < ZONES.size() else default_zone

# ---- 날씨 고르기 ----
func _roll(_first := false) -> void:
	_next_roll = _t + _rng.randf_range(PERIOD_MIN, PERIOD_MAX)
	if forced != "": kind = forced; return
	var p: Dictionary = PROB.get(zone, PROB.south)
	var r := _rng.randf(); var acc := 0.0
	for k in p:
		acc += float(p[k])
		if r <= acc: kind = k; return
	kind = "clear"

# 쌓임·값을 바로 목표로(시작·--weather·권역 넘어온 직후)
func _snap() -> void:
	cur = TARGET[kind].duplicate()
	if kind == "rain": wet = 1.0
	elif kind == "fog": wet = 0.35
	else: wet = 0.0
	snow = maxf(_base_snow(), 1.0 if kind == "snow" else 0.0)
	dirty = true
	_push_globals()

func _base_snow() -> float:
	var s := 0.0
	for z in zone_mix: s += float(LOOK[z].snow) * float(zone_mix[z])
	return s

# U 키: 맑음→흐림→비→안개→눈→강풍→자동(기후대 확률)
func cycle() -> String:
	if forced == "": forced = KINDS[0]
	else:
		var i := KINDS.find(forced)
		forced = KINDS[i + 1] if i + 1 < KINDS.size() else ""
	if forced != "": kind = forced
	else: _roll()
	return label()

func label() -> String:
	return "%s · %s%s" % [ZONE_KO.get(zone, zone), KIND_KO.get(kind, kind), "" if forced == "" else " (고정)"]

# ---- 매 프레임 ----
func update(dt: float, player: Vector3, cam: Vector3, indoor: bool) -> void:
	_t += dt
	_zone_t -= dt
	if _zone_t <= 0.0:
		_zone_t = 0.5
		var z := zone_at(player.x, player.z)
		if z != zone:
			zone = z
			if forced == "": _roll()   # 기후대가 바뀌면 그 기후대 확률로 다시 고른다
	if _t >= _next_roll: _roll()
	# 기후대 가중: 4초에 걸쳐
	var kz := minf(1.0, dt / 4.0)
	for z in zone_mix:
		var tgt := 1.0 if z == zone else 0.0
		if absf(zone_mix[z] - tgt) > 0.0005: zone_mix[z] += (tgt - zone_mix[z]) * kz; dirty = true
	# 날씨 값: 약 10초 전환
	var tg: Dictionary = TARGET[kind]
	var kt := minf(1.0, dt / 10.0)
	for k in cur:
		var v: float = cur[k]
		if absf(v - float(tg[k])) > 0.0005:
			cur[k] = v + (float(tg[k]) - v) * kt; dirty = true
	# 젖음: 비 오면 40초에 젖고, 2분에 걸쳐 마른다(안개는 살짝 축축)
	var wet_t: float = maxf(cur.rain, 0.3 * clampf((cur.fogm - 1.0) / 2.6, 0.0, 1.0))
	wet += (wet_t - wet) * minf(1.0, dt / (40.0 if wet_t > wet else 120.0))
	# 눈: 오면 1분에 쌓이고, 그치면 기후대 바탕(북부 0.55)까지 아주 천천히 녹는다
	var snow_t := maxf(_base_snow(), cur.snowfall)
	snow += (snow_t - snow) * minf(1.0, dt / (60.0 if snow_t > snow else 300.0))
	_push_globals()
	# 입자: 카메라와 플레이어 사이 가운데를 중심으로
	_indoor = indoor
	var c := cam.lerp(player, 0.6)
	var wind := _wind_dir * (1.0 + 9.0 * float(cur.wind))
	var rain_k: float = 0.0 if indoor else float(cur.rain)
	var snow_k: float = 0.0 if indoor else maxf(float(cur.snowfall), float(cur.wind) * 0.35 * clampf(snow, 0.0, 1.0) * (1.0 if zone == "alpine" or zone == "north" else 0.0))
	var dust_k: float = 0.0 if indoor else clampf((float(cur.wind) - 0.5) * 2.0, 0.0, 1.0) * (1.0 - snow_k)
	_set_p(_rain_mi, rain_k, c, Vector3(wind.x * 0.6, -11.0, wind.y * 0.6))
	_set_p(_snow_mi, snow_k, c, Vector3(wind.x * 0.5, -1.3, wind.y * 0.5))
	_set_p(_dust_mi, dust_k, c, Vector3(wind.x * 1.6, -0.4, wind.y * 1.6))

func _set_p(mi: MeshInstance3D, k: float, c: Vector3, v: Vector3) -> void:
	mi.visible = k > 0.005
	if not mi.visible: return
	var m: ShaderMaterial = mi.material_override
	m.set_shader_parameter("amount", k)
	m.set_shader_parameter("center", c)
	m.set_shader_parameter("vel", v)

func _push_globals() -> void:
	RenderingServer.global_shader_parameter_set("wet", wet)
	RenderingServer.global_shader_parameter_set("snow", clampf(snow, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("snow_line", snow_line)

# 끝낼 때·권역을 떠날 때 전역값을 기본으로 되돌린다(다른 장면이 영향받지 않게)
func reset_globals() -> void:
	RenderingServer.global_shader_parameter_set("wet", 0.0)
	RenderingServer.global_shader_parameter_set("snow", 0.0)
	RenderingServer.global_shader_parameter_set("snow_line", 100000.0)

func _exit_tree() -> void:
	reset_globals()

# ---- 빛 보정: 시간대 상태 s와 해 방향 dir → 기후대·날씨를 덧씌운 새 상태 ----
func modify(s: Dictionary, dir: Vector3) -> Array:
	var o := s.duplicate()
	var lk := { sun = Vector3.ZERO, sunI = 0.0, elev = 0.0, dens = 0.0, fog = Vector3.ZERO, sky = Vector3.ZERO, gain = Vector3.ZERO, sat = 0.0 }
	for z in zone_mix:
		var wz: float = zone_mix[z]
		if wz <= 0.0001: continue
		for k in lk: lk[k] += LOOK[z][k] * wz
	var cl: float = cur.cloud
	var day: float = s.dayMix
	o.sun = (s.sun as Vector3) * lk.sun
	o.sunI = float(s.sunI) * float(lk.sunI) * (1.0 - 0.68 * cl * day) * (1.0 - 0.25 * float(cur.rain))
	var gray := ((s.fog as Vector3) + (s.skyHor as Vector3)) * 0.5
	var g1: float = (gray.x + gray.y + gray.z) / 3.0
	var grayv := Vector3(g1, g1, g1 * 1.03)
	o.skyTop = ((s.skyTop as Vector3) * lk.sky).lerp(grayv * 0.92, cl * 0.75)
	o.skyHor = ((s.skyHor as Vector3) * lk.sky).lerp(grayv, cl * 0.6)
	o.low = (s.low as Vector3).lerp(grayv * 0.95, cl * 0.5)
	o.fog = ((s.fog as Vector3) * lk.fog).lerp(grayv, cl * 0.45)
	o.glowI = float(s.glowI) * (1.0 - 0.7 * cl)
	o.dens = float(s.dens) * float(lk.dens) * float(cur.fogm)
	# 흐리면 반구광은 고르게(하늘·땅 차이 줄임), 해가 약해진 만큼 조금 밝게
	o.hemiS = ((s.hemiS as Vector3) * lk.sky).lerp(grayv * 1.05, cl * 0.4 * day)
	o.hemiG = (s.hemiG as Vector3).lerp((s.hemiG as Vector3) * 0.5 + grayv * 0.25, cl * 0.4 * day)
	o.hemiI = float(s.hemiI) * (1.0 + 0.18 * cl * day)
	o.sat = float(s.sat) * float(lk.sat) * (1.0 - 0.22 * cl)
	o.gain = (s.gain as Vector3) * lk.gain
	o.bloom = float(s.bloom) * (1.0 - 0.5 * cl)
	# 눈이 쌓이면 땅에서 되비치는 빛(반구광 땅색)이 밝고 차갑다
	o.hemiG = (o.hemiG as Vector3).lerp(Vector3(0.45, 0.48, 0.55) * maxf(day, 0.15), clampf(snow, 0.0, 1.0) * 0.45)
	var d := Vector3(dir.x, dir.y * float(lk.elev), dir.z)
	if d.y < 0.22: d.y = 0.22
	return [o, d.normalized()]

# ---- 입자 메시 ----
func _make_particles(n: int, mode: float) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new(); rng.seed = 1870 + int(mode)
	var v := PackedVector3Array(); v.resize(n * 4)
	var uv := PackedVector2Array(); uv.resize(n * 4)
	var col := PackedColorArray(); col.resize(n * 4)
	var idx := PackedInt32Array(); idx.resize(n * 6)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in n:
		var s := Vector3(rng.randf(), rng.randf(), rng.randf())
		var r := rng.randf()
		for k in 4:
			v[i * 4 + k] = s; uv[i * 4 + k] = corners[k]; col[i * 4 + k] = Color(r, 0, 0, 1)
		var b := i * 4
		idx[i * 6] = b; idx[i * 6 + 1] = b + 1; idx[i * 6 + 2] = b + 2
		idx[i * 6 + 3] = b; idx[i * 6 + 4] = b + 2; idx[i * 6 + 5] = b + 3
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_COLOR] = col; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.name = ["rain", "snow", "dust"][int(mode)]
	var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/region_precip.gdshader")
	world._common_params(mat)
	mat.set_shader_parameter("mode", mode)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1e5, -1e4, -1e5), Vector3(2e5, 2e4, 2e5))
	mi.visible = false
	add_child(mi)
	_mats.append(mat)
	return mi
