"""Three generic launchers at real proportions, exported to glTF for the launch screen.

Run (Blender 4.2 or newer, background):
    blender -b --factory-startup --python assets/source/launchers.py -- [--render <dir>]

Writes assets/models/launcher_light.glb, launcher_medium.glb and launcher_heavy.glb. With --render, also writes a
lineup PNG to <dir> for a visual check.

They are generic: no logos, names, flags or mission marks. Proportions follow published figures, rounded:
- Light, Electron-type: 18 m tall, 1.2 m across, black carbon composite, nine small engines [S13].
- Medium, Falcon 9-type: 70 m tall, 3.7 m across, 5.2 m fairing; nine engines in an octaweb, four grid fins, four
  landing legs, black interstage [S14].
- Heavy, Falcon Heavy-type: three medium first stages side by side, 70 m tall, 12.2 m across [S15].
Section lengths inside each vehicle (tank, interstage, second stage) are our estimates from the published total
heights: simplified.

Units are metres; Blender +Z (up) becomes Godot +Y. Origin: the base of the first-stage tank on the rocket's axis,
engines below it (as the old primitive rocket). Each file's root node carries the vehicle; the launch screen scales it.
No invented markings: colours and details follow the real vehicles (white paint, black composite and interstage,
heat-darkened nozzles, the cable raceway along the Falcon 9-type stages).
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "models"))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = argv[argv.index("--render") + 1] if "--render" in argv else None


def material(name, rgb, metal=0.0, rough=0.5):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


def mats():
    return {
        "white": material("Painted white", (0.86, 0.86, 0.84), 0.0, 0.42),
        "carbon": material("Carbon composite", (0.025, 0.025, 0.028), 0.15, 0.38),
        "black": material("Black interstage", (0.03, 0.03, 0.032), 0.0, 0.6),
        "soot": material("Engine soot", (0.06, 0.055, 0.05), 0.4, 0.7),
        "nozzle": material("Nozzle, heat-darkened", (0.16, 0.15, 0.14), 0.85, 0.5),
        "titanium": material("Titanium", (0.36, 0.35, 0.34), 1.0, 0.5),
        "leg": material("Leg composite", (0.09, 0.09, 0.1), 0.2, 0.5),
        "steel": material("Steel", (0.62, 0.62, 0.62), 1.0, 0.35),
        "raceway": material("Raceway", (0.30, 0.30, 0.31), 0.2, 0.55),
    }


# ---------------------------------------------------------------- geometry helpers
def link(ob, parent):
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    return ob


def lathe(name, profile, mat, parent, segs=48, smooth=True, cap_top=True, cap_bottom=True):
    """A solid of revolution about Z from a list of (radius, z) points, bottom to top."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom and profile[0][0] > 1e-6:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 1e-6:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = smooth and len(p.vertices) == 4  # caps stay flat, or their normals bend the sides
    ob = bpy.data.objects.new(name, me)
    return link(ob, parent)


