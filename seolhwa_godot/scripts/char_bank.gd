# 인물 빌더 프레임 묶음(data/chars/<set>.json, tools/export_char_frames.js가 굽는다) — id로 인물을 찾는다.
#   꼴: { format:"chars-1", set, px, pages:["chars/<set>_0.png"…](2048² 공유 아틀라스), chars:{ id:{ role, template, sex, age, name, spec, clips } } }
#   clips는 SpriteChar 프레임 꼴 그대로라서, 올리면 id가 곧 SpriteChar 종류(kind)다(SpriteChar.new(id)).
#   한 묶음의 인물들은 페이지를 함께 쓴다 — 한 번 읽은 페이지 텍스처는 묶음 안 모든 인물이 공유한다.
# 쓰기:
#   CharBank.ensure(id)                  → 그 묶음 페이지를 (동기) 읽고 SpriteChar._banks에 올림. 이야기·군중처럼 몇 명만 쓸 때
#   CharBank.bank_src(set, ids)          → { id: {pages:[파일], clips} } — 작업 스레드에서 페이지를 읽는 쪽(npc_ambient)이 직접 올린다
#   CharBank.ids(set, role)              → 그 역할(npc_ambient 종류 이름) 인물 id들
#   CharBank.region_set(region_id)       → "amb_JL" 같은 권역 고을 사람 묶음 이름(없으면 "")
# 묶음 파일이 없으면(굽기 전) 모두 빈 값 — 부르는 쪽은 예전 그림(frames_npc·frames_amb)으로 돌아간다.
extends RefCounted

const DIR := "res://data/chars/"
const REGIONS := ["JL", "GG", "GS", "GW", "HH", "PA", "HG", "JJ"]

static var _sets := {}       # set → 묶음(읽은 JSON) 또는 null(없음)
static var _index := {}      # id → set
static var _scanned := false
static var _tex := {}        # 페이지 파일 → ImageTexture(묶음끼리도 공유)

static func manifest(set_name: String) -> Dictionary:
	if _sets.has(set_name):
		return _sets[set_name] if _sets[set_name] != null else {}
	var path := DIR + set_name + ".json"
	var d = null
	if FileAccess.file_exists(path):
		d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (d is Dictionary) or String(d.get("format", "")) != "chars-1": d = null
	_sets[set_name] = d
	if d != null:
		for id in d.chars: _index[id] = set_name
	return d if d != null else {}

# data/chars/*.json 을 모두 훑어 id → 묶음 표를 만든다(처음 한 번)
static func scan() -> void:
	if _scanned: return
	_scanned = true
	var da := DirAccess.open(DIR)
	if da == null: return
	for f in da.get_files():
		if f.ends_with(".json"): manifest(f.get_basename())

static func has(id: String) -> bool:
	scan()
	return _index.has(id)

static func set_of(id: String) -> String:
	scan()
	return String(_index.get(id, ""))

static func info(id: String) -> Dictionary:
	var s := set_of(id)
	if s == "": return {}
	return manifest(s).chars.get(id, {})

static func ids(set_name: String, role := "") -> Array:
	var m := manifest(set_name)
	var out := []
	if m.is_empty(): return out
	for id in m.chars:
		if role == "" or String(m.chars[id].get("role", "")) == role: out.append(id)
	out.sort()
	return out

static func region_set(region_id: String) -> String:
	var code := region_id.substr(0, 2).to_upper()
	if not (code in REGIONS):
		code = ""
		for c in REGIONS:
			if region_id.to_upper().contains(c + "_"): code = c; break
	if code == "": code = "JL"
	var s := "amb_" + code
	return s if not manifest(s).is_empty() else ""

static func bank_src(set_name: String, want: Array) -> Dictionary:
	var m := manifest(set_name)
	var out := {}
	if m.is_empty(): return out
	for id in want:
		if m.chars.has(id): out[id] = { pages = m.pages, clips = m.chars[id].clips }
	return out

# 페이지 이미지 읽기(작업 스레드에서도 부른다): 밉맵 + 되면 S3TC(DXT5) 압축 — 2048² 한 장 22MB → 5.6MB, 압축은 장당 약 10ms.
# 먹선·한지 테 그림에서 눈에 띄는 차이가 없었다(docs/reports/character-builder.md §4). 지원 안 하는 기기면 RGBA 그대로.
static func load_page(file: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://data/" + file))
	if img == null or img.is_empty(): return null
	img.generate_mipmaps()
	if file.begins_with("chars/") and RenderingServer.get_rendering_device() != null and RenderingServer.has_os_feature("s3tc") and not OS.get_cmdline_user_args().has("--nocompress"):
		img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC)
	return img

static func texture(file: String) -> Texture2D:
	if _tex.has(file): return _tex[file]
	var img := load_page(file)
	if img == null: return null
	var t := ImageTexture.create_from_image(img)
	_tex[file] = t
	return t

# 이미 다른 곳(작업 스레드)에서 만든 텍스처를 공유 표에 넣는다
static func put_texture(file: String, t: Texture2D) -> void:
	_tex[file] = t

# id 인물을 SpriteChar 종류로 올린다(그 묶음 페이지를 동기로 읽음). 없으면 false
static func ensure(id: String) -> bool:
	if SpriteChar._banks.has(id): return true
	var s := set_of(id)
	if s == "": return false
	var m := manifest(s)
	var pages := []
	for f in m.pages:
		var t := texture(String(f))
		if t == null: return false
		pages.append(t)
	SpriteChar._banks[id] = { pages = pages, clips = m.chars[id].clips }
	return true

# 시험·측정: 읽은 페이지 수와 대략 VRAM(RGBA + 밉맵 4/3)
static func stats() -> Dictionary:
	var b := 0.0
	for f in _tex:
		var t: Texture2D = _tex[f]
		var bpp := 1.0 if (t is ImageTexture and (t as ImageTexture).get_format() == Image.FORMAT_DXT5) else 4.0
		b += t.get_width() * t.get_height() * bpp * 4.0 / 3.0
	return { pages = _tex.size(), mb = snappedf(b / 1048576.0, 0.1) }
