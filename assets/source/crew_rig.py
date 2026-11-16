"""A skeleton for each cuy of the crew (issue #66), so the story can move their arms and legs.

Takes assets/models/crew/crew_<id>_meshy.glb and writes assets/models/crew/crew_<id>_rig.glb with an armature:
hips, spine, and for each side an arm, a hand, a leg and a foot (".L" is the cuy's left, +X; the cuyes face -Y in
Blender). The parts built separately (sleeves, hands, mitts, legs, boots, the torso, the coat, the vest...) ride
their bone rigidly; the head and its parts stay free (scripts/story/cuy_actor.gd moves the head itself, after the
spine). Rumi's body is one mesh (a TRELLIS draft; docs/design/crew/README.md), so it is skinned: each vertex is weighted to
the bones by where it is, with soft blends at the shoulders, wrists, hips and ankles.

Run: blender -b --factory-startup --python assets/source/crew_rig.py -- <repo root> [ids...]
"""
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.getcwd()
ARGS = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
CREW = ARGS or ["rumi", "killa", "inti", "wayra"]
HEAD = ("Head", "Brow", "Eye", "Glint", "Mouth", "Nose", "Whisker", "Ear", "Lid", "Tuft", "Goggle", "Headband",
        "CupRim", "Mic")
ARM = ("Arm", "Sleeve", "Cuff")
HAND = ("Hand", "Thumb", "Mitt")
LEG = ("Leg",)
FOOT = ("Boot", "Sole")


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def box(objs):
    ws = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    mn = Vector((min(w.x for w in ws), min(w.y for w in ws), min(w.z for w in ws)))
    mx = Vector((max(w.x for w in ws), max(w.y for w in ws), max(w.z for w in ws)))
    return mn, mx


def centre(objs):
    mn, mx = box(objs)
    return (mn + mx) / 2


def named(meshes, prefixes, side=None):
    out = []
    for o in meshes:
        if not o.name.startswith(prefixes):
            continue
        if any(o.name.startswith(p) for p in HEAD):
            continue
        c = centre([o])
        if side is None or (c.x > 0) == (side > 0):
            out.append(o)
    return out


def landmarks(meshes, cid):
    """Shoulder, wrist, hand, hip, ankle and toe points of each side, from the parts or (Rumi) from the body."""
    head = [o for o in meshes if o.name == "Head"]
    neck_z = box(head)[0].z + 0.02 if head else 0.6
    L = {"neck_z": neck_z}
    if cid == "rumi":
        body = [o for o in meshes if o.name == "Body"][0]
        ws = [body.matrix_world @ v.co for v in body.data.vertices]
        # the arms are above the belt (z > 0.4); below it, the tool pouches and the holster stick out as far as the
        # hands do, so the hands are measured only above the belt (slices of the mesh: the arm runs from about
        # x 0.18, z 0.60 at the shoulder down to x 0.41, z 0.44 at the hand)
        for s in (-1, 1):
            arm = [w for w in ws if w.z > 0.41 and w.z < 0.6 and w.x * s > 0.33]
            hz = sum(w.z for w in arm) / len(arm)
            hy = sum(w.y for w in arm) / len(arm)
            hx = max(w.x * s for w in arm)
            feet = [w for w in ws if w.z < 0.08 and w.x * s > 0.03]
            fx = sum(w.x for w in feet) / len(feet)
            fy = sum(w.y for w in feet) / len(feet)
            L[s] = {"shoulder": Vector((s * 0.18, hy, 0.6)), "wrist": Vector((s * (hx - 0.07), hy, hz + 0.03)),
                    "hand": Vector((s * hx, hy, hz)), "hip": Vector((fx, fy + 0.02, 0.24)),
                    "ankle": Vector((fx, fy + 0.02, 0.08)), "toe": Vector((fx, fy - 0.1, 0.03))}
        L["hip_z"] = 0.24
        return L
    hip_z = 0.0
    for s in (-1, 1):
        arm = named(meshes, ARM, s)
        hand = named(meshes, HAND, s)
        leg = [o for o in named(meshes, LEG, s) if not o.name.startswith("LegStripe")]
        foot = named(meshes, FOOT, s)
        amn, amx = box(arm)
        inner = Vector((amn.x if s > 0 else amx.x, (amn.y + amx.y) / 2, amx.z - 0.05))
        outer = Vector((amx.x if s > 0 else amn.x, (amn.y + amx.y) / 2, amn.z + 0.05))
        lmn, lmx = box(leg)
        fc = centre(foot)
        fmn, fmx = box(foot)
        L[s] = {"shoulder": inner, "wrist": outer, "hand": centre(hand),
                "hip": Vector(((lmn.x + lmx.x) / 2, (lmn.y + lmx.y) / 2, lmx.z)),
                "ankle": Vector((fc.x, fc.y + 0.02, fmx.z)), "toe": Vector((fc.x, fmn.y, fc.z))}
        hip_z = max(hip_z, lmx.z)
    L["hip_z"] = hip_z
    return L


