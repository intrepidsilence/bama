#!/bin/zsh
# Runs the in-app self-test against a fresh store in .work/. Exit code 0 when every check passed.
# Usage: tools/selftest.sh [--platform macos]
set -u
root=${0:A:h:h}
while (( $# )); do
  case $1 in
    --platform) shift; [[ ${1:-} == macos ]] || { echo "this is a Mac-only project: --platform takes macos"; exit 2; } ;;
    *) echo "usage: tools/selftest.sh [--platform macos]"; exit 2 ;;
  esac
  shift
done
app=~/Applications/__APP_NAME__.app/Contents/MacOS/__APP_NAME__
[[ -x $app ]] || { echo "no app at $app: run ./build.sh first"; exit 1; }
rm -rf ~/Library/Saved\ Application\ State/__BUNDLE_ID__.savedState
mkdir -p $root/.work
store=$root/.work/self.store
rm -f $store $store-shm $store-wal
APP_STORE=$store $app --selftest
