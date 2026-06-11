---
name: image-to-webp
version: 1.2.0
description: >-
  Convert PNG/JPG images (e.g. AI-generated icons or illustrations) into
  optimized, transparency-preserving WebP and place them where they belong in
  the CURRENT project. Detects the framework (Expo/React Native, Flutter, native
  Android/iOS, web, …), infers the asset folder + naming convention from the
  repo, asks the user when it's ambiguous, removes baked-in solid backgrounds
  (auto-escalating to a fringe-free cut for outlined icons), and reports
  file-size savings. Fully project- and framework-agnostic. Invoke ONLY when
  explicitly asked (e.g. "convert these to webp", "/image-to-webp"); never
  auto-trigger on an attached image.
---

# image-to-webp

Turn raster source images into clean, app-ready `.webp` and drop them in the
correct place for whatever project you're in — with format conventions baked in
and project/framework specifics discovered fresh each run (never hardcoded).

## When to use
- The user explicitly asks to convert image(s) to WebP for the current project.

## When NOT to use
- Don't trigger automatically on an image attachment — wait for an explicit ask.
- Animated clips → `mascot-animator`, not this.

## Tools — install nothing without asking
- `cwebp` (libwebp) — the encoder. Required (`brew install webp` if missing).
- Inspect alpha/dimensions with whatever's present: `sips` (macOS), else
  `magick identify` or `ffprobe`.
- Trim / square / background removal need `magick` (ImageMagick). If a source has
  a baked-in background and `magick` is absent, **ask before** `brew install
  imagemagick`; never auto-install it. If the user declines, encode as-is and
  tell them the background stays.

## Upstream tip — recommend a key-color background (huge quality lever)
Background removal is only as clean as the source allows. **White is the worst
background** for AI-gen art because so much art contains near-white (cream, paper,
highlights) — you're forced to use low fuzz, which leaves an anti-aliasing fringe.
When the user is *about to generate* assets, advise them to prompt a **solid pure
key color absent from the artwork** — for warm/food/skin art that's **magenta
`#FF00FF`**; `#00FF00` green also works if nothing in the art is green. A key color
with a large gap from every subject color cuts pixel-perfect with no fringe, on
*any* art style (outline or not). The flood-fill rescue below is the fallback for
art you already have on white; magenta upstream is the durable fix.

## Step 1 — Detect the project & decide the destination (do NOT hardcode)
Inspect the repo root to identify the framework, then resolve the conventional
asset location **from the project itself**:

| Marker found | Framework | Conventional image location | Notes |
|---|---|---|---|
| `pubspec.yaml` | **Flutter** | `assets/` or `assets/images/` | Must be **declared** under `flutter: assets:` in `pubspec.yaml` — add it if missing. snake_case typical. |
| `app.json`/`app.config.*` + `expo` dep | **Expo / RN** | `assets/` or `assets/images/` | Referenced via `require()`. |
| `package.json` w/ `react-native` (no expo) | **React Native** | `src/assets/` or `assets/` | Follow the repo. |
| `next.config.*` / `vite.config.*` / CRA | **Web** | `public/` (URL ref) or `src/assets/` (imported) | |
| `android/.../res/` / `build.gradle` | **Native Android** | `res/drawable*/` | lowercase + `_`, no leading digit, density buckets. |
| `*.xcodeproj` / `Assets.xcassets` | **Native iOS** | `Assets.xcassets` | imageset folders. |

Then:
1. **Confirm by looking, not guessing**: list existing image dirs (`find . -type d -name assets -o -name images -o -name drawable* …`) and see where current images actually live.
2. If the convention is clear and unambiguous → use it, and state where you'll put them.
3. If it's **ambiguous** (multiple candidate dirs, monorepo, no existing assets, mixed frameworks) → **use the AskUserQuestion tool** to confirm the destination, offering the detected convention as the recommended option.
4. Framework registration: for **Flutter**, ensure the target path is listed under `flutter: assets:` in `pubspec.yaml` (add it). For others, no registration needed.

## Step 2 — Confirm inputs
1. **Sources** — paths the user gives, or session-attached images
   (`~/.claude/image-cache/<session>/*.png`).
2. **Mode** — `icon` (default → lossless) or `illustration`/`photo` (→ lossy q90).
3. **Names** — **propose names matching the project's existing convention**: scan
   filenames already in the target dir, detect the case style (kebab / snake /
   camel) and any prefix (e.g. `ic_`, `icon-`), and propose names in that style.
   If the dir is empty, propose kebab-case and confirm. The user can override any.
4. **Target size** (optional) — longest side px. Default: keep source for
   illustrations; cap icons at ~256px.

## Step 3 — Inspect
For each source: read dimensions + alpha (`sips -g pixelWidth -g pixelHeight -g
hasAlpha`, or `magick identify -format '%wx%h %A'`). **`hasAlpha: yes` can lie** —
AI gens often carry an alpha channel that is fully opaque with the background
*painted in*. Confirm by sampling corners; if they're a solid color (white, etc.),
treat it as a baked-in background regardless of the alpha flag:
```bash
magick "$in" -format 'tl=%[pixel:p{0,0}] tr=%[pixel:p{%[fx:w-1],0}]\n' info:
```
If the corners are a solid color → go to **Step 3b** to remove it. If they're
already transparent → skip to Step 4. If there's no `magick`, warn and either ask
to install it (Step 0 tools rule) or ask the user to re-export transparent.

