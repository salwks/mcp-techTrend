# 고정 시점 카메라 — 웹 core/camera.js 이식. yaw 고정(남→북), 구역·실내에 따라 pitch/거리/fov만 부드럽게 바뀐다.
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

func _init(cam: Camera3D, w: World) -> void:
	camera = cam
	world = w

func params(pos: Vector3, interior) -> Dictionary:
	var p := DEFAULT.duplicate()
	if override != null:
		p.merge(override, true); return p
	if mode == "fixed": return p
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
	var kf := 1.0 if snap else 1.0 - exp(-dt * 4.0)
	target += (Vector3(tx, ty, tz) - target) * kf
	var pr := deg_to_rad(cur.pitch)
	var d: float = cur.distance
	camera.position = Vector3(target.x, target.y + sin(pr) * d, target.z + cos(pr) * d)
	camera.look_at(target, Vector3.UP)
	camera.fov = cur.fov
