#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET_DIR="${ROOT_DIR}/.build/MyCue.iconset"
OUTPUT_PATH="${ROOT_DIR}/Resources/AppIcon.icns"
MASTER_PNG="${ROOT_DIR}/.build/MyCue-app-icon-master.png"
COMPOSER_DIR="${ROOT_DIR}/docs/assets/MyCue.icon/Assets"

rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}" "$(dirname "${OUTPUT_PATH}")" "$(dirname "${MASTER_PNG}")"

if [[ -d "${COMPOSER_DIR}" ]]; then
  magick -size 1024x1024 xc:"#060708" \
    "${COMPOSER_DIR}/layer-01-shell.png" \
    "${COMPOSER_DIR}/layer-02-grid.png" \
    "${COMPOSER_DIR}/layer-03-monogram.png" \
    "${COMPOSER_DIR}/layer-04-accent.png" \
    -background none -layers merge +repage \
    "${MASTER_PNG}"
else
  magick -size 1024x1024 xc:"#060708" \
    -fill "#171B1F" -stroke "#545B63" -strokewidth 16 \
    -draw "roundrectangle 88,88 936,936 210,210" \
    -fill "#111417" -stroke "#111417" -strokewidth 1 \
    -draw "roundrectangle 120,120 904,904 178,178" \
    -fill "#0A0C0E" -stroke "#373E45" -strokewidth 4 \
    -draw "roundrectangle 238,238 786,786 18,18" \
    -stroke "#24292F" -strokewidth 8 \
    -draw "line 150,312 874,312" \
    -draw "line 150,712 874,712" \
    -draw "line 312,150 312,874" \
    -draw "line 712,150 712,874" \
    -stroke "#E7EDF2" -strokewidth 62 \
    -draw "line 314,704 314,320" \
    -draw "line 710,704 710,320" \
    -stroke "#E7EDF2" -strokewidth 58 \
    -draw "line 346,336 512,566" \
    -draw "line 512,566 678,336" \
    -stroke "#E77F32" -strokewidth 18 \
    -draw "line 680,260 764,260" \
    -draw "line 724,260 724,344" \
    -fill "#E77F32" -stroke none \
    -draw "circle 768,768 810,768" \
    -fill "#101214" \
    -draw "circle 768,768 786,768" \
    "${MASTER_PNG}"
fi

sizes=(16 32 128 256 512)
for size in "${sizes[@]}"; do
  magick "${MASTER_PNG}" -resize "${size}x${size}" "${ICONSET_DIR}/icon_${size}x${size}.png"
  double_size=$((size * 2))
  magick "${MASTER_PNG}" -resize "${double_size}x${double_size}" "${ICONSET_DIR}/icon_${size}x${size}@2x.png"
done

iconutil -c icns "${ICONSET_DIR}" -o "${OUTPUT_PATH}"
echo "Generated ${OUTPUT_PATH}"
