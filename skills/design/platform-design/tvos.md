# tvOS

Apple TV is watched from 8 feet or more, often for hours, and driven by the
Siri Remote. Nothing is touched or pointed at. People move a highlight
(focus) from item to item and press to choose. Every rule here serves that:
big, legible, focusable, and predictable.

## Contents

- Layout for the room
- Safe area and grid
- Focused items grow
- Where focus enters
- The remote
- Text and color on the highlight
- Checks

## Layout for the room

- Edge-to-edge artwork, few words, large type. Body text is 29 pt by
  default and never under 23 pt; use text styles, not point sizes.
- Navigation is a `TabView` at the top. It scrolls away with a page that
  has one main view. Detail pages are full screen.
- Every element on screen is reachable by focus. tvOS has no pointer;
  never add one outside a game.
- In a full-screen view (a playing video, a photo), swipes act on the
  content, not on focus.
- Controls are 66 x 66 pt by default, never under 56 x 56 pt.

Check: the snapshot reads from across the room (look at it scaled to a
quarter of its size), and every control is a `Button`, `NavigationLink`,
or another focusable view.

## Safe area and grid

- Keep primary content 60 pt from the top and bottom of the screen and
  80 pt from the sides. TVs crop the edges (overscan); content outside
  this area can vanish. Background art may go edge to edge.
- Grids use Apple's widths, with 40 pt between columns and at least
  100 pt between rows, so a focused item never overlaps its neighbor:

  | Columns | Unfocused item width |
  | --- | --- |
  | 2 | 860 pt |
  | 3 | 560 pt |
  | 4 | 410 pt |
  | 5 | 320 pt |
  | 6 | 260 pt |
  | 7 | 217 pt |
  | 8 | 184 pt |
  | 9 | 160 pt |

- A titled row gets extra space above its title and between the title and
  the items.
- Content cut off at the screen edge is cut the same width on both sides.

Check: on the snapshot, no text or control starts inside 80 pt of the left
or right edge or 60 pt of the top or bottom. The screen is 1920 x 1080 pt;
a 3840-pixel-wide screenshot is 2x, so double the numbers there. Grid
widths match the table for the column count.

## Focused items grow

A focused control grows and casts a shadow. If any container around it
clips at its own edges, the grown control's rounded ends or its top and
bottom are cut flat. This is the most common tvOS bug in generated code.
It happens in a horizontal `ScrollView` row of cards, a `List` or `Form`
given a `.frame(maxWidth:)`, a parent with `.clipped()` or `.clipShape`,
and a row with a tight fixed height.

Every time Claude adds a focusable control, or changes a container around
one:

1. Give the growth room. A scroll container that holds focusable items
   gets `.scrollClipDisabled()`, or padding inside the scroll content on
   every side the item can grow toward (`Space.focusRoom` in the
   multi-platform template's `Shared/UI/Grid.swift`). A `List` or `Form` ignores
   `.contentMargins` for this, so use `.scrollClipDisabled()` there.
2. Keep clipping off focusables. No `.clipped()`, `.clipShape`, or tight
   fixed frame on a focusable control, its row, or its scroll view. Clip
   the artwork inside the button's label instead.

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 40) {
        ForEach(shows) { show in
            Button { open(show) } label: {
                Poster(show)            // the image clips itself, inside the label
            }
            .buttonStyle(.card)
        }
    }
    .padding(.vertical, 40)             // room for the grown item and its shadow (Space.focusRoom)
}
.scrollClipDisabled()                   // the row never cuts the focused card
```

How to check, before calling the screen done:

1. Run the app on the project's tvOS simulator (`tools/snap.sh --platform
   tvos --open`, or XcodeBuildMCP on the same UDID).
2. Focus the FIRST and the LAST control of every row and every column.
   Edges are where it clips. Move with the remote keys below.
3. Take a full-resolution screenshot of each:
   `xcrun simctl io "$udid" screenshot .work/shots/tvos/focus-<row>-<first|last>.png`.
4. Zoom on the focused control's four edges, cropping around it:
   `sips -c <height> <width> --cropOffset <y> <x> <in>.png --out <in>-edge.png`,
   then open the crop with the Read tool.
5. The ends are fully rounded and the shadow is visible on all four sides.
   A flat or cut edge means not done.

Check: the report names each row and column checked, first and last, on
which screen, and that all four edges were whole.

## Where focus enters

Left alone, tvOS moves focus into a row, grid, or button bar at the item
nearest the one focus came from. Down from the tab bar then lands in the
middle of a row. The rule for every region: focus enters at the item last
focused there, else at the first item.

Implement it with three parts on each region:

- `.focusSection()`, so the region is one target for directional moves.
- `.defaultFocus($focus, target, priority: .userInitiated)`. The default
  priority (`.automatic`) ignores the preference for a remote press;
  `.userInitiated` makes it apply.
- The last focused id, remembered per region, and forgotten when that item
  leaves the region.

```swift
extension View {
    /// Focus entering this region goes to the item last focused in it, or to `ids.first`.
    func focusEntry<ID: Hashable>(_ focus: FocusState<ID?>.Binding, ids: [ID]) -> some View {
        modifier(FocusEntry(focus: focus, ids: ids))
    }
}

