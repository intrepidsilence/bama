#!/bin/zsh
# Renders Icon/AppIcon.icon the way a device shows it, with Icon Composer's
# ictool, into one contact sheet:
#   Default, Dark, TintedDark, ClearLight at 256 pt, then Default at 32 and 16 pt.
# Usage: tools/icon_review.sh [--platform macos|ios|ipados|watchos] [out.png]
#        default platform: the first of those in tools/platforms
#        default out: .work/icon/review-<platform>.png
# Xcode compiles the .icon into the Mac, iPhone, iPad, and Watch apps. Apple TV
# and Vision Pro use layered icons in an asset catalog instead (bama:app-icon).
setopt pipefail
set -eu
source "${0:A:h}/lib.sh"
id=""
if [[ ${1:-} == --platform ]]; then id=${2:-}; shift 2; fi
if [[ -z $id ]]; then
  for p in $platforms; do [[ $p == (macos|ios|ipados|watchos) ]] && { id=$p; break }; done
fi
case $id in
  macos) ictool_platform=macOS ;;
  ios|ipados) ictool_platform=iOS ;;
  watchos) ictool_platform=watchOS ;;
  *) die "${id:-this project}: no .icon renders here. The .icon covers macos, ios, ipados, and watchos; Apple TV and Vision Pro use layered icons (bama:app-icon)" ;;
esac
out=${1:-$work/icon/review-$id.png}
mkdir -p ${out:h}
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
[[ -x "$ictool" ]] || die "ictool not found. Install Xcode 26 or later."
tmp=$(mktemp -d -p $work/tmp)
trap 'rm -rf "$tmp"' EXIT

render() { # rendition size file
  "$ictool" "$root/Icon/AppIcon.icon" --export-image --output-file "$tmp/$3" \
    --platform $ictool_platform --rendition "$1" --width "$2" --height "$2" --scale 2 >/dev/null
}
render Default 256 1.png
render Dark 256 2.png
render TintedDark 256 3.png
render ClearLight 256 4.png
render Default 32 5.png
render Default 16 6.png
swift "${0:A:h}/icon_sheet.swift" "$out" "$tmp"/{1,2,3,4,5,6}.png
print -r -- "wrote $out"
