#!/bin/bash
set -e

# Configuration
JB_RAW_BASE="https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/variable"
FONTS=("JetBrainsMono[wght].ttf" "JetBrainsMono-Italic[wght].ttf")
PATCH_FONTS=("JetBrainsMono-Regular.ttf" "JetBrainsMono-Italic.ttf")
WORK_DIR="build-work"
OUTPUT_DIR="patched-fonts"

# Cleanup previous build artifacts
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# 1. Download JetBrains Mono Variable Fonts
echo "Downloading JetBrains Mono Variable fonts..."
for font in "${FONTS[@]}"; do
    echo "Downloading $font..."
    curl -g -fLo "$WORK_DIR/$font" "$JB_RAW_BASE/$font"
done

# 2. Prepare Nerd Fonts Patcher
# We use sparse checkout to avoid downloading gigabytes of pre-patched fonts
echo "Setting up Nerd Fonts Patcher..."
git clone --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git "$WORK_DIR/nerd-fonts"
pushd "$WORK_DIR/nerd-fonts" > /dev/null
git sparse-checkout set --no-cone font-patcher src/glyphs bin
popd > /dev/null

# 3. Convert variable fonts to static instances for patching reliability
echo "Converting variable fonts to static instances for patching..."
WORK_DIR="$WORK_DIR" python3 - <<'PY'
import os
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

DEFAULT_WEIGHT = 400
work_dir = Path(os.environ["WORK_DIR"])
mapping = [
    ("JetBrainsMono[wght].ttf", "JetBrainsMono-Regular.ttf"),
    ("JetBrainsMono-Italic[wght].ttf", "JetBrainsMono-Italic.ttf"),
]

for src, dst in mapping:
    src_path = work_dir / src
    dst_path = work_dir / dst
    instantiated = None
    font = TTFont(src_path)
    try:
        default_wght = DEFAULT_WEIGHT
        if "fvar" in font:
            axes_defaults = {axis.axisTag: axis.defaultValue for axis in font["fvar"].axes}
            default_wght = axes_defaults.get("wght", default_wght)
        instantiated = instantiateVariableFont(font, {"wght": default_wght})
    finally:
        font.close()

    try:
        if instantiated:
            instantiated.save(dst_path)
    finally:
        if instantiated:
            instantiated.close()
PY

# 4. Patch Fonts
# Ensure fontforge is installed in the environment
echo "Patching fonts..."
for font in "${PATCH_FONTS[@]}"; do
    echo "Processing $font..."
    # -c / --complete: Add all glyphs
    # --careful: Be careful not to overwrite existing glyphs
    fontforge -script "$WORK_DIR/nerd-fonts/font-patcher" \
        -c \
        --careful \
        --out "$OUTPUT_DIR" \
        "$WORK_DIR/$font"
done

echo "Patching complete. Files are in $OUTPUT_DIR"
