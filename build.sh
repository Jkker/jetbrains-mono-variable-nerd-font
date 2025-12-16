#!/bin/bash
set -e

# Configuration
JB_RAW_BASE="https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/variable"
FONTS=("JetBrainsMono[wght].ttf" "JetBrainsMonoItalic[wght].ttf")
WORK_DIR="build-work"
OUTPUT_DIR="patched-fonts"

# Cleanup previous build artifacts
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# 1. Download JetBrains Mono Variable Fonts
echo "Downloading JetBrains Mono Variable fonts..."
for font in "${FONTS[@]}"; do
    echo "Downloading $font..."
    curl -fLo "$WORK_DIR/$font" "$JB_RAW_BASE/$font"
done

# 2. Prepare Nerd Fonts Patcher
# We use sparse checkout to avoid downloading gigabytes of pre-patched fonts
echo "Setting up Nerd Fonts Patcher..."
git clone --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git "$WORK_DIR/nerd-fonts"
pushd "$WORK_DIR/nerd-fonts" > /dev/null
git sparse-checkout set font-patcher src/glyphs
popd > /dev/null

# 3. Patch Fonts
# Ensure fontforge is installed in the environment
echo "Patching fonts..."
for font in "${FONTS[@]}"; do
    echo "Processing $font..."
    # --complete: Add all glyphs
    # --careful: Be careful not to overwrite existing glyphs
    fontforge -script "$WORK_DIR/nerd-fonts/font-patcher" \
        -c \
        --out "$OUTPUT_DIR" \
        "$WORK_DIR/$font"
done

echo "Patching complete. Files are in $OUTPUT_DIR"
