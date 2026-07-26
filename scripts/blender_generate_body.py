#!/usr/bin/env python3
"""
Blender Pipeline: Human Body → Segmented USDZ + zone_centroids.json for xT

Run headlessly (all 3 types):
  /opt/homebrew/bin/blender --background --python scripts/blender_generate_body.py

Run a single type:
  /opt/homebrew/bin/blender --background --python scripts/blender_generate_body.py -- neutral
  /opt/homebrew/bin/blender --background --python scripts/blender_generate_body.py -- feminine
  /opt/homebrew/bin/blender --background --python scripts/blender_generate_body.py -- masculine

Source priority (per type):
  1. scripts/assets/base_body_{type}.obj  — manual drop-in (e.g. MakeHuman GUI export)
  2. MPFB2 extension in Blender           — MakeHuman topology, no GUI needed (DEFAULT)
  3. Procedural primitives + voxel remesh — last resort if MPFB2 is not installed

Outputs (per type):
  xT/Resources/Models/body_{type}.usdz
  xT/Resources/Models/zone_centroids_{type}.json

Install MPFB2 first (one-time):
  scripts/install_mpfb.sh
"""

import bpy
import json
import math
import os
import sys

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR    = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR  = os.path.join(ROOT_DIR, "xT", "Resources", "Models")
ASSETS_DIR  = os.path.join(SCRIPT_DIR, "assets")

# ---------------------------------------------------------------------------
# MPFB2 — enable the addon and import services (Z-up mesh, no GUI needed)
# ---------------------------------------------------------------------------
MPFB_AVAILABLE = False
HumanService   = None
TargetService  = None

try:
    bpy.ops.preferences.addon_enable(module="bl_ext.blender_org.mpfb")
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService   as _HS
    from bl_ext.blender_org.mpfb.services.targetservice import TargetService as _TS
    HumanService   = _HS
    TargetService  = _TS
    MPFB_AVAILABLE = True
    print("[MPFB] Available — will use MakeHuman topology")
except Exception as _mpfb_err:
    print(f"[MPFB] Not available ({_mpfb_err})")
    print("[MPFB] Run scripts/install_mpfb.sh, then re-run this script")

# ---------------------------------------------------------------------------
# MPFB gender / macro presets per body type
# MakeHuman convention: 0.0 = most feminine, 1.0 = most masculine
# ---------------------------------------------------------------------------
MPFB_MACROS = {
    "neutral":   {"gender": 0.5, "age": 0.5, "muscle": 0.5, "weight": 0.5, "height": 0.5},
    "feminine":  {"gender": 0.0, "age": 0.5, "muscle": 0.4, "weight": 0.45, "height": 0.48},
    "masculine": {"gender": 1.0, "age": 0.5, "muscle": 0.6, "weight": 0.55, "height": 0.52},
}

# ---------------------------------------------------------------------------
# Procedural fallback proportions (only used when MPFB is absent)
# ---------------------------------------------------------------------------
BODY_TYPES = {
    "neutral":   {"shoulder_width": 0.40, "hip_width": 0.34, "thigh_radius": 0.07,
                  "upper_arm_radius": 0.040, "chest_width": 0.30, "waist_width": 0.24},
    "feminine":  {"shoulder_width": 0.36, "hip_width": 0.38, "thigh_radius": 0.075,
                  "upper_arm_radius": 0.036, "chest_width": 0.29, "waist_width": 0.22},
    "masculine": {"shoulder_width": 0.45, "hip_width": 0.34, "thigh_radius": 0.075,
                  "upper_arm_radius": 0.044, "chest_width": 0.34, "waist_width": 0.27},
}

# ---------------------------------------------------------------------------
# Shared body proportions
# ---------------------------------------------------------------------------
TOTAL_HEIGHT  = 1.65
HEAD_RADIUS   = 0.09
NECK_RADIUS   = 0.045
ARM_LENGTH    = 0.55
LEG_LENGTH    = 0.75
TORSO_LENGTH  = 0.50
SUBDIV_LEVELS = 2

