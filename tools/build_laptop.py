"""Small laptop workstation with independent keyboard keys."""
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


from math import sin,cos
wood=material('Warm wood','b39670')
edge=material('Wood edge','826e55')
shell=material('Sage laptop shell','66847e')
rim=material('Dark screen bezel','405956')
keymat=material('Ivory keyboard','e6e6d3')
panel=material('Keyboard recess','526f69')
screenmat=material('Screen','253e3d')
textmat=material('Code text','a7d9c2')
accent=material('Code accent','e3ce94')

def root(name):
 obj=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(obj);return obj

def box(parent,name,pos,size,mat,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(pos[0],-pos[2],pos[1]))
 obj=bpy.context.object;obj.name=name;obj.parent=parent
 obj.scale=(size[0],size[2],size[1]);obj.data.materials.append(mat)
 if bevel:
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  mod=obj.modifiers.new('Soft edges','BEVEL');mod.width=bevel;mod.segments=2
  bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj

station=root('LaptopStation')
box(station,'Desktop',(0,.365,.405),(.48,.024,.29),wood,.003)
box(station,'Front edge',(0,.362,.55),(.48,.018,.004),edge)
for x in [-.20,.20]:
 for z in [.29,.52]: box(station,'Desk leg',(x,.177,z),(.025,.354,.025),wood)
box(station,'Laptop base',(0,.386,.37),(.36,.018,.22),shell,.005)
box(station,'Keyboard recess',(0,.396,.34),(.335,.002,.112),panel,.001)
for row in range(4):
 for col in range(12):
  box(station,f'Key_{row}_{col}',(-.146667+col*.0266667,.400,.300+row*.026),(.021,.006,.018),keymat,.001)
box(station,'Touchpad',(0,.396,.275),(.085,.0018,.022),panel,.002)
box(station,'Hinge',(0,.397,.474),(.31,.013,.012),rim,.003)
angle=.20

def display(name,x,y,z,width,height,depth,mat):
 obj=box(station,name,(x,.400+y*cos(angle)-z*sin(angle),.475+y*sin(angle)+z*cos(angle)),(width,height,depth),mat,.001 if depth>.003 else 0)
 obj.rotation_euler.x=angle
 return obj

display('Screen lid',0,.1025,0,.354,.205,.012,shell)
display('Screen bezel',0,.106,-.0065,.333,.183,.0015,rim)
display('Screen panel',0,.106,-.0075,.311,.159,.001,screenmat)
for row in range(7):
 y=.163-row*.018
 display('Line number',-.135,y,-.0083,.009,.0025,.0007,accent)
 start=-.112+(row%3)*.011
 for col,length in enumerate([.039,.059,.029] if row%2 else [.059,.031,.052]):
  display('Code line',start+length/2,y,-.0083,length,.003,.0007,textmat if col!=1 else accent)
  start+=length+.009
cursor=display('TextCursor',.080,.055,-.0085,.003,.012,.0007,textmat)
# A subtle unbranded mark on the lid remains visible from the front camera.
display('Lid mark',0,.113,.0067,.020,.020,.001, keymat)
# Keep only the two pressed keys and cursor separate. Merge the static
# workstation to avoid dozens of draw calls on integrated graphics.
bpy.ops.object.select_all(action='DESELECT')
static=[obj for obj in station.children if obj.type=='MESH' and obj.name not in ['Key_0_10','Key_0_1','TextCursor']]
for obj in static: obj.select_set(True)
bpy.context.view_layer.objects.active=static[0]
bpy.ops.object.join()
bpy.context.object.name='WorkstationMesh'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'laptop.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'laptop_station.glb'),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
print('LAPTOP_EXPORTED',flush=True)
