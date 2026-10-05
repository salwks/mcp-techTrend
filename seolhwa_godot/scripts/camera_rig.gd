# 고정 시점 카메라 — 웹 core/camera.js 이식. yaw 고정(남→북), 구역·실내에 따라 pitch/거리/fov만 부드럽게 바뀐다.
# 배를 탈 때(sailing)만 풍경 시점: 낮은 pitch(약 13°)·조금 넓은 fov로 배 뒤·옆에서 뱃길 방향(+ 높은 기슭 쪽)을 보며 yaw가 배를
# 따라 부드럽게 돈다. 내리면 yaw 0(남→북 고정)으로 천천히 돌아온다.
# 말을 탈 때(riding — scripts/region/horse_ride.gd)도 같은 풍경 시점: 배보다 조금 높고(20°) 걷기보다 멀리(21m), 말 뒤에서 볼 쪽으로
# 28° 비켜 선다. ride_k(0~1)로 걷기 시점과 섞는다(사건·어귀 앞 감속하며 가까워짐). shake_y: 말 걸음 흔들림(설정 '이동 카메라 흔들림').
class_name CameraRig
extends RefCounted

const DEFAULT := { pitch = 38.0, distance = 16.0, fov = 30.0, lookAhead = 1.2, aimZ = 0.0 }   # aimZ: 겨냥점을 z로 옮김(−=북쪽, 구역 값)

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
# 연출 미끄러짐(glide): 겨냥점·pitch·거리·fov를 시작값에서 목표값으로 smoothstep으로 천천히 옮긴다(천천히 떠나 천천히 닿는다).
# 목표 겨냥점이 null이면 매 프레임 계산한 평소 자리(플레이어)로 돌아온다. 이야기 컷(전경 등)이 '쉭' 하고 튀지 않게.
var _gl = null
const RIDE_SIDE_DEG := 28.0
# 각본 시점(shot): 컷신 한 장면에서만 — 카메라 자리(pos)와 바라볼 점(look), fov를 그대로 쓴다(하늘을 올려다보는 동아줄 장면 등).
# 평소 시점 계산(pitch·distance·yaw)은 건너뛴다. null로 되돌리면 다음 프레임부터 평소 시점(되돌릴 때는 암전 속에서).
var shot = null   # { pos: Vector3, look: Vector3, fov: float }

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
	var ky := 1.0 if snap else 1.0 - exp(-dt * (0.45 if riding else (1.1 if sailing else 1.6)))   # 말: 천천히 돈다
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
	cp.y += shake_y
	camera.position = cp
	camera.look_at(target, Vector3.UP)
	camera.fov = cur.fov

# 연출 미끄러짐 시작: 지금 화면에서 출발해 sec초 동안 새 focus/override(또는 평소 시점)로 천천히 옮긴다.
# 부르기 전에 focus·override를 목표로 바꿔 둔다. to_point = null이면 평소 겨냥점(플레이어)으로.
func glide(sec: float, to_point = null) -> void:
	_gl = { t = 0.0, dur = sec, from = target, to = to_point, cur0 = cur.duplicate() }

func gliding() -> bool:
	return _gl != null
