"""The cuy crew of Farpoint HORIZON (issue #44): four cuy astronauts (Andean guinea pigs), our own design, built by
this script in Blender so there is no AI image and no outside model. Stylized and deadpan, next to the game's
documentary-real craft (docs/design/criteria.md: characters may be stylized, real objects never).

  - an upright cuy with no neck, a little boxy (a rounded block, not a ball), fur in three colours as vertex colours;
  - a face of its own for each: eye size and lids, brows, mouth, so each reads as a character at a glance;
  - a short space suit that follows the body, in the game's palette (white fabric, horizon blue, sunrise amber),
    a backpack, sleeves, boots, and a clear bubble helmet so the face reads.

Run: blender -b --factory-startup --python assets/source/crew_cuy.py -- <out_dir> [render]
Writes <out_dir>/crew_<name>.glb for each cuy, and with "render" a line-up picture crew_lineup.png.
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

# The palette of the game (scripts/ui/kit.gd): horizon blue, sunrise amber, navy neutrals.
SUIT = (0.9, 0.91, 0.93)
BLUE = (0.18, 0.42, 0.9)
AMBER = (1.0, 0.55, 0.14)
NAVY = (0.03, 0.05, 0.1)
# Cuy coats: cream, white, ginger, chocolate, slate.
WHITE = (0.93, 0.9, 0.84)
CREAM = (0.95, 0.83, 0.62)
GINGER = (0.85, 0.42, 0.12)
CHOC = (0.28, 0.16, 0.09)
SLATE = (0.42, 0.42, 0.44)
PINK = (0.95, 0.6, 0.62)

## Each cuy. Body: half-width W, half-depth D, half-height H (metres; a game size, characters are not to scale),
## `box` how boxy (2 a ball, 4 a soft block). Patches: (centre as fractions of W, D, 2H; radius; colour).
## Face: eye size, lid (0 open, 1 shut), brows (left and right tilt, radians; + raises the outer end), height of the
## brows over the eyes, mouth ("flat", "o", "smirk", "y").
CREW = {
    # the engineer: short and stocky, unimpressed, one brow up
    "rumi": {"W": 0.37, "D": 0.33, "H": 0.39, "box": 3.6, "coat": WHITE,
             "patches": [((0.45, -1.0, 0.78), 0.17, GINGER), ((-0.45, -1.0, 0.8), 0.13, CHOC), ((0.0, 1.0, 0.75), 0.32, GINGER)],
             "ears": (CHOC, GINGER), "stripe": AMBER, "prop": "wrench",
             "eye": 0.036, "lid": 0.55, "brows": (0.0, 0.42), "brow_up": 0.05, "mouth": "flat"},
    # the scientist: tall and slim, wide-eyed, both brows up, a small "o"
    "killa": {"W": 0.3, "D": 0.29, "H": 0.47, "box": 3.2, "coat": CHOC,
              "patches": [((0.0, -1.0, 0.62), 0.13, WHITE), ((0.0, -1.0, 0.88), 0.08, WHITE)],
              "ears": (CHOC, CHOC), "stripe": BLUE, "prop": "flask",
              "eye": 0.046, "lid": 0.0, "brows": (0.25, 0.25), "brow_up": 0.075, "mouth": "o"},
    # the pilot: sure of itself, eyes narrowed, brows slanted in, a half smile
    "inti": {"W": 0.34, "D": 0.31, "H": 0.43, "box": 3.8, "coat": GINGER,
             "patches": [((0.0, -1.0, 0.6), 0.12, CREAM), ((0.48, -1.0, 0.82), 0.1, CHOC)],
             "ears": (GINGER, CHOC), "stripe": AMBER, "prop": "goggles",
             "eye": 0.036, "lid": 0.45, "brows": (-0.3, -0.3), "brow_up": 0.04, "mouth": "smirk"},
    # ground control: calm, nearly asleep, the classic cuy "y" mouth
    "wayra": {"W": 0.33, "D": 0.31, "H": 0.42, "box": 3.0, "coat": WHITE,
              "patches": [((-0.45, -1.0, 0.8), 0.15, SLATE), ((0.35, 1.0, 0.85), 0.22, SLATE), ((0.62, -0.6, 0.9), 0.09, CHOC)],
              "ears": (SLATE, WHITE), "stripe": BLUE, "prop": "headset",
              "eye": 0.034, "lid": 0.72, "brows": (-0.08, -0.08), "brow_up": 0.045, "mouth": "y"},
}


# ----------------------------------------------------------------------------------------------------------- basics
def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


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


def add(obj, parent, material):
    obj.data.materials.append(material)
    obj.parent = parent
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def sphere(name, loc, scale, parent, material, seg=48, ring=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return add(o, parent, material)


def cyl(name, loc, r, depth, parent, material, rot=(0, 0, 0), verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return add(o, parent, material)


def torus(name, loc, major, minor, parent, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=48, minor_segments=12)
    o = bpy.context.object
    o.name = name
    return add(o, parent, material)


def apply_all(o):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    o.select_set(False)


# ----------------------------------------------------------------------------------------------------------- shapes
def block(name, parent, material, W, D, H, box, grow=0.0, seg=96, ring=64):
    """A rounded block standing on z = 0: a superellipsoid of exponent `box` (2 a ball, higher a softer block), sized
    W x D x H (half sizes), its rings horizontal so a stripe or a collar cut from it has a straight edge; grown by
    `grow` along its normals (a suit over the body)."""
    e = 2.0 / box

    def spow(c, k):
        return math.copysign(abs(c) ** k, c)

    bm = bmesh.new()
    rows = []
    for i in range(1, ring):
        th = -math.pi / 2 + math.pi * i / ring
        row = []
        for j in range(seg):
            ph = -math.pi + 2.0 * math.pi * j / seg
            x = spow(math.cos(th), e) * spow(math.cos(ph), e)
            y = spow(math.cos(th), e) * spow(math.sin(ph), e)
            z = spow(math.sin(th), e)
            taper = 1.0 - 0.1 * max(0.0, z)   # a little narrower at the top: a cuy's head is the top of its body
            row.append(bm.verts.new((x * W * taper, y * D * taper, (z + 1.0) * H)))
        rows.append(row)
    bottom = bm.verts.new((0.0, 0.0, 0.0))
    top = bm.verts.new((0.0, 0.0, 2.0 * H))
    for a, b in zip(rows, rows[1:]):
        for j in range(seg):
            bm.faces.new((a[j], a[(j + 1) % seg], b[(j + 1) % seg], b[j]))
    for j in range(seg):
        bm.faces.new((rows[0][(j + 1) % seg], rows[0][j], bottom))
        bm.faces.new((rows[-1][j], rows[-1][(j + 1) % seg], top))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    if grow:
        for v in bm.verts:
            v.co += v.normal * grow
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return add(o, parent, material)


def band(name, src, parent, material, z0, z1, lift):
    """A strip of a surface between heights z0 and z1, lifted off it: a stripe or a collar that follows the shape."""
    o = src.copy()
    o.data = src.data.copy()
    o.name = name
    o.data.materials.clear()
    o.data.materials.append(material)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not (z0 <= f.calc_center_median().z <= z1)], context="FACES")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * lift
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=-0.01)
    bm.to_mesh(o.data)
    bm.free()
    return o


# ----------------------------------------------------------------------------------------------------------- the cuy
def coat_mat(name):
    """The fur: the body's own vertex colours (the coat and its patches), exported with the model."""
    m = bpy.data.materials.new("coat_" + name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.85
    b.inputs["Sheen Weight"].default_value = 0.6   # the soft glow of fur at the edges
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    return m


def paint(o, spec):
    """Colours each vertex: the coat, or the patch it falls in (a ragged, slightly soft edge)."""
    W, D, H = spec["W"], spec["D"], spec["H"]
    me = o.data
    ca = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="POINT")
    for v in me.vertices:
        p = v.co
        col = Vector(spec["coat"])
        for (c, r, pc) in spec["patches"]:
            cc = Vector((c[0] * W, c[1] * D, c[2] * 2.0 * H))
            d = (p - cc).length / r + 0.22 * noise.noise(p * 7.0 + cc * 5.0)
            k = max(0.0, min(1.0, (1.0 - d) / 0.12))
            col = col.lerp(Vector(pc), k)
        ca.data[v.index].color = (col.x, col.y, col.z, 1.0)


