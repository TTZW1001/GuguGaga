"""Tailor a broad red neck wrap and rounded side tail to the game mesh."""
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

def material(name, color):
    mat = bpy.data.materials.new(name)
    rgb = [int(color[i:i+2],16)/255 for i in (0,2,4)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb,1)
    bsdf.inputs['Roughness'].default_value = .95
    return mat

red = material('Scarf soft scarlet wool','d4383e')
hem = material('Scarf fine red hem','bc2e38')
lining = material('Scarf inner weave','b72c35')

def surface(name, verts, faces, mat, uvs=None, thickness=0):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = True
    if uvs:
        layer = mesh.uv_layers.new(name='FabricUV')
        for loop in mesh.loops:
            layer.data[loop.index].uv = uvs[loop.vertex_index]
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    if thickness:
        mesh.materials.append(lining)
        mod = obj.modifiers.new('Soft fabric thickness','SOLIDIFY')
        mod.thickness = thickness
        mod.offset = -1
        mod.material_offset = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bevel = obj.modifiers.new('Rounded cloth edges','BEVEL')
        bevel.width = .0014
        bevel.segments = 2
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.parent = rig
    groups = {name:obj.vertex_groups.new(name=name) for name in ['neck_x','spine_01_x']}
    for v in obj.data.vertices:
        # The upper wrap turns softly with the neck; the tail stays on the chest.
        t = max(0,min(1,(v.co.z-.485)/.130))
        neck_weight = .70*t*t*(3-2*t)
        groups['neck_x'].add([v.index],neck_weight,'REPLACE')
        groups['spine_01_x'].add([v.index],1-neck_weight,'REPLACE')
    mod = obj.modifiers.new('Follow neck and chest','ARMATURE')
    mod.object = rig
    made.append(obj)
    return obj

def tube(name, points, radius, mat, closed=False):
    verts,faces = [],[]
    K = 6
    for i,p in enumerate(points):
        p = Vector(p)
        previous = Vector(points[(i-1)%len(points)] if closed or i else points[i])
        following = Vector(points[(i+1)%len(points)] if closed or i<len(points)-1 else points[i])
        tangent = (following-previous).normalized()
        axis = tangent.cross(Vector((0,1,0)))
        if axis.length < .01: axis = tangent.cross(Vector((1,0,0)))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        for j in range(K):
            a = math.tau*j/K
            verts.append(p+radius*(axis*math.cos(a)+other*math.sin(a)))
    for i in range(len(points) if closed else len(points)-1):
        k = (i+1)%len(points)
        for j in range(K):
            faces.append((i*K+j,i*K+(j+1)%K,k*K+(j+1)%K,k*K+j))
    if not closed:
        faces += [tuple(reversed(range(K))),tuple((len(points)-1)*K+j for j in range(K))]
    surface(name,verts,faces,mat)

# A rounded rectangular fabric section, not a torus. The wrap spreads gently
# onto the shoulders; its front dips below the chin and clears the side hair.
N = 80
profile = [(0,0),(.035,.003),(.12,.005),(.35,.0065),(.65,.0065),(.88,.005),(.965,.003),(1,0),(1,-.002),(.965,-.004),(.88,-.005),(.65,-.005),(.35,-.005),(.12,-.005),(.035,-.004),(0,-.002)]
def wrap_point(a,t,offset=0):
    spread = 1-(1-t)**1.8
    rx = .178+.016*spread
    ry = .173+.013*spread
    dip = .018*(1+math.cos(a))/2
    z = .613-.116*t-dip+.0020*math.cos(3*a+.5)*t*t
    fold = .0023*math.cos(5*a+.4)*math.sin(math.pi*t)**2
    return Vector(((rx+offset+fold)*math.sin(a),.031-(ry+offset+fold)*math.cos(a),z))

verts,faces,uvs = [],[],[]
for t,offset in profile:
    for j in range(N+1):
        a = math.tau*j/N
        verts.append(wrap_point(a,t,offset))
        uvs.append((j/N*12,t*2))
for i in range(len(profile)):
    k = (i+1)%len(profile)
    for j in range(N):
        faces.append((i*(N+1)+j,i*(N+1)+j+1,k*(N+1)+j+1,k*(N+1)+j))
surface('Scarf_RoundedWrap',verts,faces,red,uvs)
for t in [.055,.945]:
    tube('Scarf_WrapHem_'+str(t),[wrap_point(math.tau*j/N,t,.0039) for j in range(N)],.00085,hem,closed=True)

# Longer tail tucked under the wrap at the viewer's left. It drapes against the
# breast with a soft transverse fold and rounded corners, without fringes.
U,V = 12,22
verts,faces,uvs = [],[],[]
for i in range(V+1):
    t = i/V
    for j in range(U+1):
        u = j/U*2-1
        corner = max(0,(abs(u)-.70)/.30)**2
        x = -.108-.009*math.sin(math.pi*t*.8)+u*(.045-.002*t)
        z = .492-.245*t+.008*corner*t**8
        y = -.107-.105*math.sin(math.pi*t/2)-.003*(1-u*u)*math.sin(math.pi*t)-.0018*math.cos(u*math.pi*2)*math.sin(math.pi*t)
        verts.append((x,y,z))
        uvs.append((j/U*1.5,t*4.8))
        if i<V and j<U:
            k=i*(U+1)+j
            faces.append((k,k+1,k+U+2,k+U+1))
surface('Scarf_ShortSideTail',verts,faces,red,uvs,thickness=.005)
for side in [0,U]:
    points = [Vector(verts[i*(U+1)+side])+Vector((0,-.001,0)) for i in range(2,V+1)]
    tube('Scarf_TailSideHem_'+str(side),points,.0008,hem)
tube('Scarf_TailBottomHem',[Vector(p)+Vector((0,-.001,0)) for p in verts[-(U+1):]],.0008,hem)

# A tiny packed normal texture adds a restrained knit weave in close views.
# Ordinary glTF texture sampling keeps it compatible with low-end rendering.
texture = bpy.data.images.new('Scarf knit normal',width=128,height=128,alpha=False)
texture.colorspace_settings.name = 'Non-Color'
pixels = []
for y in range(128):
    for x in range(128):
        a = math.tau*(x/8+(y%16)/16)
        b = math.tau*y/8
        pixels.extend((.5+.075*math.sin(a),.5+.055*math.sin(b),.99,1))
texture.pixels.foreach_set(pixels)
texture.filepath_raw = str(OUT/'scarf_knit_normal.png')
texture.file_format = 'PNG'
texture.save()
texture.pack()
for mat in [red,lining]:
    nodes = mat.node_tree.nodes
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = texture
    normal = nodes.new('ShaderNodeNormalMap')
    normal.inputs['Strength'].default_value = .30
    mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
    mat.node_tree.links.new(normal.outputs['Normal'],nodes.get('Principled BSDF').inputs['Normal'])

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'red_scarf.blend'))
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
combined.name = 'RedScarf_Optimized'
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
path = OUT/'red_scarf.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_def_bones=True)
print('SCARF_EXPORTED',1,'mesh',len(materials),'materials',triangles,'triangles',path.stat().st_size,'bytes',flush=True)
