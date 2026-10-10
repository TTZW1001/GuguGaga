"""Model a soft, pleated satin bow tie fitted to the existing game character."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/accessories'
SOURCE = ROOT / 'assets/incoming/accessories'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/tomori/penguin.glb'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
made = []

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

satin = material('Bow cherry red satin','c9324b',.50)
inner = material('Bow shaded reverse and band','9d253b',.65)
knot = material('Bow folded centre wrap','da4358',.46)

def skin(obj):
    obj.parent = rig
    groups = {name:obj.vertex_groups.new(name=name) for name in ['neck_x','spine_01_x']}
    for v in obj.data.vertices:
        t = max(0,min(1,(v.co.z-.490)/.090))
        neck_weight = .45*t*t*(3-2*t)
        groups['neck_x'].add([v.index],neck_weight,'REPLACE')
        groups['spine_01_x'].add([v.index],1-neck_weight,'REPLACE')
    mod = obj.modifiers.new('Follow neck and breast','ARMATURE')
    mod.object = rig
    made.append(obj)

def surface(name, verts, faces, materials, indices=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    for mat in materials: mesh.materials.append(mat)
    for i,p in enumerate(mesh.polygons):
        p.use_smooth = True
        if indices: p.material_index=indices[i]
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    skin(obj)
    return obj

# The lobes widen from a pinched throat into rounded fabric loops. Their front
# surfaces carry two shallow radial creases, rather than looking like spheres.
L,K = 28,32
for side in [-1,1]:
    verts,faces,indices = [],[],[]
    for i in range(L+1):
        u = i/L
        end = math.sqrt(max(.0001,1-(max(0,(u-.86)/.14))**2))
        spread = u*u*(3-2*u)
        half_height = (.010+.025*spread)*end
        depth = (.007+.008*math.sin(math.pi*u*.85))*end
        for j in range(K):
            a = math.tau*j/K
            cross = math.cos(a)
            front = max(0,math.sin(a))
            crease = math.exp(-((cross-.42)/.15)**2)+math.exp(-((cross+.42)/.15)**2)
            x = side*(.010+.092*u)
            z = .526+.006*u+half_height*cross
            y = -.105+.029*u*u-depth*math.sin(a)+.0037*crease*math.sin(math.pi*u)**.7*front**3
            verts.append((x,y,z))
    for i in range(L):
        for j in range(K):
            faces.append((i*K+j,i*K+(j+1)%K,(i+1)*K+(j+1)%K,(i+1)*K+j))
            indices.append(0 if math.sin(math.tau*(j+.5)/K)>0 else 1)
    faces += [tuple(reversed(range(K))),tuple(L*K+j for j in range(K))]
    indices += [1,0]
    surface('Bow_PleatedLoop_'+str(side),verts,faces,[satin,inner],indices)

# A bevelled fabric wrap gives the centre a clear knot, with soft corners.
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-.114,.529))
obj = bpy.context.object
obj.name = 'Bow_CentreWrap'
obj.scale = (.029,.030,.041)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bevel = obj.modifiers.new('Soft folded knot corners','BEVEL')
bevel.width = .007
bevel.segments = 4
bpy.ops.object.modifier_apply(modifier=bevel.name)
obj.data.materials.append(knot)
for p in obj.data.polygons: p.use_smooth=True
normals = obj.modifiers.new('Even satin normals','WEIGHTED_NORMAL')
bpy.ops.object.modifier_apply(modifier=normals.name)
# Vertex positions for all pieces must be in the character's source space.
bpy.ops.object.transform_apply(location=True,rotation=False,scale=False)
skin(obj)

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'red_bow.blend'))
copies = []
for obj in made:
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.collection.objects.link(copy)
    copies.append(copy)
bpy.ops.object.select_all(action='DESELECT')
for obj in copies: obj.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
combined = bpy.context.object
combined.name = 'RedBow_Optimized'
materials,slots = [],[]
for mat in combined.data.materials:
    if mat not in materials: materials.append(mat)
    slots.append(materials.index(mat))
indices = [slots[p.material_index] for p in combined.data.polygons]
combined.data.materials.clear()
for mat in materials: combined.data.materials.append(mat)
for p,idx in zip(combined.data.polygons,indices): p.material_index=idx
combined.data.calc_loop_triangles()
triangles = len(combined.data.loop_triangles)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
combined.select_set(True)
bpy.context.view_layer.objects.active = rig
path = OUT/'red_bow.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_def_bones=True)
print('BOW_EXPORTED',1,'mesh',len(materials),'materials',triangles,'triangles',path.stat().st_size,'bytes',flush=True)
