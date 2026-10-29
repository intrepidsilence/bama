---
name: design-kit
description: Custom design system for a SwiftUI app on any Apple platform with its own parts, not Apple's, covering three token layers that resolve per platform, type, an icon set, every part in every state, custom window chrome on macOS, a parts gallery per target, and checks. Use when the user wants the app to have its own look and feel, a brand, or custom buttons, rows, and sidebars, when design-from-app has measured a reference app, or when the user asks for a design system or component library.
---

# Design kit

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

A native look comes from Apple's parts. A custom look comes from the app's
own parts: its sidebar row, its button, its checkbox, its icons. SwiftUI
draws all of them. A kit is those parts, the numbers behind them, and one
page that shows every part in every state, on every target.

Most apps keep Apple's parts and only pick an accent color (call the Skill
tool with `bama:design-system`). Build a kit when the parts themselves
must change. To copy the look of an existing app, call the Skill tool with
`bama:design-from-app` first: it measures the app and then comes back
here.

Everything lives in a `DesignKit/` folder next to the app's other UI code
(`Sources/<App>/DesignKit/` in the Mac template, `Shared/UI/DesignKit/`
in the multi-platform template). Code for every step:
[parts.md](parts.md).

## 0. Read the targets

Read the target platforms from the brief (`docs/BRIEF.md`, or
`muninn_recall` with the app's name and "targets" in `muninn` mode). Read
the platform rules for each: call the Skill tool with `bama:mac-design`
for macOS and `bama:platform-design` for the others. A kit part follows
the input of each target: pointer and keyboard on macOS, touch on iOS,
touch and pointer on iPadOS, the Siri Remote and focus on tvOS, the
Digital Crown on watchOS, gaze and pinch on visionOS.

Check: Claude can name every target and its input.

## 1. Write the spec

Write `design/KIT.md` from [kit-spec.md](kit-spec.md): three words for the
feel, the tokens with a value per target, the type scale, the icon rules,
and one section per part with its sizes and states. Agents build from this
page and review against it.

Check: every part the app's screens need has a section with its sizes per
target and its states.

## 2. Tokens in three layers

`DesignKit/Tokens.swift`:

1. **Palette**: raw colors, named by hue and step (`gray50`, `blue600`).
   Only this file reads it.
2. **Meaning**: `Ink.text`, `Ink.accent`, `Ink.selection`, `Ink.divider`,
   with a light and a dark value each. Parts read only this layer.
3. **Scales**: `KitType` (type roles), `Metric` (sizes), `Motion`
   (named intents like `hover` and `check`).

A rebrand changes the palette. A dark mode fix changes the meaning layer.
Neither touches a part.

Every `Metric` that differs per platform resolves through one helper,
`Platform.value(mac:phone:pad:tv:watch:vision:)`. A row is 28 pt on a Mac
and 66 pt on a TV; one number for both is a bug. Hit sizes start from
Apple's default control size per platform (parts.md, Tokens). A Mac-only
app uses plain constants.

Check: `grep -rn 'Palette\.' Sources/ Shared/ | grep -v Tokens.swift` finds
nothing, and every `Metric` that differs per target is one
`Platform.value` call.

## 3. Type

Name styles by role (`title`, `body`, `label`, `section`, `meta`), never
by size. Map each role to a text style (`.body`, `.title`), which already
resolves per platform and follows Dynamic Type. A custom size goes through
`Platform.value` and `relativeTo:`. Use the system font unless the brand
needs its own; a bundled font goes in the app's resources, registered in
`Info.plist` (`ATSApplicationFontsPath` on macOS, `UIAppFonts` on the
other platforms). Half-point sizes are fine when a reference needs them.

Check: views set fonts only through `.kitType(...)`.

## 4. Icons

Icons decide the feel more than color does. Views name a `KitIcon`, never
an SF Symbol or a file, so the whole set can change in one place.

- Start from SF Symbols at a fixed size and weight. Light weights read
  less like Apple.
- For a set of the app's own, draw each icon as a SwiftUI `Shape` from its
  SVG path, or make custom symbols in the SF Symbols app.
- One stroke weight and one corner style for the whole set. The size is
  one `Metric` per platform: a TV icon is read from across the room.
- A selected row may switch to the filled form.

Check: `grep -rn 'systemName:' Sources/ Shared/ | grep -v DesignKit/` finds nothing.

## 5. Parts

One file per family in `DesignKit/Components/`: sidebar, rows, buttons,
fields, menus. Each part:

- Is a real control. Style a `Button` with a `ButtonStyle`, a `Toggle`
  with a `ToggleStyle`, a field with a modifier. Never a shape with a tap
  gesture: it loses the keyboard, focus, the remote, and VoiceOver.
- Has every state its targets have: rest, pressed, selected, disabled,
  plus hover (macOS, iPadOS pointer), focused (keyboard focus on macOS and
  iPadOS, the focus engine on tvOS), and the system hover effect for gaze
  (visionOS), in light and dark. Hover uses `.kitHover`, which does
  nothing where there is no pointer.
- On tvOS, focused means larger with a shadow (`Metric.focusScale`), and
  the part never sits inside a `.clipped()` or `.clipShape` container.
- Is at least the platform's hit size (`Metric.rowHeight`).
- Takes a forced state for the gallery, so hover, pressed, and focused
  show up in a snapshot.
- Reads only meaning tokens, `KitType`, `Metric`, `Motion`, and `KitIcon`.

Check: the part matches its section in `design/KIT.md` in every state on
every target.

## 6. Window chrome (macOS)

This step applies to a macOS target only. iOS, iPadOS, tvOS, watchOS, and
visionOS keep the system's navigation bars, tab bars, and ornaments:
style what sits inside them, not the bars.

For a fully custom Mac look, hide the title bar and draw the app's own top
bar, and build the sidebar from kit rows instead of `List`. Keep the
traffic lights, menus, context menus, sheets, and alerts native: users
depend on them. SwiftUI cannot move the traffic lights; a small
`NSViewRepresentable` reaches the `NSWindow` (parts.md, Window chrome).

A custom sidebar matches the macOS 27 system one where people would
notice: the selected row's text turns semibold, the selection fill dims
when the window is inactive (`@Environment(\.appearsActive)`), and row
corners stay concentric with the sidebar (`bama:mac-design` patterns.md,
"Custom chrome that follows the window"). Custom glass bounces on click
only on controls.

Check: the window opens at its default size, the traffic lights sit where
the spec says, the custom sidebar moves with the arrow keys, and its
selection dims when another window is in front.

## 7. Gallery

`DesignKit/KitGallery.swift` shows every part in every state, in light and
dark, the way a storybook does. The app shows it instead of its pages when
`APP_KIT_GALLERY=1` is set, so the normal snapshot command captures it on
each target:

```bash
./build.sh --platform <id>                         # snap.sh installs the last build
APP_KIT_GALLERY=1 tools/snap.sh --platform <id>   # once per target
# PNGs in .work/shots/<id>/
```

Review a new part here before it goes into a screen.

On tvOS, read the gallery's focused column: zoom on the four edges of the
first and the last part in each row. The rounded ends and the shadow are
whole. Then focus the first and last item of a real row in the app and
check the same.

Check: each target's gallery snapshot shows every part from
`design/KIT.md` in light and dark, no tvOS focused part is cut off, and
the user has seen them.

## 8. Checks

```bash
tools/grid-lint.sh
grep -rnE 'Color\(hex|Color\(red|\.font\(\.system|systemName:|\.clipped\(\)' Sources/ | grep -v DesignKit/
```

Run the grep on `Shared/` too in the multi-platform template. Both come back clean (a `.clipped()` hit is fine only around an
image with no focusable part inside). Then build, snapshot every target,
and run the layout checks on the screens (call the Skill tool with
`bama:build-and-verify`, and with `bama:layout-grid` for the grid).

Done when `design/KIT.md` covers every part with a value per target, every
part is a real control with every state its targets have, the gallery
shows them all in light and dark on every target, tvOS focus is never
clipped, and the checks above come back clean.
