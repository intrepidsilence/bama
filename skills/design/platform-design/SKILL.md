---
name: platform-design
description: Design rules that make a SwiftUI app feel native on iPhone, iPad, Apple TV, Apple Watch, and Apple Vision Pro, with one rule file per platform and a check for each rule. Use when building or reviewing any screen for iOS, iPadOS, tvOS, watchOS, or visionOS, when a shared view must work on more than one platform, or when the user says a screen feels wrong on one device, a highlighted control is cut off, focus lands in the wrong place, or Back does not swipe.
---

# Platform design

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Each Apple device is held, worn, or watched in its own way. A layout that is
right on an iPad is wrong on a TV across the room and wrong on a wrist. Claude
designs each target for its own screen and input, uses the system parts
first, and checks every target on its own simulator.

The Mac has its own skill: call the Skill tool with `bama:mac-design`.

- One rule file per platform, each with its checks:
  [ios.md](ios.md), [ipados.md](ipados.md), [tvos.md](tvos.md),
  [watchos.md](watchos.md), [visionos.md](visionos.md). Claude reads the
  file for every target in the brief before writing views for it.
- Apple's current text on one topic, when a rule here is not enough:
  `"${CLAUDE_SKILL_DIR}/../mac-design/scripts/hig.sh" <topic>` (for example
  `focus-and-selection`, `ornaments`, `digital-crown`). Pages cache in the
  project's `.work/hig/`. Leave off `--mac`: that flag drops the other
  platforms' sections.
- Tokens: call the Skill tool with `bama:design-system`. Names, flow, and
  where a feature opens: `bama:ux-design`. Spacing and the grid checks:
  `bama:layout-grid`.
- Other skills, when the session lists them: `tvos-focus-navigation` for
  focus flows, `swiftui-liquid-glass` for glass API details
  (CONVENTIONS.md, section 10).

## 1. Name the targets

Read the target platforms in the brief (`docs/BRIEF.md`, or recall it in
`muninn` mode). For each target, Claude writes one line under
`## Design plan` in the brief (in `muninn` mode, the plan is one memory,
type `decision`): the device, how people hold or watch it, the input, and
where they look for controls. Start from this table.

| Platform | Distance and session | Input | Where people look for controls |
| --- | --- | --- | --- |
| iOS | a foot or two; a minute to an hour | touch, one or two hands | tab bar at the bottom, toolbar, swipe actions on rows, swipe back from the left edge |
| iPadOS | up to about 3 feet; minutes to hours | touch, pointer, keyboard, Pencil | sidebar or top tab bar, toolbar, menu bar with shortcuts, context menus |
| tvOS | 8 feet or more; often hours | Siri Remote, focus | top tab bar, rows of focusable items, Back to go up, Play/Pause for media |
| watchOS | under a foot; under a minute | Digital Crown, tap, swipe | one screen, vertical pages and lists turned by the Crown |
| visionOS | content about a meter or more away | eyes and pinch, hands | tab bar on the window's leading side, toolbar in an ornament at the bottom |

Each target then gets what the rest of this file and its own rule file
say. Common parts that differ per platform:

- iOS: `TabView` with a bottom tab bar, `NavigationStack` per tab.
- iPadOS: `TabView` with `.tabViewStyle(.sidebarAdaptable)`, or
  `NavigationSplitView`; `.commands` fill the iPad menu bar.
- tvOS: `TabView` at the top, rows of focusable items, full-screen detail.
- watchOS: `NavigationStack` or a vertical `TabView`, short lists.
- visionOS: a `WindowGroup` with glass, tab bar and toolbar as ornaments,
  a volume or immersive space only for 3D moments.

Check: the design plan has one line per target, and each line names the
input and where the main controls sit.

## 2. Keep each platform's values on its platform

Shared views are fine. Shared numbers are the bug. A size picked for a TV
in shared code makes the phone screen huge, and a phone size makes the TV
unreadable.

- Every size, spacing, and behavior that differs per platform goes through
  `Platform.value(mac:phone:pad:tv:watch:vision:)` (in the multi-platform
  template's `Shared/UI/Platform.swift`; all six labels are required) or
  an `#if os(...)` block (CONVENTIONS.md, section 2). Never a bare number that was right on
  the one simulator in front of Claude.
- Put a control where that platform's users look for it (the table in
  step 1). A Mac command gets a menu item and a shortcut; the same command
  on iPhone is a toolbar button or a swipe action; on tvOS it is a
  focusable button in the page.
- After changing shared code, Claude checks every target, not only the one
  being worked on.

Check: `grep -nE "os\(|Platform.value" <changed files>` shows a branch for
every value that differs, and every target was built and snapshotted after
the change.

## 3. Rules every platform shares

- **System parts first.** `TabView`, `NavigationStack`,
  `NavigationSplitView`, `List`, `Form`, `.toolbar`, `.searchable`,
  `.sheet`, system buttons. They bring the platform's focus, hover, glass,
  sizes, and accessibility for free. Custom parts only where the system
  has nothing, with a code comment saying why.
- **Liquid Glass** is for the navigation and control layer (tab bars,
  toolbars, sidebars, ornaments, floating buttons). Content gets none.
  Never glass on glass. Standard bars get glass on their own: delete custom
  backgrounds behind them.
- **Text styles, not point sizes.** `.font(.body)`, `.headline`, and so on
  scale with Dynamic Type and pick each platform's size. When a custom size
  is unavoidable, stay at or above the platform's minimum:

  | Platform | Default body | Minimum |
  | --- | --- | --- |
  | iOS, iPadOS | 17 pt | 11 pt |
  | tvOS | 29 pt | 23 pt |
  | visionOS | 17 pt | 12 pt |
  | watchOS | 16 pt | 12 pt |
  | macOS (for comparison) | 13 pt | 10 pt |

