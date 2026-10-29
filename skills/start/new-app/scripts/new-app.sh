#!/bin/zsh
# Creates a new Apple app from a template next to this script.
# Usage: new-app.sh <AppName> <bundle-id> [parent-folder] [--platforms <list>]
#   new-app.sh Tasks com.yourname.tasks ~/Developer
#   new-app.sh Tasks com.yourname.tasks ~/Developer --platforms ios,ipados,tvos
# --platforms: a comma list of macos ios ipados tvos watchos visionos. Default: macos.
#   macos alone      template/        a Swift package, no Xcode project
#   anything else    template-multi/  XcodeGen project.yml with one app target per
#                                     platform, a shared <AppName>Kit package, shared SwiftUI
# Creates <parent-folder>/<AppName>. If that folder exists, it must not have a
# Package.swift or project.yml yet; existing files (like docs/BRIEF.md) are kept.
# AppName must be one word in UpperCamelCase (letters and digits only).
set -euo pipefail
usage="usage: new-app.sh <AppName> <bundle-id> [parent-folder] [--platforms macos,ios,ipados,tvos,watchos,visionos]"
all_ids=(macos ios ipados tvos watchos visionos)
args=()
list=macos
while (( $# )); do
  case $1 in
    --platforms) shift; list=${1:?$usage} ;;
    --platforms=*) list=${1#--platforms=} ;;
    -h|--help) echo $usage; exit 0 ;;
    -*) echo $usage; exit 1 ;;
    *) args+=($1) ;;
  esac
  shift
done
(( $#args >= 2 && $#args <= 3 )) || { echo $usage; exit 1; }
name=$args[1]
bundle=$args[2]
parent=${args[3]:-$PWD}
[[ "$name" =~ ^[A-Z][A-Za-z0-9]*$ ]] || { echo "AppName must be UpperCamelCase letters and digits, like Tasks or DailyLog"; exit 1; }
[[ "$bundle" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || { echo "bundle-id must be reverse DNS, like com.yourname.tasks"; exit 1; }

# The platforms, checked, without repeats, in the order of all_ids.
wanted=(${(s:,:)list})
for id in $wanted; do
  (( ${all_ids[(Ie)$id]} )) || { echo "unknown platform '$id'. Ids: ${(j:, :)all_ids}"; exit 1; }
done
platforms=()
for id in $all_ids; do (( ${wanted[(Ie)$id]} )) && platforms+=($id); done
(( $#platforms )) || { echo "--platforms is empty. Ids: ${(j:, :)all_ids}"; exit 1; }

if [[ $platforms == macos ]]; then
  kind=mac
  template=${0:A:h:h}/template
else
  kind=multi
  template=${0:A:h:h}/template-multi
  [[ -x /opt/homebrew/bin/xcodegen || -n ${commands[xcodegen]:-} ]] || echo "note: xcodegen is not installed; build.sh needs it: brew install xcodegen"
fi
dest="$parent/$name"
# An existing folder is fine if it has no project yet (for example only docs/BRIEF.md).
[[ ! -e "$dest/Package.swift" ]] || { echo "$dest already has a Package.swift"; exit 1; }
[[ ! -e "$dest/project.yml" ]] || { echo "$dest already has a project.yml"; exit 1; }

mkdir -p "$dest"
# Keep files that are already there. Not `cp -n`: on macOS it exits 1 when it
# skips a file, and set -e then stops the script halfway.
rsync -a --ignore-existing "$template/" "$dest/"
# A kept .gitignore gets the template lines it lacks.
if ! cmp -s "$template/.gitignore" "$dest/.gitignore"; then
  [[ -z $(tail -c1 "$dest/.gitignore") ]] || echo >> "$dest/.gitignore"
  grep -vxF -f "$dest/.gitignore" "$template/.gitignore" >> "$dest/.gitignore" || true
fi

# The paths the template created, named as they end up. Only these get
# placeholders filled and get committed.
raw=()
for entry in "$template"/*(DN); do
  [[ $kind == multi && ${entry:t} == project ]] || raw+=(${entry:t})
done
created=(${raw//__APP_NAME__/$name})

if [[ $kind == multi ]]; then
  # project.yml: the shared part, then one target block per platform.
  parts=("$dest/project/base.yml")
  (( ${platforms[(Ie)macos]} )) && parts+=("$dest/project/macos.yml")
  (( ${platforms[(Ie)ios]} || ${platforms[(Ie)ipados]} )) && parts+=("$dest/project/ios.yml")
  (( ${platforms[(Ie)tvos]} )) && parts+=("$dest/project/tvos.yml")
  (( ${platforms[(Ie)watchos]} )) && parts+=("$dest/project/watchos.yml")
  (( ${platforms[(Ie)visionos]} )) && parts+=("$dest/project/visionos.yml")
  cat $parts > "$dest/project.yml"
  rm -rf "$dest/project"
  # TARGETED_DEVICE_FAMILY: 1 iPhone, 2 iPad.
  family=""
  (( ${platforms[(Ie)ios]} )) && family=1
  (( ${platforms[(Ie)ipados]} )) && family=${family:+$family,}2
  sed -i '' -e "s/__IOS_FAMILY__/$family/" "$dest/project.yml"
  echo $platforms > "$dest/tools/platforms"
  created+=(project.yml)
fi

# Rename placeholder folders and files, deepest first.
for p in ${(f)"$(cd "$dest" && find $raw -depth -name '*__APP_NAME__*')"}; do
  [[ -n $p ]] && mv "$dest/$p" "$dest/${p:h}/${${p:t}//__APP_NAME__/$name}"
done
# Replace the placeholders in every text file the template created.
(cd "$dest" && grep -rlI "__APP_NAME__\|__BUNDLE_ID__" $created || true) | while read -r f; do
  sed -i '' -e "s/__APP_NAME__/$name/g" -e "s/__BUNDLE_ID__/$bundle/g" "$dest/$f"
done
chmod +x "$dest/build.sh" "$dest"/tools/*.sh
[[ -f "$dest/tools/check-layout.swift" ]] && chmod +x "$dest/tools/check-layout.swift"

cd "$dest"
[[ -d .git ]] || git init -q
# Stage by name: the template's files, and docs/ when the brief is already there.
# Never git add -A, so stray files and .work/ stay out.
[[ -d docs ]] && created+=(docs)
git add -- $created
if [[ $kind == mac ]]; then
  git commit -qm "Create $name from the macOS app template"
else
  git commit -qm "Create $name from the multi-platform app template ($platforms)"
fi
echo "created $dest ($platforms)"
if [[ $kind == mac ]]; then
  echo "next: cd \"$dest\" && ./build.sh --open"
else
  echo "next: cd \"$dest\" && ./build.sh --platform ${platforms[1]} --open"
fi
