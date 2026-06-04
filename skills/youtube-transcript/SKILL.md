---
name: youtube-transcript
description: Fetch a YouTube video's transcript from a URL or video ID, then summarize or answer questions about it. Use when the user shares a YouTube link and wants its contents.
allowed-tools: Bash(yt-transcript:*)
---

# YouTube Transcript

Fetch and work with a YouTube video's transcript. The video URL (or bare 11-char
video ID) is passed as `$ARGUMENTS`.

## Step 1 — Fetch

Run the wrapper script (handles URL/ID extraction, language fallbacks, and failure
detection — never scrape or use any other method):

```bash
yt-transcript "$ARGUMENTS"
```

## Step 2 — Use the result

- **Exit 0:** stdout is the clean transcript text. Use it to do whatever the user
  asked — summarize, extract a framework, answer a question, etc. If they only
  pasted a link with no instruction, give a tight summary of the key points.
- **Exit 1:** the video has no retrievable transcript (captions disabled or video
  unavailable). Tell the user plainly. **Never fabricate the video's contents.**

## Notes

- If no argument was given, ask the user for the YouTube URL or video ID.
- The transcript can be long; lead with the synthesis the user actually wants, not
  a raw dump, unless they explicitly ask for the full text.
