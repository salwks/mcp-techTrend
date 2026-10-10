# 기록책·저장 시험(save_keeper.gd가 인자를 보고 부른다)
#   --savetest       칸 1에 저장 → 진행을 바꿈 → 칸 1 불러오기(장면 다시 열기) → 바꾼 값이 되돌아왔나 · 예전 꼴 저장(버전 1) 불러오기
#                    → SAVETEST PASS / FAIL (헤드리스 가능)
#   --uishots=폴더   기록책 갈피마다 펼침면 · 다음 장, Esc 메뉴, 저장 · 불러오기 창, 조사 카드 · 대화 · 선택 · 안내 · 도장을 찍는다(창 필요)
#   --bottomshots=폴더  아래쪽 글(조사·대화 안내 E, 처음 한 번 안내 띠, 자막·조작 유지 자막, 말·배 안내, 소지품, 오른쪽 아래 키 안내)을 찍는다(창 필요)
#   --uifixture=res://….json  시작 저장(vars · cases · routes_done)을 깐다   --uifull  나의 첫 문장 · 들은 말 몇 개를 더한다(화면용)
# 예) godot --path seolhwa_godot res://scenes/region.tscn --resolution 1600x900 -- --region=JL_NAMWON_UNBONG --notitle \
#       --savefile=user://ui_shots.json --uifixture=res://story/jeju/test_post_act4.json --uifull --uishots=shots/ui
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const META := "seolhwa_savetest"

var k   # save_keeper
var d

func _init(keeper) -> void:
	k = keeper
	d = keeper.d

static func apply_fixture(args: Dictionary) -> void:
	var data := Progress.data()
	if args.has("uifixture"):
		var j = JSON.parse_string(FileAccess.get_file_as_string(String(args.uifixture)))
		if j is Dictionary:
			data.vars = j.get("vars", {}).duplicate(true)
			data.cases = j.get("cases", {}).duplicate(true)
			data.routes_done = j.get("routes_done", {}).duplicate(true)
			data.erase("where")
	if args.has("uifull"):
		data.vars["PLAYER_FIRST_LINE"] = "섞여 있는 흔적을 나누되, 먼저 살아 있는 사람을 찾는다."
		data.vars["MAIN_GWAK_FOUND"] = true
		data.vars["MAIN_MASTER_TRACE"] = "HANYANG,GANGNEUNG,GYEONGJU,HWANGJU,PYONGYANG,HAMHUNG"
		for h in [["주모", "남원 주막", "고개 너머 떡장수가 사흘째 안 돌아온다오."], ["장꾼", "남원 장", "밤에 고갯길로 가면 누가 이름을 부른다더군."],
				["뱃사공", "마포 선창", "요새 칠패 창고에 밤마다 불이 켜진다오."], ["서리", "평양 감영", "장부 글씨가 둘이라는 말이 돌았소."]]:
			Progress.add_heard({ id = "uitest_%s" % h[0], space = "", by = h[0], place = h[1], text = h[2] })
	Progress.save()
	print("UITEST fixture vars=%d cases=%s" % [data.vars.size(), data.cases.keys()])

func _frames(n: int) -> void:
	for i in n: await d.get_tree().process_frame

func _wait_load() -> void:
	while d.main._loading: await d.get_tree().process_frame
	await _frames(40)

# ---- 저장 · 불러오기 ----
func savetest() -> void:
	await _wait_load()
	var phase := String(Engine.get_meta(META, "")) if Engine.has_meta(META) else ""
	var fails := []
	if phase == "":
		Progress.set_var("SAVETEST_MARK", "A")
		Progress.place_now = "시험 고을"
		# 길목 깃발 가 봄(travel_nodes)도 저장 칸에 실려 이어진다
		var HR: Script = load("res://scripts/region/horse_ride.gd")
		HR.discover(String(d.space_id), _test_flag())
		var ok: bool = k.save_to(1)
		var info := Progress.slot_info(1)
		if not ok or info.is_empty(): fails.append("칸 1 저장 실패")
		elif String(info.meta.get("place", "")) != "시험 고을": fails.append("칸 1 고을 이름 %s" % info.meta)
		print("SAVETEST saved slot1 %s" % JSON.stringify(info))
		Progress.set_var("SAVETEST_MARK", "B")
		Progress.save()
		if Progress.latest_slot() != 0: fails.append("가장 새 칸이 자동 기록이 아님(%d)" % Progress.latest_slot())
		if not fails.is_empty():
			print("SAVETEST FAIL ", "; ".join(fails)); d.main._quit(); return
		Engine.set_meta(META, "loaded")
		if not k.load_from(1):
			print("SAVETEST FAIL 칸 1 불러오기 실패"); d.main._quit()
		return
	# 장면을 다시 연 뒤
	Engine.remove_meta(META)
	var mark := str(Progress.get_var("SAVETEST_MARK", ""))
	if mark != "A": fails.append("불러온 값 %s (A여야)" % mark)
	var fid := _test_flag()
	var flag_ok: bool = load("res://scripts/region/horse_ride.gd").is_discovered(String(d.space_id), fid)
	print("SAVETEST flag %s/%s kept=%s" % [d.space_id, fid, flag_ok])
	if fid == "" or not flag_ok: fails.append("길목 깃발 가 봄이 저장 칸에서 이어지지 않음(%s)" % fid)
	var wh := Progress.where()
	print("SAVETEST after load mark=%s space=%s where=%s" % [mark, d.space_id, JSON.stringify(wh)])
	# 예전 꼴(버전 1 — routes_done만) 칸도 읽힌다
	var f := FileAccess.open(Progress.slot_path(3), FileAccess.WRITE)
	f.store_string(JSON.stringify({ "routes_done": { "OLD_ROUTE": "2026-10-01T00:00:00" } }))
	f.close()
	if not Progress.load_slot(3): fails.append("버전 1 칸 불러오기 실패")
	elif not Progress.route_done("OLD_ROUTE") or not (Progress.data().get("vars") is Dictionary) or not (Progress.data().get("heard") is Array):
		fails.append("버전 1 칸 꼴 채우기 실패")
	if fails.is_empty(): print("SAVETEST PASS slot1 → load → mark A, flag kept, v1 slot ok")
	else: print("SAVETEST FAIL ", "; ".join(fails))
	d.main._quit()

