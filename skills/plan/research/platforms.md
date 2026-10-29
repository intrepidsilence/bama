# Platform track checklist

The Platform subagent answers these for each target platform in the brief.
Every answer gets a `[V]`, `[K]`, or `[U]` tag and, for `[V]`, an Apple
developer docs or WWDC URL.

## Every platform

- Which framework does each feature need, and is it on this platform at
  the minimum OS (26)? Many APIs exist on iOS and macOS but not on tvOS or
  watchOS.
- Permissions: which usage-description keys (`NS...UsageDescription`) and
  entitlements, and what the user sees when asked.
- Background limits: what runs when the app is not on screen (background
  tasks, push, timers).
- Data: where it is stored, how it syncs between the user's devices
  (CloudKit, App Groups for widgets and extensions), and size limits.
- Extensions: widgets, Share, Shortcuts (App Intents), notifications.

## Per platform

| Platform | Also check |
| --- | --- |
| `macos` | Sandbox and what it blocks (event taps, other apps' files, AppleScript), global shortcuts, menu bar extras, Accessibility and Screen Recording permissions, login items. |
| `ios` | Widgets and Live Activities, Share extension, Background App Refresh limits, Focus filters, Control Center controls. |
| `ipados` | Multiple windows (scenes), Stage Manager sizes, pointer and keyboard shortcuts, Apple Pencil APIs. |
| `tvos` | No WebKit view, small local storage (cache only, use iCloud for data), no background modes beyond audio, Top Shelf extension, focus engine, Siri Remote input, text entry limits. |
| `watchos` | Independent app or companion, WatchConnectivity, complications and Smart Stack widgets (WidgetKit), runtime limits in the background, workout and extended runtime sessions, small storage. |
| `visionos` | Windows, volumes, immersive spaces (RealityKit), what needs an immersive space (ARKit hand and world tracking), Shared Space limits, ornaments, iPad apps running unmodified. |

## Across platforms

- Which code can be shared in the `<App>Kit` package, and which needs an
  `#if os(...)` or a per-platform target.
- Handoff and continuity between the targets, if the brief asks for it.
