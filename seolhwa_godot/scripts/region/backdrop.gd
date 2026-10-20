# 먼 산(배산임수) — 권역 밖 능선(region_data/<권역>/backdrop.json)을 플레이어 자리에서 본 높이각(방위 1024칸 × 세 겹)으로 그려
# 하늘 그림판(shaders/sky_backdrop.gdshader)의 능선 세 겹에 얹는다(u_prof). 지오메트리가 없어 카메라 먼 끝(1인칭 260m)·
# 물 반사·지도와 무관하고, 플레이어가 60m 넘게 움직이면 다시 센다(10ms 안팎).
#   겹 0 = 가장 먼 겹(옅은 먹·높이 그대로) · 1 · 2 = 가까운 겹(짙은 먹). 칸 값 = 높이각의 사인(e = d.y) — 셰이더와 같은 단위.
#   권역 지형(원경 32m 격자)이 먼 산 앞을 가리는 것은 깊이로 저절로(하늘 그림판은 가장 먼 깊이에 그린다).
extends RefCounted

const N := 1024
const EMPTY := -0.25
var main
var ridges: Array = []      # [{layer, half_w, samples: [Vector3(x, z, h)]}]
var tex: ImageTexture
var img: Image
var last := Vector2(INF, INF)
var on := false

func _init(m, data_dir: String) -> void:
	main = m
	var p := data_dir.path_join("backdrop.json")
	if not FileAccess.file_exists(p): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary): return
	for r in d.get("ridges", []):
		var pts: Array = r.pts
		var smp := []
		# 꼭짓점 사이를 60m마다 + 작은 봉우리 굴곡(시드 고정 — 이름 해시)
		var seed := float(hash(String(r.get("name", ""))) % 1000) * 0.37
		for i in range(pts.size() - 1):
			var a := Vector3(pts[i][0], pts[i][1], pts[i][2]); var b := Vector3(pts[i + 1][0], pts[i + 1][1], pts[i + 1][2])
			var n := maxi(1, int(Vector2(b.x - a.x, b.y - a.y).length() / 60.0))
			for k in n:
				var q := a.lerp(b, float(k) / n)
				var t := float(smp.size())
				q.z *= 1.0 + 0.08 * sin(t * 0.37 + seed) + 0.05 * sin(t * 1.13 + seed * 2.0)
				smp.append(q)
		var l: Array = pts[pts.size() - 1]
		smp.append(Vector3(l[0], l[1], l[2]))
		ridges.append({ layer = int(r.get("layer", 1)), half_w = float(r.get("half_w", 1000.0)), samples = smp })
	if ridges.is_empty(): return
	img = Image.create(N, 1, false, Image.FORMAT_RGBF)
	tex = ImageTexture.create_from_image(img)
	on = true
	main.sky_mat.set_shader_parameter("u_prof", tex)
	main.sky_mat.set_shader_parameter("u_prof_on", 1.0)

# pos = 눈(카메라) 자리 — 3인칭 카메라·촬영 카메라가 플레이어에서 떨어져 있어도 그 자리에서 본 높이각
var last_y := INF
func update(pos: Vector3, force := false) -> void:
	if not on: return
	var p2 := Vector2(pos.x, pos.z)
	if not force and p2.distance_to(last) < 60.0 and absf(pos.y - last_y) < 25.0: return
	last = p2; last_y = pos.y
	var prof := []
	for li in 3:
		var a := PackedFloat32Array(); a.resize(N); a.fill(EMPTY)
		prof.append(a)
	var eye := pos.y
	for r in ridges:
		var arr: PackedFloat32Array = prof[clampi(r.layer, 0, 2)]
		var hw: float = r.half_w
		for s in r.samples:
			var dx: float = s.x - pos.x; var dz: float = s.y - pos.z
			var dist := sqrt(dx * dx + dz * dz)
			if dist < 50.0: continue
			var dh: float = s.z - eye
			var e_top := dh / sqrt(dist * dist + dh * dh)
			var az := atan2(dx, -dz)   # 셰이더 az = atan(d.x, -d.z)
			var c := (az / TAU + 0.5) * N
			# 꼭대기에서 산발치(반폭 hw, 높이 0)까지 높이각이 줄어든다 — 방위로 반폭만큼 퍼진 세모
			var spread := atan2(hw, dist) / TAU * N
			var e_base := (-eye) / sqrt(dist * dist + eye * eye)
			var i0 := int(floor(c - spread)); var i1 := int(ceil(c + spread))
			for i in range(i0, i1 + 1):
				var f := 1.0 - absf(float(i) - c) / maxf(spread, 0.5)
				if f <= 0.0: continue
				# 둥근 산꼭대기(먹 그림 산처럼 어깨가 부드럽게): f² 대신 smooth
				var g := f * f * (3.0 - 2.0 * f)
				var e := lerpf(e_base, e_top, g)
				var ii := posmod(i, N)
				if e > arr[ii]: arr[ii] = e
	# 이웃 칸 고르게(±3칸 가중 평균) — 표본마다 뾰족한 봉우리 끝·칸 사이 턱이 먹 그림 능선처럼 부드럽게
	for li in 3:
		var a: PackedFloat32Array = prof[li]
		var b := a.duplicate()
		for i in N:
			if a[i] <= EMPTY + 1e-4: continue
			var s := 0.0; var wsum := 0.0
			for k in range(-3, 4):
				var v: float = a[posmod(i + k, N)]
				if v <= EMPTY + 1e-4: continue
				var w := 4.0 - absf(float(k))
				s += v * w; wsum += w
			b[i] = s / wsum
		prof[li] = b
	for i in N:
		img.set_pixel(i, 0, Color(prof[0][i], prof[1][i], prof[2][i]))
	tex.update(img)
