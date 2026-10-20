# 건물 빌더 세계 반영(rollout) — 남원 배치(placement_namwon.json)의 정한 구역에서 옛 village/house_compound를 bldg/compound로 바꾼다(헤드리스).
#   tools/bldg/rollout.sh west [--revert]   (= godot --headless --path . -s res://tools/bldg/rollout.gd -- --district=west → python3 tools/bldg/rollout_apply.py)
#   · 구역 표(DISTRICTS)에 든 항목만 바꾼다. 세계 전체를 바꾸지 않는다.
#   · 같은 자리·같은 필지(옛 footprint = lot) 안에서: 옛 small(초가) → choga_house, small(기와) → giwa_house, medium → jungnong(기와면 giwa_house)
#     시드는 옛 시드에서 시작해 필지 안에 드는 첫 시드를 고른다(결정적).
#   · 바꾼 항목에 was(옛 kit·params)·rollout 표시를 남긴다 → --revert로 되돌린다.
#   · 이야기 인물 집(STORY_IDS)은 건드리지 않는다. 손대야 하면 spec을 통째로 적어(시드 고정) 바뀌지 않게 한다.
#   · namwon.py로 배치를 다시 만들면 이 변경이 지워진다 → 그 뒤 이 도구를 다시 돌린다.
extends SceneTree
const CP := preload("res://kit/bldg/compound.gd")

const FILE := "res://region_data/JL_NAMWON_UNBONG/placement_namwon.json"
const DISTRICTS := {
	# 서문 밖 장터길 민가 구역 — 남문 밖 장터에서 서문으로 돌아가는 장터길(namwon_market_lane) 서쪽과 성황사 오솔길 둘레
	west = { bbox = [-3420.0, 200.0, -3322.0, 365.0], tag = "building-rollout-1/west" },
}
const STORY_IDS := []   # 이 구역엔 이야기 인물 집이 없다(이겸 거처 −3192,700 · 월매 집 둘레 −3213,450 · 옥 −3175,230 은 구역 밖)

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var dname: String = args.get("district", "west")
	var D: Dictionary = DISTRICTS[dname]
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	var n := 0
	for it in d.items:
		var x := float(it.x); var z := float(it.z)
		var bb: Array = D.bbox
		if x < bb[0] or x > bb[2] or z < bb[1] or z > bb[3]: continue
		if String(it.id) in STORY_IDS: continue
		if args.has("revert"):
			if it.has("was"):
				it.kit = it.was.kit; it.params = it.was.params; it.footprint = it.was.footprint
				it.erase("was"); it.erase("rollout"); it.reverted = true; n += 1
			continue
		if String(it.kit) != "village/house_compound": continue
		var old: Dictionary = it.params
		var lot := Vector2(float(it.footprint[0]), float(it.footprint[1]))
		var giwa := String(old.get("roof", "")) == "giwa"
		var type := "giwa_house" if giwa else ("jungnong" if String(old.get("size", "small")) != "small" else "choga_house")
		var cls := "middle" if type != "choga_house" else "commoner"
		var pick := _fit(type, cls, int(old.seed), lot)
		if pick.is_empty() and type == "jungnong":
			type = "choga_house"; cls = "commoner"; pick = _fit(type, cls, int(old.seed), lot)
		if pick.is_empty():
			print("ROLLOUT %s 필지 %.1f×%.1f에 드는 %s 시드 없음 — 그대로 둠" % [it.id, lot.x, lot.y, type]); continue
		it.was = { kit = it.kit, params = old, footprint = it.footprint }
		it.kit = "bldg/compound"
		it.params = pick.params
		it.footprint = [snappedf(pick.fp.x, 0.1), snappedf(pick.fp.y, 0.1)]
		it.rollout = D.tag
		n += 1
		print("ROLLOUT %s %s → %s seed=%d fp=%.1f×%.1f (필지 %.1f×%.1f)" % [it.id, "giwa" if giwa else String(old.get("size", "")), type, pick.params.seed, pick.fp.x, pick.fp.y, lot.x, lot.y])
	# 바뀐 항목만 따로 적는다 → tools/bldg/rollout_apply.py가 원본 json 형식(들여쓰기 1, 키 순서) 그대로 끼워 넣는다
	var ch := []
	for it in d.items:
		if it.has("was") or it.has("reverted"): ch.append(it)
	var out: String = args.get("out", "res://tools/bldg/rollout_%s.json" % dname)
	if not args.has("dry"):
		var f := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
		f.store_string(JSON.stringify({ district = dname, revert = args.has("revert"), items = ch }, " ", false))
		f.close()
	print("ROLLOUT done district=%s changed=%d%s" % [dname, n, " (dry)" if args.has("dry") else ""])
	quit()

static func _fit(type: String, cls: String, seed0: int, lot: Vector2) -> Dictionary:
	for k in 300:
		var p := { type = type, region = "south", cls = cls, seed = seed0 * 7 + k, lot = [lot.x, lot.y] }
		var fp: Vector2 = CP.footprint(p)
		if fp.x <= lot.x + 0.05 and fp.y <= lot.y + 0.05:
			return { params = p, fp = fp }
	return {}
