#!/bin/zsh
# Snapshots of every page in light and dark, with seed data, on a fresh test store.
# Usage: tools/snap.sh [--platform macos] [--open]
#        APP_SNAPSHOT_PAGES=all,settings tools/snap.sh
# Writes .work/shots/macos/<page>-<light|dark>.png and -layout.json, then quits the
# test copy. --open opens the installed app afterwards.
set -u
root=${0:A:h:h}
open=0
while (( $# )); do
  case $1 in
    --open) open=1 ;;
    --platform) shift; [[ ${1:-} == macos ]] || { echo "this is a Mac-only project: --platform takes macos"; exit 2; } ;;
    *) echo "usage: tools/snap.sh [--platform macos] [--open]"; exit 2 ;;
  esac
  shift
done
app=~/Applications/__APP_NAME__.app/Contents/MacOS/__APP_NAME__
[[ -x $app ]] || { echo "no app at $app: run ./build.sh first"; exit 1; }
store=$root/.work/test.store
shots=$root/.work/shots/macos
mkdir -p $root/.work
# A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
rm -rf ~/Library/Saved\ Application\ State/__BUNDLE_ID__.savedState
# Seed data only fills an empty store, so start from nothing.
rm -f $store $store-shm $store-wal
rm -rf $shots
APP_STORE=$store APP_SEED=1 APP_SNAPSHOT=$shots $app
rc=$?
(( open )) && open ~/Applications/__APP_NAME__.app
exit $rc
