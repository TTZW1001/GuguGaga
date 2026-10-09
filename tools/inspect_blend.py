import bpy, json, pathlib
root=pathlib.Path(__file__).resolve().parents[1]
summary={'version':bpy.app.version_string,'objects':[],'actions':[],'images':[],'texts':[]}
for obj in bpy.data.objects:
    item={'name':obj.name,'type':obj.type,'location':list(obj.location),'scale':list(obj.scale),'dimensions':list(obj.dimensions),'hidden':obj.hide_viewport,'render_hidden':obj.hide_render,'parent':obj.parent.name if obj.parent else None}
    if obj.type=='MESH':
        item.update(vertices=len(obj.data.vertices),faces=len(obj.data.polygons),materials=[m.name if m else None for m in obj.data.materials],modifiers=[(m.name,m.type) for m in obj.modifiers])
    if obj.type=='ARMATURE':
        item['bones']=[{'name':b.name,'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None} for b in obj.data.bones]
    summary['objects'].append(item)
for a in bpy.data.actions:summary['actions'].append({'name':a.name,'frames':list(a.frame_range)})
for i in bpy.data.images:summary['images'].append({'name':i.name,'path':i.filepath,'packed':bool(i.packed_file),'size':list(i.size)})
for t in bpy.data.texts:summary['texts'].append({'name':t.name,'text':t.as_string()[:3000]})
for m in bpy.data.materials:
    print('MATERIAL',m.name,list(m.diffuse_color),[(n.type,n.name) for n in m.node_tree.nodes] if m.use_nodes else None,flush=True)
(root/'tools/source/tomori-inspection.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2),flush=True)
# Export only visible character geometry; do not change the user's blend file.
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj.type in {'MESH','ARMATURE'} and not obj.hide_render:obj.select_set(True)
out=root/'assets/tomori'
out.mkdir(exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out/'penguin.glb'),export_format='GLB',use_selection=True,export_animations=True,export_cameras=False,export_lights=False)
print('EXPORTED',out/'penguin.glb',flush=True)