# ---- 화면 ----
func _shot(dir: String, nm: String, frames := 30) -> void:
	await _frames(frames)
	var img: Image = d.get_viewport().get_texture().get_image()
	var p: String = d.main._abs(dir.path_join(nm + ".png")) if d.main.has_method("_abs") else dir.path_join(nm + ".png")
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	img.save_png(p)
	print("UITEST shot ", p)

func uishots(dir: String) -> void:
	await _wait_load()
	d.ui.auto = false
	await _frames(60)
	# 기록책 — 갈피마다(앞 갈피 먼저), 갈피가 여러 장이면 다음 장도
	var jd: Dictionary = d.journal_data()
	var jv = d.ui._jv
	d.ui.journal_show(jd)
	for si in jv.order:
		var id := String(jd.pages[si].id)
		jv.goto_section(si, false)
		await _shot(dir, "journal_%s" % id, 20)
		var first: int = jv.spread
		jv.turn(1)
		if jv.spread != first and int(jv.pages[jv.spread * 2].sec) == si:
			await _frames(4)
			await _shot(dir, "journal_%s_flip" % id, 1)
			await _shot(dir, "journal_%s_2" % id, 30)
	d.ui.journal_close()
	await _frames(10)
	# 지도(권역): 지명·호신물 칸 같은 HUD가 감춰지는지(scripts/hud_gate.gd) — 지명을 다시 띄운 채로 연다
	var mp = d.main._map
	if mp != null:
		d.main._title.show_title("시험 고을")
		mp.toggle(); mp.show_mode("all")
		await _shot(dir, "map_all", 20)
		mp.toggle()
		await _frames(10)
	# 조사 카드 · 대화 · 선택
	d.ui.examine("짚신 한 짝", "길가 풀숲에 젖은 짚신 한 짝. 끈이 끊어졌다. 신은 지 오래되지 않았다.", "clue")
	await _shot(dir, "card", 20)
	d.ui._confirm.emit()
	await _frames(10)
	d.ui.say("주모", ["어서 오시오. 고개 너머 떡장수 말이오? 사흘째 소식이 없소."])
	await _shot(dir, "dialog", 60)
	d.ui._confirm.emit(); await _frames(2); d.ui._confirm.emit()
	await _frames(10)
	d.ui.choice("어디부터 볼까.", [{ label = "주막 뒤 고갯길" }, { label = "장터 사람들" }, { label = "외딴집", disabled = true, hint = "아직 모르는 곳" }])
	await _shot(dir, "choice", 20)
	d.ui._picked.emit(0)
	await _frames(10)
	d.ui.prompt("살펴보기")
	d.ui.key_hint("F", "쉬며 기록을 정리한다")
	d.ui.hint("R   기록책")
	d.ui.toast("기록 — 들음 · 주모", "journal")
	d.ui.save_stamp()
	await _shot(dir, "hud_prompt_stamp", 25)
	d.ui.prompt(""); d.ui.key_hint("F", ""); d.ui.hint_clear()
	# 저장 칸 두 개 채우고 Esc 메뉴 · 저장 창 · 불러오기 창
	k.thumb = k.grab()
	Progress.place_now = "남원"
	k.save_to(1)
	k._set_hour(19.5)
	await _frames(20)
	k.thumb = k.grab()
	k.save_to(2)
	d.onboard.open_menu()
	await _shot(dir, "esc_menu", 20)
	var menu = d.onboard.menu
	menu.visible = false
	var sm = k.open_slots("save")
	await _shot(dir, "save_menu", 20)
	sm._switch("load")
	await _shot(dir, "load_menu", 20)
	sm._close()
	menu.close()
	print("UITEST done")
	d.main._quit()

