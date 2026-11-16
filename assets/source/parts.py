"""Rocket parts that snap together in the builder, exported one glTF per part to assets/parts/.

Run (Blender 4.2 or newer, background):
    blender -b --factory-startup --python assets/source/parts.py -- [--render <dir>]

Downloaded models come first; we model only what no source offers with a usable license (searched 2026-11-14):
- Engines from Sketchfab, CC BY (credited in docs/sources.md): "Merlin Engine" by hoahluke [S-merlin-model], "Merlin 1D Vacuum"
  by MartianDays [S-mvac-model], "Rocket Nozzle Part" by Zachary [S-nozzle-model]. Copies in assets/source/vendor/.
- Side booster from NASA 3D Resources, public domain: the Space Shuttle Solid Rocket Booster [S-srb-model].
- Ours (no usable download exists): tanks, interstages and fairings, simple shapes of revolution at real sizes
  [S13] [S14].

Every part has two empty nodes, Attach_Bottom and Attach_Top, on its axis. The builder stacks parts by putting a part's
Attach_Bottom on the Attach_Top of the part below. Engines have both at their mount plane (z = 0 here), so their nozzles
hang below into the interstage or under the rocket, as on the real vehicles; an engine cluster's Attach_Top is the top
of its thrust section. The booster's origin is its base on its own axis; the builder places a pair beside the core.
Units are metres; Blender +Z becomes Godot +Y.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
VENDOR = os.path.join(HERE, "vendor")
OUT = os.path.normpath(os.path.join(HERE, "..", "parts"))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = argv[argv.index("--render") + 1] if "--render" in argv else None


# ---------------------------------------------------------------- scene and materials
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


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
        "titanium": material("Titanium", (0.36, 0.35, 0.34), 1.0, 0.5),
        "raceway": material("Raceway", (0.30, 0.30, 0.31), 0.2, 0.55),
    }


def link(ob, parent=None):
    bpy.context.scene.collection.objects.link(ob)
    if parent:
        ob.parent = parent
    return ob


def empty(name, z, parent):
    e = bpy.data.objects.new(name, None)
    e.location = (0, 0, z)
    return link(e, parent)


def new_root(name, top, bottom=0.0):
    root = bpy.data.objects.new(name, None)
    link(root)
    empty("Attach_Bottom", bottom, root)
    empty("Attach_Top", top, root)
    return root


# ---------------------------------------------------------------- shapes (ours)
def lathe(name, profile, mat, parent, segs=48):
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((max(r, 1e-5) * math.cos(2 * math.pi * i / segs),
                                    max(r, 1e-5) * math.sin(2 * math.pi * i / segs), z)) for i in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = len(p.vertices) == 4
    return link(bpy.data.objects.new(name, me), parent)


def tube(name, r, z0, z1, mat, parent, segs=48):
    return lathe(name, [(r, z0), (r, z1)], mat, parent, segs)


def box(name, size, loc, mat, parent, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = link(bpy.data.objects.new(name, me), parent)
    ob.location, ob.rotation_euler = loc, rot
    return ob


def raceway(name, R, z0, z1, parent, m):
    a = -math.pi / 2
    ob = box(name, (0.09 * R / 1.85, 0.22 * R / 1.85, z1 - z0), (0, 0, 0), m["raceway"], parent)
    ob.location = (math.cos(a) * R, math.sin(a) * R, (z0 + z1) / 2)
    ob.rotation_euler = (0, 0, a)


def grid_fins(R, z, parent, m, size):
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        h = bpy.data.objects.new(f"GridFin{i}", None)
        link(h, parent)
        h.location = (math.cos(a) * (R + size * 0.5), math.sin(a) * (R + size * 0.5), z)
        h.rotation_euler = (0, 0, a)
        t = size * 0.05
        for k, (sx, sz, x, zz) in enumerate(((size, size * 0.08, 0, size * 0.46), (size, size * 0.08, 0, -size * 0.46),
                                             (size * 0.08, size, size * 0.46, 0), (size * 0.08, size, -size * 0.46, 0))):
            box(f"GridFin{i}_f{k}", (sx, t, sz), (x, 0, zz), m["titanium"], h)
        for k in range(-3, 4):
            for s in (1, -1):
                b = box(f"GridFin{i}_b{k}{s}", (size * 0.78, t * 0.6, size * 0.035), (k * size * 0.12, 0, 0),
                        m["titanium"], h, (0, math.radians(45 * s), 0))


def nose_profile(R, z0, cyl, nose, boat_from=None):
    prof = [(boat_from, z0)] if boat_from else []
    base = z0 + (0.9 if boat_from else 0.0)
    prof += [(R, base), (R, base + cyl)]
    prof += [(R * math.cos(math.asin(i / 14)), base + cyl + nose * i / 14) for i in range(1, 14)]
    prof += [(0.0, base + cyl + nose)]
    return prof, base + cyl + nose


# ---------------------------------------------------------------- downloaded models
def import_joined(path, name, decimate=1.0):
    """Imports a glTF and returns one mesh object with every mesh joined and transforms applied, optionally decimated
    (a ratio of its triangles) to keep the web build light."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    others = [o.name for o in new if o.type != "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for n in others:  # the importer's empties; the joined meshes are already gone
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
    ob.name = name
    if decimate < 1.0:
        mod = ob.modifiers.new("decimate", "DECIMATE")
        mod.ratio = decimate
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob


def bbox(ob):
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def bake(ob, M):
    ob.data.transform(M)
    ob.matrix_world = Matrix.Identity(4)


def normalize_engine(ob, exit_diameter):
    """Engine standing on Z with its nozzle down: scale so the nozzle exit has the real diameter, centre the nozzle on
    the axis, and put the mount plane (the top) at z = 0."""
    lo, hi = bbox(ob)
    h = hi.z - lo.z
    lip = [v.co for v in ob.data.vertices if v.co.z < lo.z + h * 0.04]
    ex = max(max(v.x for v in lip) - min(v.x for v in lip), max(v.y for v in lip) - min(v.y for v in lip))
    cx = (max(v.x for v in lip) + min(v.x for v in lip)) / 2
    cy = (max(v.y for v in lip) + min(v.y for v in lip)) / 2
    s = exit_diameter / ex
    bake(ob, Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -hi.z)))
    lo, hi = bbox(ob)
    return hi.z - lo.z


# ---------------------------------------------------------------- parts
def engine_cluster(pid, src, R, exit_d, ring_r, skirt, m, decimate=1.0):
    """Nine engines (one centre, eight in a ring, as on the Falcon 9 and Electron first stages) under a thrust section."""
    root = new_root(pid, top=skirt)
    eng = import_joined(os.path.join(VENDOR, src), pid + "_engine", decimate)
    length = normalize_engine(eng, exit_d)
    eng.parent = root
    eng.location = (0, 0, -0.02)
    for i in range(8):
        a = 2 * math.pi * i / 8
        c = bpy.data.objects.new(f"{pid}_engine{i + 1}", eng.data)  # shares the mesh: glTF stores it once
        link(c, root)
        c.location = (ring_r * math.cos(a), ring_r * math.sin(a), -0.02)
        c.rotation_euler = (0, 0, a)
    lathe(pid + "_skirt", [(R * 0.98, 0.0), (R, skirt)], m["soot"], root)
    lathe(pid + "_heatshield", [(R * 0.98, 0.0), (0.0, 0.0)], m["soot"], root)
    return root, length


def single_engine(pid, src, exit_d, decimate=1.0):
    root = new_root(pid, top=0.0)
    eng = import_joined(os.path.join(VENDOR, src), pid + "_engine", decimate)
    length = normalize_engine(eng, exit_d)
    eng.parent = root
    return root, length


def tank(pid, R, length, mat_key, m, soot=0.0, race=True):
    root = new_root(pid, top=length)
    tube(pid + "_body", R, 0, length, m[mat_key], root, 64)
    if soot:
        tube(pid + "_soot", R * 1.002, 0, soot, m["soot"], root, 64)
    if race:
        raceway(pid + "_raceway", R, soot, length, root, m)
    return root


def interstage(pid, R, length, m, fins):
    root = new_root(pid, top=length)
    tube(pid + "_body", R * 1.004, 0, length, m["black"], root, 64)
    if fins:
        grid_fins(R, length - 1.3, root, m, 1.4)
    return root


def fairing(pid, R, cyl, nose, mat_key, m, boat_from=None):
    prof, top = nose_profile(R, 0.0, cyl, nose, boat_from)
    root = new_root(pid, top=top)
    lathe(pid + "_shell", prof, m[mat_key], root, 64)
    zc = 0.9 if boat_from else 0.0
    for s in (-1, 1):
        box(f"{pid}_seam{s}", (0.04 * R / 2.6, 0.03, cyl), (0, s * R * 1.002, zc + cyl / 2), m["black"], root)
    return root