def box(name, size, center, mat, parent, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.location = center
    ob.rotation_euler = rot
    return link(ob, parent)


def tube(name, r, z0, z1, mat, parent, segs=48):
    return lathe(name, [(r, z0), (r, z1)], mat, parent, segs)


def engine(name, r_throat, r_exit, length, pos, parent, m, segs=24):
    """A bell nozzle hanging below pos."""
    x, y, z = pos
    prof = [(r_exit, -length), (r_exit * 0.86, -length * 0.62), (r_exit * 0.62, -length * 0.3),
            (r_throat, -length * 0.08), (r_throat * 1.5, 0.0)]
    ob = lathe(name, prof, m["nozzle"], parent, segs, cap_bottom=False)
    ob.location = (x, y, z)
    # soot ring at the lip
    lip = lathe(name + "_lip", [(r_exit * 1.02, -length - 0.01), (r_exit * 1.02, -length + length * 0.07)],
                m["soot"], parent, segs, cap_top=False, cap_bottom=False)
    lip.location = (x, y, z)
    return ob


def octaweb(prefix, R, z, parent, m, r_exit):
    """Nine engines: one in the centre, eight around it, as on the Falcon 9 first stage."""
    engine(prefix + "_e0", r_exit * 0.35, r_exit, r_exit * 2.6, (0, 0, z), parent, m)
    for i in range(8):
        a = 2 * math.pi * i / 8
        rr = R * 0.66
        engine(f"{prefix}_e{i + 1}", r_exit * 0.35, r_exit, r_exit * 2.6, (rr * math.cos(a), rr * math.sin(a), z), parent, m)
    # thrust section skirt
    lathe(prefix + "_skirt", [(R * 0.97, z - 0.35), (R, z + 0.3)], m["soot"], parent, 48, cap_top=False)
    lathe(prefix + "_base", [(R * 0.97, z - 0.3), (0.0001, z - 0.3)], m["soot"], parent, 48)


def grid_fins(prefix, R, z, parent, m, size):
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        holder = bpy.data.objects.new(f"{prefix}_fin{i}", None)
        link(holder, parent)
        holder.location = (math.cos(a) * (R + size * 0.5), math.sin(a) * (R + size * 0.5), z)
        holder.rotation_euler = (0, 0, a)
        # a lattice: outer frame plus bars, flat against the body (stowed)
        t = size * 0.05
        box(f"{prefix}_fin{i}_frame_a", (size, t, size * 0.08), (0, 0, size * 0.46), m["titanium"], holder)
        box(f"{prefix}_fin{i}_frame_b", (size, t, size * 0.08), (0, 0, -size * 0.46), m["titanium"], holder)
        box(f"{prefix}_fin{i}_frame_c", (size * 0.08, t, size), (size * 0.46, 0, 0), m["titanium"], holder)
        box(f"{prefix}_fin{i}_frame_d", (size * 0.08, t, size), (-size * 0.46, 0, 0), m["titanium"], holder)
        for k in range(-3, 4):
            box(f"{prefix}_fin{i}_bar{k}a", (size * 1.25, t * 0.6, size * 0.035), (0, 0, 0), m["titanium"], holder,
                (0, math.radians(45), 0)).location = (k * size * 0.12, 0, 0)
            box(f"{prefix}_fin{i}_bar{k}b", (size * 1.25, t * 0.6, size * 0.035), (0, 0, 0), m["titanium"], holder,
                (0, math.radians(-45), 0)).location = (k * size * 0.12, 0, 0)
        # clip the lattice to the frame by scaling the bars into it (cheap and reads well at distance)
        for ch in holder.children:
            if "_bar" in ch.name:
                ch.scale = (0.62, 1, 1)


def landing_legs(prefix, R, z, length, parent, m):
    for i in range(4):
        a = i * math.pi / 2
        holder = bpy.data.objects.new(f"{prefix}_leg{i}", None)
        link(holder, parent)
        holder.location = (math.cos(a) * (R + 0.07), math.sin(a) * (R + 0.07), z)
        holder.rotation_euler = (0, 0, a)
        # stowed leg: a long carbon panel with a tapered tip, folded up along the body
        w = R * 0.42
        bm = bmesh.new()
        prof = [(-w / 2, 0), (w / 2, 0), (w * 0.32, length), (-w * 0.32, length)]
        top = [bm.verts.new((0.06, x, y)) for x, y in prof]
        bot = [bm.verts.new((-0.06, x, y)) for x, y in prof]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((bot[k], bot[j], top[j], top[k]))
        me = bpy.data.meshes.new(f"{prefix}_leg{i}_panel")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(m["leg"])
        link(bpy.data.objects.new(me.name, me), holder)
        box(f"{prefix}_leg{i}_foot", (0.2, w * 1.05, 0.3), (0.02, 0, 0.1), m["titanium"], holder)


def fairing(prefix, R, z, cyl_len, nose_len, parent, m, mat_key="white", boat_from=None):
    prof = []
    if boat_from:  # boat-tail from a narrower second stage up to the fairing radius
        prof += [(boat_from, z - 0.9)]
    prof += [(R, z), (R, z + cyl_len)]
    prof += [(R * math.cos(math.asin(i / 12)), z + cyl_len + nose_len * i / 12) for i in range(1, 12)]
    prof += [(0.0, z + cyl_len + nose_len)]
    lathe(prefix + "_fairing", prof, m[mat_key], parent, 64)
    # the separation seam, a thin dark line around and along the fairing
    lathe(prefix + "_seam", [(R * 1.003, z + 0.05), (R * 1.003, z + 0.12)], m["black"], parent, 64, cap_top=False, cap_bottom=False)
    for s in (-1, 1):
        box(f"{prefix}_seamv{s}", (0.04, 0.03, cyl_len), (0, s * R * 1.002, z + cyl_len / 2), m["black"], parent)


def raceway(name, R, z0, z1, parent, m, angle=-math.pi / 2):
    """The cable raceway that runs along a Falcon 9-type stage: a low, flat-topped fairing on one side."""
    w, d = 0.22, 0.09
    ob = box(name, (d, w, z1 - z0), (0, 0, 0), m["raceway"], parent)
    ob.location = (math.cos(angle) * (R + d / 2 - 0.01), math.sin(angle) * (R + d / 2 - 0.01), (z0 + z1) / 2)
    ob.rotation_euler = (0, 0, angle)
    return ob


# ---------------------------------------------------------------- vehicles
def medium_core(prefix, parent, m, with_upper=True, x=0.0, nose=False):
    """A Falcon 9-type first stage (and optionally the second stage and fairing) with its axis at (x, 0)."""
    R = 3.7 / 2
    core = bpy.data.objects.new(prefix, None)
    link(core, parent)
    core.location = (x, 0, 0)
    S1 = 41.2        # first stage tank, to the interstage (estimate from the 70 m total)
    INTER = 6.7      # interstage, black
    tube(prefix + "_s1", R, 0, S1, m["white"], core, 64)
    # sooty band above the engines, as on a flown booster
    tube(prefix + "_s1_band", R * 1.002, 0.0, 2.2, m["soot"], core, 64)
    raceway(prefix + "_s1_raceway", R, 2.2, S1, core, m)
    octaweb(prefix, R, 0.0, core, m, r_exit=0.46)
    landing_legs(prefix, R, -0.6, 9.5, core, m)
    if with_upper:
        tube(prefix + "_inter", R * 1.004, S1, S1 + INTER, m["black"], core, 64)
        grid_fins(prefix, R, S1 + INTER - 1.3, core, m, 1.4)
        S2 = 9.0
        tube(prefix + "_s2", R, S1 + INTER, S1 + INTER + S2, m["white"], core, 64)
        raceway(prefix + "_s2_raceway", R, S1 + INTER, S1 + INTER + S2, core, m)
        fairing(prefix, 5.2 / 2, S1 + INTER + S2 + 0.9, 6.6, 6.5, core, m, boat_from=R)
        return core, S1 + INTER + S2 + 0.9 + 6.6 + 6.5
    if nose:  # side booster: a black interstage-like ring and a nose cone
        tube(prefix + "_inter", R * 1.004, S1, S1 + 2.5, m["black"], core, 64)
        grid_fins(prefix, R, S1 + 1.3, core, m, 1.4)
        prof = [(R, S1 + 2.5)] + [(R * math.cos(math.asin(i / 12)), S1 + 2.5 + 5.0 * i / 12) for i in range(1, 12)] + [(0.0, S1 + 7.5)]
        lathe(prefix + "_nose", prof, m["white"], core, 64)
    return core, S1


def build_medium(m):
    root = bpy.data.objects.new("LauncherMedium", None)
    bpy.context.scene.collection.objects.link(root)
    core, top = medium_core("Core", root, m)
    return root, top


def build_heavy(m):
    root = bpy.data.objects.new("LauncherHeavy", None)
    bpy.context.scene.collection.objects.link(root)
    core, top = medium_core("Core", root, m)
    spacing = (12.2 - 3.7) / 2  # centre to centre, from the 12.2 m overall width
    for s, name in ((-1, "BoosterA"), (1, "BoosterB")):
        b, _ = medium_core(name, root, m, with_upper=False, x=s * spacing, nose=True)
        # attach struts between core and booster
        for zz in (2.5, 38.0):
            box(f"{name}_strut{zz}", (spacing - 3.7, 0.5, 0.5), (s * spacing / 2, 0, zz), m["steel"], root)
    return root, top


def build_light(m):
    """Electron-type: a slim black composite rocket with nine small engines and a white-tipped fairing."""
    root = bpy.data.objects.new("LauncherLight", None)
    bpy.context.scene.collection.objects.link(root)
    R = 1.2 / 2
    S1, INTER, S2 = 12.1, 0.9, 2.4   # estimates from the 18 m total
    tube("s1", R, 0, S1, m["carbon"], root, 48)
    tube("inter", R * 1.004, S1, S1 + INTER, m["soot"], root, 48)
    tube("s2", R, S1 + INTER, S1 + INTER + S2, m["carbon"], root, 48)
    # nine engines in a ring of eight plus one, small
    engine("e0", 0.06, 0.15, 0.42, (0, 0, 0), root, m, 16)
    for i in range(8):
        a = 2 * math.pi * i / 8
        engine(f"e{i + 1}", 0.06, 0.15, 0.42, (0.38 * math.cos(a), 0.38 * math.sin(a), 0), root, m, 16)
    lathe("skirt", [(R * 0.97, -0.12), (R, 0.15)], m["soot"], root, 48, cap_top=False)
    lathe("base", [(R * 0.97, -0.1), (0.0001, -0.1)], m["soot"], root, 48)
    z = S1 + INTER + S2
    fairing("light", R, z, 1.1, 1.4, root, m, "carbon")
    return root, z + 1.1 + 1.4


def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def export(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for ob in root.children_recursive:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_animations=False, export_materials="EXPORT",
                              export_cameras=False, export_lights=False)
    print("EXPORTED", path, os.path.getsize(path), "bytes")


bpy.ops.wm.read_factory_settings(use_empty=True)
M = mats()
heights = {}
built = {}
for key, fn in (("light", build_light), ("medium", build_medium), ("heavy", build_heavy)):
    clear_scene()
    root, top = fn(M)
    heights[key] = top
    export(root, os.path.join(OUT_DIR, f"launcher_{key}.glb"))
print("HEIGHTS", {k: round(v, 2) for k, v in heights.items()})

if RENDER_DIR:
    clear_scene()
    scn = bpy.context.scene
    for i, (key, fn) in enumerate((("light", build_light), ("medium", build_medium), ("heavy", build_heavy))):
        root, _ = fn(M)
        root.location = ((i - 1) * 22.0, 0, 0)
    world = bpy.data.worlds.new("Sky")
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.55, 0.75, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.data.color = 4.0, (1.0, 0.95, 0.88)
    sun.rotation_euler = (math.radians(55), 0, math.radians(30))
    scn.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.lens = 35
    cam.location = (14, -95, 30)
    cam.rotation_euler = (Vector((0, 0, 33)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 32
    scn.cycles.use_denoising = True
    scn.render.resolution_x, scn.render.resolution_y = 1200, 1000
    scn.view_settings.view_transform = "AgX"
    scn.render.filepath = os.path.join(RENDER_DIR, "launchers.png")
    bpy.ops.render.render(write_still=True)
    # close-up of the medium launcher's base: engines, legs
    cam.location = (9, -13, 2.0)
    cam.rotation_euler = (Vector((0, 0, 4.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = os.path.join(RENDER_DIR, "medium_base.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", RENDER_DIR)
