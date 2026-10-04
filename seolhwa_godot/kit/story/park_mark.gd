# 박규상 객주 `朴` 표식(시나리오 v2.2) — 새 모델 없이 기존 소품 위에 얹는 종이·자루 표식 판.
# 그림: assets/story/park_mark.png(tools/story/make_park_mark.py). 같은 그래픽 언어를 네 가지로:
#   kind: seal(작은 인장) · slip(반쯤 찢긴 납품표 — 바닥에 눕힘) · wrap(곡물 자루·포장 표식 — 세움) · waybill(운송장 한 칸)
#   params: size(긴 변 m), upright(세우기, 기본 wrap만), tilt(눕힌 판의 기울기 rad), seed
extends RefCounted

const TEX_PATH := "res://assets/story/park_mark.png"
const REGIONS := {   # 아틀라스 칸(px): x, y, w, h — 512×256
	seal = [0, 0, 128, 128], slip = [128, 0, 128, 256], wrap = [256, 0, 128, 128], waybill = [384, 0, 128, 256],
}
static var _mat: StandardMaterial3D

static func _material() -> StandardMaterial3D:
	if _mat != null: return _mat
	var img := Image.load_from_file(ProjectSettings.globalize_path(TEX_PATH))
	_mat = StandardMaterial3D.new()
	if img != null and not img.is_empty():
		img.generate_mipmaps()
		_mat.albedo_texture = ImageTexture.create_from_image(img)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat.alpha_scissor_threshold = 0.4
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.roughness = 1.0
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _mat

static func build(params: Dictionary) -> Dictionary:
	var kind := String(params.get("kind", "seal"))
	var r: Array = REGIONS.get(kind, REGIONS.seal)
	var size := float(params.get("size", { seal = 0.08, slip = 0.3, wrap = 0.32, waybill = 0.34 }.get(kind, 0.2)))
	var aspect := float(r[2]) / float(r[3])
	var w := size * aspect if aspect < 1.0 else size
	var h := size if aspect < 1.0 else size / aspect
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var mat := _material().duplicate() as StandardMaterial3D
	mat.uv1_scale = Vector3(float(r[2]) / 512.0, float(r[3]) / 256.0, 1.0)
	mat.uv1_offset = Vector3(float(r[0]) / 512.0, float(r[1]) / 256.0, 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root := Node3D.new()
	root.name = "park_mark_" + kind
	root.add_child(mi)
	if bool(params.get("upright", kind == "wrap")):
		mi.position = Vector3(0, h * 0.5, 0)
	else:
		mi.rotation = Vector3(-PI * 0.5 + float(params.get("tilt", 0.0)), 0, 0)   # 바닥에 눕힘(앞면이 위)
		mi.position = Vector3(0, 0.004, 0)
	return { node = root }
