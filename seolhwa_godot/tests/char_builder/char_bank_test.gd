# 인물 빌더 묶음 시험(scripts/char_bank.gd · data/chars/*.json — tools/export_char_frames.js가 굽는다) — 헤드리스
#   godot --headless --path . -s res://tests/char_builder/char_bank_test.gd
#   A 프리셋(presets): 주모·방자·포졸·마을 사내가 id로 찾아지고 모든 동작(idle·walk·run·talk·sit·sit_seat·sit_down·stand_up·bow·kneel·carry·jump) × 앞·옆·뒤 클립이 있다
#   B 권역 묶음 amb_<권역> 여덟: 인물 수 ≤ 36(공간당 상한), 페이지 2048², 역할 고루, id 겹침 없음, 그림 크기 이상 없음
#   C SpriteChar: 빌더 id로 만들고 동작이 있다, carry는 짐 든 사람에게만, carry도 걸음 위상이 돈다
#   D 권역 이름 → 묶음(region_set), 모르는 이름은 JL
#   E 다양성: 같은 역할의 사람들 자료(얼굴·차림)가 서로 다르다
#   묶음이 없으면(굽기 전) 굽는 법을 찍고 FAIL
#   끝 줄: CHARBANK PASS n / CHARBANK FAIL n
extends SceneTree

const CharBank := preload("res://scripts/char_bank.gd")
const ANIMS := ["idle", "walk", "run", "talk", "sit", "sit_seat", "sit_down", "stand_up", "sit_talk", "sit_work", "squat", "bow", "kneel", "carry", "jump"]
const AMB := ["idle", "walk", "talk", "sit", "sit_seat", "sit_talk", "sit_work", "squat", "bow", "kneel", "jump"]   # 고을 사람: 모두 앉기 둘·뛰기 포함
const REG := ["JL", "GG", "GS", "GW", "HH", "PA", "HG", "JJ"]

