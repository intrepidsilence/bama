# iOS

iPhone is held in one or two hands, a foot or two away, in sessions from a
minute to an hour. Thumbs reach the middle and bottom of the screen most
easily. People expect to swipe: back from the left edge, actions on list
rows, a sheet down to close it.

## Contents

- Layout
- Navigation
- Back and the edge swipe
- Sheets and other surfaces
- Checks

## Layout

- Content stays inside the safe area: clear of the Dynamic Island, the
  status bar, and the home indicator. Backgrounds may run edge to edge
  (`.ignoresSafeArea()` on the background only).
- Standard margins come from the system (`.padding()` with no value, or
  `List` and `Form`): 16 pt in compact width, 20 pt in regular width
  (AI-Brain wiki `hig-layout.md`).
- Controls have 44 x 44 pt hit areas, never under 28 x 28 pt. A small icon
  gets a larger `.contentShape`.
- Body text 17 pt by default, never under 11 pt. Text styles only, so
  Dynamic Type works up to the accessibility sizes.
- Few controls on screen. Secondary actions go in a menu, a context menu,
  or swipe actions on the row.
- Support portrait and landscape unless the app has a strong reason not to.

Check: snapshots on the project's iOS simulator, light and dark (and on
the smallest iPhone the app supports, when the project keeps a simulator
for it), plus one at the largest accessibility text size
(`xcrun simctl ui "$udid" content_size accessibility-extra-extra-extra-large`).
Nothing is clipped or under a system bar.

## Navigation

- `TabView` for top-level sections: a tab bar floating at the bottom, on
  Liquid Glass. Single-word labels with SF Symbols. Never hide the tab bar
  while navigating inside a tab; only a modal covers it.
- Each tab holds its own `NavigationStack`, so its place survives switching
  tabs.
- `.toolbar` items for the page's actions. `.searchable` for search, or a
  search tab at the trailing end of the tab bar.
- Rows take `.swipeActions` for their frequent actions, and the same
  actions in `.contextMenu`.

Check: every tab keeps its place when the user leaves it and comes back.

## Back and the edge swipe

Wherever there is a Back button, the swipe from the left edge also goes
back, and the page slides with the finger. A page that only switches when
the swipe ends feels broken.

1. Prefer a real `NavigationStack` push for every new page.
   `NavigationLink(value:)` with `.navigationDestination(for:)` gives Back,
   the edge swipe, and the slide together.
2. A screen with its own page model (a browser with its own history, pages
   swapped in by state) mirrors that model into a `NavigationStack(path:)`.
   The model stays the source of truth; when the user pops by swiping, the
   stack's new path is handed back to the model as its Back.

```swift
@Observable final class Browser {
    var trail: [Folder.ID] = []          // the app's own page model
    func goBack(to count: Int) { trail.removeLast(trail.count - count) }
}

struct BrowserView: View {
    @Bindable var browser: Browser

    var body: some View {
        NavigationStack(path: Binding(
            get: { browser.trail },
            set: { newPath in                 // a swipe or Back popped pages
                if newPath.count < browser.trail.count { browser.goBack(to: newPath.count) }
                else { browser.trail = newPath }
            })) {
            FolderList(id: nil)
                .navigationDestination(for: Folder.ID.self) { FolderList(id: $0) }
        }
    }
}
```

3. Never hide the system Back swipe. `.navigationBarBackButtonHidden(true)`
   with a custom Back button turns the swipe off. Use it only on a page the
   user asked to lock (a running workout, an unsaved form that confirms).
4. A SwiftUI `DragGesture` on an edge strip misses quick flicks (iOS holds
   back edge touches). It is never the fix. If a gesture is truly needed,
   use `UIScreenEdgePanGestureRecognizer` through
   `UIGestureRecognizerRepresentable`.

How to check: simulator input tools (axe, XcodeBuildMCP swipe) cannot
trigger any edge pan, not even `NavigationStack`'s own, so a swipe that
fails in them proves nothing. Claude taps Back on every page with the
tools and confirms each lands on its parent. Then Claude asks the user to
swipe back on every page on a device, and to say whether the page slides
with the finger.

Check: the report lists each page, "Back tapped: lands on <parent>", and
the user's answer for the swipe, or says the swipe is still unconfirmed.

## Sheets and other surfaces

- A sheet for a short, self-contained task. Swipe down closes it; when
  that would lose typed work, ask first
  (`.interactiveDismissDisabled(hasChanges)` plus a confirmation).
- Add `.presentationDetents([.medium, .large])` when the first half of
  the sheet is useful on its own (a share or a picker), with
  `.presentationDragIndicator(.visible)`.
- `.fullScreenCover` only for an immersive task: a camera, a player, a
  game.
- A popover on iPhone shows as a sheet. Design its content to work as one.
- `.confirmationDialog` for a choice of actions on something; `.alert`
  only for a problem the user must act on now.

Check: each sheet closes with a swipe down, and a sheet with typed input
asks before it loses it.

## Checks

1. Snapshots: `tools/snap.sh --platform ios`, every page, light and dark.
2. Largest accessibility text size: no clipped or overlapping text.
3. Back tapped on every page; edge swipe confirmed by the user on a device.
4. Tabs keep their place; sheets close with a swipe.

Sources: HIG Designing for iOS, Layout, Accessibility (sizes), Buttons,
Tab bars (iOS), Sheets (iOS); AI-Brain wiki `hig-layout.md`. The edge
swipe rules were learned on shipped apps.
