# visionOS

Apple Vision Pro places windows in the room around the person. People look
at a control to target it and pinch to choose, with their hands resting in
their lap. Comfort comes first: content a meter or more away, in front of
them, never asking them to turn or reach.

## Contents

- Windows, volumes, and immersive spaces
- Glass and ornaments
- Hover highlights
- Comfort
- Checks

## Windows, volumes, and immersive spaces

- Most of the app is windows: flat planes of standard controls on glass.
  An app starts in the Shared Space, beside other apps.
- A volume (`.windowStyle(.volumetric)`) holds a 3D object people look at
  from any side.
- An immersive space (`ImmersiveSpace`) is for the app's few big moments.
  Pick the least immersion that suits each moment.
- A window opens at 1280 x 720 pt by default, about two meters away. Pick
  a starting size with little empty space, and set a minimum and maximum
  size so the layout never breaks; do not use them to block resizing.
- Keep content centered as the window grows.
- 3D content inside a window is rare and inset from the edges. Large 3D
  goes in a volume or an immersive space.
- Supplemental content opens in a new window beside the current one, not
  in an ornament.

Check: resize each window to its minimum and maximum in the simulator;
nothing overlaps and nothing floats in empty space.

## Glass and ornaments

- Windows have a glass background on their own. Do not paint a solid
  background over it.
- Toolbars and tab bars become ornaments on their own: the tab bar floats
  vertically on the window's leading side and expands when looked at. Each
  tab has an SF Symbol and a short label.
- A custom ornament (`.ornament(attachmentAnchor:)`) holds frequently used
  controls for its window, like playback controls. It is no wider than its
  window, usually stays visible, and uses borderless buttons on its glass.
- Few ornaments per window; their weight adds up.

Check: no window has a custom opaque background, and every ornament is no
wider than its window.

## Hover highlights

Looking at a control highlights it (the hover effect). The highlight
spreads past the control's edges, so a parent that clips cuts it off, just
as a focused card is cut off on tvOS.

- Controls are 60 x 60 pt by default, never under 28 x 28 pt. Place them
  so their centers are at least 60 pt apart, or with at least 16 pt of
  space around each. A control of 60 pt or more gets 4 pt of padding so
  its highlight does not overlap its neighbors.
- Interactive shapes are rounded; eyes slide off corners.
- An image and its label that act as one control get one shape that
  highlights as a whole: `.contentShape(.hoverEffect, RoundedRectangle(...))`
  with `.hoverEffect()`.
- No `.clipped()`, `.clipShape`, or tight frame on a control or the row that
  holds it; a scroll view of controls gets `.scrollClipDisabled()` or
  padding inside it.
- Standard controls first; custom hover effects only for a special moment.

How to check: in the visionOS simulator the pointer stands in for the eyes.
Hover the first and last control of every row and toolbar, take a
screenshot (`xcrun simctl io "$udid" screenshot .work/shots/visionos/hover-<row>-<first|last>.png`),
and crop around the control with `sips` as in [tvos.md](tvos.md#focused-items-grow).
The highlight is whole on all four sides.

Check: the report names each row checked and that the highlight was whole.

## Comfort

- Place content in front of the person, at least a meter away for
  anything read over time.
- Interaction works with hands at rest (look and pinch). Direct touch, if
  used, is close and brief.
- No fast motion, no motion without a still frame of reference, and no
  repeating pattern that fills the view.
- Text styles only: body 17 pt by default, never under 12 pt.
- The Digital Crown belongs to the system (volume, immersion, recenter);
  apps get no Crown input.

Check: nothing in the app moves on its own while the person reads, and
every action works with a look and a pinch.

## Checks

1. Snapshots: `tools/snap.sh --platform visionos`, every window (visionOS
   has one appearance; glass adapts to the room).
2. Windows resize between their minimum and maximum without breaking.
3. Hover: first and last control of every row and toolbar, highlight whole.
4. Targets 60 pt, centers 60 pt apart.
5. No custom background on glass; ornaments no wider than their window.

Sources: HIG Designing for visionOS, Windows (visionOS), Layout (visionOS),
Ornaments, Eyes, Buttons (visionOS), Tab bars (visionOS), Digital Crown,
Focus and selection, Accessibility (sizes); AI-Brain wiki `visionos.md`.
