"""Tailor the red hood against the shipped penguin; keep its source untouched.
Run with the portable Blender: --background --python tools/build_red_hood.py.
"""
import bpy
import math
import json
import struct
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/accessories'
OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/tomori/penguin.glb'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
character = [o for o in bpy.context.scene.objects if o.type == 'MESH']
made = []

def material(name, color, roughness=0.88):
    m = bpy.data.materials.new(name)
    rgb = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    linear = [(v/12.92 if v <= 0.04045 else ((v+0.055)/1.055)**2.4) for v in rgb]
    m.diffuse_color = (*linear, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*linear, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    return m

red = material('Crimson wool', 'bd2339')
lining = material('Wine red lining', '711b2e')
edge = material('Rolled scarlet edges', 'd63947')
cord = material('Red drawstring', 'a41d32')

def skin(obj, mode='hood'):
    obj.parent = rig
    groups = {name: obj.vertex_groups.new(name=name) for name in ['head_x', 'neck_x', 'spine_01_x', 'arm_stretch_l', 'arm_stretch_r']}
    for v in obj.data.vertices:
        z = v.co.z
        # The crown follows the head; the shoulder cape follows the torso.
        # A continuous neck transition avoids a rigid hood/cape join when nodding.
        h = max(0.0, min(1.0, (z-0.545)/0.095))
        h = h*h*(3-2*h)
        n = (1-h)*max(0.0, min(1.0, (z-0.455)/0.10))
        arm_weight = 0.0
        arm_bone = 'arm_stretch_l' if v.co.x > 0 else 'arm_stretch_r'
        if mode == 'cape':
            lateral = max(0.0, min(1.0, (abs(v.co.x)-.105)/.09))
            lower = max(0.0, min(1.0, (.548-z)/.048))
            arm_weight = .94*lateral*lower
        for name, weight in [('head_x', h*(1-arm_weight)), ('neck_x', n*(1-arm_weight)), ('spine_01_x', (1-h-n)*(1-arm_weight)), (arm_bone, arm_weight)]:
            if weight > 0.00001:
                groups[name].add([v.index], weight, 'REPLACE')
    mod = obj.modifiers.new('Penguin skeleton', 'ARMATURE')
    mod.object = rig
    made.append(obj)

def surface(name, verts, faces, mat, thickness=0, mode='hood'):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = True
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # Recalculate before making the lining: all shells have true cloth thickness.
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    if thickness:
        mesh.materials.append(lining)
        solid = obj.modifiers.new('Lined cloth thickness', 'SOLIDIFY')
        solid.thickness = thickness
        solid.offset = -1
        solid.material_offset = 1
        solid.material_offset_rim = 0
        bpy.ops.object.modifier_apply(modifier=solid.name)
    skin(obj, mode)
    obj.select_set(False)
    return obj

def tube(name, points, radius, mat, closed=False, segments=6, mode='hood'):
    verts, faces = [], []
    for i, p in enumerate(points):
        p = Vector(p)
        before = Vector(points[(i-1) % len(points)] if closed or i else points[i])
        after = Vector(points[(i+1) % len(points)] if closed or i < len(points)-1 else points[i])
        tangent = (after-before).normalized()
        axis = tangent.cross(Vector((0, 1, 0)))
        if axis.length < 0.01:
            axis = tangent.cross(Vector((1, 0, 0)))
        axis.normalize()
        bitangent = tangent.cross(axis).normalized()
        for j in range(segments):
            a = 2*math.pi*j/segments
            verts.append(p + radius*(math.cos(a)*axis + math.sin(a)*bitangent))
    for i in range(len(points) if closed else len(points)-1):
        nxt = (i+1) % len(points)
        for j in range(segments):
            faces.append((i*segments+j, i*segments+(j+1)%segments, nxt*segments+(j+1)%segments, nxt*segments+j))
    if not closed:
        faces += [tuple(reversed(range(segments))), tuple((len(points)-1)*segments+j for j in range(segments))]
    return surface(name, verts, faces, mat, mode=mode)

# Horizontal sections, with a face opening that peaks above the bangs.
# z, half-width, depth radius, depth centre, opening half angle.
sections = [
    (.548, .142, .154, .027, .33),
    (.570, .163, .172, .027, .48),
    (.600, .192, .190, .023, .67),
    (.640, .215, .207, .020, .83),
    (.690, .222, .214, .017, .89),
    (.740, .219, .216, .014, .87),
    (.790, .205, .213, .010, .76),
    (.835, .186, .204, .007, .60),
    (.875, .162, .188, .007, .40),
    (.910, .131, .168, .009, .17),
    (.930, .104, .150, .012, .00),
    (.950, .074, .117, .008, .00),
    (.973, .041, .071, -.005, .00),
    (.995, .003, .006, -.024, .00),
]
# Interpolate sections densely so the cloth silhouette stays soft.
def catmull(a, b, c, d, t):
    return 0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
rows = []
for k in range(len(sections)-1):
    for step in range(3):
        t = step/3
        rows.append(tuple(catmull(sections[max(k-1,0)][j], sections[k][j], sections[k+1][j], sections[min(k+2,len(sections)-1)][j], t) for j in range(5)))
rows.append(sections[-1])
N = 56
verts, faces = [], []
left_edge, right_edge = [], []
for z, rx, ry, cy, opening in rows:
    opening = max(0, opening)
    for j in range(N+1):
        theta = opening+(2*math.pi-2*opening)*j/N
        # Small vertical drape folds are strongest near the nape and cheeks.
        fold = .0019*math.cos(theta*8)*max(0, min(1, (.79-z)/.22))*math.sin(math.pi*j/N)**2
        p = ((rx+fold)*math.sin(theta), cy-(ry+fold)*math.cos(theta), z)
        verts.append(p)
        if j == 0 and z <= .9301:
            left_edge.append(p)
        if j == N and z <= .9301:
            right_edge.append(p)
for i in range(len(rows)-1):
    for j in range(N):
        faces.append((i*(N+1)+j, i*(N+1)+j+1, (i+1)*(N+1)+j+1, (i+1)*(N+1)+j))
faces.append(tuple((len(rows)-1)*(N+1)+j for j in range(N+1)))
hood = surface('RedHood_Cloth', verts, faces, red, .004)
tube('RedHood_FaceHem', left_edge+list(reversed(right_edge[:-1])), .0038, edge, segments=8)

# Short shoulder cape, open at the front so the separate neck slot remains usable.
verts, faces = [], []
cape_hem = []
cape_front = [[], []]
R = 19
for i in range(R):
    t = i/(R-1)
    # Spread over the shoulder first, then hang down rather than continuing
    # out as a stiff cone. Keep clearance around the existing body silhouette.
    spread = 1-(1-t)**1.7
    rx = .142+.097*spread
    ry = .154+.074*spread
    opening = .33+.10*t+.03*math.sin(math.pi*t)
    for j in range(N+1):
        theta = opening+(2*math.pi-2*opening)*j/N
        back = (1-math.cos(theta))/2
        z = .548-t*(.088+.044*back)-.018*t*t
        # Broad, shallow folds and a gently uneven hem read as soft cloth
        # without simulated vertices or an extra per-frame update.
        envelope = math.sin(math.pi*j/N)**.7
        fold = t**1.4*(.006*math.cos(theta*6+.3)+.0015*math.cos(theta*11-.2))*envelope
        z += .006*t*t*math.cos(theta*6+.3)*envelope
        front_corner = math.exp(-min(j/N,1-j/N)/.075)
        z += .010*t**3*front_corner
        p = ((rx+fold)*math.sin(theta), .027-(ry+fold)*math.cos(theta), z)
        verts.append(p)
        if i == R-1:
            cape_hem.append(p)
        if j == 0:
            cape_front[0].append(p)
        if j == N:
            cape_front[1].append(p)
for i in range(R-1):
    for j in range(N):
        faces.append((i*(N+1)+j, (i+1)*(N+1)+j, (i+1)*(N+1)+j+1, i*(N+1)+j+1))
surface('RedHood_ShoulderCape', verts, faces, red, .0035, mode='cape')
tube('RedHood_CapeHem', cape_hem, .0028, edge, segments=8, mode='cape')
for side in range(2):
    tube('RedHood_CapeOpening'+str(side), cape_front[side], .0030, edge, mode='cape')

# A small tied cord under the chin, kept red like the reference.
for sign in [-1, 1]:
    points = []
    for i in range(17):
        t = i/16
        points.append((sign*(.046*(1-t)), -.122-.017*t, .548-.010*math.sin(t*math.pi)))
    tube('RedHood_Drawstring'+str(sign), points, .0028, cord)
    points = []
    for i in range(33):
        a = 2*math.pi*i/32
        points.append((sign*(.003+.026*math.sin(a/2)**1.2), -.141-.004*math.sin(a), .538+.012*math.sin(a)))
    tube('RedHood_TiedLoop'+str(sign), points, .0028, edge)
    points = [(sign*(.003+.014*t), -.141-.008*math.sin(t*math.pi), .535-.036*t) for t in [i/16 for i in range(17)]]
    tube('RedHood_CordEnd'+str(sign), points, .0026, cord)

# A discreet stitched centre seam along the back.
points = [(0, cy+ry+.001, z) for z, rx, ry, cy, opening in rows if z < .973]
tube('RedHood_BackSeam', points, .0013, cord)

# Save an editable fitting scene, then export only the new skinned accessory.
for obj in character:
    if obj.name == 'Icosphere':
        obj.hide_render = True
source_dir = ROOT / 'assets/incoming/accessories'
source_dir.mkdir(exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source_dir / 'red_hood.blend'))
# Keep named fitting pieces editable in the .blend. Join export copies into
# one skinned mesh with four shared material surfaces instead of 13 draw nodes.
copies = []
for obj in made:
    clone = obj.copy()
    clone.data = obj.data.copy()
    bpy.context.collection.objects.link(clone)
    copies.append(clone)
