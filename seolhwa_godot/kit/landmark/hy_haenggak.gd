# 궁궐 행각(回廊) 직선 모듈 — 안쪽(+z)으로 트인 기둥 줄 + 바깥(−z) 벽, 맞배. 근정전·인정전 마당 둘레에 이어 붙인다. 로컬 x 방향 length m.
# params: seed, length(24), bay(3.0), depth(4.0), open_side("front"|"both")
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 24.0)); var bay: float = float(params.get("bay", 3.0)); var d: float = float(params.get("depth", 4.0))
	var n := maxi(1, roundi(L / bay))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var both: bool = str(params.get("open_side", "front")) == "both"
	Hub.haenglang(b, r, rng, n, L / n, d, "none", 0.0, 0.0, 3.0, 0.45, { back = "none" if both else "wall", sides = "none", col_color = Co.DAN_R, band = Co.DAN_G, bracket = "ikgong", floor = false, roof_nx = n * 2 })
	return {
		node = Co.node2("행각", b, r), colliders = [] if both else [{ type = "box", minX = -L / 2, maxX = L / 2, minZ = -d / 2 - 0.3, maxZ = -d / 2 + 0.2 }],
		lights = [], occluder = true, footprint = Vector2(L + 1.0, d + 2.0), anchors = {},
	}
