# 건물 빌더 갤러리 배치 만들기(헤드리스) — 남원 권역 빈 터(읍성 서쪽 풀밭)에 새 빌더 건물·묶음과 기존 키트(비교용)를
# 줄지어 놓는 배치 파일과, 찍기 도구(scripts/region/bldg_gallery.gd)가 읽는 목록(manifest)을 만든다.
#   godot --headless --path . -s res://tools/bldg/gallery_place.gd -- [--set=gallery|block] [--out=res://shots/building_builder/_place/]
#   --set=gallery  : 다양성·비교·실내(기본) — 터 가운데 (-3607, 526), 330×230m
#   --set=block    : 성능 시험용 30채 마을 한 구역(남원 읍성 서쪽, 고을 사람이 보는 거리) — (-3487, 526)
# 배치 파일은 shots/ 아래(깃 밖) — 실제 세계 배치(region_data)는 건드리지 않는다.
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const CP := preload("res://kit/bldg/compound.gd")
const S := preload("res://kit/bldg/_spec.gd")

var items := []
var manifest := []

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var set: String = args.get("set", "gallery")
	var out: String = args.get("out", "res://shots/building_builder/_place_%s/" % set)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	if set == "block": _block()
	elif set == "integ": _put(_e("integ_yangban", "통합 점검 양반가", "integ", "bldg/compound", { type = "yangban", region = "south", seed = 3, interior = true }), -3487.0, 526.0)
	else: _gallery()
	var f := FileAccess.open(ProjectSettings.globalize_path(out.path_join("placement_bldg_%s.json" % set)), FileAccess.WRITE)
	f.store_string(JSON.stringify({ note = "건물 빌더 시험 배치(" + set + ") — tools/bldg/gallery_place.gd가 만든다", items = items }, "\t"))
	f.close()
	var g := FileAccess.open(ProjectSettings.globalize_path(out.path_join("manifest.json")), FileAccess.WRITE)
	g.store_string(JSON.stringify({ set = set, items = manifest }, "\t"))
	g.close()
	print("GPLACE set=%s items=%d out=%s" % [set, items.size(), out])
	quit()

func _fp(kit: String, params: Dictionary) -> Vector2:
	if kit == "bldg/building": return B.footprint(params)
	if kit == "bldg/compound": return CP.footprint(params)
	# 기존 키트: 지어서 잰다
	var info: Dictionary = load("res://kit/%s.gd" % kit).build(params)
	var fp := Vector2(info.get("footprint", Vector2(10, 8)))
	if info.get("node") is Node: (info.node as Node).free()
	return fp

# 줄 채우기(왼→오, 줄이 차면 다음 줄). 줄 위쪽(z 작은 쪽)부터
func _rows(list: Array, cx: float, cz: float, W: float, gap := 6.0) -> float:
	var x := cx - W / 2; var z := cz; var row_d := 0.0
	for e in list:
		var fp: Vector2 = e.fp
		if x + fp.x > cx + W / 2 and x > cx - W / 2 + 0.1:
			x = cx - W / 2; z += row_d + gap + 10.0; row_d = 0.0
		var px := x + fp.x / 2; var pz := z + fp.y / 2
		_put(e, px, pz)
		x += fp.x + gap
		row_d = maxf(row_d, fp.y)
	return z + row_d

func _put(e: Dictionary, x: float, z: float) -> void:
	var id: String = e.id
	var it := { id = id, kit = e.kit, params = e.params, x = snappedf(x, 0.1), z = snappedf(z, 0.1), ry = 0.0, flatten = true, clear_veg = true }
	items.append(it)
	var m := { id = id, label = e.label, group = e.group, kit = e.kit, params = e.params, x = it.x, z = it.z, fp = [e.fp.x, e.fp.y] }
	if e.has("inside"): m.inside = e.inside
	if e.has("refs"): m.refs = e.refs
	if e.has("approach"): m.approach = e.approach
	manifest.append(m)

