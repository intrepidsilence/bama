---
name: swift-swiftui
description: Swift 6 and SwiftUI code rules for apps on every Apple platform, including concurrency, state, SwiftData, shared code across platforms, AppKit bridges, and fixes for common compiler errors. Use when writing, reviewing, or debugging Swift code in an Apple app, when sharing code between platforms, or on concurrency, Sendable, or "not in scope" errors.
---

# Swift and SwiftUI

The code is right when it compiles with zero warnings in Swift 6 language
mode on every target platform, and the app does what the story says. Voice,
platforms, and the work folder follow [CONVENTIONS.md](../../../CONVENTIONS.md).

Before writing code, Claude reads the brief's target platforms. Check: Claude
can name each target and whether the app uses the Mac-only Swift package
template or the multi-platform template (`<App>Kit` package plus one app
target per platform).

For how it should look, call the Skill tool with `bama:mac-design` (macOS)
or `bama:platform-design` (the other platforms). For copyable Mac view code,
read [../../design/mac-design/patterns.md](../../design/mac-design/patterns.md).

When the session lists `swiftui-pro`, `swift-concurrency-pro`, or
`swiftdata-pro`, Claude calls them for a deep review of SwiftUI, concurrency,
or SwiftData code. The rules below are BAMA's own and stay short.

## Concurrency

The templates set main-actor default isolation: every type and function runs
on the main actor unless the code says otherwise. UI code needs no
annotations.

| Work | Put it in |
| --- | --- |
| UI state, views, view models | Default (main actor) |
| CPU-heavy pure work (parsing, image work, diffing) | A `nonisolated` function marked `@concurrent` |
| Shared mutable state used off the main thread | An `actor` |
| A C callback (event tap, Carbon hotkey, CoreAudio listener) | A `nonisolated` static func that hops back with `Task { @MainActor in ... }` |

- Data that crosses actors is `Sendable`: structs and enums of `Sendable`
  values, or `final class` with only `let` properties.
- `MainActor.assumeIsolated { }` inside a callback that is known to run on
  the main thread (a main run loop `Timer`, a main queue notification).
- `Task { }` inherits the actor. `Task.detached` only when it must not.
- Fix a concurrency error at its type, not with `@unchecked Sendable` or
  `nonisolated(unsafe)`. Those two are a last resort, with a comment why.
- **Runtime trap the compiler misses.** A closure created inside a
  `@MainActor` type and passed to an API without a `@Sendable` closure
  parameter (`DispatchSource.setEventHandler`, `DispatchWorkItem`,
  `addPeriodicTimeObserver`, CoreAudio listener blocks) inherits the main
  actor. When it runs on a background queue, Swift 6 crashes the app. Write
  it as `{ @Sendable in ... }`, and run every background path once after
  any concurrency change.

## State

- `@Observable` classes for models. `@State` in the view that owns one,
  `@Bindable` to bind to its properties, `.environment(model)` to share it.
- `@ObservationIgnored` on caches, timers, and handles, so they never
  trigger a redraw.
- `@State` for view-local values. `@AppStorage` for small preferences.
  Keychain for secrets.
- `ForEach(items)` over values, never `ForEach($items)` for data the user
  can delete: a row can read an index that no longer exists and crash. Get
  a binding by looking the item up by id.

## SwiftData

- `@Model` classes, `.modelContainer` on the scene, `@Query` in views,
  `@Environment(\.modelContext)` to insert and delete.
- Every new property has a default value, so existing stores still open.
- macOS: store at `~/Library/Application Support/<AppName>/`. Other
  platforms: see the storage table in
  [multiplatform.md](multiplatform.md). Every platform allows an override
  (`APP_STORE`), so tests never touch the real data.
- Give every model its own `uid: UUID`. `persistentModelID` changes on the
  first save, so it breaks selection and lookups.
- Undo: register the reverse of each action on the window's undo manager.
  SwiftData's automatic undo is not reliable. Code in
  [../../design/mac-design/patterns.md](../../design/mac-design/patterns.md) (Undo with SwiftData).
- A widget, Top Shelf, or other extension that reads the data opens the
  same store from an App Group container. See [multiplatform.md](multiplatform.md).
- Need SQL, a CLI, or several processes on one file? Use SQLite with WAL
  through a small library target instead.

## Shared code across platforms

For an app with more than one target. The full rules and code are in
[multiplatform.md](multiplatform.md); these five apply to every change:

- Rules and data logic live in the `<App>Kit` package, with no SwiftUI.
  App targets hold views and platform glue only.
- A size, spacing, or behavior that differs per platform goes through
  `Platform.value(mac:phone:pad:tv:watch:vision:)`. Code that only exists
  on some platforms (an API, a framework) goes in `#if os(...)`.
- A value written for one platform never leaks into another: no bare
  number tuned on the Mac inside a shared view.
- New APIs get `if #available` or `@available` for the oldest deployment
  target of each platform that compiles the file.
