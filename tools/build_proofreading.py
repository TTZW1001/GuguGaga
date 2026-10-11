"""Small proofreading desk, open book, hinged sheet and handheld rubber stamp."""
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
    values = [int(color[i:i+2],16)/255 for i in (0,2,4)]
    linear = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
    mat.diffuse_color = (*linear,1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear,1)
    shader.inputs['Roughness'].default_value = .85
    return mat

wood = material('Honey wood','b39670')
edge = material('Desk edges','826e55')
cover = material('Cloth book cover','60887d')
paper = material('Cream pages','fff4da')
rule = material('Printed text','9caa99')
page_edge = material('Paper edges','d6d4bb')
handle = material('Dark stamp handle','705a46')
rubber = material('Red stamp pad','a35f56')
ink = material('Red approval ink','bb6a60')

def root(name):
    obj = bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    return obj

def box(parent,name,pos,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(pos[0],-pos[2],pos[1]))
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    obj.scale = (size[0],size[2],size[1])
    obj.data.materials.append(mat)
    return obj

def cylinder(parent,name,y,radius,height,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=radius,depth=height,location=(0,0,y))
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    return obj

def text_lines(parent,x,y,z,back=False):
    for i,width in enumerate([.115,.125,.102,.121,.113]):
        box(parent,'Printed line',(x,y,z-.065+i*.021),(width,.0006,.0013),rule)

desk = root('ProofDesk')
box(desk,'Desktop',(0,.365,.42),(.46,.024,.28),wood)
box(desk,'Front edge',(0,.362,.562),(.46,.018,.004),edge)
for x in [-.19,.19]:
    for z in [.32,.52]:
        box(desk,'Desk leg',(x,.177,z),(.025,.354,.025),wood)
for x in [-.09,.09]:
    box(desk,'Book cover',(x,.381,.40),(.178,.006,.222),cover)
    box(desk,'Page block',(x,.391,.40),(.167,.015,.207),paper)
    for j in range(4):
        box(desk,'Page edges',(x,.386+j*.003,.504),(.167,.0006,.001),page_edge)
    text_lines(desk,x,.399,.40)
box(desk,'Book spine',(0,.390,.40),(.009,.017,.217),cover)

leaf = root('TurningSheet')
box(leaf,'Turning paper',(.086,0,0),(.172,.0012,.204),paper)
text_lines(leaf,.086,.001,0)
text_lines(leaf,.086,-.001,0,True)

stamp = root('ProofStamp')
box(stamp,'Stamp pad',(0,.004,0),(.047,.008,.039),rubber)
box(stamp,'Stamp base',(0,.011,0),(.050,.008,.042),handle)
cylinder(stamp,'Stem',.034,.010,.040,handle)
cylinder(stamp,'Round grip',.060,.021,.016,handle)

mark = root('ApprovalMark')
for x in [-.022,.022]: box(mark,'Mark edge',(x,0,0),(.0015,.0005,.036),ink)
for z in [-.018,.018]: box(mark,'Mark edge',(0,0,z),(.045,.0005,.0015),ink)
for i in range(5): box(mark,'Approval print',(-.014+i*.007,0,0),(.003,.0005,.013 if i%2 else .018),ink)

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'proofreading.blend'))
for obj,name in [(desk,'proof_desk'),(leaf,'proof_leaf'),(stamp,'proof_stamp'),(mark,'proof_mark')]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    for child in obj.children: child.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',
                             use_selection=True,export_animations=False,
                             export_cameras=False,export_lights=False)
    print('PROOF_PROP_EXPORTED',name,flush=True)
