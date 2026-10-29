#!/bin/zsh
# Runs the in-app self-test against a fresh store in .work/. Exit code 0 when
# every check passed on every platform. Run ./build.sh first.
# Usage: tools/selftest.sh                    every platform in tools/platforms
#        tools/selftest.sh --platform tvos    one platform
# Simulators: the project simulator boots if needed and shuts down at the end
# when this run booted it.
setopt pipefail
set -u
source "${0:A:h}/lib.sh"

usage="usage: tools/selftest.sh [--platform <id>]   ids: $platforms"
only=()
while (( $# )); do
  case $1 in
    --platform) shift; [[ -n ${1:-} ]] || die $usage; check_platform $1; only=($1) ;;
    -h|--help) print -r -- $usage; exit 0 ;;
    *) die $usage ;;
  esac
  shift
done
(( $#only )) && todo=($only) || todo=($platforms)
store=$work/self.store
failed=()

test_mac() {
  local bin=$HOME/Applications/$name.app/Contents/MacOS/$name
  [[ -x $bin ]] || { print -r -- "no app at $bin: run ./build.sh --platform macos"; return 1 }
  rm -rf "$HOME/Library/Saved Application State/$bundle.savedState"
  APP_STORE=$store with_timeout 120 "Mac self-test" $bin --selftest
}

test_sim() { # <id>
  local id=$1 app udid log i rc=1 b=$(bundle_for $1)
  app=$(built_app $id) || return 1
  udid=$(project_sim $id) || return 1
  boot_sim $udid
  with_timeout 300 "$id install" xcrun simctl install $udid $app || { finish_sim $udid 0; return 1 }
  log=$work/logs/selftest-$id.log
  : > $log
  SIMCTL_CHILD_APP_STORE=$store xcrun simctl launch --terminate-running-process \
    --stdout=$log --stderr=$log $udid $b --selftest >/dev/null
  for i in {1..240}; do
    grep -q "^SELFTEST " $log && break
    sleep 0.5
  done
  grep -E "^(PASS|FAIL|SELFTEST)" $log
  if grep -q "^SELFTEST PASS" $log; then
    rc=0
  elif ! grep -q "^SELFTEST " $log; then
    print -r -- "TIMEOUT: no SELFTEST line after 120s (log: $log)"
  fi
  xcrun simctl terminate $udid $b 2>/dev/null
  finish_sim $udid 0
  return $rc
}

total=$#todo
n=0
for id in $todo; do
  (( n++ ))
  stage $n $total "$id: self-test"
  rm -f $store $store-shm $store-wal
  if [[ $id == macos ]]; then test_mac; else test_sim $id; fi || failed+=($id)
done
rm -f $store $store-shm $store-wal

if (( $#failed )); then
  print -r -- "[$total/$total] 100% SELFTEST FAILED on: $failed"
  exit 1
fi
print -r -- "[$total/$total] 100% SELFTEST PASS on: $todo"
