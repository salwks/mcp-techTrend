# 고정 시점 카메라 — 웹 core/camera.js 이식. 기본 내려다보는 각 40°(2026-10 — 38에서, 권역 기본 구역 CAM_DEFAULT 40과 같게; 도시 구역도 40~42). yaw 고정(남→북), 구역·실내에 따라 pitch/거리/fov만 부드럽게 바뀐다.
# 배를 탈 때(sailing)만 풍경 시점: 낮은 pitch(약 13°)·조금 넓은 fov로 배 뒤·옆에서 뱃길 방향(+ 높은 기슭 쪽)을 보며 yaw가 배를
# 따라 부드럽게 돈다. 내리면 yaw 0(남→북 고정)으로 천천히 돌아온다.
# 말을 탈 때(riding — scripts/region/horse_ride.gd)도 같은 풍경 시점: 배보다 조금 높고(20°) 걷기보다 멀리(21m), 말 뒤에서 볼 쪽으로
# 28° 비켜 선다. ride_k(0~1)로 걷기 시점과 섞는다(사건·어귀 앞 감속하며 가까워짐). shake_y: 말 걸음 흔들림(설정 '이동 카메라 흔들림').
class_name CameraRig
extends RefCounted

const DEFAULT := { pitch = 40.0, distance = 16.0, fov = 30.0, lookAhead = 1.2, aimZ = 0.0 }   # aimZ: 겨냥점을 z로 옮김(−=북쪽, 구역 값)

var camera: Camera3D
var world: World
var cur := DEFAULT.duplicate()
var target := Vector3.ZERO
var mode := "zones"
var zone_name := ""
var override = null
var focus = null
var sailing := false   # 배를 타고 갈 때: 낮게·옆에서 기슭과 하늘이 보이게(부드럽게 바뀐다)
var sail_dir := Vector2.ZERO   # 배가 가는 방향(xz, 길이 1)
var sail_side := 1.0           # 볼 기슭: 뱃길 왼쪽 +1 / 오른쪽 −1 (카메라는 반대쪽 뒤에 선다)
const SAIL := { pitch = 15.0, distance = 15.0, fov = 40.0, lookAhead = 0.0, aimZ = 0.0 }
const SAIL_SIDE_DEG := 48.0    # 배 뒤에서 옆으로 돌아선 각도
var yaw := 0.0                 # 지금 yaw(라디안, 0 = 남쪽에서 북쪽을 봄)
var riding := false            # 말 타고 갈 때
var ride_dir := Vector2.ZERO
var ride_side := 1.0
var ride_k := 1.0              # 1 = 말 시점, 0 = 걷기 시점(멈춤에 다가가며 줄어든다)
var shake_y := 0.0
const RIDE := { pitch = 20.0, distance = 21.0, fov = 38.0, lookAhead = 0.0, aimZ = 0.0 }
# 이야기 인물 대화 카메라(공통 TALK — 제작 규칙 v1.0 결정 4·C27): 플레이어가 이야기 인물(사건 actor)에게 직접 말을 걸 때만.
#   고을 사람(ambient_talk)·역참 마부·길목 깃발은 쓰지 않는다. 겨냥은 플레이어와 인물 사이(story_director._talk_camera).
const TALK := { "pitch": 38.0, "distance": 13.5, "fov": 38.0 }

# 대화 카메라 값 고르기: 공통 TALK → case.talk_camera → actor.talk_camera (뒤가 앞을 덮는다). 대화 중 명시적 camera/cutscene은 그 위에서 이긴다.
#   각 층: 없음(null) = 그대로 · false = 끄기(평소 카메라) · true = 켜기(공통 값) · {pitch, distance, fov 일부} = 덮어쓰기.
#   반환: 쓸 값 Dictionary(pitch·distance·fov) 또는 null(끔)
static func talk_spec(case_head: Dictionary, actor_spec := {}):
	var out = TALK.duplicate()
	for layer in [case_head.get("talk_camera"), actor_spec.get("talk_camera")]:
		if layer == null: continue
		if layer is bool:
			if not layer: out = null
			elif out == null: out = TALK.duplicate()
		elif layer is Dictionary:
			if out == null: out = TALK.duplicate()
			for k in ["pitch", "distance", "fov"]:
				if layer.has(k): out[k] = float(layer[k])
	return out
