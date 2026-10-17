import glob,re,os,json
from PIL import Image,ImageDraw,ImageFont,ImageStat
OUT='/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-prologue-trial/seolhwa_godot/shots/prologue_trial'
os.makedirs(OUT,exist_ok=True)
V=['current','current_e','framed']
font=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',20)
big=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',28)
def frames(v):
    fs=glob.glob('cap/%s/frames/*.jpg'%v)
    return sorted([(float(re.search(r'_t([\d.]+)\.jpg',f).group(1)),f) for f in fs])
def near(fr,t): return min(fr,key=lambda x:abs(x[0]-t))
def beats(v):
    L=open('cap/%s/log.txt'%v).read()
    m=re.search(r'p0_ms=(\d+) ng0_ms=(\d+)',L); off=(int(m.group(1))-int(m.group(2)))/1000
    c=re.search(r'NEWCAP t0_ms=(\d+)',L); capoff=(int(m.group(2))-int(c.group(1)))/1000  # ng0 relative to capture t0
    b=[(n,float(t)+off) for n,t in re.findall(r'FIRST15 prologue (\S+) t=([\d.]+)',L)]
    s=[(n,float(t)+off) for n,t in re.findall(r'PROTRIAL sfx (\S+) t=([\d.]+)',L)]
    cut=[float(t)+off for t in re.findall(r'PROTRIAL sound_cut t=([\d.]+)',L)]
    return b,s,cut,capoff
info={}
for v in V:
    fr=frames(v); b,s,cut,capoff=beats(v)
    ctl=dict(b)['control']
    # contact sheet: every 0.5 s to control+1
    W,H=320,180; cols=8
    ts=[i*0.5 for i in range(int((ctl+1.0)/0.5)+1)]
    rows=(len(ts)+cols-1)//cols
    sh=Image.new('RGB',(W*cols,H*rows+40),(20,20,20)); dr=ImageDraw.Draw(sh)
    dr.text((8,6),'%s — 새 게임부터 0.5초마다 (조작 %.1f초)'%(v,ctl),fill='white',font=big)
    bt={n:t for n,t in b}
    for i,t in enumerate(ts):
        tf,f=near(fr,t); im=Image.open(f).resize((W,H)); d=ImageDraw.Draw(im)
        lab='%.1f'%t
        for n,bt_ in b:
            if t-0.25<=bt_<t+0.25: lab+=' '+n
        d.rectangle((0,0,W,24),fill=(0,0,0)); d.text((4,1),lab,fill='yellow',font=font)
        sh.paste(im,((i%cols)*W,40+(i//cols)*H))
    sh.save(f'{OUT}/contact_{v}.jpg',quality=82)
    # gif first 15 s at 0.25
    g=[]; gt=[i*0.25 for i in range(61)]
    for t in gt:
        tf,f=near(fr,t); im=Image.open(f).resize((480,270)); d=ImageDraw.Draw(im)
        d.rectangle((0,0,150,26),fill=(0,0,0)); d.text((4,2),'%s %.2f'%(v,t),fill='yellow',font=font)
        g.append(im.convert('P',palette=Image.ADAPTIVE,colors=128))
    g[0].save(f'{OUT}/first15_{v}.gif',save_all=True,append_images=g[1:],duration=250,loop=0,optimize=True)
    info[v]=dict(beats=b,sfx=s,cut=cut,ctl=ctl,capoff=capoff)
# side by side first 10 s, 0.5 s rows
W,H=400,225; ts=[i*0.5 for i in range(21)]
sh=Image.new('RGB',(70+W*3,50+H*len(ts)),(20,20,20)); dr=ImageDraw.Draw(sh)
for j,v in enumerate(V): dr.text((70+j*W+8,10),v,fill='white',font=big)
for i,t in enumerate(ts):
    dr.text((6,50+i*H+90),'%.1f초'%t,fill='yellow',font=font)
    for j,v in enumerate(V):
        tf,f=near(frames(v),t); im=Image.open(f).resize((W,H))
        sh.paste(im,(70+j*W,50+i*H))
sh.save(f'{OUT}/side_by_side_first10s.jpg',quality=80)
# brightness of first 3 s
for v in V:
    info[v]['lum']=[(round(t,2),round(ImageStat.Stat(Image.open(f).convert('L')).mean[0])) for t,f in frames(v) if t<=3.3]
json.dump(info,open('timing.json','w'),ensure_ascii=False,indent=1)
print(json.dumps({v:{'beats':info[v]['beats'],'sfx':info[v]['sfx'][:6],'cut':info[v]['cut'],'lum':info[v]['lum'],'capoff':info[v]['capoff']} for v in V},ensure_ascii=False))