func _e(id: String, label: String, group: String, kit: String, params: Dictionary) -> Dictionary:
	var e := { id = id, label = label, group = group, kit = kit, params = params, fp = _fp(kit, params) }
	if kit == "bldg/building":
		var sp := S.resolve(params)
		e.refs = sp.refs
		# 실내 찍기 자리: 첫 날개의 방(없으면 대청) 가운데(건물 로컬)
		var w: Dictionary = sp.wings[0]
		var L := 0.0
		for b in w.bays: L += float(b.w)
		var x := -L / 2
		var pick := []
		for b in w.bays:
			if b.fn in ["room", "kitchen", "hall", "maru", "shrine"]: pick.append([b.fn, x + float(b.w) / 2])
			x += float(b.w)
		e.inside = pick
	elif kit == "bldg/compound":
		e.refs = [{ choga_house = "choga", jungnong = "jungnong", yangban = "yangban", jumak_yard = "jumak", gate_demo = "entrance" }.get(String(params.type), "choga")]
		if params.type in ["yangban", "jungnong", "choga_house"]:
			# 진입 길(대문 → 마당 → 중문·내외담 → 안마당) 점: 묶음 로컬
			e.approach = _approach_path(params)
	return e

func _gallery() -> void:
	var V := []
	# 1) 다양성: 서민 초가(권역별) · 양반가 · 주막 · 시전 · 관아·객사·향교·서원·정자·누각·방앗간·대장간·절 · 중농·서민 묶음
	for s in [1, 2, 3]: V.append(_e("bg_choga_s%d" % s, "서민 초가 남부 #%d" % s, "variety", "bldg/building", { type = "choga", region = "south", seed = s }))
	V.append(_e("bg_choga_c1", "서민 초가 중부 ㄱ자 #1", "variety", "bldg/building", { type = "choga", region = "central", seed = 1 }))
	V.append(_e("bg_choga_c2", "서민 초가 중부 ㄱ자 #2", "variety", "bldg/building", { type = "choga", region = "central", seed = 2 }))
	V.append(_e("bg_choga_n1", "서민 초가 북부 겹집", "variety", "bldg/building", { type = "choga", region = "north", seed = 1 }))
	V.append(_e("bg_choga_j1", "서민 초가 제주", "variety", "bldg/building", { type = "choga", region = "jeju", seed = 1 }))
	V.append(_e("bg_choga_m1", "산간 너와집", "variety", "bldg/building", { type = "choga", region = "mountain", seed = 1 }))
	for s in [1, 2, 3]: V.append(_e("bg_jumak_%d" % s, "주막 #%d" % s, "variety", "bldg/compound", { type = "jumak_yard", region = "south" if s < 3 else "central", seed = s }))
	for s in [1, 2, 3]: V.append(_e("bg_sijeon_%d" % s, "시전 행랑 #%d" % s, "variety", "bldg/building", { type = "sijeon", region = "central" if s > 1 else "south", seed = s }))
	for s in [1, 2]: V.append(_e("bg_dongheon_%d" % s, "관아 동헌 #%d" % s, "variety", "bldg/building", { type = "dongheon", region = "south", seed = s }))
	V.append(_e("bg_gaeksa_1", "객사", "variety", "bldg/building", { type = "gaeksa", region = "south", seed = 1 }))
	V.append(_e("bg_daeseong_1", "향교 대성전", "variety", "bldg/building", { type = "daeseong", region = "south", seed = 1 }))
	V.append(_e("bg_gangdang_1", "서원 강당", "variety", "bldg/building", { type = "gangdang", region = "south", seed = 1 }))
	V.append(_e("bg_jeongja_1", "정자 #1", "variety", "bldg/building", { type = "jeongja", region = "south", seed = 1 }))
	V.append(_e("bg_jeongja_2", "정자 #2", "variety", "bldg/building", { type = "jeongja", region = "south", seed = 4 }))
	V.append(_e("bg_nugak_1", "누각", "variety", "bldg/building", { type = "nugak", region = "south", seed = 1 }))
	for s in [1, 2]: V.append(_e("bg_mill_%d" % s, "물레방앗간 #%d" % s, "variety", "bldg/building", { type = "mill", region = "south", seed = s }))
	for s in [1, 2]: V.append(_e("bg_smithy_%d" % s, "대장간 #%d" % s, "variety", "bldg/building", { type = "smithy", region = "south", seed = s }))
	V.append(_e("bg_daeung_1", "절 대웅전", "variety", "bldg/building", { type = "daeung", region = "south", seed = 1 }))
	var C := []
	for s in [1, 2, 3]: C.append(_e("bg_yangban_%d" % s, "양반가 묶음 #%d" % s, "variety", "bldg/compound", { type = "yangban", region = "south" if s == 1 else "central", seed = s }))
	for s in [1, 2]: C.append(_e("bg_jungnong_%d" % s, "중농 묶음 #%d" % s, "variety", "bldg/compound", { type = "jungnong", region = "south" if s == 1 else "central", seed = s }))
	C.append(_e("bg_chogahouse_1", "서민 초가 묶음", "variety", "bldg/compound", { type = "choga_house", region = "south", seed = 1 }))
	# 2) 비교: 기존 키트(같은 자리 줄) ↔ 새 빌더
	var K := []
	K.append(_e("cmp_old_choga", "기존 village/choga", "compare", "village/choga", { seed = 1 }))
	K.append(_e("cmp_new_choga", "새 빌더 초가(남부)", "compare", "bldg/building", { type = "choga", region = "south", seed = 2 }))
	K.append(_e("cmp_old_choga_il", "기존 village/choga il", "compare", "village/choga", { seed = 2, plan = "il" }))
	K.append(_e("cmp_new_choga_il", "새 빌더 초가 툇마루", "compare", "bldg/building", { type = "choga", region = "south", seed = 3 }))
	K.append(_e("cmp_old_giwa", "기존 village/giwa", "compare", "village/giwa", { seed = 1, plain = true }))
	K.append(_e("cmp_new_giwa", "새 빌더 안채(기와)", "compare", "bldg/building", { type = "anchae", region = "south", seed = 1 }))
	K.append(_e("cmp_old_jumak", "기존 village/jumak", "compare", "village/jumak", { seed = 1 }))
	K.append(_e("cmp_new_jumak", "새 빌더 주막", "compare", "bldg/building", { type = "jumak", region = "south", seed = 1 }))
	# 2b) 대문 종류(문 + 양옆 담 토막)
	var Gs := []
	var gnames := { sarip = "사립문(싸리울)", chomun = "초가 대문", ilgak = "일각문", pyeong = "평대문", soseul = "솟을대문", jungmun = "중문", hyeop = "협문", samun = "관아 삼문(솟을삼문)", hongsal = "홍살문" }
	for gt in ["sarip", "chomun", "ilgak", "pyeong", "soseul", "jungmun", "hyeop", "samun", "hongsal"]:
		Gs.append(_e("gate_" + gt, String(gnames[gt]), "gate", "bldg/compound", { type = "gate_demo", gate = gt, seed = 1 }))
	Gs.append(_e("gate_entry", "마을 어귀(장승·서낭·우물)", "gate", "bldg/compound", { type = "village_entry", seed = 1 }))
	# 3) 실내(잘라 보기)
	var I := []
	I.append(_e("int_choga", "실내: 초가 방·부엌", "interior", "bldg/building", { type = "choga", region = "south", seed = 1, interior = true }))
	I.append(_e("int_anchae", "실내: 양반가 안채(안방·대청)", "interior", "bldg/building", { type = "anchae", region = "south", seed = 2, interior = true }))
	I.append(_e("int_sarang", "실내: 사랑채(사랑방)", "interior", "bldg/building", { type = "sarang", region = "south", seed = 1, interior = true }))
	I.append(_e("int_jumak", "실내: 주막(봉놋방·부엌)", "interior", "bldg/building", { type = "jumak", region = "south", seed = 2, interior = true }))
	var cx := -3607.0; var cz := 526.0 - 112.0
	var z := _rows(V, cx, cz, 320.0)
	z = _rows(C, cx, z + 16.0, 320.0)
	z = _rows(K, cx, z + 16.0, 320.0)
	z = _rows(Gs, cx, z + 12.0, 320.0, 8.0) + 14.0   # 다음 줄(실내)이 대문 마을 카메라 자리에 걸리지 않게
	z = _rows(I, cx, z + 16.0, 320.0)
	print("GPLACE gallery z_end=%.1f (터 끝 %.1f)" % [z, 526.0 + 115.0])