var n := 0
var fails := 0
func ok(c: bool, what: String) -> void:
	n += 1
	if c: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	CharBank.scan()
	var pre := CharBank.manifest("presets")
	if pre.is_empty():
		print("data/chars/presets.json 없음 — python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/chars_bake.html?set=presets · ?set=amb_all")
	# A
	ok(not pre.is_empty(), "A presets.json 있음")
	for id in ["p_jumo", "p_bangja", "p_pojol", "p_villager"]:
		ok(CharBank.has(id) and CharBank.set_of(id) == "presets", "A %s 찾음" % id)
		var c: Dictionary = CharBank.info(id).get("clips", {})
		var miss := []
		for a in ANIMS:
			for v in ["front", "side", "back"]:
				if not c.has("%s|%s" % [v, a]): miss.append("%s|%s" % [v, a])
		ok(miss.is_empty(), "A %s 모든 동작·시점 (빠짐 %s)" % [id, miss])
	ok(String(CharBank.info("p_jumo").get("role", "")) == "innkeeper", "A p_jumo 역할 innkeeper")
	# 뛰기: 한 번 동작, 공중에서 그림이 떠 있다(lift) · 앉기 둘은 2장 자세
	var jc: Dictionary = CharBank.info("p_bangja").get("clips", {}).get("side|jump", {})
	var top := 0.0
	for f in jc.get("frames", []): top = maxf(top, float(f.get("lift", 0.0)))
	ok(String(jc.get("spec", {}).get("kind", "")) == "once" and jc.frames.size() >= 8 and top > 0.15, "A 뛰기 once %d장, 가장 높이 %.2fm" % [jc.get("frames", []).size(), top])
	ok(CharBank.info("p_jumo").clips["front|sit_seat"].frames.size() == 2 and CharBank.info("p_jumo").clips["side|sit"].frames.size() == 2, "A 앉기(땅·높은 자리) 2장 자세")
	# B
	var all_ids := {}
	for r in REG:
		var m := CharBank.manifest("amb_" + r)
		ok(not m.is_empty(), "B amb_%s 있음" % r)
		if m.is_empty(): continue
		ok(m.chars.size() >= 24 and m.chars.size() <= 36, "B amb_%s 인물 %d (24~36)" % [r, m.chars.size()])
		ok(m.pages.size() <= 14, "B amb_%s 페이지 %d ≤ 14" % [r, m.pages.size()])
		var bad := 0; var roles := {}; var dup := 0
		for id in m.chars:
			if all_ids.has(id): dup += 1
			all_ids[id] = true
			var ch: Dictionary = m.chars[id]
			roles[String(ch.role)] = true
			for a in AMB:
				for v in ["front", "side", "back"]:
					var cl = ch.clips.get("%s|%s" % [v, a])
					if cl == null: bad += 1; continue
					for f in cl.frames:
						var h := float(f.y1) - float(f.y0)
						if int(f.page) < 0 or int(f.page) >= m.pages.size() or h < 0.4 or h > 3.4 or float(f.u1) <= float(f.u0): bad += 1
		ok(bad == 0, "B amb_%s 클립·그림 이상 없음(%d)" % [r, bad])
		ok(dup == 0, "B amb_%s id 겹침 없음" % r)
		for role in ["farmer", "farmwife", "merchant", "elder", "child_boy", "child_girl"]:
			ok(roles.has(role), "B amb_%s 역할 %s" % [r, role])
		for p in m.pages:
			ok(FileAccess.file_exists("res://data/" + String(p)), "B 페이지 파일 %s" % p)
	ok(CharBank.ids("amb_JJ", "haenyeo").size() >= 2, "B 제주 해녀 여럿")
	# C
	if CharBank.ensure("p_jumo"):
		var sc := SpriteChar.new("p_jumo")
		ok(sc.has_anim("walk") and sc.has_anim("carry") and sc.has_anim("kneel") and sc.has_anim("jump") and sc.has_anim("sit_seat"), "C SpriteChar(p_jumo) 동작(jump·sit_seat 포함)")
		sc.set_anim("carry"); sc.move_speed = 1.2
		var ph0 := sc.phase
		root.add_child(sc)
		var cam := Camera3D.new(); root.add_child(cam)
		await process_frame
		sc.update_char(0.2, cam)
		ok(absf(sc.phase - ph0) > 0.05, "C carry 걸음 위상이 돈다")
		sc.queue_free(); cam.queue_free()
	var with_carry := 0; var without := 0
	for id in CharBank.ids("amb_JL"):
		var ch: Dictionary = CharBank.info(id)
		var I: Dictionary = ch.spec.get("items", {})
		var loaded := String(I.get("handLoad", "none")) != "none" or String(I.get("head", "none")) != "none" or String(I.get("back", "none")) != "none"
		var has := (ch.clips as Dictionary).has("side|carry")
		if has != loaded: without += 1
		if has: with_carry += 1
	ok(without == 0 and with_carry > 0, "C carry는 짐 든 사람에게만(%d명)" % with_carry)
	# D
	ok(CharBank.region_set("JL_NAMWON_UNBONG") == "amb_JL", "D 남원 → amb_JL")
	ok(CharBank.region_set("GG_HANYANG") == "amb_GG", "D 한양 → amb_GG")
	ok(CharBank.region_set("ROUTE_X") == "amb_JL", "D 모르는 이름 → amb_JL")
	# E
	var f := CharBank.ids("amb_JL", "farmer") + CharBank.ids("amb_JL", "merchant")
	var sig := {}
	for id in f:
		var sp: Dictionary = CharBank.info(id).spec
		sig[JSON.stringify([sp.face.shape, sp.face.eyes, sp.face.nose, sp.face.beard, sp.headwear, sp.colors.get("coat", ""), sp.body.height])] = true
	ok(f.size() >= 2 and sig.size() == f.size(), "E 남원 농부·상인 %d명 모두 다름" % f.size())
	print("CHARBANK %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)
