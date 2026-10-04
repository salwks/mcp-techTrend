# 고정 시점 카메라 — 웹 core/camera.js 이식. yaw 고정(남→북), 구역·실내에 따라 pitch/거리/fov만 부드럽게 바뀐다.
# 배를 탈 때(sailing)만 풍경 시점: 낮은 pitch(약 13°)·조금 넓은 fov로 배 뒤·옆에서 뱃길 방향(+ 높은 기슭 쪽)을 보며 yaw가 배를
# 따라 부드럽게 돈다. 내리면 yaw 0(남→북 고정)으로 천천히 돌아온다.
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
	var ky := 1.0 if snap else 1.0 - exp(-dt * (1.1 if sailing else 1.6))
	yaw = wrapf(yaw + wrapf(want_yaw - yaw, -PI, PI) * ky, -PI, PI)
	if absf(yaw) < 1e-4 and want_yaw == 0.0: yaw = 0.0
	var kf := 1.0 if snap else 1.0 - exp(-dt * 4.0)
	target += (Vector3(tx, ty, tz) - target) * kf
	var pr := deg_to_rad(cur.pitch)
	var d: float = cur.distance
	var off := Vector3(sin(yaw) * cos(pr) * d, sin(pr) * d, cos(yaw) * cos(pr) * d)
	if yaw == 0.0: off = Vector3(0, sin(pr) * d, cos(pr) * d)   # 기본 시점은 예전 식 그대로
	var cp := target + off
	if sailing or yaw != 0.0:   # 낮은 시점: 기슭·둑 속으로 들어가지 않게
		cp.y = maxf(cp.y, world.height_at(cp.x, cp.z) + 1.6)
	camera.position = cp
	camera.look_at(target, Vector3.UP)
	camera.fov = cur.fov