def booster_srb(pid):
    """NASA's Shuttle SRB, scaled to its real 45.46 m length and stood on its nozzle with the origin at its base."""
    root = bpy.data.objects.new(pid, None)
    link(root)
    ob = import_joined(os.path.join(VENDOR, "nasa_solid_rocket_booster.glb"), pid + "_body")
    lo, hi = bbox(ob)
    size = hi - lo
    axis = max(range(3), key=lambda i: size[i])
    s = 45.46 / size[axis]
    centre = (lo + hi) / 2
    rot = {0: Matrix.Rotation(math.pi / 2, 4, "Y"), 1: Matrix.Rotation(-math.pi / 2, 4, "X"), 2: Matrix.Identity(4)}[axis]
    bake(ob, rot @ Matrix.Scale(s, 4) @ Matrix.Translation(-centre))
    # the nose cone is the narrow end: make sure it points up
    lo, hi = bbox(ob)
    top = [v.co for v in ob.data.vertices if v.co.z > hi.z - 1.0]
    bot = [v.co for v in ob.data.vertices if v.co.z < lo.z + 1.0]
    span = lambda vs: max(v.x for v in vs) - min(v.x for v in vs)
    if span(top) > span(bot):
        bake(ob, Matrix.Rotation(math.pi, 4, "X"))
    lo, hi = bbox(ob)
    bake(ob, Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
    ob.parent = root
    empty("Attach_Bottom", 0.0, root)
    empty("Attach_Top", 45.46, root)
    return root


def export(root, pid):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in root.children_recursive:
        o.select_set(True)
    path = os.path.join(OUT, pid + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_animations=False, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_image_format="AUTO")
    print("PART", pid, os.path.getsize(path), "bytes")


# Real sizes [S13] [S14] [S15]; section lengths inside a stage are our estimates from the published stage lengths.
R37, R12 = 3.7 / 2, 1.2 / 2
BUILDERS = {
    # 3.7 m family (Falcon 9-type): first stage 41.2 m = 3.2 m thrust section + 38.0 m tank; interstage 6.5 m;
    # second stage tank 9.0 m above it (13.8 m with the vacuum engine inside the interstage); fairing 5.2 m.
    "engine_merlin_x9": lambda m: engine_cluster("engine_merlin_x9", "merlin_engine.glb", R37, 0.92, R37 * 0.66, 3.2, m)[0],
    "engine_merlin_vac": lambda m: single_engine("engine_merlin_vac", "merlin_1d_vacuum.glb", 3.3)[0],
    "tank_37_long": lambda m: tank("tank_37_long", R37, 38.0, "white", m, soot=2.0),
    "tank_37_short": lambda m: tank("tank_37_short", R37, 9.0, "white", m),
    "interstage_37": lambda m: interstage("interstage_37", R37, 6.5, m, True),
    "fairing_52": lambda m: fairing("fairing_52", 5.2 / 2, 6.6, 6.5, "white", m, boat_from=R37),
    # 1.2 m family (Electron-type): first stage 12.1 m = 1.0 m thrust section + 11.1 m tank; interstage 0.9 m;
    # second stage tank 2.4 m; fairing 2.5 m.
    "engine_small_x9": lambda m: engine_cluster("engine_small_x9", "rocket_nozzle_part.glb", R12, 0.25, R12 * 0.64, 1.0, m, 0.2)[0],
    "engine_small_vac": lambda m: single_engine("engine_small_vac", "rocket_nozzle_part.glb", 0.42, 0.4)[0],
    "tank_12_long": lambda m: tank("tank_12_long", R12, 11.1, "carbon", m, race=False),
    "tank_12_short": lambda m: tank("tank_12_short", R12, 2.4, "carbon", m, race=False),
    "interstage_12": lambda m: interstage("interstage_12", R12, 0.9, m, False),
    "fairing_12": lambda m: fairing("fairing_12", R12, 1.1, 1.4, "carbon", m),
    # side boosters
    "booster_srb": lambda m: booster_srb("booster_srb"),
}

os.makedirs(OUT, exist_ok=True)
for pid, build in BUILDERS.items():
    reset()
    root = build(mats())
    export(root, pid)

if RENDER_DIR:
    # A lineup of every part, for a visual check.
    reset()
    m = mats()
    x = 0.0
    for pid, build in BUILDERS.items():
        root = build(m)
        root.location = (x, 0, 4.0)
        x += 6.5
    scn = bpy.context.scene
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.52, 0.62, 1)
    sun = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN")); sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(55), 0, math.radians(25)); link(sun)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); link(cam); scn.camera = cam
    cam.location = (x / 2, -95, 24); cam.data.lens = 40
    cam.rotation_euler = (Vector((x / 2, 0, 22)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.engine = "CYCLES"; scn.cycles.samples = 24; scn.cycles.use_denoising = True
    scn.render.resolution_x, scn.render.resolution_y = 1600, 800
    scn.view_settings.view_transform = "AgX"
    scn.render.filepath = os.path.join(RENDER_DIR, "parts.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED")
