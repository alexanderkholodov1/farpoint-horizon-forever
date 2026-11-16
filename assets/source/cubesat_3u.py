"""3U CubeSat with four deployable solar wings and four UHF tape antennas, exported to glTF for Godot.

Run (Blender 4.2 or newer, background):
    blender -b --factory-startup --python assets/source/cubesat_3u.py -- [--render <dir>]

Writes assets/models/cubesat_3u.glb. With --render, also writes stowed.png and deployed.png to <dir> for a visual check.

Geometry follows the CubeSat Design Specification Rev 14 (Cal Poly, 2022), the 3U envelope of 100 x 100 x 340.5 mm
with four corner rails of 8.5 mm. The rail ends standing 6.5 mm proud of the end faces, the 40 x 80 mm triple-junction
cells with cropped corners (seven per body face), the wings hinged at one end, and the 17 cm UHF whips (a quarter wave at
the 437 MHz amateur band) are typical of commercial 3U parts; they are representative values, not one product.
https://www.nasa.gov/wp-content/uploads/2018/01/cubesatdesignspecificationrev14_12022-02-09.pdf

Units are metres. Blender's +Z (the long axis) becomes Godot's +Y on export.

Godot nodes (each with its origin on its hinge, so code can also drive them):
    Wing_PX, Wing_NX, Wing_PY, Wing_NY   rotate 90 degrees outward about their hinge at the -Z end
    Antenna_0..3                         scale along their length from stowed to 17 cm
Animation "deploy" (frames 1-72 at 24 fps, 3 s): antennas unroll, then the wings swing open one after another.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "models", "cubesat_3u.glb"))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER_DIR = argv[argv.index("--render") + 1] if "--render" in argv else None

# --- Dimensions (CDS Rev 14 for the envelope; the rest representative) ---
W = 0.100            # body width
L = 0.3405           # body length (3U)
RAIL = 0.0085        # rail width
FOOT = 0.0065        # rail end standing proud of the end faces
PCB = 0.0016         # solar panel substrate
CELL_W, CELL_H, CROP = 0.080, 0.040, 0.006
N_CELLS = 7
WING_GAP = 0.0012    # stowed wing standing off the body panel
WHIP = 0.170         # UHF quarter wave
FPS, END = 24, 72

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.name = "deploy"
scn.render.fps = FPS
scn.frame_start, scn.frame_end = 1, END


# --- Materials (glTF metallic-roughness only) ---
def material(name, rgb, metal=0.0, rough=0.5, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 1.0
    return m

M = {
    "rail": material("Anodized aluminium", (0.62, 0.60, 0.57), 1.0, 0.38),
    "frame": material("Black anodized frame", (0.035, 0.035, 0.04), 0.6, 0.45),
    "pcb": material("Panel substrate", (0.04, 0.06, 0.05), 0.0, 0.55),
    "cell": material("Triple-junction cell", (0.025, 0.045, 0.16), 0.55, 0.18),
    "bus": material("Cell busbar", (0.80, 0.80, 0.78), 1.0, 0.25),
    "gold": material("Gold plating", (1.0, 0.71, 0.29), 1.0, 0.22),
    "ceramic": material("Patch ceramic", (0.86, 0.84, 0.78), 0.0, 0.4),
    "whip": material("Tape spring steel", (0.78, 0.77, 0.74), 1.0, 0.3),
    "glass": material("Lens glass", (0.02, 0.03, 0.05), 0.0, 0.04),
    "hinge": material("Hinge steel", (0.55, 0.55, 0.56), 1.0, 0.3),
}


M["whip"].use_backface_culling = False


# --- Mesh helpers ---
def new_obj(name, bm, mat, parent=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    scn.collection.objects.link(ob)
    if parent:
        ob.parent = parent
    return ob

def box(name, size, center, mat, parent=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    ob = new_obj(name, bm, mat, parent)
    if bevel:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width, mod.segments, mod.limit_method = bevel, 1, "ANGLE"
    return ob

def cylinder(name, r, depth, center, mat, parent=None, segs=24, axis="Z"):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    ob = new_obj(name, bm, mat, parent)
    for p in ob.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    return ob

def cell_array(name, length, z0, parent, n=N_CELLS):
    """Cells with cropped corners and a busbar, on the local XY plane facing +Z, starting at y = z0."""
    pitch = length / n
    bm_c, bm_b = bmesh.new(), bmesh.new()
    for i in range(n):
        cy = z0 + pitch * (i + 0.5)
        hw, hh, c = CELL_W / 2, CELL_H / 2, CROP
        pts = [(-hw + c, -hh), (hw - c, -hh), (hw, -hh + c), (hw, hh - c),
               (hw - c, hh), (-hw + c, hh), (-hw, hh - c), (-hw, -hh + c)]
        bm_c.faces.new([bm_c.verts.new((x, cy + y, 0.0002)) for x, y in pts])
        y = cy + hh - 0.0035
        bm_b.faces.new([bm_b.verts.new(v) for v in
                        ((-hw + c, y, 0.0004), (hw - c, y, 0.0004), (hw - c, y + 0.0015, 0.0004), (-hw + c, y + 0.0015, 0.0004))])
    cells = new_obj(name + "_cells", bm_c, M["cell"], parent)
    bus = new_obj(name + "_busbars", bm_b, M["bus"], parent)
    return cells, bus

def face_frame(rot_z):
    """Matrix placing a local panel (XY plane, +Z outward, Y along the body) on body side rotated rot_z about Z."""
    return Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Rotation(math.pi / 2, 4, "Z")


# --- Body ---
root = bpy.data.objects.new("CubeSat3U", None)
scn.collection.objects.link(root)

h = W / 2 - RAIL / 2
for i, (sx, sy) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
    box(f"Rail_{i}", (RAIL, RAIL, L), (sx * h, sy * h, 0), M["rail"], root, bevel=0.0007)
    # separation spring plungers on two rails at +Z, as on real units
    if i in (0, 2):
        cylinder(f"Spring_{i}", 0.0022, 0.004, (sx * h, sy * h, L / 2 + 0.002), M["hinge"], root, segs=12)

inner = W - 2 * RAIL
face_len = L - 2 * FOOT
# Internal frame closes the corners behind the panels
box("Frame", (W - 0.008, W - 0.008, face_len), (0, 0, 0), M["frame"], root)

# Body-mounted solar panels, one per side
SIDES = {"PX": 0.0, "PY": math.pi / 2, "NX": math.pi, "NY": -math.pi / 2}
for tag, rz in SIDES.items():
    holder = bpy.data.objects.new(f"BodyPanel_{tag}", None)
    scn.collection.objects.link(holder)
    holder.parent = root
    holder.matrix_world = Matrix.Translation(face_frame(rz) @ Vector((0, 0, W / 2 - 0.0012))) @ face_frame(rz)
    box(f"BodyPanel_{tag}_pcb", (inner, face_len, PCB), (0, 0, -PCB / 2), M["pcb"], holder)
    cell_array(f"BodyPanel_{tag}", face_len - 0.020, -(face_len - 0.020) / 2, holder)

# +Z end: antenna deployment module with a gold-plated GPS patch
z_top = L / 2 - FOOT
box("AntennaModule", (inner + 0.004, inner + 0.004, 0.007), (0, 0, z_top - 0.0035 + 0.002), M["frame"], root)
box("GPSPatch", (0.025, 0.025, 0.004), (0, 0, z_top + 0.004), M["ceramic"], root, bevel=0.0008)
box("GPSPatch_gold", (0.018, 0.018, 0.0006), (0, 0, z_top + 0.0063), M["gold"], root)

# -Z end: aluminium end plate with an Earth-observing camera
z_bot = -L / 2 + FOOT
box("EndPlate", (inner + 0.004, inner + 0.004, 0.003), (0, 0, z_bot + 0.0015 - 0.002), M["rail"], root, bevel=0.0005)
cylinder("CameraBarrel", 0.016, 0.012, (0.012, 0.012, z_bot - 0.006), M["frame"], root, segs=32)
cylinder("CameraLens", 0.0115, 0.0012, (0.012, 0.012, z_bot - 0.0122), M["glass"], root, segs=32)
cylinder("CameraRing", 0.0135, 0.0008, (0.012, 0.012, z_bot - 0.0118), M["gold"], root, segs=32)


# --- Deployable wings: hinged at the -Z end, cells face inward when stowed and toward +Z when deployed ---
wings = []
wing_len = L - 2 * FOOT - 0.004
for tag, rz in SIDES.items():
    # Hinge axis runs along the body side at the -Z end, just outside the rails
    out = W / 2 + WING_GAP + PCB
    hinge = Matrix.Rotation(rz, 4, "Z") @ Matrix.Translation((out, 0, z_bot + 0.002))
    wing = bpy.data.objects.new(f"Wing_{tag}", None)
    scn.collection.objects.link(wing)
    wing.parent = root
    wing.matrix_world = hinge
    wing.rotation_mode = "XYZ"
    # Local frame: wing extends along +Z (stowed, up the body); cells on its -X face (toward the body)
    box(f"Wing_{tag}_pcb", (PCB, inner, wing_len), (-PCB / 2, 0, wing_len / 2), M["pcb"], wing)
    # Back face: black frame edge strips that read as a real panel
    box(f"Wing_{tag}_edge", (0.0008, inner, 0.004), (0.0004, 0, wing_len - 0.002), M["frame"], wing)
    holder = bpy.data.objects.new(f"Wing_{tag}_face", None)
    scn.collection.objects.link(holder)
    holder.parent = wing
    holder.matrix_parent_inverse = Matrix.Identity(4)
    holder.matrix_basis = (Matrix.Translation((-PCB, 0, 0)) @ Matrix.Rotation(-math.pi / 2, 4, "Y")
                           @ Matrix.Rotation(-math.pi / 2, 4, "Z"))
    cell_array(f"Wing_{tag}", wing_len - 0.016, 0.008, holder)
    for s in (-1, 1):
        cylinder(f"Wing_{tag}_hinge{s}", 0.0018, 0.010, (0, s * inner * 0.32, 0), M["hinge"], wing, segs=12, axis="Y")
    wings.append(wing)

# --- UHF tape antennas, from the module corners; stowed coiled (scaled down), deployed radially ---
antennas = []
for i in range(4):
    ang = math.pi / 4 + i * math.pi / 2
    ant = bpy.data.objects.new(f"Antenna_{i}", None)
    scn.collection.objects.link(ant)
    ant.parent = root
    ant.matrix_world = (Matrix.Translation((math.cos(ang) * inner * 0.42, math.sin(ang) * inner * 0.42, z_top + 0.0058))
                        @ Matrix.Rotation(ang, 4, "Z"))
    # tape: thin, slightly curved strip along local +X
    bm = bmesh.new()
    wdt, curve = 0.003, 0.0006
    for x0, x1 in ((0, WHIP),):
        vs = [bm.verts.new((x0, -wdt / 2, 0)), bm.verts.new((x0, 0, curve)), bm.verts.new((x0, wdt / 2, 0)),
              bm.verts.new((x1, -wdt / 2, 0)), bm.verts.new((x1, 0, curve)), bm.verts.new((x1, wdt / 2, 0))]
        bm.faces.new((vs[0], vs[3], vs[4], vs[1]))
        bm.faces.new((vs[1], vs[4], vs[5], vs[2]))
    whip = new_obj(f"Antenna_{i}_tape", bm, M["whip"], ant)  # a thin tape, seen from both sides
    whip.matrix_parent_inverse = Matrix.Identity(4)
    antennas.append(ant)


# --- Animation "deploy" ---
STOWED_SCALE = 0.06
SIDES_RZ = list(SIDES.values())
for i, ant in enumerate(antennas):
    t0 = 1 + i * 3
    ant.scale = (STOWED_SCALE, 1, 1)
    ant.keyframe_insert("scale", frame=1)
    ant.keyframe_insert("scale", frame=t0)
    ant.scale = (1, 1, 1)
    ant.keyframe_insert("scale", frame=t0 + 14)

for i, wing in enumerate(wings):
    t0 = 22 + i * 8
    wing.rotation_euler = (0, 0, SIDES_RZ[i])
    wing.keyframe_insert("rotation_euler", frame=1)
    wing.keyframe_insert("rotation_euler", frame=t0)
    # swing outward about the local Y (hinge) axis: the wing's +Z goes to +X, outward
    wing.rotation_euler = (0, math.radians(90), SIDES_RZ[i])
    wing.keyframe_insert("rotation_euler", frame=t0 + 22)

scn.frame_set(1)


# --- Export ---
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_apply=True, export_yup=True,
    export_animations=True, export_animation_mode="SCENE", export_anim_scene_split_object=False, export_force_sampling=True,
    export_materials="EXPORT", export_cameras=False, export_lights=False,
)
print("EXPORTED", OUT, os.path.getsize(OUT), "bytes")


# --- Optional preview renders ---
if RENDER_DIR:
    os.makedirs(RENDER_DIR, exist_ok=True)
    world = bpy.data.worlds.new("Space")
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.006, 0.007, 0.012, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.data.angle, sun.data.color = 5.0, math.radians(0.6), (1.0, 0.96, 0.9)
    sun.rotation_euler = (math.radians(50), math.radians(-25), math.radians(35))
    scn.collection.objects.link(sun)
    fill = bpy.data.objects.new("EarthGlow", bpy.data.lights.new("EarthGlow", "AREA"))
    fill.data.energy, fill.data.size, fill.data.color = 6.0, 1.0, (0.45, 0.62, 1.0)
    fill.location = (-0.3, -0.5, -0.6)
    fill.rotation_euler = (Vector((0, 0, 0)) - fill.location).to_track_quat("-Z", "Y").to_euler()
    scn.collection.objects.link(fill)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.lens = 55
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 48
    scn.cycles.use_denoising = True
    scn.render.resolution_x, scn.render.resolution_y = 1000, 1000
    scn.view_settings.view_transform = "AgX"
    for name, frame, loc, target in (("stowed", 1, (0.55, -0.62, 0.38), (0, 0, 0)),
                                     ("deployed", END, (0.95, -1.05, 0.75), (0, 0, -0.02))):
        scn.frame_set(frame)
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(RENDER_DIR, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", scn.render.filepath)