def face(parent, spec, coat_lid):
    """The face on the front of the body: eyes (with a lid at `lid`), brows, nose, mouth, whiskers."""
    W, D, H = spec["W"], spec["D"], spec["H"]
    y = -D * 0.9 - 0.012                # the front face (flat-ish on a boxy body)
    ez = 2.0 * H * 0.76                 # eye height
    ex = W * 0.4
    e = spec["eye"]
    line = mat("line", (0.08, 0.05, 0.05), 0.6)
    for side, sx in enumerate((-1, 1)):
        sphere("Eye", (sx * ex, y, ez), (e, e * 0.75, e * 1.1), parent, mat("eye", (0.02, 0.02, 0.03), 0.15), 24, 12)
        sphere("Glint", (sx * ex + e * 0.3, y - e * 0.7, ez + e * 0.35), (e * 0.24, e * 0.15, e * 0.24), parent,
               mat("glint", (1, 1, 1), 0.2, emit=2.0), 12, 6)
        if spec["lid"] > 0.0:
            # the lid covers the top of the eye down to `lid` of its height
            lid = sphere("Lid", (sx * ex, y - 0.002, ez + e * 1.1 * (1.0 - spec["lid"])), (e * 1.2, e * 0.85, e * 0.9), parent, coat_lid, 24, 12)
            bm = bmesh.new()
            bm.from_mesh(lid.data)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.0], context="VERTS")
            bm.to_mesh(lid.data)
            bm.free()
        # the brow: a short stroke above the eye, tilted (its outer end up when the tilt is positive)
        tilt = spec["brows"][side]
        b = cyl("Brow", (sx * ex, y - 0.004, ez + e * 1.1 + spec["brow_up"]), 0.009, e * 2.0, parent, line, rot=(0.0, math.pi / 2, 0.0), verts=8)
        b.rotation_euler = (0.0, math.pi / 2 - sx * tilt, 0.0)
    nz = 2.0 * H * 0.62
    sphere("Nose", (0, y - 0.01, nz), (0.034, 0.022, 0.023), parent, mat("nose", PINK, 0.5), 24, 12)
    mz = nz - 0.045
    m = spec["mouth"]
    if m == "flat":
        cyl("Mouth", (0, y - 0.004, mz), 0.005, 0.05, parent, line, rot=(0, math.pi / 2, 0), verts=6)
    elif m == "o":
        torus("Mouth", (0, y - 0.004, mz - 0.006), 0.014, 0.0045, parent, line, rot=(math.pi / 2, 0, 0))
    elif m == "smirk":
        s = cyl("Mouth", (0.012, y - 0.004, mz + 0.004), 0.005, 0.05, parent, line, rot=(0, math.pi / 2, 0), verts=6)
        s.rotation_euler = (0.0, math.pi / 2 - 0.35, 0.0)
    else:   # "y": the cuy's own mouth
        cyl("Mouth", (0, y - 0.004, mz + 0.012), 0.004, 0.03, parent, line, verts=6)
        for sx in (-1, 1):
            cyl("MouthL", (sx * 0.012, y - 0.004, mz - 0.008), 0.004, 0.03, parent, line, rot=(0.0, sx * 0.9, 0.0), verts=6)
    for sx in (-1, 1):
        for k, ang in enumerate((-0.16, 0.0, 0.18)):
            w = cyl("Whisker", (sx * (W * 0.62), y + 0.01, nz - 0.02 + k * 0.022), 0.0025, 0.2, parent, line, verts=6)
            w.rotation_euler = (0.0, math.pi / 2, sx * ang)


