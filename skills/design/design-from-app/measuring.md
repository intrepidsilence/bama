# Measuring a screenshot

Recipes for step 3 and the traps found while rebuilding a task app's
inbox from one screenshot. That rebuild reached 1.3% different pixels,
with every row within 1.5 pt.

## Contents

- Scale
- Recipes
- Text sizes
- Traps
- A measured example

## Scale

Every command takes `--scale`, the pixels per point of the capture (the
table in SKILL.md, step 1). A wrong scale makes every number wrong by the
same factor. To confirm it, measure a system part whose size is known on
that platform, such as the iPhone tab bar or a Mac sidebar row, and
compare.

- **iPhone**: most are 3x, some older models 2x. The status bar and home
  indicator are part of the capture; measure content from below the
  status bar.
- **iPad**: 2x. In Split View or Stage Manager the app is a window
  smaller than the screen; capture the window.
- **Apple TV**: the screen is 1920 x 1080 pt. An HD capture is 1x, a 4K
  capture 2x. Focused items are larger than at rest: measure a resting
  item for its size and a focused one for the growth.
- **Apple Watch**: 2x, and sizes differ per case size. Note the model.
- **Vision Pro**: measure window captures only; ornaments and depth do
  not measure as flat pixels.

## Recipes

**Pane widths.** Run `hline` through an empty part of the window. Each
run of one color is a pane:

```text
swift measure.swift hline shot.png 700 0 300 --tolerance 3 --scale 2
0..218.5  (219 pt)  #F9FBFC     <- sidebar
219..300  (81.5 pt)  #FDFFFF    <- content
```

**Row pitch.** `rows` over a narrow column of icons and labels lists
every row's content band. The distance between band centers is the row
pitch. Start below the title bar, or the window edge counts as content.

**Left edges.** `cols` across one row lists where the checkbox, the text,
and the details start. Do it for two rows to confirm a shared edge.

**Selection and hairlines.** Run `vline` and `hline` through the selected
row with `--tolerance 4` to find the pill's edges. Dividers show up in a
`vline` as 0.5 pt runs of a light gray.

**Colors.** `ink` ignores the background and reports the strongest color
of the text or icon in a box. Sample each kind of text: primary,
secondary, accent, and each status color.

## Text sizes

A band from `rows` over a word is its cap or ascender height, not its font
size, and the letters change it. It is not the font size.
Instead:

1. Build the screen with a first guess (13 pt body).
2. Measure the same word in both images: band height and width.
3. Scale the size by the ratio of the widths. Repeat once.

If every ratio comes out the same (0.77, say), the reference ran zoomed.
That is common for web apps. Either keep the zoomed sizes to match the
screenshot, or keep the reference's own sizes (14, 26, 12) and multiply
every token by one factor, so the kit can run at native size later.

## Traps

The first four are macOS window traps.

- **Hidden title bar.** A fixed `.frame` on a window with a hidden title
  bar adds the bar's height: 742 became 774. Use `.defaultSize`.
- **Window restoration.** A restored frame overrides `.defaultSize` during
  snapshots. Use `.restorationBehavior(.disabled)` on the reference window.
- **Focus ring.** The first button in the window gets the system focus ring
  in a snapshot. Add `.focusEffectDisabled()` at the root and draw the
  kit's own ring.
- **Green button gray.** A window that cannot resize grays out the zoom
  button. Keep the window resizable.
- **Two kinds of detail line.** A date line and a description line looked
  the same but had different space below. When one row is off and the
  others match, look for a different part, not a different number.
- **Simulator size.** On iOS, iPadOS, tvOS, watchOS, and visionOS, the
  screen size comes from the simulator device. Snapshot on the same device
  type the reference came from, or the sizes never match.
- **tvOS focus in the snapshot.** The first focusable item is focused at
  launch and drawn larger. Compare at rest by forcing the rest state, or
  compare the focused item with a focused reference.
- **Selected icons.** The reference used filled icons on the selected row.
- **Compressed screenshots.** JPEG and WebP shift colors by a few steps.
  Round to the nearest clean value, and sample large flat areas.
- **Antialiasing.** Edges of text and icons blend with the background.
  Read sizes from `rows` and `cols` with `--tolerance 30` or more, and
  colors from `ink`, not from single pixels.

## A measured example

A light task app on the Mac (2x), 1000 x 742 pt window, as it appears in
the kit:

| Token | Value |
| --- | --- |
| sidebar width | 219 |
| sidebar row pitch | 26.5, pill 200 x 26.5 inset 9.5, radius 5 |
| content column | 625 wide, centered |
| title | 20.5 bold, frame top 51 |
| task row | top 9, checkbox 14.5, text at +21, divider 0.5 |
| bottom space | 10.5 plain, 7 with a date, 11 with a description |
| type | system font, body 10.75, meta 9.25 (web sizes x 0.77) |
| colors | sidebar #F9FBFC, text #202020, secondary #666666, accent #287ABC, selection #DFEDFA, date #247236 |
