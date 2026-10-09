import bpy, json, pathlib
from collections import Counter
out={}
for obj in bpy.data.objects:
    if obj.type!='MESH':continue
    out[obj.name]={'shape_keys':list(obj.data.shape_keys.key_blocks.keys()) if obj.data.shape_keys else [],'vertex_groups':[g.name for g in obj.vertex_groups],'dominant_groups':dict(Counter(obj.vertex_groups[max(v.groups,key=lambda g:g.weight).group].name for v in obj.data.vertices if v.groups))}
print(json.dumps(out,ensure_ascii=False,indent=2),flush=True)
(pathlib.Path(__file__).resolve().parents[1]/'tools/source/tomori-face.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
