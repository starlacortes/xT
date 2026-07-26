#!/usr/bin/env bash
# Install the MPFB2 Blender extension headlessly.
# Run once before blender_generate_body.py.
#
# Usage:
#   scripts/install_mpfb.sh
#   scripts/install_mpfb.sh /path/to/blender   # custom Blender binary

set -euo pipefail

BLENDER="${1:-/opt/homebrew/bin/blender}"

if [[ ! -x "$BLENDER" ]]; then
    echo "❌  Blender not found at $BLENDER"
    echo "   Install via: brew install --cask blender"
    echo "   Or pass a custom path: $0 /path/to/blender"
    exit 1
fi

echo "Blender: $("$BLENDER" --version 2>/dev/null | head -1)"

# Idempotent: check if already installed
if "$BLENDER" --background --python-expr \
    "import bpy; bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb'); \
     from bl_ext.blender_org.mpfb.services.humanservice import HumanService; print('OK')" \
    2>&1 | grep -q "^OK"; then
    echo "✓ MPFB2 is already installed and importable — nothing to do."
    exit 0
fi

echo "Syncing extension repo..."
"$BLENDER" --online-mode --command extension sync

echo "Installing MPFB2 (~45 MB, may take a moment)..."
"$BLENDER" --online-mode --command extension install mpfb

echo "Verifying..."
result=$("$BLENDER" --background --python-expr \
    "import bpy; bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb'); \
     from bl_ext.blender_org.mpfb.services.humanservice import HumanService; print('OK')" \
    2>&1 | grep "^OK" || echo "FAIL")

if [[ "$result" == "OK" ]]; then
    echo "✓ MPFB2 installed and verified."
    echo ""
    echo "Run the body model pipeline:"
    echo "  $BLENDER --background --python scripts/blender_generate_body.py"
else
    echo "❌  MPFB2 installed but import failed. Check Blender logs above."
    exit 1
fi
