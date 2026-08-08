#!/system/bin/sh

TOOL="/data/local/tmp/font-cmap-tool-arm64-v8a"
REMOVE_RANGE="[200B]"

for font in ./*.ttf ./*.otf; do
    [ -e "$font" ] || continue
    echo "Processing: $font"
    $TOOL filter "$font" --remove "$REMOVE_RANGE"
done