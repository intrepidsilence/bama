---
name: layout-grid
description: Grid and alignment rules for a SwiftUI app on any Apple platform, with per-platform notes (tvOS focus room and safe area, watchOS margins, visionOS spacing) and three checks that catch misalignment (a lint for off-grid numbers, a layout probe that measures real frames in snapshot mode, and a grid overlay). Use when building or reviewing a custom page, card, row, form, or sheet, after every build that touched layout, or when the user says something looks misaligned, crooked, cramped, cut off, or unevenly spaced.
---

# Layout grid

Agents guess numbers. A guessed `.padding(13)` looks almost right and
makes the whole app feel slightly off. This skill replaces guessing with
one scale and three checks that fail when something is off.

What each template from `bama:new-app` ships:

| | Mac-only template | Multi-platform template |
| --- | --- | --- |
| The scale | `Sources/<App>/UI/Grid.swift`: `Space`, `.gridArea`, `.gridProbe`, the grid overlay | `Shared/UI/Grid.swift`: `Space` with a per-device `Space.margin` and `Space.focusRoom`, and `CardSize`; no probes, no overlay |
| Per-platform values | none (one platform) | `Shared/UI/Platform.swift`: `Platform.value(mac:phone:pad:tv:watch:vision:)`, all six labels required, and `Platform.current` |
| Check 1, lint | `tools/grid-lint.sh` (lints `Sources/`) | `tools/grid-lint.sh` (lints `Shared/`) |
| Check 2, probes | `tools/check-layout.swift` on `.work/shots/macos/*-layout.json` | not shipped |
| Check 3, overlay | `APP_GRID=1` on the app launched by hand | not shipped |

Both lints skip `Theme.swift`, `Grid.swift`, and `Tokens.swift`, where the
scale itself is defined. For a Mac app made before this skill, Claude
copies `UI/Grid.swift`, `tools/grid-lint.sh`, and `tools/check-layout.swift`
from the Mac-only template, and the layout file line from its
`Snapshot.swift`. On the multi-platform template, probes and the overlay
are a change to the project, not something to assume is there; until
then, checks 1 and the snapshot review below are the checks.

## The rules

1. Every padding, spacing, and size comes from `Space`: `xs 4`, `sm 8`,
   `md 12`, `lg 16`, `xl 20`, `xxl 24`, `section 32`. Raw numbers are
   0, 1, 2, or a multiple of 4.
2. Pages and windows have a margin (`Space.margin`, set per platform; see
   the table below). Cards pad 16 (`Space.lg`). Related controls sit 8
   apart, groups 20 to 24, sections 32.
3. Each column has one leading edge. Titles, text, cards, and buttons in a
   column start on the same x. Indent on purpose, by a step of the scale.
4. Let containers do the aligning:
   - Labels with controls: `Form` with `.formStyle(.grouped)`, or
     `.columns` for the Mac layout of right-aligned labels.
   - Rows and columns of values: `Grid` and `GridRow`.
   - A label with a value: `LabeledContent`.
   - Text of different sizes in one row: `HStack(alignment: .firstTextBaseline)`.
   - Numbers in a column: `.monospacedDigit()`, trailing aligned.
   - An icon with text: `Label`.
5. Mac sheets are 360, 480, or 640 wide. Controls take their height from
   `.controlSize` (Mac) or the system style, never from a fixed height.
6. Nested corners are concentric: inner radius = outer radius - padding.
7. `.offset` and `.position` move a view after layout, so nothing lines up
   with it. Use them only for motion and drag previews, with
   `// grid: ok <why>` on the line.
8. Long text truncates with its full value available. Nothing clips.
9. A value that differs per platform goes through
   `Platform.value(mac:phone:pad:tv:watch:vision:)` or `#if os(...)`, and
   each branch is still on the scale (CONVENTIONS.md, section 2).

## Per platform

The 4 pt grid holds everywhere. What changes is the margin, the room
around controls, and what "cut off" means.

| Platform | Margin | Room around controls | Watch for |
| --- | --- | --- | --- |
| macOS | 20 pt window margin | 8 pt between related controls | the top 50 pt free for dragging the window |
| iOS | system margins: 16 pt compact width, 20 pt regular | 44 pt hit areas | content under the Dynamic Island or home indicator |
| iPadOS | 16 or 20 pt by size class | 44 pt hit areas; pointer hover room | layouts that only work full screen |
| tvOS | safe area: 80 pt sides, 60 pt top and bottom | 40 pt between grid columns, at least 100 pt between rows | a focused item grows; any clipping parent cuts it |
| watchOS | the system's, from `List` and `ScrollView` | at most 3 glyph buttons or 2 text buttons in a row | rounded screen corners cutting content |
| visionOS | the window's own padding | control centers 60 pt apart, or 16 pt around each | the hover highlight spreads past a control; any clipping parent cuts it |

