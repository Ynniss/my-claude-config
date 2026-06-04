#!/usr/bin/env bash
# mobile-verify — ATTACH to a Metro/Expo dev server the USER is already running,
# open the app on a booted simulator/emulator, and leave it ready to drive with
# Maestro.
#
# This script NEVER starts, stops, restarts, or otherwise manages any Metro/Expo
# process. If no server is running it tells you and exits — it does not spawn one.
#
# Usage: attach.sh [ios|android] [port]
#   platform : default ios
#   port     : default 8081 (override if you ran `expo start` on another port)
#
# Run from the project root.
set -uo pipefail

PLATFORM="${1:-ios}"
PORT="${2:-${EXPO_PORT:-8081}}"

server_up() { curl -s "http://localhost:${PORT}/status" 2>/dev/null | grep -q "packager-status:running"; }

if ! server_up; then
  cat >&2 <<EOF
No Expo/Metro dev server detected on http://localhost:${PORT}.
This skill does NOT start one — please run it yourself in your own terminal:
    npx expo start
…then re-run this. If your server is on another port, pass it:
    attach.sh ${PLATFORM} <port>
EOF
  exit 1
fi
echo "Found your running dev server on :${PORT}. Opening the app on ${PLATFORM} (Expo Go)…"

URL="exp://127.0.0.1:${PORT}"
if [ "$PLATFORM" = "android" ]; then
  adb shell am start -a android.intent.action.VIEW -d "$URL" >/dev/null 2>&1 \
    || { echo "ERROR: adb open failed — emulator booted? Expo Go installed?" >&2; exit 1; }
else
  xcrun simctl openurl booted "$URL" \
    || { echo "ERROR: simctl open failed — simulator booted? Expo Go installed?" >&2; exit 1; }
fi
echo "App loading from your server. Drive with Maestro (appId host.exp.Exponent / host.exp.exponent)."
