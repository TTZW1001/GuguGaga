"""Tailor the elegant fedora, sunglasses, tie and sleeved coat to the live model.
Run with Blender --background --python tools/build_elegant_suit.py.
"""
import bpy
import bmesh
import math
import json
import struct
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
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
body_tree = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
hair_envelope = bmesh.new()
for v in bpy.data.objects['Tomori_mesh'].data.vertices:
    p = bpy.data.objects['Tomori_mesh'].matrix_world @ v.co
    if p.z>.72: hair_envelope.verts.new(p)
bmesh.ops.convex_hull(hair_envelope,input=list(hair_envelope.verts))
scalp = BVHTree.FromBMesh(hair_envelope)
hair_envelope.free()
torso_envelope = bmesh.new()
arm_names = set()
for side in ['l','r']:
    arm = rig.data.bones['arm_stretch_'+side]
    arm_names.update([arm.name]+[bone.name for bone in arm.children_recursive])
arm_groups = {group.index for group in body.vertex_groups if group.name in arm_names}
for v in body.data.vertices:
    p = body.matrix_world @ v.co
    arm_weight = sum(group.weight for group in v.groups if group.group in arm_groups)
    if abs(p.x)<.24 and .075<p.z<.615 and arm_weight<.2:
        torso_envelope.verts.new(p)
bmesh.ops.convex_hull(torso_envelope,input=list(torso_envelope.verts))
torso_shape = BVHTree.FromBMesh(torso_envelope)
torso_envelope.free()
made = []

def coat_point(point):
    p = Vector(point)
    centre = Vector((0,.026,p.z))
    direction = (p-centre).normalized()
    hit,_,_,_ = torso_shape.ray_cast(centre+direction*.6,-direction,1)
    if hit is not None:
        distance = (hit-centre).length+.017
        if (p-centre).length<distance: p = centre+direction*distance
    return p

