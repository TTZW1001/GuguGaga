"""Model a miniature, hollow gold crown against the shipped character's hair.
Run with Blender --background --python tools/build_crown.py.
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
envelope = bmesh.new()
for vertex in head.data.vertices:
    p = head.matrix_world @ vertex.co
    if p.z > .72:
        envelope.verts.new(p)
bmesh.ops.convex_hull(envelope, input=list(envelope.verts))
scalp = BVHTree.FromBMesh(envelope)
envelope.free()
frame = Matrix.Translation((.028,.012,.913)) @ Quaternion((0,1,0),math.radians(10)).to_matrix().to_4x4() @ Quaternion((1,0,0),math.radians(4)).to_matrix().to_4x4()
made = []

def material(name, hex_color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    rgb = [int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb,1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    return mat

gold = material('Crown warm gold','dba83d',.25,.34)
trim = material('Crown polished gold edging','f4cb69',.22,.28)

def surface(name, verts, faces, mat, local=True, thickness=0):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([frame @ Vector(p) if local else p for p in verts],[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    if thickness:
        mod = obj.modifiers.new('Gold sheet thickness','SOLIDIFY')
        mod.thickness = thickness
        mod.offset = -1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.parent = rig
    group = obj.vertex_groups.new(name='head_x')
    group.add(list(range(len(mesh.vertices))),1,'REPLACE')
    mod = obj.modifiers.new('Follow head','ARMATURE')
    mod.object = rig
    made.append(obj)
    return obj

def tube(name, points, radius, mat, local=True, segments=6):
    verts,faces = [],[]
    for i,p in enumerate(points):
        p = Vector(p)
        tangent = (Vector(points[(i+1)%len(points)])-Vector(points[(i-1)%len(points)])).normalized()
        axis = tangent.cross(Vector((0,0,1))).normalized()
        other = tangent.cross(axis).normalized()
        for j in range(segments):
            a = math.tau*j/segments
            verts.append(p+radius*(axis*math.cos(a)+other*math.sin(a)))
    for i in range(len(points)):
        k = (i+1)%len(points)
        for j in range(segments):
            faces.append((i*segments+j,i*segments+(j+1)%segments,k*segments+(j+1)%segments,k*segments+j))
    return surface(name,verts,faces,mat,local=local)

def bead(name, center, radius, mat, rings=6, segments=10):
    verts,faces = [],[]
    for i in range(rings+1):
        phi = math.pi*i/rings
        for j in range(segments):
            a = math.tau*j/segments
            verts.append(Vector(center)+radius*Vector((math.sin(phi)*math.cos(a),math.sin(phi)*math.sin(a),math.cos(phi))))
    for i in range(rings):
        for j in range(segments):
            faces.append((i*segments+j,i*segments+(j+1)%segments,(i+1)*segments+(j+1)%segments,(i+1)*segments+j))
    surface(name,verts,faces,mat)

N = 96
base_radius = .052
bottom = []
for j in range(N):
    a = math.tau*j/N
    p = frame @ Vector((base_radius*math.sin(a),-base_radius*math.cos(a),0))
    hit,_,_,_ = scalp.ray_cast(Vector((p.x,p.y,1.1)),Vector((0,0,-1)),.4)
    if hit is None:
        raise RuntimeError('Crown opening is outside scalp')
    p.z = hit.z+.0015
    bottom.append(p)

# Open lower ring: a fitted bottom, softly rounded upper lip, no solid lid.
verts,faces = [],[]
for i in range(3):
    t = i/2
    for j in range(N):
        a = math.tau*j/N
        top = frame @ Vector((.053*math.sin(a),-.053*math.cos(a),.023))
        p = bottom[j].lerp(top,t)
        p += frame.to_3x3() @ Vector((math.sin(a),-math.cos(a),0)) * (.0006*math.sin(math.pi*t))
        verts.append(p)
for i in range(2):
    for j in range(N):
        faces.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
surface('Crown_FittedBand',verts,faces,gold,local=False,thickness=.0022)
tube('Crown_LowerRolledRim',bottom[::2],.0021,trim,local=False,segments=8)

# Eight tapering points rise from deep, curved valleys. Alternate their height
# slightly so the rear tips do not line up behind the front ones in the game.
def peak(a):
    shape = ((1+math.cos(8*a))/2)**2
    return shape, .028+shape*(.044+.007*math.cos(4*a))

verts,faces = [],[]
for i in range(4):
    t = i/3
    for j in range(N):
        a = math.tau*j/N
        shape,height = peak(a)
        radius = .053+t*(.002+.012*shape)
        z = .022+(height-.022)*t
        verts.append((radius*math.sin(a),-radius*math.cos(a),z))
for i in range(3):
    for j in range(N):
        faces.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
surface('Crown_CurvedPoints',verts,faces,gold,thickness=.0018)
tube('Crown_UpperBandRim',[(.053*math.sin(math.tau*j/N),-.053*math.cos(math.tau*j/N),.023) for j in range(0,N,2)],.0016,trim)
for i in range(8):
    a = math.tau*i/8
    _,z = peak(a)
    bead('Crown_TipPearl_'+str(i),(.067*math.sin(a),-.067*math.cos(a),z+.001),.0055,trim)
for i in range(16):
    a = math.tau*(i+.5)/16
    bead('Crown_BandStud_'+str(i),(.054*math.sin(a),-.054*math.cos(a),.0135),.0019,trim,rings=4,segments=8)

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'small_crown.blend'))
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
combined.name = 'SmallCrown_Optimized'
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
triangles = len(combined.data.loop_triangles)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
combined.select_set(True)
bpy.context.view_layer.objects.active = rig
path = OUT / 'small_crown.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_def_bones=True)
print('CROWN_EXPORTED',1,'mesh',len(materials),'materials',triangles,'triangles',path.stat().st_size,'bytes',flush=True)
