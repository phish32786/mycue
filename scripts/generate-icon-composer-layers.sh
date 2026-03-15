#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/docs/assets/icon-composer"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

magick -size 1024x1024 xc:none \
  -fill "#171B1F" -stroke "#545B63" -strokewidth 16 \
  -draw "roundrectangle 88,88 936,936 210,210" \
  -fill "#111417" -stroke "#111417" -strokewidth 1 \
  -draw "roundrectangle 120,120 904,904 178,178" \
  "${OUT_DIR}/layer-01-shell.png"

magick -size 1024x1024 xc:none \
  -fill none -stroke "#24292F" -strokewidth 8 \
  -draw "line 150,312 874,312" \
  -draw "line 150,712 874,712" \
  -draw "line 312,150 312,874" \
  -draw "line 712,150 712,874" \
  -fill none -stroke "#373E45" -strokewidth 4 \
  -draw "roundrectangle 238,238 786,786 18,18" \
  "${OUT_DIR}/layer-02-grid.png"

magick -size 1024x1024 xc:none \
  -fill none -stroke "#E7EDF2" -strokewidth 62 \
  -draw "line 314,704 314,320" \
  -draw "line 710,704 710,320" \
  -stroke "#E7EDF2" -strokewidth 58 \
  -draw "line 346,336 512,566" \
  -draw "line 512,566 678,336" \
  "${OUT_DIR}/layer-03-monogram.png"

magick -size 1024x1024 xc:none \
  -fill none -stroke "#E77F32" -strokewidth 18 \
  -draw "line 680,260 764,260" \
  -draw "line 724,260 724,344" \
  -fill "#E77F32" -stroke none \
  -draw "circle 768,768 810,768" \
  -fill "#101214" \
  -draw "circle 768,768 786,768" \
  "${OUT_DIR}/layer-04-accent.png"

magick \
  "${OUT_DIR}/layer-01-shell.png" \
  "${OUT_DIR}/layer-02-grid.png" \
  "${OUT_DIR}/layer-03-monogram.png" \
  "${OUT_DIR}/layer-04-accent.png" \
  -background none -layers merge +repage \
  "${OUT_DIR}/flattened-preview.png"

cat > "${OUT_DIR}/README.md" <<'EOF'
# Icon Composer Layers

These are the prepared source layers for rebuilding the MyCue app icon in Apple's Icon Composer.

Suggested import order:

1. `layer-01-shell.png`
2. `layer-02-grid.png`
3. `layer-03-monogram.png`
4. `layer-04-accent.png`

Recommended direction in Icon Composer:

- keep the shell as the back enclosure
- treat the grid as a subtle mid/background technical layer
- keep the monogram as the primary foreground shape
- keep the orange accent as the smallest top detail
- use Apple’s rounder enclosure and Liquid Glass treatment conservatively
- preserve the dark industrial feel; do not turn it into a generic glossy blue icon

The current flattened fallback icon in the app bundle is generated from the same layers.
EOF

echo "Generated layered assets in ${OUT_DIR}"
