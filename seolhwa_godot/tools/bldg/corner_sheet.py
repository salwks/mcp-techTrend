import json
names=[("c1_choga_c1_junction","초가 중부 ㄱ 이음(부엌 날개↔몸채 뒤)"),("c2_anchae_c1_junction","안채 중부 ㄱ 이음"),("c3_anchae_n2_junction","안채 북부 ㄱ 이음"),("c4_choga_s1_frontR","초가 남부 앞 모서리"),("c5_choga_s1_backL","초가 남부 뒤 모서리"),("c6_gotgan_frontR","곳간 앞 모서리"),("c7_choga_j1_backR","제주 돌벽 뒤 모서리"),("c8_giwajip_backR","읍내 기와집 뒤 모서리"),("c9_choga_s1_inside","초가 방 안 모서리(실내)"),("c10_anchae_s2_inside","안채 실내 모서리"),("c11_giwahouse_wallcorner","기와 갓 토담 모서리"),("c12_giwahouse_gatejoin","평대문–토담 이음")]
cells=[]
for k,l in names:
    for t in ("before","after"): cells.append({"path":f"res://shots/building_rollout/corners/raw/{k}_{t}.png","label":f"{l} · {'전' if t=='before' else '후'}"})
sh=[{"out":"res://shots/building_rollout/corners/corners_a.jpg","title":"외벽 모서리 이음 — 전(왼) · 후(오른) 가까이(1/2)","cols":2,"cw":800,"ch":600,"cells":cells[:12]},{"out":"res://shots/building_rollout/corners/corners_b.jpg","title":"외벽 모서리 이음 — 전(왼) · 후(오른) 가까이(2/2)","cols":2,"cw":800,"ch":600,"cells":cells[12:]}]
json.dump({"sheets":sh},open("shots/building_rollout/corners/sheets_corners.json","w"),ensure_ascii=False,indent=1)
