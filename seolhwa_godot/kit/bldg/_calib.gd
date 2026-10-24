# KHS 실측 보정 프리셋(WP7a) — 지역 프로필별 범위 + 근거 상태. 보편 상수가 아니다.
#   값은 모두 실측(배율 전, m)이다. 배율(RegionProfile.scale_policy.building.factor)은 _spec.real_scale에서 한 번만 곱한다.
#   근거: /Users/sinjaeho/Documents/works/khs_assets/godot_ready/CALIBRATION.md · MEASUREMENTS.md (국가유산청 3D, 공공누리 1유형)
#     낙안읍성 안채 9동(전남 순천, 현황 + 일부 가상 복원) → south 초가
#     김명관 고택(전북 정읍, 18세기 호남 양반가, 현황) → south 양반
#     연경당·운현궁(19세기 서울 상류, 현황·수리 후) → central 양반
#   status: 생성기는 confirmed를 만들지 않는다(V18) — 실측 근거가 있어도 "proposed", 근거 없는 지역은 "unknown".
#   kind: SourceRecord.kind(current_state/after_repair/restoration …), units_confirmed: 단위·기준(마당 지면) 확인 여부.
#   쓰는 법: CB.between(r, "yangban", region, "bay_w", 2.5, 2.9) — 표에 있으면 그 범위, 없으면 옛 기본 범위(난수 한 번은 늘 뽑는다 →
#   다른 값의 씨앗 순서가 그대로).
extends RefCounted

const SOURCES := {
	"khs:nagan_houses": { title = "순천 낙안읍성 민가 안채 9동 3D 실측(국가유산청)", kind = "current_state", units_confirmed = true,
		limits = "현황과 일부 가상 복원(슬레이트→초가)이 섞임; 조선 원형 확정 아님" },
	"khs:kim_myeonggwan": { title = "정읍 김명관 고택 3D 실측(국가유산청)", kind = "current_state", units_confirmed = true,
		limits = "단일 메시라 문 치수는 쓸 수 없음; 18세기 호남 사가 한 사례" },
	"khs:yeongyeongdang": { title = "창덕궁 연경당 3D 실측(국가유산청)", kind = "after_repair", units_confirmed = true,
		limits = "19세기 궁궐 안 사대부형 집 — 서울 상류 한 사례" },
	"khs:unhyeongung": { title = "운현궁 3D 실측(국가유산청)", kind = "after_repair", units_confirmed = true,
		limits = "19세기 서울 궁가; 부속 지붕이 섞인 측정값은 뺌" },
	"report:nagan_2011": { title = "한국의 전통가옥(36) 기록화보고서 — 낙안성(2011)", kind = "survey", units_confirmed = true,
		limits = "양규철가옥 평면·단면 판독(15장) — 한 사례" },
}

