"""Rotary telephone desk and separately animated receiver."""
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


from math import sin,cos,pi
from mathutils import Vector
wood=material('Warm wood','b39670')
edge=material('Wood edge','826e55')
coral=material('Vintage coral enamel','c5806e')
cream=material('Ivory rotary dial','efdfc4')
ink=material('Dark dial and cord','594b40')
metal=material('Dial finger stop','a68d63')
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


def cylinder(parent,name,pos,radius,height,mat):
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=height,location=(pos[0],-pos[2],pos[1]))
 obj=bpy.context.object;obj.name=name;obj.parent=parent;obj.data.materials.append(mat)
 mod=obj.modifiers.new('Rounded rim','BEVEL');mod.width=min(.003,height*.2);mod.segments=2
 bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj

station=root('TelephoneStation')
box(station,'Desktop',(0,.365,.405),(.48,.024,.32),wood,.003)
box(station,'Front edge',(0,.362,.565),(.48,.018,.004),edge)
for x in [-.20,.20]:
 for z in [.28,.53]: box(station,'Desk leg',(x,.177,z),(.025,.354,.025),wood)
box(station,'Phone base',(-.055,.405,.350),(.230,.052,.190),coral,.014)
box(station,'Cradle back',(-.055,.436,.310),(.174,.022,.036),coral,.005)
for x in [-.130,.020]: box(station,'Cradle prong',(x,.449,.310),(.018,.014,.036),coral,.004)
cylinder(station,'Dial surround',(-.055,.434,.385),.051,.008,ink)
cylinder(station,'Rotary dial',(-.055,.440,.385),.046,.006,cream)
for i in range(10):
 a=2*pi*i/12+.15
 cylinder(station,'Finger hole',(-.055+.033*cos(a),.4435,.385+.033*sin(a)),.007,.0015,ink)
cylinder(station,'Dial centre',(-.055,.444,.385),.017,.002,coral)
box(station,'Finger stop',(-.016,.448,.405),(.006,.008,.018),metal,.001)
receiver=root('Receiver')
box(receiver,'Curved grip',(0,0,0),(.190,.020,.034),coral,.008)
for x in [-.10,.10]:
 cylinder(receiver,'Receiver cup',(x,-.018,0),.031,.031,coral)
 cylinder(receiver,'Earpiece grille',(x,-.034,0),.023,.0015,ink)
 for i in range(5):
  a=2*pi*i/5
  cylinder(receiver,'Speaker hole',(x+.011*cos(a),-.035, .011*sin(a)),.0022,.001,cream)
# Consolidate static geometry; the entire receiver remains one animated prop.
for parent in [station,receiver]:
 bpy.ops.object.select_all(action='DESELECT')
 children=[obj for obj in parent.children if obj.type=='MESH']
 for obj in children: obj.select_set(True)
 bpy.context.view_layer.objects.active=children[0];bpy.ops.object.join()
 bpy.context.object.name=parent.name+'Mesh'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'telephone.blend'))
for obj,name in [(station,'telephone_station'),(receiver,'telephone_receiver')]:
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
 for child in obj.children: child.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
 print('TELEPHONE_EXPORTED',name,flush=True)