- After a change in shared code, Claude builds every target. Check: each
  target's build has zero warnings.

## Menu commands (macOS)

SwiftUI `Commands` do not observe `@Observable` models, so a title or a
`.disabled(...)` that reads the model goes stale. In testing, neither
`@FocusedValue` (from `.focusedSceneValue`) nor an `@ObservedObject` inside
the commands updated reliably: the menu stayed disabled with a row
selected. What works: mirror the selection into a small `ObservableObject`,
observe it in the `App`, and pass the values into the commands. The App's
body then rebuilds the menus when they change.

```swift
@MainActor final class MenuState: ObservableObject {
    static let shared = MenuState()
    @Published private(set) var selection: Set<UUID> = []
    func update(_ s: Set<UUID>) { if selection != s { selection = s } }
}
// AppModel: var selection: Set<UUID> = [] { didSet { MenuState.shared.update(selection) } }

struct MyApp: App {
    @ObservedObject private var menu = MenuState.shared
    var body: some Scene {
        Window("App", id: "main") { ContentView() }
            .commands { AppCommands(model: model, selectedIDs: menu.selection) }
    }
}
```

Disable items with `.disabled(selectedIDs.isEmpty)` and resolve the target
again when the item fires. Never ship items that stay enabled and do
nothing. Check the menu from outside the app (`bama:test-app`, "Menu
check").

A menu shortcut also fires while a text field has focus. Never use Delete,
Command-Delete, arrows, or Return as menu shortcuts. Handle them on the
list with `.onDeleteCommand` and `.onKeyPress`.

iPadOS shows the same `.commands` in its menu bar and in the Command key
overlay, so an iPad target reuses them.

## Names Swift already uses

Never name a type `Task`, `View`, `Color`, `Image`, `Text`, `Section`,
`Label`, `Menu`, `Group`, or `Settings`. `Task` breaks every `Task { }`.
Use `Todo`, `TaskItem`, `NoteSection`.

## AppKit bridges (macOS)

SwiftUI covers windows, lists, and forms. AppKit is still the answer for:

- Floating panels that do not steal focus: `NSPanel` with
  `.nonactivatingPanel` hosting a SwiftUI view (`NSHostingView`, with
  `sizingOptions = []` for a fixed frame).
- Text views with custom behavior: `NSViewRepresentable` around `NSTextView`.
- Status items with custom click handling: `NSStatusItem`.
- Key and mouse monitors: `NSEvent.addLocalMonitorForEvents`. Remove the
  monitor when the view goes away.

On iOS, iPadOS, and tvOS the same jobs use `UIViewRepresentable` around a
UIKit view. Keep each bridge in its app target or behind `#if os(...)`.

For system hooks (hotkeys, Accessibility, screen capture on the Mac;
widgets, intents, Top Shelf, complications elsewhere), call the Skill tool
with `bama:os-integrations`.

## Compiler errors

| Error | Fix |
| --- | --- |
| `cannot find 'X' in scope` right after adding a file (macOS package template) | `swift package clean --scratch-path ~/Library/Developer/<AppName>/build` |
| `cannot find 'X' in scope` right after adding a file (multi-platform template) | `xcodegen generate`, then build again |
| `cannot find 'X' in scope` on one platform only | The symbol is missing on that OS. Wrap it in `#if os(...)` or move it to that app target |
| `'X' is only available in <OS> N or newer` | `if #available` at the call, or raise that platform's deployment target in the brief |
| `Main actor-isolated ... from a nonisolated context` | Make the caller main-actor, or `await` the call |
| `Sending 'x' risks causing data races` | Make the type `Sendable`, or keep it on one actor |
| `The compiler is unable to type-check this expression` | Split the view into smaller subviews or `let` constants |
| `ambiguous use of 'Task'` | A type in the app's code is named `Task`; rename it |

Fix the first error first. Later errors often come from it.

## Swift 6 errors

Moving an existing Swift 5 app? Read
[../../ship/build-and-verify/existing-app.md](../../ship/build-and-verify/existing-app.md)
first: expect several build rounds, then hunt the runtime trap above.

| Error | Fix |
| --- | --- |
| Static `let` of a non-Sendable type (formatter, `NSFont`, `CFString`) | `@MainActor` on the enclosing type, a computed `var`, or a commented `nonisolated(unsafe)` |
| `sending 'note' risks causing data races` in a main-queue observer | Copy the Sendable parts (an id, a pid) out of the notification before `MainActor.assumeIsolated` |
| Observer token captured before it is assigned | Keep the token in a small `@MainActor` class |
| "pattern that the region-based isolation checker does not understand" in a task group | Use an array of `Task { @MainActor in ... }` and await each one |
| Vars changed from `OperationQueue` blocks under `NSLock` | `OSAllocatedUnfairLock(initialState:)` |
| `@objc` action on an `NSMenuItem` subclass | `@MainActor @objc func` |

Done when the app builds with zero warnings in Swift 6 language mode for
every target platform, and the story's acceptance checks pass on each one.
