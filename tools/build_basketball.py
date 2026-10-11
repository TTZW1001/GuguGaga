"""Editable, unbranded basketball in the character's model-space units."""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/sports'
SOURCE = ROOT / 'assets/incoming/sports'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color):
    mat = bpy.data.materials.new(name)
    srgb = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in srgb]
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Roughness'].default_value = .82
    return mat


orange = material('Matte orange leather', 'd97c32')
black = material('Dark recessed channels', '37251d')
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=.064)
ball = bpy.context.object
ball.name = 'Basketball leather'
ball.data.materials.append(orange)
for face in ball.data.polygons:
    face.use_smooth = True
for axis in range(3):
    curve = bpy.data.curves.new('Basketball channel', 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = .00125
    curve.bevel_resolution = 1
    spline = curve.splines.new('POLY')
    spline.points.add(95)
    spline.use_cyclic_u = True
    for i, vertex in enumerate(spline.points):
        angle = math.tau*i/96
        point = [.0641*math.cos(angle), .0641*math.sin(angle)]
        xyz = [0.0, 0.0, 0.0]
        xyz[(axis+1)%3], xyz[(axis+2)%3] = point
        vertex.co = (*xyz, 1)
    obj = bpy.data.objects.new('Black channel '+str(axis+1), curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(black)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')

bpy.ops.object.select_all(action='SELECT')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'basketball.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'basketball.glb'), export_format='GLB',
                         use_selection=True, export_animations=False,
                         export_cameras=False, export_lights=False)
print('BASKETBALL_EXPORTED', (OUT/'basketball.glb').stat().st_size, flush=True)