def material(name, color, roughness, metallic=0):
    mat = bpy.data.materials.new(name)
    rgb = [int(color[i:i+2],16)/255 for i in (0,2,4)]
    linear = [v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    mat.diffuse_color = (*linear,1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear,1)
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Metallic'].default_value = metallic
    return mat

cloth = material('Soft black wool','191c22',.83)
satin = material('Charcoal satin ribbon and lapels','30343e',.46)
frame_mat = material('Polished black acetate','0c1015',.23)
lens_mat = material('Opaque smoke lenses','18232d',.19,.12)
lining = material('Coat dark lining','101319',.88)

def skin(obj, mode):
    obj.parent = rig
    groups = {name: obj.vertex_groups.new(name=name) for name in ['head_x','neck_x','spine_01_x','arm_stretch_l','arm_stretch_r','forearm_stretch_l','forearm_stretch_r']}
    for v in obj.data.vertices:
        if mode == 'head':
            weights = {'head_x':1}
        else:
            n = max(0,min(1,(v.co.z-.46)/.13))*.58
            a = 0
            weights = {'neck_x':n*(1-a),'spine_01_x':(1-n)*(1-a), 'arm_stretch_l' if v.co.x>0 else 'arm_stretch_r':a}
        for name,weight in weights.items():
            if weight>.00001: groups[name].add([v.index],weight,'REPLACE')
    mod = obj.modifiers.new('Existing penguin bones','ARMATURE')
    mod.object = rig
    made.append(obj)

def surface(name, vertices, faces, mat, mode='head', thickness=0, bevel=0):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    if thickness:
        mesh.materials.append(lining)
        mod = obj.modifiers.new('Tailored thickness','SOLIDIFY')
        mod.thickness = thickness
        mod.offset = -1
        mod.material_offset = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if bevel:
        mod = obj.modifiers.new('Soft edges','BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for polygon in mesh.polygons: polygon.use_smooth = True
    skin(obj,mode)
    return obj

def tube(name, points, radius, mat, mode='head', closed=False, segments=6):
    vertices,faces = [],[]
    for i,p in enumerate(points):
        p = Vector(p)
        before = Vector(points[(i-1)%len(points)] if closed or i else points[i])
        after = Vector(points[(i+1)%len(points)] if closed or i<len(points)-1 else points[i])
        tangent = (after-before).normalized()
        axis = tangent.cross(Vector((0,1,0)))
        if axis.length<.01: axis = tangent.cross(Vector((1,0,0)))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        for j in range(segments):
            a = math.tau*j/segments
            vertices.append(p+radius*(axis*math.cos(a)+other*math.sin(a)))
    for i in range(len(points) if closed else len(points)-1):
        nxt = (i+1)%len(points)
        for j in range(segments):
            faces.append((i*segments+j,i*segments+(j+1)%segments,nxt*segments+(j+1)%segments,nxt*segments+j))
    if not closed:
        faces += [tuple(reversed(range(segments))),tuple((len(points)-1)*segments+j for j in range(segments))]
    return surface(name,vertices,faces,mat,mode)

# Fedora: a shallow curled brim and a pinched, creased crown rather than a
# cylinder. A little lean keeps the silhouette playful on the rounded head.
hat_frame = Matrix.Translation((.005,.024,.835)) @ Quaternion((0,1,0),math.radians(-7)).to_matrix().to_4x4()
N = 64
def hat_point(rx,ry,z,a,fit=False):
    p = hat_frame @ Vector((rx*math.sin(a),-ry*math.cos(a),z))
    if fit:
        # Fit sideways around the hair at this height. Raising the brim above
        # the hair would make the hat look perched on top of the head.
        centre = Vector((.005,.024,p.z))
        direction = Vector((p.x-centre.x,p.y-centre.y,0)).normalized()
        for attempt in range(90):
            hit,_,_,_ = scalp.ray_cast(Vector((p.x,p.y,1.1)),Vector((0,0,-1)),.5)
            if hit is None or hit.z+.005<=p.z: break
            p += direction*.0008
    return p

vertices,faces = [],[]
for i in range(7):
    t = i/6
    for j in range(N):
        a = math.tau*j/N
        z = .003+.010*t*t*math.sin(a)**2-.009*t*t*max(0,math.cos(a))
        vertices.append(hat_point(.173+.063*t,.188+.048*t,z,a,fit=True))
        if i<6:
            k = i*N+j
            faces.append((k,i*N+(j+1)%N,(i+1)*N+(j+1)%N,k+N))
surface('Fedora_curled_brim',vertices,faces,cloth,thickness=.004)
brim_edge = [vertices[6*N+j]+Vector((0,0,.0005)) for j in range(N)]
tube('Fedora_bound_brim',brim_edge,.0017,satin,closed=True)

vertices,faces = [],[]
sections = [(0,.177,.192),(.024,.172,.187),(.086,.148,.159),(.135,.128,.138),(.150,.117,.127)]
for i,(z,rx,ry) in enumerate(sections):
    for j in range(N):
        a = math.tau*j/N
        # Pinch on both front corners, below the central crown crease.
        pinch = .011*math.exp(-((abs(math.sin(a))-.55)/.24)**2)*max(0,math.cos(a))*(i/4)
        crest = -.011*abs(math.cos(a))*(i/4)**3
        vertices.append(hat_point(rx-pinch,ry,z+crest,a,fit=True))
        if i<4:
            k = i*N+j
            faces.append((k,i*N+(j+1)%N,(i+1)*N+(j+1)%N,k+N))
# Nested top loops form a soft central crease, with no cone-shaped fan apex.
for scale,z in [(.73,.143),(.38,.127),(.08,.121)]:
    start = len(vertices)
    for j in range(N):
        a = math.tau*j/N
        vertices.append(hat_point(.117*scale,.127*scale,z-.006*abs(math.cos(a)),a))
        faces.append((start-N+j,start-N+(j+1)%N,start+(j+1)%N,start+j))
faces.append(tuple(range(len(vertices)-N,len(vertices))))
surface('Fedora_pinched_crown',vertices,faces,cloth,thickness=.003)
vertices,faces = [],[]
for i,z in enumerate([.010,.035]):
    for j in range(N):
        a = math.tau*j/N
        point = hat_point(.176-i*.008,.191-i*.008,z,a,fit=True)
        point += Vector((point.x-.005,point.y-.024,0)).normalized()*.0035
        vertices.append(point)
        if i==0: faces.append((j,(j+1)%N,N+(j+1)%N,N+j))
surface('Fedora_satin_band',vertices,faces,satin,thickness=.0012)

# Generous rounded rectangular glasses, curved around the actual face.
# Opaque smoke lenses avoid transparency sorting and expensive refraction.
def glasses_point(x,z,depth=0):
    return (x,-.169+.025*(abs(x)/.14)**1.7-depth,z)
for sign in [-1,1]:
    outline = []
    for j in range(64):
        a = math.tau*j/64
        u = math.copysign(abs(math.cos(a))**.48,math.cos(a))
        v = math.copysign(abs(math.sin(a))**.48,math.sin(a))
        outline.append(glasses_point(sign*.067+.058*u,.687+.047*v))
    tube('Sunglasses_rounded_frame_'+str(sign),outline,.0052,frame_mat,closed=True,segments=8)
    vertices,faces = [glasses_point(sign*.067,.687,.001)],[]
    for i in range(1,5):
        scale = i/4
        for j in range(64):
            a = math.tau*j/64
            u = math.copysign(abs(math.cos(a))**.48,math.cos(a))
            v = math.copysign(abs(math.sin(a))**.48,math.sin(a))
            vertices.append(glasses_point(sign*.067+.053*scale*u,.687+.042*scale*v,.002*(1-scale*scale)))
            k = 1+(i-1)*64+j
            if i==1: faces.append((0,k,1+(j+1)%64))
            else: faces.append((k-64,1+(i-2)*64+(j+1)%64,1+(i-1)*64+(j+1)%64,k))
    surface('Sunglasses_smoke_lens_'+str(sign),vertices,faces,lens_mat,thickness=.0015)
    tube('Sunglasses_temple_'+str(sign),[(sign*.125,-.148,.708),(sign*.133,-.106,.708),(sign*.134,-.062,.702),(sign*.132,-.020,.693),(sign*.126,.002,.680)],.0032,frame_mat,segments=8)
tube('Sunglasses_bridge',[glasses_point(-.014,.701),glasses_point(0,.705,.004),glasses_point(.014,.701)],.0046,frame_mat,segments=8)

# A tailored open coat, with actual armholes connected to separate sleeves.
# Fit the body independently from the arms, so lifting a sleeve does not pull
# the entire side of the coat outwards like a cape.
vertices,faces,hem,edges = [],[],[],[[],[]]
R,C = 36,72
sections = [(0,.158,.174),(.13,.195,.193),(.38,.231,.224),(.65,.241,.226),(1,.219,.196)]
for i in range(R+1):
    t = i/R
    for p in range(len(sections)-1):
        if sections[p][0]<=t<=sections[p+1][0]:
            ta,xa,ya = sections[p]
            tb,xb,yb = sections[p+1]
            s = (t-ta)/(tb-ta)
            # Cubic Hermite interpolation smooths the shoulder transition.
            previous = sections[max(0,p-1)]
            following = sections[min(len(sections)-1,p+2)]
            radii = []
            for axis in [1,2]:
                m0 = (sections[p+1][axis]-previous[axis])/(tb-previous[0])
                m1 = (following[axis]-sections[p][axis])/(following[0]-ta)
                radii.append((2*s**3-3*s*s+1)*sections[p][axis]+(s**3-2*s*s+s)*(tb-ta)*m0+(-2*s**3+3*s*s)*sections[p+1][axis]+(s**3-s*s)*(tb-ta)*m1)
            rx,ry = radii
            break
    opening = .63+.13*math.sin(t*math.pi/2)
    for j in range(C+1):
        a = opening+(math.tau-2*opening)*j/C
        envelope = math.sin(math.pi*j/C)**.55
        fold = (.0015+.0025*t)*math.cos(8*a+.25)*envelope
        z = .552-.455*t-.012*t*((1-math.cos(a))/2)+.003*t*t*math.cos(8*a+.25)*envelope
        z += .014*t**3*math.exp(-min(j/C,1-j/C)/.08)
        point = coat_point(((rx+fold)*math.sin(a),.026-(ry+fold)*math.cos(a),z))
        vertices.append(point)
        if i==R: hem.append(point)
        if j==0: edges[0].append(point)
        if j==C: edges[1].append(point)
for i in range(R):
    for j in range(C):
        k = i*(C+1)+j
        face = (k,k+1,k+C+2,k+C+1)
        centre = sum((Vector(vertices[idx]) for idx in face),Vector())/4
        angle = math.atan2(centre.x,.026-centre.y)%math.tau
        side_angle = min(abs(angle-math.pi/2),abs(angle-3*math.pi/2))
        if (side_angle/.37)**2+((centre.z-.482)/.059)**2<1: continue
        faces.append(face)

# Trace exact boundary loops of the cut mesh. Sleeve roots share these
# positions, keeping the shoulder seam closed throughout arm motion.
counts = {}
for face in faces:
    for a,b in zip(face,face[1:]+face[:1]):
        edge = tuple(sorted((a,b)))
        counts[edge] = counts.get(edge,0)+1
adjacency = {}
for (a,b),count in counts.items():
    if count==1:
        adjacency.setdefault(a,[]).append(b)
        adjacency.setdefault(b,[]).append(a)
unused = set(adjacency)
holes = []
while unused:
    start = min(unused)
    loop,previous,current = [],None,start
    while current not in loop:
        loop.append(current)
        unused.discard(current)
        following = [idx for idx in adjacency[current] if idx!=previous]
        previous,current = current,following[0]
    centre = sum((Vector(vertices[idx]) for idx in loop),Vector())/len(loop)
    if abs(centre.x)>.15 and .42<centre.z<.54: holes.append(loop)
if len(holes)!=2: raise RuntimeError('Expected two closed sleeve armholes')
for hole in holes:
    for repeat in range(4):
        smoothed = [coat_point(Vector(vertices[idx])*.5+Vector(vertices[hole[(j-1)%len(hole)]])*.25+Vector(vertices[hole[(j+1)%len(hole)]])*.25) for j,idx in enumerate(hole)]
        for idx,point in zip(hole,smoothed): vertices[idx] = point
surface('Coat_fitted_open_body',vertices,faces,cloth,'torso',thickness=.0035)
tube('Coat_rolled_hem',hem,.0018,cloth,'torso')
for sign in range(2): tube('Coat_front_binding_'+str(sign),edges[sign],.0020,satin,'torso')

for hole in holes:
    root_points = [Vector(vertices[idx]) for idx in hole]
    centre = sum(root_points,Vector())/len(root_points)
    sign = 1 if centre.x>0 else -1
    bone_name = 'arm_stretch_l' if sign>0 else 'arm_stretch_r'
    elbow_name = 'forearm_stretch_l' if sign>0 else 'forearm_stretch_r'
    hinge = rig.data.bones[bone_name].head_local.copy()
    axis = Vector((sign*math.cos(1.25),0,-math.sin(1.25)))
    across = Vector((sign*math.sin(1.25),0,math.cos(1.25)))
    angles = [math.atan2((p.y-centre.y)/.07,(p.z-centre.z)/.06) for p in root_points]
    sleeve_vertices,sleeve_faces,arm_weights = [],[],[]
    steps,L = 18,len(hole)
    for i in range(steps+1):
        t = i/steps
        blend = min(1,t/.38)
        blend = blend*blend*(3-2*blend)
        length = .11+.19*t
        c = hinge+axis*length+Vector((sign*.004,0,0))
        # A generous, almost untapered sleeve suits the broad flipper. Keep a
        # little fullness through the middle instead of narrowing to a wrist.
        width = .074-.004*t+.009*math.sin(math.pi*t)
        depth = .086-.006*t+.006*math.sin(math.pi*t)
        for j,angle in enumerate(angles):
            p = c+across*(math.cos(angle)*width)+Vector((0,math.sin(angle)*depth,0))
            sleeve_vertices.append(root_points[j].lerp(p,blend))
            arm_weights.append(blend)
            if i<steps:
                k = i*L+j
                sleeve_faces.append((k,i*L+(j+1)%L,(i+1)*L+(j+1)%L,k+L))
    sleeve = surface('Coat_sleeve_'+str(sign),sleeve_vertices,sleeve_faces,cloth,'torso',thickness=.003)
    # Solidify preserves the vertex order and adds a duplicate inner shell.
    for v in sleeve.data.vertices:
        amount = arm_weights[v.index%len(arm_weights)]
        n = max(0,min(1,(v.co.z-.46)/.13))*.58
        for group in sleeve.vertex_groups:
            group.remove([v.index])
        along = (v.co-hinge).dot(axis)
        fold = max(0,min(1,(along-.15)/.10))
        fold = fold*fold*(3-2*fold)
        sleeve.vertex_groups[bone_name].add([v.index],amount*(1-fold),'REPLACE')
        sleeve.vertex_groups[elbow_name].add([v.index],amount*fold,'REPLACE')
        sleeve.vertex_groups['neck_x'].add([v.index],n*(1-amount),'REPLACE')
        sleeve.vertex_groups['spine_01_x'].add([v.index],(1-n)*(1-amount),'REPLACE')
    cuff = tube('Coat_turned_cuff_'+str(sign),sleeve_vertices[-L:],.0032,satin,'torso',closed=True,segments=8)
    for group in cuff.vertex_groups: group.remove(list(range(len(cuff.data.vertices))))
    cuff.vertex_groups[elbow_name].add(list(range(len(cuff.data.vertices))),1,'REPLACE')

# The back collar rises around the lower hair envelope. Its flared top gives
# the bob haircut clearance, including a nod and a small turn of the head.
collar_vertices,collar_faces = [],[]
for i in range(6):
    t = i/5
    for j in range(49):
        a = .75+(math.tau-1.50)*j/48
        back = (1-math.cos(a))/2
        z = .535+t*(.043+.072*back)
        rx = .170+.035*t
        ry = .187+.043*t
        collar_vertices.append((rx*math.sin(a),.026-ry*math.cos(a),z))
        if i<5 and j<48:
            k = i*49+j
            collar_faces.append((k,k+1,k+50,k+49))
surface('Coat_raised_back_collar',collar_vertices,collar_faces,cloth,'torso',thickness=.004)
tube('Coat_collar_top_binding',collar_vertices[-49:],.002,satin,'torso')
# Turned-back notched lapels continue into the higher collar.
for sign in [-1,1]:
    points = [(sign*.055,-.131,.569),(sign*.137,-.132,.586),(sign*.175,-.120,.541),(sign*.139,-.165,.493),(sign*.148,-.171,.425),(sign*.092,-.148,.510)]
    surface('Coat_notched_lapel_'+str(sign),points,[(0,1,2,3,5),(5,3,4)],satin,'torso',thickness=.003,bevel=.001)

# Unstrapped black silk tie, fitted to the breast rather than suspended in air.
def breast_y(x,z):
    hit,_,_,_ = body_tree.ray_cast(Vector((x,-.5,z)),Vector((0,1,0)),1)
    if hit is None: raise RuntimeError('Tie fitting ray missed breast')
    return hit.y
vertices,faces = [],[]
U,V = 10,36
for i in range(V+1):
    t = i/V
    width = .010+.025*min(t/.85,1)**.72
    if t>.85: width = max(.0002,.035*(1-(t-.85)/.15))
    z = .512-.240*t
    for j in range(U+1):
        u = j/U*2-1
        x = width*u
        vertices.append((x,breast_y(x,z)-.010-.002*(1-u*u),z))
        if i<V and j<U:
            k = i*(U+1)+j
            faces.append((k,k+1,k+U+2,k+U+1))
surface('Tie_black_pointed_blade',vertices,faces,satin,'torso',thickness=.003)
vertices = []
for depth in [.005,.025]:
    for x,z in [(-.019,.547),(.019,.547),(.010,.510),(-.010,.510)]: vertices.append((x,breast_y(x,z)-depth,z))
surface('Tie_soft_knot',vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],satin,'torso',bevel=.003)

# Preserve named editable pieces with the original character as fitting guide.
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'elegant_suit.blend'))
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
combined.name = 'ElegantSuit_Optimized'
# Weld identical outer shoulder seam vertices for continuous shading.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=.00004)
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
materials,slots = [],[]
for mat in combined.data.materials:
    if mat not in materials: materials.append(mat)
    slots.append(materials.index(mat))
