"""The cuy crew in T-pose (issue #44), the second look: a full figure with legs and arms out, as the team's reference
sheet shows them (the reference was made with Meshy, an AI tool: these models are built by this script in Blender,
from primitives, to match it; declare that in the README if they are used). Each wears the suit of its job:
  Rumi the engineer: a work suit with a tool belt and pouches, knee pads, a roll of tape on the hip;
  Wayra ground control: a blue vest with a badge on a lanyard, a headset, an antenna on the backpack;
  Killa the scientist: a long lab coat with a blue stripe down the front.

Run: blender -b --factory-startup --python assets/source/crew_cuy_tpose.py -- <out_dir> [render]
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, noise

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0]) if ARGS else os.path.abspath("build/crew")
RENDER = "render" in ARGS
os.makedirs(OUT, exist_ok=True)

WHITE_FUR = (0.95, 0.93, 0.9)
GINGER = (0.92, 0.5, 0.08)
BROWN = (0.36, 0.15, 0.06)
LAVENDER = (0.42, 0.42, 0.56)
PINK = (0.97, 0.66, 0.7)
SUIT = (0.93, 0.94, 0.96)
GREY = (0.55, 0.57, 0.62)
NAVY = (0.12, 0.16, 0.3)
AMBER = (1.0, 0.72, 0.12)
BLUE = (0.08, 0.3, 0.85)
LILAC = (0.6, 0.6, 0.85)
DARK = (0.08, 0.06, 0.06)

# Each: head coat and patches [(centre on the unit head (x right, y front-, z up), radius, colour)], face, outfit.
CREW = {
    "rumi": {"coat": WHITE_FUR,
             "patches": [((-0.55, -0.6, 0.35), 0.5, GINGER), ((0.6, -0.5, 0.35), 0.55, BROWN), ((0.6, 0.2, 0.7), 0.5, BROWN)],
             "ears": (GINGER, BROWN), "brows": (0.25, -0.25), "lid": 0.25, "mouth": "flat", "outfit": "engineer"},
    "wayra": {"coat": WHITE_FUR,
              "patches": [((0.0, 0.0, 1.0), 0.75, LAVENDER), ((-0.65, -0.3, 0.55), 0.45, LAVENDER), ((0.65, -0.3, 0.55), 0.45, LAVENDER)],
              "ears": (LAVENDER, LAVENDER), "brows": (-0.05, 0.05), "lid": 0.6, "mouth": "y", "outfit": "ground"},
    "killa": {"coat": BROWN,
              "patches": [((0.0, -0.95, 0.15), 0.42, WHITE_FUR), ((0.0, -0.7, 0.75), 0.22, WHITE_FUR)],
              "ears": (BROWN, BROWN), "brows": (0.2, -0.2), "lid": 0.3, "mouth": "flat", "outfit": "scientist"},
}


# ------------------------------------------------------------------------------------------------- helpers
def mat(name, color, rough=0.6, metal=0.0, alpha=1.0, emit=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
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


def add(o, parent, material):
    o.data.materials.append(material)
    o.parent = parent
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def sphere(name, loc, scale, parent, material, seg=40, ring=20, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return add(o, parent, material)


def cyl(name, loc, r, depth, parent, material, rot=(0, 0, 0), verts=32, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r2, radius2=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return add(o, parent, material)


def box(name, loc, size, parent, material, bevel=0.02, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    add(o, parent, material)
    md = o.modifiers.new("b", "BEVEL")
    md.width = bevel
    md.segments = 3
    md.limit_method = "NONE"
    return o


def torus(name, loc, major, minor, parent, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=48, minor_segments=12)
    o = bpy.context.object
    o.name = name
    return add(o, parent, material)


def limb(name, a, b, r, parent, material, r_end=None):
    """A rounded capsule from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    c = cyl(name, (a + b) / 2, r_end if r_end else r, d.length, parent, material, verts=24, r2=r)
    c.rotation_mode = "QUATERNION"
    c.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    sphere(name + "A", a, (r, r, r), parent, material, 24, 12)
    sphere(name + "B", b, (r_end or r,) * 3, parent, material, 24, 12)
    return c


def apply_all(o):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    o.select_set(False)


# ------------------------------------------------------------------------------------------------- the head
HEAD_C = Vector((0.0, 0.0, 0.79))   # the head's centre (the figure is 1.0 tall)
HR = Vector((0.165, 0.145, 0.155))   # its half sizes


