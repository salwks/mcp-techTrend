# 건물 서술자 내보내기(WP7a, 헤드리스): 빌더 프리셋을 building-descriptor/1 JSON으로.
#   godot --headless --path . -s res://tools/bldg/descriptor_export.gd -- --out=/tmp/seolhwa_desc [--set=presets|samples] [--only=choga/south/1[/int]]
#        [--regionprofile=<settlement 계획서 plan.json 또는 RegionProfile JSON>]
#   --set=presets: 22 프리셋 × 지역 5 × 씨앗 1–3(+ 걸어 들어가는 집 5종 × 남부·중부) · samples: tools/bldg/descriptors/samples에 둔 4채
#   RegionProfile을 주면 그 scale_policy.building.factor를 기록하고 빌더 배율과 다르면 실패(종료 코드 2) — 두 번 곱하지 않는다.
extends SceneTree
const DS := preload("res://kit/bldg/descriptor.gd")
const S := preload("res://kit/bldg/_spec.gd")

const TYPES := ["choga", "jumak", "sijeon", "anchae", "sarang", "haengrang", "sadang", "gotgan", "dwitgan", "oeyang", "araechae", "giwajip",
	"dongheon", "gaeksa", "daeseong", "gangdang", "jeongja", "nugak", "mill", "smithy", "daeung"]
const REGIONS := ["south", "central", "north", "jeju", "mountain"]
const SAMPLES := ["choga/south/1/int", "choga/central/1", "anchae/central/1", "sarang/south/1"]

static func params_of(key: String) -> Dictionary:
	var q := key.split("/")
	var p := { type = q[0], region = q[1], seed = int(q[2]) }
	if q.size() > 3 and q[3] == "int": p.interior = true
	p.stable_id = key.replace("/", ".")
	return p

static func load_profile(path: String) -> Dictionary:
	if path == "": return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary): return {}
	if d.has("region_profile"): return d.region_profile
	return d

static func keys_for(set: String) -> Array:
	var out := []
	if set == "samples": return SAMPLES.duplicate()
	for t in TYPES:
		for rg in REGIONS:
			for s in [1, 2, 3]: out.append("%s/%s/%d" % [t, rg, s])
	for t in ["choga", "jumak", "gotgan", "araechae", "oeyang", "anchae", "sarang"]:
		for rg in ["south", "central"]:
			for s in [1, 2]: out.append("%s/%s/%d/int" % [t, rg, s])
	return out

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var out: String = args.get("out", "/tmp/seolhwa_desc")
	if out.begins_with("res://"): out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var prof := load_profile(String(args.get("regionprofile", "")))
	if not prof.is_empty():
		var f := float(prof.scale_policy.building.factor)
		if absf(f - S.profile_factor()) > 1e-6:
			printerr("DESCEXPORT scale mismatch: RegionProfile %.4f vs builder %.4f" % [f, S.profile_factor()])
			quit(2); return
	var keys: Array = [String(args.only)] if args.has("only") else keys_for(String(args.get("set", "presets")))
	var n := 0; var bytes := 0
	var t0 := Time.get_ticks_msec()
	for k in keys:
		var d := DS.describe(params_of(k), prof)
		var s := JSON.stringify(d, " ", true)
		var fn := out.path_join(String(k).replace("/", "_") + ".json")
		var fa := FileAccess.open(fn, FileAccess.WRITE)
		fa.store_string(s + "\n"); fa.close()
		n += 1; bytes += s.length()
	print("DESCEXPORT n=%d bytes=%d ms=%d out=%s factor=%.3f profile=%s" % [n, bytes, Time.get_ticks_msec() - t0, out, S.profile_factor(), "given" if not prof.is_empty() else "rules-default"])
	quit(0)
