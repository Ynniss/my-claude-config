---
name: mascot-animator
description: Convert an AI-generated animation clip (a Veo / Kling / Flow / Sora-style .mp4 or .mov of a character or mascot) into an app-ready, transparent, infinitely-looping WebP (plus optional GIF) for a React Native / Expo app. Use this whenever the user hands over a short video clip and wants it turned into a mascot asset, animated sticker, looping icon, transparent WebP/GIF, or "something I can drop into the app" — even if they don't say "WebP" explicitly. Trigger on phrases like "make this a webp", "animate my mascot", "remove the background and loop it", "turn this clip into an asset", or when a generated character clip needs background removal + looping for in-app use.
---

# Mascot Animator

Turns a generated character clip into a transparent, looping in-app asset. The
heavy lifting is a single bundled script — **run it, don't reimplement it.** Do
not extract or process frames yourself; that wastes tokens and time. Your job is
to pick the right flags and execute one command.

## Upstream (manual — not your job)
The user generates the motion clip themselves in Google Flow (Veo), Kling, etc.
(subscription credits, ~10–20 per 8s clip). That step can't be scripted cheaply.
You start from the **downloaded .mp4/.mov**.

## What to run

```bash
~/.claude/skills/mascot-animator/scripts/animate_to_webp.sh INPUT.mp4 [options]
```

Pick the background-removal mode from how the clip was generated:

| Situation | Use |
|---|---|
| Plain / arbitrary background (e.g. default white Veo output) | *default* (AI matte via `rembg`) |
| Clip generated on a solid green/blue screen | `--chroma 0x00FF00` (fast, no rembg) |
| Background should be kept (full-screen splash, no overlay) | `--no-matte` |

Common options: `-w 480` (width px), `--fps 16`, `--square` (centered square
canvas, good for icon/loader slots), `--gif` (also emit a transparent GIF
fallback), `-o path/zayd_wave.webp`.

Example (typical mascot reaction clip on a plain background, square slot, with gif):
```bash
~/.claude/skills/mascot-animator/scripts/animate_to_webp.sh zayd_wave.mp4 --square --gif -w 400 -o assets/zayd_wave.webp
```

## Dependencies
- `ffmpeg` — required (all modes).
- `rembg` — only for the default AI-matte mode. If missing, the script says so;
  install with `pip install "rembg[cli]"` (first run downloads a ~170MB model),
  or fall back to `--chroma` / `--no-matte`.

## In-app usage (mention to user if relevant)
`expo-image` renders animated WebP natively and transparently:
```jsx
<Image source={require('./assets/zayd_wave.webp')} style={{width:120,height:120}} />
```
> **iOS note:** Verify animated WebP loops on a real iOS device before shipping — if it
> renders as a static frame, use the `--gif` output as fallback and pass it to
> `<Image>` conditionally via `Platform.OS`.

## Notes
- WebP/GIF carry no audio — Veo's auto-generated music is dropped automatically.
- Keep clips short (≤8s) and width modest (≤480) so assets stay light.
- For pervasive ambient motion (idle bob on a static PNG), this skill isn't
  needed — that's better done with Reanimated on the still image.