- **Control sizes.** Hit areas meet the platform's size:

  | Platform | Default control | Minimum control |
  | --- | --- | --- |
  | iOS, iPadOS | 44 x 44 pt | 28 x 28 pt |
  | tvOS | 66 x 66 pt | 56 x 56 pt |
  | visionOS | 60 x 60 pt | 28 x 28 pt |
  | watchOS | 44 x 44 pt | 28 x 28 pt |

  Space between controls counts as much as size: about 12 pt around a
  control with a bezel, about 24 pt around one without.
- **Color.** Semantic colors (`.primary`, `.secondary`, system
  backgrounds). One accent. Status color always comes with an icon or a
  word. Check light and dark on every target.
- **The accent is set.** A badge, pill, or capsule that is mysteriously
  white (most often on tvOS in dark mode, or on a Liquid Glass tint) is
  usually an empty `AccentColor.colorset`: `Color.accentColor` then falls
  back to white. Fill the color set with light and dark values, and use the
  theme's own accent token (`bama:design-system`) for tints and badges that must
  stand out.
- **The focused or highlighted state is designed.** tvOS draws a light
  highlight behind a focused item; white text on it disappears. Give the
  focused state its own foreground (dark on the light highlight), or use a
  system button style that does.
- **A highlighted control is never cut off.** On tvOS a focused item grows
  and casts a shadow; on visionOS the hover highlight spreads past the
  item; on iPadOS the focus ring sits outside it. Any parent that clips at
  its edges cuts the highlight flat. The fix and the check are in
  [tvos.md](tvos.md#focused-items-grow) and
  [visionos.md](visionos.md#hover-highlights).
- **Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text, and
  Dynamic Type** all work. Icon-only buttons have labels.

Check: every rule here holds on the light and dark snapshots of each
target, or has a code comment saying why not.

## 4. Per-platform checks

Run the checks in each target's rule file. The ones that catch the most:

| Platform | Check | How |
| --- | --- | --- |
| iOS | Back swipes, and the page slides with the finger | [ios.md](ios.md#back-and-the-edge-swipe): tap Back with tools on every page; the user confirms the swipe on a device |
| iOS | Nothing under the Dynamic Island or home indicator | snapshot at the largest and smallest iPhone, light and dark |
| iPadOS | Works at every width | [ipados.md](ipados.md#every-width): snapshot full screen and a narrow window |
| iPadOS | Every command is in the menu bar with a shortcut | open the menu bar on the simulator (pointer to the top edge) |
| tvOS | A focused control is never cut off | [tvos.md](tvos.md#focused-items-grow): focus the first and last item of every row and column, zoom on all four edges |
| tvOS | Focus enters each region at the last item, else the first | [tvos.md](tvos.md#where-focus-enters): press into each region from every side |
| tvOS | Content stays inside the TV safe area | [tvos.md](tvos.md#safe-area-and-grid) |
| watchOS | The main task takes one screen and a tap or two | [watchos.md](watchos.md) |
| watchOS | The Crown scrolls every list and page | turn the Crown in the simulator (scroll over the screen) |
| visionOS | Targets are 60 pt with centers 60 pt apart, and hover is never cut off | [visionos.md](visionos.md#hover-highlights) |

Check: each row that applies to a target has a result in the report: what
was checked, on which screen, and how.

## 5. Review set

Snapshot every page of every target in light and dark:

```bash
tools/snap.sh --platform ios       # .work/shots/ios/<page>-light.png, -dark.png
tools/snap.sh --platform tvos      # one run per target in the brief
```

Open the PNGs with the Read tool. Look for clipped highlights, text under
system bars, values that leaked from another platform (a TV-sized card on a
phone), white badges, and empty bands under short content.

The script uses the project's own simulator for that platform
(`.work/simulators`) and shuts it down after, unless `--open`. Focus and
hover checks need the app running on that simulator, so they use `--open`
or XcodeBuildMCP pointed at the same UDID:

```bash
udid=$(awk '$1=="tvos"{print $2}' .work/simulators)
```

Check: every target has a light and a dark PNG for every page in
`.work/shots/<platform>/`, and each was opened and looked at.

## References

Apple Human Interface Guidelines (fetched 2026-10-29 with `hig.sh`):

- Designing for iOS, iPadOS, tvOS, watchOS, visionOS: device distance,
  input, and session length in the step 1 table.
- Accessibility: default and minimum text sizes per platform; default and
  minimum control sizes; 12 pt and 24 pt spacing around controls.
- Buttons: hit region of at least 44 x 44 pt, 60 x 60 pt in visionOS.
- Layout: tvOS safe area and grids, visionOS spacing, watchOS buttons per
  row.
- Focus and selection: tvOS focus states, iPadOS focus groups, visionOS
  hover versus focus.
- Tab bars: iOS bottom, iPadOS top with sidebar option, tvOS top, visionOS
  leading side.
- The menu bar: the iPadOS menu bar.
- Toolbars: the visionOS toolbar along the window's bottom edge.

Other sources:

- AI-Brain wiki, `swiftui.md`, "Gotchas & Patterns": the empty
  `AccentColor.colorset` that renders white, and white-on-white focused
  fields on tvOS.
- Rules learned on shipped apps (focus growth, focus entry, the iOS edge
  swipe, per-platform values): kept here as checkable rules in the
  platform files.

Done when every target in the brief has its design plan line, the checks
in step 4 that apply have passed and are in the report, and the light and
dark snapshots of every page of every target show no rule broken.