# ---------------------------------------------------------------------------
# Zone definitions — used for vertex-group proximity assignment
# (label, _part_hint, cx, cy, cz, cr) — cx/cy/cz are normalized in full-body bbox
# For a T-pose MakeHuman mesh (Z-up, Y-front):
#   nx=0 → body's right side, nx=1 → body's left side
#   ny=0 → back, ny=1 → front
#   nz=0 → feet, nz=1 → head
# ---------------------------------------------------------------------------

# Coordinates calibrated from live diagnostic on MakeHuman GUI OBJ exports (neutral body).
# MH arm span dominates bbox X (torso is ~48% of total width) so torso zones
# cluster around nx 0.28–0.72.  Arm zones reach only ~nx 0.78–0.90, not 0.90–0.95.
# ny: front = HIGH (close to 1), back = LOW (close to 0)
# nz: feet = 0, head = 1
ZONES = [
    # Torso — upper (chest / shoulders / neck)
    ("Left Shoulder",          "_", 0.69, 0.85, 0.80, 0.10),
    ("Right Shoulder",         "_", 0.31, 0.85, 0.80, 0.10),
    ("Upper Chest",            "_", 0.50, 0.82, 0.78, 0.20),
    ("Left Upper Chest",       "_", 0.70, 0.83, 0.78, 0.11),
    ("Right Upper Chest",      "_", 0.29, 0.83, 0.78, 0.11),
    ("Left Lower Chest",       "_", 0.68, 0.80, 0.73, 0.11),
    ("Right Lower Chest",      "_", 0.31, 0.80, 0.68, 0.12),
    ("Neck",                   "_", 0.50, 0.72, 0.82, 0.15),
    # Torso — lower (abdomen / glutes / ventrogluteal)
    ("Upper Left Abdomen",     "_", 0.61, 0.87, 0.53, 0.10),
    ("Upper Right Abdomen",    "_", 0.42, 0.90, 0.52, 0.10),
    ("Periumbilical",          "_", 0.50, 0.90, 0.59, 0.08),
    ("Lower Left Abdomen",     "_", 0.57, 0.90, 0.48, 0.09),
    ("Lower Right Abdomen",    "_", 0.43, 0.90, 0.48, 0.09),
    ("Left Upper Glute",       "_", 0.60, 0.45, 0.55, 0.09),
    ("Right Upper Glute",      "_", 0.40, 0.45, 0.55, 0.09),
    ("Left Ventrogluteal",     "_", 0.55, 0.67, 0.60, 0.09),
    ("Right Ventrogluteal",    "_", 0.45, 0.67, 0.60, 0.09),
    ("Left Lower Glute",       "_", 0.60, 0.38, 0.49, 0.10),
    ("Right Lower Glute",      "_", 0.40, 0.38, 0.49, 0.10),
    # Arms — left (character's left = positive X)
    # MH GUI T-pose: forearm at nx~0.79, wrist at nx~0.89, nz drops to ~0.55/0.42
    ("Left Deltoid",           "_", 0.75, 0.74, 0.77, 0.09),
    ("Left Upper Arm",         "_", 0.84, 0.70, 0.62, 0.08),
    ("Left Forearm",           "_", 0.79, 0.64, 0.55, 0.09),
    ("Left Inner Wrist",       "_", 0.89, 0.72, 0.42, 0.09),
    ("Left Posterior Deltoid", "_", 0.75, 0.55, 0.77, 0.10),
    ("Left Triceps",           "_", 0.84, 0.55, 0.62, 0.08),
    ("Left Posterior Forearm", "_", 0.80, 0.52, 0.55, 0.09),
    # Arms — right (character's right = negative X)
    ("Right Deltoid",           "_", 0.25, 0.74, 0.77, 0.09),
    ("Right Upper Arm",         "_", 0.16, 0.70, 0.62, 0.08),
    ("Right Forearm",           "_", 0.21, 0.64, 0.55, 0.09),
    ("Right Inner Wrist",       "_", 0.11, 0.72, 0.42, 0.09),
    ("Right Posterior Deltoid", "_", 0.25, 0.55, 0.77, 0.10),
    ("Right Triceps",           "_", 0.16, 0.55, 0.62, 0.08),
    ("Right Posterior Forearm", "_", 0.20, 0.52, 0.55, 0.09),
    # Thighs — left (hamstrings shift to nx~0.65–0.68, not 0.60)
    ("Upper Left Thigh",       "_", 0.60, 0.87, 0.40, 0.09),
    ("Mid Left Thigh",         "_", 0.60, 0.87, 0.33, 0.08),
    ("Lower Left Thigh",       "_", 0.60, 0.87, 0.26, 0.08),
    ("Outer Left Thigh",       "_", 0.64, 0.81, 0.35, 0.08),
    ("Inner Left Thigh",       "_", 0.56, 0.78, 0.35, 0.09),
    ("Upper Left Hamstring",   "_", 0.66, 0.51, 0.37, 0.09),
    ("Mid Left Hamstring",     "_", 0.66, 0.51, 0.30, 0.09),
    ("Lower Left Hamstring",   "_", 0.64, 0.50, 0.23, 0.09),
    # Thighs — right
    ("Upper Right Thigh",      "_", 0.40, 0.87, 0.40, 0.09),
    ("Mid Right Thigh",        "_", 0.40, 0.87, 0.33, 0.08),
    ("Lower Right Thigh",      "_", 0.40, 0.87, 0.26, 0.08),
    ("Outer Right Thigh",      "_", 0.36, 0.81, 0.35, 0.08),
    ("Inner Right Thigh",      "_", 0.44, 0.78, 0.35, 0.09),
    ("Upper Right Hamstring",  "_", 0.34, 0.51, 0.37, 0.09),
    ("Mid Right Hamstring",    "_", 0.34, 0.51, 0.30, 0.09),
    ("Lower Right Hamstring",  "_", 0.36, 0.50, 0.23, 0.09),
]

