# JetBrains Mono Variable Nerd Font Patcher

This repository automates the patching of [JetBrains Mono Variable](https://github.com/JetBrains/JetBrainsMono) font with [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) glyphs.

## How it works

A GitHub Action workflow runs periodically (or manually) to:
1. Download the latest variable font from JetBrains.
2. Download the Nerd Fonts Patcher.
3. Patch the font.
4. Commit the patched font back to this repository.

## Usage

Download the patched fonts from the `patched-fonts` directory (once generated).