def head(root, spec, name):
    """A soft, slightly boxy head with the coat and patches painted on its vertices, then the face and the ears."""
    m = bpy.data.materials.new("coat_" + name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.8
    b.inputs["Sheen Weight"].default_value = 0.5
    vc = m.node_tree.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    m.node_tree.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=128, ring_count=80, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    o.name = "Head"
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for v in bm.verts:
        n = v.co.normalized()
        k = 3.0
        r = (abs(n.x) ** k + abs(n.y) ** k + abs(n.z) ** k) ** (1.0 / k)
        p = n / r
        p.z *= 1.0 - 0.08 * max(0.0, -p.z)      # a fuller jaw, flatter below
        v.co = p
    bm.to_mesh(o.data)
    bm.free()
    ca = o.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")   # linear, as the materials
    for v in o.data.vertices:
        p = v.co.normalized()
        col = Vector(spec["coat"])
        for (c, rr, pc) in spec["patches"]:
            cc = Vector(c).normalized()
            d = (p - cc).length / rr + 0.18 * noise.noise(p * 5.0 + cc * 3.0)
            col = col.lerp(Vector(pc), max(0.0, min(1.0, (1.0 - d) / 0.08)))
        ca.data[v.index].color = (col.x, col.y, col.z, 1.0)
    o.scale = HR
    o.location = HEAD_C
    add(o, root, m)
    # the face, on the front (-y)
    fy = HEAD_C.y - HR.y - 0.004
    line = mat("line", DARK, 0.6)
    for side, sx in enumerate((-1, 1)):
        ex = HEAD_C + Vector((sx * 0.068, 0.0, 0.025))
        sphere("Eye", (ex.x, fy + 0.012, ex.z), (0.022, 0.014, 0.026), root, mat("eye", (0.02, 0.02, 0.03), 0.15), 24, 12)
        sphere("Glint", (ex.x + 0.006, fy - 0.002, ex.z + 0.01), (0.006, 0.003, 0.006), root, mat("glint", (1, 1, 1), 0.2, emit=2.0), 12, 6)
        if spec["lid"] > 0.0:
            lid = sphere("Lid", (ex.x, fy + 0.008, ex.z + 0.026 * (1.0 - spec["lid"] * 2.0) + 0.006), (0.027, 0.016, 0.016), root,
                         mat("lid_" + name + str(side), spec["coat"], 0.8), 24, 12)
            bm = bmesh.new()
            bm.from_mesh(lid.data)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.0], context="VERTS")
            bm.to_mesh(lid.data)
            bm.free()
        br = cyl("Brow", (ex.x, fy + 0.004, ex.z + 0.045), 0.005, 0.045, root, line, verts=8)
        br.rotation_euler = (0.0, math.pi / 2 - sx * spec["brows"][side], 0.0)
    nz = HEAD_C.z - 0.035
    sphere("Nose", (0, fy - 0.002, nz), (0.02, 0.012, 0.014), root, mat("nose", PINK, 0.5), 24, 12)
    if spec["mouth"] == "y":
        cyl("Mouth", (0, fy, nz - 0.02), 0.0028, 0.018, root, line, verts=6)
        for sx in (-1, 1):
            cyl("MouthL", (sx * 0.008, fy, nz - 0.032), 0.0028, 0.02, root, line, rot=(0, sx * 0.9, 0), verts=6)
    else:
        cyl("Mouth", (0, fy, nz - 0.024), 0.0028, 0.022, root, line, rot=(0, math.pi / 2, 0), verts=6)
        for sx in (-1, 1):
            cyl("MouthL", (sx * 0.01, fy, nz - 0.03), 0.0028, 0.016, root, line, rot=(0, sx * 1.1, 0), verts=6)
    for sx in (-1, 1):
        for k, ang in enumerate((-0.15, 0.0, 0.15)):
            w = cyl("Whisker", (sx * 0.1, fy + 0.006, nz - 0.012 + k * 0.012), 0.0018, 0.09, root, line, verts=6)
            w.rotation_euler = (0.0, math.pi / 2, sx * ang)
    for side, sx in enumerate((-1, 1)):
        at = HEAD_C + Vector((sx * 0.12, 0.0, HR.z * 0.9))
        e = sphere("Ear", at, (0.05, 0.022, 0.045), root, mat("ear_%s%d" % (name, side), spec["ears"][side], 0.8), 24, 12)
        e.rotation_euler = (0.1, 0.0, sx * 0.25)
        e.rotation_euler.y = sx * 0.55
        i = sphere("EarIn", at + Vector((0, -0.012, -0.004)), (0.033, 0.012, 0.03), root, mat("earin", PINK, 0.7), 24, 12)
        i.rotation_euler = (0.1, sx * 0.55, sx * 0.25)


