---
name: design-from-app
description: Rebuild the look of an app the user likes, from any Apple platform, as a native SwiftUI design kit, by measuring its screenshots (sizes, spacing, type, colors, icons) in points at the screenshot's scale, building its parts with that platform's native controls, and comparing pixel by pixel until they match. Use when the user names an app whose look they want, shares screenshots of one, or says "make it look like X".
argument-hint: "<app name or screenshot paths>"
---

# Design from app

Look at an app, measure it, and rebuild its design system in SwiftUI. The
result is a design kit (`bama:design-kit`) with the reference app's
numbers, and one reference screen that matches the screenshot.

Guessing gets close. Measuring gets it right. Two scripts do the
measuring, next to this skill:

- `scripts/measure.swift`: sizes, positions, text heights, and colors from
  a screenshot.
- `scripts/compare.swift`: a side-by-side, a diff, and the share of pixels
  that differ.

Run them with `swift "${CLAUDE_SKILL_DIR}/scripts/measure.swift" ...`.
All coordinates are points: pixels divided by the screenshot's scale.

## 1. Get the screenshots

Ask for screenshots, or take them with the `bama:clone` skill. Claude
accepts them where they are:

- `docs/screens/<NN>-<page>.png`: from `bama:clone`, one platform.
- `docs/screens/<platform>/<NN>-<page>.png`: from `bama:clone`, several
  platforms.
- `design/reference/<platform>/`: screenshots the user hands over.

Below, `<ref>` is the main reference screenshot at whichever of these
paths it has. Claude needs:

- The window or screen only, at the device's native scale, no desktop and
  no device frame.
- One screen with the most parts on it (a sidebar, a list, a toolbar, a
  tab bar), plus close-ups of menus, dialogs, a focused item on tvOS, and
  dark mode if they matter.
- The platform the reference runs on, and its scale:

| Reference from | Scale (`--scale`) | Native size to expect |
| --- | --- | --- |
| Mac, Retina | 2 | the window, in points x 2 |
| iPhone | 3 (2 on older models) | the screen, in points x 3 |
| iPad | 2 | the screen or the window |
| Apple TV HD | 1 | 1920 x 1080 px |
| Apple TV 4K | 2 | 3840 x 2160 px |
| Apple Watch | 2 | the screen, in points x 2 |
| Vision Pro | 2 | one window capture |

- The size in points: `measure.swift info shot.png --scale <n>`.

Check: `info` prints a size in points that matches the device (an iPhone
screen is about 400 pt wide, an Apple TV 1920 pt), and every screenshot of
one platform uses the same scale.

## 2. List the parts

Look at each screenshot and name every distinct part: navigation chrome
(window chrome, tab bar, navigation bar, ornament), sidebar row, section
header, primary action, list row, checkbox, date chip, icon button,
divider, focused card. Start `design/KIT.md` from the `bama:design-kit`
skill's kit-spec.md with one section per part.

Check: every visible element on the main screenshot belongs to a part.

## 3. Measure

Fill `design/KIT.md` with numbers, not estimates. Pass `--scale` on every
command. The recipes and the traps are in [measuring.md](measuring.md).
In short:

| To find | Command |
| --- | --- |
| Sidebar width, panes | `hline shot.png <y in an empty area>` |
| Row positions and pitch | `rows shot.png <x0> <x1> [y0 y1]` |
| Left edges, gaps | `cols shot.png <y0> <y1> [x0 x1]` |
| Selection pill, dividers | `vline` and `hline` through it, `--tolerance 4` |
| Text and icon colors | `ink shot.png x y w h` |
| Surface colors | `palette shot.png x y w h` |
| A close look | `crop shot.png x y w h .work/compare/<name>.png 4` |

Check: every token and every part size in `design/KIT.md` has a number
from a command, in points.

## 4. Find the font and the icons

- Most Apple apps use the system font, even web apps. Start there. When
  the letters differ (a, g, t, digits), name the font and pick it or an
  open alternative with a license that allows bundling.
- Text sizes come from step 6: build, measure the same word in both
  images, scale.
- Icons: note the size, stroke weight, corners, and whether selected rows
  switch to a filled form. Match with SF Symbols at a light weight first;
  draw the ones that do not match as shapes (`bama:design-kit` parts.md,
  Icons).

Check: `design/KIT.md` names the font, the icon source, and the icon size
and weight.

## 5. Build the kit and one screen

Rebuild for the reference's own platform first, with that platform's
native containers: a Mac window with a sidebar, an iPhone
`NavigationStack` and `TabView`, an iPad `NavigationSplitView`, a tvOS
grid of focusable cards, a watchOS `List`, a visionOS window with
ornaments. Copy the look of the parts, not a structure the platform does
not use. Then carry the kit to the app's other targets with
`Platform.value`, sized for each (call the Skill tool with
`bama:platform-design`).

Call the Skill tool with `bama:design-kit` and build the tokens, the
parts, the chrome, and the gallery from `design/KIT.md`. Then build the
main screenshot's screen from kit parts only, with the same data and the
same window or screen size (the matching simulator device for iOS, iPadOS,
tvOS, watchOS, and visionOS).

Check: a snapshot of that screen (`./build.sh --platform <id>`, then
`tools/snap.sh --platform <id>`; PNGs in `.work/shots/<id>/`) has the same size in pixels as the reference.

## 6. Compare until it matches

```bash
swift "${CLAUDE_SKILL_DIR}/scripts/compare.swift" <ref> \
  .work/shots/<id>/<page>-light.png .work/compare/main --scale <n>
swift "${CLAUDE_SKILL_DIR}/scripts/compare.swift" <ref> \
  .work/shots/<id>/<page>-light.png .work/compare/sidebar 0 0 220 300 --scale <n>
```

Open `side-by-side.png` and `diff.png` with the Read tool. Then measure
the same rows, edges, and words in both images, and fix the tokens, not
the views. Order: window or screen size, text sizes, columns and left
edges, row heights, colors, icons.

Check: under 2% of pixels differ on the whole window or screen, and every
row and left edge is within 1.5 pt of the reference.

## 7. Make it the user's own

Before the app ships to anyone else, replace what belongs to the other
company: its name, logo, illustrations, and any font or icon it owns.
Keep the structure, the spacing, and the feel. Write the replacements in
`design/KIT.md`.

Check: `design/KIT.md` lists each replaced item and what replaced it.

Done when `design/KIT.md` has a measured number in points for every token
and part, the kit's gallery shows every part on every target, the
reference screen passes step 6 on the reference's platform, and step 7
lists what was replaced.
