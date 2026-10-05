# 사건 분류(EVENT_CLASS) — 시나리오 v2.4.1 §1.11·§42·§44.
#   EVENT_CLASS는 세 값뿐: MAIN_FRAME(이겸·우치·강복·박규상 창작 메인 프레임) / FOLKLORE_EVENT(이름 있는 설화 기반 사건) / AMBIENT(생활·풍경·비서사).
#   실제 전승을 배경·소문·연상으로만 쓰면 제4의 클래스가 아니라 메타데이터로: FOLKLORE_ANCHOR_IDS[] + FOLKLORE_ANCHOR_MODE(SETTING/RUMOR/ECHO).
#   FOLKLORE_EVENT: SOURCE_ID(Fxx) · SOURCE_VERIFIED=true. CATALOG_ID(JGxx 등)는 선택 — 원전 카탈로그 추적용. SOURCE_VERIFIED=false면 빌드에서 뺀다(§44).
#   MAIN_FRAME: SOURCE_ID MAIN_FRAME_* · MAIN_FRAME_ORIGIN_NOTE. Fxx/Axx를 출처로 달지 않는다(앵커·ECHO 목록은 출처 주장이 아니다).
#   AMBIENT: 출처를 달지 않는다.
# 쓰는 곳: story_runner.run_event(빌드 판정), tools/story/validate_event_class.gd(검사).
extends RefCounted

const CLASSES := ["MAIN_FRAME", "FOLKLORE_EVENT", "AMBIENT"]
const ANCHOR_MODES := ["SETTING", "RUMOR", "ECHO"]

static func is_folk_id(s: String) -> bool:
	var re := RegEx.new()
	re.compile("^[FA][0-9]{2}$")
	return re.search(s) != null

# 빌드에 넣는가(§44) — 분류가 없거나 틀린 사건, 확인 안 된 설화 사건은 뺀다
static func in_build(ev: Dictionary) -> bool:
	match String(ev.get("EVENT_CLASS", "")):
		"FOLKLORE_EVENT": return bool(ev.get("SOURCE_VERIFIED", false))
		"MAIN_FRAME": return not is_folk_id(String(ev.get("SOURCE_ID", "")))
		"AMBIENT": return true
	return false

# 어긋난 것들(빈 배열이면 통과). warn은 막지 않는 알림
static func check(ev: Dictionary, warn: Array = []) -> Array:
	var errs := []
	var cls := String(ev.get("EVENT_CLASS", ""))
	var sid := String(ev.get("SOURCE_ID", ""))
	if not CLASSES.has(cls):
		errs.append("EVENT_CLASS '%s' — MAIN_FRAME/FOLKLORE_EVENT/AMBIENT 중 하나여야 함" % cls)
		return errs
	var anchors: Array = ev.get("FOLKLORE_ANCHOR_IDS", [])
	for a in anchors:
		if not is_folk_id(String(a)): errs.append("FOLKLORE_ANCHOR_IDS '%s' — Fxx/Axx 아님" % a)
	if not anchors.is_empty() and not ANCHOR_MODES.has(String(ev.get("FOLKLORE_ANCHOR_MODE", ""))):
		errs.append("FOLKLORE_ANCHOR_MODE '%s' — SETTING/RUMOR/ECHO 중 하나여야 함" % ev.get("FOLKLORE_ANCHOR_MODE", ""))
	match cls:
		"MAIN_FRAME":
			if is_folk_id(sid): errs.append("MAIN_FRAME인데 SOURCE_ID가 설화 출처 '%s'" % sid)
			elif not sid.begins_with("MAIN_FRAME_"): errs.append("MAIN_FRAME SOURCE_ID '%s' — MAIN_FRAME_* 형태여야 함" % sid)
			if String(ev.get("MAIN_FRAME_ORIGIN_NOTE", "")).strip_edges() == "": errs.append("MAIN_FRAME_ORIGIN_NOTE 없음")
			if ev.has("SOURCE_VERIFIED"): errs.append("MAIN_FRAME에 SOURCE_VERIFIED — 설화 출처처럼 보인다")
		"FOLKLORE_EVENT":
			if sid == "": errs.append("FOLKLORE_EVENT SOURCE_ID 없음")
			elif not sid.begins_with("F") or not is_folk_id(sid): errs.append("FOLKLORE_EVENT SOURCE_ID '%s' — Fxx여야 함(옛 목록 id는 CATALOG_ID로)" % sid)
			if not ev.has("SOURCE_VERIFIED"): errs.append("FOLKLORE_EVENT SOURCE_VERIFIED 없음")
			elif not bool(ev.SOURCE_VERIFIED): errs.append("FOLKLORE_EVENT SOURCE_VERIFIED=false — 빌드에서 빠진다")
		"AMBIENT":
			if sid != "": errs.append("AMBIENT에 SOURCE_ID '%s' — 가짜 출처 금지" % sid)
	return errs