# 연출 미끄러짐(glide): 겨냥점·pitch·거리·fov를 시작값에서 목표값으로 smoothstep으로 천천히 옮긴다(천천히 떠나 천천히 닿는다).
# 목표 겨냥점이 null이면 매 프레임 계산한 평소 자리(플레이어)로 돌아온다. 이야기 컷(전경 등)이 '쉭' 하고 튀지 않게.
var _gl = null
const RIDE_SIDE_DEG := 28.0
# 각본 시점(shot): 컷신 한 장면에서만 — 카메라 자리(pos)와 바라볼 점(look), fov를 그대로 쓴다(하늘을 올려다보는 동아줄 장면 등).
# 평소 시점 계산(pitch·distance·yaw)은 건너뛴다. null로 되돌리면 다음 프레임부터 평소 시점(되돌릴 때는 암전 속에서).
var shot = null   # { pos: Vector3, look: Vector3, fov: float }
# 대화 구도(story_director.camera에 talk 표시가 붙은 값 — 공통 TALK·talk_camera_base)가 넣은 override·focus 사전 그대로.
#   1인칭(region_main)은 이것을 저작 연출로 치지 않는다(1인칭에서는 애초에 넣지 않지만, 3인칭 대화 도중 0을 눌렀을 때를 위해).
var talk_o = null
var talk_f = null
# 대화 옆 돌기(재기획 2단계 CAM_TALK_2 — scripts/story/talk_frame.gd): null = 평소(yaw 0) · 라디안 = 대화 동안 이 yaw로 선다.
#   배·말 풍경 시점과 같은 yaw 경로를 쓴다(새 카메라 체계 없음). 미끄러짐(glide) 동안은 yaw도 smoothstep으로 함께 옮긴다.
var talk_yaw = null

func _init(cam: Camera3D, w: World) -> void:
	camera = cam
	world = w

func params(pos: Vector3, interior) -> Dictionary:
	var p := DEFAULT.duplicate()
	if override != null:
		p.merge(override, true); return p
	if mode == "fixed": return p
	if sailing:
		p.merge(SAIL, true); return p
	if riding:
		for k in RIDE: p[k] = lerpf(float(p[k]), float(RIDE[k]), ride_k)
		return p
	if interior != null and interior.has("camera"):
		p.merge(interior.camera, true); p.lookAhead = 0.3; return p
	var zone = null
	for z in world.camera_zones:
		if World.in_box(z, pos.x, pos.z): zone = z
	zone_name = zone.name if zone != null else ""
	if zone != null:
		for k in ["pitch", "distance", "fov", "lookAhead", "aimZ"]:
			if zone.has(k): p[k] = float(zone[k])
		if zone.has("yaw"): p.yaw = float(zone.yaw)   # 전망 자리(산 자리 view_yaw): 바라보는 쪽으로 돈다(도)
	return p

func update(dt: float, pos: Vector3, facing: String, interior, snap := false) -> void:
	if shot != null:
		var sp: Vector3 = shot.pos
		var lk: Vector3 = shot.look
		if Vector2(lk.x - sp.x, lk.z - sp.z).length() < 0.05: lk.z -= 0.05   # 바로 위를 보면 look_at이 깨진다
		camera.position = sp + Vector3(0, shake_y, 0)
		camera.look_at(lk, Vector3.UP)
		camera.fov = float(shot.get("fov", cur.fov))
		return
	var p := params(pos, interior)
	var k := 1.0 if snap else 1.0 - exp(-dt * 2.2)
	for key in ["pitch", "distance", "fov", "lookAhead", "aimZ"]:
		cur[key] += (float(p.get(key, 0.0)) - cur[key]) * k
	var ahead: Vector2 = { down = Vector2(0, 0.6), up = Vector2(0, -1), left = Vector2(-1, 0), right = Vector2(1, 0) }.get(facing, Vector2.ZERO)
	var tx: float; var tz: float; var ty: float
	if focus != null:
		tx = focus.x; tz = focus.z; ty = focus.get("y", world.height_at(tx, tz)) + 0.9
	else:
		tx = pos.x + ahead.x * cur.lookAhead; tz = pos.z + ahead.y * cur.lookAhead + cur.aimZ; ty = pos.y + 0.9
	# 배: 겨냥점은 배 앞쪽, yaw는 배 뒤에서 볼 기슭 반대쪽으로 SAIL_SIDE_DEG만큼 돌아선 자리(카메라 → 겨냥점 = 뱃길 앞 + 기슭 쪽)
	var want_yaw := 0.0
	if sailing and override == null and focus == null and sail_dir.length() > 0.5:
		tx = pos.x + sail_dir.x * 4.0; tz = pos.z + sail_dir.y * 4.0; ty = pos.y + 1.4
		var back := (-sail_dir).rotated(deg_to_rad(SAIL_SIDE_DEG) * sail_side)   # −h를 −n(볼 기슭 반대) 쪽으로
		want_yaw = atan2(back.x, back.y)
	elif riding and override == null and focus == null and ride_dir.length() > 0.5 and ride_k > 0.25:
		tx = pos.x + ride_dir.x * 5.0 * ride_k; tz = pos.z + ride_dir.y * 5.0 * ride_k; ty = pos.y + 1.0 + 0.8 * ride_k
		var back2 := (-ride_dir).rotated(deg_to_rad(RIDE_SIDE_DEG) * ride_side)
		want_yaw = atan2(back2.x, back2.y)
	elif talk_yaw != null and not sailing and not riding and shot == null:
		want_yaw = float(talk_yaw)
	elif p.has("yaw") and override == null and focus == null:
		want_yaw = deg_to_rad(float(p.yaw))
	var ky := 1.0 if snap else 1.0 - exp(-dt * (0.45 if riding else (1.1 if sailing else 1.6)))   # 말: 천천히 돈다
	if _gl != null and _gl.has("yaw0"):
		var wy := smoothstep(0.0, 1.0, clampf((_gl.t + dt) / maxf(_gl.dur, 0.01), 0.0, 1.0))
		yaw = wrapf(lerp_angle(float(_gl.yaw0), want_yaw, wy), -PI, PI)
	else:
		yaw = wrapf(yaw + wrapf(want_yaw - yaw, -PI, PI) * ky, -PI, PI)
	if absf(yaw) < 1e-4 and want_yaw == 0.0: yaw = 0.0
	var kf := 1.0 if snap else 1.0 - exp(-dt * 4.0)
	if _gl != null:
		_gl.t += dt
		var w := smoothstep(0.0, 1.0, clampf(_gl.t / maxf(_gl.dur, 0.01), 0.0, 1.0))
		var gt: Vector3 = _gl.to if _gl.to != null else Vector3(tx, ty, tz)
		target = (_gl.from as Vector3).lerp(gt, w)
		for key in ["pitch", "distance", "fov", "lookAhead", "aimZ"]:
			cur[key] = lerpf(float(_gl.cur0[key]), float(p.get(key, 0.0)), w)
		if _gl.t >= _gl.dur: _gl = null
	else:
		target += (Vector3(tx, ty, tz) - target) * kf
	var pr := deg_to_rad(cur.pitch)
	var d: float = cur.distance
	var off := Vector3(sin(yaw) * cos(pr) * d, sin(pr) * d, cos(yaw) * cos(pr) * d)
	if yaw == 0.0: off = Vector3(0, sin(pr) * d, cos(pr) * d)   # 기본 시점은 예전 식 그대로
	var cp := target + off
	if sailing or riding or yaw != 0.0:   # 낮은 시점: 기슭·둑 속으로 들어가지 않게
		cp.y = maxf(cp.y, world.height_at(cp.x, cp.z) + 1.6)
	if interior == null and world.has_method("ground_at"): cp = _clear_terrain(cp, target)
	cp.y += shake_y
	camera.position = cp
	camera.look_at(target, Vector3.UP)
	camera.fov = cur.fov

