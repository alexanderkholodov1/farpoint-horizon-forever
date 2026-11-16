"""Killa, the scientist, matched to the team's Meshy reference (issue #44), built entirely in Blender by this script.
Measured on screenshots of the reference (front, sides, back; the reference was made with Meshy, an AI tool: say so
in the README's "Use of AI" if this model is used): a long white lab coat open down the front over a blue lining,
a chest pocket with a pen strip, two lower pockets, grey cuffs and collar, brown legs below the coat, navy boots, a
white backpack with navy straps and a grey device; the head tall and brown with a white blaze and muzzle, a tuft on
top, glossy worried eyes, a pink nose and whiskers. No helmet (team decision, for expression and animation).

Run: blender -b --factory-startup --python assets/source/crew_killa.py -- <out.glb>
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.join(HERE, "crew_killa.glb")

COAT = (0.97, 0.96, 0.95)
BLUE = (0.25, 0.55, 0.92)
GREY = (0.6, 0.61, 0.65)
NAVY = (0.15, 0.19, 0.36)
BOOT = (0.32, 0.34, 0.42)
FUR_BROWN = (0.47, 0.22, 0.11)
FUR_WHITE = (0.98, 0.95, 0.94)
PINK = (0.97, 0.62, 0.62)

HEAD_C = Vector((0.0, -0.01, 0.83))
HEAD_R = Vector((0.155, 0.16, 0.172))


# ------------------------------------------------------------------------------------------------------------ helpers
def mat(name, color, rough=0.6, metal=0.0, alpha=1.0, emit=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (color[0] ** 2.2, color[1] ** 2.2, color[2] ** 2.2, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (color[0] ** 2.2, color[1] ** 2.2, color[2] ** 2.2, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    return m


def finish(o, material):
    o.data.materials.clear()
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def sphere(name, loc, scale, material, seg=40, ring=20, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return finish(o, material)


def cyl(name, loc, r, depth, material, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return finish(o, material)


def torus(name, loc, major, minor, material, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=64, minor_segments=12)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return finish(o, material)


def capsule(name, a, b, r, material, r_end=None):
    """A smooth capsule from a to b (radius r, r_end at b)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rb = r_end if r_end else r
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=r, radius2=rb, depth=d.length, location=(a + b) / 2)
    c = bpy.context.object
    c.name = name
    c.rotation_mode = "QUATERNION"
    c.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    finish(c, material)
    sphere(name + "A", a, (r, r, r), material, 32, 16)
    sphere(name + "B", b, (rb, rb, rb), material, 32, 16)


