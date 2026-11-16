"""Rumi, the engineer, matched to the team's Meshy reference (issue #44).

The body (suit, tool belt, wrench, screwdriver, knee pads, boots, tape, backpack) is `rumi_trellis_body.glb`: a mesh
made with TRELLIS (an AI image-to-3D model, the Hugging Face Space trellis-community/TRELLIS) from a screenshot of the
Meshy (AI) model. Its head came out wrong (the glass helmet confused it), so this script cuts it off above the collar
and builds the head here, in Blender, from primitives, to the reference: a soft boxy cream head, a ginger patch around
its right eye and ear, a brown patch around its left eye and ear, glossy black eyes under small brows, a pink nose, a
small mouth, whiskers, and a clear bubble helmet with a silver rim.
Both tools are AI: the README's "Use of AI" must say so if this model is used.

Run: blender -b --factory-startup --python assets/source/crew_rumi_meshy.py -- <out.glb>
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.join(HERE, "crew_rumi.glb")
BODY = os.path.join(HERE, "rumi_trellis_body.glb")

NECK_Z = 0.118      # above this the generated head is cut off (the collar ring stays)
HEAD_C = Vector((0.0, -0.01, 0.256))
HEAD_R = Vector((0.19, 0.205, 0.175))   # deep front to back: round seen from the side, as the reference

CREAM = (1.0, 0.93, 0.85)
GINGER = (0.97, 0.6, 0.2)
BROWN = (0.5, 0.21, 0.08)
PINK = (0.97, 0.6, 0.66)
DARK = (0.06, 0.04, 0.04)


def mat(name, color, rough=0.6, metal=0.0, alpha=1.0, emit=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (color[0] ** 2.2, color[1] ** 2.2, color[2] ** 2.2, 1.0)   # sRGB in, linear for Blender
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        b.inputs["Transmission Weight"].default_value = 0.9
        m.surface_render_method = "BLENDED"
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    return m


def finish(o, material):
    o.data.materials.clear()
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def sphere(name, loc, scale, material, seg=32, ring=16, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return finish(o, material)


def cyl(name, loc, r, depth, material, rot=(0, 0, 0), verts=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return finish(o, material)


def body():
    bpy.ops.import_scene.gltf(filepath=BODY)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    b = bpy.context.object
    b.name = "Body"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(b.data)
    # only the head goes: the backpack, behind it (y > 0.15), rises above the collar too and stays whole
    # the generated head goes; the backpack behind it stays whole. Measured from the side: the backpack's front face
    # stands at y 0.11..0.12 up to its top at z 0.22, and the old head's back reaches y 0.125 only above that
    def old_head(c):
        return c.z > NECK_Z and (c.y < 0.09 or (c.z > 0.225 and c.y < 0.15))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if old_head(v.co)], context="VERTS")
    bm.to_mesh(b.data)
    bm.free()
    # the head sits on the collar: its centre over the middle of the neck opening, not where the generated head was
    ring = [v.co for v in b.data.vertices if NECK_Z - 0.035 < v.co.z <= NECK_Z and v.co.y < 0.15]
    xs = [c.x for c in ring]
    ys = [c.y for c in ring]
    HEAD_C.x = (min(xs) + max(xs)) / 2
    # forward, its face flush with the front of the chest (as the reference seen from the side): the neck opening is
    # deeper than the head, and the backpack sits behind it
    HEAD_C.y = min(ys) + HEAD_R.y * 0.96 + 0.005
    print("collar centre", round(HEAD_C.x, 3), round(HEAD_C.y, 3), "opening", round(max(xs) - min(xs), 3), "x", round(max(ys) - min(ys), 3))
    return b


def head():
    """The head, measured on the reference: a dome, round on top and wide at the cheeks, cream, a big ginger patch over
    its right side (the viewer's left) from the crown down past the eye, a brown one over its left side down to the
    eye, the forehead between them cream; glossy black eyes set wide, thin brows, a big pink nose, a small "Λ"
    mouth, three brown whiskers a side, round ears on the top corners, pink inside."""
    m = bpy.data.materials.new("coat_rumi")
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
        k = 1.85 if n.z >= 0.0 else 3.0            # a round dome above, squarer, fuller cheeks below
        r = (abs(n.x) ** k + abs(n.y) ** k + abs(n.z) ** k) ** (1.0 / k)
        p = n / r
        p.x *= 1.0 + 0.08 * max(0.0, -p.z)
        p.y *= 0.96 if p.y < 0 else 1.0           # a slightly flatter face
        v.co = Vector((p.x * HEAD_R.x, p.y * HEAD_R.y, p.z * HEAD_R.z)) + HEAD_C
    bm.to_mesh(o.data)
    bm.free()
    ca = o.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    # patches, in the unit head (x right, y front -, z up): ginger and brown over the two upper sides
    patches = [((-0.72, -0.5, 0.33), 0.66, GINGER), ((0.74, -0.45, 0.48), 0.62, BROWN), ((0.55, 0.6, 0.5), 0.55, BROWN), ((-0.55, 0.6, 0.4), 0.5, GINGER)]
    for v in o.data.vertices:
        u = Vector(((v.co.x - HEAD_C.x) / HEAD_R.x, (v.co.y - HEAD_C.y) / HEAD_R.y, (v.co.z - HEAD_C.z) / HEAD_R.z))
        col = Vector(CREAM)
        for c, rr, pc in patches:
            d = (u - Vector(c)).length / rr + 0.05 * noise.noise(u * 3.0 + Vector(c))
            col = col.lerp(Vector(pc), max(0.0, min(1.0, (1.0 - d) / 0.035)))
        ca.data[v.index].color = (col.x ** 2.2, col.y ** 2.2, col.z ** 2.2, 1.0)   # float colours are linear
    finish(o, m)

    def at(ux, uz, out=0.0):
        """A point on the face at unit (ux, uz), `out` metres in front of it."""
        y = HEAD_C.y - HEAD_R.y * 0.96 * (1.0 - 0.35 * ux * ux) - out
        return Vector((ux * HEAD_R.x, y, HEAD_C.z + uz * HEAD_R.z))

    line = mat("whisker", (0.32, 0.17, 0.08), 0.6)
    for sx, ear_col, brow_col in ((-1, GINGER, (0.78, 0.38, 0.06)), (1, BROWN, (0.32, 0.12, 0.04))):
        e = at(sx * 0.44, 0.17, 0.006)
        sphere("Eye", e + Vector((0, -0.004, 0)), (0.02, 0.013, 0.024), mat("eye", (0.01, 0.01, 0.012), 0.05), 32, 16)
        sphere("Glint", e + Vector((-0.007, -0.012, 0.012)), (0.0065, 0.004, 0.0075), mat("glint", (1, 1, 1), 0.2, emit=3.0), 12, 6)
        b = at(sx * 0.44, 0.4, 0.004)
        br = cyl("Brow", b, 0.0052, 0.046, mat("brow_%d" % sx, brow_col, 0.6))
        br.rotation_euler = (0.0, math.pi / 2 + sx * 0.18, 0.0)
        # ears: big, round, on the top corners, leaning out, pink inside
        ea = HEAD_C + Vector((sx * HEAD_R.x * 0.7, 0.0, HEAD_R.z * 0.88))
        ear = sphere("Ear", ea, (0.052, 0.024, 0.05), mat("ear_%d" % sx, ear_col, 0.7), 32, 16)
        ear.rotation_euler = (0.1, sx * 0.5, sx * 0.38)
        inn = sphere("EarIn", ea + Vector((sx * 0.004, -0.018, -0.006)), (0.04, 0.012, 0.038), mat("earin", PINK, 0.55), 24, 12)
        inn.rotation_euler = (0.1, sx * 0.5, sx * 0.38)
        # whiskers: three a side, from the cheek beside the nose, fanning out and down
        for k, ang in enumerate((0.06, -0.12, -0.3)):
            root = at(sx * 0.2, -0.3 - k * 0.06, 0.007)
            L = 0.085
            w = cyl("Whisker", root + Vector((sx * math.cos(ang) * L / 2, 0, math.sin(ang) * L / 2)), 0.0016, L, line, verts=6)
            w.rotation_euler = (0.0, math.pi / 2 - sx * ang, 0.0)
    # the nose: a big rounded triangle, wider at the top
    nose = sphere("Nose", at(0.0, -0.2, 0.012), (0.028, 0.015, 0.019), mat("nose", PINK, 0.4), 32, 16)
    bm = bmesh.new()
    bm.from_mesh(nose.data)
    for v in bm.verts:
        v.co.x *= 1.0 + 0.4 * v.co.z
    bm.to_mesh(nose.data)
    bm.free()
    # the mouth: a short line down from the nose, then two strokes down and out (a small "Λ")
    mz = at(0.0, -0.38, 0.006)
    cyl("Mouth", mz, 0.002, 0.02, line, verts=6)
    for sx in (-1, 1):
        ml = cyl("MouthL", mz + Vector((sx * 0.009, 0, -0.014)), 0.002, 0.022, line, verts=6)
        ml.rotation_euler = (0.0, -sx * 0.75, 0.0)
    # no helmet: the face is in the open, easier to read and to animate (team decision)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body()
    head()
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # stand it on the ground, 1.0 tall as the rest of the crew
    zs = [(o.matrix_world @ v.co).z for o in bpy.context.scene.objects if o.type == "MESH" for v in o.data.vertices]
    zmin = min(zs)
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.location.z -= zmin
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True)
    print("wrote", OUT)


main()
