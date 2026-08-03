#!/usr/bin/env bash
#
# eas-ship — build an Expo/EAS app and submit it to internal testing only.
#
#   Android : built LOCALLY (--local), then submitted to the Play internal track.
#   iOS     : built on EAS CLOUD (local iOS needs Xcode + distribution signing),
#             then uploaded to App Store Connect, where it reaches TestFlight.
#
# Flags mirror the eas-cli contract:
#   -p, --platform  android | ios | all   (default: all)
#       --profile   <name>                (default: production)
#       --build-only                      skip submission
#
# Hard rule: this script refuses to submit anywhere but internal testing. It never
# promotes to a production store track — that stays a manual console action.
#
set -euo pipefail

PLATFORM=all
PROFILE=production
SUBMIT=1

die() { printf '\n\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
say() { printf '\n\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--platform) PLATFORM="${2:-}"; shift 2 ;;
    --platform=*)  PLATFORM="${1#*=}"; shift ;;
    --profile)     PROFILE="${2:-}"; shift 2 ;;
    --profile=*)   PROFILE="${1#*=}"; shift ;;
    --build-only)  SUBMIT=0; shift ;;
    -h|--help)     awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    *)             die "unknown argument: $1" ;;
  esac
done

case "$PLATFORM" in android|ios|all) ;; *) die "--platform must be android, ios or all" ;; esac

# ---------------------------------------------------------------- app root ----
# The directory holding eas.json: the repo root in most projects, or a subfolder in a
# polyglot monorepo that keeps the app alongside other stacks.
APP_ROOT=$PWD
while [ ! -f "$APP_ROOT/eas.json" ]; do
  [ "$APP_ROOT" = "/" ] && die "no eas.json found in $PWD or any parent"
  APP_ROOT=$(dirname "$APP_ROOT")
done
cd "$APP_ROOT"
say "app root: $APP_ROOT"

# ---------------------------------------------------------------- preflight ----
command -v npx >/dev/null || die "npx not found"
npx eas-cli whoami >/dev/null 2>&1 || die "not logged in to EAS — run: npx eas-cli login"

node -e '
  const fs = require("fs");
  const eas = JSON.parse(fs.readFileSync("eas.json", "utf8"));
  const profile = process.argv[1];
  if (!eas.build?.[profile]) {
    console.error(`eas.json has no build profile "${profile}"`);
    process.exit(1);
  }
' "$PROFILE" || die "build profile check failed"

if [ "$PLATFORM" = android ] || [ "$PLATFORM" = all ]; then
  command -v java >/dev/null || die "java not found — a local Android build needs JDK 17"
  command -v keytool >/dev/null || die "keytool not found — needed to verify the signing key"
  command -v unzip >/dev/null || die "unzip not found — needed to read the cert out of the .aab"
  [ -n "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}" ] || die "ANDROID_HOME / ANDROID_SDK_ROOT is unset"
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  warn "working tree is dirty — eas includes uncommitted changes, so this build will not"
  warn "match any commit. Push first if you want it reproducible."
fi

# ------------------------------------------------------------ track guard ----
# Refuse anything that is not internal testing. Android carries an explicit track in
# eas.json; iOS has none — an App Store Connect upload lands in TestFlight and needs a
# separate manual review submission to reach the public store, so it is internal by
# construction as long as we pass no release flags.
if [ "$SUBMIT" = 1 ] && { [ "$PLATFORM" = android ] || [ "$PLATFORM" = all ]; }; then
  node -e '
    const fs = require("fs");
    const eas = JSON.parse(fs.readFileSync("eas.json", "utf8"));
    const track = eas.submit?.[process.argv[1]]?.android?.track;
    if (track === undefined) {
      console.error(`eas.json has no submit.${process.argv[1]}.android.track — refusing to guess.`);
      console.error(`Add   "submit": { "${process.argv[1]}": { "android": { "track": "internal" } } }`);
      process.exit(1);
    }
    if (track !== "internal") {
      console.error(`submit.${process.argv[1]}.android.track is "${track}", not "internal".`);
      console.error("This script only ships to internal testing. Promote from the Play Console by hand.");
      process.exit(1);
    }
  ' "$PROFILE" || die "Play track guard failed"
  say "track guard: android → internal"
fi

