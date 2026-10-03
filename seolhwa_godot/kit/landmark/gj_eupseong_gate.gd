# 경주읍성 성문 — 1012년(고려 현종) 쌓고 조선 때 고쳐 쌓은 방형 석성(둘레 약 2.3km, 높이 약 4m). 4문: 남 징례문(徵禮門)·동 향일문(向日門)·북 공진문(拱辰門)·서 망미문(望美門).
# 1870년에는 성벽·성문이 서 있었다(1912년 무렵 시가지 정비로 대부분 헐림). 성벽은 landmark/seong_wall·seong_chi를 그대로 쓴다.
# seongmun 감싸기: 단층 문루 + 옹성(가설: 남문은 옹성 없이 큰길로 곧장, 나머지는 옆으로 열림). params: seed, name, open, lu
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "징례문", open = "none", lu = 1, width = 18.0 }, params))
