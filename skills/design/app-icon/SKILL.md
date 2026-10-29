---
name: app-icon
description: App icon for every Apple platform the app targets, made as one Icon Composer file (Icon/AppIcon.icon, JSON plus SVG layers) for macOS, iOS, iPadOS, and watchOS, plus layered image stacks for tvOS and visionOS, compiled with actool and reviewed in every look. Use when the user wants an app icon, a better icon, a Dock or Home screen icon, or a tvOS Top Shelf image.
allowed-tools: Bash(tools/make_icon.sh) Bash(tools/icon_review.sh *) Bash(./build.sh *) Bash(tools/snap.sh *) Bash(swift *) Bash(xcrun actool *) Bash(xcrun simctl *) Read Edit Write
---

# App icon

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

One design, one set of layers, every target. What carries it depends on
the platform: [HIG App icons; Xcode, Creating your app icon using Icon
Composer]

| Target | Format | Shape after the system masks it | HIG layout size |
| --- | --- | --- | --- |
| macOS, iOS, iPadOS | Icon Composer `.icon` (Liquid Glass) | rounded square | 1024 x 1024 px |
| watchOS | the same `.icon` file | circle | 1088 x 1088 px |
| tvOS | image stack in an asset catalog, 2 to 5 layers, parallax | rounded rectangle | 400 x 240 pt (800 x 480 px) |
| visionOS | solid image stack in an asset catalog, 2 or 3 layers | circle | 1024 x 1024 px |

The `.icon` file keeps one 1024 x 1024 canvas for macOS, iOS, iPadOS, and
watchOS; Icon Composer fits it to each shape, including the watch circle.

The `.icon` file lives in git: `Icon/AppIcon.icon`, a folder with
`icon.json` and SVG layers in `Assets/`. Claude writes both by hand. The
system adds the glass, the highlights, the shadow, the mask, and the dark,
tinted, and clear looks. Claude never draws those.

- `tools/make_icon.sh` compiles it with `actool` into `Resources/Assets.car`
  and `Resources/AppIcon.icns` (Mac template). In the multi-platform
  template Xcode compiles it for each target.
- `tools/icon_review.sh` renders it with `ictool` (Icon Composer's command
  line tool, inside Xcode) into one contact sheet in `.work/icon/`.

Older Mac app without these files: copy `Icon/`, `tools/make_icon.sh`,
`tools/icon_review.sh`, and `tools/icon_sheet.swift` from the `bama:new-app`
Mac template, the icon block of its `build.sh`, and `CFBundleIconName` =
`AppIcon` from its `Info.plist.in`.

Other cases: [more-cases.md](more-cases.md).
- An Xcode or XcodeGen project (Xcode compiles the `.icon` itself).
- Converting an existing flat icon into layers.
- A Dock icon that changes with a theme or style.

Per-platform stacks: [tvos-icon.md](tvos-icon.md) (App Icon and Top Shelf
images) and [visionos-icon.md](visionos-icon.md).

## The file

```text
Icon/AppIcon.icon/
  icon.json
  Assets/front.svg     1024 x 1024 canvas, same as the icon
  Assets/back.svg
```

```json
{
  "fill" : { "automatic-gradient" : "srgb:0.20000,0.42000,0.96000,1.00000" },
  "groups" : [
    {
      "layers" : [
        { "glass" : true, "image-name" : "front.svg", "name" : "front" },
        { "glass" : true, "image-name" : "back.svg", "name" : "back", "opacity" : 0.6 }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.5 }
    }
  ],
  "supported-platforms" : { "squares" : [ "macOS" ] }
}
```

- `fill` is the background: `solid`, `automatic-gradient` (one color, the
  system adds a soft gradient), or `linear-gradient` with two colors.
  Colors are `srgb:r,g,b,a` or `display-p3:r,g,b,a`.
- The first layer in the list sits on top.
- Shadow `kind`: `neutral`, `layer-color`, or `none`.
- A different look per appearance goes in `<key>-specializations`, for
  example `fill-specializations` with an entry for `dark`.
- The art fills the whole square. Never draw the rounded square, a
  circle, a margin, a shadow, or a sheen: the system adds them.
- `supported-platforms` sets which platforms Icon Composer shows. Mac
  only: `{ "squares" : [ "macOS" ] }`. iPhone, iPad, and Mac:
  `{ "squares" : "shared" }`. With a watch app, add
  `"circles" : [ "watchOS" ]`. `actool` compiles the file for any of the
  three either way.

## What makes it look like Apple made it

1. One idea. One object that says what the app does: a check for tasks, a
   stack of cards for a reader, a waveform for audio.
2. No text, no letters, no screenshots of the UI.
3. The glyph is the app's own drawing. Never use an SF Symbol, or a shape
   that looks like one: the SF Symbols license forbids symbols in app
   icons.
4. Two or three layers, each one flat shape in white or one tint. Glass
   gives the depth. Put the main shape on top, a softer one behind it.
5. The glyph is large: about 45 to 55 percent of the canvas width. Thin
   parts vanish at 16 px.
6. Filled shapes only. A stroke on an open path leaves a faint glass line.
7. One background hue. `automatic-gradient` looks right almost every time.
8. Centered. watchOS and visionOS cut the square to a circle, so nothing
   that matters sits in the corners.
