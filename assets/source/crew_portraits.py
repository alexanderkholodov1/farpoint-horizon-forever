"""Portraits of the cuy crew for the story scenes (issue #66): each crew model (assets/models/crew/crew_<id>_meshy.glb)
rendered from the front, head and shoulders, on a transparent background, 512 x 512.

Run: blender -b --factory-startup --python assets/source/crew_portraits.py -- <repo root>
Writes assets/story/portraits/<id>.png.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.getcwd()
CREW = ["rumi", "killa", "inti", "wayra"]
OUT = os.path.join(ROOT, "assets", "story", "portraits")
os.makedirs(OUT, exist_ok=True)


def render(cid):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "crew", "crew_%s_meshy.glb" % cid))
    zs = []
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            zs += [(o.matrix_world @ v.co).z for v in o.data.vertices]
    top = max(zs)
    height = top - min(zs)
    centre_z = top - height * 0.2           # the head: the top fifth of the figure, a little below the crown
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 48
    scn.cycles.use_denoising = True
    scn.render.resolution_x = 512
    scn.render.resolution_y = 512
    scn.render.film_transparent = True
    scn.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.78, 0.85, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    for rot, energy in (((50, 0, -30), 2.6), ((65, 0, 150), 0.8)):
        bpy.ops.object.light_add(type="SUN")
        s = bpy.context.object
        s.data.energy = energy
        s.rotation_euler = tuple(math.radians(a) for a in rot)
    bpy.ops.object.camera_add(location=(0.0, -3.0, centre_z))
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = height * 0.48
    cam.rotation_euler = (math.radians(90), 0, 0)
    scn.camera = cam
    scn.render.filepath = os.path.join(OUT, "%s.png" % cid)
    bpy.ops.render.render(write_still=True)
    print("wrote", cid)


for c in CREW:
    render(c)
