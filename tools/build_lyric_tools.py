"""Small spiral notebook and pencil, in the character's unscaled model units."""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/study'
SOURCE = ROOT / 'assets/incoming/study'
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
    shader.inputs['Roughness'].default_value = .8
    return mat


cover = material('Sage cover', '628b7d')
paper = material('Cream paper', 'fff6df')
rule = material('Faint ruled lines', 'd7dac3')
brass = material('Brass binding', 'b39155')
yellow = material('Warm pencil lacquer', 'd5a653')
wood = material('Pencil wood', 'd4b58c')
graphite = material('Graphite', '354544')
eraser = material('Soft pink eraser', 'c68a8c')


def new_root(name):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    return root


def finish(obj, name, mat, root, smooth=False):
    obj.name = name
    obj.parent = root
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = smooth
    return obj


def box(name, pos, size, mat, root):
    # Godot coordinates (x,y,z) -> Blender (x,-z,y).
    bpy.ops.mesh.primitive_cube_add(size=1, location=(pos[0], -pos[2], pos[1]))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    return finish(obj, name, mat, root)


notebook = new_root('LyricNotebook')
box('SoftCover', (0,0,-.006), (.30,.228,.007), cover, notebook)
box('PaperStack', (0,0,.0015), (.282,.212,.012), paper, notebook)
for i in range(5):
    box('PageEdge', (0,-.106,-.003+i*.002), (.282,.0007,.0006), rule, notebook)
for y in [.05,.02,-.01,-.04,-.07]:
    box('Rule', (.008,y,.0078), (.247,.0007,.0005), rule, notebook)
box('Header', (.052,.081,.0078), (.09,.002,.0005), brass, notebook)
for i in range(7):
    bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=5,
                                    major_radius=.008, minor_radius=.0018,
                                    location=(-.142, 0, -.085+i*.028))
    finish(bpy.context.object, 'SpiralBinding', brass, notebook, True)

pencil = new_root('LyricPencil')


def cylinder(name, y, radius, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=depth,
                                        location=(0,0,y))
    return finish(bpy.context.object, name, mat, pencil)


cylinder('PencilBarrel', -.0245, .0065, .141, yellow)
cylinder('EraserCollar', .044, .0068, .009, brass)
cylinder('Eraser', .052, .0067, .008, eraser)
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=.002, radius2=.0065,
                                depth=.016, location=(0,0,-.103))
finish(bpy.context.object, 'SharpenedWood', wood, pencil)
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0, radius2=.002,
                                depth=.004, location=(0,0,-.113))
finish(bpy.context.object, 'GraphiteTip', graphite, pencil)

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'lyric_tools.blend'))
for root, filename in [(notebook,'lyric_notebook'),(pencil,'lyric_pencil')]:
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in root.children: obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(filename+'.glb')), export_format='GLB',
                             use_selection=True, export_animations=False,
                             export_cameras=False, export_lights=False)
    print('LYRIC_ASSET_EXPORTED', filename, (OUT/(filename+'.glb')).stat().st_size, flush=True)