def rounded_box(name, loc, size, material, bevel=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    md = o.modifiers.new("round", "BEVEL")
    md.width = bevel
    md.segments = 6
    md.limit_method = "NONE"
    return finish(o, material)


def lathe(name, profile, depth_k, material, seg=64):
    """A body of revolution from (z, half-width) pairs, its depth `depth_k` times its width: a soft, chubby torso."""
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        ring = []
        for j in range(seg):
            a = 2.0 * math.pi * j / seg
            ring.append(bm.verts.new((r * math.cos(a), r * depth_k * math.sin(a), z)))
        rings.append(ring)
    for a_, b_ in zip(rings, rings[1:]):
        for j in range(seg):
            bm.faces.new((a_[j], a_[(j + 1) % seg], b_[(j + 1) % seg], b_[j]))
    bot = bm.verts.new((0, 0, profile[0][0]))
    for j in range(seg):
        bm.faces.new((rings[0][(j + 1) % seg], rings[0][j], bot))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return finish(o, material)


# ------------------------------------------------------------------------------------------------------------ body
# the coat, measured on the front view: a little narrower at the shoulders, flared toward its hem at the knees
COAT_PROF = [(0.15, 0.205), (0.2, 0.2), (0.3, 0.19), (0.4, 0.178), (0.5, 0.168), (0.58, 0.162), (0.64, 0.152), (0.675, 0.13)]


def coat_open_width(z):
    """Half the width of the blue opening down the front of the coat, at height z: narrow at the collar, wide at the hem."""
    return 0.035 + 0.09 * max(0.0, (0.62 - z) / 0.47) ** 1.4


def body():
    coat_m = mat("coat", COAT, 0.75)
    blue_m = mat("lining", BLUE, 0.5)
    dense = []
    for (z0, r0), (z1, r1) in zip(COAT_PROF, COAT_PROF[1:]):
        for k in range(8):
            t = k / 8.0
            dense.append((z0 + (z1 - z0) * t, r0 + (r1 - r0) * t))
    dense.append(COAT_PROF[-1])
    # white and the blue lining as the coat's own vertex colours: a clean, smooth edge down the opening
    cm = bpy.data.materials.new("coat_vc")
    cm.use_nodes = True
    cb = cm.node_tree.nodes["Principled BSDF"]
    cb.inputs["Roughness"].default_value = 0.7
    cvc = cm.node_tree.nodes.new("ShaderNodeVertexColor")
    cvc.layer_name = "Col"
    cm.node_tree.links.new(cvc.outputs["Color"], cb.inputs["Base Color"])
    o = lathe("Coat", dense, 0.82, cm, seg=192)
    ca = o.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    for v in o.data.vertices:
        c = v.co
        k = 0.0
        if c.y < 0:
            k = max(0.0, min(1.0, (coat_open_width(c.z) - abs(c.x)) / 0.006))
        col = Vector(COAT).lerp(Vector(BLUE), k)
        ca.data[v.index].color = (col.x ** 2.2, col.y ** 2.2, col.z ** 2.2, 1.0)
    # an open hem: the bottom cap goes, the coat is a shell over the legs
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < 0.152], context="FACES")
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.01)
    bm.to_mesh(o.data)
    bm.free()
    # the torso inside the coat (seen through the open hem)
    lathe("Torso", [(0.13, 0.12), (0.2, 0.17), (0.45, 0.16), (0.66, 0.13)], 0.8, mat("torso", COAT, 0.75))
    torus("Collar", (0, 0, 0.675), 0.13, 0.02, mat("collar", GREY, 0.35, 0.5), scale=(1.0, 0.85, 1.0))
    # pockets: one on the chest with a pen strip, two low
    rounded_box("ChestPocket", (0.075, -0.142, 0.52), (0.06, 0.008, 0.06), coat_m, 0.006)
    rounded_box("PenStrip", (0.075, -0.148, 0.555), (0.05, 0.006, 0.012), mat("pen", GREY, 0.4), 0.004)
    for sx in (-1, 1):
        rounded_box("Pocket", (sx * 0.125, -0.165, 0.29), (0.07, 0.01, 0.075), coat_m, 0.008)
    # the backpack's straps over the shoulders
    nav = mat("strap", NAVY, 0.5)
    for sx in (-1, 1):
        capsule("StrapTop", (sx * 0.1, 0.06, 0.67), (sx * 0.135, -0.09, 0.6), 0.012, nav)
        capsule("Strap", (sx * 0.135, -0.09, 0.6), (sx * 0.15, -0.06, 0.44), 0.012, nav)
    # sleeves in T-pose, grey cuffs, white hands
    for sx in (-1, 1):
        capsule("Sleeve", (sx * 0.13, -0.01, 0.6), (sx * 0.29, -0.01, 0.51), 0.058, coat_m, r_end=0.05)
        torus("Cuff", (sx * 0.295, -0.01, 0.507), 0.05, 0.011, mat("cuff", GREY, 0.4, 0.3), rot=(0, math.pi / 2 + sx * 0.5, 0))
        h = sphere("Hand", (sx * 0.345, -0.015, 0.49), (0.054, 0.034, 0.042), mat("hand", (0.98, 0.95, 0.93), 0.6), 32, 16)
        h.rotation_euler = (0, sx * 0.45, 0)
        sphere("Thumb", (sx * 0.33, -0.048, 0.505), (0.016, 0.015, 0.02), mat("hand", (0.98, 0.95, 0.93), 0.6), 16, 8)
    # brown legs below the coat, navy boots
    fur = mat("legfur", FUR_BROWN, 0.7)
    for sx in (-1, 1):
        capsule("Leg", (sx * 0.075, 0.0, 0.2), (sx * 0.078, -0.005, 0.085), 0.058, fur)
        b = sphere("Boot", (sx * 0.08, -0.025, 0.04), (0.06, 0.08, 0.045), mat("boot", BOOT, 0.5), 40, 20)
        bm = bmesh.new()
        bm.from_mesh(b.data)
        bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.z < -0.55], context="VERTS")
        bm.to_mesh(b.data)
        bm.free()
        cyl("BootRim", (sx * 0.079, -0.015, 0.08), 0.058, 0.016, mat("bootrim", NAVY, 0.5), verts=32)
    # the backpack: white, rounded, a grey device with a dial on its back
    rounded_box("Pack", (0.0, 0.2, 0.5), (0.28, 0.13, 0.3), mat("pack", (0.95, 0.95, 0.96), 0.55), 0.05)
    rounded_box("Device", (0.0, 0.27, 0.52), (0.1, 0.02, 0.12), mat("device", GREY, 0.35, 0.4), 0.025)
    cyl("Dial", (0.0, 0.285, 0.55), 0.03, 0.02, mat("dial", (0.85, 0.86, 0.88), 0.3, 0.5), rot=(math.pi / 2, 0, 0), verts=32)


