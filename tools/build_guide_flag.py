"""Triangular guide flag, in unscaled character units; no textures required."""
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

red = material('Plain red flag', 'e94242')
wood = material('Flag pole', 'cda16c')
cap = material('Pole cap', 'e7c286')
root = bpy.data.objects.new('GuideFlag', None)
bpy.context.collection.objects.link(root)
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.0055, depth=.385, location=(0,0,.1475))
pole=bpy.context.object;pole.name='Wooden pole';pole.parent=root;pole.data.materials.append(wood)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.008, location=(0,0,.343))
obj=bpy.context.object;obj.name='Small pole cap';obj.parent=root;obj.data.materials.append(cap)
from math import sin,pi
vertices=[];faces=[]
for row in range(5):
 for column in range(12):
  t=column/12;v=row/4
  x=-.006-.19*t
  y=.2675+.125*(1-t)*(v-.5)-.009*t*t
  z=.009*sin(t*pi*2.5)*t+.004*sin(v*pi)*t
  vertices.append((x,-z,y))
tip=len(vertices)
vertices.append((-.196,-.009,.2585))
for row in range(4):
 for col in range(11):
  a=row*12+col;faces.append((a,a+1,a+13,a+12))
 faces.append((row*12+11,tip,(row+1)*12+11))
mesh=bpy.data.meshes.new('Gently curved triangular red cloth');mesh.from_pydata(vertices,[],faces);mesh.update()
obj=bpy.data.objects.new('Small red flag',mesh);bpy.context.collection.objects.link(obj);obj.parent=root;obj.data.materials.append(red)
mod=obj.modifiers.new('Cloth thickness','SOLIDIFY');mod.thickness=.0015
bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action='DESELECT')
for obj in root.children:obj.select_set(True)
bpy.context.view_layer.objects.active=pole;bpy.ops.object.join();bpy.context.object.name='FlagMesh'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'guide_flag.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'guide_flag.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
print('GUIDE_FLAG_EXPORTED',flush=True)
