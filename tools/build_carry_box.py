"""Closed cardboard box, in unscaled character units; no textures required."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/work'
SOURCE = ROOT / 'assets/incoming/work'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color):
    mat = bpy.data.materials.new(name)
    values = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    linear = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Roughness'].default_value = .95
    return mat

card = material('Kraft cardboard', 'b99266')
tape = material('Packing tape', 'd8be8e')
seam = material('Cardboard seams', '866746')
label = material('Parcel label', 'f3e9cc')
ink = material('Parcel ink', '675b49')
root = bpy.data.objects.new('CarryBox', None)
bpy.context.collection.objects.link(root)

def box(name, pos, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(pos[0], -pos[2], pos[1]))
    obj = bpy.context.object
    obj.name = name
    obj.parent = root
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Soft box edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new('Corner normals', 'WEIGHTED_NORMAL')
    return obj

box('Cardboard', (0,0,0), (.40,.20,.22), card, .003)
box('Lid seam', (0,.1004,0), (.003,.0008,.218), seam)
box('Top tape', (0,.1012,0), (.044,.001,.22), tape)
for z in [-.1105,.1105]:
    box('Tape down side', (0,.069,z), (.044,.062,.001), tape)
box('Shipping label', (.095,.102,0), (.112,.001,.078), label)
for i in range(8):
    box('Barcode', (.056+i*.010,.103,.008), (.004 if i%3 else .006,.0008,.040), ink)
for side in [-1,1]:
    x=side*.201
    box('Handle mark', (x,.022,0), (.001,.015,.055), seam)
box('Front parcel label', (-.095,.010,.1112), (.105,.065,.001), label)
for y,width in [(.029,.075),(.013,.064),(-.003,.078),(-.019,.045)]:
    box('Label print', (-.095,y,.112), (width,.003,.0007), ink)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'carry_box.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'carry_box.glb'), export_format='GLB',
                         use_selection=True, export_animations=False,
                         export_cameras=False, export_lights=False)
print('CARRY_BOX_EXPORTED', (OUT/'carry_box.glb').stat().st_size, flush=True)