# family → region → key → { r:[lo,hi] 또는 v, status, src, note }
const PRESETS := {
	"choga": {
		"south": {
			depth = { r = [2.1, 2.3], status = "proposed", src = ["khs:nagan_houses"], note = "몸채 깊이 2.14–2.18(툇칸은 따로)" },
			rise_k = { r = [0.72, 0.76], status = "proposed", src = ["khs:nagan_houses"], note = "처마 끝→용마루 2.8 m(대다수 같은 키트 지붕)" },
			eave = { r = [1.1, 1.4], status = "proposed", src = ["khs:nagan_houses"], note = "내밀기 본채 1.2–1.8 실측, 1.1–1.4 채택(이전 eave v2)" },
			droop = { r = [0.3, 0.5], status = "proposed", src = ["khs:nagan_houses"], note = "처마 끝 밑선 = 벽 위끝 −0.3~0.5, 드나드는 문 머리 +0.10 이상(DOORCLEAR)" },
			base_h = { r = [0.165, 0.245], status = "proposed", src = ["khs:nagan_houses"], note = "기단+바닥 0.48–0.67" },
		},
	},
	"yangban": {
		"south": {
			bay_w = { r = [2.0, 2.4], status = "proposed", src = ["khs:kim_myeonggwan"], note = "칸 2.0–2.5(호남 사가)" },
			wall_h = { r = [2.0, 2.2], status = "proposed", src = ["khs:kim_myeonggwan"], note = "기둥 위끝 2.4–3.0(지면) − 기단·바닥" },
			base_h = { r = [0.17, 0.28], status = "proposed", src = ["khs:kim_myeonggwan"], note = "기단+바닥 0.47–0.54(바닥 0.30 별도)" },
			toet_d = { r = [1.0, 1.2], status = "proposed", src = ["khs:kim_myeonggwan", "khs:yeongyeongdang"], note = "툇칸 0.73–1.33, 중앙 1.0–1.2" },
			rise_k = { r = [0.88, 1.0], status = "proposed", src = ["khs:kim_myeonggwan"], note = "처마 끝→용마루 3.4–3.8 m" },
			eave_dy = { r = [-0.25, -0.05], status = "proposed", src = ["khs:kim_myeonggwan"], note = "처마 끝 ≈ 기둥 위끝 −0.4~0 — 빌더가 도리 여유로 아래를 묶음" },
		},
		"central": {
			bay_w = { r = [2.4, 2.6], status = "proposed", src = ["khs:yeongyeongdang", "khs:unhyeongung"], note = "칸 2.40–2.61(서울 상류)" },
			toet_d = { r = [1.0, 1.2], status = "proposed", src = ["khs:yeongyeongdang"], note = "툇칸 중앙 1.0–1.2" },
			rise_k = { r = [0.78, 0.95], status = "proposed", src = ["khs:yeongyeongdang", "khs:unhyeongung"], note = "처마 끝→용마루 2.0–3.3 m" },
			eave_dy = { r = [-0.15, 0.0], status = "proposed", src = ["khs:yeongyeongdang", "khs:unhyeongung"], note = "연경당 처마 끝 3.04 vs 기둥 위끝 3.06–3.21" },
			base_h = { status = "proposed", src = ["khs:yeongyeongdang", "khs:unhyeongung"], note = "기단+바닥 0.87–1.25 — 옛 범위(안채 0.55–0.85·사랑 0.6–0.95 + 바닥 0.30)가 이미 맞음, 그대로 둠" },
		},
		"default": {
			bay_w = { r = [2.2, 2.6], status = "unknown", src = [], note = "지역 실측 없음 — 전체 권장 2.2–2.6 외삽" },
			toet_d = { r = [1.0, 1.2], status = "unknown", src = [], note = "지역 실측 없음 — 전체 권장" },
			rise_k = { r = [0.8, 0.95], status = "unknown", src = [], note = "지역 실측 없음 — 전체 권장(지붕이 납작함 보정)" },
			eave_dy = { r = [-0.15, 0.0], status = "unknown", src = [], note = "지역 실측 없음" },
		},
	},
}

static func entry(family: String, region: String, key: String) -> Dictionary:
	var f: Dictionary = PRESETS.get(family, {})
	var e: Dictionary = (f.get(region, {}) as Dictionary).get(key, {})
	if e.is_empty(): e = (f.get("default", {}) as Dictionary).get(key, {})
	return e

# 난수 한 번: 표 범위(있으면) 또는 옛 범위
static func between(r: Kit.Rng, family: String, region: String, key: String, lo: float, hi: float) -> float:
	var e := entry(family, region, key)
	if e.has("r"): return r.between(float(e.r[0]), float(e.r[1]))
	return r.between(lo, hi)

static func has(family: String, region: String, key: String) -> bool:
	return entry(family, region, key).has("r")

# 서술자 근거 목록: 이 집(명세)에 적용된 보정 항목 [{ key, range, status, sources, note }]
static func applied(sp: Dictionary) -> Array:
	var fam := family_of(String(sp.get("type", "")))
	if fam == "": return []
	var out := []
	var reg := String(sp.get("region", "south"))
	var f: Dictionary = PRESETS.get(fam, {})
	var keys := {}
	for k in (f.get(reg, {}) as Dictionary): keys[k] = true
	for k in (f.get("default", {}) as Dictionary): keys[k] = true
	for k in keys:
		var e := entry(fam, reg, k)
		out.append({ key = "%s.%s" % [fam, k], range = e.get("r", []), applied = e.has("r"), status = e.status, sources = e.src, note = e.note,
			region_profile = reg if (f.get(reg, {}) as Dictionary).has(k) else "default" })
	out.sort_custom(func(a, b): return String(a.key) < String(b.key))
	return out

static func family_of(type: String) -> String:
	if type == "choga": return "choga"
	if type in ["anchae", "sarang"]: return "yangban"
	return ""