ZONE_LABELS = {z[0] for z in ZONES}


# ---------------------------------------------------------------------------
# Scene helpers
# ---------------------------------------------------------------------------
def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)


# ---------------------------------------------------------------------------
# Shared normalizer: scale to TOTAL_HEIGHT, feet at Z=0, clean normals
# ---------------------------------------------------------------------------
def normalize_body(body, apply_y_rotation=False):
    """Normalizes any body mesh to TOTAL_HEIGHT.
    apply_y_rotation=True for Y-up OBJ imports (MakeHuman .obj), not MPFB."""
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode='OBJECT')

    if apply_y_rotation:
        body.rotation_euler.x = math.radians(-90)
        bpy.ops.object.transform_apply(rotation=True)

    body_verts = [body.matrix_world @ v.co for v in body.data.vertices]
    min_z = min(v.z for v in body_verts)
    max_z = max(v.z for v in body_verts)
    current_height = max_z - min_z
    if current_height > 0.01 and abs(current_height - TOTAL_HEIGHT) > 0.01:
        s = TOTAL_HEIGHT / current_height
        body.scale = (s, s, s)
    # Feet to Z = 0
    body.location.z = -min_z * body.scale.z
    bpy.ops.object.transform_apply(location=True, scale=True)

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.shade_smooth()


# ---------------------------------------------------------------------------
# Source 1: manual OBJ drop-in
# ---------------------------------------------------------------------------
def import_base_mesh(obj_path, body_type_name):
    """Import a manually-placed OBJ base mesh. Returns mesh object."""
    # Blender's default wm.obj_import treats OBJ as Y-up, forward=-Z:
    #   OBJ Y (height)  → Blender Z  ✓
    #   OBJ X           → Blender X  ✓  (character's left = +X, matches MPFB2)
    #   OBJ +Z (front)  → Blender -Y ✗  (body front ends up at negative Y)
    # Fix: flip Y axis so front = +Y, matching MPFB2 zone conventions.
    bpy.ops.wm.obj_import(filepath=obj_path)
    objs = [o for o in bpy.context.selected_objects if o.type == 'MESH']
    if not objs:
        raise RuntimeError(f"No mesh objects in {obj_path}")
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    if len(objs) > 1:
        bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = f"body_{body_type_name}"
    # Flip Y: negate every vertex's Y coordinate, then restore outward normals
    for v in body.data.vertices:
        v.co.y = -v.co.y
    for p in body.data.polygons:
        p.flip()
    normalize_body(body, apply_y_rotation=False)
    return body


