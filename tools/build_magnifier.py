"""Small brass magnifier with a jade grip; origin at the wing's grip point."""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/study'
SOURCE = ROOT / 'assets/incoming/study'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness=.5, alpha=1):
    mat = bpy.data.materials.new(name)
    values = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    linear = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
    mat.diffuse_color = (*linear, alpha)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Alpha'].default_value = alpha
    shader.inputs['Roughness'].default_value = roughness
    if alpha<1:
        mat.surface_render_method = 'DITHERED'
    return mat


brass = material('Soft brass rim', 'b78a50', .45)
grip_mat = material('Jade green handle', '42665a', .7)
glass = material('Clear pale blue lens', 'c9e7e4', .25, .14)
shine = material('Quiet lens glint', 'f0faf3', .35, .55)
root = bpy.data.objects.new('Magnifier', None)
bpy.context.collection.objects.link(root)


def finish(obj, name, mat):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = root
    for face in obj.data.polygons:
        face.use_smooth = True


# Blender Z maps to Godot Y; Blender -Y maps to Godot +Z.
bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=10,
                                location=(0, 0, .15), rotation=(math.pi/2, 0, 0),
                                major_radius=.062, minor_radius=.006)
finish(bpy.context.object, 'BrassRim', brass)
bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=.011, depth=.11,
                                    location=(0, 0, .025))
finish(bpy.context.object, 'JadeGrip', grip_mat)
for z in [-.03, .08]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8,
                                        radius=.011, location=(0, 0, z))
    finish(bpy.context.object, 'Rounded grip end', grip_mat)
bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=.009, depth=.023,
                                    location=(0, 0, .083))
finish(bpy.context.object, 'GripCollar', brass)
bpy.ops.mesh.primitive_circle_add(vertices=48, radius=.057, fill_type='NGON',
                                 location=(0, 0, .15), rotation=(math.pi/2, 0, 0))
finish(bpy.context.object, 'ClearLens', glass)
for index, (start, end, radius) in enumerate([(105, 145, .047), (292, 310, .050)]):
    curve = bpy.data.curves.new('Lens glint', 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = .0011
    curve.bevel_resolution = 1
    spline = curve.splines.new('POLY')
    spline.points.add(10)
    for i, vertex in enumerate(spline.points):
        angle = math.radians(start+(end-start)*i/10)
        vertex.co = (radius*math.cos(angle), -.001, .15+radius*math.sin(angle), 1)
    obj = bpy.data.objects.new('LensGlint'+str(index), curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(shine)
    obj.parent = root
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')

bpy.ops.object.select_all(action='SELECT')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'magnifier.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'magnifier.glb'), export_format='GLB',
                         use_selection=True, export_animations=False,
                         export_cameras=False, export_lights=False)
print('MAGNIFIER_EXPORTED', (OUT/'magnifier.glb').stat().st_size, flush=True)