def ears(parent, spec, outer, inner):
    W, D, H = spec["W"], spec["D"], spec["H"]
    for sx in (-1, 1):
        at = (sx * W * 0.72, -D * 0.1, 2.0 * H * 0.95)
        e = sphere("Ear", at, (0.1, 0.035, 0.075), parent, outer, 24, 12)
        e.rotation_euler = (0.2, sx * 0.5, sx * 0.55)
        i = sphere("EarIn", (at[0] - sx * 0.005, at[1] - 0.02, at[2] - 0.005), (0.07, 0.02, 0.05), parent, inner, 24, 12)
        i.rotation_euler = (0.2, sx * 0.5, sx * 0.55)


def suit(parent, spec):
    """The space suit: the lower body in white fabric that follows the body, a stripe and a collar that follow it too,
    a chest panel with lights, a backpack, sleeves with gloves, boots, and the bubble helmet."""
    W, D, H, box = spec["W"], spec["D"], spec["H"], spec["box"]
    fab = mat("suit", SUIT, 0.75)
    st = mat("stripe_%d" % int(spec["stripe"][2] * 100), spec["stripe"], 0.5)
    top = 2.0 * H * 0.52      # the suit reaches up to here; the face shows above it
    o = block("Suit", parent, fab, W, D, H, box, grow=0.025)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > top], context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    band("Stripe", o, parent, st, 2.0 * H * 0.18, 2.0 * H * 0.24, 0.006)
    band("Collar", o, parent, mat("ring", (0.75, 0.77, 0.8), 0.3, 0.8), top - 0.08, top, 0.016)
    # chest panel with three small lights
    pz = 2.0 * H * 0.36
    p = cyl("Panel", (0, -D * 0.98 - 0.02, pz), 0.08, 0.03, parent, mat("panel", NAVY, 0.4), rot=(math.pi / 2, 0, 0), verts=6)
    p.scale = (1.0, 0.65, 1.0)
    for k, c in enumerate((BLUE, AMBER, (0.6, 0.9, 1.0))):
        sphere("Light", (-0.032 + k * 0.032, -D * 0.98 - 0.04, pz), (0.011, 0.008, 0.011), parent, mat("led%d" % k, c, 0.3, emit=3.0), 12, 6)
    # backpack
    b = cyl("Pack", (0, D + 0.07, 2.0 * H * 0.42), W * 0.5, 0.14, parent, fab, rot=(math.pi / 2, 0, 0), verts=24)
    b.scale = (1.0, 1.4, 1.0)
    cyl("PackStripe", (0, D + 0.15, 2.0 * H * 0.42), W * 0.34, 0.02, parent, st, rot=(math.pi / 2, 0, 0), verts=24)
    # sleeves hanging at the sides, gloves, boots
    for sx in (-1, 1):
        a = sphere("Arm", (sx * (W + 0.03), -0.02, 2.0 * H * 0.33), (0.06, 0.06, 0.13), parent, fab, 24, 12)
        a.rotation_euler = (0.0, sx * 0.18, 0.0)
        sphere("Glove", (sx * (W + 0.05), -0.04, 2.0 * H * 0.2), (0.058, 0.058, 0.058), parent, mat("glove", (0.95, 0.95, 0.96), 0.5), 24, 12)
        sphere("Boot", (sx * W * 0.45, -0.06, 0.035), (0.1, 0.13, 0.06), parent, mat("boot", (0.22, 0.23, 0.26), 0.6), 24, 12)
    # the bubble helmet around the head
    hz = 2.0 * H * 0.78
    hr = max(W * 1.18, H * 0.66)
    sphere("Helmet", (0, -0.01, hz), (hr, hr, hr * 0.97), parent, mat("glass", (0.85, 0.93, 1.0), 0.02, alpha=0.18), 48, 24)
    return hz, hr