# ------------------------------------------------------------------------------------------------- the body
def body(root, outfit):
    suit = mat("suit", SUIT, 0.6)
    glove = mat("glove", (0.85, 0.87, 0.9), 0.55)
    # torso: a rounded block from the hips to the neck
    box("Torso", (0, 0, 0.45), (0.27, 0.22, 0.32), root, suit, bevel=0.08)
    torus("NeckRing", (0, 0, 0.635), 0.105, 0.018, root, mat("ring", (0.78, 0.8, 0.84), 0.25, 0.85))
    # backpack
    box("Pack", (0, 0.14, 0.47), (0.2, 0.09, 0.24), root, suit, bevel=0.035)
    # arms out in T-pose, a little down
    for sx in (-1, 1):
        limb("Arm", (sx * 0.13, 0, 0.55), (sx * 0.27, 0, 0.5), 0.042, root, suit, r_end=0.038)
        sphere("Glove", (sx * 0.305, 0, 0.49), (0.04, 0.034, 0.038), root, glove, 24, 12)
        sphere("Thumb", (sx * 0.295, -0.03, 0.51), (0.015, 0.015, 0.018), root, glove, 12, 6)
        boot_col = LILAC if outfit == "ground" else ((0.13, 0.15, 0.28) if outfit == "scientist" else GREY)
        limb("Leg", (sx * 0.065, 0, 0.29), (sx * 0.07, 0, 0.075), 0.062, root, suit)
        b = sphere("Boot", (sx * 0.074, -0.025, 0.045), (0.07, 0.09, 0.05), root, mat("boot_" + outfit, boot_col, 0.6), 24, 12)
    # the bubble helmet
    sphere("Helmet", HEAD_C + Vector((0, 0, 0.01)), (0.205, 0.2, 0.2), root, mat("glass", (0.88, 0.94, 1.0), 0.02, alpha=0.12), 48, 24)
    torus("HelmetRing", (0, 0, 0.62), 0.14, 0.012, root, mat("ring", (0.78, 0.8, 0.84), 0.25, 0.85))
    return suit


def engineer(root):
    navy = mat("navy", NAVY, 0.5)
    amber = mat("amber", AMBER, 0.5)
    grey = mat("grey", GREY, 0.5)
    box("Belt", (0, 0, 0.33), (0.285, 0.235, 0.05), root, navy, bevel=0.015)
    box("Buckle", (0, -0.12, 0.33), (0.05, 0.01, 0.04), root, amber, bevel=0.005)
    for sx, w in ((-1, 0.05), (1, 0.045)):
        box("Pouch", (sx * 0.1, -0.12, 0.31), (w, 0.03, 0.05), root, amber, bevel=0.008)
    box("ToolPouch", (-0.15, -0.06, 0.29), (0.035, 0.05, 0.07), root, navy, bevel=0.01)
    cyl("Screwdriver", (-0.15, -0.06, 0.35), 0.006, 0.07, root, mat("red", (0.85, 0.2, 0.15), 0.5), verts=8)
    cyl("Wrench", (-0.165, -0.04, 0.345), 0.005, 0.08, root, mat("metal", (0.75, 0.76, 0.78), 0.3, 0.9), verts=8)
    t = torus("Tape", (0.165, 0.0, 0.29), 0.045, 0.025, root, grey, rot=(0, math.pi / 2, 0))
    cyl("TapeCore", (0.165, 0.0, 0.29), 0.025, 0.04, root, mat("dark", (0.2, 0.2, 0.22), 0.5), rot=(0, math.pi / 2, 0), verts=24)
    for sx in (-1, 1):
        box("Knee", (sx * 0.068, -0.045, 0.16), (0.07, 0.02, 0.06), root, amber, bevel=0.012)
        box("Shoulder", (sx * 0.12, 0, 0.6), (0.06, 0.12, 0.03), root, grey, bevel=0.01)
        box("Chest", (sx * 0.06, -0.112, 0.53), (0.02, 0.006, 0.07), root, amber, bevel=0.004)