def make_armature(L):
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.object
    arm.name = "Rig"
    arm.data.name = "Rig"
    eb = arm.data.edit_bones
    eb.remove(eb[0])

    def bone(name, h, t, parent=None):
        b = eb.new(name)
        b.head = h
        b.tail = t
        if parent:
            b.parent = eb[parent]
        return b

    hz = L["hip_z"]
    bone("hips", (0, 0, hz * 0.5), (0, 0, hz + 0.02))
    bone("spine", (0, 0, hz + 0.02), (0, 0, L["neck_z"]), "hips")
    for s, tag in ((1, "L"), (-1, "R")):
        P = L[s]
        bone("arm." + tag, P["shoulder"], P["wrist"], "spine")
        bone("hand." + tag, P["wrist"], P["hand"] + (P["hand"] - P["wrist"]) * 0.3, "arm." + tag)
        bone("leg." + tag, P["hip"], P["ankle"], "hips")
        bone("foot." + tag, P["ankle"], P["toe"], "leg." + tag)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def attach(o, arm, bone_name):
    mw = o.matrix_world.copy()
    o.parent = arm
    o.parent_type = "BONE"
    o.parent_bone = bone_name
    o.matrix_world = mw


def skin_rumi(body, arm, L):
    """Weights by position: arms past the shoulders, hands past the wrists, legs below the hips, feet below the
    ankles, the rest to the spine (above the hips) or the hips."""
    names = ["hips", "spine"] + [b + "." + t for t in ("L", "R") for b in ("arm", "hand", "leg", "foot")]
    groups = {n: body.vertex_groups.new(name=n) for n in names}
    mw = body.matrix_world
    hz = L["hip_z"]
    for v in body.data.vertices:
        w = mw @ v.co
        s = 1 if w.x > 0 else -1
        tag = "L" if s > 0 else "R"
        P = L[s]
        weights = {}
        ax = abs(w.x)
        # the arm: near the segment from the shoulder to the hand, and above the belt
        a, b = P["shoulder"], P["hand"]
        ab = b - a
        t = max(0.0, min(1.0, (w - a).dot(ab) / ab.length_squared))
        d = (w - (a + ab * t)).length
        arm_k = (1 - smooth(0.065, 0.1, d)) * smooth(0.0, 0.2, t) * smooth(0.385, 0.42, w.z)
        hand_k = smooth(0.62, 0.8, t)
        leg_k = (1 - smooth(hz - 0.06, hz + 0.02, w.z)) * smooth(0.02, 0.06, ax)
        foot_k = 1 - smooth(P["ankle"].z - 0.02, P["ankle"].z + 0.03, w.z)
        torso = 1 - arm_k
        if leg_k > 0:
            weights["leg." + tag] = leg_k * (1 - foot_k) * torso
            weights["foot." + tag] = leg_k * foot_k * torso
        weights["hips" if w.z < hz + 0.08 else "spine"] = (1 - leg_k) * torso
        if arm_k > 0:
            weights["arm." + tag] = arm_k * (1 - hand_k)
            weights["hand." + tag] = arm_k * hand_k
        total = sum(weights.values()) or 1.0
        for n, k in weights.items():
            if k > 1e-4:
                groups[n].add([v.index], k / total, "REPLACE")
    mw0 = body.matrix_world.copy()
    body.parent = arm
    body.matrix_world = mw0
    mod = body.modifiers.new("Rig", "ARMATURE")
    mod.object = arm


def rig(cid):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "crew", "crew_%s_meshy.glb" % cid))
    # the import may put a parent empty above the meshes: keep the world positions, drop the empties
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.parent:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        if o.type == "EMPTY":
            bpy.data.objects.remove(o)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    L = landmarks(meshes, cid)
    arm = make_armature(L)
    for o in meshes:
        n = o.name
        if n.startswith(HEAD):
            continue
        if cid == "rumi" and n == "Body":
            skin_rumi(o, arm, L)
            continue
        c = centre([o])
        tag = "L" if c.x > 0 else "R"
        if n.startswith(HAND):
            attach(o, arm, "hand." + tag)
        elif n.startswith(ARM):
            attach(o, arm, "arm." + tag)
        elif n.startswith(FOOT):
            attach(o, arm, "foot." + tag)
        elif n.startswith(LEG) and not n.startswith("LegStripe"):
            attach(o, arm, "leg." + tag)
        elif n.startswith("LegStripe"):
            attach(o, arm, "leg." + tag)
        elif c.z < L["hip_z"]:
            attach(o, arm, "hips")
        else:
            attach(o, arm, "spine")
    out = os.path.join(ROOT, "assets", "models", "crew", "crew_%s_rig.glb" % cid)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_apply=False,
                              export_skins=True, export_animations=False, export_vertex_color="ACTIVE")
    print("wrote", out, {k: (tuple(round(x, 3) for x in v["shoulder"]) if isinstance(v, dict) else v) for k, v in L.items()})


for c in CREW:
    rig(c)