indices = [slots[p.material_index] for p in combined.data.polygons]
combined.data.materials.clear()
for mat in materials: combined.data.materials.append(mat)
for polygon,index in zip(combined.data.polygons,indices): polygon.material_index = index
combined.data.calc_loop_triangles()
triangles = len(combined.data.loop_triangles)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
combined.select_set(True)
bpy.context.view_layer.objects.active = rig
path = OUT/'elegant_suit.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_def_bones=True)

# Sleeves were fitted to relaxed flippers, matching the game's rest pose.
# Only sleeve weights use these corrected arm binds; head and torso retain
# their original binds. Raising a wing moves its sleeve around the same hinge.
data = bytearray(path.read_bytes())
json_size = struct.unpack_from('<I',data,12)[0]
doc = json.loads(data[20:20+json_size])
binary_start = 20+json_size+8
axis = Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
for gltf_skin in doc['skins']:
    accessor = doc['accessors'][gltf_skin['inverseBindMatrices']]
    view = doc['bufferViews'][accessor['bufferView']]
    start = binary_start+view.get('byteOffset',0)+accessor.get('byteOffset',0)
    for i,node_index in enumerate(gltf_skin['joints']):
        name = doc['nodes'][node_index]['name']
        if name not in ('arm_stretch_l','arm_stretch_r','forearm_stretch_l','forearm_stretch_r'): continue
        hinge = rig.data.bones['arm_stretch_'+name[-1]].head_local
        angle = 1.25 if name.endswith('_l') else -1.25
        delta = Matrix.Translation(hinge) @ Quaternion((0,1,0),angle).to_matrix().to_4x4() @ Matrix.Translation(-hinge)
        values = struct.unpack_from('<16f',data,start+64*i)
        original = Matrix(tuple(tuple(values[col*4+row] for col in range(4)) for row in range(4)))
        bind = original @ axis @ delta.inverted() @ axis.inverted()
        struct.pack_into('<16f',data,start+64*i,*[bind[row][col] for col in range(4) for row in range(4)])
path.write_bytes(data)
print('ELEGANT_EXPORTED',1,'mesh',len(materials),'materials',triangles,'triangles',path.stat().st_size,'bytes',flush=True)