# 산 비탈 가림(mountain-terrain): 겨냥점 → 카메라 선분이 땅(지형만 — 건물 바닥·다리 면은 보지 않음)에 걸리면 카메라를 들어 올린다.
#   당기기(거리 줄이기) 대신 올리기 — 화면 크기(거리)는 그대로, 비탈 위에서 내려다보는 각만 깊어진다. 평지 고을에서는 걸리는 일이 없어 그대로.
#   급히 튀지 않게 올린 양은 부드럽게 줄인다(_lift).
var _lift := 0.0
func _clear_terrain(cp: Vector3, tgt: Vector3) -> Vector3:
	var need := 0.0
	var gc: float = world.ground_at(cp.x, cp.z) + 1.4
	need = maxf(need, gc - cp.y)
	for k in range(1, 8):
		var t := 0.22 + 0.78 * k / 8.0
		var q := tgt.lerp(cp, t)
		var g: float = world.ground_at(q.x, q.z) + 0.9
		if g > q.y:   # 이 표본에서 선분이 땅에 묻힘 → 카메라 높이 c가 tgt.y + (g − tgt.y)/t 이상이어야 한다
			need = maxf(need, tgt.y + (g - tgt.y) / t - cp.y)
	if need > _lift: _lift = need
	else: _lift = maxf(need, _lift - 0.25)
	cp.y += _lift
	return cp

# 연출 미끄러짐 시작: 지금 화면에서 출발해 sec초 동안 새 focus/override(또는 평소 시점)로 천천히 옮긴다.
# 부르기 전에 focus·override를 목표로 바꿔 둔다. to_point = null이면 평소 겨냥점(플레이어)으로.
func glide(sec: float, to_point = null, with_yaw := false) -> void:
	_gl = { t = 0.0, dur = sec, from = target, to = to_point, cur0 = cur.duplicate() }
	if with_yaw: _gl.yaw0 = yaw   # 대화 구도: yaw도 같은 시간에 smoothstep(talk_yaw ↔ 0)

func gliding() -> bool:
	return _gl != null

# 1인칭(region_main._fp_frame)이 쓴다: 미끄러짐에 목표 겨냥점이 있나 · 바로 끝내기(다음 update에서 목표에 닿는다) · 버리기
func glide_has_target() -> bool:
	return _gl != null and _gl.to != null

func glide_finish() -> void:
	if _gl != null: _gl.t = _gl.dur

func glide_cancel() -> void:
	_gl = null

# 지금 카메라 값이 대화 구도가 아닌 저작 연출(d.camera·shot·glide·사건 override/focus)인가 — lead 표시 focus(추격 앞보기)는 빼고
func authored() -> bool:
	if shot != null: return true
	if override != null and not is_same(override, talk_o): return true
	if focus != null and not is_same(focus, talk_f) and not bool(focus.get("lead", false)): return true
	return glide_has_target()
