"""Spacecraft components the game assembles into the player's craft (issue #12), exported to one glTF.

Run (Blender 4.2 or newer, background):
    blender -b --factory-startup --python assets/source/craft_kit.py -- [--render <dir>]

Writes assets/models/craft_kit.glb. scripts/world/ship_builder.gd instances its top-level nodes by name and scales them to
the craft. Every component is modeled at unit size, standing on its mount at the origin and pointing out along
Blender +Z (Godot +Y after export): the code only has to place it on a face and scale it.

The shapes follow real hardware, simplified (no single product is copied, there are no marks):
- StarTracker: a camera head under a long conical sun baffle, as on most three-axis craft.
- CamTelescope: a cylindrical telescope barrel with an internal baffle, an angled sunshade lip and a mounting flange,
  as Earth-observation cameras of Landsat and Sentinel-2 class have.
- CamBox: a compact camera, housing with a short lens barrel and cooling fins, as on small satellites.
- Radiometer: a box with a rotating scan drum and a stepped passive cooler pointed at cold space, as thermal
  imagers like ASTER TIR or VIIRS use.
- Spectrometer: a box with a slit aperture behind a rectangular baffle, as UV gas spectrometers like OMI or TROPOMI.
- Dish: a true paraboloid (focal ratio 0.4), its rim, a feed horn at the focus on three struts, and a gimbal base.
- SarPanel: a radar antenna panel tiled with patch radiators, as Sentinel-1 class SAR.
- Boom: a triangular lattice mast with a sensor head at the tip, as magnetometer booms.
- ThrusterChem: a bell nozzle with its valve and flange (hydrazine class).
- ThrusterIon: a gridded ion engine, its discharge chamber, perforated grid and neutralizer, as NASA NEXT or NSTAR.
- AdapterRing: the launch adapter ring on the craft's base.
- Sada, Yoke: the solar array drive and the arm that holds a wing off the body.
- SunSensor: a small coarse sun sensor head.

Units: each part is about 1 unit across; its real size comes from the game data (scripts/world/ship_builder.gd).
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "models", "craft_kit.glb"))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = argv[argv.index("--render") + 1] if "--render" in argv else None

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene


def material(name, rgb, metal=0.0, rough=0.5, emit=None, two_sided=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = not two_sided
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 1.0
    return m


M = {
    "alu": material("Aluminium", (0.72, 0.72, 0.72), 1.0, 0.32),
    "alu_dark": material("Anodized aluminium", (0.32, 0.32, 0.34), 0.9, 0.4),
    "black": material("Black paint", (0.025, 0.025, 0.028), 0.0, 0.6),
    "black_in": material("Black baffle", (0.012, 0.012, 0.014), 0.0, 0.85, two_sided=True),
    "white": material("White paint", (0.82, 0.82, 0.8), 0.0, 0.45),
    "white2": material("White paint two-sided", (0.86, 0.86, 0.84), 0.0, 0.4, two_sided=True),
    "gold": material("Gold foil", (1.0, 0.72, 0.3), 1.0, 0.28),
    "silver": material("Silver foil", (0.86, 0.86, 0.88), 1.0, 0.2),
    "glass": material("Lens", (0.02, 0.035, 0.06), 0.2, 0.03),
    "nozzle": material("Niobium nozzle", (0.42, 0.4, 0.38), 1.0, 0.35),
    "grid": material("Molybdenum grid", (0.36, 0.35, 0.34), 1.0, 0.45),
    "copper": material("Copper", (0.85, 0.5, 0.32), 1.0, 0.3),
    "patch": material("Patch radiator", (0.75, 0.62, 0.38), 1.0, 0.35),
    "panel": material("Antenna panel", (0.2, 0.21, 0.22), 0.3, 0.6),
    "carbon": material("Carbon fibre", (0.05, 0.05, 0.055), 0.4, 0.35),
}


def new_obj(name, bm, mat, parent=None, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    scn.collection.objects.link(ob)
    if parent:
        ob.parent = parent
    return ob


def root(name):
    e = bpy.data.objects.new(name, None)
    scn.collection.objects.link(e)
    return e


def box(name, size, center, mat, parent, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.rotate(bm, cent=Vector(), matrix=Matrix.Rotation(rot[0], 3, "X") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[2], 3, "Z"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return new_obj(name, bm, mat, parent)


def lathe(name, profile, mat, parent, segs=40, smooth=True, cap_top=False, cap_bottom=False, center=(0, 0, 0)):
    """Revolve [(r, z), ...] (bottom to top) around Z."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((center[0] + r * math.cos(a), center[1] + r * math.sin(a), center[2] + z)))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for i in range(segs):
            bm.faces.new((rings[j][i], rings[j][(i + 1) % segs], rings[j + 1][(i + 1) % segs], rings[j + 1][i]))
    if cap_bottom and profile[0][0] > 0:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 0:
        bm.faces.new(rings[-1])
    bm.normal_update()
    return new_obj(name, bm, mat, parent, smooth)