# ------------------------------------------------------------------------------------------------------------ head
def head():
    m = bpy.data.materials.new("coat_killa")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    vc = m.node_tree.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    m.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=128, ring_count=96, radius=1.0)
    o = bpy.context.object
    o.name = "Head"
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for v in bm.verts:
        n = v.co.normalized()
        k = 2.0 if n.z >= 0.0 else 2.6          # a round dome, soft cheeks
        r = (abs(n.x) ** k + abs(n.y) ** k + abs(n.z) ** k) ** (1.0 / k)
        p = n / r
        p.x *= 1.0 + 0.05 * max(0.0, -p.z)
        p.y *= 0.95 if p.y < 0 else 1.0
        v.co = Vector((p.x * HEAD_R.x, p.y * HEAD_R.y, p.z * HEAD_R.z)) + HEAD_C
    bm.to_mesh(o.data)
    bm.free()
    ca = o.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    for v in o.data.vertices:
        u = Vector(((v.co.x - HEAD_C.x) / HEAD_R.x, (v.co.y - HEAD_C.y) / HEAD_R.y, (v.co.z - HEAD_C.z) / HEAD_R.z))
        col = Vector(FUR_BROWN)
        white = 0.0
        if u.y < -0.2:
            # the blaze: a narrow stripe from the forehead between the eyes, opening into a wide white muzzle
            w = 0.13 if u.z > 0.0 else 0.13 + 0.7 * min(1.0, (0.0 - u.z) / 0.3)
            if u.z < 0.62:
                white = max(0.0, min(1.0, (w - abs(u.x)) / 0.06))
        col = col.lerp(Vector(FUR_WHITE), white)
        ca.data[v.index].color = (col.x ** 2.2, col.y ** 2.2, col.z ** 2.2, 1.0)
    finish(o, m)
    fur = mat("tuft", FUR_BROWN, 0.7)
    for k, (dx, tilt, sc) in enumerate(((-0.02, -0.4, 1.0), (0.012, 0.1, 1.1), (0.04, 0.5, 0.8))):
        t = sphere("Tuft", HEAD_C + Vector((dx, 0.0, HEAD_R.z * 0.97)), (0.014 * sc, 0.03 * sc, 0.032 * sc), fur, 16, 8)
        t.rotation_euler = (-0.6, tilt, 0)

    def at(ux, uz, out=0.0):
        y = HEAD_C.y - HEAD_R.y * 0.95 * (1.0 - 0.25 * ux * ux) - out
        return Vector((ux * HEAD_R.x, y, HEAD_C.z + uz * HEAD_R.z))

    line = mat("whisker", (0.12, 0.08, 0.06), 0.6)
    for sx in (-1, 1):
        e = at(sx * 0.4, 0.1, 0.006)
        sphere("Eye", e + Vector((0, -0.004, 0)), (0.026, 0.015, 0.03), mat("eye", (0.01, 0.01, 0.012), 0.05), 32, 16)
        sphere("Glint", e + Vector((-0.006, -0.013, 0.01)), (0.006, 0.004, 0.007), mat("glint", (1, 1, 1), 0.2, emit=3.0), 12, 6)
        # worried brows: their inner ends raised
        b = at(sx * 0.42, 0.42, 0.005)
        br = cyl("Brow", b, 0.0055, 0.045, mat("brow", (0.28, 0.12, 0.05), 0.6))
        br.rotation_euler = (0.0, math.pi / 2 + sx * 0.28, 0.0)
        ea = HEAD_C + Vector((sx * HEAD_R.x * 0.75, 0.02, HEAD_R.z * 0.88))
        ear = sphere("Ear", ea, (0.048, 0.022, 0.046), mat("ear", FUR_BROWN, 0.7), 32, 16)
        ear.rotation_euler = (0.1, sx * 0.5, sx * 0.38)
        inn = sphere("EarIn", ea + Vector((sx * 0.004, -0.016, -0.006)), (0.034, 0.011, 0.033), mat("earin", PINK, 0.55), 24, 12)
        inn.rotation_euler = (0.1, sx * 0.5, sx * 0.38)
        for k, ang in enumerate((0.1, -0.06, -0.22)):
            root = at(sx * 0.22, -0.3 - k * 0.07, 0.007)
            L = 0.09
            w = cyl("Whisker", root + Vector((sx * math.cos(ang) * L / 2, 0, math.sin(ang) * L / 2)), 0.0015, L, line, verts=6)
            w.rotation_euler = (0.0, math.pi / 2 - sx * ang, 0.0)
    nose = sphere("Nose", at(0.0, -0.2, 0.012), (0.024, 0.013, 0.016), mat("nose", PINK, 0.4), 32, 16)
    bm = bmesh.new()
    bm.from_mesh(nose.data)
    for vv in bm.verts:
        vv.co.x *= 1.0 + 0.4 * vv.co.z
    bm.to_mesh(nose.data)
    bm.free()
    mz = at(0.0, -0.4, 0.006)
    cyl("Mouth", mz, 0.002, 0.02, line, verts=6)
    for sx in (-1, 1):
        ml = cyl("MouthL", mz + Vector((sx * 0.009, 0, -0.012)), 0.002, 0.022, line, verts=6)
        ml.rotation_euler = (0.0, -sx * 1.1, 0.0)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body()
    head()
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True)
    print("wrote", OUT)


main()
