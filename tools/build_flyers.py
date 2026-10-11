"""Small matching flyer stack and single flyer in unscaled character units."""
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
    shader.inputs['Roughness'].default_value = .9
    return mat


paper = material('Warm paper', 'fff6df')
edge = material('Paper edges', 'e1dfcc')
teal = material('Teal print', '6a9486')
gold = material('Apricot print', 'd8ac66')


def root(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    return obj


def box(parent, name, pos, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(pos[0], -pos[2], pos[1]))
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    obj.scale = (size[0], size[2], size[1])
    obj.data.materials.append(mat)
    return obj


def print_page(parent, z, back=False):
    # Readable decorative printing on both faces without textures or fonts.
    box(parent, 'Heading', (0,.060,z), (.105,.016,.0003), teal)
    box(parent, 'Highlight', (-.029,.021,z), (.040,.035,.0003), gold)
    for y, width in [(0.034,.036),(.020,.042),(.006,.033)]:
        box(parent, 'Feature', (.027,y,z), (width,.004,.0003), teal)
    for y, width in [(-.024,.107),(-.038,.097),(-.052,.074)]:
        box(parent, 'Copy', (0,y,z), (width,.003,.0003), teal)


stack = root('FlyerStack')
for i in range(12):
    box(stack, 'Sheet', ((i%2)*.002, (i%3)*.001, -.01375+i*.0025),
        (.170,.215,.0024), paper if i%2==0 else edge)
print_page(stack,.0151)
single = root('SingleFlyer')
box(single, 'Paper', (0,0,0), (.148,.180,.002), paper)
print_page(single,.0012)
print_page(single,-.0012,True)

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'flyers.blend'))
for obj, name in [(stack,'flyer_stack'),(single,'flyer_single')]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    for child in obj.children: child.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB',
                             use_selection=True, export_animations=False,
                             export_cameras=False, export_lights=False)
    print('FLYER_ASSET_EXPORTED',name,(OUT/(name+'.glb')).stat().st_size,flush=True)