- **tvOS focus room.** A scroll view that holds focusable items gets
  `.scrollClipDisabled()`, or padding inside its content on every side an
  item can grow toward. No `.clipped()`, `.clipShape`, or tight fixed
  frame around a focusable item or its row. The grid widths and the
  first-and-last focus check: `bama:platform-design`, "tvos.md".
- **visionOS hover room.** The same: no clipping parent around a control.
  Controls of 60 pt or more get 4 pt of padding so their highlights do not
  overlap.
- **watchOS.** Use `List` and `ScrollView` so the system sets the side
  margins and the insets for the curved edges on each case size. Custom
  padding inside rows stays on the scale.

On the multi-platform template, page margins use `Space.margin` and the
room around focusable rows uses `Space.focusRoom`; both already carry the
right value per device.

Check: run `tools/snap.sh --platform <id>` for each target and open the
PNGs in `.work/shots/<platform>/` with the Read tool. The margin matches
the table, and no focused or hovered control on tvOS or visionOS is cut
off (the first-and-last checks in `bama:platform-design`).

## Check 1: lint the code

Run it after every build that touched views:

```bash
tools/grid-lint.sh
# Sources/Tasks/TaskRow.swift:14: off grid (10): .padding(.horizontal, 10)
# FAIL grid-lint: 1 lines off the grid
```

Fix each line with a `Space` token, or `Platform.value(...)` with a token
per platform where the value must differ.

## Check 2: probe the real layout (Mac-only template)

Mark what is laid out by hand: the page, its sections, cards, rows in a
card, sheet content. System lists, forms, sidebars, and toolbars align
themselves and need no probes.

```swift
VStack(alignment: .leading, spacing: Space.xxl) {
    Text("Today").gridProbe("title", area: "page")
    StatsRow().gridProbe("stats", area: "page")
    TaskCard()
        .gridArea("card", inset: Space.lg)
        .gridProbe("card", area: "page")
}
.padding(Space.margin)
.gridArea("page")
```

`.gridArea` marks a container and its inset. `.gridProbe` marks a view in
it. Probes with the same `edge` (default `"lead"`) must share one leading
edge. Pass `edge: nil` for views that sit side by side.

Snapshot mode writes a `<page>-<light|dark>-layout.json` next to every
PNG in `.work/shots/macos/`. Take the snapshots, then check them:

```bash
tools/snap.sh
swift tools/check-layout.swift .work/shots/macos/*-layout.json
# PASS today-light-layout.json: 12 probes in 2 areas
# FAIL inbox-light-layout.json
#   - edge page/lead has 2 leading edges: title 320, list 324
```

It checks that every probe:

1. Starts on a whole or half point, so its edges stay sharp.
2. Starts a multiple of 4 pt from its area's edge.
3. Stays inside its area's inset on both sides.
4. Shares one leading edge with the others on its edge.
5. Sits a multiple of 4 pt below the probe above it.
6. Never overlaps another probe in its area.

## Check 3: look at the grid (Mac-only template)

When a check fails and the cause is not clear, draw the grid over the
pages. `tools/snap.sh` does not pass `APP_GRID` on, so launch the binary
by hand with a test store and a snapshot folder in `.work/`:

```bash
APP_GRID=1 APP_STORE=.work/test.store APP_SNAPSHOT=.work/shots/grid \
  ~/Applications/<App>.app/Contents/MacOS/<App>
```

The PNGs in `.work/shots/grid/` show an 8 pt grid, each area in blue with
its inset dashed, and each probe in pink with its name. Claude opens them
with the Read tool.

## Fix a failure

| Message | Usual cause | Fix |
| --- | --- | --- |
| starts 23 pt into page | a raw padding on one child | remove it, use the stack's `Space` padding |
| 2 leading edges | a centered stack, or one child with extra padding | `alignment: .leading` on the stack |
| gap 10 pt | `spacing: 10`, or a `Spacer(minLength:)` | a `Space` token |
| inside its 20 pt inset | a missing margin, or a fixed width wider than the parent | `.padding(Space.margin)`, `maxWidth` instead of `width` |
| overlap | `.offset`, `.position`, or a fixed height | remove it, let the stack size the view |
| x between pixels | a fractional number | a whole number from `Space` |
| right on one platform, wrong on another | a bare number in shared code | `Platform.value(...)` with a `Space` token per platform |
| focused card cut flat (tvOS) | a clipping parent or a tight row height | `.scrollClipDisabled()`, padding inside the scroll content |

Sources for the per-platform numbers: HIG Layout (tvOS safe area and
grids, visionOS spacing, watchOS buttons per row), HIG Eyes and Buttons
(visionOS), HIG Accessibility (control sizes), AI-Brain wiki
`hig-layout.md` (iOS and iPadOS margins).

Done when `tools/grid-lint.sh` passes; on the Mac-only template,
`tools/check-layout.swift` passes on the layout files of every page
touched and every custom page and card has a `.gridArea` with probes on
its main parts; and the per-platform table holds on each target's
snapshots.
