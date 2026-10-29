# Architecture for apps that grow

The Mac-only template starts with one app target and a small Kit library.
The multi-platform template starts with a shared `<App>Kit` package and one
app target per platform. Move to this shape when the app gets a CLI, an
engine (media, sync, parsing), a second platform, or a second contributor.

## Contents

- Targets and dependency direction
- Multi-platform shape
- Edits as pure operations
- Split state by update rate
- Seams with two adapters
- Engines report counters, not exceptions
- Safe saves
- Errors
- File size norms
- Gotchas

## Targets and dependency direction

```text
App (SwiftUI, menus, windows) -> feature and engine targets -> Core
```

Never the reverse. Core knows nothing about SwiftUI, AVFoundation, or Metal.

```swift
// Package.swift
.target(name: "AppCore"),                                  // values, documents, rules, math
.target(name: "AppStore", dependencies: ["AppCore"]),      // persistence, sync
.target(name: "AppEngine", dependencies: ["AppCore"]),     // media, rendering, heavy work
.executableTarget(name: "App", dependencies: ["AppCore", "AppStore", "AppEngine"]),
.executableTarget(name: "appctl", dependencies: ["AppCore", "AppStore"]),   // CLI
.testTarget(name: "AppCoreTests", dependencies: ["AppCore"]),
```

A CLI on the same core keeps the core free of UI by force. The app target
stays thin: views and one `@MainActor` model per page.

## Multi-platform shape

```text
<App>-macOS, <App>-iOS, <App>-tvOS, ... (app targets: scenes, menus, platform views)
        -> <App>KitUI (shared SwiftUI views, the platform helper, design tokens)
        -> <App>Kit (values, rules, persistence, engines; no UI framework)
```

```yaml
# project.yml (XcodeGen)
packages:
  TasksKit: { path: TasksKit }
targets:
  Tasks-macOS: { type: application, platform: macOS, sources: [Apps/macOS, Shared], dependencies: [{ package: TasksKit }] }
  Tasks-iOS:   { type: application, platform: iOS,   sources: [Apps/iOS, Shared],   dependencies: [{ package: TasksKit }] }
```

- **The Kit is where tests live.** Everything that is not a view goes
  there, so one `swift test` covers every platform. The Kit imports
  Foundation and SwiftData, not SwiftUI, UIKit, or AppKit.
- **Shared views** live in one place (a `Shared/` folder or a `KitUI`
  target). A view that differs per platform in a few values reads them from
  the platform helper:

  ```swift
  let cardWidth = Platform.value(mac: 220, phone: 160, pad: 200, tv: 360, watch: 140, vision: 260)
  ```

- **A platform difference in behavior is a seam.** Name it with a small
  protocol or a view per platform, chosen in one place:

  ```swift
  // Shared/ItemActions.swift: one interface
  protocol ItemActionsPresenter { func present(_ item: Item) }
  // Apps/macOS/ContextMenuPresenter.swift and Apps/tvOS/FocusMenuPresenter.swift: one adapter each
  ```

  One `#if os` that picks the adapter beats ten scattered through a view.
- **Platform folders hold only what truly differs**: the scene and window
  setup, menu bar commands on macOS, focus sections on tvOS, complications
  on watchOS, ornaments on visionOS. When two platform folders hold the
  same view with small differences, merge it into a shared view with
  platform values.
- **Dependency direction holds per platform**: an app target may depend on
  the Kit, never one app target on another. Code two targets need moves
  down into the Kit or the shared views.

## Edits as pure operations

Every change to the user's document is an operation applied to a value.
One entry point serves the UI, Undo, the CLI, and tests.

```swift
public enum EditOp: Codable, Sendable { case rename(id: ID, to: String), move(id: ID, to: Int) }

public extension Document {
    func apply(_ ops: [EditOp]) throws -> Document   // all or nothing, returns a new value
}

@discardableResult func perform(_ ops: [EditOp], named name: String) -> Bool {
    do {
        let next = try doc.apply(ops)
        guard next != doc else { return false }
        pushUndo(name); doc = next; scheduleSave(); return true
    } catch { errorMessage = error.localizedDescription; return false }
}
```

## Split state by update rate

A value that changes many times a second (a playhead, a meter, a timer)
lives in its own small observable object. Only the views that show it
observe it. Putting it on the page model re-renders every view on the page.

```swift
@MainActor @Observable final class PlayheadClock { var frame = 0 }

struct PlayheadLabel: View {
    let clock: PlayheadClock
    var body: some View { Text("\(clock.frame)").monospacedDigit() }
}
```

Engines own their real-time state. The UI reads snapshots at the rate a
person can see: 15 Hz for meters, 1 Hz for device lists.

## Seams with two adapters

Add a protocol only where behavior gets swapped: network, clock, file system,
an external service. Give it a production adapter and a test adapter on
day one.

```swift
public protocol Transport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
struct URLSessionTransport: Transport { ... }
struct RecordedTransport: Transport { ... }    // tests: replays saved responses
```

## Engines report counters, not exceptions

Real-time paths never throw. They count what went wrong and expose a
snapshot.

```swift
public struct WriterStats: Sendable { var appended = 0, stalls = 0, dropped = 0, fallbacks = 0 }
public func snapshot() -> WriterStats { lock.withLock { stats } }
```

The self-test prints the counters. A non-zero `dropped` fails it.

## Safe saves

Write to a temp file, then rename (atomic). Keep a revision number; when the
file changed since it was read, reload and replay unsaved operations. Never
overwrite an output another feature points at: write a new version.

## Errors

A typed `enum` per module that conforms to `LocalizedError`. The UI shows
`errorMessage`. Media and real-time paths degrade (drop a preview frame,
fall back to the CPU) and count it.

## File size norms

Library files mostly 100 to 450 lines. A file over 600 lines is a check-in
signal. View models over 1,000 lines are the first refactor targets. Test
hooks live in a test target or behind a launch flag, not in app files. A
shared view with more than 3 `#if os(...)` blocks is a check-in signal.

## Gotchas

- Synthesized `Codable` can change the bytes of old files when a type gains a
  property (it writes `"items": []`). Keep a test that loads and re-saves
  an old file byte for byte.
- `model.child?.field = f(model.child)` on an `@Observable` type can crash
  with an exclusivity violation. Read into a `let` first.
- A menu action named like an AppKit setter (`setAppearance:`) crashes.
  Name actions `applyAppearance(_:)`.
- A huge function can crash the release optimizer. Split it.
- A file added to a platform folder is not in the Xcode project until
  `xcodegen generate` runs. "Cannot find type in scope" right after adding
  a file usually means that.
- A shared view that compiles on the Mac can fail on watchOS or tvOS,
  where some modifiers and controls do not exist. Build every target after
  a change in shared code.
- Two agents building one package at once break each other. New types
  land in new files that compile on their own; never add an empty target.
- Async job queues: give each job a generation number and claim it before
  starting, so a retry never runs a paid job twice.