def props(parent, spec, hz, hr):
    W, D, H = spec["W"], spec["D"], spec["H"]
    m = mat("prop_metal", (0.75, 0.76, 0.78), 0.35, 0.9)
    gz = 2.0 * H * 0.2
    kind = spec["prop"]
    if kind == "wrench":
        cyl("Wrench", (W + 0.1, -0.06, gz + 0.1), 0.016, 0.24, parent, m, verts=12)
        torus("WrenchHead", (W + 0.1, -0.06, gz + 0.23), 0.035, 0.014, parent, m, rot=(math.pi / 2, 0, 0))
    elif kind == "flask":
        g = mat("flaskglass", (0.6, 1.0, 0.85), 0.05, alpha=0.4)
        sphere("Flask", (-(W + 0.1), -0.08, gz + 0.04), (0.05, 0.05, 0.06), parent, g, 24, 12)
        cyl("FlaskNeck", (-(W + 0.1), -0.08, gz + 0.11), 0.016, 0.06, parent, g, verts=12)
    elif kind == "goggles":
        for sx in (-1, 1):
            torus("Goggle", (sx * W * 0.32, -D * 0.6, 2.0 * H * 0.98), 0.05, 0.013, parent, mat("gogframe", (0.15, 0.15, 0.16), 0.4), rot=(1.1, 0, 0))
            sphere("GoggleLens", (sx * W * 0.32, -D * 0.6 - 0.005, 2.0 * H * 0.98), (0.045, 0.012, 0.045), parent, mat("goglens", AMBER, 0.1, emit=0.3), 16, 8)
    elif kind == "headset":
        band_m = mat("band", (0.15, 0.15, 0.16), 0.4)
        r = W * 0.95
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.014, location=(0, 0.02, 2.0 * H * 0.8),
                                         rotation=(math.pi / 2, 0, 0), major_segments=48, minor_segments=10)
        hb = bpy.context.object
        hb.name = "Headband"
        add(hb, parent, band_m)
        bm = bmesh.new()   # only its upper half, over the crown from ear to ear
        bm.from_mesh(hb.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.02], context="VERTS")
        bm.to_mesh(hb.data)
        bm.free()
        for sx in (-1, 1):
            cyl("EarCup", (sx * r, 0.02, 2.0 * H * 0.8), 0.06, 0.04, parent, mat("cup", BLUE, 0.4), rot=(0, math.pi / 2, 0), verts=24)
        cyl("Mic", (-r * 0.8, -D * 0.6, 2.0 * H * 0.7), 0.008, 0.2, parent, band_m, rot=(0.0, 0.0, -0.95), verts=8)
        sphere("MicTip", (-r * 0.55, -D * 0.85, 2.0 * H * 0.7), (0.022, 0.022, 0.022), parent, mat("cup", BLUE, 0.4), 12, 6)


