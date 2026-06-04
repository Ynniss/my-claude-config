# Mascot pipeline — reusable prompts

The pipeline: **generate still (green bg) → animate with Veo → run `animate_to_webp.sh`**.
The script chroma-keys the green out, so every upstream step must keep the green flat and clean.

---

## 1. Image generation / edit (ChatGPT or Google AI Studio)

Append this clause **after** your scene/action description:

> Show **only** the baby and the action described — nothing else. No text, letters,
> numbers, captions, logos, watermarks, borders, frames, icons, or extra props. A single
> isolated character.
>
> Place it on a **flat, solid chroma-key green background (#00FF00)** — perfectly even
> edge to edge, no gradients, shadows, or texture, and no green spill or reflections on
> the character. Keep the full character centered with a little margin so nothing is cropped.

**Load-bearing words:** "only … nothing else", "no text", "flat solid chroma-key green
#00FF00, no shadows/gradients".

---

## 2. Animation (Google Veo 3, image-to-video)

Feed the green-screen still + this prompt. Replace the bracketed action.

> Animate this image. Keep the camera completely locked — no pan, zoom, dolly, or shake.
> Keep the flat green background solid, static, and unchanged: do not add scenery, objects,
> lighting shifts, or shadows of any kind. **Only the character moves.** [ACTION, e.g. "the
> baby happily waves one hand at the viewer and gives a warm smile"]. Natural, smooth, gentle
> motion. The character stays fully in frame and centered the whole time. No new elements, no
> text, no watermark, no camera cuts. Keep the motion short and subtle, ending near the
> starting pose so it loops cleanly. Silent, no sound.

**Notes**
- Keep it **2–3 seconds** — shorter = smaller WebP and a tighter loop.
- Veo loves to invent a room; "background static and unchanged, camera locked" is what
  stops it. Be forceful.
- Veo 3 generates audio — ignore it, the script drops it. "Silent" just nudges it.
- "ends near the starting pose" gives a seamless loop.

---

## 3. Encode (this skill)

```bash
~/.claude/skills/mascot-animator/scripts/animate_to_webp.sh INPUT.mp4 --square --gif -w 480
```
Add `-loop 1` behavior / speed tweaks at the encode step if needed.
