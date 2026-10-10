"""Build a small, tilted mortarboard fitted to the shipped penguin's scalp.
Run with Blender --background --python tools/build_graduation_cap.py.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/accessories'
SOURCE = ROOT / 'assets/incoming/accessories'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/tomori/penguin.glb'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
head = bpy.data.objects['Tomori_mesh']
# Hair consists of separate open locks. Use their smooth outer envelope for
# fitting; rays into gaps between locks would produce a jagged cap opening.
hair_envelope = bmesh.new()
for vertex in head.data.vertices:
    point = head.matrix_world @ vertex.co
    if point.z > .72:
        hair_envelope.verts.new(point)
bmesh.ops.convex_hull(hair_envelope,input=list(hair_envelope.verts))
scalp = BVHTree.FromBMesh(hair_envelope)
hair_envelope.free()
made = []

def material(name, color, roughness=.88):
    mat = bpy.data.materials.new(name)
    rgb = [int(color[i:i+2], 16)/255 for i in (0,2,4)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb,1)
    shader.inputs['Roughness'].default_value = roughness
    return mat

cloth = material('Charcoal graduation cloth', '282b38')
binding = material('Satin edge binding', '3d4152', .76)
gold = material('Warm gold tassel thread', 'dfb34f', .60)
gold.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value = .08

# The cap leans to the character's left, with its board pitched towards the
# camera. Dimensions use the original GLB's units, before the game scale of 2.5.
rotation = Quaternion((0,1,0), math.radians(32)).to_matrix().to_4x4() @ Quaternion((1,0,0), math.radians(8)).to_matrix().to_4x4() @ Quaternion((0,0,1), math.radians(30)).to_matrix().to_4x4()
frame = Matrix.Translation((.065,.010,.878)) @ rotation

def surface(name, verts, faces, mat, local=True, thickness=0):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([frame @ Vector(p) if local else p for p in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = True
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    if thickness:
        mod = obj.modifiers.new('Cloth thickness', 'SOLIDIFY')
        mod.thickness = thickness
        mod.offset = -1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.parent = rig
    group = obj.vertex_groups.new(name='head_x')
    group.add(list(range(len(mesh.vertices))), 1, 'REPLACE')
    mod = obj.modifiers.new('Follow head', 'ARMATURE')
    mod.object = rig
    made.append(obj)
    return obj

def tube(name, points, radius, mat, local=True, segments=6, closed=False):
    vertices, faces = [], []
    for i,p in enumerate(points):
        p = Vector(p)
        before = Vector(points[(i-1) % len(points)] if closed or i else points[i])
        after = Vector(points[(i+1) % len(points)] if closed or i<len(points)-1 else points[i])
        tangent = (after-before).normalized()
        axis = tangent.cross(Vector((0,1,0)))
        if axis.length < .01:
            axis = tangent.cross(Vector((1,0,0)))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        for j in range(segments):
            a = math.tau*j/segments
            vertices.append(p+radius*(axis*math.cos(a)+other*math.sin(a)))
    for i in range(len(points) if closed else len(points)-1):
        k = (i+1) % len(points)
        for j in range(segments):
            faces.append((i*segments+j,i*segments+(j+1)%segments,k*segments+(j+1)%segments,k*segments+j))
    if not closed:
        faces += [tuple(reversed(range(segments))),tuple((len(points)-1)*segments+j for j in range(segments))]
    return surface(name,vertices,faces,mat,local=local)

# The opening follows the top of the actual scalp, not a tilted planar ellipse.
# This lets the small cap sit on one side without a gap under its high edge.
def scalp_height(x, y):
    heights = []
    for dx,dy in [(0,0),(-.0006,0),(.0006,0),(0,-.0006),(0,.0006)]:
        hit, normal, face_id, distance = scalp.ray_cast(Vector((x+dx,y+dy,1.1)),Vector((0,0,-1)),.5)
        if hit is not None:
            heights.append(hit.z)
    return max(heights) if heights else None

N, R = 48, 9
verts, faces, rim = [], [], []
rim_gaps = []
footprint = []
for j in range(N):
    a = math.tau*j/N
    direction = Vector((math.sin(a),-math.cos(a),0))
    radius = 1/math.sqrt((direction.x/.092)**2+(direction.y/.100)**2)
    for attempt in range(20):
        p = frame @ Vector((direction.x*radius,direction.y*radius,0))
        height = scalp_height(p.x,p.y)
        if height is not None and height >= .80:
            p.z = height+.0023
            footprint.append(p)
            break
        radius *= .95
    else:
        raise RuntimeError('No scalp contact for cap opening point '+str(j))
for i in range(R):
    t = i/(R-1)
    for j in range(N):
        a = math.tau*j/N
        direction = Vector((math.sin(a),-math.cos(a),0))
        bottom = footprint[j]
        top = frame @ Vector((direction.x*.080,direction.y*.084,.059))
        p = bottom.lerp(top,t)
        p += frame.to_3x3() @ direction*(.0007*math.cos(a*10+.2)*math.sin(math.pi*t))
        height = scalp_height(p.x,p.y)
        if height is not None:
            p.z = max(p.z,height+.0023)
        verts.append(p)
        if i == 0:
            rim.append(p)
            rim_gaps.append(p.z-(bottom.z-.0023))
for i in range(R-1):
    for j in range(N):
        faces.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
faces.append(tuple((R-1)*N+j for j in range(N)))
surface('Graduate_SoftCrown',verts,faces,cloth,local=False,thickness=.0020)
tube('Graduate_OpeningHem',rim,.0016,binding,local=False,closed=True,segments=8)
print('CAP_OPENING_FIT',len(rim),'scalp contacts; maximum clearance',round(max(rim_gaps),5),flush=True)

# Small square board: rounded plan corners, a shallow padded top and bevelled
# perimeter. The square is retained as the familiar mortarboard silhouette.
half, corner = .128,.008
outline = []
for cx,cy,start in [(half-corner,half-corner,0),(-half+corner,half-corner,90),(-half+corner,-half+corner,180),(half-corner,-half+corner,270)]:
    for j in range(6):
        a = math.radians(start+90*j/5)
        outline.append(Vector((cx+corner*math.cos(a),cy+corner*math.sin(a),0)))
M = len(outline)
verts,faces = [(0,0,.064)],[]
for f in [.25,.6,.85,.99]:
    for p in outline:
        x,y = p.x*f,p.y*f
        z = .061+.003*(1-f*f)-.0012*((x/half)**2+(y/half)**2)
        verts.append((x,y,z))
for j in range(M):
    faces.append((0,1+j,1+(j+1)%M))
for ring in range(3):
    for j in range(M):
        faces.append((1+ring*M+j,1+ring*M+(j+1)%M,1+(ring+1)*M+(j+1)%M,1+(ring+1)*M+j))
for p in outline:
    verts.append((p.x,p.y,.0575-.0012*((p.x/half)**2+(p.y/half)**2)))
for p in outline:
    verts.append((p.x*.99,p.y*.99,.0550-.0012*((p.x/half)**2+(p.y/half)**2)))
for ring in [3,4]:
    for j in range(M):
        faces.append((1+ring*M+j,1+ring*M+(j+1)%M,1+(ring+1)*M+(j+1)%M,1+(ring+1)*M+j))
faces.append(tuple(reversed([1+5*M+j for j in range(M)])))
surface('Graduate_RoundedBoard',verts,faces,cloth)
edge_points = [(p.x,p.y,.0575-.0012*((p.x/half)**2+(p.y/half)**2)) for p in outline]
tube('Graduate_BoardBinding',edge_points,.0010,binding,closed=True)

# A discreet cloth-covered button, then a gold cord across the board.
button = [(math.cos(a)*.007,math.sin(a)*.007,.0655) for a in [math.tau*j/24 for j in range(24)]]
tube('Graduate_Button',button,.0020,binding,closed=True)
board_path = []
for j in range(17):
    t = j/16
    # Lead to the outer right corner so the tassel hangs beside the hair.
    board_path.append((.125*t,-.125*t+.003*math.sin(math.pi*t),.067-.005*t))
tube('Graduate_TopCord',board_path,.0015,gold)

# The hanging section is modelled vertically in the standing pose, rather
# than leaning with the board. It remains a lightweight head-bound accessory.
anchor = frame @ Vector(board_path[-1])
hanger_end = Vector((anchor.x+.005,anchor.y-.004,anchor.z-.075))
hanger = []
for j in range(21):
    t = j/20
    curve = t*t*(3-2*t)
    p = anchor.lerp(hanger_end,curve)
    p.z = anchor.z-.075*t
    hanger.append(p)
tube('Graduate_HangingCord',hanger,.0017,gold,local=False,segments=8)
for k in range(4):
    points = [(hanger_end.x+.005*math.cos(math.tau*j/16),hanger_end.y+.005*math.sin(math.tau*j/16),hanger_end.z-.0015*k) for j in range(16)]
    tube('Graduate_TasselWrap'+str(k),points,.0014,gold,local=False,closed=True)
for strand in range(12):
    a = math.tau*strand/12
    points = []
    for j in range(9):
        t = j/8
        radius = .003+.0048*math.sin(t*math.pi*.60)
        p = hanger_end+Vector((radius*math.cos(a)+.002*t*t,radius*math.sin(a)-.0015*t*t,-.006-(.064+.002*math.cos(a*3))*t))
        points.append(p)
    tube('Graduate_TasselStrand'+str(strand),points,.0012,gold,local=False,segments=5)

# Editable fitting scene with named pieces, followed by a single-mesh export.
for obj in bpy.context.scene.objects:
    if obj.name == 'Icosphere':
        obj.hide_render = True
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'graduation_cap.blend'))
copies = []
for obj in made:
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.collection.objects.link(copy)
    copies.append(copy)
bpy.ops.object.select_all(action='DESELECT')
for obj in copies:
    obj.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
combined = bpy.context.object
combined.name = 'GraduationCap_Optimized'
materials,slots = [],[]
for mat in combined.data.materials:
    if mat not in materials:
        materials.append(mat)
    slots.append(materials.index(mat))
indices = [slots[p.material_index] for p in combined.data.polygons]
combined.data.materials.clear()
for mat in materials:
    combined.data.materials.append(mat)
for p,idx in zip(combined.data.polygons,indices):
    p.material_index = idx
combined.data.calc_loop_triangles()
triangle_count = len(combined.data.loop_triangles)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
combined.select_set(True)
bpy.context.view_layer.objects.active = rig
path = OUT / 'graduation_cap.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_def_bones=True)
print('GRADUATION_CAP_EXPORTED',1,'mesh',len(materials),'materials',triangle_count,'triangles',path.stat().st_size,'bytes',flush=True)
