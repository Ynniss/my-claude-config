---
name: mobile-verify
description: Attach to a RUNNING Expo/Metro dev server, open the current React Native / Expo app on a booted iOS simulator or Android emulator, drive it with Maestro, and visually verify a feature works. Project-agnostic — works in any RN/Expo repo. Invoke explicitly when asked to run, test, drive, screenshot, or confirm a screen/feature works on a simulator/emulator. Never auto-trigger.
---

# mobile-verify — attach to a running dev server and assess a feature

A global, reusable loop for **any** React Native / Expo project: attach → drive with
Maestro → screenshot → **`Read` the PNGs and judge the result**. No MCP, no idb.

> **Hard rule: never manage the dev server.** Do NOT run `expo start`, Metro, or any
> server/build process, and never start/stop/restart one. The **user** keeps Metro
> running themselves. This skill only *attaches* to it, opens the app on the
> simulator, drives it, and reads screenshots. If no server is running, **stop and
> ask the user to start it** — do not start it yourself.

Run everything from the **current project root** (the repo being worked on).

## Prerequisites (the user owns these)

- The user has **`expo start` already running** in their own terminal. Confirm with a
  read-only check: `curl -s localhost:8081/status` → expect `packager-status:running`.
  If it's not up, **ask the user to start it** and stop here.
- A simulator/emulator is **booted** (`xcrun simctl list devices booted` / `adb devices`).
- **Maestro** installed (`maestro --version`) and **Expo Go** installed on the device.

## 1. Attach (open the app against the user's server)

```bash
~/.claude/skills/mobile-verify/scripts/attach.sh ios          # or: android [port]
```

This only checks the server is up (read-only) and deep-links the app onto the booted
device so it loads from the **already-running** server. It never spawns or kills Metro.
If the app is already open on the device, you can skip this and go straight to Maestro.

(Dev-client builds: same idea, but the *user* builds/installs and runs the server; you
just open the app's scheme URL or assume it's already open, then drive.)

## 2. Drive + capture with Maestro

Saved flows live in the project's **`.maestro/`** dir (Maestro's convention) — not in
this skill. App id depends on how the user runs it:
- Expo Go: `host.exp.Exponent` (iOS) / `host.exp.exponent` (Android)
- Dev build / bare: the app's own bundle id / package name

```bash
maestro test -e APP_ID=host.exp.Exponent .maestro/<flow>.yaml --debug-output /tmp/mv-shots
```

- Put a `takeScreenshot: <name>` after each meaningful state so the trail tells the
  whole story even if a gated step halts progress.
- **Ad-hoc check** (no saved flow): write a throwaway YAML to `/tmp` and run it the
  same way. Match by visible **text** / `accessibilityLabel` (prefer `testID` when present).
- **No-flow option:** just screenshot the current screen — `xcrun simctl io booted
  screenshot /tmp/s.png` (iOS) / `adb exec-out screencap -p > /tmp/s.png` — and read it.

Maestro drives the UI and captures screenshots; it does not touch the dev server.

## 3. Assess

`Read` each screenshot and check against the expectation: right screen, correct
copy/layout/selected-state, gating behaved, no visual regression. Report per screen:
✅ matched · ❌ didn't (attach the shot) · any redbox/error verbatim. On failure,
surface the error — don't thrash, and don't try to "fix" it by restarting the server.

## Notes

- This skill is the *mechanism*; per-app specifics (flows, testIDs) live in each repo's
  `.maestro/`.
- Nothing here starts/stops a server — there is no cleanup step to run afterward.
