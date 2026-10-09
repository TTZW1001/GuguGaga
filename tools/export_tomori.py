"""Run with Blender --background --disable-autoexec SOURCE.blend --python this_file.
The input blend is never overwritten; export only gameplay facial morphs and
1024px textures, which are sufficient for a 100px on-screen head.
"""
import bpy, pathlib, zipfile
root=pathlib.Path(__file__).resolve().parents[1]
used={
    'Basis','face_Base_obj_morph0','face_Base_obj_morph7',
    'face_Base_obj_morph3','face_Base_obj_morph5','face_Base_obj_morph6',
    'face_NoOutline_obj_morph0','face_NoOutline_obj_morph1'
}
head=bpy.data.objects['Tomori_mesh']
for key in list(head.data.shape_keys.key_blocks):
    if key.name not in used:head.shape_key_remove(key)
for key in head.data.shape_keys.key_blocks:key.value=0
temp=root/'tools/source/tomori-textures'
temp.mkdir(parents=True,exist_ok=True)
for image in bpy.data.images:
    if not image.packed_file or image.size[0]==0:continue
    maximum=512 if image.name=='eye.png' else 1024
    width,height=image.size
    factor=min(1,maximum/max(width,height))
    if factor<1:image.scale(round(width*factor),round(height*factor))
    image.filepath_raw=str(temp/image.name)
    image.file_format='PNG'
    image.save()
    image.pack()
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj.type in {'MESH','ARMATURE'} and not obj.hide_render:obj.select_set(True)
out=root/'assets/tomori'
out.mkdir(exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out/'penguin.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
with zipfile.ZipFile(root/'assets/incoming/private_madagascar.zip') as source:
    (out/'body-license.txt').write_bytes(source.read('license.txt'))
print('OPTIMIZED_EXPORT', (out/'penguin.glb').stat().st_size, 'bytes;',len(head.data.shape_keys.key_blocks)-1,'facial morphs',flush=True)
