#!/usr/bin/env bash
#
# animate_to_webp.sh — turn a green-screen clip into a transparent looping WebP.
#
# USAGE:
#   animate_to_webp.sh INPUT.mp4 [options]
#
# OPTIONS:
#   -o, --out PATH      Output file (default: <input>.webp)
#   -w, --width PX      Output width in px (default: 480)
#       --fps N         Frames per second (default: 16)
#       --chroma HEX    Background color to key out (default: 0x00FF00 green)
#       --square        Pad to a centered square canvas
#       --gif           Also emit a .gif fallback
#   -h, --help          Show this help
#
# Requires: ffmpeg, img2webp (brew install webp)

set -euo pipefail

OUT=""; WIDTH=480; FPS=16; CHROMA="0x00FF00"; SQUARE=0; GIF=0
INPUT=""

die(){ echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--out)    OUT="$2"; shift 2;;
    -w|--width)  WIDTH="$2"; shift 2;;
    --fps)       FPS="$2"; shift 2;;
    --chroma)    CHROMA="$2"; shift 2;;
    --square)    SQUARE=1; shift;;
    --gif)       GIF=1; shift;;
    -h|--help)   sed -n '2,14p' "$0"; exit 0;;
    -*)          die "unknown option: $1";;
    *)           INPUT="$1"; shift;;
  esac
done

[[ -n "$INPUT" ]] || die "no input file. usage: animate_to_webp.sh INPUT.mp4 [options]"
[[ -f "$INPUT" ]] || die "input not found: $INPUT"
command -v ffmpeg   >/dev/null || die "ffmpeg not installed (brew install ffmpeg)"
command -v img2webp >/dev/null || die "img2webp not installed (brew install webp)"

[[ -z "$OUT" ]] && OUT="${INPUT%.*}.webp"

DELAY=$(( 1000 / FPS ))

if [[ $SQUARE -eq 1 ]]; then
  VF="colorkey=${CHROMA}:0.30:0.10,fps=${FPS},scale=${WIDTH}:${WIDTH}:flags=lanczos:force_original_aspect_ratio=decrease,format=rgba,pad=${WIDTH}:${WIDTH}:(ow-iw)/2:(oh-ih)/2:color=0x00000000"
else
  VF="colorkey=${CHROMA}:0.30:0.10,fps=${FPS},scale=${WIDTH}:-1:flags=lanczos"
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo ">> extracting + keying frames..."
ffmpeg -y -loglevel error -i "$INPUT" -vf "$VF" "$TMP/frame_%04d.png"

FRAMES=("$TMP"/frame_*.png)
[[ -f "${FRAMES[0]}" ]] || die "no frames extracted — check input file"
echo "   ${#FRAMES[@]} frames"

echo ">> encoding WebP..."
img2webp -loop 0 -d "$DELAY" -lossy -q 75 "${FRAMES[@]}" -o "$OUT"

if [[ $GIF -eq 1 ]]; then
  echo ">> encoding GIF..."
  ffmpeg -y -loglevel error -framerate "$FPS" -i "$TMP/frame_%04d.png" \
    -vf "split[s0][s1];[s0]palettegen=reserve_transparent=1[p];[s1][p]paletteuse=alpha_threshold=128" \
    -loop 0 "${OUT%.webp}.gif"
  echo ">> gif:  ${OUT%.webp}.gif ($(du -h "${OUT%.webp}.gif" | cut -f1))"
fi

echo ">> done: $OUT ($(du -h "$OUT" | cut -f1))"
