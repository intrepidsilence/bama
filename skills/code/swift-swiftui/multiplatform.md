# Shared code across platforms

For an app with more than one target platform, built from the
multi-platform template (`bama:new-app`): an XcodeGen `project.yml`, a
shared `<App>Kit` package, and one app target per platform.

## Contents

- Where code goes
- Per-platform values
- Code that exists on some platforms only
- Availability
- Where the data lives
- Sharing a store with widgets and extensions
- Syncing between devices
- Check for leaks

## Where code goes

| Code | Place |
| --- | --- |
| Rules, parsing, networking, formatting | `<App>Kit` package, no SwiftUI |
| SwiftData `@Model` types and the store setup | `Shared/` (`Shared/Models.swift`, `Shared/Store.swift`), because the test-store guard reads the app's launch environment. Move them into `<App>Kit` when an extension (widget, Top Shelf, complication) needs the same store, and keep the guard in the app |
| Views used by more than one platform | `Shared/`, with platform helpers in `Shared/UI/` (`Platform.swift`, `Grid.swift`, `Theme.swift`) |
| Views, scenes, and glue for one platform | That platform's app target |
| Widget, Top Shelf, complication, intents extension | Its own extension target, linking `<App>Kit` |

- Tests for `<App>Kit` run on the Mac with `swift test`. They need no
  simulator, so the logic gets most of the tests.
- An extension never imports an app target. What both need goes in
  `<App>Kit`.

Check: `<App>Kit` has no `import SwiftUI`, `import UIKit`, or `import AppKit`.

## Per-platform values

Every size, spacing, and behavior that differs per platform goes through
the template's helper. One call names every platform, so a new target can
never inherit another platform's number by accident:

```swift
let rowHeight = Platform.value(mac: 28, phone: 44, pad: 44, tv: 66, watch: 36, vision: 44)
let columns   = Platform.value(mac: 4, phone: 2, pad: 3, tv: 5, watch: 1, vision: 3)
```

- Values follow each platform's design rules (`bama:mac-design`,
  `bama:platform-design`), not a scaled copy of the Mac value.
- iPhone and iPad are the same OS. The helper tells them apart by idiom,
  so `phone:` and `pad:` can differ. An iPad window can be narrow
  (Split View, Stage Manager): use size classes for layout, and the
  helper for the idiom's base sizes.
- A shared design token (`DesignKit/Tokens.swift`) that differs per
  platform calls the helper inside the token, so views read one name.

## Code that exists on some platforms only

`#if os(...)` when the API or framework is missing on a platform:

```swift
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif
```

- `#if canImport(ActivityKit)` for a framework that only some platforms
  ship. Pair it with `os(...)` when a framework imports but its API is
  marked unavailable on a platform.
- Keep `#if` blocks small and at the edges. A view full of `#if` branches
  is two views: split it, and pick one in the app target.
- `#if targetEnvironment(simulator)` only for development aids, never for
  behavior the user sees.

## Availability

- Each platform has its own deployment target in `project.yml`. A shared
  file must compile for the oldest of them.
- `if #available(iOS 26, macOS 26, tvOS 26, watchOS 26, visionOS 26, *)`
  names every platform that has the API, and gives a fallback in `else`.
- `@available(...)` on a type or function used by only some platforms.
  Check: every target builds with zero availability warnings.

## Where the data lives

| Platform | SwiftData store | Notes |
| --- | --- | --- |
| macOS | `~/Library/Application Support/<App>/` | Listed in `tools/footprint.sh` as the user's real data |
| iOS, iPadOS | `URL.applicationSupportDirectory` in the app's container | The default `ModelConfiguration` location |
| watchOS | `URL.applicationSupportDirectory` in the watch app's container | Separate from the phone. Data reaches it through Watch Connectivity or CloudKit (`bama:os-integrations`, watchOS) |
| visionOS | `URL.applicationSupportDirectory` in the app's container | Same as iOS |
| tvOS | Treat local files as a cache | See below |
| Any, with an extension | The App Group container | See "Sharing a store" |