def ground(root):
    blue = mat("vest", BLUE, 0.55)
    box("Vest", (0, 0, 0.455), (0.295, 0.245, 0.29), root, blue, bevel=0.075)
    box("VestOpen", (0, -0.118, 0.47), (0.06, 0.004, 0.25), root, mat("suit", SUIT, 0.6), bevel=0.002)
    box("Badge", (0, -0.125, 0.43), (0.05, 0.004, 0.065), root, mat("badge", (0.97, 0.97, 0.98), 0.4), bevel=0.004)
    for sx in (-1, 1):
        limb("Lanyard", (sx * 0.045, -0.115, 0.6), (0.0, -0.124, 0.465), 0.004, root, mat("lanyard", (0.95, 0.95, 0.97), 0.5))
        cyl("EarCup", (sx * 0.17, 0, HEAD_C.z), 0.04, 0.03, root, mat("cup", BLUE, 0.4), rot=(0, math.pi / 2, 0), verts=24)
    torus("Headband", (0, 0, HEAD_C.z + 0.02), 0.17, 0.008, root, mat("band", (0.15, 0.17, 0.25), 0.4), rot=(math.pi / 2, 0, 0))
    limb("Mic", (-0.17, -0.02, HEAD_C.z - 0.02), (-0.06, -0.15, HEAD_C.z - 0.07), 0.005, root, mat("band", (0.15, 0.17, 0.25), 0.4))
    sphere("MicTip", (-0.055, -0.155, HEAD_C.z - 0.072), (0.012, 0.012, 0.012), root, mat("band", (0.15, 0.17, 0.25), 0.4), 12, 6)
    cyl("Antenna", (0.08, 0.2, 0.68), 0.005, 0.16, root, mat("band", (0.15, 0.17, 0.25), 0.4), verts=8)


def scientist(root):
    coat = mat("labcoat", (0.97, 0.97, 0.98), 0.55)
    blue = mat("labstripe", BLUE, 0.5)
    # the long coat: from the shoulders down past the knees, a little flared
    cyl("Coat", (0, 0, 0.37), 0.145, 0.5, root, coat, verts=40, r2=0.175)
    box("Stripe", (0, -0.165, 0.37), (0.055, 0.01, 0.5), root, blue, bevel=0.004)
    box("StripeLow", (0, -0.172, 0.24), (0.055, 0.01, 0.24), root, blue, bevel=0.004)
    for sx in (-1, 1):
        box("Lapel", (sx * 0.05, -0.135, 0.56), (0.04, 0.01, 0.1), root, coat, bevel=0.005, rot=(0, 0, sx * 0.4))
        box("Pocket", (sx * 0.1, -0.14, 0.33), (0.05, 0.01, 0.05), root, coat, bevel=0.004)
    # the legs show below the coat in her own fur
    for sx in (-1, 1):
        limb("Shin", (sx * 0.07, 0, 0.13), (sx * 0.072, 0, 0.07), 0.053, root, mat("legfur", BROWN, 0.8))


def build(name, spec, x):
    root = bpy.data.objects.new("crew_" + name, None)
    bpy.context.collection.objects.link(root)
    head(root, spec, name)
    body(root, spec["outfit"])
    {"engineer": engineer, "ground": ground, "scientist": scientist}[spec["outfit"]](root)
    for o in root.children:
        apply_all(o)
        # stubbier legs, as the reference: below the hips (z 0.29) the figure is squashed to 0.22, the rest comes down
        for v in o.data.vertices:
            z = v.co.z
            v.co.z = z * (0.22 / 0.29) if z <= 0.29 else z - 0.07
    root.location = (x, 0, 0)
    return root


def export(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in root.children:
        o.select_set(True)
    loc = root.location.copy()
    root.location = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    root.location = loc


def render(path):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 48
    scn.cycles.use_denoising = True
    scn.render.resolution_x = 1500
    scn.render.resolution_y = 560
    scn.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.12, 0.13, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.3
    for loc, energy in (((-2, -3, 3), 170), ((2.5, -2, 1.5), 60), ((0, 3, 2), 90)):
        bpy.ops.object.light_add(type="AREA", location=loc)
        lt = bpy.context.object
        lt.data.energy = energy
        lt.data.size = 2.5
        lt.rotation_euler = (Vector((0, 0, 0.5)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(0.0, -6.2, 0.45))
    cam = bpy.context.object
    cam.data.lens = 70
    cam.rotation_euler = (Vector((0, 0, 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    roots = []
    for i, n in enumerate(CREW):
        r = build(n, CREW[n], (i - 1) * 0.95)
        roots.append(r)
        export(r, os.path.join(OUT, "crew_%s_tpose.glb" % n))
        print("wrote", n)
    if RENDER:
        render(os.path.join(OUT, "crew_tpose.png"))
        print("rendered")


main()
