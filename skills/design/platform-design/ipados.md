# iPadOS

iPad is held, set on a stand, or docked to a keyboard, within about 3 feet.
People mix touch, a pointer, a keyboard, and Apple Pencil, often in one
session, and run the app in a resizable window next to others. The iPad
version is not a stretched iPhone and not a squeezed Mac.

Everything in [ios.md](ios.md) applies (safe area, 44 pt targets, text
styles, sheets, Back and the edge swipe) unless this file says otherwise.

## Contents

- Every width
- Navigation
- Pointer and keyboard
- The menu bar
- Surfaces
- Checks

## Every width

- The app runs at any width: full screen, a narrow window beside another
  app, a resizable window in Stage Manager. Layout follows
  `horizontalSizeClass` and the space it gets, never the device model.
- Compact width behaves like iPhone: tab bar, stacked layout, sheets.
  Regular width uses the room: a sidebar, columns, popovers.
- Margins come from the system: 20 pt in regular width, 16 pt in compact
  (AI-Brain wiki `hig-layout.md`).
- Long text keeps a readable line length; do not let a paragraph run the
  full width of a 13-inch screen.
- Grids adapt their column count (`GridItem(.adaptive(minimum:))`), not
  their item size.

Check: snapshots in full screen and in a narrow window (the size class
flips to compact), light and dark. Nothing overlaps, nothing is clipped,
and the compact layout is the iPhone layout.

## Navigation

- `TabView` with `.tabViewStyle(.sidebarAdaptable)` shows the tab bar near
  the top, with a button that turns it into a sidebar. Use
  `NavigationSplitView` instead when the app is a sidebar that should never
  become tabs.
- A `NavigationSplitView` collapses to a stack in compact width. Check the
  collapsed form; it must still reach every page.
- The page's actions go in `.toolbar`. Selection details go in
  `.inspector`, which becomes a sheet in compact width.

Check: in a narrow window, every page is still reachable and Back works.

## Pointer and keyboard

- Custom controls take `.hoverEffect()` so the pointer shows what it is
  over. System controls do this on their own.
- The pointer, focus ring, and hover effect need room: no `.clipped()` or
  tight frame around a control whose effect spreads past its edges.
- Every frequent action has `.keyboardShortcut`, using the Mac's standard
  shortcuts (Command-N, Command-F, Command-Z).
- Focus moves with Tab between focus groups (sidebar, list, grid) and with
  the arrow keys inside one group. System lists, sidebars, and collections
  are groups on their own; a custom stack of focusable views needs a Tab
  check (`.focusSection()` is not available on iPadOS).
- Text fields and lists support selection and drag and drop.

Check: with a hardware keyboard on the simulator (I/O > Keyboard > Connect
Hardware Keyboard), Tab reaches every area, the arrows move inside each,
and every listed shortcut works.

## The menu bar

iPadOS 26 has a menu bar, revealed by moving the pointer to the top edge or
swiping down from it. SwiftUI `.commands` fill it.

- Use the same menu order and names as the Mac (call the Skill tool with
  `bama:mac-design`, "menus.md").
- Every command in the menu bar also has a way in the UI: the menu bar is
  often hidden, and some items need a hardware keyboard.
- With tabs, add each tab to the View menu with a shortcut.
- App > Settings opens the app's page in the iPad Settings app. An in-app
  settings screen gets its own item just below it.
- Group items into submenus more often than on the Mac; iPad menu rows are
  taller.

Check: on the simulator, reveal the menu bar and confirm each command is
there with its shortcut, and also reachable without the menu bar.

## Surfaces

- In regular width, a popover for a few choices tied to one control, a
  form sheet or page sheet for a short task, `.inspector` for details
  beside the content.
- Fewer modal and full-screen transitions than on iPhone: the screen has
  room to show things in place.
- A sheet that would cover the whole screen on iPad is usually a new page
  or a new window (`openWindow`) instead.

Check: no sheet on a 13-inch iPad is a mostly empty card.

## Checks

1. Snapshots: `tools/snap.sh --platform ipados`, every page, light and
   dark, full screen and a narrow window.
2. Compact width matches the iPhone layout and reaches every page.
3. Keyboard: Tab, arrows, and every shortcut; the menu bar lists every
   command.
4. Hover effects on custom controls are whole, not clipped.
5. Back tapped on every page; the edge swipe confirmed by the user on a
   device (see [ios.md](ios.md#back-and-the-edge-swipe)).

Sources: HIG Designing for iPadOS, Layout, Tab bars (iPadOS), The menu bar
(iPadOS), Focus and selection (iPadOS), Sheets (iOS, iPadOS); AI-Brain wiki
`hig-layout.md`.
