---
name: mascot-animator
description: Turn a character clip into a transparent looping WebP for Expo. Never auto-trigger — only invoke on explicit user request (e.g. /mascot-animator or direct ask).
---

Generate the clip on a solid green background in Veo/Flow/Kling, then:

```bash
~/.claude/skills/mascot-animator/scripts/animate_to_webp.sh INPUT.mp4 --square --gif -w 400 -o assets/images/mascot.webp
```

In-app:
```jsx
<Image source={require('./assets/mascot.webp')} style={{width:120,height:120}} />
```
If animated WebP renders static on iOS, switch to the `.gif` output via `Platform.OS`.
