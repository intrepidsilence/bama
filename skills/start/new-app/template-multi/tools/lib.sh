# Shared by build.sh and the tools/ scripts. Each one sources it:
#   source "${0:A:h}/tools/lib.sh"      (build.sh)
#   source "${0:A:h}/lib.sh"            (tools/*.sh)
# Platform ids: macos ios ipados tvos watchos visionos. This project's list is
# in tools/platforms. Everything temporary goes to .work/, never /tmp.

root=${${(%):-%x}:A:h:h}
name="__APP_NAME__"
bundle="__BUNDLE_ID__"
work=$root/.work
# Build products stay outside the project, so iCloud or Dropbox never sync them.
dd=$HOME/Library/Developer/$name/DerivedData
all_ids=(macos ios ipados tvos watchos visionos)
platforms=(${(z)"$(<$root/tools/platforms)"})
mkdir -p $work/tmp $work/logs
# fd 3 stays the terminal, so heartbeats show while a command's output goes to a log.
exec 3>&1

die() { print -r -- "$*" >&2; exit 1 }

# stage <n> <of> <text>: prints "[n/N] pct% text" so a long run shows where it is.
stage() { print -r -- "[$1/$2] $(( ($1 - 1) * 100 / $2 ))% $3" }

# with_timeout <seconds> <label> <command...>
# Runs the command, prints a heartbeat every minute, and stops it with a
# TIMEOUT line when it runs longer than <seconds>.
with_timeout() {
  local secs=$1 label=$2; shift 2
  "$@" &
  local pid=$!
  _child=$pid
  (
    local t=0
    while (( t < secs )); do
      sleep 5; (( t += 5 ))
      kill -0 $pid 2>/dev/null || exit 0
      (( t % 60 == 0 )) && print -r -- "  ... $label still running (${t}s)" >&3
    done
    print -r -- "TIMEOUT: $label stopped after ${secs}s" >&3
    kill -TERM $pid 2>/dev/null
  ) &
  local dog=$!
  _dog=$dog
  wait $pid
  local rc=$?
  pkill -P $dog 2>/dev/null
  kill $dog 2>/dev/null
  wait $dog 2>/dev/null
  _child="" _dog=""
  return $rc
}

# Stopping a script (Ctrl-C, kill) also stops the command it is waiting on.
_child="" _dog=""
trap '[[ -n $_dog ]] && { pkill -P $_dog; kill $_dog; } 2>/dev/null; [[ -n $_child ]] && kill -TERM $_child 2>/dev/null; exit 130' INT TERM

# check_platform <id>: a known id, and a target of this project.
check_platform() {
  (( ${all_ids[(Ie)$1]} )) || die "unknown platform '$1'. Ids: $all_ids"
  (( ${platforms[(Ie)$1]} )) || die "this project has no $1 target. Its platforms (tools/platforms): $platforms"
}

scheme_for() {
  case $1 in
    macos) print $name ;;
    ios|ipados) print $name-iOS ;;
    tvos) print $name-tvOS ;;
    watchos) print $name-watchOS ;;
    visionos) print $name-visionOS ;;
  esac
}

destination_for() {
  case $1 in
    macos) print "generic/platform=macOS" ;;
    ios|ipados) print "generic/platform=iOS Simulator" ;;
    tvos) print "generic/platform=tvOS Simulator" ;;
    watchos) print "generic/platform=watchOS Simulator" ;;
    visionos) print "generic/platform=visionOS Simulator" ;;
  esac
}

sdk_for() {
  case $1 in
    ios|ipados) print iphonesimulator ;;
    tvos) print appletvsimulator ;;
    watchos) print watchsimulator ;;
    visionos) print xrsimulator ;;
  esac
}

bundle_for() { [[ $1 == watchos ]] && print $bundle.watchkitapp || print $bundle }

# The app build.sh built last for <id>, recorded in .work/built-<id>.
built_app() {
  local app
  [[ -f $work/built-$1 ]] && app=$(<$work/built-$1)
  [[ -n ${app:-} && -d $app ]] || die "no $1 build yet: run ./build.sh --platform $1"
  print -r -- $app
}

xcodegen_bin() {
  local bin
  for bin in ${commands[xcodegen]:-} /opt/homebrew/bin/xcodegen /usr/local/bin/xcodegen; do
    [[ -x $bin ]] && { print -r -- $bin; return 0 }
  done
  die "xcodegen not found. Install it: brew install xcodegen"
}

