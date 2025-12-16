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
python3 - <<'PY'
from pathlib import Path
import subprocess
import sys

try:
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "fonttools"])
    import site
    sys.path.append(site.getusersitepackages())
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont

work_dir = Path("build-work")
mapping = [
    ("JetBrainsMono[wght].ttf", "JetBrainsMono-Regular.ttf"),
    ("JetBrainsMono-Italic[wght].ttf", "JetBrainsMono-Italic.ttf"),
]

for src, dst in mapping:
    src_path = work_dir / src
    dst_path = work_dir / dst
    font = TTFont(src_path)
    default_wght = 400
    if "fvar" in font:
        default_wght = font["fvar"].axes[0].defaultValue
    instantiated = instantiateVariableFont(font, {"wght": default_wght})
    instantiated.save(dst_path)
PY

# 3. Patch Fonts
# Ensure fontforge is installed in the environment
echo "Patching fonts..."
for font in "${PATCH_FONTS[@]}"; do
    echo "Processing $font..."
    # --complete: Add all glyphs
    # --careful: Be careful not to overwrite existing glyphs
    fontforge -script "$WORK_DIR/nerd-fonts/font-patcher" \
        -c \
        --careful \
        --out "$OUTPUT_DIR" \
        "$WORK_DIR/$font"
done

echo "Patching complete. Files are in $OUTPUT_DIR"