# ------------------------------------------------- native config injection ----
# Files like google-services.json are gitignored, so eas drops them from the project
# archive and prebuild dies. A cloud build gets them from EAS file env vars; a LOCAL
# build cannot, so pass an absolute path instead. No-op for projects without them.
inject_native_config() {
  local probe android_file ios_file
  # EAS_BUILD_PROFILE matters: a config that switches Firebase projects per profile
  # (dev vs prod) reads it, so probing without it resolves the wrong file.
  probe=$(EAS_BUILD_PROFILE="$PROFILE" node -e '
    try {
      const cfg = require("@expo/config").getConfig(process.cwd(), { skipSDKVersionRequirement: true });
      process.stdout.write((cfg.exp.android?.googleServicesFile ?? "") + "\n" + (cfg.exp.ios?.googleServicesFile ?? ""));
    } catch { process.stdout.write("\n"); }
  ' 2>/dev/null || printf '\n')
  android_file=$(printf '%s' "$probe" | sed -n '1p')
  ios_file=$(printf '%s' "$probe" | sed -n '2p')

  if [ -n "$android_file" ] && [ -z "${GOOGLE_SERVICES_JSON:-}" ]; then
    local abs="$APP_ROOT/${android_file#./}"
    if [ -f "$abs" ] && git check-ignore -q "$abs" 2>/dev/null; then
      export GOOGLE_SERVICES_JSON="$abs"
      say "injected GOOGLE_SERVICES_JSON (gitignored, absent from the archive)"
    fi
  fi
  if [ -n "$ios_file" ] && [ -z "${GOOGLE_SERVICES_PLIST:-}" ]; then
    local abs="$APP_ROOT/${ios_file#./}"
    if [ -f "$abs" ] && git check-ignore -q "$abs" 2>/dev/null; then
      export GOOGLE_SERVICES_PLIST="$abs"
      say "injected GOOGLE_SERVICES_PLIST"
    fi
  fi
}

# ------------------------------------------------------------------- logs ----
# A failed `eas build --local` prints the whole job spec as base64 — which decodes to
# your upload keystore AND its cleartext password. Keep logs 0600 and shred them on
# exit. (eas-cli also passes that blob as argv, so it is visible to `ps` while the
# build runs; nothing this script can do about that.)
LOGDIR=$(mktemp -d)
chmod 700 "$LOGDIR"
cleanup() { rm -rf "$LOGDIR"; }
trap cleanup EXIT

# ---------------------------------------------------------------- android ----
build_android() {
  inject_native_config
  local log="$LOGDIR/android.log" stamp="$LOGDIR/stamp"
  : > "$stamp"
  say "building Android locally (profile: $PROFILE) — this takes a while"
  if ! npx eas-cli build --platform android --profile "$PROFILE" --local --non-interactive \
        > "$log" 2>&1; then
    # Drop the encoded job spec before showing anything: it carries the keystore and its
    # password. Filter by length too, not just the marker — the marker is the base64 of a
    # particular JSON key order and would miss a reshuffle.
    tail -40 "$log" | grep -v 'eyJqb2Ii' | awk 'length($0) < 500' >&2 || true
    die "Android build failed (log shredded; see the tail above)"
  fi

  # Match only an artifact newer than this run's start. Picking "the newest .aab in the
  # folder" would happily submit a leftover from a previous build if this one wrote its
  # output elsewhere — shipping a stale binary is exactly what this script exists to prevent.
  local aab
  aab=$(find "$APP_ROOT" -maxdepth 1 -name '*.aab' -newer "$stamp" 2>/dev/null | head -1 || true)
  [ -n "$aab" ] || die "build reported success but produced no new .aab in $APP_ROOT — refusing to submit a stale artifact"
  say "artifact: $aab"

  # Read the signing identity off the artifact, never off config: build.gradle signs
  # release with the debug key in a stock RN template, and EAS overrides that only at
  # build time. Play rejects an AAB signed by anything but the registered upload key.
  local sha1
  sha1=$(unzip -p "$aab" 'META-INF/*.RSA' 2>/dev/null | keytool -printcert 2>/dev/null \
          | awk -F': ' '/SHA1:/ {print $2; exit}' || true)
  [ -n "$sha1" ] || die "could not read a signing fingerprint from $aab"
  say "signing SHA-1: $sha1"

  # Optional pin: put the expected fingerprint in .eas-ship-sha1 next to eas.json.
  # It is a public certificate hash, safe to commit.
  if [ -f "$APP_ROOT/.eas-ship-sha1" ]; then
    local expected
    expected=$(tr -d '[:space:]' < "$APP_ROOT/.eas-ship-sha1")
    if [ "$(echo "$sha1" | tr -d '[:space:]')" != "$expected" ]; then
      die "signing mismatch — expected $expected, got $sha1. NOT submitting."
    fi
    say "fingerprint matches .eas-ship-sha1"
  else
    warn "no .eas-ship-sha1 pin found — verify the fingerprint above yourself before trusting this build"
  fi

  ANDROID_AAB="$aab"
}

submit_android() {
  say "submitting to the Play internal track"
  npx eas-cli submit --platform android --profile "$PROFILE" --path "$ANDROID_AAB" --non-interactive \
    || die "Android submit failed"
}

# -------------------------------------------------------------------- ios ----
build_ios() {
  say "building iOS on EAS cloud (profile: $PROFILE)"
  npx eas-cli build --platform ios --profile "$PROFILE" --non-interactive --wait \
    || die "iOS build failed"
}

submit_ios() {
  say "uploading to App Store Connect → TestFlight"
  npx eas-cli submit --platform ios --profile "$PROFILE" --latest --non-interactive \
    || die "iOS submit failed"
}

# ------------------------------------------------------------------- run ----
if [ "$PLATFORM" = android ] || [ "$PLATFORM" = all ]; then
  build_android
  if [ "$SUBMIT" = 1 ]; then submit_android; fi
fi
if [ "$PLATFORM" = ios ] || [ "$PLATFORM" = all ]; then
  build_ios
  if [ "$SUBMIT" = 1 ]; then submit_ios; fi
fi

say "done — internal testing only; promote to production from the store console by hand"