# Writes __APP_NAME__.xcodeproj from project.yml. Cheap, so every build does it:
# new source files join the targets without editing the project.
generate_project() {
  $(xcodegen_bin) generate --spec $root/project.yml --project $root --quiet >$work/logs/xcodegen.log 2>&1 \
    || { cat $work/logs/xcodegen.log; die "xcodegen failed"; }
}

# --- Simulators -------------------------------------------------------------
# The project's own simulators are named bama-<App>-<platform> and recorded in
# .work/simulators ("<platform> <udid>" per line). Scripts never boot, shut
# down, or erase any other simulator: other sessions share this Mac.

device_types_for() {
  case $1 in
    ios) print iPhone-17-Pro iPhone-17 iPhone-16-Pro ;;
    ipados) print iPad-Pro-13-inch-M5-12GB iPad-Pro-11-inch-M5-12GB iPad-Air-13-inch-M3 ;;
    tvos) print Apple-TV-4K-3rd-generation-4K Apple-TV-4K-3rd-generation-1080p ;;
    watchos) print Apple-Watch-Series-11-46mm Apple-Watch-Series-10-46mm Apple-Watch-Ultra-3-49mm ;;
    visionos) print Apple-Vision-Pro-4K Apple-Vision-Pro ;;
  esac
}

runtime_platform_for() {
  case $1 in
    ios|ipados) print iOS ;;
    tvos) print tvOS ;;
    watchos) print watchOS ;;
    visionos) print xrOS ;;
  esac
}

sim_field() { # <udid> <field>
  xcrun simctl list devices -j | jq -r --arg u $1 --arg f $2 '[.devices[][] | select(.udid == $u)] | first | .[$f] // empty'
}

# project_sim <id>: prints the udid of the project's simulator for <id>,
# creating it on first use with the newest installed runtime.
project_sim() {
  local id=$1 simname="bama-$name-$1" udid="" runtime type
  [[ -f $work/simulators ]] && udid=$(awk -v p=$id '$1 == p { u = $2 } END { print u }' $work/simulators)
  [[ -n $udid && $(sim_field $udid name) == $simname ]] || udid=""
  if [[ -z $udid ]]; then
    # One left from an earlier run whose .work/ was removed.
    udid=$(xcrun simctl list devices -j | jq -r --arg n $simname \
      '[.devices[][] | select(.name == $n and .isAvailable)] | first | .udid // empty')
  fi
  if [[ -z $udid ]]; then
    runtime=$(xcrun simctl list runtimes -j | jq -r --arg p $(runtime_platform_for $id) \
      '[.runtimes[] | select(.isAvailable and .platform == $p)] | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty')
    [[ -n $runtime ]] || die "no $(runtime_platform_for $id) simulator runtime installed (Xcode > Settings > Components)"
    for type in ${(z)"$(device_types_for $id)"}; do
      udid=$(xcrun simctl create $simname com.apple.CoreSimulator.SimDeviceType.$type $runtime 2>/dev/null) && break
    done
    [[ -n $udid ]] || die "could not create a $id simulator with $runtime"
    print -r -- "created simulator $simname ($udid)" >&2
  fi
  { [[ -f $work/simulators ]] && grep -v "^$id " $work/simulators; print -r -- "$id $udid" } > $work/simulators.new
  mv $work/simulators.new $work/simulators
  print -r -- $udid
}

# boot_sim <udid>: boots it and waits until it is ready. Sets booted_here=1
# when this run booted it, so the script can shut it down again at the end.
booted_here=0
boot_sim() {
  if [[ $(sim_field $1 state) == Booted ]]; then booted_here=0; return 0; fi
  with_timeout 300 "simulator boot" xcrun simctl bootstatus $1 -b >/dev/null || die "simulator $1 did not boot"
  booted_here=1
}

# Shuts the simulator down if this run booted it, unless --open asked to keep it.
finish_sim() { # <udid> <open>
  if (( $2 )); then
    # Xcode 26 and earlier show simulators in Simulator.app; Xcode 27 has no
    # Simulator.app and shows them in DeviceHub.
    if open -b com.apple.iphonesimulator --args -CurrentDeviceUDID $1 2>/dev/null; then
      print -r -- "opened Simulator on bama-$name ($1)"
    elif open -b com.apple.dt.Devices 2>/dev/null; then
      print -r -- "opened DeviceHub: pick the bama-$name simulator there to see the app ($1)"
    else
      print -r -- "the simulator is running, but no Simulator app was found to show it ($1)"
    fi
  elif (( booted_here )); then
    xcrun simctl shutdown $1 2>/dev/null
  fi
}