# ---- 아래쪽 글(안내·자막·말 안내·소지품) — 크기·겹침 확인용 ----
func bottomshots(dir: String) -> void:
	await _wait_load()
	d.ui.auto = false
	await _frames(60)
	var vs: Vector2 = d.get_viewport().get_visible_rect().size
	print("UITEST bottom viewport=%s k=%.2f" % [vs, d.ui._k])
	d.ui.items([{ label = "떡", count = 3 }, { label = "부싯돌", count = 1 }, { label = "쪽빛 천 조각", count = 1 }, { label = "짚신 한 짝", count = 1 }])
	# 1) 조사·대화 안내 + 처음 한 번 안내 띠 + 오른쪽 아래 키 안내
	d.ui.hint("WASD 걷기   ·   Shift 달리기   ·   마우스 오른쪽 끌기 — 둘러보기")
	d.ui.key_hint("F", "쉬며 기록을 정리한다")
	await _shot_prompt(dir, "1_prompt_hint", "주모 · 말 걸기")
	# 2) 처음 조사 전(크게) + 두 줄 안내
	d.ui.prompt_strong = true
	d.ui.hint("말이 큰길을 따라 저절로 간다\nSpace 멈춤·다시 감   ·   E 내리기\n갈림길 앞에서는 A·D로 길을 고른다")
	d.ui.key_hint("F", "")
	await _shot_prompt(dir, "2_prompt_strong_hint3", "살펴보기")
	d.ui.prompt_strong = false
	d.ui.prompt(""); d.ui.hint_clear()
	await _frames(30)
	# 3) 자막(조작 유지 자막 — 긴 줄 줄바꿈)
	d.ui.caption("길손  “그 기록하던 양반 말이야. 한양으로 갔다던데.”", 6.0)
	await _shot(dir, "3_caption", 30)
	d.ui.caption("누이  “오라버니, 문고리 잡지 마. 어머니 목소리여도 열면 안 돼. 아까 그 손 봤잖아, 털이 숭숭 났어.”", 6.0)
	await _shot(dir, "4_caption_long", 30)
	# 4) 자막 + 안내가 함께
	await _shot_prompt(dir, "5_caption_prompt", "문고리 · 살펴보기", 10)
	d.ui.prompt("")
	if d.ui._cap_tween: d.ui._cap_tween.kill()
	var cb = d.ui.get("_cap_box")
	if cb == null: cb = d.ui._caption   # 예전 꼴(띠 없음)
	cb.modulate.a = 0.0
	await _frames(10)
	# 5) 말·배 안내(region_main 아래 가운데 — 말 안내가 매 프레임 덮어쓰므로 그리기 바로 앞에 다시 넣는다)
	if d.main.has_method("_boat_text"):
		var t := "E   말에 오른다 — 운봉 고을 어귀 쪽으로 (약 3분)   ·   Q 다른 곳 1/4"
		for i in 30:
			await RenderingServer.frame_pre_draw
			d.main._boat_text(t)
		d.ui.hint("WASD 걷기   ·   Shift 달리기")
		for i in 30:
			await RenderingServer.frame_pre_draw
			d.main._boat_text(t)
		await RenderingServer.frame_post_draw
		var img: Image = d.get_viewport().get_texture().get_image()
		var pth: String = d.main._abs(dir.path_join("6_ride_prompt.png"))
		img.save_png(pth)
		print("UITEST shot ", pth)
		d.ui.hint_clear()
	# 6) 전투 HUD 아래쪽(화살·떡, 키 안내)
	d.ui.combat_mode(true)
	d.ui.hud_ammo(5, 2)
	await _shot(dir, "7_combat_bottom", 10)
	d.ui.combat_mode(false)
	print("UITEST bottom done")
	d.main._quit()

# 조사 안내(E)는 이야기 쪽이 매 프레임 대상에 맞춰 다시 쓴다 — 그리기 바로 앞에 넣어 찍는다
func _shot_prompt(dir: String, nm: String, text: String, frames := 30) -> void:
	for i in frames:
		await RenderingServer.frame_pre_draw
		d.ui.prompt(text)
	await RenderingServer.frame_post_draw
	var img: Image = d.get_viewport().get_texture().get_image()
	var p: String = d.main._abs(dir.path_join(nm + ".png"))
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	img.save_png(p)
	print("UITEST shot ", p)

# 이 공간의 마지막 길목 깃발(시작 자리에서 먼 것 — 걸어서 저절로 알게 되지 않게)
func _test_flag() -> String:
	var W: Script = load("res://scripts/region/waymarks.gd")
	var l: Array = W.flags_in(String(d.space_id))
	return String(l[l.size() - 1].id) if not l.is_empty() else ""
