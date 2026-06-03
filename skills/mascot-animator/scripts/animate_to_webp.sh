#!/usr/bin/env bash
#
# animate_to_webp.sh — turn an AI-generated animation clip (Veo / Kling / Sora-style
# mp4) into an app-ready, transparent, looping WebP for React Native (expo-image).
#
# Pipeline: [optional background removal] -> scale -> center/pad -> loop -> strip audio -> .webp
#
# USAGE:
#   animate_to_webp.sh INPUT.mp4 [options]
#
# OPTIONS:
#   -o, --out PATH      Output file (default: <input>.webp)
#   -w, --width PX      Output width in px (default: 480). Height auto-keeps aspect.
#       --fps N         Frames per second (default: 16). Lower = smaller file.
#       --chroma HEX    Fast mode: key out a solid-color background instead of AI
#                       matting. e.g. --chroma 0x00FF00 for a green-screen clip.
#       --no-matte      Keep the original background (no transparency).
#       --square        Pad to a centered square transparent canvas (good for icons).
#       --gif           Also emit a transparent .gif fallback.
#       --keep          Keep the temp frame folder (for debugging).
#   -h, --help          Show this help.
#
# DEFAULT (no --chroma / --no-matte): AI background removal via `rembg`, which works
# on any background (e.g. the plain white Veo output). Install once with:
#   pip install "rembg[cli]"
#
# Requires: ffmpeg (always). rembg only for the default AI-matte mode.

set -euo pipefail

OUT=""; WIDTH=480; FPS=16; CHROMA=""; NOMATTE=0; SQUARE=0; GIF=0; KEEP=0
INPUT=""

die(){ echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--out) OUT="$2"; shift 2;;
    -w|--width) WIDTH="$2"; shift 2;;
    --fps) FPS="$2"; shift 2;;
    --chroma) CHROMA="$2"; shift 2;;
    --no-matte) NOMATTE=1; shift;;
    --square) SQUARE=1; shift;;
    --gif) GIF=1; shift;;
    --keep) KEEP=1; shift;;
    -h|--help) sed -n '2,30p' "$0"; exit 0;;
    -*) die "unknown option: $1";;
    *) INPUT="$1"; shift;;
  esac
done

[[ -n "$INPUT" ]] || die "no input file given. usage: animate_to_webp.sh INPUT.mp4 [options]"
[[ -f "$INPUT" ]] || die "input not found: $INPUT"
command -v ffmpeg >/dev/null || die "ffmpeg not installed."

[[ -z "$OUT" ]] && OUT="${INPUT%.*}.webp"

# Build the scale (+ optional square pad) filter, preserving alpha.
# --square: scale to fit inside the square first (handles portrait clips), then pad.
if [[ $SQUARE -eq 1 ]]; then
  VF="scale=${WIDTH}:${WIDTH}:flags=lanczos:force_original_aspect_ratio=decrease,format=rgba,pad=${WIDTH}:${WIDTH}:(ow-iw)/2:(oh-ih)/2:color=0x00000000"
else
  VF="scale=${WIDTH}:-1:flags=lanczos"
fi

WEBP_ARGS=(-loglevel error -loop 0 -an -c:v libwebp -lossless 0 -q:v 75 -compression_level 6)

if [[ -n "$CHROMA" ]]; then
  # ---- FAST MODE: chroma-key a solid background, single ffmpeg pass ----
  echo ">> chroma-key mode (keying out $CHROMA)"
  ffmpeg -y -loglevel error -i "$INPUT" -vf "colorkey=${CHROMA}:0.30:0.10,fps=${FPS},${VF}" \
    "${WEBP_ARGS[@]}" "$OUT"
  if [[ $GIF -eq 1 ]]; then
    ffmpeg -y -loglevel error -i "$INPUT" -vf "colorkey=${CHROMA}:0.30:0.10,fps=${FPS},${VF},split[s0][s1];[s0]palettegen=reserve_transparent=1[p];[s1][p]paletteuse=alpha_threshold=128" \
      -loop 0 "${OUT%.webp}.gif"
  fi

elif [[ $NOMATTE -eq 1 ]]; then
  # ---- KEEP BACKGROUND: just transcode/scale/loop ----
  echo ">> no-matte mode (keeping original background)"
  ffmpeg -y -loglevel error -i "$INPUT" -vf "fps=${FPS},${VF}" "${WEBP_ARGS[@]}" "$OUT"
  [[ $GIF -eq 1 ]] && ffmpeg -y -loglevel error -i "$INPUT" -vf "fps=${FPS},${VF},split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "${OUT%.webp}.gif"

else
  # ---- DEFAULT: AI background removal (rembg), works on any background ----
  command -v rembg >/dev/null || die "rembg not installed. Run: pip install \"rembg[cli]\"  (or use --chroma / --no-matte)"
  echo ">> AI-matte mode (rembg)"
  TMP="$(mktemp -d)"; trap '[[ $KEEP -eq 0 ]] && rm -rf "$TMP"' EXIT
  echo "   extracting frames @ ${FPS}fps ..."
  ffmpeg -y -loglevel error -i "$INPUT" -vf "fps=${FPS}" "$TMP/raw_%04d.png"
  echo "   removing backgrounds (this is the slow step) ..."
  rembg p "$TMP" "$TMP/cut" >/dev/null 2>&1 || die "rembg failed"
  echo "   encoding WebP ..."
  ffmpeg -y -loglevel error -framerate "$FPS" -i "$TMP/cut/raw_%04d.png" -vf "${VF}" "${WEBP_ARGS[@]}" "$OUT"
  if [[ $GIF -eq 1 ]]; then
    ffmpeg -y -loglevel error -framerate "$FPS" -i "$TMP/cut/raw_%04d.png" -vf "${VF},split[s0][s1];[s0]palettegen=reserve_transparent=1[p];[s1][p]paletteuse=alpha_threshold=128" \
      -loop 0 "${OUT%.webp}.gif"
  fi
fi

SZ=$(du -h "$OUT" | cut -f1)
echo ">> done: $OUT (${SZ})"
[[ $GIF -eq 1 ]] && echo ">> gif:  ${OUT%.webp}.gif ($(du -h "${OUT%.webp}.gif"|cut -f1))"
