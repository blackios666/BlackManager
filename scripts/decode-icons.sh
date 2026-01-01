#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)/.."
ICON_B64="$DIR/Resources/Icons/folder.png.b64"
OUT="$DIR/Resources/Icons/folder.png"
if [ ! -f "$ICON_B64" ]; then
  echo "Archivo $ICON_B64 no encontrado"
  exit 1
fi
base64 -d "$ICON_B64" > "$OUT"
echo "Decoded $OUT"