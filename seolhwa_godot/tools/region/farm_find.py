"""필지 종류별로 가장 빽빽한 자리 찾기(스크린샷 자리 고르기용): python3 tools/region/farm_find.py region_data/<id>"""
import numpy as np, struct, sys
d=sys.argv[1]
b=open(d+'/parcels.bin','rb').read()
ver,n,nv,ni,nc=struct.unpack('<5I',b[4:24])
if ver>=2:
    import gzip; b=b[:24]+gzip.decompress(b[24:])
P=np.frombuffer(b,np.float32,n*12,24).reshape(n,12)
def show(name, m):
    q=P[m]
    if len(q)==0: print(name, 0); return
    # densest: point with most same-kind neighbours within 40 m
    from scipy.spatial import cKDTree
    t=cKDTree(q[:,:2]); c=np.array([len(x) for x in t.query_ball_point(q[:,:2],40)])
    i=np.argmax(c); print(name, len(q), 'best', q[i,:2].round(0), c[i])
show('flat paddy', (P[:,3]==0)&(P[:,11]<0.015))
show('terrace paddy', (P[:,3]==0)&(P[:,11]>0.025))
show('stone paddy', (P[:,3]==0)&(P[:,8].astype(int)&1==1))
show('flat field', (P[:,3]==1)&(P[:,11]<0.05))
show('contour field', (P[:,3]==1)&(P[:,11]>0.05)&(P[:,8].astype(int)&4==0))
show('terraced field', (P[:,3]==1)&(P[:,8].astype(int)&4==4))
show('stone terr field', (P[:,3]==1)&(P[:,8].astype(int)&5==5))
show('wall field', (P[:,3]==1)&(P[:,8].astype(int)&2==2))
