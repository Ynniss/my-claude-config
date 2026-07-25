#!/bin/sh
input=$(cat)

IFS='|' read -r model cwd repo ctx lim5 reset5 lim7 <<EOF
$(printf '%s' "$input" | jq -r '[
  (.model.display_name // ""),
  (.workspace.current_dir // .cwd // ""),
  (.workspace.repo.name // ""),
  (.context_window.used_percentage // 0 | floor),
  (.rate_limits.five_hour.used_percentage // 0 | floor),
  (.rate_limits.five_hour.resets_at // 0 | floor),
  (.rate_limits.seven_day.used_percentage // 0 | floor)
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

session="session ${lim5}%"

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

line2="context ${ctx}%  ·  $session  ·  week ${lim7}%"

printf '%s\n%s' "$line1" "$line2"
