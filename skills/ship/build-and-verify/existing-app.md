# Existing apps

The ship and code skills assume an app made from the `bama:new-app`
template: `build.sh`, `tools/snap.sh`, `tools/selftest.sh`, `APP_SNAPSHOT`,
`APP_STORE`, Swift 6 with main-actor default isolation, project simulators.
An older app, or one built with an Xcode project for any Apple platform, has
none of these. Claude maps each piece first, then follows the skills.

## Contents

- Map the template pieces
- Simulators and devices
- Snapshots through a debug bridge (macOS)
- Snapshots in a simulator
- Unit tests without a host app
- Self-test in a running app
- Moving to Swift 6

## Map the template pieces

| Template piece | Existing Xcode or XcodeGen app |
| --- | --- |
| `./build.sh` (macOS) | `make build`, or `xcodebuild -scheme <App> -configuration Release -destination 'platform=macOS' -derivedDataPath ~/Library/Developer/<App>/DerivedData build` |
| `./build.sh --open` (macOS) | Quit the running copy, copy the `.app` to the same install path, `lsregister -f -R -trusted <path>`, `open <path>` |
| `./build.sh --platform <id>` | `xcodebuild -scheme <App> -destination 'platform=<Simulator>,id=<udid>' -derivedDataPath ~/Library/Developer/<App>/DerivedData build`, then `xcrun simctl install <udid> <path to .app>` |
| `--platform <id> --open` | `xcrun simctl launch <udid> <bundle-id>`, and `open -a Simulator` |
| `APP_SNAPSHOT` mode | macOS: a `snapshot:` bridge command (below). Simulator: a snapshot launch argument (below). |
| `APP_STORE=.work/...` | A data folder override read from the environment, or a bridge command that only reads |
| `swift test` | A test target with no host app (below) |
| `--selftest` launch flag | A `selftest` bridge command, or a launch argument the app reads |
| Swift 6, default isolation | Swift 5 mode: migrate (below) or keep it and annotate `@MainActor` |

The simulator names for `-destination`: `iOS Simulator`, `tvOS Simulator`,
`watchOS Simulator`, `visionOS Simulator`. An iPad uses `iOS Simulator`
with an iPad UDID. `xcodebuild -showdestinations -scheme <App>` lists what
the scheme accepts.

Keep DerivedData in `~/Library/Developer/<App>/`, not in the repo, so iCloud
or Dropbox do not sync it, and add that folder to `tools/footprint.sh`.

Claude writes the mapping into the app's `CLAUDE.md`, and creates the file
if it is missing.

Done with this section when every row has a working command that Claude ran
once.

## Simulators and devices

**Simulators.** Claude creates the project's own, one per platform, and
records each in `.work/simulators` (CONVENTIONS.md, section 5):

```bash
xcrun simctl list runtimes                          # the installed runtimes
xcrun simctl list devicetypes | grep -i 'iPhone 1'  # a device type name
udid=$(xcrun simctl create "bama-<App>-ios" "iPhone 16" com.apple.CoreSimulator.SimRuntime.iOS-26-0)
echo "ios $udid" >> .work/simulators
```

Pick a runtime and device type from the lists, not from memory. Boot with
`xcrun simctl boot <udid>`, shut down with `xcrun simctl shutdown <udid>`.
Never `shutdown all`, and never touch a simulator not in `.work/simulators`.

With XcodeBuildMCP in the session, `build_run_sim`, `screenshot`,
`snapshot_ui`, and the tap tools work. Claude sets the session defaults to
the project's scheme and the project simulator's UDID first
(`session_set_defaults`, then `session_show_defaults` to confirm).

**Devices.** A physical iPhone, iPad, Apple TV, or Vision Pro:

```bash
xcrun devicectl list devices
xcodebuild -scheme <App> -destination 'platform=iOS,id=<device udid>' -derivedDataPath ~/Library/Developer/<App>/DerivedData build
xcrun devicectl device install app --device <device udid> <path to .app>
xcrun devicectl device process launch --device <device udid> <bundle-id>
xcrun devicectl device process terminate --device <device udid> --pid <pid>
```

A device needs a signing team in the project. Claude terminates what it
launched on a device when the check ends, unless the user should try it.

## Snapshots through a debug bridge (macOS)

A single-instance Mac app (menu bar utility, background agent) cannot be
launched a second time in snapshot mode. Claude adds commands to its debug
bridge (see `bama:os-integrations`, recipes.md):