# ---------------------------------------------------------------------------
# Source 2: MPFB2 (MakeHuman topology, no separate app)
# ---------------------------------------------------------------------------
def create_mpfb_body(body_type_name):
    """Generate a MakeHuman body via MPFB2. Returns mesh object.
    MPFB produces a Z-up mesh with feet at Z=0 and height ~1.65 m."""
    macros = MPFB_MACROS.get(body_type_name, MPFB_MACROS["neutral"])

    macro_dict = TargetService.get_default_macro_info_dict()
    for key, value in macros.items():
        if key in macro_dict:
            macro_dict[key] = value

    body = HumanService.create_human(
        mask_helpers=True,
        detailed_helpers=False,
        extra_vertex_groups=False,
        feet_on_ground=True,
        scale=0.1,
        macro_detail_dict=macro_dict,
    )
    body.name = f"body_{body_type_name}"

    # Remove shape keys first (MPFB adds morph shape keys; they block modifier_apply)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    if body.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)

    # Apply modifiers (bakes the Mask so helper geometry is removed permanently)
    for mod in list(body.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except Exception as e:
            print(f"  Warning: could not apply modifier '{mod.name}': {e}")
            body.modifiers.remove(mod)

    # MPFB is already Z-up with feet at Z≈0 and height≈1.65
    normalize_body(body, apply_y_rotation=False)
    return body


# ---------------------------------------------------------------------------
# Source 3: procedural primitives + voxel remesh (last resort)
# ---------------------------------------------------------------------------
def create_procedural_body(body_type_name="neutral"):
    cfg = BODY_TYPES.get(body_type_name, BODY_TYPES["neutral"])
    SHOULDER_WIDTH   = cfg["shoulder_width"]
    HIP_WIDTH        = cfg["hip_width"]
    UPPER_ARM_RADIUS = cfg["upper_arm_radius"]
    THIGH_RADIUS     = cfg["thigh_radius"]

    body_parts = {}

    bpy.ops.mesh.primitive_uv_sphere_add(radius=HEAD_RADIUS,
                                          location=(0, 0, TOTAL_HEIGHT - HEAD_RADIUS))
    head = bpy.context.active_object
    head.name = "head"; head.scale = (1.0, 0.92, 0.88)
    bpy.ops.object.transform_apply(scale=True)
    body_parts["head"] = head

    neck_z = TOTAL_HEIGHT - 2 * HEAD_RADIUS + 0.02
    bpy.ops.mesh.primitive_cylinder_add(radius=NECK_RADIUS, depth=0.08,
                                         location=(0, 0, neck_z), vertices=16)
    neck = bpy.context.active_object; neck.name = "neck"
    neck.scale = (1.0, 0.8, 1.0); bpy.ops.object.transform_apply(scale=True)
    body_parts["neck"] = neck

    torso_top = neck_z - 0.02
    bpy.ops.mesh.primitive_cylinder_add(radius=SHOULDER_WIDTH / 2,
                                         depth=TORSO_LENGTH * 0.45,
                                         location=(0, 0, torso_top - TORSO_LENGTH * 0.225),
                                         vertices=24)
    tu = bpy.context.active_object; tu.name = "torso_upper"
    tu.scale = (1.0, 0.55, 1.0); bpy.ops.object.transform_apply(scale=True)
    body_parts["torso_upper"] = tu

    hip_top = torso_top - TORSO_LENGTH * 0.45
    bpy.ops.mesh.primitive_cylinder_add(radius=HIP_WIDTH / 2,
                                         depth=TORSO_LENGTH * 0.42,
                                         location=(0, 0, hip_top - TORSO_LENGTH * 0.21),
                                         vertices=24)
    tl = bpy.context.active_object; tl.name = "torso_lower"
    tl.scale = (1.0, 0.70, 1.0); bpy.ops.object.transform_apply(scale=True)
    body_parts["torso_lower"] = tl

    arm_top_z = torso_top - 0.02
    for side, x_sign in [("left", -1), ("right", 1)]:
        arm_x = x_sign * (SHOULDER_WIDTH / 2 + UPPER_ARM_RADIUS * 0.8)
        bpy.ops.mesh.primitive_cylinder_add(radius=UPPER_ARM_RADIUS, depth=ARM_LENGTH,
                                             location=(arm_x, 0, arm_top_z - ARM_LENGTH / 2),
                                             vertices=16)
        arm = bpy.context.active_object; arm.name = f"arm_{side}"
        body_parts[f"arm_{side}"] = arm

    leg_top_z = hip_top - TORSO_LENGTH * 0.40 - 0.02
    for side, x_sign in [("left", -1), ("right", 1)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=THIGH_RADIUS, depth=LEG_LENGTH * 0.55,
                                             location=(x_sign * 0.09, 0,
                                                       leg_top_z - LEG_LENGTH * 0.275),
                                             vertices=20)
        leg = bpy.context.active_object; leg.name = f"thigh_{side}"
        bpy.ops.object.transform_apply(scale=True)
        body_parts[f"thigh_{side}"] = leg

    bpy.ops.object.select_all(action='DESELECT')
    for obj in body_parts.values():
        obj.select_set(True)
    bpy.context.view_layer.objects.active = list(body_parts.values())[0]
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = f"body_{body_type_name}"

    mod = body.modifiers.new(name="VoxelRemesh", type='REMESH')
    mod.mode = 'VOXEL'; mod.voxel_size = 0.018; mod.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier="VoxelRemesh")

    mod = body.modifiers.new(name="Subdiv", type='SUBSURF')
    mod.levels = SUBDIV_LEVELS; mod.subdivision_type = 'CATMULL_CLARK'
    bpy.ops.object.modifier_apply(modifier="Subdiv")

    normalize_body(body)
    return body