# 성능 시험 마을 블록: 30채(서민 초가·중농·주막·양반가·시전 섞임) — 길을 사이에 두고 두 줄 + 안쪽 줄
func _block() -> void:
	var L := []
	var types := [["choga", "south"], ["choga", "central"], ["choga", "south"], ["jumak", "south"], ["choga", "south"], ["gotgan", "south"],
		["araechae", "south"], ["choga", "south"], ["sarang", "south"], ["anchae", "south"], ["sijeon", "south"], ["choga", "central"]]
	var rr := Kit.Rng.new(4242)
	var n := 0
	while n < 30:
		var t: Array = types[n % types.size()]
		L.append(_e("blk_%02d" % n, "%s %d" % [t[0], n], "block", "bldg/building", { type = t[0], region = t[1], seed = 100 + n }))
		n += 1
	_rows(L, -3487.0, 526.0 - 45.0, 105.0, 3.0)

# 묶음의 진입 길: [[이름, x, z] …] — 골목 → 대문 바깥 → 문지방 넘어 → 마당 → (중문) → 안마당
func _approach_path(params: Dictionary) -> Array:
	var p := CP.plan(params)
	var gate = null; var jm = null; var nae = null; var an = null; var hr = null
	for e in p.pieces:
		match String(e.tag):
			"gate": gate = e
			"jungmun": jm = e
			"naeoedam": nae = e
			"anchae": an = e
			"haengrang": hr = e
	var gx := 0.0; var gz := 0.0
	if gate != null: gx = float(gate.x); gz = float(gate.z)
	elif hr != null:
		var sp := S.resolve(hr.params)
		var bays: Array = sp.wings[0].bays
		var Lh := 0.0
		for b in bays: Lh += float(b.w)
		var acc := 0.0
		for i in int(sp.get("gate_i", 0)): acc += float(bays[i].w)
		gx = float(hr.x) - Lh / 2 + acc + float(bays[int(sp.get("gate_i", 0))].w) / 2
		var D := 0.0
		for d in sp.wings[0].depth: D += float(d)
		gz = float(hr.z) + D / 2
	var out := [["alley", gx, gz + 7.0], ["gate_out", gx, gz + 1.2], ["gate_in", gx, gz - 1.6]]
	if hr != null: out[2] = ["gate_in", gx, gz - 4.0]
	if jm != null:
		out.append(["jungmun_out", float(jm.x), float(jm.z) + 1.4])
		out.append(["jungmun_in", float(jm.x), float(jm.z) - 1.0])
	if nae != null:
		var nx := (float(nae.params.ax) + float(nae.params.bx)) / 2; var nz := float(nae.params.az)
		var side := 1.0 if (jm == null and gx <= nx) or (jm != null and float(jm.x) <= nx) else -1.0
		if jm != null: out.append(["naeoe", nx + 2.4 * side, float(jm.z) - 1.0])   # 중문 안: 내외담 옆으로 돌아 안마당
		else: out.append(["naeoe", nx + 2.4 * side, nz + 1.0])
	if an != null:
		var ab := B.bounds(S.resolve(an.params))
		out.append(["anmadang", float(an.x) + ab.get_center().x * 0.0, float(an.z) + ab.end.y + 2.5])
	return out