def cyl(name, r, z0, z1, mat, parent, segs=32, center=(0, 0, 0), caps=True):
    return lathe(name, [(r, z0), (r, z1)], mat, parent, segs, smooth=True, cap_top=caps, cap_bottom=caps, center=center)


def rod(name, a, b, r, mat, parent, segs=8):
    """A thin cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=d.length)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    bmesh.ops.rotate(bm, cent=Vector(), matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=(a + b) / 2, verts=bm.verts)
    return new_obj(name, bm, mat, parent, smooth=True)


# ===================================================================================== PARTS
def star_tracker():
    r = root("StarTracker")
    box("Head", (0.42, 0.42, 0.34), (0, 0, 0.17), M["black"], r)
    cyl("Lens", 0.15, 0.34, 0.4, M["glass"], r)
    # conical baffle, open, black inside, white outside
    lathe("BaffleOut", [(0.17, 0.38), (0.36, 1.0)], M["white2"], r, 32)
    lathe("BaffleLip", [(0.36, 1.0), (0.34, 1.0)], M["white2"], r, 32)
    lathe("BaffleIn", [(0.34, 1.0), (0.155, 0.39)], M["black_in"], r, 32)
    return r


def cam_telescope():
    r = root("CamTelescope")
    cyl("Flange", 0.5, 0.0, 0.05, M["alu"], r, 40)
    lathe("Barrel", [(0.42, 0.05), (0.42, 0.85)], M["black"], r, 40)
    # MLI band around the barrel
    lathe("Band", [(0.43, 0.25), (0.43, 0.6)], M["silver"], r, 40)
    # internal baffle rings and the primary seen at the bottom
    for i, z in enumerate((0.55, 0.7, 0.82)):
        lathe("Vane%d" % i, [(0.415, z), (0.3, z)], M["black_in"], r, 40)
    lathe("Inner", [(0.415, 0.98), (0.415, 0.15)], M["black_in"], r, 40)
    cyl("Optic", 0.26, 0.14, 0.17, M["glass"], r, 32)
    # sunshade cut at an angle: a ring whose top edge rises on one side
    bm = bmesh.new()
    segs = 40
    lo, hi = [], []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        x, y = 0.42 * math.cos(a), 0.42 * math.sin(a)
        lo.append(bm.verts.new((x, y, 0.85)))
        hi.append(bm.verts.new((x, y, 0.98 + 0.22 * (0.5 + 0.5 * math.sin(a)))))
    for i in range(segs):
        bm.faces.new((lo[i], lo[(i + 1) % segs], hi[(i + 1) % segs], hi[i]))
    bm.normal_update()
    new_obj("Sunshade", bm, M["white2"], r, smooth=True)
    return r


def cam_box():
    r = root("CamBox")
    box("Housing", (0.8, 0.8, 0.45), (0, 0, 0.225), M["alu_dark"], r)
    # cooling fins on two sides
    for s in (-1, 1):
        for i in range(6):
            box("Fin_%d_%d" % (s, i), (0.08, 0.025, 0.36), (s * 0.44, -0.3 + i * 0.12, 0.2), M["alu_dark"], r)
    lathe("LensBarrel", [(0.26, 0.45), (0.26, 0.62), (0.22, 0.68), (0.22, 0.78)], M["black"], r, 32, cap_top=False)
    lathe("LensInner", [(0.2, 0.78), (0.2, 0.6)], M["black_in"], r, 32)
    cyl("Glass", 0.19, 0.62, 0.64, M["glass"], r, 32)
    return r


def radiometer():
    r = root("Radiometer")
    box("Body", (1.0, 0.8, 0.5), (0, 0, 0.25), M["silver"], r)
    # scan drum, lying along X, with its slot window
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.24, radius2=0.24, depth=0.7)
    bmesh.ops.rotate(bm, cent=Vector(), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector((-0.1, 0.0, 0.72)), verts=bm.verts)
    new_obj("ScanDrum", bm, M["alu"], r, smooth=True)
    box("Slot", (0.6, 0.12, 0.06), (-0.1, 0.0, 0.95), M["black"], r)
    for s in (-1, 1):
        box("DrumMount%d" % s, (0.06, 0.3, 0.25), (-0.1 + s * 0.38, 0, 0.6), M["alu_dark"], r)
    # stepped passive cooler: nested square cones opening to cold space
    for i, (w, z0, z1) in enumerate(((0.42, 0.5, 0.62), (0.34, 0.62, 0.72), (0.26, 0.72, 0.8))):
        bm = bmesh.new()
        sq0 = [bm.verts.new((0.32 + x * w * 0.6, y * w * 0.6, z0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        sq1 = [bm.verts.new((0.32 + x * w, y * w, z1)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for k in range(4):
            bm.faces.new((sq0[k], sq0[(k + 1) % 4], sq1[(k + 1) % 4], sq1[k]))
        new_obj("Cooler%d" % i, bm, M["white2"] if i == 0 else M["silver"], r)
    box("ColdPlate", (0.22, 0.22, 0.02), (0.32, 0, 0.52), M["black"], r)
    return r


def spectrometer():
    r = root("Spectrometer")
    box("Body", (0.9, 0.7, 0.6), (0, 0, 0.3), M["gold"], r)
    box("Plate", (0.92, 0.72, 0.03), (0, 0, 0.6), M["alu"], r)
    # rectangular baffle around a long slit
    w, h, z0, z1 = 0.5, 0.18, 0.6, 0.95
    bm = bmesh.new()
    a = [bm.verts.new((x * w / 2, y * h / 2, z0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    b = [bm.verts.new((x * (w / 2 + 0.06), y * (h / 2 + 0.08), z1)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    for k in range(4):
        bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    new_obj("Baffle", bm, M["black_in"], r)
    box("Slit", (0.44, 0.03, 0.01), (0, 0, 0.62), M["glass"], r)
    box("Electronics", (0.4, 0.3, 0.15), (0.2, 0.15, 0.68), M["alu_dark"], r)
    return r


def dish():
    r = root("Dish")
    f = 0.4 * 2.0   # focal length for a dish of diameter 2 (radius 1), f/D = 0.4
    depth = 1.0 / (4 * f)
    # gimbal base
    cyl("Gimbal", 0.16, 0.0, 0.18, M["alu_dark"], r, 24)
    box("Yoke", (0.38, 0.1, 0.22), (0, 0, 0.26), M["alu_dark"], r)
    z0 = 0.34
    prof = [(1.0 * (i / 16.0), z0 + (1.0 * i / 16.0) ** 2 / (4 * f)) for i in range(17)]
    # the reflecting front (white paint, as real dishes) and the back (ribbed)
    lathe("Reflector", prof, M["white2"], r, 48)
    lathe("Rim", [(1.0, z0 + depth), (1.02, z0 + depth), (1.02, z0 + depth - 0.04)], M["alu"], r, 48, smooth=False)
    back = [(rr * 0.98, z - 0.03) for rr, z in prof]
    lathe("Back", list(reversed(back)), M["alu"], r, 48)
    for i in range(8):
        a = 2 * math.pi * i / 8
        pts = [(rr * 0.97, z - 0.06) for rr, z in prof[2::2]]
        for j in range(len(pts) - 1):
            (r0, z_0), (r1, z_1) = pts[j], pts[j + 1]
            rod("Rib%d_%d" % (i, j), (r0 * math.cos(a), r0 * math.sin(a), z_0), (r1 * math.cos(a), r1 * math.sin(a), z_1), 0.015, M["alu"], r)
    # feed at the focus on three struts
    fz = z0 + f
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.3
        rod("Strut%d" % i, (0.8 * math.cos(a), 0.8 * math.sin(a), z0 + 0.64 ** 2 / (4 * f) + 0.0), (0.05 * math.cos(a), 0.05 * math.sin(a), fz - 0.06), 0.018, M["white"], r)
    lathe("Feed", [(0.03, fz - 0.12), (0.06, fz - 0.06), (0.12, fz + 0.02)], M["gold"], r, 24, cap_bottom=True)
    cyl("FeedCap", 0.12, fz + 0.02, fz + 0.035, M["white"], r, 24)
    return r


def sar_panel():
    r = root("SarPanel")
    box("Panel", (1.0, 1.0, 0.04), (0, 0, 0.02), M["panel"], r)
    n = 10
    for i in range(n):
        for j in range(n):
            box("P%d_%d" % (i, j), (0.06, 0.06, 0.006), (-0.45 + i * 0.1, -0.45 + j * 0.1, 0.043), M["patch"], r)
    for s in (-1, 1):
        box("Edge%d" % s, (1.02, 0.02, 0.06), (0, s * 0.5, 0.02), M["alu"], r)
    box("Back", (0.9, 0.9, 0.02), (0, 0, -0.01), M["white"], r)
    return r


def boom():
    r = root("Boom")
    tri = [(0.05 * math.cos(a), 0.05 * math.sin(a)) for a in (0, 2 * math.pi / 3, 4 * math.pi / 3)]
    n = 14
    for k, (x, y) in enumerate(tri):
        rod("Longeron%d" % k, (x, y, 0), (x, y, 1.0), 0.006, M["carbon"], r, 6)
    for i in range(n + 1):
        z = i / n
        for k in range(3):
            a, b = tri[k], tri[(k + 1) % 3]
            rod("Batten%d_%d" % (i, k), (a[0], a[1], z), (b[0], b[1], z), 0.004, M["carbon"], r, 4)
            if i < n:
                rod("Diag%d_%d" % (i, k), (a[0], a[1], z), (b[0], b[1], z + 1.0 / n), 0.0025, M["alu"], r, 4)
    cyl("Canister", 0.09, -0.12, 0.02, M["alu_dark"], r, 24)
    box("Sensor", (0.1, 0.1, 0.1), (0, 0, 1.05), M["white"], r)
    return r


def thruster_chem():
    r = root("ThrusterChem")
    cyl("Flange", 0.5, 0.0, 0.05, M["alu"], r, 32)
    box("Valve", (0.4, 0.4, 0.25), (0, 0, 0.17), M["alu_dark"], r)
    cyl("Chamber", 0.15, 0.29, 0.45, M["nozzle"], r, 32)
    # bell from throat to exit (opens away from the craft, along +Z)
    prof = [(0.09, 0.45)]
    for i in range(1, 13):
        t = i / 12.0
        prof.append((0.09 + 0.36 * (1 - (1 - t) ** 2.2), 0.45 + 0.55 * t))
    lathe("Bell", prof, M["nozzle"], r, 40)
    lathe("BellIn", list(reversed([(rr - 0.012, z) for rr, z in prof])), M["black_in"], r, 40)
    return r


def thruster_ion():
    r = root("ThrusterIon")
    cyl("Mount", 0.55, 0.0, 0.06, M["alu"], r, 40)
    lathe("Chamber", [(0.42, 0.06), (0.5, 0.2), (0.5, 0.5)], M["alu_dark"], r, 48, cap_bottom=True)
    lathe("Mask", [(0.5, 0.5), (0.52, 0.52), (0.44, 0.54)], M["alu"], r, 48, smooth=False)
    cyl("Grid", 0.44, 0.5, 0.52, M["grid"], r, 48)
    # the perforations: a ring pattern of dark dots on the grid
    for ring in range(1, 7):
        rr = ring * 0.06
        cnt = 6 * ring
        for i in range(cnt):
            a = 2 * math.pi * i / cnt
            cyl("H%d_%d" % (ring, i), 0.018, 0.52, 0.523, M["black"], r, 8, center=(rr * math.cos(a), rr * math.sin(a), 0))
    # neutralizer cathode on its arm
    rod("NeutArm", (0.5, 0, 0.3), (0.62, 0, 0.5), 0.02, M["alu"], r)
    cyl("Neut", 0.04, 0.48, 0.6, M["nozzle"], r, 16, center=(0.62, 0, 0))
    return r


def adapter_ring():
    r = root("AdapterRing")
    lathe("Ring", [(0.5, 0.0), (0.5, 0.06), (0.46, 0.06), (0.46, 0.18), (0.5, 0.18), (0.5, 0.22), (0.44, 0.22), (0.44, 0.0)],
          M["alu"], r, 64, smooth=False)
    for i in range(12):
        a = 2 * math.pi * i / 12
        box("Bolt%d" % i, (0.03, 0.03, 0.03), (0.5 * math.cos(a), 0.5 * math.sin(a), 0.2), M["alu_dark"], r)
    return r


def sada():
    r = root("Sada")
    cyl("Housing", 0.5, 0.0, 0.6, M["alu_dark"], r, 32)
    cyl("Shaft", 0.22, 0.6, 1.0, M["alu"], r, 24)
    lathe("Collar", [(0.55, 0.42), (0.55, 0.5)], M["alu"], r, 32, cap_top=True, cap_bottom=True)
    return r


def yoke():
    """The arm from the drive to the first panel: two tubes meeting at the drive, spread to the panel's hinges."""
    r = root("Yoke")
    rod("TubeA", (0, 0, 0), (0.3, 0, 1.0), 0.03, M["carbon"], r, 10)
    rod("TubeB", (0, 0, 0), (-0.3, 0, 1.0), 0.03, M["carbon"], r, 10)
    rod("Cross", (-0.15, 0, 0.5), (0.15, 0, 0.5), 0.022, M["carbon"], r, 10)
    for s in (-1, 1):
        box("Hinge%d" % s, (0.08, 0.08, 0.06), (s * 0.3, 0, 1.0), M["alu"], r)
    return r