bpy.ops.object.select_all(action='DESELECT')
for clone in copies:
    clone.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
combined = bpy.context.object
combined.name = 'RedHood_Optimized'
# Consolidate identical material slots explicitly for consistent glTF surfaces.
materials = []
slots = []
for mat in combined.data.materials:
    if mat not in materials:
        materials.append(mat)
    slots.append(materials.index(mat))
indices = [slots[p.material_index] for p in combined.data.polygons]
combined.data.materials.clear()
for mat in materials:
    combined.data.materials.append(mat)
for polygon, idx in zip(combined.data.polygons, indices):
    polygon.material_index = idx
combined.data.calc_loop_triangles()
triangles = len(combined.data.loop_triangles)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
combined.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT / 'red_hood.glb'), export_format='GLB', use_selection=True, export_animations=False, export_cameras=False, export_lights=False, export_def_bones=True)

# The cape is fitted to relaxed flippers. Use that pose as its arm bind pose,
# so idle skinning is identity and raising a wing lifts the shoulder cloth.
# Editing the inverse bind matrices preserves the tailored surface normals;
# pre-warping vertices would create shading artifacts along the weight blend.
path = OUT / 'red_hood.glb'
data = bytearray(path.read_bytes())
json_size = struct.unpack_from('<I', data, 12)[0]
doc = json.loads(data[20:20+json_size])
binary_start = 20+json_size+8
axis = Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
for gltf_skin in doc['skins']:
    accessor = doc['accessors'][gltf_skin['inverseBindMatrices']]
    view = doc['bufferViews'][accessor['bufferView']]
    start = binary_start+view.get('byteOffset',0)+accessor.get('byteOffset',0)
    for i, node_index in enumerate(gltf_skin['joints']):
        name = doc['nodes'][node_index]['name']
        if name not in ('arm_stretch_l', 'arm_stretch_r'):
            continue
        bone = rig.data.bones[name]
        hinge = bone.head_local
        angle = 1.25 if name.endswith('_l') else -1.25
        delta = Matrix.Translation(hinge) @ Quaternion((0,1,0), angle).to_matrix().to_4x4() @ Matrix.Translation(-hinge)
        values = struct.unpack_from('<16f', data, start+64*i)
        original = Matrix(tuple(tuple(values[col*4+row] for col in range(4)) for row in range(4)))
        # Preserve the exporter's bone-axis correction in the original bind.
        bind = original @ axis @ delta.inverted() @ axis.inverted()
        struct.pack_into('<16f', data, start+64*i, *[bind[row][col] for col in range(4) for row in range(4)])
path.write_bytes(data)
print('RED_HOOD_EXPORTED', 1, 'mesh', len(materials), 'materials', triangles, 'triangles', path.stat().st_size, 'bytes', flush=True)