def build(name, spec, x):
    root = bpy.data.objects.new("crew_" + name, None)
    bpy.context.collection.objects.link(root)
    body = block("Body", root, coat_mat(name), spec["W"], spec["D"], spec["H"], spec["box"], seg=160, ring=110)   # dense: the fur patches are vertex colours
    bm = bmesh.new()   # a little unevenness, as fur
    bm.from_mesh(body.data)
    for v in bm.verts:
        v.co += v.normal * 0.01 * noise.noise(v.co * 6.0)
    bm.to_mesh(body.data)
    bm.free()
    paint(body, spec)
    face(root, spec, mat("lid_" + name, spec["coat"], 0.85))
    ears(root, spec, mat("ear_" + name, spec["ears"][0], 0.8), mat("earin", PINK, 0.7))
    hz, hr = suit(root, spec)
    props(root, spec, hz, hr)
    for o in root.children:
        apply_all(o)
    root.location = (x, 0, 0)
    return root


def export(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in root.children:
        o.select_set(True)
    loc = root.location.copy()
    rot = root.rotation_euler.copy()
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    root.location = loc
    root.rotation_euler = rot


def render(path):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 48
    scn.cycles.use_denoising = True
    scn.render.resolution_x = 1600
    scn.render.resolution_y = 800
    world = bpy.data.worlds.new("w")
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.025, 0.05, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    bpy.context.object.data.materials.append(mat("ground", (0.32, 0.31, 0.33), 0.95))
    scn.view_settings.view_transform = "Standard"
    for loc, energy, col in (((-3, -4, 5), 420, (1.0, 0.94, 0.86)), ((4, -2, 2), 110, (0.6, 0.75, 1.0)), ((0, 4, 3), 260, (1.0, 0.8, 0.6))):
        bpy.ops.object.light_add(type="AREA", location=loc)
        lt = bpy.context.object
        lt.data.energy = energy
        lt.data.size = 3
        lt.data.color = col
        lt.rotation_euler = (Vector((0, 0, 0.5)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(0.0, -6.4, 1.3))
    cam = bpy.context.object
    cam.data.lens = 50
    cam.rotation_euler = (Vector((0, 0, 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    clear()
    names = list(CREW)
    roots = []
    for i, n in enumerate(names):
        r = build(n, CREW[n], (i - 1.5) * 1.15)
        roots.append(r)
        export(r, os.path.join(OUT, "crew_%s.glb" % n))
        print("wrote", "crew_%s.glb" % n)
    if RENDER:
        for r in roots:
            r.rotation_euler = (0, 0, 0.2 if r.location.x < 0 else -0.2)
        render(os.path.join(OUT, "crew_lineup.png"))
        print("rendered crew_lineup.png")


main()