# ---------------------------------------------------------------------------
# Zone vertex groups
# ---------------------------------------------------------------------------
def create_zone_vertex_groups(body):
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode='OBJECT')

    verts_ws = [body.matrix_world @ v.co for v in body.data.vertices]
    min_x = min(v.x for v in verts_ws); max_x = max(v.x for v in verts_ws)
    min_y = min(v.y for v in verts_ws); max_y = max(v.y for v in verts_ws)
    min_z = min(v.z for v in verts_ws); max_z = max(v.z for v in verts_ws)
    rx = max_x - min_x; ry = max_y - min_y; rz = max_z - min_z

    zone_groups = {label: body.vertex_groups.new(name=label) for label, *_ in ZONES}

    # Build normalized vertex array for fast nearest-neighbour lookup
    norm_verts = []
    for v in body.data.vertices:
        wco = body.matrix_world @ v.co
        norm_verts.append((
            (wco.x - min_x) / rx if rx > 0 else 0.5,
            (wco.y - min_y) / ry if ry > 0 else 0.5,
            (wco.z - min_z) / rz if rz > 0 else 0.5,
        ))

    for i, (nx, ny, nz) in enumerate(norm_verts):
        for label, _, cx, cy, cz, cr in ZONES:
            d = math.sqrt((nx - cx) ** 2 + (ny - cy) ** 2 + (nz - cz) ** 2)
            if d < cr * 1.2:
                w = max(0.0, 1.0 - d / (cr * 1.2))
                zone_groups[label].add([i], w, 'ADD')

    # Diagnostic: for any zone with no assigned vertices, show nearest vertex coords
    gidx_map = {vg.name: vg.index for vg in body.vertex_groups if vg.name in ZONE_LABELS}
    has_verts = set()
    for v in body.data.vertices:
        for g in v.groups:
            for name, idx in gidx_map.items():
                if g.group == idx and g.weight > 0.01:
                    has_verts.add(name)
    empty_zones = [z for z in ZONE_LABELS if z not in has_verts]
    if empty_zones:
        print(f"  DIAG: {len(empty_zones)} empty zones — nearest vertex (nx,ny,nz):")
        for label, _, cx, cy, cz, cr in ZONES:
            if label not in empty_zones:
                continue
            best = min(range(len(norm_verts)),
                       key=lambda i: (norm_verts[i][0]-cx)**2+(norm_verts[i][1]-cy)**2+(norm_verts[i][2]-cz)**2)
            bx, by, bz = norm_verts[best]
            dist = math.sqrt((bx-cx)**2+(by-cy)**2+(bz-cz)**2)
            print(f"    {label:28s}: want({cx:.2f},{cy:.2f},{cz:.2f}) nearest({bx:.2f},{by:.2f},{bz:.2f}) d={dist:.3f} cr={cr}")