def sun_sensor():
    r = root("SunSensor")
    box("Body", (0.8, 0.8, 0.35), (0, 0, 0.175), M["alu_dark"], r)
    box("Window", (0.4, 0.4, 0.04), (0, 0, 0.37), M["glass"], r)
    return r


for build in (star_tracker, cam_telescope, cam_box, radiometer, spectrometer, dish, sar_panel, boom, thruster_chem,
              thruster_ion, adapter_ring, sada, yoke, sun_sensor):
    build()

# lay the parts out in a row (only matters for the preview; Godot reads each node's own transform as identity)
roots = [o for o in scn.objects if o.parent is None]
if RENDER_DIR:
    os.makedirs(RENDER_DIR, exist_ok=True)
    for i, o in enumerate(roots):
        o.location = ((i % 5) * 2.6, -(i // 5) * 2.8, 0)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.location = (5.2, -14.0, 9.0)
    cam.rotation_euler = (math.radians(55), 0, 0)
    cam.data.lens = 32
    scn.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(40), math.radians(20), math.radians(30))
    scn.collection.objects.link(sun)
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.08, 1)
    scn.world = w
    scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1600, 1000
    scn.render.filepath = os.path.join(RENDER_DIR, "craft_kit.png")
    bpy.ops.render.render(write_still=True)
    for o in roots:
        o.location = (0, 0, 0)

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True, export_animations=False)
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