## Step 3b — Remove a baked-in solid background (when needed)
Use an **edge flood-fill**, never a global `-transparent` / `colorkey`: flood-fill
only clears the background color *connected to the border*, so any same-color
region *inside* the subject (cream porridge inside a bowl, white in an eye) is
preserved because the subject's outline fences the fill off. Global keying would
punch holes in those interior regions.

`$BG` below is the corner color you detected (`white`, `magenta`, `"#00FF00"`, …).

**Pass 1 — clean key** (low fuzz; safe for any art, leaves edge fringe only when
`$BG` is close to subject colors like white-on-cream):
```bash
magick "$in" -alpha set -bordercolor "$BG" -border 1 \
  -fuzz 15% -fill none -draw 'alpha 0,0 floodfill' \
  -shave 1x1 "$out"
```
The 1px border unifies all four edges into one region so a single corner
flood-fill clears the whole background.

**Detect leftover fringe** — measure how many opaque pixels are still near `$BG`
after the cut (a non-trivial count = anti-aliasing halo survived):
```bash
magick "$out" -alpha extract -negate -threshold 1% \
  -format 'fringe=%[fx:mean]\n' info:    # higher mean ≈ more leftover edge matter
```
Eyeball the result too (the user spotting a halo is the real signal). If clean →
done. If fringe remains, escalate **only when the art is an outlined "sticker"
icon** (a continuous dark/contrasting stroke encloses the subject):

**Pass 2 — fringe-free rescue** (high fuzz is *safe here* because the enclosing
outline dams the fill out of the interior; the 1px alpha erode shaves the
half-blended AA ribbon):
```bash
magick "$in" -alpha set -bordercolor "$BG" -border 1 \
  -fuzz 40% -fill none -draw 'alpha 0,0 floodfill' \
  -shave 1x1 \
  -channel A -morphology Erode Disk:1 +channel "$out"
```

**When Pass 2 is NOT safe** — fall back to a clean key + tell the user to
regenerate on a magenta key color instead (don't silently mangle the art):
- No enclosing outline (painterly/soft/photographic edges) → high fuzz leaks in.
- Subject color touches the border *and* sits near `$BG` → can't separate.
- Thin/wispy details (fine hair, single-px steam, whiskers) → the erode eats them.

**Verify after either pass**: re-sample the corners (must be `srgba(0,0,0,0)`) and
spot-check an interior pixel that should stay opaque (e.g. the cream fill).

> **Troubleshooting:** processing several files rapidly in one shell loop can throw
> `magick: no decode delegate … /tmp/…` on a file (a temp-file race), silently
> skipping it. If a file is missing from the output, just re-run that one source in
> its own `magick` invocation — it succeeds standalone.

## Step 4 — Encode
Icons / flat art (lossless, preserves transparent-pixel RGB):
```bash
cwebp -lossless -exact -q 100 "$in" -o "$out"
cwebp -lossless -exact -q 100 -resize 256 0 "$in" -o "$out"   # cap width, aspect kept
```
Illustrations / shaded / photographic (lossy, smaller):
```bash
cwebp -q 90 -alpha_q 100 -exact "$in" -o "$out"
```
Report bytes: `stat -f%z file.webp` (macOS) / `stat -c%s` (Linux).

## Step 5 — Place & register
Write to the resolved dir using the agreed names. Create the dir if needed.
Flutter: confirm/append the path under `pubspec.yaml` → `flutter: assets:`.
Never overwrite silently — if a name exists, confirm first.

## Step 6 — Report
Table per file: name · src dims · alpha · out size · % saved. Then hand back how
to reference each asset for the detected framework (e.g. `require('…')` for RN,
`Image.asset('…')` for Flutter, URL/import for web).

## Conventions
- Always keep alpha (`-exact`). One consistent size per set.
- Filenames follow the **project's** existing style; don't impose one.
- Detect everything per-run; keep nothing project-specific in this skill.

## Example (framework-neutral)
> "Convert these 5 icon PNGs to WebP and add them to this project."

1. Detect framework from repo markers; locate where existing images live.
   - Flutter repo → propose `assets/images/`, snake_case, and plan to register in
     `pubspec.yaml`.
   - Expo repo → propose the repo's `assets/images/`, matching its filename style.
   - Ambiguous → AskUserQuestion to pick the folder.
2. Propose names in the repo's convention; let the user adjust.
3. Inspect alpha (flag opaque ones), encode lossless, place, register if needed.
4. Report sizes + savings + the correct reference snippet for that framework.

## Changelog
- **1.2.0** — background removal: detect baked-in solid backgrounds (corner
  sampling, since `hasAlpha` lies), edge flood-fill that preserves interior
  same-color regions, fringe detection + auto-escalating high-fuzz/erode rescue
  for outlined icons, magenta-key upstream recommendation, and the temp-race
  troubleshooting note. Asks before installing ImageMagick.
- **1.1.0** — made fully framework-agnostic: detect Flutter/Expo/RN/web/native,
  infer asset dir + naming from the repo, AskUserQuestion when ambiguous, Flutter
  pubspec registration; removed all project-specific paths/examples.
- **1.0.0** — initial: cwebp lossless/lossy, alpha check, resize, kebab naming,
  placement, savings report.
