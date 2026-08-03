---
name: eas-ship
description: Build an Expo/EAS React Native app and ship it to internal testing — Android built locally then submitted to the Play internal track, iOS built on EAS cloud then uploaded to TestFlight. Project-agnostic, works in any Expo repo with an eas.json. Refuses to submit to a production store track. Invoke explicitly when asked to cut, spin up, or ship an internal/test/QA build. Never auto-trigger.
---

# eas-ship — cut an internal testing build

A global, reusable flow for **any** Expo/EAS project: preflight → build → verify the signing
key → submit to internal testing only. The script does the mechanical work; this file covers
the judgment around it.

> **Hard rule: internal testing only.** Never submit to a production store track, and never
> work around the guard that enforces it (no editing `eas.json`'s track, no `--track` override).
> Promotion to production is the user's manual console action. If they ask you to ship to
> production, stop and tell them to do it from the Play Console / App Store Connect themselves.

## When to use

The user asks for an internal/test/QA/TestFlight build, or to "spin up a build" of a mobile
app. **Never auto-trigger** — a build costs 20-40 minutes and pushes a binary to a store.

## Run it

```bash
~/.claude/skills/eas-ship/scripts/eas-ship.sh -p all --profile production
```

Flags mirror eas-cli: `-p android|ios|all` (default `all`), `--profile <name>` (default
`production`), `--build-only` to skip submission. Run it from anywhere inside the project —
it walks up to the directory holding `eas.json`, so a monorepo subfolder works.

Run it in the **background** and report progress; an Android local build takes 20-40 minutes.

## What it does, and where judgment is needed

| Stage | Behaviour | Your job when it stops |
|---|---|---|
| Preflight | EAS login, JDK, Android SDK, `keytool`/`unzip` | Tell the user the exact missing piece; don't try to install toolchains |
| Track guard | `submit.<profile>.android.track` must be `internal` | **Stop.** Report what the repo is configured for. Offer to add an `internal` block only if the key is *absent*; never rewrite a `production` one |
| Native config | Probes the resolved Expo config; a gitignored `googleServicesFile` is passed as an absolute path | Nothing — this is the fix for local builds, which can't read EAS file env vars |
| Build | Android local, iOS on EAS cloud | On failure, read the tail it prints. **Never** paste a full `--local` log anywhere |
| Signing check | Reads SHA-1 off the `.aab`, compares to `.eas-ship-sha1` if present | On mismatch it refuses to submit — that is correct. Do not override |
| Submit | Play internal track / App Store Connect → TestFlight | — |

## Two things that bite

**A failed `eas build --local` dumps your keystore.** eas-cli prints the whole job spec as
base64 on failure; it decodes to the upload keystore *and* its cleartext password. The script
keeps logs in a `0700` temp dir and shreds them on exit, and filters the blob out of anything
it echoes. eas-cli also passes that blob as **argv**, so it is visible to `ps` for the duration
of the build — nothing can be done about that, but never suggest sharing a build log.

**Uncommitted work is included, gitignored files are not.** EAS copies the working directory
over its shallow clone, so dirty changes *do* reach the build (the script warns that it won't
match any commit). Gitignored files are a different path — they are dropped from the archive
entirely, which is why native config needs the absolute-path injection.

## Pinning the signing key

Without a pin the script only warns about the fingerprint. To make it a hard stop, put the
expected SHA-1 in `.eas-ship-sha1` next to `eas.json`:

```
AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
```

A certificate fingerprint is public — safe to commit. Read the correct value off a known-good
artifact (`unzip -p <file>.aab 'META-INF/*.RSA' | keytool -printcert`), never off
`build.gradle`: a stock RN template signs `release` with the debug key and EAS overrides that
only at build time.

## Status

Verified: argument handling, app-root discovery, the track guard (against repos configured for
both `production` and no track at all), the profile-aware native-config probe, and a full
Android build → fingerprint check → Play internal submission.

**Not yet exercised: the iOS path.** Neither `build_ios` nor `submit_ios` has run. Treat the
first iOS invocation as a test, and check the eas-cli output rather than assuming success.
