"""Lightweight handheld microphone, origin at the wing grip (Godot Y up)."""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/study'
SOURCE = ROOT / 'assets/incoming/study'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    values = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    linear = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Roughness'].default_value = roughness
    return mat


handle = material('Charcoal grip', '394d52', .7)
silver = material('Soft silver grille', '9badae', .65)
dark = material('Grille recess', '344648', .85)
brass = material('Warm brass collar', 'bc965a', .5)
root = bpy.data.objects.new('Microphone', None)
bpy.context.collection.objects.link(root)


def finish(obj, name, mat):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = root
    for face in obj.data.polygons:
        face.use_smooth = True


def cylinder(name, z, radius, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=depth,
                                        location=(0, 0, z))
    finish(bpy.context.object, name, mat)


cylinder('Handle', .024, .011, .10, handle)
cylinder('GripEnd', -.027, .0115, .009, brass)
cylinder('Collar', .077, .014, .014, brass)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12,
                                    radius=1, location=(0, 0, .105))
bpy.context.object.scale = (.025, .025, .028)
finish(bpy.context.object, 'Capsule', dark)
# Raised rings and meridians read as a microphone grille without a texture.
for latitude in [-.72, -.36, 0, .36, .72]:
    radius = .0257*math.sqrt(1-latitude*latitude)
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=4,
                                    major_radius=radius, minor_radius=.001,
                                    location=(0, 0, .105+.0285*latitude))
    finish(bpy.context.object, 'GrilleRing', silver)
for index in range(10):
    curve = bpy.data.curves.new('Grille strand', 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = .0008
    curve.bevel_resolution = 0
    spline = curve.splines.new('POLY')
    spline.points.add(12)
    angle = index*math.tau/10
    for i, vertex in enumerate(spline.points):
        t = math.pi*i/12
        vertex.co = (.0257*math.sin(t)*math.cos(angle),
                     .0257*math.sin(t)*math.sin(angle), .105+.0285*math.cos(t), 1)
    obj = bpy.data.objects.new('GrilleStrand', curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(silver)
    obj.parent = root
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
bpy.ops.object.select_all(action='SELECT')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'microphone.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'microphone.glb'), export_format='GLB',
                         use_selection=True, export_animations=False,
                         export_cameras=False, export_lights=False)
print('MICROPHONE_EXPORTED', (OUT/'microphone.glb').stat().st_size, flush=True)
