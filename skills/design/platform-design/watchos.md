# watchOS

Apple Watch is read in a glance, less than a foot from the eye, often while
the person is moving. A visit lasts seconds, usually under a minute. People
turn the Digital Crown to move and tap to act. Complications and
notifications are used more than the app itself.

## Contents

- Glanceable
- Navigation and the Digital Crown
- Layout
- Always On and the watch face
- Checks

## Glanceable

- The app's main task fits one screen and one or two taps. Anything longer
  belongs on the iPhone.
- Show the one value people raised their wrist for at the top, large.
- Use on-device data to show what matters now, without asking.
- Work on its own when the iPhone is away. Fetch only what the screen
  shows.

Check: for each story, count the taps from launch to done. More than two is
a design to cut.

## Navigation and the Digital Crown

- Navigation is shallow: a `NavigationStack` with one or two levels, or a
  vertical `TabView` (`.tabViewStyle(.verticalPage)`) that the Crown pages
  through.
- The Crown scrolls every list and page. System `List`, `ScrollView`, and
  vertical pages get this for free. A custom value (a timer, a level) uses
  `.digitalCrownRotation` and shows the change on screen as the Crown
  turns, at the speed it turns.
- Every Crown interaction also works by touch.
- Apps never respond to a Crown press; the system owns it.
- Sheets are rare and brief, never a way to move through the app. A choice
  of actions is an alert or a confirmation dialog.

Check: on the simulator, scroll every list and page with the Crown
(Simulator: scroll over the screen with the pointer or trackpad), and reach
the same places by touch.

## Layout

- Content fills the screen; chrome is minimal. Use `List` and `ScrollView`
  so the system sets the side margins and the curved-edge insets for each
  case size.
- At most three glyph buttons, or two text buttons, side by side. Text
  buttons usually span the full width.
- Body text 16 pt by default, never under 12 pt. Text styles only, in SF
  Compact (the system font on watchOS).
- Controls 44 x 44 pt by default, never under 28 x 28 pt.
- Color in the background can carry meaning (a state, a category);
  materials show hierarchy.

Check: snapshots on the project's watchOS simulator (one appearance:
watchOS apps are dark); nothing is clipped by the rounded corners.

## Always On and the watch face

- When the wrist drops, the screen dims (`@Environment(\.isLuminanceReduced)`).
  Hide seconds and fast-changing values, and anything private.
- A complication or widget shows the app's key value on the watch face and
  opens the app at that value. Design it with the app, not after.
- Notifications carry the timely information and its main action, so
  people do not need to open the app.

Check: the snapshot with `isLuminanceReduced` set shows no private data and
no ticking value.

## Checks

1. Snapshots: `tools/snap.sh --platform watchos`, every page.
2. Taps per story: two or fewer.
3. The Crown scrolls every list and page; touch reaches the same places.
4. Always On hides private and fast-changing values.

Sources: HIG Designing for watchOS, Digital Crown, Layout (watchOS),
Sheets (watchOS), Accessibility (sizes); AI-Brain wiki
`hig-color-and-typography.md` (SF Compact). Exact side margins per case
size are not stated in the HIG text checked; the rule leaves them to the
system containers.