tvOS has no guaranteed persistent local storage. Apple's guidance is to
keep user data in iCloud (CloudKit, or `NSUbiquitousKeyValueStore` for
small values), with `UserDefaults` capped around 500 KB, and local files in
`URL.cachesDirectory`, which the system can purge. In one shipped app, file
writes into the App Group container failed with EPERM on a real Apple TV
while the tvOS simulator allowed them; only `UserDefaults(suiteName:)`
worked there. So on tvOS: a SwiftData store lives in Caches and can be
rebuilt, or syncs through CloudKit, and every storage path is tested on a
device. (Needs a check against current Apple docs before a tvOS app ships.)

The test override works the same everywhere:

```swift
// In <App>Kit
public enum StoreLocation {
    public static func url(appGroup: String? = nil) -> URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(filePath: path)
        }
        if let appGroup,
           let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return group.appending(path: "<App>.store")
        }
        #if os(tvOS)
        return URL.cachesDirectory.appending(path: "<App>.store")
        #elseif os(macOS)
        return URL.applicationSupportDirectory.appending(path: "<App>/<App>.store")
        #else
        return URL.applicationSupportDirectory.appending(path: "<App>.store")
        #endif
    }
}
// let config = ModelConfiguration(url: StoreLocation.url(appGroup: "group.<bundle-id>"))
```

Create the parent folder before opening the store. Scripts set `APP_STORE`
to a path in `.work/` on the Mac. In a simulator, Claude passes it with
`SIMCTL_CHILD_APP_STORE=<path>` before `xcrun simctl launch`, and points it
inside the app's own container (`xcrun simctl get_app_container <udid>
<bundle-id> data`).

## Sharing a store with widgets and extensions

A widget, Live Activity, control, Top Shelf extension, complication, or
share extension runs in its own process and cannot read the app's
container. Both read one store in an App Group:

1. Add the App Groups capability with one id, `group.<bundle-id>`, to the
   app target and every extension target in `project.yml`
   (`com.apple.security.application-groups`).
2. Open the store with that group in the app and in each extension:
   `ModelConfiguration(schema: schema, groupContainer: .identifier("group.<bundle-id>"))`.
   Both sides use the same schema.
3. After the app changes data an extension shows, it tells the extension:
   `WidgetCenter.shared.reloadAllTimelines()` for widgets and
   complications, `TVTopShelfContentProvider.topShelfContentDidChange()`
   for Top Shelf. Put this call in the one place that announces a data
   change, so every mutation reaches every extension.
4. Extensions read. Writes from an extension (an interactive widget's App
   Intent) go through the same model code as the app.

- Data Protection: a store the widget reads while the device is locked
  needs `completeUntilFirstUserAuthentication` (the App Group default), not
  `complete`.
- Secrets stay in the Keychain, shared through a Keychain access group,
  never in the store.
- macOS App Group ids have their own prefix rules for apps outside the
  Mac App Store. (Needs a check against Apple's App Groups docs for the
  app's distribution.)

Check: change data in the app, and the widget or extension shows the new
state without reinstalling.

## Syncing between devices

SwiftData syncs through CloudKit when the iCloud capability names a
container (`ModelConfiguration(cloudKitDatabase: .private("iCloud.<bundle-id>"))`).
CloudKit needs every property to be optional or have a default, no
`@Attribute(.unique)`, and optional relationships. Decide this before M1:
adding sync later means a schema change on every platform.

## Check for leaks

After a change in shared code:

```bash
# Bare numbers in shared views: each is a candidate for Platform.value
grep -rnE '\.(frame|padding|font\(\.system\(size)[^)]*[0-9]{2}' <shared UI folder> | grep -v Platform.value
```

Then build every target and look at each one on its own simulator or the
Mac (`bama:test-app`). One platform's screenshot says nothing about the
others.

Done when `<App>Kit` holds the logic with no UI imports, every
per-platform value goes through `Platform.value` or `#if os(...)`, every
target builds with zero warnings, and each target's store is in the place
the table names.
