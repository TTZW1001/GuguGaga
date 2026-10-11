"""Small reusable feeding props; export editable Blender sources and GLBs."""
import bpy
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/food'
SOURCE = ROOT / 'assets/incoming/food'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)


def material(name, hex_color):
    mat = bpy.data.materials.new(name)
    rgb = [int(hex_color[i:i+2], 16)/255 for i in (0, 2, 4)]
    linear = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Roughness'].default_value = .88
    return mat


def ellipsoid(name, centre, scale, mat):
    # Describe the front silhouette in Godot XY, then convert to Blender X,-Z,Y.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=(centre[0], -centre[2], centre[1]))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def tube(name, points, radius, mat):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new('POLY')
    spline.points.add(len(points)-1)
    for vertex, point in zip(spline.points, points):
        vertex.co = (point[0], -point[2], point[1], 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    obj.select_set(False)


def extruded(name, outline, depth, mat):
    # Bevel the silhouette so the dried fish reads softly at game size.
    verts = [(x, -z, y) for z in [-depth, depth] for x, y in outline]
    n = len(outline)
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    bevel = obj.modifiers.new('Soft edges', 'BEVEL')
    bevel.width = .003
    bevel.segments = 2
    return obj


for kind in ['bread', 'fish', 'steak', 'snack']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    golden = material('Warm baked crust', 'd69c56')
    cream = material('Cream highlights', 'f7ddb1')
    dark = material('Toasted details', '76513c')
    if kind == 'bread':
        ellipsoid('Round soft bread', (0, 0, 0), (.075, .047, .034), golden)
        for centre in [-.035, 0, .035]:
            points = []
            for i in range(13):
                t = i/12
                x, y = centre+(t-.5)*.012, .006+(t-.5)*.048
                z = .034*math.sqrt(max(0, 1-(x/.075)**2-(y/.047)**2))+.0008
                points.append((x, y, z))
            tube('Bread scoring', points, .0026, cream)
    elif kind == 'fish':
        ellipsoid('Golden dried fish', (.010, 0, 0), (.059, .034, .018), golden)
        extruded('Forked tail', [(-.043, 0), (-.083, .032), (-.075, 0), (-.083, -.032)], .009, golden)
        extruded('Top fin', [(-.022, .020), (-.005, .048), (.020, .023)], .005, cream)
        extruded('Bottom fin', [(-.016, -.023), (.007, -.042), (.026, -.022)], .005, cream)
        ellipsoid('Fish eye', (.047, .010, .016), (.0045, .0045, .002), dark)
        tube('Gill', [(.032, -.014, .016), (.027, 0, .020), (.032, .017, .016)], .0014, dark)
    elif kind == 'steak':
        salmon = material('Salmon flesh', 'e99778')
        skin = material('Fish steak skin', '738b8c')
        ellipsoid('Rounded fish steak skin', (0, 0, 0), (.075, .054, .027), skin)
        ellipsoid('Salmon face', (0, 0, .007), (.069, .048, .023), salmon)
        for sign in [-1, 1]:
            for offset in [-.025, -.004, .017]:
                points = []
                for i in range(13):
                    t = i/12
                    x = sign*(.020+.037*t)
                    y = offset+.010*math.sin(math.pi*t)
                    z = .007+.023*math.sqrt(max(0, 1-(x/.069)**2-(y/.048)**2))+.0008
                    points.append((x, y, z))
                tube('Cream marbling', points, .0015, cream)
        ellipsoid('Steak bone', (0, -.003, .030), (.009, .013, .002), cream)
    else:
        ellipsoid('Happy cookie', (0, 0, 0), (.061, .058, .025), golden)
        for x, y in [(-.026, .021), (.018, .030), (-.035, -.016), (.006, -.006), (.030, -.026)]:
            z = .025*math.sqrt(max(0, 1-(x/.061)**2-(y/.058)**2))
            ellipsoid('Chocolate chip', (x, y, z), (.006, .006, .002), dark)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(kind+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')), export_format='GLB', use_selection=True, export_animations=False, export_cameras=False, export_lights=False)
    print('FOOD_EXPORTED', kind, (OUT/(kind+'.glb')).stat().st_size, flush=True)
