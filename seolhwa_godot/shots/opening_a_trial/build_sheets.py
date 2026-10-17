# 여는 사건 A 「소나기」 시험 — 캡처에서 시트·GIF·시각표 만들기(시험 브랜치 전용)
import glob,re,os,json,sys
from PIL import Image,ImageDraw,ImageFont
CAP=os.path.dirname(os.path.abspath(__file__))+'/cap'
OUT='/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-opening-a/seolhwa_godot/shots/opening_a_trial'
os.makedirs(OUT,exist_ok=True)
V=[v for v in ['shipped','sonagi_name','sonagi_other','sonagi_knock'] if os.path.isdir(CAP+'/'+v)]
LABEL={'shipped':'출시판(지금+E1~E7)','sonagi_name':'소나기 · 이름 쪽','sonagi_other':'소나기 · 날씨 쪽','sonagi_knock':'소나기 · E1 지킴(이름 쪽)'}
font=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',18)
big=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',28)
def frames(v):
    fs=glob.glob(CAP+'/%s/frames/*.jpg'%v)
    return sorted([(float(re.search(r'_t([\d.]+)\.jpg',f).group(1)),f) for f in fs])
def near(fr,t): return min(fr,key=lambda x:abs(x[0]-t))
def info(v):
    L=open(CAP+'/%s/log.txt'%v).read()
    m=re.search(r'p0_ms=(\d+) ng0_ms=(\d+)',L); off=(int(m.group(1))-int(m.group(2)))/1000
    c=re.search(r'NEWCAP t0_ms=(\d+)',L); cap=(int(m.group(2))-int(c.group(1)))/1000   # 새 게임 시각(캡처 기준)
    b=[(n,round(float(t)+off,2)) for n,t in re.findall(r'FIRST15 prologue (\S+) t=([\d.]+)',L)]
    s=[(n,round(float(t)+off,2)) for n,t in re.findall(r'FIRST15 sonagi ([a-z_0-9]+) t=([\d.]+)',L)]
    sfx=[(n,round(float(t)+off,2)) for n,t in re.findall(r'FIRST15 sfx (\S+) t=([\d.]+)',L)]
    return dict(beats=b,sonagi=s,sfx=sfx,off=off,cap=cap)
I={v:info(v) for v in V}
def ft(v,t): return t+I[v]['cap']   # 새 게임 기준 t → 캡처 파일 시각
for v in V:
    fr=frames(v); b=I[v]['beats']; bd=dict(b); ctl=bd['control']
    W,H=320,180; cols=8
    ts=[i*0.5 for i in range(int((ctl+1.5)/0.5)+1)]
    rows=(len(ts)+cols-1)//cols
    sh=Image.new('RGB',(W*cols,H*rows+44),(20,20,20)); dr=ImageDraw.Draw(sh)
    dr.text((8,6),'%s — 새 게임부터 0.5초마다 (방 안 조작 %.1f초)'%(LABEL[v],ctl),fill='white',font=big)
    ev=b+[(n,t) for n,t in I[v]['sonagi'] if n in ('first_e','branch','deliver')]
    for i,t in enumerate(ts):
        tf,f=near(fr,ft(v,t)); im=Image.open(f).resize((W,H)); d=ImageDraw.Draw(im)
        lab='%.1f'%t
        for n,bt in ev:
            if t-0.25<=bt<t+0.25: lab+=' '+n
        d.rectangle((0,0,W,22),fill=(0,0,0)); d.text((4,1),lab[:40],fill='yellow',font=font)
        sh.paste(im,((i%cols)*W,44+(i//cols)*H))
    sh.save(f'{OUT}/contact_{v}.jpg',quality=78)
    g=[]
    for i in range(81):
        t=i*0.25; tf,f=near(fr,ft(v,t)); im=Image.open(f).resize((480,270)); d=ImageDraw.Draw(im)
        d.rectangle((0,0,230,24),fill=(0,0,0)); d.text((4,2),'%s %.2f'%(LABEL[v],t),fill='yellow',font=font)
        g.append(im.convert('P',palette=Image.ADAPTIVE,colors=96))
    g[0].save(f'{OUT}/first20_{v}.gif',save_all=True,append_images=g[1:],duration=250,loop=0,optimize=True)
W,H=400,225; ts=[i*1.0 for i in range(31)]
sh=Image.new('RGB',(70+W*len(V),50+H*len(ts)),(20,20,20)); dr=ImageDraw.Draw(sh)
for j,v in enumerate(V): dr.text((70+j*W+8,12),LABEL[v],fill='white',font=big)
for i,t in enumerate(ts):
    dr.text((6,50+i*H+95),'%.0f초'%t,fill='yellow',font=big)
    for j,v in enumerate(V):
        tf,f=near(frames(v),ft(v,t)); sh.paste(Image.open(f).resize((W,H)),(70+j*W,50+i*H))
sh.save(f'{OUT}/side_by_side_first30s.jpg',quality=72)
json.dump(I,open(OUT+'/timing.json','w'),ensure_ascii=False,indent=1)
for v in V:
    bd=dict(I[v]['beats']); sd=dict(I[v]['sonagi'])
    print(v, json.dumps({k:bd.get(k) for k in ['control_play','INTRO_02','book_look','present','E6_knock','dip','control']},ensure_ascii=False), json.dumps({k:sd.get(k) for k in ['first_e','split','branch','deliver','rain_end']}), 'first_sfx',I[v]['sfx'][:3])
