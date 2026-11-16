"""Wayra, ground control, matched to the team's Meshy reference (issue #44), built entirely in Blender by this script.
Measured on screenshots of the reference (front, sides, back; the reference was made with Meshy, an AI tool: say so
in the README's "Use of AI" if this model is used): a chubby white suit, a blue vest open at the front, a badge on a
lanyard, grey cuffs and collar, lilac boots, a grey backpack with a blue panel and an antenna; the head white with
grey patches over both eyes and the crown, sleepy eyes, a pink nose, whiskers, and a blue headset with a microphone.
No helmet: the face is in the open (team decision, for expression and animation).

Run: blender -b --factory-startup --python assets/source/crew_wayra.py -- <out.glb>
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.join(HERE, "crew_wayra.glb")

SUIT = (0.96, 0.95, 0.95)
VEST = (0.2, 0.44, 0.84)
VEST_DARK = (0.15, 0.34, 0.68)
GREY = (0.6, 0.61, 0.65)
FUR_WHITE = (0.97, 0.96, 0.97)
FUR_GREY = (0.44, 0.45, 0.53)
LILAC = (0.56, 0.56, 0.7)
PINK = (0.97, 0.6, 0.62)
NAVY = (0.14, 0.17, 0.32)
HEADSET = (0.17, 0.4, 0.82)

HEAD_C = Vector((0.0, -0.02, 0.8))
HEAD_R = Vector((0.215, 0.205, 0.175))


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
# the torso, measured on the front view: narrow at the hips' bottom, widest at the belly, a little narrower at the neck
TORSO = [(0.2, 0.14), (0.23, 0.185), (0.28, 0.208), (0.34, 0.218), (0.42, 0.218), (0.5, 0.208), (0.57, 0.19),
         (0.61, 0.172), (0.64, 0.155)]


def body():
    suit = mat("suit", SUIT, 0.75)
    lathe("Torso", TORSO, 0.86, suit)
    # the vest: the torso's band from the belly to the collar, a little larger, open down the front
    vest_prof = [(z, r + 0.014) for z, r in TORSO if 0.33 <= z <= 0.62] + [(0.625, 0.172)]
    v = lathe("Vest", vest_prof, 0.86, mat("vest", VEST, 0.55))
    bm = bmesh.new()
    bm.from_mesh(v.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < -0.05 and abs(f.calc_center_median().x) < 0.05],
                     context="FACES")
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.012)
    bm.to_mesh(v.data)
    bm.free()
    # pockets and a name strip on the vest
    for sx in (-1, 1):
        p = rounded_box("Pocket", (sx * 0.13, -0.2, 0.39), (0.075, 0.012, 0.022), mat("vestdark", VEST_DARK, 0.55), 0.006)
        p.rotation_euler = (0.0, -sx * 0.25, sx * 0.55)
    rounded_box("NameStrip", (0.11, -0.19, 0.55), (0.07, 0.01, 0.016), mat("strip", GREY, 0.5), 0.004).rotation_euler = (0, 0, 0.5)
    # the collar ring
    torus("Collar", (0, 0, 0.64), 0.158, 0.02, mat("collar", GREY, 0.35, 0.5), scale=(1.0, 0.88, 1.0))
    # the lanyard and the badge
    nav = mat("lanyard", NAVY, 0.5)
    for sx in (-1, 1):
        capsule("Lanyard", (sx * 0.07, -0.14, 0.63), (0.0, -0.21, 0.44), 0.004, nav)
    rounded_box("Badge", (0.0, -0.215, 0.39), (0.075, 0.008, 0.095), mat("badgeframe", GREY, 0.4), 0.008)
    rounded_box("BadgeFace", (0.0, -0.221, 0.39), (0.058, 0.004, 0.075), mat("badge", (0.97, 0.97, 0.98), 0.4), 0.005)
    # legs and boots
    for sx in (-1, 1):
        capsule("Leg", (sx * 0.1, 0.0, 0.24), (sx * 0.105, -0.01, 0.1), 0.088, suit, r_end=0.078)
        b = sphere("Boot", (sx * 0.108, -0.035, 0.045), (0.082, 0.112, 0.048), mat("boot", LILAC, 0.55), 40, 20)
        bm = bmesh.new()
        bm.from_mesh(b.data)
        bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.z < -0.55], context="VERTS")   # a flat sole
        bm.to_mesh(b.data)
        bm.free()
        cyl("BootRim", (sx * 0.106, -0.015, 0.085), 0.08, 0.018, mat("bootrim", NAVY, 0.5), verts=32)
    # arms out in T-pose, a little down, grey cuffs, soft white hands
    for sx in (-1, 1):
        capsule("Arm", (sx * 0.17, -0.01, 0.56), (sx * 0.335, -0.01, 0.505), 0.062, suit, r_end=0.052)
        torus("Cuff", (sx * 0.34, -0.01, 0.502), 0.052, 0.012, mat("cuff", GREY, 0.4, 0.3), rot=(0, math.pi / 2 + sx * 0.3, 0))
        h = sphere("Hand", (sx * 0.395, -0.015, 0.49), (0.058, 0.036, 0.046), mat("hand", (0.98, 0.95, 0.93), 0.6), 32, 16)
        h.rotation_euler = (0, sx * 0.25, 0)
        sphere("Thumb", (sx * 0.385, -0.05, 0.505), (0.018, 0.016, 0.022), mat("hand", (0.98, 0.95, 0.93), 0.6), 16, 8)
    # the backpack: a grey frame, a blue panel on its back, an antenna on its right
    rounded_box("Pack", (0.0, 0.215, 0.49), (0.32, 0.13, 0.27), mat("pack", (0.72, 0.73, 0.76), 0.35, 0.2), 0.04)
    rounded_box("PackPanel", (0.0, 0.284, 0.49), (0.26, 0.012, 0.21), mat("packpanel", (0.5, 0.62, 0.86), 0.45), 0.02)
    cyl("Antenna", (0.135, 0.2, 0.68), 0.008, 0.16, mat("antenna", (0.3, 0.31, 0.34), 0.4), verts=12)
    cyl("AntennaBase", (0.135, 0.2, 0.62), 0.016, 0.04, mat("antenna", (0.3, 0.31, 0.34), 0.4), verts=16)
    sphere("AntennaTip", (0.135, 0.2, 0.765), (0.014, 0.014, 0.014), mat("antenna", (0.3, 0.31, 0.34), 0.4), 16, 8)


# ------------------------------------------------------------------------------------------------------------ head
def head():
    m = bpy.data.materials.new("coat_wayra")
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
        k = 1.9 if n.z >= 0.0 else 2.8           # a round dome, fuller cheeks below
        r = (abs(n.x) ** k + abs(n.y) ** k + abs(n.z) ** k) ** (1.0 / k)
        p = n / r
        p.x *= 1.0 + 0.08 * max(0.0, -p.z)
        p.y *= 0.96 if p.y < 0 else 1.0
        v.co = Vector((p.x * HEAD_R.x, p.y * HEAD_R.y, p.z * HEAD_R.z)) + HEAD_C
    bm.to_mesh(o.data)
    bm.free()
    ca = o.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    # grey over both eyes and the crown's sides and back, a white blaze down the middle and a white muzzle
    patches = [((-0.62, -0.45, 0.12), 0.74, FUR_GREY), ((0.62, -0.45, 0.12), 0.74, FUR_GREY),
               ((0.0, 0.0, 1.0), 0.95, FUR_GREY), ((0.0, 0.75, 0.35), 0.85, FUR_GREY)]
    for v in o.data.vertices:
        u = Vector(((v.co.x - HEAD_C.x) / HEAD_R.x, (v.co.y - HEAD_C.y) / HEAD_R.y, (v.co.z - HEAD_C.z) / HEAD_R.z))
        col = Vector(FUR_WHITE)
        for c, rr, pc in patches:
            d = (u - Vector(c)).length / rr + 0.05 * noise.noise(u * 3.0 + Vector(c))
            col = col.lerp(Vector(pc), max(0.0, min(1.0, (1.0 - d) / 0.09)))   # a soft edge
        if u.y < 0.3 and u.z > -0.1:                                   # the blaze from the crown down the face, widening toward the nose
            w = 0.12 + 0.16 * max(0.0, 0.25 - u.z)
            col = col.lerp(Vector(FUR_WHITE), max(0.0, min(1.0, (w - abs(u.x)) / 0.06)))
        col = col.lerp(Vector(FUR_WHITE), max(0.0, min(1.0, (-0.1 - u.z) / 0.12)))   # the muzzle and chin
        ca.data[v.index].color = (col.x ** 2.2, col.y ** 2.2, col.z ** 2.2, 1.0)
    finish(o, m)
    # a white tuft on the crown
    for k, (dx, dz, sc) in enumerate(((-0.02, 0.0, 1.0), (0.025, -0.01, 0.8), (0.0, 0.012, 0.7))):
        t = sphere("Tuft", HEAD_C + Vector((dx, -0.05, HEAD_R.z * 0.98 + dz)), (0.03 * sc, 0.022 * sc, 0.03 * sc),
                   mat("tuft", FUR_WHITE, 0.7), 16, 8)
        t.rotation_euler = (0.3, 0, dx * 10)

    def at(ux, uz, out=0.0):
        y = HEAD_C.y - HEAD_R.y * 0.96 * (1.0 - 0.35 * ux * ux) - out
        return Vector((ux * HEAD_R.x, y, HEAD_C.z + uz * HEAD_R.z))

    line = mat("whisker", (0.3, 0.2, 0.18), 0.6)
    for sx in (-1, 1):
        # sleepy eyes: dark, a grey lid over more than half, drooping to the outside
        e = at(sx * 0.42, 0.1, 0.005)
        sphere("Eye", e + Vector((0, -0.004, 0)), (0.024, 0.013, 0.02), mat("eye", (0.01, 0.01, 0.012), 0.05), 32, 16)
        sphere("Glint", e + Vector((-0.006, -0.012, -0.004)), (0.005, 0.003, 0.004), mat("glint", (1, 1, 1), 0.2, emit=2.0), 12, 6)
        lid = sphere("Lid", e + Vector((0, -0.006, 0.004)), (0.028, 0.016, 0.022), mat("lid", FUR_GREY, 0.6), 32, 16)
        bm = bmesh.new()
        bm.from_mesh(lid.data)
        bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.z < -0.1], context="VERTS")
        bm.to_mesh(lid.data)
        bm.free()
        lid.rotation_euler = (0.0, sx * 0.18, 0.0)
        # ears: round, grey, pink inside, on the top corners
        ea = HEAD_C + Vector((sx * HEAD_R.x * 0.72, 0.02, HEAD_R.z * 0.86))
        ear = sphere("Ear", ea, (0.05, 0.024, 0.048), mat("ear", FUR_GREY, 0.7), 32, 16)
        ear.rotation_euler = (0.1, sx * 0.5, sx * 0.38)
        inn = sphere("EarIn", ea + Vector((sx * 0.004, -0.018, -0.006)), (0.038, 0.012, 0.036), mat("earin", PINK, 0.55), 24, 12)
        inn.rotation_euler = (0.1, sx * 0.5, sx * 0.38)
        for k, ang in enumerate((0.08, -0.08, -0.24)):
            root = at(sx * 0.2, -0.36 - k * 0.06, 0.007)
            L = 0.09
            w = cyl("Whisker", root + Vector((sx * math.cos(ang) * L / 2, 0, math.sin(ang) * L / 2)), 0.0016, L, line, verts=6)
            w.rotation_euler = (0.0, math.pi / 2 - sx * ang, 0.0)
    nose = sphere("Nose", at(0.0, -0.22, 0.012), (0.026, 0.014, 0.018), mat("nose", PINK, 0.4), 32, 16)
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
    # the headset: a grey band over the crown, blue cups on the ears' sides, a microphone to the mouth
    band = mat("band", (0.42, 0.44, 0.48), 0.4, 0.3)
    bpy.ops.mesh.primitive_torus_add(major_radius=HEAD_R.x * 1.08, minor_radius=0.011, location=HEAD_C + Vector((0, 0.03, 0.0)),
                                     rotation=(math.pi / 2, 0, 0), major_segments=64, minor_segments=10)
    hb = bpy.context.object
    hb.name = "Headband"
    hb.scale = (1.0, 1.15, 1.0)
    finish(hb, band)
    bm = bmesh.new()
    bm.from_mesh(hb.data)
    bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.y < -0.01], context="VERTS")   # its upper half only
    bm.to_mesh(hb.data)
    bm.free()
    cup = mat("cup", HEADSET, 0.4)
    for sx in (-1, 1):
        cyl("EarCup", HEAD_C + Vector((sx * (HEAD_R.x * 1.05), 0.02, -0.02)), 0.055, 0.045, cup, rot=(0, math.pi / 2, 0), verts=32)
        torus("CupRim", HEAD_C + Vector((sx * (HEAD_R.x * 1.05 - 0.022), 0.02, -0.02)), 0.05, 0.01, mat("cuprim", NAVY, 0.5),
              rot=(0, math.pi / 2, 0))
    # the boom: from the cup's front, down and in, ending beside the mouth
    cup_front = HEAD_C + Vector((HEAD_R.x * 1.02, -0.04, -0.05))
    elbow = at(0.62, -0.55, 0.04)
    tip = at(0.3, -0.62, 0.035)
    capsule("Mic", cup_front, elbow, 0.0055, band)
    capsule("Mic2", elbow, tip, 0.0055, band)
    sphere("MicTip", tip, (0.02, 0.014, 0.014), mat("mictip", NAVY, 0.5), 16, 8)


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
