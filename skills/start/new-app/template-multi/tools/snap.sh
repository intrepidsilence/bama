#!/bin/zsh
# Snapshots of every page in light and dark, with seed data, on a fresh test store.
# Usage: tools/snap.sh                    every platform in tools/platforms
#        tools/snap.sh --platform ios     one platform
#        tools/snap.sh --open             leave the app open afterwards (the Mac app,
#                                         or the simulator with the app launched)
#        APP_SNAPSHOT_PAGES=all,detail tools/snap.sh   limit the pages
# Writes .work/shots/<platform>/<page>-<light|dark>.png. Run ./build.sh first.
#   macos     the app captures its own window, plus Settings
#   others    the project simulator bama-__APP_NAME__-<platform>: boot, install, then per
#             page: launch on that page, screenshot, quit. The simulator shuts down
#             at the end unless --open, or unless it was already running.
setopt pipefail
set -u
source "${0:A:h}/lib.sh"

usage="usage: tools/snap.sh [--platform <id>] [--open]   ids: $platforms"
open=0
only=()
while (( $# )); do
  case $1 in
    --open) open=1 ;;
    --platform) shift; [[ -n ${1:-} ]] || die $usage; check_platform $1; only=($1) ;;
    -h|--help) print -r -- $usage; exit 0 ;;
    *) die $usage ;;
  esac
  shift
done
(( $#only )) && todo=($only) || todo=($platforms)
store=$work/test.store
failed=()

# Waits until the app's output file has "SNAPSHOT ready <page>"; 60 s at most.
wait_ready() { # <log> <page>
  local i
  for i in {1..120}; do
    grep -q "SNAPSHOT ready $2" $1 2>/dev/null && return 0
    grep -q "SNAPSHOT refused\|SNAPSHOT unknown" $1 2>/dev/null && { cat $1; return 1 }
    sleep 0.5
  done
  print -r -- "TIMEOUT: page $2 not ready after 60s"
  return 1
}

snap_mac() {
  local app=$HOME/Applications/$name.app
  [[ -x $app/Contents/MacOS/$name ]] || { print -r -- "no app at $app: run ./build.sh --platform macos"; return 1 }
  # A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
  rm -rf "$HOME/Library/Saved Application State/$bundle.savedState"
  rm -rf $shots
  APP_STORE=$store APP_SEED=1 APP_SNAPSHOT=$shots with_timeout 300 "Mac snapshots" $app/Contents/MacOS/$name
  (( open )) && open $app
  ls $shots/*.png >/dev/null 2>&1
}

snap_sim() { # <id>
  local id=$1 app udid log pages page mode rc=0 b=$(bundle_for $1)
  app=$(built_app $id) || return 1
  udid=$(project_sim $id) || return 1
  boot_sim $udid
  with_timeout 300 "$id install" xcrun simctl install $udid $app || { finish_sim $udid 0; return 1 }
  # A clean status bar on iPhone and iPad.
  [[ $id == ios || $id == ipados ]] && xcrun simctl status_bar $udid override --time 9:41 \
    --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null
  rm -rf $shots
  mkdir -p $shots
  log=$work/logs/snap-$id.log

  # The first launch seeds the store and prints the app's page list.
  : > $log
  SIMCTL_CHILD_APP_STORE=$store SIMCTL_CHILD_APP_SEED=1 SIMCTL_CHILD_APP_SNAPSHOT_PAGE=list \
    xcrun simctl launch --terminate-running-process --stdout=$log --stderr=$log $udid $b >/dev/null
  for i in {1..60}; do grep -q "SNAPSHOT pages\|SNAPSHOT refused" $log && break; sleep 0.5; done
  pages=$(sed -n 's/^SNAPSHOT pages //p' $log | tail -1)
  [[ -n $pages ]] || { cat $log; print -r -- "$id: the app printed no page list"; finish_sim $udid 0; return 1 }
  [[ -n ${APP_SNAPSHOT_PAGES:-} ]] && pages=$APP_SNAPSHOT_PAGES

  for mode in light dark; do
    # Not every simulator has an appearance switch; APP_APPEARANCE covers the rest.
    xcrun simctl ui $udid appearance $mode >/dev/null 2>&1
    for page in ${(s:,:)pages}; do
      : > $log
      SIMCTL_CHILD_APP_STORE=$store SIMCTL_CHILD_APP_SNAPSHOT_PAGE=$page SIMCTL_CHILD_APP_APPEARANCE=$mode \
        xcrun simctl launch --terminate-running-process --stdout=$log --stderr=$log $udid $b >/dev/null
      if wait_ready $log $page; then
        with_timeout 60 "screenshot" xcrun simctl io $udid screenshot --type=png $shots/$page-$mode.png >/dev/null 2>&1 \
          && print -r -- "SNAPSHOT $shots/$page-$mode.png" || { print -r -- "$id: screenshot of $page failed"; rc=1 }
      else
        rc=1
      fi
      xcrun simctl terminate $udid $b 2>/dev/null
    done
  done
  [[ $id == ios || $id == ipados ]] && xcrun simctl status_bar $udid clear 2>/dev/null
  (( open )) && xcrun simctl launch $udid $b >/dev/null && print -r -- "left running: simulator bama-$name-$id with $name open"
  finish_sim $udid $open
  return $rc
}

total=$#todo
n=0
for id in $todo; do
  (( n++ ))
  stage $n $total "$id: snapshots"
  shots=$work/shots/$id
  # Seed data only fills an empty store, so every platform starts from nothing.
  rm -f $store $store-shm $store-wal
  if [[ $id == macos ]]; then snap_mac; else snap_sim $id; fi || failed+=($id)
done
rm -f $store $store-shm $store-wal

if (( $#failed )); then
  print -r -- "[$total/$total] 100% FAILED: $failed"
  exit 1
fi
print -r -- "[$total/$total] 100% snapshots in $work/shots/"
