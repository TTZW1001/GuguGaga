"""Editable wooden suanpan, in the penguin's model-space units."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/study'
SOURCE = ROOT / 'assets/incoming/study'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness=.72):
    mat = bpy.data.materials.new(name)
    values = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    linear = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Roughness'].default_value = roughness
    return mat


wood = material('Honey wood frame', 'b7804d')
rod_mat = material('Warm brass rods', 'c6a064', .5)
lower_mat = material('Jade lower beads', '466c60', .45)
upper_mat = material('Amber upper beads', 'a75737', .5)
root = bpy.data.objects.new('Abacus', None)
bpy.context.collection.objects.link(root)
static = []


def point(xyz):
    x, y, z = xyz
    return x, -z, y


def cube(name, position, dimensions):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(position))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = point((dimensions[0], dimensions[1], -dimensions[2]))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(wood)
    bevel = obj.modifiers.new('Soft wooden edges', 'BEVEL')
    bevel.width = .003
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    static.append(obj)


for sign in [-1, 1]:
    cube('Side rail', (sign*.19, 0, 0), (.020, .28, .030))
    cube('End rail', (0, sign*.13, 0), (.38, .020, .030))
cube('Counting divider', (0, .035, 0), (.36, .010, .027))
for col in range(7):
    x = (col-3)*.05
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.0023,
                                      depth=.24, location=point((x, 0, 0)))
    obj = bpy.context.object
    obj.name = 'Counting rod'
    obj.data.materials.append(rod_mat)
    static.append(obj)
    for bank, ys, mat in [('L', [-.016-.022*i for i in range(5)], lower_mat),
                          ('U', [.078, .103], upper_mat)]:
        for i, y in enumerate(ys):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8,
                                                radius=1, location=point((x, y, 0)))
            bead = bpy.context.object
            bead.name = f'Bead_{col}_{bank}{i}'
            bead.scale = (.017, .011, .009)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            bead.data.materials.append(mat)
            for face in bead.data.polygons:
                face.use_smooth = True
            bead.parent = root

bpy.ops.object.select_all(action='DESELECT')
for obj in static:
    obj.select_set(True)
bpy.context.view_layer.objects.active = static[0]
bpy.ops.object.join()
bpy.context.object.name = 'AbacusFrame'
bpy.context.object.parent = root
bpy.ops.object.select_all(action='SELECT')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'abacus.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'abacus.glb'), export_format='GLB',
                         use_selection=True, export_animations=False,
                         export_cameras=False, export_lights=False)
print('ABACUS_EXPORTED', (OUT/'abacus.glb').stat().st_size, flush=True)