- `snapshot:<file>:<match>`: capture one of the app's own windows with
  ScreenCaptureKit, from inside the app:

  ```swift
  let content = try await SCShareableContent.current
  guard let scWindow = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) })
  else { return }
  let filter = SCContentFilter(desktopIndependentWindow: scWindow)
  let config = SCStreamConfiguration()
  config.width = Int(window.frame.width * 2); config.height = Int(window.frame.height * 2)
  let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
  ```

  It shows glass, forms, and sidebars exactly as on screen, needs only the
  app's own Screen Recording grant, and never shows other apps.
- Find windows in `NSApp.windows`. `NSApp.orderedWindows` skips panels.
  Match by title, or by root view type:
  `String(describing: type(of: window.contentView!))` reads like
  `NSHostingView<LauncherView>`.
- `appearance:light|dark|system`: set `NSApp.appearance` (not the saved
  preference), so one script snapshots every surface in both modes.
- `cacheDisplay(in:to:)` is a fallback only. It draws forms, sidebars, and
  glass blank.

## Snapshots in a simulator

The simulator captures the whole device screen, which holds only the app,
so no permission is needed:

```bash
xcrun simctl ui <udid> appearance dark
SIMCTL_CHILD_APP_STORE="$PWD/.work/test.store" SIMCTL_CHILD_APP_SEED=1 \
  xcrun simctl launch --terminate-running-process <udid> <bundle-id> -page today
xcrun simctl io <udid> screenshot .work/shots/ios/today-dark.png
```

`SIMCTL_CHILD_<NAME>` sets `<NAME>` in the app's environment. Arguments
after the bundle id reach the app as launch arguments. A page argument (or
a deep link with `xcrun simctl openurl <udid> <app>://today`) takes the app
straight to a page, so a script can walk every page in both appearances.
Claude waits for the page to render (a line the app prints to stderr when
it appears) rather than a fixed sleep.

After a refactor, diff new snapshots against a baseline:

```bash
magick compare -metric AE -fuzz 8% before/settings.png after/settings.png .work/compare/settings-diff.png
```

Zero changed pixels proves the screen did not change. Small diffs on live
data (clocks, stats) are fine.

## Unit tests without a host app

An Xcode or XcodeGen app often has no library target. Claude adds a unit
test target that compiles the pure logic files directly, with no host app:

```yaml
# project.yml
<App>Tests:
  type: bundle.unit-test
  platform: macOS
  sources:
    - path: Tests
    - path: <App>/Features/Colors/ColorFormat.swift
    - path: <App>/Core/FuzzyMatch.swift
```

Give it its own scheme and run:

```bash
xcodebuild test -scheme <App>Tests -destination 'platform=macOS,arch=arm64'
```

Pure logic runs the same on every platform, so the macOS destination tests
it fastest. Logic that uses an iOS-only or tvOS-only API needs that
platform's simulator as the destination. `-quiet` prints nothing on
success; read the exit code.

A hosted test bundle launches a second copy of the app, which fights the
running one for global hotkeys, the menu bar slot, event taps, and bridge
notifications. Avoid it.

Logic buried in `@MainActor` stores cannot be compiled alone. Move it into
its own file and type that takes plain values (text, not a URL; numbers,
not a view). The better end state is a shared `<App>Kit` package, as in the
multi-platform template.

## Self-test in a running app

Make the self-test a bridge command (macOS) or a launch argument
(simulator) that prints PASS or FAIL per check and exits 0 or 1. Checks
worth adding to any app:

- Every action's Shortcuts title equals its menu or button title.
- Every SF Symbol name exists: `NSImage(systemSymbolName:accessibilityDescription:) != nil`
  on macOS, `UIImage(systemName:) != nil` on the others.
- Every URL action name round-trips through the URL handler.
- **Smoke step**: start every background timer, sampler, and observer for a
  few seconds, then print PASS. Only this catches crashes on background
  queues (see Moving to Swift 6).

## Moving to Swift 6

- Expect several build rounds. The compiler stops early, so the first error
  count is low. One app showed 9 errors first and about 22 errors and 28
  warnings in the end.
- The compiler-clean build can still crash at run time. A closure created
  inside a `@MainActor` type and handed to an API that does not take a
  `@Sendable` closure inherits the main actor. When the API runs it on a
  background queue, Swift 6 traps (`dispatch_assert_queue`). Find them:

  ```bash
  grep -rn 'setEventHandler\|setCancelHandler\|DispatchWorkItem\|addPeriodicTimeObserver\|AudioObjectAddPropertyListenerBlock' --include='*.swift' .
  ```

  Mark each such closure `{ @Sendable in ... }` and hop to the main actor
  inside it where needed. Then run the smoke step.
- Common errors and fixes: `bama:swift-swiftui`, "Swift 6 errors".
