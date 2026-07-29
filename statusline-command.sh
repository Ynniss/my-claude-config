#!/bin/sh
input=$(cat)

IFS='|' read -r model cwd repo ctx lim5 reset5 lim7 reset7 <<EOF
$(printf '%s' "$input" | jq -r '[
  (.model.display_name // ""),
  (.workspace.current_dir // .cwd // ""),
  (.workspace.repo.name // ""),
  (.context_window.used_percentage // 0 | floor),
  (.rate_limits.five_hour.used_percentage // 0 | floor),
  (.rate_limits.five_hour.resets_at // 0 | floor),
  (.rate_limits.seven_day.used_percentage // 0 | floor),
  (.rate_limits.seven_day.resets_at // 0 | floor)
] | map(tostring) | join("|")')
EOF

# "Opus 5 (1M context)" -> "Opus 5 1M"
model=$(printf '%s' "$model" | sed 's/ (\([0-9A-Za-z]*\) context)/ \1/')

# Location: repo name (+ subpath), else abbreviated path. Branch is shown
# separately, so a worktree dir named after its branch never repeats.
root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
if [ -n "$root" ]; then
  [ -n "$repo" ] || repo=$(basename "$root")
  rel="${cwd#$root}"
  location="$repo$rel"
else
  case "$cwd" in
    "$HOME") location="~" ;;
    "$HOME"/*) location="~${cwd#$HOME}" ;;
    *) location="$cwd" ;;
  esac
  case "$location" in
    */*/*/*) location="$(printf '%s' "$location" | cut -d/ -f1)/…/$(basename "$cwd")" ;;
  esac
fi

branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

line1="$model · $location"
[ -n "$branch" ] && line1="$line1 · $branch"

# Threshold-colored, bold percentage: green (<50%), amber (50-79%), red (>=80%).
esc=$(printf '\033')
reset="${esc}[0m"
pct_color() {
  if [ "$1" -ge 80 ]; then printf '%s[1;31m' "$esc"   # red
  elif [ "$1" -ge 50 ]; then printf '%s[1;33m' "$esc" # amber
  else printf '%s[1;32m' "$esc"                       # green
  fi
}

# Context-only thresholds: green (<35%), amber (35-49%), red (>=50%).
# Tuned for "context rot" (quality decays well before the hard limit), not the
# wall itself — autoCompactEnabled is false, so this is the only nudge to compact.
# User prefers to compact as early as 50%.
ctx_color() {
  if [ "$1" -ge 50 ]; then printf '%s[1;31m' "$esc"   # red
  elif [ "$1" -ge 35 ]; then printf '%s[1;33m' "$esc" # amber
  else printf '%s[1;32m' "$esc"                       # green
  fi
}

ctx_colored="$(ctx_color "$ctx")${ctx}%${reset}"
lim5_colored="$(pct_color "$lim5")${lim5}%${reset}"
lim7_colored="$(pct_color "$lim7")${lim7}%${reset}"

session="session ${lim5_colored}"

# Countdown to the 5-hour window reset.
left=$((reset5 - $(date +%s)))
if [ "$left" -gt 0 ]; then
  h=$((left / 3600)); m=$(((left % 3600) / 60))
  if [ "$h" -gt 0 ]; then span="${h}h${m}m"
  elif [ "$m" -gt 0 ]; then span="${m}m"
  else span="<1m"
  fi
  session="$session ($span left)"
fi

week="week ${lim7_colored}"

# Countdown to the 7-day window reset.
left7=$((reset7 - $(date +%s)))
if [ "$left7" -gt 0 ]; then
  d=$((left7 / 86400)); h7=$(((left7 % 86400) / 3600)); m7=$(((left7 % 3600) / 60))
  if [ "$d" -gt 0 ]; then span7="${d}d${h7}h"
  elif [ "$h7" -gt 0 ]; then span7="${h7}h${m7}m"
  elif [ "$m7" -gt 0 ]; then span7="${m7}m"
  else span7="<1m"
  fi
  week="$week ($span7 left)"
fi

line2="context ${ctx_colored}  ·  $session  ·  $week"

printf '%s\n%s' "$line1" "$line2"
