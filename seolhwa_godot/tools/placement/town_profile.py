"""고을 성격표(region.json archetypes + settlement.profile) → 배치 생성기용 '고을 모양새'(Style).

계약서 §9: profile = 입지 유형 기본값 + 고유값 덮어쓰기. 생성기는 roof(지붕 비율)·wall(담 재료)·layout(마을 짜임)·plan(가옥형)을 읽는다.
plan: 이 권역은 남부 기후대라 "il"(一자 홑집) 기본. 중부면 "giyeok".
"""
import random

ROOF_KIT = {"choga": "village/choga", "giwa": "village/giwa", "neowa": "village/neowa_house", "gulpi": "village/gulpi_house",
            "guitul": "village/guitul_house", "choga_low": "village/choga_low"}
# 초가 터 둘레 울(wall_run kind). stone_terrace = 옆·뒤 돌담 + 앞 돌축대(따로 놓음). none = 울 없음
WALL_RUN = {"stone": "stone_lite", "stone_terrace": "stone_lite", "todam": "todam_thatch", "fence": "fence_lite",
            "stone_net": "stone_lite", "basalt": "stone_lite", "none": None}
PLAN_BY_CLIMATE = {"south": "il", "alpine": "il", "coast": "il", "central": "giyeok", "north": ""}


class Style:
    def __init__(self, sid, roof, wall, layout, plan, archetype):
        self.sid, self.roof, self.wall, self.layout, self.plan, self.archetype = sid, roof, wall, layout, plan, archetype

    def pick_roof(self, seed, salt=0):
        h = random.Random(seed * 2654435761 % 2 ** 31 + salt * 97 + 11).random()
        t = 0.0
        tot = sum(self.roof.values()) or 1.0
        for k, w in sorted(self.roof.items()):
            t += w / tot
            if h < t:
                return k
        return sorted(self.roof)[-1]

    @property
    def wall_run(self):
        return WALL_RUN.get(self.wall, "stone_lite")

    def __repr__(self):
        return f"Style({self.sid}: roof={self.roof} wall={self.wall} layout={self.layout} plan={self.plan})"


def resolve(region, sid):
    arch = region.get("archetypes", {})
    s = next((x for x in region["settlements"] if x["id"] == sid), None)
    prof = (s or {}).get("profile", {}) or {}
    a = arch.get(prof.get("archetype", "plain"), {})
    roof = dict(prof.get("roof") or a.get("roof") or {"choga": 1.0})
    wall = prof.get("wall") or a.get("wall") or "fence"
    layout = prof.get("layout") or a.get("layout") or "rows"
    plan = prof.get("plan") or PLAN_BY_CLIMATE.get(prof.get("climate", "south"), "il")
    return Style(sid, roof, wall, layout, plan, prof.get("archetype", "plain"))


def style_by_archetype(region, archetype, sid="_"):
    a = region.get("archetypes", {}).get(archetype, {})
    return Style(sid, dict(a.get("roof", {"choga": 1.0})), a.get("wall", "fence"), a.get("layout", "rows"), "il", archetype)
