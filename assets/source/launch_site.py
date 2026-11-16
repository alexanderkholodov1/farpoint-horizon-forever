"""The launch pad and its structures (issue #12), exported to glTF for Godot.

Run (Blender 4.2 or newer, background):
    blender -b --factory-startup --python assets/source/launch_site.py -- [--render <dir>]

Writes assets/models/launch_site.glb. Units are metres; the launch screen scales it as it scales the rocket
(about 0.088 game units per metre). Origin at the centre of the launch mount, on the hardstand; the rocket stands on
the mount's top (MOUNT_H). Blender +Z becomes Godot +Y; Blender -Y becomes Godot +Z.

Modeled after the pads of the US East Coast (SLC-40, LC-39A) as photographed, simplified and with no marks:
- a concrete hardstand with a flame trench running from under the mount, its walls and a sloped flame deflector;
- a low steel launch mount with an open centre and hold-down arms;
- a square lattice fixed service structure about 80 m tall: four columns, a horizontal frame every 6 m, X bracing on
  every face, work platforms, a crew access arm and a lightning mast;
- three tall lattice lightning towers around the pad (their catenary wires left out: from the camera they seemed to
  cross the rocket);
- the elevated water tank that feeds the sound suppression deluge (a sphere on legs, LC-39A style);
- a spherical liquid oxygen tank, horizontal fuel tanks, the horizontal integration hangar and the pad road.
Sizes are our estimates from photographs and the published rocket heights, not drawings.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "models", "launch_site.glb"))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = argv[argv.index("--render") + 1] if "--render" in argv else None

MOUNT_H = 2.4        # top of the launch mount above the hardstand (the rocket's base)
TOWER_X = -16.0      # centre of the service structure (the rocket is at the origin)
TOWER_W = 10.0
TOWER_H = 84.0
BAY = 6.0

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene


def material(name, rgb, metal=0.0, rough=0.5, two_sided=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = not two_sided
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


M = {
    "concrete": material("Concrete", (0.4, 0.39, 0.37), 0.0, 0.9),
    "concrete_dark": material("Scorched concrete", (0.26, 0.25, 0.24), 0.0, 0.95),
    "steel": material("Painted steel", (0.55, 0.56, 0.57), 0.5, 0.5),
    "steel_dark": material("Dark steel", (0.2, 0.2, 0.21), 0.7, 0.45),
    "grating": material("Grating", (0.4, 0.4, 0.41), 0.6, 0.6),
    "white": material("White tank", (0.78, 0.78, 0.76), 0.1, 0.4),
    "wire": material("Wire", (0.25, 0.25, 0.25), 0.8, 0.4),
    "asphalt": material("Asphalt", (0.12, 0.12, 0.125), 0.0, 0.92),
    "hangar": material("Hangar cladding", (0.82, 0.83, 0.84), 0.3, 0.55),
    "door": material("Hangar door", (0.55, 0.57, 0.6), 0.6, 0.45),
    "warning": material("Yellow handrail", (0.85, 0.68, 0.12), 0.2, 0.5),
}

_batch = {}   # material key -> bmesh, so thousands of struts become a few meshes


def bm_for(key):
    if key not in _batch:
        _batch[key] = bmesh.new()
    return _batch[key]


def add_box(key, size, center, rot=None):
    bm = bm_for(key)
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
    if rot is not None:
        bmesh.ops.rotate(tmp, cent=Vector(), matrix=rot, verts=tmp.verts)
    bmesh.ops.translate(tmp, vec=Vector(center), verts=tmp.verts)
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def add_rod(key, a, b, r, segs=6):
    a, b = Vector(a), Vector(b)
    d = b - a
    if d.length < 1e-4:
        return
    tmp = bmesh.new()
    bmesh.ops.create_cone(tmp, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=d.length)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    bmesh.ops.rotate(tmp, cent=Vector(), matrix=rot, verts=tmp.verts)
    bmesh.ops.translate(tmp, vec=(a + b) / 2, verts=tmp.verts)
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm_for(key).from_mesh(me)
    bpy.data.meshes.remove(me)


def add_lathe(key, profile, center=(0, 0, 0), segs=32, caps=True):
    tmp = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([tmp.verts.new((center[0] + r * math.cos(2 * math.pi * i / segs), center[1] + r * math.sin(2 * math.pi * i / segs), center[2] + z)) for i in range(segs)])
    for j in range(len(rings) - 1):
        for i in range(segs):
            tmp.faces.new((rings[j][i], rings[j][(i + 1) % segs], rings[j + 1][(i + 1) % segs], rings[j + 1][i]))
    if caps and profile[0][0] > 0:
        tmp.faces.new(list(reversed(rings[0])))
    if caps and profile[-1][0] > 0:
        tmp.faces.new(rings[-1])
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm_for(key).from_mesh(me)
    bpy.data.meshes.remove(me)


def add_sphere(key, r, center, segs=32, rings=16):
    prof = [(r * math.sin(math.pi * i / rings), -r * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
    prof[0] = (0.0, -r)
    prof[-1] = (0.0, r)
    add_lathe(key, prof, center, segs, caps=False)


def lattice_column(key, x, y, z0, z1, w, bay, r_leg, r_brace):
    """A square lattice mast (lightning tower style) from z0 to z1, w wide."""
    corners = [(x - w / 2, y - w / 2), (x + w / 2, y - w / 2), (x + w / 2, y + w / 2), (x - w / 2, y + w / 2)]
    for cx, cy in corners:
        add_rod(key, (cx, cy, z0), (cx, cy, z1), r_leg)
    n = max(1, int((z1 - z0) / bay))
    for i in range(n + 1):
        z = z0 + (z1 - z0) * i / n
        for k in range(4):
            a, b = corners[k], corners[(k + 1) % 4]
            add_rod(key, (a[0], a[1], z), (b[0], b[1], z), r_brace)
            if i < n:
                z2 = z0 + (z1 - z0) * (i + 1) / n
                add_rod(key, (a[0], a[1], z), (b[0], b[1], z2), r_brace)


# ===================================================================================== GROUND
def hardstand():
    # the main pad: 70 x 70 m of concrete, the mount at its centre
    add_box("concrete", (70, 70, 1.0), (0, 0, -0.5))
    # the flame trench: an open channel running to +X (away from the tower), 9 m wide, walls standing 1.5 m
    add_box("concrete_dark", (40, 9, 0.2), (22, 0, 0.05))
    for s in (-1, 1):
        add_box("concrete", (40, 1.2, 1.6), (22, s * 5.1, 0.8))
    # the flame deflector under the mount, a wedge sloping into the trench
    tmp_rot = Matrix.Rotation(math.radians(-28), 3, "Y")
    add_box("steel_dark", (11, 8.6, 0.8), (4.5, 0, 0.4), tmp_rot)
    # scorched ring around the mount
    add_lathe("concrete_dark", [(0.0, 0.02), (14.0, 0.02)], (0, 0, 0), 48, caps=False)
    # the road to the pad and the apron in front of the hangar
    add_box("asphalt", (8, 160, 0.1), (0, -115, 0.05))
    add_box("asphalt", (60, 30, 0.1), (0, -200, 0.05))
    add_box("concrete", (26, 14, 0.4), (TOWER_X, 0, 0.2))   # the tower's footing


def launch_mount():
    h = MOUNT_H
    # four legs and a square ring with an open centre over the trench
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box("steel_dark", (1.2, 1.2, h), (sx * 4.2, sy * 4.2, h / 2))
    for s in (-1, 1):
        add_box("steel", (10.0, 1.6, 0.9), (0, s * 4.2, h - 0.45))
        add_box("steel", (1.6, 10.0, 0.9), (s * 4.2, 0, h - 0.45))
    # hold-down arms reaching toward the rocket's base
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        add_box("steel_dark", (1.8, 0.4, 0.5), (2.6 * math.cos(a), 2.6 * math.sin(a), h - 0.1),
                Matrix.Rotation(a, 3, "Z"))
    # the tail service mast on the mount's side, toward the tower
    add_box("steel", (1.4, 1.4, 6.0), (-4.8, 2.8, h + 3.0))


# ===================================================================================== TOWER
def service_tower():
    x0, y0, w = TOWER_X, 0.0, TOWER_W
    corners = [(x0 - w / 2, y0 - w / 2), (x0 + w / 2, y0 - w / 2), (x0 + w / 2, y0 + w / 2), (x0 - w / 2, y0 + w / 2)]
    n = int(TOWER_H / BAY)
    for cx, cy in corners:
        add_box("steel", (0.9, 0.9, TOWER_H), (cx, cy, TOWER_H / 2))
    for i in range(n + 1):
        z = i * BAY
        for k in range(4):
            a, b = corners[k], corners[(k + 1) % 4]
            mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, z)
            if a[0] == b[0]:
                add_box("steel", (0.55, w, 0.55), mid)
            else:
                add_box("steel", (w, 0.55, 0.55), mid)
            if i < n:
                add_rod("steel", (a[0], a[1], z), (b[0], b[1], z + BAY), 0.16)
                add_rod("steel", (b[0], b[1], z), (a[0], a[1], z + BAY), 0.16)
        # work platforms every second level, with grating floors and yellow rails on the rocket side
        if i % 2 == 0 and 0 < i < n:
            add_box("grating", (w - 0.6, w - 0.6, 0.18), (x0, y0, z + 0.1))
            add_box("warning", (0.08, w, 0.08), (x0 + w / 2 + 0.6, y0, z + 1.1))
        # an elevator shaft and stairs in one corner: a closed core
    add_box("steel_dark", (3.2, 3.2, TOWER_H), (x0 - w / 2 + 2.0, y0 + w / 2 - 2.0, TOWER_H / 2))
    # the top: roof, a crane beam and the lightning mast
    add_box("steel", (w + 1.0, w + 1.0, 0.6), (x0, y0, TOWER_H + 0.3))
    add_box("steel", (1.0, 1.0, 4.0), (x0 + 2, y0, TOWER_H + 2.6))
    add_rod("steel", (x0, y0, TOWER_H), (x0, y0, TOWER_H + 22.0), 0.35, 8)
    # crew access arm toward the rocket at about the top of the second stage, a covered walkway on a truss
    arm_z = 62.0
    arm_x0, arm_x1 = x0 + w / 2, -2.4
    add_box("steel", (arm_x1 - arm_x0, 2.6, 0.4), ((arm_x0 + arm_x1) / 2, 0, arm_z))
    add_box("white", (arm_x1 - arm_x0, 2.4, 2.6), ((arm_x0 + arm_x1) / 2, 0, arm_z + 1.5))
    for i in range(6):
        xa = arm_x0 + (arm_x1 - arm_x0) * i / 6
        xb = arm_x0 + (arm_x1 - arm_x0) * (i + 1) / 6
        add_rod("steel", (xa, -1.3, arm_z - 2.0), (xb, -1.3, arm_z), 0.12)
        add_rod("steel", (xa, 1.3, arm_z - 2.0), (xb, 1.3, arm_z), 0.12)
    add_box("steel", (arm_x1 - arm_x0, 0.4, 0.4), ((arm_x0 + arm_x1) / 2, -1.3, arm_z - 2.0))
    add_box("steel", (arm_x1 - arm_x0, 0.4, 0.4), ((arm_x0 + arm_x1) / 2, 1.3, arm_z - 2.0))
    # two propellant umbilical arms lower down, retracted against the tower
    for z in (20.0, 44.0):
        add_box("steel", (6.0, 1.2, 1.2), (x0 + w / 2 + 3.0, 2.5, z))
        add_rod("steel_dark", (x0 + w / 2, 2.0, z - 0.6), (x0 + w / 2 + 6.0, 2.0, z - 0.6), 0.25)


# ===================================================================================== AROUND THE PAD
LIGHTNING = [(-55.0, 45.0), (55.0, 45.0), (0.0, -62.0)]
LIGHTNING_H = 110.0


def lightning_towers():
    for x, y in LIGHTNING:
        lattice_column("steel", x, y, 0.0, LIGHTNING_H, 3.0, 5.0, 0.22, 0.08)
        add_rod("steel", (x, y, LIGHTNING_H), (x, y, LIGHTNING_H + 12.0), 0.25, 8)
        add_box("concrete", (6, 6, 1.0), (x, y, 0.3))
    # Real pads string catenary wires between these masts, high above the rocket. Seen from the launch camera they
    # crossed the rocket and read as cables it could snag on (the team member's call), so the game leaves them out.


def water_tower():
    x, y, z = 95.0, 70.0, 62.0
    add_sphere("white", 9.5, (x, y, z))
    for i in range(8):
        a = 2 * math.pi * i / 8
        add_rod("steel", (x + 11 * math.cos(a), y + 11 * math.sin(a), 0), (x + 7 * math.cos(a), y + 7 * math.sin(a), z), 0.45, 8)
    add_rod("steel", (x, y, 0), (x, y, z - 9), 1.0, 12)
    for zz in (18.0, 38.0):
        k = 1.0 - zz / z * 0.36
        for i in range(8):
            a, b = 2 * math.pi * i / 8, 2 * math.pi * (i + 1) / 8
            add_rod("steel", (x + 11 * k * math.cos(a), y + 11 * k * math.sin(a), zz), (x + 11 * k * math.cos(b), y + 11 * k * math.sin(b), zz), 0.2, 6)


def tank_farm():
    # liquid oxygen: a spherical vacuum-jacketed tank on a concrete ring
    add_sphere("white", 10.0, (-75.0, -60.0, 12.0))
    add_lathe("concrete", [(10.0, 0.0), (10.0, 2.5)], (-75.0, -60.0, 0.0), 32)
    # fuel and helium: three horizontal tanks on concrete saddles
    for i in range(3):
        y = -25.0 - i * 8.0
        add_rod("white", (-110.0, y, 4.0), (-86.0, y, 4.0), 3.0, 20)
        for s_ in (-1, 1):
            add_sphere("white", 3.0, (-98.0 + s_ * 12.0, y, 4.0), 20, 10)
            add_box("concrete", (1.0, 6.0, 2.0), (-98.0 + s_ * 8.0, y, 1.0))
    # the pipes from the farm to the pad
    add_rod("steel", (-86.0, -30.0, 1.0), (TOWER_X - 5, -3.0, 1.0), 0.5, 8)


def hangar():
    # horizontal integration facility at the end of the road
    x, y = 0.0, -235.0
    add_box("hangar", (90, 50, 30), (x, y, 15))
    add_box("door", (60, 0.6, 26), (x, y + 25.1, 13))
    add_box("steel_dark", (92, 52, 1.0), (x, y, 30.5))
    # a few smaller buildings
    add_box("hangar", (24, 18, 9), (70.0, -190.0, 4.5))
    add_box("hangar", (14, 12, 6), (-70.0, -175.0, 3.0))


hardstand()
launch_mount()
service_tower()
lightning_towers()
tank_farm()
water_tower()
hangar()

root = bpy.data.objects.new("LaunchSite", None)
scn.collection.objects.link(root)
for key, bm in _batch.items():
    me = bpy.data.meshes.new(key)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[key])
    if key in ("white", "wire"):
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(key.capitalize(), me)
    scn.collection.objects.link(ob)
    ob.parent = root
# markers the game reads: the mount's top (the rocket's base) and the access arm's tip
for name, loc in (("RocketBase", (0, 0, MOUNT_H)), ("TowerTop", (TOWER_X, 0, TOWER_H))):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    scn.collection.objects.link(e)
    e.parent = root

if RENDER_DIR:
    os.makedirs(RENDER_DIR, exist_ok=True)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    cam.location = (120, 150, 45)
    cam.rotation_euler = (math.radians(78), 0, math.radians(140))
    cam.data.lens = 28
    scn.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(-30))
    scn.collection.objects.link(sun)
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.65, 0.85, 1)
    scn.world = w
    scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1600, 1000
    scn.render.filepath = os.path.join(RENDER_DIR, "launch_site.png")
    bpy.ops.render.render(write_still=True)

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True, export_animations=False)
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
