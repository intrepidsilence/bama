#!/bin/zsh
# Everything __APP_NAME__ keeps outside the project folder, and a way to remove it.
# Usage: tools/footprint.sh          list every location, whether it exists, and its size
#        tools/footprint.sh clean    remove build products, the installed app, saved window
#                                    state, the project's simulators, the agent CLI's
#                                    ~/.local/bin link (when it points here), and .work/
# Agent registrations of the CLI (~/.claude/skills, ~/.codex/skills, Claude Desktop) are listed only.
# It never removes the real data in ~/Library/Application Support/__APP_NAME__/.
# A skill that creates something new outside the project adds it here, in the same change.
set -u
root=${0:A:h:h}
name="__APP_NAME__"
bundle="__BUNDLE_ID__"
sims=$root/.work/simulators
# The agent CLI's command name. Empty until bama:agent-cli adds the CLI and sets it.
cli=""
cmd=${1:-list}
[[ $cmd == list || $cmd == clean ]] || { echo "usage: tools/footprint.sh [list|clean]"; exit 2; }

# path | what | cleanable (yes or never)
locations=(
  "$root/.work|temporary files (.work/)|yes"
  "$HOME/Library/Developer/$name|build products, test builds, DerivedData|yes"
  "$HOME/Applications/$name.app|installed Mac app|yes"
  "$HOME/Library/Saved Application State/$bundle.savedState|window state|yes"
  "$HOME/Library/Preferences/$bundle.plist|settings the app saved (window sizes, choices)|never"
  "$HOME/Library/Application Support/$name|the user's real data|never"
)

size() { du -sh "$1" 2>/dev/null | cut -f1 | tr -d ' '; }

# The CLI's ~/.local/bin link counts as this project's only when it points
# into this project or its build products.
link=$HOME/.local/bin/$cli
ours_link() {
  [[ -n $cli && -L $link ]] || return 1
  local target=${link:A}
  [[ $target == $root/* || $target == $HOME/Library/Developer/$name/* ]]
}

# Agent registrations of the CLI: listed, never removed (the user may rely on them).
cli_registrations() {
  [[ -n $cli ]] || return 0
  local dir desktop="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  for dir in $HOME/.claude/skills/$cli $HOME/.codex/skills/$cli; do
    [[ -e $dir ]] && printf '%-8s %-7s %s  (agent skill for the %s CLI; clean: never)\n' exists "$(size $dir)" "$dir" "$cli"
  done
  if [[ -f $desktop ]] && jq -e --arg c $cli '.mcpServers[$c]' "$desktop" >/dev/null 2>&1; then
    printf '%-8s %-7s %s  (Claude Desktop entry mcpServers.%s; clean: never)\n' exists - "$desktop" "$cli"
  fi
}

# The project's own simulators, one "<platform> <udid>" per line. Only devices
# named bama-<App>-* count, so a wrong line never touches another simulator.
project_sims() {
  [[ -f $sims ]] || return 0
  local platform udid line
  while read -r platform udid; do
    [[ -n ${udid:-} ]] || continue
    line=$(xcrun simctl list devices | grep -F "($udid)" | head -1)
    if [[ $line == *"bama-$name-"* ]]; then
      echo "$platform $udid"
    fi
  done < $sims
}

if [[ $cmd == list ]]; then
  for entry in $locations; do
    loc=${entry%%|*}; rest=${entry#*|}; what=${rest%%|*}; clean=${rest#*|}
    if [[ -e $loc ]]; then
      printf '%-8s %-7s %s  (%s; clean: %s)\n' exists "$(size $loc)" "$loc" "$what" "$clean"
    else
      printf '%-8s %-7s %s  (%s)\n' absent - "$loc" "$what"
    fi
  done
  found=0
  for line in "${(@f)$(project_sims)}"; do
    [[ -n $line ]] || continue
    found=1
    udid=${line#* }
    printf '%-8s %-7s simulator bama-%s-%s %s  (clean: yes)\n' exists \
      "$(size $HOME/Library/Developer/CoreSimulator/Devices/$udid)" "$name" "${line%% *}" "$udid"
  done
  (( found )) || printf '%-8s %-7s %s\n' absent - "project simulators (none in .work/simulators)"
  if ours_link; then
    printf '%-8s %-7s %s -> %s  (agent CLI link; clean: yes)\n' exists - "$link" "${link:A}"
  elif [[ -n $cli && -L $link ]]; then
    printf '%-8s %-7s %s -> %s  (points outside this project; clean: never)\n' exists - "$link" "${link:A}"
  fi
  cli_registrations
  exit 0
fi

# clean: simulators first, because their list lives in .work/.
for line in "${(@f)$(project_sims)}"; do
  [[ -n $line ]] || continue
  udid=${line#* }
  xcrun simctl shutdown $udid 2>/dev/null
  if xcrun simctl delete $udid; then echo "removed simulator bama-$name-${line%% *} ($udid)"; fi
done
# The CLI link first: it points into the build products removed below.
if ours_link; then rm -f "$link" && echo "removed $link (agent CLI link)"; fi
# A running copy of the installed app holds its files open. Quit it first.
pkill -f "$HOME/Applications/$name.app/Contents/MacOS/$name" 2>/dev/null && sleep 1
for entry in $locations; do
  loc=${entry%%|*}; rest=${entry#*|}; what=${rest%%|*}; clean=${rest#*|}
  [[ $clean == yes && -e $loc ]] || continue
  s=$(size $loc)
  rm -rf "$loc" && echo "removed $loc ($s, $what)"
done
for entry in $locations; do
  loc=${entry%%|*}; rest=${entry#*|}; what=${rest%%|*}; clean=${rest#*|}
  [[ $clean == never && -e $loc ]] && echo "kept $loc ($what)"
done
cli_registrations | sed 's/^exists *[^ ]* */kept /'
exit 0
