"""Inti, the pilot, matched to the team's Meshy reference (issue #44), built entirely in Blender by this script.
Measured on screenshots of the reference (front, sides, back; the reference was made with Meshy, an AI tool: say so
in the README's "Use of AI" if this model is used): a white flight suit with orange stripes down the arms and legs and
a zip down the front, a navy padded vest with an orange name patch, navy mitts, dark boots with orange soles, an
orange scarf flying to one side; the head ginger with a cream muzzle, aviator goggles on the brow with a brown strap
round the head, confident eyes under strong brows, a pink nose and whiskers. No helmet (team decision).

Run: blender -b --factory-startup --python assets/source/crew_inti.py -- <out.glb>
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.join(HERE, "crew_inti.glb")

SUIT = (0.97, 0.96, 0.95)
ORANGE = (0.95, 0.55, 0.18)
NAVY = (0.12, 0.17, 0.33)
BOOT = (0.27, 0.29, 0.34)
FUR = (0.93, 0.52, 0.2)
CREAM = (0.99, 0.84, 0.6)
PINK = (0.97, 0.6, 0.62)
LEATHER = (0.36, 0.2, 0.11)
LENS = (0.98, 0.62, 0.22)

HEAD_C = Vector((0.0, -0.01, 0.82))
HEAD_R = Vector((0.18, 0.175, 0.178))


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
TORSO = [(0.2, 0.14), (0.23, 0.18), (0.28, 0.2), (0.34, 0.208), (0.42, 0.205), (0.5, 0.19), (0.57, 0.172),
         (0.62, 0.155), (0.65, 0.14)]


def body():
    suit = mat("suit", SUIT, 0.7)
    orange = mat("stripe", ORANGE, 0.55)
    navy = mat("vest", NAVY, 0.6)
    lathe("Torso", TORSO, 0.86, suit)
    # the zip down the front of the suit, from the vest to the belly
    rounded_box("Zip", (0.0, -0.183, 0.4), (0.01, 0.008, 0.22), mat("zip", (0.55, 0.56, 0.6), 0.35, 0.6), 0.004)
    # the padded vest: two puffy bands around the chest, open at the front
    for k, z0 in enumerate((0.46, 0.56)):
        prof = [(z0, 0.0), (z0 + 0.004, 0.2), (z0 + 0.05, 0.218), (z0 + 0.096, 0.2), (z0 + 0.1, 0.0)]
        prof = [(z, r if r > 0 else 0.15) for z, r in prof]
        v = lathe("VestBand", prof, 0.9, navy)
        bm = bmesh.new()
        bm.from_mesh(v.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < -0.05 and abs(f.calc_center_median().x) < 0.06],
                         context="FACES")
        bm.to_mesh(v.data)
        bm.free()
    # the vest's high collar and its orange name patch
    torus("VestCollar", (0, 0, 0.665), 0.16, 0.03, navy, scale=(1.0, 0.88, 1.0))
    rounded_box("NamePatch", (0.11, -0.19, 0.6), (0.06, 0.01, 0.018), orange, 0.004).rotation_euler = (0, 0, 0.45)
    # arms, a little down, with orange stripes along the top, navy mitts
    for sx in (-1, 1):
        a, b = Vector((sx * 0.17, -0.01, 0.57)), Vector((sx * 0.31, -0.02, 0.47))
        capsule("Arm", a, b, 0.058, suit, r_end=0.052)
        capsule("ArmStripe", a + Vector((0, -0.01, 0.052)), b + Vector((0, -0.01, 0.046)), 0.011, orange)
        sphere("Mitt", (sx * 0.355, -0.03, 0.445), (0.065, 0.055, 0.06), mat("mitt", NAVY, 0.55), 32, 16)
        sphere("Thumb", (sx * 0.33, -0.08, 0.47), (0.022, 0.02, 0.026), mat("mitt", NAVY, 0.55), 16, 8)
    # legs with orange stripes down their outsides, dark boots on orange soles
    for sx in (-1, 1):
        capsule("Leg", (sx * 0.1, 0.0, 0.24), (sx * 0.105, -0.01, 0.1), 0.085, suit, r_end=0.076)
        capsule("LegStripe", (sx * 0.196, -0.05, 0.42), (sx * 0.17, -0.04, 0.11), 0.012, orange)
        b = sphere("Boot", (sx * 0.108, -0.03, 0.06), (0.078, 0.098, 0.055), mat("boot", BOOT, 0.5), 40, 20)
        bm = bmesh.new()
        bm.from_mesh(b.data)
        bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.z < -0.5], context="VERTS")
        bm.to_mesh(b.data)
        bm.free()
        cyl("Sole", (sx * 0.108, -0.035, 0.014), 0.077, 0.022, orange, verts=40).scale = (1.0, 1.25, 1.0)
        cyl("BootTop", (sx * 0.106, -0.01, 0.1), 0.078, 0.022, mat("boottop", BOOT, 0.5), verts=32)
    # the scarf: a loop round the neck and a long tail flying out to the right
    sc = mat("scarf", ORANGE, 0.75)
    torus("ScarfLoop", (0, -0.01, 0.672), 0.13, 0.035, sc, scale=(1.0, 0.95, 0.8))
    # the tail: a ribbon of quads along a gentle wave, given thickness and smoothed by modifiers (clean normals)
    verts, faces = [], []
    n = 10
    for k in range(n + 1):
        t = k / n
        p = Vector((0.1 + 0.33 * t, -0.06 + 0.17 * t, 0.665 - 0.05 * t + 0.02 * math.sin(t * 6.0)))
        w = 0.05 - 0.018 * t
        verts += [tuple(p + Vector((0, 0, w))), tuple(p + Vector((0, 0, -w)))]
        if k:
            a = 2 * (k - 1)
            faces.append((a, a + 2, a + 3, a + 1))
    me = bpy.data.meshes.new("ScarfTail")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("ScarfTail", me)
    bpy.context.collection.objects.link(o)
    sol = o.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.014
    sol.offset = 0.0
    o.modifiers.new("smooth", "SUBSURF").levels = 2
    finish(o, sc)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    o.select_set(False)


# ------------------------------------------------------------------------------------------------------------ head
def head():
    m = bpy.data.materials.new("coat_inti")
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
        k = 2.0 if n.z >= 0.0 else 2.7
        r = (abs(n.x) ** k + abs(n.y) ** k + abs(n.z) ** k) ** (1.0 / k)
        p = n / r
        p.x *= 1.0 + 0.08 * max(0.0, -p.z)
        p.y *= 0.95 if p.y < 0 else 1.0
        v.co = Vector((p.x * HEAD_R.x, p.y * HEAD_R.y, p.z * HEAD_R.z)) + HEAD_C
    bm.to_mesh(o.data)
    bm.free()
    ca = o.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    for v in o.data.vertices:
        u = Vector(((v.co.x - HEAD_C.x) / HEAD_R.x, (v.co.y - HEAD_C.y) / HEAD_R.y, (v.co.z - HEAD_C.z) / HEAD_R.z))
        cream = 0.0
        if u.y < -0.2:
            # a cream face: a narrow stripe between the eyes widening into a big round muzzle and chin
            w = 0.18 if u.z > 0.15 else 0.18 + 0.75 * min(1.0, (0.15 - u.z) / 0.3)
            if u.z < 0.5:
                cream = max(0.0, min(1.0, (w - abs(u.x)) / 0.08))
        col = Vector(FUR).lerp(Vector(CREAM), cream)
        ca.data[v.index].color = (col.x ** 2.2, col.y ** 2.2, col.z ** 2.2, 1.0)
    finish(o, m)

    def at(ux, uz, out=0.0):
        y = HEAD_C.y - HEAD_R.y * 0.95 * (1.0 - 0.3 * ux * ux) - out
        return Vector((ux * HEAD_R.x, y, HEAD_C.z + uz * HEAD_R.z))

    line = mat("whisker", (0.15, 0.08, 0.05), 0.6)
    for sx in (-1, 1):
        e = at(sx * 0.4, 0.05, 0.006)
        sphere("Eye", e + Vector((0, -0.004, 0)), (0.022, 0.013, 0.025), mat("eye", (0.01, 0.01, 0.012), 0.05), 32, 16)
        sphere("Glint", e + Vector((-0.006, -0.013, 0.009)), (0.006, 0.004, 0.007), mat("glint", (1, 1, 1), 0.2, emit=3.0), 12, 6)
        # strong, confident brows: outer ends lower, thick
        b = at(sx * 0.42, 0.3, 0.006)
        br = cyl("Brow", b, 0.008, 0.055, mat("brow", (0.42, 0.18, 0.06), 0.6))
        br.rotation_euler = (0.0, math.pi / 2 - sx * 0.15, 0.0)
        ea = HEAD_C + Vector((sx * HEAD_R.x * 0.74, 0.02, HEAD_R.z * 0.86))
        ear = sphere("Ear", ea, (0.052, 0.024, 0.05), mat("ear", FUR, 0.7), 32, 16)
        ear.rotation_euler = (0.1, sx * 0.5, sx * 0.38)
        inn = sphere("EarIn", ea + Vector((sx * 0.004, -0.017, -0.006)), (0.036, 0.012, 0.035), mat("earin", PINK, 0.55), 24, 12)
        inn.rotation_euler = (0.1, sx * 0.5, sx * 0.38)
        for k, ang in enumerate((0.08, -0.06, -0.2)):
            root = at(sx * 0.2, -0.32 - k * 0.07, 0.007)
            L = 0.1
            w = cyl("Whisker", root + Vector((sx * math.cos(ang) * L / 2, 0, math.sin(ang) * L / 2)), 0.0016, L, line, verts=6)
            w.rotation_euler = (0.0, math.pi / 2 - sx * ang, 0.0)
    nose = sphere("Nose", at(0.0, -0.22, 0.013), (0.026, 0.014, 0.018), mat("nose", PINK, 0.4), 32, 16)
    bm = bmesh.new()
    bm.from_mesh(nose.data)
    for vv in bm.verts:
        vv.co.x *= 1.0 + 0.4 * vv.co.z
    bm.to_mesh(nose.data)
    bm.free()
    mz = at(0.0, -0.42, 0.007)
    cyl("Mouth", mz, 0.002, 0.02, line, verts=6)
    for sx in (-1, 1):
        ml = cyl("MouthL", mz + Vector((sx * 0.009, 0, -0.012)), 0.002, 0.022, line, verts=6)
        ml.rotation_euler = (0.0, -sx * 1.1, 0.0)
    # aviator goggles on the brow, the strap round the head
    leather = mat("strap", LEATHER, 0.6)
    torus("GoggleStrap", HEAD_C + Vector((0, 0.0, HEAD_R.z * 0.52)), 1.0, 0.016, leather,
          rot=(-0.12, 0, 0), scale=(HEAD_R.x * 0.9, HEAD_R.y * 0.92, 1.0))
    for sx in (-1, 1):
        g = at(sx * 0.38, 0.72, 0.02)
        torus("GoggleRim", g, 0.042, 0.012, mat("gogrim", (0.48, 0.3, 0.18), 0.45, 0.2), rot=(math.pi / 2 - 0.35, 0, 0))
        lens = sphere("GoggleLens", g + Vector((0, -0.004, 0)), (0.038, 0.012, 0.038), mat("lens", LENS, 0.15, emit=0.2), 32, 16)
        lens.rotation_euler = (-0.35, 0, 0)
    capsule("GoggleBridge", at(-0.17, 0.74, 0.03), at(0.17, 0.74, 0.03), 0.009, leather)


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
