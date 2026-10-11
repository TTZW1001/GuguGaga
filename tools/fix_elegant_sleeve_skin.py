"""Reweight existing sleeves in Blender and GLB without rebuilding their shape.
Run in Blender with assets/incoming/accessories/elegant_suit.blend open.
The regular builder uses the same forearm blend for future exports.
"""
import bpy
import json
import math
import struct
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')


def fold_weight(along):
    t = max(0, min(1, (along - .15) / .10))
    return t * t * (3 - 2 * t)


source_vertices = 0
for sign, side in [(1, 'l'), (-1, 'r')]:
    arm = 'arm_stretch_' + side
    elbow = 'forearm_stretch_' + side
    hinge = rig.data.bones[arm].head_local
    axis = Vector((sign * math.cos(1.25), 0, -math.sin(1.25)))
    for name in ['Coat_sleeve_' + str(sign), 'Coat_turned_cuff_' + str(sign)]:
        obj = bpy.data.objects[name]
        if elbow not in obj.vertex_groups:
            obj.vertex_groups.new(name=elbow)
        for vertex in obj.data.vertices:
            weights = {obj.vertex_groups[g.group].name: g.weight for g in vertex.groups}
            total = weights.get(arm, 0) + weights.get(elbow, 0)
            fold = 1 if 'cuff' in name else fold_weight((vertex.co - hinge).dot(axis))
            obj.vertex_groups[arm].add([vertex.index], total * (1 - fold), 'REPLACE')
            obj.vertex_groups[elbow].add([vertex.index], total * fold, 'REPLACE')
            source_vertices += 1

# Edit only joint weights and two inverse binds in the shipped GLB. All vertex
# positions, normals, triangles, UVs, materials and the confirmed rest shape
# stay byte-identical to the previous model.
path = ROOT / 'assets/accessories/elegant_suit.glb'
data = bytearray(path.read_bytes())
json_size = struct.unpack_from('<I', data, 12)[0]
doc = json.loads(data[20:20 + json_size])
binary_start = 20 + json_size + 8
skin = doc['skins'][0]
joint_names = [doc['nodes'][index]['name'] for index in skin['joints']]


def accessor_layout(index):
    accessor = doc['accessors'][index]
    view = doc['bufferViews'][accessor['bufferView']]
    code = {5121: 'B', 5123: 'H', 5126: 'f'}[accessor['componentType']]
    width = {'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[accessor['type']]
    fmt = '<' + code * width
    offset = binary_start + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', struct.calcsize(fmt))
    return accessor['count'], fmt, offset, stride


def read(index, vertex):
    _, fmt, offset, stride = accessor_layout(index)
    return struct.unpack_from(fmt, data, offset + vertex * stride)


def write(index, vertex, values):
    _, fmt, offset, stride = accessor_layout(index)
    struct.pack_into(fmt, data, offset + vertex * stride, *values)


elbow_indices = {joint_names.index('forearm_stretch_l'), joint_names.index('forearm_stretch_r')}
already_fixed = any(
    weight > .00001 and joint in elbow_indices
    for mesh in doc['meshes'] for primitive in mesh['primitives']
    for i in range(doc['accessors'][primitive['attributes']['POSITION']]['count'])
    for joint, weight in zip(read(primitive['attributes']['JOINTS_0'], i), read(primitive['attributes']['WEIGHTS_0'], i))
)
changed = 0
if not already_fixed:
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attributes = primitive['attributes']
            is_cuff = doc['materials'][primitive['material']]['name'] == 'Charcoal satin ribbon and lapels'
            for i in range(doc['accessors'][attributes['POSITION']]['count']):
                joints = read(attributes['JOINTS_0'], i)
                weights = read(attributes['WEIGHTS_0'], i)
                position = Vector(read(attributes['POSITION'], i))
                updated = []
                for joint, weight in zip(joints, weights):
                    if weight <= 0:
                        continue
                    name = joint_names[joint]
                    if name not in ('arm_stretch_l', 'arm_stretch_r'):
                        updated.append((joint, weight))
                        continue
                    sign = 1 if name.endswith('_l') else -1
                    hinge = Vector((sign * .13, .515, -.035))
                    axis = Vector((sign * math.cos(1.25), -math.sin(1.25), 0))
                    fold = 1 if is_cuff else fold_weight((position - hinge).dot(axis))
                    updated.extend([(joint, weight * (1 - fold)), (joint_names.index('forearm_stretch_' + name[-1]), weight * fold)])
                updated = [(j, w) for j, w in updated if w > 0]
                assert len(updated) <= 4
                updated += [(0, 0)] * (4 - len(updated))
                write(attributes['JOINTS_0'], i, [j for j, _ in updated])
                write(attributes['WEIGHTS_0'], i, [w for _, w in updated])
                if tuple(j for j, _ in updated) != joints or tuple(w for _, w in updated) != weights:
                    changed += 1
    for side in ['l', 'r']:
        joint = joint_names.index('forearm_stretch_' + side)
        sign = 1 if side == 'l' else -1
        hinge = Vector((sign * .13, .515, -.035))
        rotation = Quaternion((0, 0, -1), sign * 1.25).to_matrix().to_4x4()
        delta = Matrix.Translation(hinge) @ rotation @ Matrix.Translation(-hinge)
        values = read(skin['inverseBindMatrices'], joint)
        original = Matrix(tuple(tuple(values[col * 4 + row] for col in range(4)) for row in range(4)))
        bind = original @ delta.inverted()
        write(skin['inverseBindMatrices'], joint, [bind[row][col] for col in range(4) for row in range(4)])
    path.write_bytes(data)

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'assets/incoming/accessories/elegant_suit.blend'))
print('SLEEVE_SKIN_FIXED', source_vertices, 'source vertices;', changed, 'export vertices; geometry unchanged', flush=True)
