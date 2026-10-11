"""Editable hanging training bag and compact freestanding support, model units."""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/sports'
SOURCE = ROOT/'assets/incoming/sports'
OUT.mkdir(exist_ok=True)
SOURCE.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, roughness=.8):
    mat=bpy.data.materials.new(name)
    rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    mat.diffuse_color=(*rgb,1)
    mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*rgb,1)
    shader.inputs['Roughness'].default_value=roughness
    return mat

red=material('Warm terracotta leather','b75c4d')
edge=material('Leather end caps','754b40')
cream=material('Cream training target','e9d5ae')
steel=material('Matte charcoal frame','53605b',.65)
rope=material('Woven straps','74634d')

def xyz(p): return Vector((p[0],-p[2],p[1]))

def finish(obj,name,mat,parent=None,bevel=0):
    obj.name=name
    obj.data.materials.append(mat)
    if bevel:
        mod=obj.modifiers.new('Soft edges','BEVEL')
        mod.width=bevel
        mod.segments=3
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for face in obj.data.polygons: face.use_smooth=True
    if parent:
        world=obj.matrix_world.copy()
        obj.parent=parent
        obj.matrix_world=world
    return obj

def cylinder(name,a,b,r,mat,parent=None,bevel=0,vertices=32):
    a,b=xyz(a),xyz(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=(b-a).length,location=(a+b)/2)
    obj=bpy.context.object
    obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=Vector((0,0,1)).rotation_difference((b-a).normalized())
    bpy.context.view_layer.update()
    return finish(obj,name,mat,parent,bevel)

def box(name,center,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(center))
    obj=bpy.context.object
    obj.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(obj,name,mat,bevel=.009)

box('Weighted support base',(.34,.018,.43),(.23,.036,.48),steel)
cylinder('Upright',(.34,.035,.43),(.34,1.035,.43),.018,steel,bevel=.004)
cylinder('Top support',(.34,1.035,.43),(0,1.035,.405),.018,steel,bevel=.004)
cylinder('Diagonal brace',(.34,.82,.43),(.17,1.035,.4175),.010,steel)
hanger=bpy.data.objects.new('BagHanger',None)
bpy.context.collection.objects.link(hanger)
hanger.location=xyz((0,1.035,.405))
bpy.context.view_layer.update()
cylinder('Leather bag',(0,.28,.405),(0,.60,.405),.105,red,hanger,.018,48)
for y in [.295,.585]:
    cylinder('Leather binding',(0,y-.008,.405),(0,y+.008,.405),.106,edge,hanger,.003,48)
for y in [.34,.54]:
    cylinder('Cream band',(0,y-.006,.405),(0,y+.006,.405),.106,cream,hanger,.002,48)
cylinder('Round target',(0,.46,.298),(0,.46,.295),.041,cream,hanger,.001,32)
for x in [-.067,.067]:
    cylinder('Suspension strap',(x,.598,.405),(0,.72,.405),.006,rope,hanger,vertices=12)
cylinder('Hanging link',(0,.72,.405),(0,1.035,.405),.004,steel,hanger,vertices=12)

bpy.ops.object.select_all(action='SELECT')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'punching_bag.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'punching_bag.glb'),export_format='GLB',
                         use_selection=True,export_animations=False,
                         export_cameras=False,export_lights=False)
print('PUNCHING_BAG_EXPORTED',(OUT/'punching_bag.glb').stat().st_size,flush=True)
