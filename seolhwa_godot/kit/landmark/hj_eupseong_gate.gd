# 황주읍성 성문 — 황해도 황주목 읍성(평양 가는 의주대로 길목, 산을 낀 석성). 1870년에 성벽·문이 있었다고 봄. 문 이름·문루 모양은 기록을 못 찾아 가설
# (단층 팔작 3칸 + 옆으로 열린 반원 옹성). 성벽은 seong_wall/seong_chi 재사용. seongmun 감싸기. params: seed, name("남문"), open("west"), lu(1)
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "황주남문", open = "west", radius = 10.0, lu = 1, width = 16.0 }, params))