# ---------------------------------------------------------------------------
# Export zone centroids (Blender Z-up → SceneKit Y-up)
# SceneKit: X = Blender X, Y = Blender Z, Z = -Blender Y
# Scale: multiply by (1.5 / TOTAL_HEIGHT) to match the app's 1.5 m target height
# ---------------------------------------------------------------------------
def export_zone_centroids(body, output_path):
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode='OBJECT')

    scenekit_scale = 1.5 / TOTAL_HEIGHT
    mesh = body.data
    # calc_normals_split() removed in Blender 5.x — normals are auto-maintained

    centroids = {}
    for vg in body.vertex_groups:
        label = vg.name
        if label not in ZONE_LABELS:
            continue
        gidx = vg.index
        positions, normals = [], []
        for v in mesh.vertices:
            for g in v.groups:
                if g.group == gidx and g.weight > 0.01:
                    wco = body.matrix_world @ v.co
                    positions.append((wco.x * scenekit_scale,
                                      wco.z * scenekit_scale,
                                      -wco.y * scenekit_scale))
                    wn = body.matrix_world.to_3x3() @ v.normal
                    wn.normalize()
                    normals.append((wn.x, wn.z, -wn.y))
                    break
        if not positions:
            continue
        n   = len(positions)
        cx  = sum(p[0] for p in positions) / n
        cy  = sum(p[1] for p in positions) / n
        cz  = sum(p[2] for p in positions) / n
        nx  = sum(v[0] for v in normals) / n
        ny  = sum(v[1] for v in normals) / n
        nz  = sum(v[2] for v in normals) / n
        length = math.sqrt(nx*nx + ny*ny + nz*nz)
        if length > 0:
            nx, ny, nz = nx / length, ny / length, nz / length
        centroids[label] = {
            "pos":    [round(cx, 4), round(cy, 4), round(cz, 4)],
            "normal": [round(nx, 4), round(ny, 4), round(nz, 4)],
        }

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(centroids, f, indent=2)
    print(f"✓ {len(centroids)} zone centroids → {output_path}")


# ---------------------------------------------------------------------------
# UV + Material
# ---------------------------------------------------------------------------
def uv_unwrap(body):
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')


def assign_material(body):
    mat = bpy.data.materials.new(name=f"Skin_{body.name}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.92, 0.78, 0.68, 1.0)
        bsdf.inputs['Roughness'].default_value  = 0.55
        for key in ('Subsurface Weight', 'Subsurface'):
            try:
                if hasattr(bsdf.inputs.get(key, None), 'default_value'):
                    bsdf.inputs[key].default_value = 0.10
            except Exception:
                pass
    if body.data.materials:
        body.data.materials[0] = mat
    else:
        body.data.materials.append(mat)


# ---------------------------------------------------------------------------
# USDZ export
# ---------------------------------------------------------------------------
def export_usdz(body, output_path):
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=output_path,
        export_materials=True,
        export_uvmaps=True,
        export_mesh_colors=True,
        export_normals=True,
        selected_objects_only=True,
        use_instancing=False,
        evaluation_mode='RENDER',
        convert_orientation=True,
        convert_world_material=True,
    )
    print(f"✓ USDZ exported: {output_path}")


