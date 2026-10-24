# KHS 김명관 안채 기와 조각 → 모듈(로컬 틀: x 폭, y 위(지붕 면 법선), z 처마 쪽(비탈 아래)). 길이는 원본 m(배율 전)
import json, numpy as np, sys
d=json.load(open(sys.argv[1]))['parts']; out=sys.argv[2]
def frame(T):
    P=T[:,:3]; c=P.mean(0); u,s,vt=np.linalg.svd(P-c); L=vt[0]
    if L[2]>0: L=-L
    W=np.cross(L,[0,0,1.0]); W/=np.linalg.norm(W); H=np.cross(W,L); H/=np.linalg.norm(H)
    if H[2]<0: H=-H
    W=np.cross(H,L)  # right-handed: x=W, y=H, z=L
    return c,L,W,H
def local(T):
    c,L,W,H=frame(T)
    P=T[:,:3]-c; N=T[:,5:8]
    q=np.stack([P@W,P@H,P@L],1); n=np.stack([N@W,N@H,N@L],1)
    return q,n
mods={}
for name,n in [('sukiwa2',112),('amkiwa5',120),('waguto',92),('sukiwa_short',40)]:
    arrs=[np.array(t) for t in d[str(n)] if isinstance(t,list)]
    T=arrs[0]; q,nn=local(T)
    q[:,0]-=(q[:,0].max()+q[:,0].min())/2
    q[:,2]-=q[:,2].min()
    # 수키와/암키와: 바닥(가장 낮은 점)을 y=0
    q[:,1]-=q[:,1].min()
    uv=T[:,3:5].copy(); uv[:,1]=1.0-uv[:,1]   # 그림 좌표(위가 0)
    mods[name]={'tris':len(T)//3,'size':(q.max(0)-q.min(0)).round(4).tolist(),
        'pos':q.round(4).reshape(-1).tolist(),'nrm':nn.round(3).reshape(-1).tolist(),'uv':uv.round(4).reshape(-1).tolist(),
        'uv_rect':[float(uv[:,0].min()),float(uv[:,1].min()),float(uv[:,0].max()),float(uv[:,1].max())]}
    # 여러 표본 크기 통계
    sz=[]
    for T2 in arrs[:40]:
        q2,_=local(T2); sz.append(q2.max(0)-q2.min(0))
    mods[name]['size_median_40']=np.median(np.array(sz),0).round(4).tolist()
# 수키와 겉 단면: 바깥 법선(y>0.3) 점의 (x,y)를 x로 묶어 위 껍질
q,nn=local(np.array(d['112'][0])); q[:,0]-=(q[:,0].max()+q[:,0].min())/2; q[:,1]-=q[:,1].min()
outer=q[nn[:,1]>-0.2]
xs=np.linspace(outer[:,0].min(),outer[:,0].max(),9)
prof=[]
for x in xs:
    m=np.abs(outer[:,0]-x)<0.012
    prof.append([round(float(x),4), round(float(outer[m,1].max()),4)])
mods['sukiwa_profile']=prof
# 암키와 오목 깊이(가운데 vs 가장자리, 위 껍질)
q,nn=local(np.array(d['120'][0])); q[:,0]-=(q[:,0].max()+q[:,0].min())/2
up=q[nn[:,1]>0.3]
mods['amkiwa_sag']=round(float(up[np.abs(up[:,0])>0.09][:,1].max()-up[np.abs(up[:,0])<0.03][:,1].max()),4)
# 수키와 줄 간격: 같은 비탈(같은 길이 방향) 수키와 중심의 폭 방향 투영 차
cs=[];Ls=[]
for t in d['112']:
    if isinstance(t,list):
        T=np.array(t); c,L,W,H=frame(T); cs.append(c); Ls.append(L)
cs=np.array(cs); Ls=np.array(Ls)
pitches=[]
for i in range(len(cs)):
    for j in range(len(cs)):
        if i==j or np.dot(Ls[i],Ls[j])<0.99: continue
        dv=cs[j]-cs[i]; W=np.cross(Ls[i],[0,0,1.0]); W/=np.linalg.norm(W)
        along=abs(dv@Ls[i]); across=abs(dv@W)
        if along<0.2 and 0.15<across<0.8: pitches.append(across)
mods['row_pitch_samples']=len(pitches)
mods['row_pitch_m']=round(float(np.percentile(pitches,25)),4) if pitches else None
mods['row_pitch_pct']=np.percentile(pitches,[10,25,50,75,90]).round(3).tolist() if pitches else None
mods['tile_len_m']=round(mods['sukiwa2']['size'][2]/2,4)
mods['amkiwa_course_m']=round(mods['amkiwa5']['size'][2]/5,4)
mods['source']={'uid':'13999891595861016944','name':'국가민속문화유산_정읍_김명관_고택_안채','file':'anchae.fbx (material MI_Giwa)','license':'KOGL-1 (공공누리 제1유형)','attribution':'국가유산청'}
json.dump(mods,open(out,'w'),ensure_ascii=False)
for k,v in mods.items():
    if isinstance(v,dict) and 'tris' in v: print(k,v['tris'],v['size'],v['size_median_40'],[round(x,3) for x in v['uv_rect']])
    elif k!='source': print(k,v)