private struct FocusEntry<ID: Hashable>: ViewModifier {
    var focus: FocusState<ID?>.Binding
    var ids: [ID]
    @State private var last: ID?

    func body(content: Content) -> some View {
        content
            #if os(tvOS)
            .focusSection()
            #endif
            .defaultFocus(focus, last.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first,
                          priority: .userInitiated)
            .onChange(of: focus.wrappedValue) { _, new in
                // Several rows can share one focus state: remember only this row's items.
                if let new, ids.contains(new) { last = new }
            }
    }
}

// Each item:   .focused($focus, equals: item.id)
// The region:  .focusEntry($focus, ids: items.map(\.id))
```

- Rows that share one `@FocusState` need ids that do not collide across
  rows (prefix them with the row).
- A focusable item with no visible highlight (a plain `.focusable()`
  text) confuses people. Make it a `Button`.
- Moves inside a region stay geometric; this rule only decides the entry.

How to check: on the simulator, press INTO each region from every side it
can be entered from (from the tab bar, from the row above, from the row
below, from a side button bar), and screenshot where the highlight lands.
First visit: the first item. After moving to the third item, leaving, and
coming back: the third item.

Check: the report lists each region, each side pressed in from, and where
focus landed.

## The remote

- Swipe moves focus; press chooses. Do not act on a light tap; people rest
  a thumb on the remote.
- Back opens the parent of the current screen, and at the top level goes
  to the Home Screen. It is not "the previous screen" when the hierarchy
  says otherwise.
- Play/Pause plays, pauses, and resumes media. Respond to it during
  playback.
- Never change focus without a press, except to move it to a neighbor when
  the focused item disappears.

Keys for the simulator, as HID codes (XcodeBuildMCP `key_press`, or
`axe key <code> --udid "$udid"`): right 79, left 80, down 81, up 82,
select (Return) 40, Back (Escape) 41.

Check: Back from every page lands on its parent; Play/Pause works on every
playback screen.

## Text and color on the highlight

- The focused state draws a light highlight. White text on it disappears.
  Give every custom focused state a dark foreground, or use a system button
  style (`.bordered`, `.card`) and confirm its focused label on a
  screenshot.
- A `TextField` in a system `.alert` shows a light field with the app's
  white text on it. Put text entry on its own page with a contrasting field
  background instead.
- A badge or capsule that renders white is usually the empty
  `AccentColor.colorset` (SKILL.md, step 3). Fill it, and use the theme's
  accent token for tints.

Check: focus every custom control and text field once in dark mode and
read its label on the screenshot.

## Checks

1. Snapshots: `tools/snap.sh --platform tvos`, every page, light and dark.
2. Safe area: no text or control in the outer 80 pt sides or 60 pt top and
   bottom.
3. Focus growth: first and last item of every row and column, four edges,
   whole and shadowed.
4. Focus entry: every region, from every side, lands on last-or-first.
5. Back and Play/Pause behave as above.
6. Focused labels are legible in dark mode.

Sources: HIG Designing for tvOS, Layout (tvOS), Focus and selection
(tvOS), Remotes, Accessibility (sizes), Tab bars (tvOS); AI-Brain wiki
`swiftui.md` "Gotchas & Patterns". HID key codes measured on the tvOS
simulator in a shipped app.