# ---------------------------------------------------------------------------
# Per-type build orchestrator
# ---------------------------------------------------------------------------
def build_body_type(body_type_name):
    print("\n" + "=" * 60)
    print(f"  Building: {body_type_name}")
    print("=" * 60)

    clear_scene()

    output_usdz      = os.path.join(OUTPUT_DIR, f"body_{body_type_name}.usdz")
    output_centroids = os.path.join(OUTPUT_DIR, f"zone_centroids_{body_type_name}.json")
    obj_path         = os.path.join(ASSETS_DIR, f"base_body_{body_type_name}.obj")

    mpfb_used = False
    if os.path.isfile(obj_path):
        print(f"\n[1/6] Importing manual base mesh: {obj_path}")
        body = import_base_mesh(obj_path, body_type_name)
        print(f"  Imported: {len(body.data.vertices):,} verts, {len(body.data.polygons):,} faces")
    elif MPFB_AVAILABLE:
        print(f"\n[1/6] Generating MakeHuman body via MPFB2 ({body_type_name})...")
        body = create_mpfb_body(body_type_name)
        print(f"  MPFB: {len(body.data.vertices):,} verts, {len(body.data.polygons):,} faces")
        mpfb_used = True
    else:
        print(f"\n[1/6] MPFB unavailable — building procedural body (fallback)...")
        print(f"       Install MPFB2 with: scripts/install_mpfb.sh")
        body = create_procedural_body(body_type_name)
        print(f"  Procedural: {len(body.data.vertices):,} verts, {len(body.data.polygons):,} faces")

    print(f"\n[2/6] Creating {len(ZONES)} injection zone vertex groups...")
    create_zone_vertex_groups(body)
    gidx_map = {vg.name: vg.index for vg in body.vertex_groups if vg.name in ZONE_LABELS}
    covered_set = set()
    for v in body.data.vertices:
        for g in v.groups:
            for name, idx in gidx_map.items():
                if g.group == idx and g.weight > 0.01:
                    covered_set.add(name)
    print(f"  {len(covered_set)} / {len(ZONES)} zones have assigned vertices")

    if not mpfb_used:
        # MPFB meshes already have clean MakeHuman UVs — skip re-unwrap
        print("\n[3/6] UV unwrapping...")
        uv_unwrap(body)
    else:
        print("\n[3/6] UV unwrap skipped (MPFB mesh already has UVs)")

    print("\n[4/6] Assigning skin material...")
    assign_material(body)

    print("\n[5/6] Exporting USDZ...")
    export_usdz(body, output_usdz)

    print("\n[6/6] Exporting zone centroids JSON...")
    export_zone_centroids(body, output_centroids)

    print(f"\n  ✓ {body_type_name} done")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    argv = sys.argv
    if "--" in argv:
        args = argv[argv.index("--") + 1:]
        requested = [a for a in args if a in BODY_TYPES]
        types_to_build = requested if requested else list(BODY_TYPES.keys())
    else:
        types_to_build = list(BODY_TYPES.keys())

    print("=" * 60)
    print("  xT Body Model Pipeline")
    print(f"  Building: {', '.join(types_to_build)}")
    print(f"  MPFB2:    {'available' if MPFB_AVAILABLE else 'NOT available — run scripts/install_mpfb.sh'}")
    print("=" * 60)

    for body_type_name in types_to_build:
        build_body_type(body_type_name)

    print("\n" + "=" * 60)
    print(f"  ✓ All done! ({len(types_to_build)} body type(s))")
    print("=" * 60)


if __name__ == "__main__":
    main()
