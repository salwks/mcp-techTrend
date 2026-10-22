#!/usr/bin/env python3
"""town-organic 점검 시점 만들기: placement_namwon_town.json의 구역(길·마당)에서 마을 카메라·기본·1인칭·내려다보기 시점과 길 걷기를 고른다.
   python3 tools/bldg/town_views.py west   → tools/bldg/town_views.json 의 sets.<구역>(전·후 같은 자리: <구역>_before는 views만)"""
import json, sys, os, math
here = os.path.dirname(os.path.abspath(__file__)); root = os.path.abspath(os.path.join(here, '..', '..'))
dn = sys.argv[1] if len(sys.argv) > 1 else 'west'
T = json.load(open(os.path.join(root, 'region_data/JL_NAMWON_UNBONG/placement_namwon_town.json')))
D = T['districts'][dn]; pre = {'west': 'orgw', 'eup': 'orge'}.get(dn, 'org' + dn[0])
FIX = {  # 구역마다 고정 시점(전·후 비교용) + 내려다보기 중심
  'west': dict(lane=[[-3340.4, 232], [-3341.5, 270], [-3342, 300], [-3341, 340], [-3340.4, 358]], center=[-3385, 285],
               fixed=[('t1', '장터길(서문 앞 북쪽)', -3343, 258), ('t2', '서문 앞 마당', -3349, 246), ('t3', '장터길–성황사길 갈림목', -3350, 291), ('t4', '장터길 남쪽', -3343, 335)]),
  'eup': dict(lane=[[-3227.8, 334], [-3227.8, 300], [-3227.8, 262], [-3227.8, 250], [-3260, 249.3], [-3300, 249.3]], center=[-3228, 293],
              fixed=[('t1', '남문 안 마당', -3227.8, 330), ('t2', '남북 큰길 가운데', -3225, 295), ('t3', '십자로 남쪽', -3224, 258), ('t4', '동서 큰길 서쪽', -3290, 252)]),
}
fx = FIX.get(dn, {})
path = os.path.join(here, 'town_views.json')
V = json.load(open(path)) if os.path.exists(path) else {'note': '', 'sets': {}}
views = []
for i, label, x, z in fx.get('fixed', []): views.append(dict(id=i, label=label, mode='town', x=x, z=z))
streets = [a for a in T['alleys'] if a['id'].startswith(pre + '_')]
streets.sort(key=lambda a: -len(a['points']))
def mid(a, f=0.5):
    p = a['points']; return p[min(len(p) - 1, int(len(p) * f))]
def yaw(a, f=0.5):
    p = a['points']; i = min(len(p) - 2, int(len(p) * f)); dx = p[i + 1][0] - p[i][0]; dz = p[i + 1][1] - p[i][1]
    return round(math.degrees(math.atan2(dx, -dz)))
k = 5
for a in streets[:5]:
    x, z = mid(a); views.append(dict(id='t%d' % k, label='%s 가운데' % a['id'].replace(pre + '_', ''), mode='town', x=round(x, 1), z=round(z, 1))); k += 1
for j, a in enumerate(streets[:2]):
    x, z = mid(a, 0.35); views.append(dict(id='s%d' % (j + 1), label='기본 카메라 %s' % a['id'].replace(pre + '_', ''), mode='std', x=round(x, 1), z=round(z, 1)))
for j, a in enumerate(streets[:4]):
    x, z = mid(a, 0.3); views.append(dict(id='f%d' % (j + 1), label='1인칭 %s' % a['id'].replace(pre + '_', ''), mode='fp', x=round(x, 1), z=round(z, 1), yaw=yaw(a, 0.3), pitch=3))
cx, cz = fx.get('center', D['area'][0])
views += [dict(id='o1', label='구역 내려다보기', mode='over', x=cx, z=cz, dist=130, pitch=55, yaw=0),
          dict(id='o2', label='높은 비스듬히(참고 그림 각, 동남에서)', mode='over', x=cx, z=cz, dist=170, pitch=28, yaw=45),
          dict(id='o3', label='남쪽에서 비스듬히', mode='over', x=cx, z=cz - 5, dist=180, pitch=34, yaw=0),
          # 참고 그림 각(ACON 2203 #1 남문 위 낮은 비스듬히 · #5 길 위 가까운 비스듬히)
          dict(id='r1', label='참고 각 #1(남문 위 낮게)', mode='over', x=cx, z=cz - 12, dist=95, pitch=17, yaw=0),
          dict(id='r5', label='참고 각 #5(길 위 가깝게)', mode='over', x=cx + 4, z=cz + 12, dist=42, pitch=30, yaw=35)]
walks = []
for a in streets:
    p = [list(q) for q in a['points']]
    # 막다른 끝은 1.5m 당긴다(길 끝이 담·건물 처마 밑에 닿아 발 둘레가 끼는 자리 — 걷기 판정만)
    if len(p) >= 2:
        dx = p[-2][0] - p[-1][0]; dz = p[-2][1] - p[-1][1]; L = max(1e-6, (dx * dx + dz * dz) ** 0.5)
        k = min(1.5, L * 0.5) / L; p[-1] = [p[-1][0] + dx * k, p[-1][1] + dz * k]
    st = 1 if len(p) < 14 else 2   # 굽은 길의 현(chord)이 담을 가로지르지 않게 촘촘히
    pts = p[::st] + ([p[-1]] if (len(p) - 1) % st else [])
    walks.append(dict(id=a['id'].replace(pre + '_', ''), label=a['id'], pts=[[round(x, 1), round(z, 1)] for x, z in pts], shots=[]))
if fx.get('lane'): walks.append(dict(id='lane', label='큰길', pts=fx['lane'], shots=[]))
xs = [p[0] for p in D['area']]; zs = [p[1] for p in D['area']]
V['sets'][dn] = dict(label='고을 짜임 ' + dn, views=views, walks=walks, gates=dict(bbox=[min(xs) - 5, min(zs) - 5, max(xs) + 5, max(zs) + 5], file='res://region_data/JL_NAMWON_UNBONG/placement_namwon_town.json'))
V['sets'][dn + '_before'] = dict(label='전 ' + dn, views=views)
V['note'] = 'town-organic 점검 시점(scripts/region/bldg_rollout.gd). yaw 0 = 북, +90 = 동. over: 카메라가 바라보는 점에서 (sin yaw, cos yaw) 쪽(0 = 남쪽에서 북으로). tools/bldg/town_views.py로 만든다.'
json.dump(V, open(path, 'w'), ensure_ascii=False, indent=1)
print('views', len(views), 'walks', len(walks))
