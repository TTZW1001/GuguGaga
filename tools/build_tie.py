"""Tailor a striped blue tie, without a neck strap, to the shipped breast mesh."""
import bpy
import math
import struct
import zlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/accessories'
SOURCE = ROOT / 'assets/incoming/accessories'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/tomori/penguin.glb'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
body = bpy.data.objects['mesh0']
body_tree = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
made = []

def breast_y(x,z):
    hit,_,_,_ = body_tree.ray_cast(Vector((x,-.5,z)),Vector((0,1,0)),1)
    if hit is None: raise RuntimeError('No breast surface under tie')
    return hit.y

def material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    rgb = [int(color[i:i+2],16)/255 for i in (0,2,4)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb,1)
    bsdf.inputs['Roughness'].default_value = roughness
    return mat

satin = material('Tie navy blue diagonal silk','294880',.58)
reverse = material('Tie dark blue reverse','20365a',.76)

# Bake a small, ordinary sRGB texture: thin diagonal stripes and a restrained
# woven variation, with no procedural shader dependency in the game.
W,H = 256,512
rows = []
for y in range(H):
    row = bytearray([0])
    for x in range(W):
        u,v = (x+.5)/W,(y+.5)/H
        phase = ((u+3*v)*4)%1
        distance = min(phase,1-phase)
        stripe = max(0,min(1,(.037-distance)/.012))
        weave = 1+.025*math.sin(math.tau*x/3)*math.sin(math.tau*y/3)
        base,light = (41,72,128),(139,167,203)
        row.extend(max(0,min(255,round((base[i]*(1-stripe)+light[i]*stripe)*weave))) for i in range(3))
    rows.append(row)
def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
texture_path = OUT/'tie_blue_stripes.png'
texture_path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b''))
image = bpy.data.images.load(str(texture_path))
image.colorspace_settings.name = 'sRGB'
image.pack()
tex = satin.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image
satin.node_tree.links.new(tex.outputs['Color'],satin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

def skin(obj):
    obj.parent = rig
    groups = {name:obj.vertex_groups.new(name=name) for name in ['neck_x','spine_01_x']}
    for v in obj.data.vertices:
        t = max(0,min(1,(v.co.z-.480)/.100))
        n = .42*t*t*(3-2*t)
        groups['neck_x'].add([v.index],n,'REPLACE')
        groups['spine_01_x'].add([v.index],1-n,'REPLACE')
    mod = obj.modifiers.new('Follow neck and breast','ARMATURE')
    mod.object = rig
    made.append(obj)

def set_uv(obj,knot=False):
    layer = obj.data.uv_layers.new(name='TieStripes')
    for loop in obj.data.loops:
        p = obj.data.vertices[loop.vertex_index].co
        u = (p.x+.04)/.08
        v = (.512-p.z)/.235
        # The knot has its own folded diagonal direction, like wrapped silk.
        layer.data[loop.index].uv = ((1-u if knot else u),v+.31 if knot else v)

# A gently domed, tapering blade follows the actual breast at every sample.
# The final rows form the familiar pointed hem rather than a rectangular slab.
U,V = 12,44
verts,faces = [],[]
for i in range(V+1):
    t = i/V
    width = .010+.026*(min(t/.86,1)**.70)
    if t>.86: width=max(.0002,.036*(1-(t-.86)/.14))
    z = .512-.235*t
    for j in range(U+1):
        u = j/U*2-1
        x = width*u
        dome = .0018*(1-u*u)
        dimple = .0012*math.exp(-(u/.22)**2)*math.exp(-((t-.08)/.10)**2)
        y = breast_y(x,z)-.009-dome+dimple
        verts.append((x,y,z))
        if i<V and j<U:
            k=i*(U+1)+j
            faces.append((k,k+1,k+U+2,k+U+1))
mesh = bpy.data.meshes.new('Tie tailored blade')
mesh.from_pydata(verts,[],faces)
mesh.update()
obj = bpy.data.objects.new('Tie_TaperedPointedBlade',mesh)
bpy.context.collection.objects.link(obj)
mesh.materials.append(satin)
mesh.materials.append(reverse)
set_uv(obj)
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active=obj
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
solid = obj.modifiers.new('Folded fabric thickness','SOLIDIFY')
solid.thickness=.0032
solid.offset=-1
solid.material_offset=1
bpy.ops.object.modifier_apply(modifier=solid.name)
bevel = obj.modifiers.new('Soft sewn edges','BEVEL')
bevel.width=.0009
bevel.segments=2
bevel.affect='EDGES'
bevel.angle_limit=math.radians(40)
bpy.ops.object.modifier_apply(modifier=bevel.name)
for p in obj.data.polygons: p.use_smooth=True
skin(obj)

# Rounded trapezoidal knot: broad at the top, pinched at the lower throat.
verts=[]
for depth in [.004,.025]:
    for x,z in [(-.019,.547),(.019,.547),(.010,.510),(-.010,.510)]:
        verts.append((x,breast_y(x,z)-depth,z))
faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
mesh=bpy.data.meshes.new('Tie folded knot')
mesh.from_pydata(verts,[],faces)
mesh.update()
obj=bpy.data.objects.new('Tie_SoftTrapezoidKnot',mesh)
bpy.context.collection.objects.link(obj)
mesh.materials.append(satin)
set_uv(obj,knot=True)
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active=obj
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
bevel=obj.modifiers.new('Rounded satin knot edges','BEVEL')
bevel.width=.003
bevel.segments=3
bpy.ops.object.modifier_apply(modifier=bevel.name)
for p in obj.data.polygons: p.use_smooth=True
normals=obj.modifiers.new('Even satin knot normals','WEIGHTED_NORMAL')
bpy.ops.object.modifier_apply(modifier=normals.name)
skin(obj)

bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'blue_tie.blend'))
copies=[]
for obj in made:
    copy=obj.copy()
    copy.data=obj.data.copy()
    bpy.context.collection.objects.link(copy)
    copies.append(copy)
bpy.ops.object.select_all(action='DESELECT')
for obj in copies: obj.select_set(True)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
combined=bpy.context.object
combined.name='BlueTie_Optimized'
materials,slots=[],[]
for mat in combined.data.materials:
    if mat not in materials: materials.append(mat)
    slots.append(materials.index(mat))
indices=[slots[p.material_index] for p in combined.data.polygons]
combined.data.materials.clear()
for mat in materials: combined.data.materials.append(mat)
for p,idx in zip(combined.data.polygons,indices): p.material_index=idx
combined.data.calc_loop_triangles()
triangles=len(combined.data.loop_triangles)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
combined.select_set(True)
bpy.context.view_layer.objects.active=rig
path=OUT/'blue_tie.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_def_bones=True)
print('TIE_EXPORTED',1,'mesh',len(materials),'materials',triangles,'triangles',path.stat().st_size,'bytes',flush=True)
