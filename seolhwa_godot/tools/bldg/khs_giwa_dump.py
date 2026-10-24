import bpy, bmesh, sys, json
import numpy as np
argv = sys.argv[sys.argv.index('--')+1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
o=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]
me=o.data; mats=[m.name for m in me.materials]; gi=mats.index('MI_Giwa')
bm=bmesh.new(); bm.from_mesh(me); bm.transform(o.matrix_world)
uvl=bm.loops.layers.uv.active
faces=[f for f in bm.faces if f.material_index==gi]
fs=set(faces); seen=set(); parts=[]
for f in faces:
    if f in seen: continue
    st=[f]; seen.add(f); comp=[]
    while st:
        g=st.pop(); comp.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h in fs and h not in seen: seen.add(h); st.append(h)
    parts.append(comp)
res={'parts':{}}
want={112,120,92,40,96,64,38,60,72,48,56}
cnt={}
for p in parts:
    n=len(p)
    if n not in want: continue
    k=cnt.get(n,0); cnt[n]=k+1
    tri=[]
    for f in p:
        L=list(f.loops)
        for i in range(1,len(L)-1):
            for l in (L[0],L[i],L[i+1]):
                tri.append(list(l.vert.co)+list(l[uvl].uv)+list(l.vert.normal))
    res['parts'].setdefault(str(n),[]).append(tri if k<40 else None)
    if k>=40:
        vs=np.array([v.co[:] for f in p for v in f.verts]); 
        res['parts'][str(n)][-1]={'c':vs.mean(0).tolist()}
json.dump(res,open(out,'w'))