9. The same design on every target, so people know it is one app.
10. Distinct from the apps next to it in the Dock or on the Home screen.
    On a Mac, list Dock apps without a screenshot:
    `defaults read com.apple.dock persistent-apps | grep file-label`.

## Steps

1. Read the brief (`docs/BRIEF.md`, or `muninn_recall` with the app's
   name and "brief" in `muninn` mode) for the idea and the target
   platforms. Write three icon concepts in one line each: the object, the
   background color, the layers. Pick one with the user, or pick the one
   that is easiest to recognize at 16 px.

   Check: one concept is chosen, it uses no SF Symbol, and Claude has
   listed which formats from the table above the targets need.

2. Write the layers as SVG files in `Icon/AppIcon.icon/Assets/`, on a
   1024 x 1024 canvas, white filled shapes (`rect` with `rx`, `circle`,
   `path`). Write `icon.json` to list them, with `supported-platforms`
   for the targets. Delete layer files no longer used.

   Check: every `image-name` in `icon.json` has a file in `Assets/`.

3. Compile:

   ```bash
   tools/make_icon.sh
   # wrote Resources/Assets.car and Resources/AppIcon.icns
   ```

   In the multi-platform template, build each target instead
   (`bama:build-and-verify`).

   Check: the line above prints, or every target builds. On an error, fix
   the file it names.

4. Review every look:

   ```bash
   tools/icon_review.sh
   # wrote .work/icon/<file>.png (the script prints the path)
   ```

   Read the PNG. It shows Default, Dark, Tinted, and Clear at 256 pt, then
   Default at 32 and 16 pt. The glyph reads in every look and is still
   recognizable at 16 pt. If not, make it bigger, bolder, or simpler.

   For iPhone, iPad, and watch targets, render those platforms too (the
   watch shows the circle):

   ```bash
   ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
   "$ictool" Icon/AppIcon.icon --export-image --output-file .work/icon/ios.png \
     --platform iOS --rendition Default --width 256 --height 256 --scale 2
   "$ictool" Icon/AppIcon.icon --export-image --output-file .work/icon/watchos.png \
     --platform watchOS --rendition Default --width 256 --height 256 --scale 2
   ```

   Check: Claude has read every review PNG, and the glyph reads in each
   look, at 16 pt, and inside the watch circle.

5. Iterate two or three times. Change one thing per round: glyph size,
   layer opacity, background color.

   Check: the last round's review PNGs pass step 4's check.

6. tvOS or visionOS target: build its stack from the same SVG art with
   [tvos-icon.md](tvos-icon.md) or [visionos-icon.md](visionos-icon.md).

   Check: the stack compiles with no `error:` lines from `actool`.

7. Look at the real icon on each target.

   - **macOS**: `./build.sh --open` and look at the Dock. If the Dock
     still shows the old icon, macOS cached it. Run
     `touch ~/Applications/<App>.app` and restart the app. If it still
     shows the old one, Claude asks the user before `killall Dock`: it
     restarts the Dock for the whole desktop.
   - **iOS, iPadOS, tvOS, watchOS, visionOS**: install on the project
     simulator, go to the Home screen, and screenshot it:

     ```bash
     ./build.sh --platform <id>                  # builds and installs; snap.sh never builds
     tools/snap.sh --platform <id> --open        # leaves the simulator up with the app
     udid=$(awk '$1 == "<id>" { print $2 }' .work/simulators)
     xcrun simctl terminate "$udid" <bundle-id>  # back to the Home screen
     xcrun simctl io "$udid" screenshot .work/icon/home-<id>.png
     xcrun simctl shutdown "$udid"               # unless the user wants it left open
     ```

     Use only the project's own simulator from `.work/simulators`. A new
     app may land on a later Home screen page or in the App Library; the
     icon review sheet stays the main check where the simulator cannot
     show it. Shut the simulator down when done, unless the user wants it
     open.

   Check: the Dock or each target's Home screen screenshot shows the new
   icon, and Claude has read each screenshot.

The user can fine-tune the file by hand in Icon Composer:
`open -a "Icon Composer" Icon/AppIcon.icon`. Run `tools/make_icon.sh`
(or rebuild) after they save.

## Gotchas

- The folder must be named `AppIcon.icon`. With another name, `actool`
  writes nothing and still exits 0. `make_icon.sh` checks for that.
- A missing layer file: `actool` fails with the name, but `ictool` exits 0
  and renders an empty background. Compile before reviewing.
- PDF layers do not render. Use SVG or PNG.
- `xcrun ictool` is a different tool. Icon Composer's `ictool` lives at
  `$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool`.
  It renders `macOS`, `iOS`, and `watchOS`; it refuses `tvOS` and
  `visionOS`, which use image stacks.
- The Mac app needs `CFBundleIconName` = `AppIcon` in `Info.plist` and
  `Assets.car` in `Contents/Resources`. `AppIcon.icns` covers older Finder
  views and macOS 15.
- An Icon Composer file replaces the target's `AppIcon` set in its asset
  catalog: delete the set, since two icons named `AppIcon` clash. Apple
  says to keep an asset catalog icon only when the icon must show on
  releases before 26.

Done when every target has its icon (the `.icon` for macOS, iOS, iPadOS,
and watchOS; a stack for tvOS and visionOS), every build compiles it with
no errors, the review PNGs show a clear glyph in every look and at 16 pt,
the icon uses no SF Symbol, and the Dock or each target's Home screen
shows the new icon (or Claude has said which target it could not show and
why).
