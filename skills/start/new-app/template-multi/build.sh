#!/bin/zsh
# Builds __APP_NAME__ for each platform in tools/platforms, or one with --platform.
#   macos     installs ~/Applications/__APP_NAME__.app
#   others    installs into the project simulator bama-__APP_NAME__-<platform>
# Build products live in ~/Library/Developer/__APP_NAME__/DerivedData, outside
# the repo (and outside Dropbox or iCloud, which would try to sync them).
#
# Usage: ./build.sh                       every platform, release build
#        ./build.sh --platform tvos       one platform
#        ./build.sh --debug               debug build
#        ./build.sh --open                then open the app: the Mac app, or the
#                                         simulator with the app launched (left running)
# Logs: .work/logs/build-<platform>.log
setopt pipefail
set -u
source "${0:A:h}/tools/lib.sh"

usage="usage: ./build.sh [--platform <id>] [--debug] [--open]   ids: $platforms"
config=Release
open=0
only=()
while (( $# )); do
  case $1 in
    --debug) config=Debug ;;
    --open) open=1 ;;
    --platform) shift; [[ -n ${1:-} ]] || die $usage; check_platform $1; only=($1) ;;
    -h|--help) print -r -- $usage; exit 0 ;;
    *) die $usage ;;
  esac
  shift
done
(( $#only )) && todo=($only) || todo=($platforms)

# Sign the Mac app with an Apple Development certificate when there is one
# (Xcode > Settings > Accounts). Otherwise ad hoc, which is fine on this Mac.
identity="${SIGN_IDENTITY:-}"
if [[ -z $identity ]]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)
fi
[[ -n $identity ]] || identity=-

total=$(( 1 + 2 * $#todo ))
n=1
stage $n $total "generate __APP_NAME__.xcodeproj from project.yml"
generate_project

failed=()
typeset -A built   # scheme -> app path, so ios and ipados share one build
for id in $todo; do
  scheme=$(scheme_for $id)
  log=$work/logs/build-$id.log
  (( n++ ))
  if [[ -n ${built[$scheme]:-} ]]; then
    stage $n $total "$id: build (same target as an earlier platform, reused)"
  else
    stage $n $total "$id: build $scheme ($config)"
    extra=()
    [[ $id == macos ]] && extra=(CODE_SIGNING_ALLOWED=NO)
    with_timeout 1800 "$id build" xcodebuild -project $root/$name.xcodeproj -scheme $scheme \
      -configuration $config -destination "$(destination_for $id)" -derivedDataPath $dd \
      $extra build >$log 2>&1
    rc=$?
    # Warnings and errors from this project's sources, once each. Fix them.
    grep -E "^$root/.*: (error|warning):" $log | sed "s#^$root/##" | sort -u | head -40
    if (( rc != 0 )) || ! grep -q "BUILD SUCCEEDED" $log; then
      grep -E "error:" $log | sort -u | head -20
      print -r -- "$id: build failed (log: $log)"
      failed+=($id)
      (( n++ ))
      continue
    fi
    if [[ $id == macos ]]; then
      built[$scheme]=$dd/Build/Products/$config/$name.app
    else
      built[$scheme]=$dd/Build/Products/$config-$(sdk_for $id)/$name.app
    fi
  fi
  app=${built[$scheme]}
  print -r -- $app > $work/built-$id

  (( n++ ))
  if [[ $id == macos ]]; then
    stage $n $total "macos: install ~/Applications/$name.app"
    dest=$HOME/Applications/$name.app
    mkdir -p $HOME/Applications
    pkill -f "$dest/Contents/MacOS/$name" 2>/dev/null && sleep 0.5
    rm -rf $dest
    cp -R $app $dest
    xattr -cr $dest
    # Debug builds keep the code in a separate dylib: sign it before the bundle.
    for lib in $dest/Contents/MacOS/*.dylib(N); do
      codesign --force --sign "$identity" $lib 2>&1 | grep -v "replacing existing signature"
    done
    codesign --force --sign "$identity" $dest 2>&1 | grep -v "replacing existing signature"
    codesign --verify $dest || { print -r -- "macos: signing failed"; failed+=($id); continue; }
    print -r -- "installed $dest (signed: $identity)"
    (( open )) && open $dest
  else
    stage $n $total "$id: install into simulator bama-$name-$id"
    udid=$(project_sim $id) || exit 1
    boot_sim $udid
    with_timeout 300 "$id install" xcrun simctl install $udid $app || { failed+=($id); finish_sim $udid 0; continue; }
    print -r -- "installed into bama-$name-$id ($udid)"
    if (( open )); then
      xcrun simctl launch $udid $(bundle_for $id) >/dev/null
      print -r -- "left running: simulator bama-$name-$id with $name open"
    fi
    finish_sim $udid $open
  fi
done

if (( $#failed )); then
  print -r -- "[$total/$total] 100% FAILED: $failed"
  exit 1
fi
print -r -- "[$total/$total] 100% built: $todo"
