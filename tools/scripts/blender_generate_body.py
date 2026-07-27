#!/usr/bin/env python3
"""
Blender Pipeline: Human Body → USDZ for xT

Produces the body meshes only. Injection-zone mapping is NOT done here — see
tools/zonebake, which bakes a per-vertex zone map from the exported USDZ. After
regenerating a mesh you must re-run zonebake, because the baked map is keyed to the
mesh's vertex order.

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

The mesh is emitted in a canonical orientation — Z up, head at max Z, feet on Z = 0,
facing +Y — and normalize_body asserts it rather than assuming it.

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
# Zone definitions have moved.
#
# This script no longer maps injection zones. Zone assignment now lives in
# tools/zonebake, which partitions the exported mesh surface by geodesic distance
# from seeds authored in absolute world metres (tools/zonebake/Sources/zonebake/ZoneSeeds.swift).
#
# The table that used to live here placed each zone as a sphere centre in coordinates
# normalized to the mesh bounding box, and assigned any vertex within `cr * 1.2` to it.
# That approach was the bug:
#
#   * The bounding box is not centred on the body — measured world X runs -0.289..+0.262,
#     so the midline sits at fraction 0.5245 and every zone authored at "0.50" was 1.4 cm
#     onto the body's right.
#   * The documented depth convention (ny=0 back, ny=1 front) did not match the mesh,
#     mirroring every zone about the coronal mid-plane.
#   * Fractions cannot express pose. The arms hang at the sides, so at forearm height the
#     arm's entire depth range is negative; a "front of forearm" authored as a high depth
#     fraction lands behind the body.
#   * Euclidean proximity is wrong on a surface. A hand is ~4 cm from a thigh through the
#     air but most of a metre away along skin, which let the wrist zones claim 14% of the
#     whole mesh.
#
# The 49 zone labels themselves are a storage contract (InjectionSite.zoneLabel is the
# migration key for dose history) and are generated into xT/Shared/ZoneID.swift by zonebake.
# ---------------------------------------------------------------------------




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
def detect_orientation(verts):
    """Determines which end of a Z-up mesh is the head, and which way it faces.

    Returns (head_at_max_z, front_y_sign).

    Both tests use measured geometry rather than assumptions, because assuming is what
    caused the zone-mapping bug this pipeline is being repaired for:

      * The feet end is much wider laterally than the head end — two feet spread apart
        versus a crown. Measured on the source meshes: 4.67 vs 1.67 units, a 2.8x ratio.
      * The feet point forward: the sole/toe slice reaches ~10 cm further forward than
        the ankle slice above it, while reaching only ~0.5 mm further back. (A nose
        protrusion test at head height is *not* reliable — the occiput extends about as
        far back as the nose does forward.)
    """
    zs = [v.z for v in verts]
    lo_z, hi_z = min(zs), max(zs)
    height = hi_z - lo_z
    if height <= 0.01:
        raise RuntimeError("degenerate mesh height; cannot determine orientation")

    def lateral_width(z0, z1):
        xs = [v.x for v in verts if z0 <= v.z <= z1]
        return (max(xs) - min(xs)) if xs else 0.0

    band = height * 0.06
    width_low = lateral_width(lo_z, lo_z + band)
    width_high = lateral_width(hi_z - band, hi_z)
    head_at_max_z = width_high < width_low

    def depth_range(frac_a, frac_b):
        """Depth extent of a slice, measured as fractions of height up from the feet."""
        if head_at_max_z:
            z0, z1 = lo_z + height * frac_a, lo_z + height * frac_b
        else:
            z0, z1 = hi_z - height * frac_b, hi_z - height * frac_a
        ys = [v.y for v in verts if z0 <= v.z <= z1]
        return (min(ys), max(ys)) if ys else None

    foot = depth_range(0.0, 0.035)
    ankle = depth_range(0.035, 0.075)
    if foot is None or ankle is None:
        raise RuntimeError("could not sample foot/ankle slices; cannot determine facing")
    front_y_sign = 1.0 if (foot[1] - ankle[1]) >= (ankle[0] - foot[0]) else -1.0

    return head_at_max_z, front_y_sign


def normalize_body(body, apply_y_rotation=False):
    """Normalizes any body mesh to TOTAL_HEIGHT in a canonical orientation.

    Canonical means: Z up with the head at max Z, feet on Z = 0, and the body facing +Y.
    This is asserted, not assumed.

    The previous version simply pinned the mesh's minimum Z to zero to "put the feet on
    the floor", never checking which end was the head. The meshes that shipped are in fact
    stored upside down and facing -Y, which mirrored every injection zone about the coronal
    mid-plane: fitting all eight axis-sign combinations against the shipped centroids cut
    mean placement error from 0.108 to 0.047 once the depth axis was flipped. Nothing caught
    it because a second inversion in the app cancelled the first for the height axis alone,
    so heights looked plausible while depth and normals were wrong.

    apply_y_rotation=True for Y-up OBJ imports (MakeHuman .obj), not MPFB.
    """
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode='OBJECT')

    if apply_y_rotation:
        body.rotation_euler.x = math.radians(-90)
        bpy.ops.object.transform_apply(rotation=True)

    verts = [body.matrix_world @ v.co for v in body.data.vertices]
    head_at_max_z, front_y_sign = detect_orientation(verts)
    print(f"  orientation: head at {'max' if head_at_max_z else 'min'} Z, "
          f"front at {'+' if front_y_sign > 0 else '-'}Y")

    # Canonicalize with proper rotations only. A 180 degree rotation flips exactly two axes,
    # so it can never mirror the mesh — unlike negating a single scale component, which
    # inverts winding order and the normal matrix.
    if not head_at_max_z and front_y_sign > 0:
        # Upside down, facing +Y: flip Z and X together.
        body.rotation_euler = (0.0, math.radians(180), 0.0)
    elif not head_at_max_z and front_y_sign < 0:
        # Upside down, facing -Y: flip Z and Y together.
        body.rotation_euler = (math.radians(180), 0.0, 0.0)
    elif head_at_max_z and front_y_sign < 0:
        # Upright but facing backwards: spin about Z.
        body.rotation_euler = (0.0, 0.0, math.radians(180))
    if tuple(body.rotation_euler) != (0.0, 0.0, 0.0):
        bpy.ops.object.transform_apply(rotation=True)

    verts = [body.matrix_world @ v.co for v in body.data.vertices]
    min_z = min(v.z for v in verts)
    max_z = max(v.z for v in verts)
    current_height = max_z - min_z
    if current_height > 0.01 and abs(current_height - TOTAL_HEIGHT) > 0.01:
        s = TOTAL_HEIGHT / current_height
        body.scale = (s, s, s)
    # Feet to Z = 0. Safe now that the head is known to be at max Z.
    body.location.z = -min_z * body.scale.z
    bpy.ops.object.transform_apply(location=True, scale=True)

    # Assert the canonical result rather than trusting the steps above.
    verts = [body.matrix_world @ v.co for v in body.data.vertices]
    head_at_max_z, front_y_sign = detect_orientation(verts)
    zs = [v.z for v in verts]
    if not head_at_max_z:
        raise RuntimeError("normalize_body: head is still at min Z after canonicalization")
    if front_y_sign < 0:
        raise RuntimeError("normalize_body: body still faces -Y after canonicalization")
    if abs(min(zs)) > 1e-3:
        raise RuntimeError(f"normalize_body: feet are at Z={min(zs):.4f}, expected 0")
    if abs((max(zs) - min(zs)) - TOTAL_HEIGHT) > 1e-3:
        raise RuntimeError(f"normalize_body: height is {max(zs) - min(zs):.4f}, expected {TOTAL_HEIGHT}")
    print(f"  canonical: head at max Z, front +Y, feet at Z=0, height {max(zs) - min(zs):.4f}")

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
    # Blender's default wm.obj_import treats OBJ as Y-up, forward=-Z, and expresses the
    # conversion as an *unapplied* rotation on the object rather than baking it into the mesh.
    #
    # That detail is the origin of the whole zone-mapping bug. This function used to "fix the
    # facing" with `for v in body.data.vertices: v.co.y = -v.co.y`, intending to move the front
    # from -Y to +Y. But `v.co` is *local*, and with the import's 90 degree X rotation still
    # pending, local Y is the height axis in world space. So the flip turned the body upside
    # down and left the facing untouched — which is precisely how the shipped assets came to be
    # stored head-down and still facing -Y.
    #
    # The fix is to stop hand-flipping axes. Apply the import transform so local and world
    # agree, then let normalize_body detect the orientation and canonicalize it.
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
    # Bake the importer's axis conversion into the mesh so local == world from here on.
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
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
    # No vertex groups exist any more, so the exporter can no longer emit the 49
    # `primvars:<Zone_Name>` weight arrays the shipped assets carry. Those were dead payload:
    # no Swift code referenced `primvar`, `faceIndex`, or `textureCoordinates`, so nothing
    # ever read them. Zone membership now lives in the baked zone map instead.
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
    obj_path         = os.path.join(ASSETS_DIR, f"base_body_{body_type_name}.obj")

    mpfb_used = False
    if os.path.isfile(obj_path):
        print(f"\n[1/4] Importing manual base mesh: {obj_path}")
        body = import_base_mesh(obj_path, body_type_name)
        print(f"  Imported: {len(body.data.vertices):,} verts, {len(body.data.polygons):,} faces")
    elif MPFB_AVAILABLE:
        print(f"\n[1/4] Generating MakeHuman body via MPFB2 ({body_type_name})...")
        body = create_mpfb_body(body_type_name)
        print(f"  MPFB: {len(body.data.vertices):,} verts, {len(body.data.polygons):,} faces")
        mpfb_used = True
    else:
        print(f"\n[1/4] MPFB unavailable — building procedural body (fallback)...")
        print(f"       Install MPFB2 with: scripts/install_mpfb.sh")
        body = create_procedural_body(body_type_name)
        print(f"  Procedural: {len(body.data.vertices):,} verts, {len(body.data.polygons):,} faces")

    if not mpfb_used:
        # MPFB meshes already have clean MakeHuman UVs — skip re-unwrap
        print("\n[2/4] UV unwrapping...")
        uv_unwrap(body)
    else:
        print("\n[2/4] UV unwrap skipped (MPFB mesh already has UVs)")

    print("\n[3/4] Assigning skin material...")
    assign_material(body)

    print("\n[4/4] Exporting USDZ...")
    export_usdz(body, output_usdz)

    print(f"\n  ✓ {body_type_name} done")
    print(f"    Next: run `swift run zonebake {body_type_name}` from tools/zonebake to")
    print(f"    rebake the zone map against this mesh, and check its report and previews.")


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
