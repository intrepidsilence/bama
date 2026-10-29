---
name: test-app
description: Test an Apple platform app at every level, from Swift Testing unit tests in the shared Kit package and an in-app self-test per platform to a debug bridge or debug server that lets an agent drive the running app and read its state. Use when adding logic, fixing a bug, before a release, or when the user asks for tests, end-to-end checks, or "make sure it works" on Mac, iPhone, iPad, Apple TV, Apple Watch, or Vision Pro.
---

# Test an app

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Claude follows [CONVENTIONS.md](../../../CONVENTIONS.md): platform ids
(section 2), test databases in `.work/` (3), project simulators (5), and
what may stay running (6).

Levels, cheapest first. Each new story gets the cheapest level that can
prove its acceptance criteria, on every platform in its `Platforms:` line.
A bug fix starts with a test that fails.

Story acceptance lines say which level proves them:

- `- [unit] <text>`: shared logic. One Swift Testing test in the Kit, run
  once for every platform.
- `- [snap] <platform>: <text>`: checked on that platform only, by its
  snapshots (`bama:build-and-verify`) or its self-test. With no platform
  prefix, on every platform in `Platforms:`.

| Level | Proves | Platforms | Speed |
| --- | --- | --- | --- |
| Unit tests (Swift Testing) | Rules, parsing, data | all (once, in the Kit package) | Seconds |
| Self-test (`--selftest`) | The app's real functions on a test store | each target | Seconds |
| Key events and menu audit (inside the self-test) | Keyboard flows and every shortcut | macOS (iPad with a keyboard) | Seconds |
| Debug bridge + computer use | Global shortcuts, panels, permissions, other apps | macOS | Minutes |
| Debug server or XCUITest | Taps, focus, navigation on a simulator or device | iOS, iPadOS, tvOS, watchOS, visionOS | Minutes |

Snapshots (`bama:build-and-verify`) prove how it looks. This skill proves
how it behaves.

## 1. Unit tests

Logic lives in the `<App>Kit` package with no SwiftUI, so tests run without
the app, once, for every platform. A Mac-only app keeps the Kit as a library
target in its root `Package.swift`. A multi-platform app has it as its own
package that every app target depends on.

```swift
import Testing
@testable import AppKitCore

@Test("Natural dates", arguments: [("tomorrow 9am", 1, 9), ("next fri", 5, nil)])
func parses(_ phrase: String, dayOffset: Int, hour: Int?) throws {
    let result = try #require(DateParser.parse(phrase, now: .fixed))
    #expect(result.dayOffset == dayOffset)
    #expect(result.hour == hour)
}
```

```bash
swift test --scratch-path ~/Library/Developer/<App>/test-build                         # Mac-only
swift test --package-path <App>Kit --scratch-path ~/Library/Developer/<App>/kit-build  # multi-platform
```

The Kit runs its tests on the Mac. Code behind `#if os(iOS)` (or another
platform) in the Kit is not compiled there, so it is not tested. Keep such
code out of the Kit, or test it in that platform's simulator with
`xcodebuild test -scheme <App>Kit -destination 'platform=iOS Simulator,id=<udid>'`
on the project simulator.

- Fix the clock (`now:` parameter) and the store path in every test.
- A parser that removes text from what the user typed needs at least 20
  negative rows: real titles that contain date or time words ("Watch
  Friday Night Lights"). Add consistency rows for related phrases ("next
  week" and "next friday"), and a tested way to undo a parsed part.
- **Table tests** for anything with many cases. Keep the table with the
  research findings too (`docs/research/<topic>.md`, or MuninnDB in
  `muninn` records mode), and add a row there before changing behavior. A
  date parser easily needs 100 rows.

Done with this step when the test command exits 0 and each new rule has a
test row.

## 2. Self-test

A launch flag that runs the same functions the UI calls, prints PASS or FAIL
per step, and exits 0 or 1:

```bash
tools/selftest.sh                    # macOS
tools/selftest.sh --platform ios     # in the bama-<App>-ios simulator
# PASS add task
# PASS complete task
# PASS undo
```

The script deletes `.work/self.store` (with `-wal` and `-shm`) and points
`APP_STORE` at it. In a simulator it passes the environment with the
`SIMCTL_CHILD_` prefix, which `xcrun simctl launch` hands to the app, and
sends the app's output to a log:

```bash
SIMCTL_CHILD_APP_STORE="$root/.work/self.store" \
  xcrun simctl launch --terminate-running-process \
  --stdout=.work/logs/selftest-ios.log --stderr=.work/logs/selftest-ios.log \
  <udid> <bundle-id> --selftest
```

The script waits up to 120 seconds for a `SELFTEST PASS` or `SELFTEST FAIL`
line in `.work/logs/selftest-<platform>.log`, prints PASS or FAIL per
platform, and exits 0 only when every platform passed. On a FAIL, Claude
reads that log. The watchOS app's bundle id is `<bundle-id>.watchkitapp`. The self-test never runs against the user's data or a
device's real data.

Checks worth adding to any self-test:

- Every action's Shortcuts title equals its menu or button title.
- Every SF Symbol name exists: `NSImage(systemSymbolName:accessibilityDescription:)`
  on macOS, `UIImage(systemName:)` on the others.
- Every URL action round-trips.
- For every page: New Item creates a row that is visible and selected (on
  macOS, focused) on that page. After an action removes the selected row,
  selection moves to the next row.
- Every value that differs per platform comes from the platform helper
  (`Platform.value(...)`): the self-test prints the value it read for the
  running platform, so a Mac size showing up on tvOS is visible.
- **Smoke step**: start every background timer, sampler, and observer for a
  few seconds, then print PASS. It is the only check that catches crashes on
  background queues.

A single-instance Mac app (menu bar utility) cannot launch a second copy
with `--selftest`. Make it a bridge command instead. Xcode projects without
a Kit package: see
[../build-and-verify/existing-app.md](../build-and-verify/existing-app.md)
for a test target with no host app.

Done with this step when `tools/selftest.sh` exits 0 on every target
platform the story names.

### Key events and menu audit (macOS)

The self-test can press real keys without computer use:

```swift
let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
    timestamp: 0, windowNumber: window.windowNumber, context: nil,
    characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
window.sendEvent(event)                               // Return in the focused list
NSApp.mainMenu?.performKeyEquivalent(with: commandK)  // a menu shortcut
```

Walk `NSApp.mainMenu` and check every command's title, key equivalent,
modifiers, and symbol against the command map. One loop turns "every
action has a menu item and a shortcut" into a check per item.

Focus the list after making the window key (`window.makeKey()`, then
`makeFirstResponder(list)`). A search field in the toolbar can take focus
first, and then list keys and menu items miss the list.

On iPad, the same command map drives `.keyboardShortcut` and the menu that
appears when the user holds Command. The self-test checks every command has
a shortcut in the map; the hardware keyboard itself needs XCUITest or the
user's device.

### Menu check (from outside, macOS)

Claude does not test SwiftUI menu state from inside the app. Its items
carry no action selector, `isEnabled` updates on SwiftUI's schedule, and the
checks fail whenever another app is in front, which is always true while an
agent works. In the self-test, check what the commands receive (the
selection passed into them) and run the actions the items call.

Check the real menu from outside, through Accessibility, on a seeded test
copy. Computer use `app_menu` works in the background:

1. Nothing selected: To-Do > Complete is reported disabled.
2. Click a row (`app_click`), then To-Do > Complete: the row is done and the
   next row is selected (`app_screenshot`).

Claude writes these steps into the app's `CLAUDE.md`, so every agent runs
them after touching commands.

### Runs that never hang

Each rule has a Mac form and a simulator form:

| Rule | macOS | Simulator |
| --- | --- | --- |
| Quit cleanly with an exit code | Quit through `NSApp.terminate`, with the exit code set in `applicationWillTerminate`. Close open sheets first, or terminate is refused and the run waits forever. | Print a last `SELFTEST PASS` or `SELFTEST FAIL` line, then `exit(code)`. iOS apps have no terminate call. The script waits for that line, not for the process. |
| Clear state from a crashed run | Delete `~/Library/Saved Application State/<bundle id>.savedState`. After a crash, the next launch shows a "reopen windows?" alert that blocks every later run with no output. Do not use `-ApplePersistenceIgnoreState`: SwiftUI then opens no window at all. | `xcrun simctl terminate <udid> <bundle-id>` before launch (or `launch --terminate-running-process`). Scene restoration can reopen the last page; the self-test sets its own starting page. |
| Start from an empty test store | Delete the test store and its `-wal` and `-shm` files before a seeded run. Seed data only fills an empty store. | The same, with `SIMCTL_CHILD_APP_STORE` pointing into the project's `.work/`. The simulator app can read and write the Mac path. |
| Keep the lines before a crash | Print line-buffered (`setvbuf(stdout, nil, _IOLBF, 0)`). | The same. `--stdout` and `--stderr` send the lines to `.work/logs/`, where they survive a crash. |
| Never wait forever | Every run has a time limit. A script Claude writes stops the app after 2 minutes and says it timed out. | `tools/selftest.sh` waits at most 120 seconds for the `SELFTEST` line and counts a missing line as FAIL. A simulator stuck on boot for 2 minutes is shut down (`xcrun simctl shutdown <udid>`, project simulator only) and the run starts again. |
| No permission prompts | Grant ahead in the test copy, or skip the check with a named reason. | `xcrun simctl privacy <udid> grant <service> <bundle-id>` before launch, so an alert does not block the run. |

## 3. Debug bridge (macOS)

For behavior a self-test cannot reach: global shortcuts, floating panels,
window control, permissions, timing. The running app listens for commands
and writes its state to a file. Code shape:
[../../code/os-integrations/recipes.md](../../code/os-integrations/recipes.md) (Debug bridge).

```bash
swift scripts/<app>ctl.swift status            # writes and prints status.json
swift scripts/<app>ctl.swift windowLeft        # runs an action by name
swift scripts/<app>ctl.swift snapshot:launcher # draws a window to a PNG
swift scripts/<app>ctl.swift captureProbe:.work/tmp/a.png   # runs, logs timing, cancels
```

Commands worth adding:

- `status`: permissions, feature flags, open panels, counts, last error.
- One command per action, by the same name as the menu item and URL.
- `snapshot:<window>`: captures one of the app's windows with ScreenCaptureKit
  (code in [../build-and-verify/existing-app.md](../build-and-verify/existing-app.md)).
- `appearance:light|dark|system`: switches the app's appearance for snapshots.
- `selftest`: the self-test as a command, for an app that is already running.
- `<feature>File:<path>`: opens an editor or card on a test file, with no
  clipboard or data change.
- `<feature>Probe`: runs a slow path and logs the time of each step (see
  `bama:performance`).

Compile the bridge in debug builds, or behind a launch flag in release.

## 4. Simulators and devices (iOS, iPadOS, tvOS, watchOS, visionOS)

A self-test covers the logic. To drive the real UI (tap, swipe, move focus,
read the screen) Claude uses one of three, cheapest first:

1. **XcodeBuildMCP**, when the session has it, on the project simulator:
   `snapshot_ui` reads the screen as elements, `tap`, `swipe`, `button`
   (tvOS remote presses), and `type_text` act on it. Point it at the UDID
   in `.work/simulators`. Good for one story's acceptance lines.
2. **An HTTP debug server** inside the debug build, for repeatable checks
   and for physical devices, where XcodeBuildMCP UI tools do not reach. The
   app listens on a local port and answers `GET /status`, `POST
   /action/<name>`, `GET /screenshot`, `GET /focus` (tvOS: the focused
   element). On a device, Claude reaches it over the local network. When
   the session has `debug-server-architect`, Claude calls it for the
   design; otherwise it mirrors the Mac bridge commands above as HTTP
   routes. Compile it in debug builds only.
3. **XCUITest**, in a UI test target, for a check that must run the same
   way every time, in CI or before a release:

   ```bash
   xcodebuild test -scheme <App>UITests -destination 'platform=tvOS Simulator,id=<udid>'
   ```

   Pass the test store through `app.launchEnvironment["APP_STORE"]`. A UI
   test launches its own copy of the app; close other copies first.

What tools cannot check, and who does:

- **iOS back swipe.** No simulator tool can trigger the edge swipe. Claude
  taps Back on every page, then asks the user to swipe from the left edge
  on a device and confirm the page slides back with the finger.
- **tvOS focus entry.** Claude presses into each row, grid, and bar from
  every side and reads where focus lands (`button` presses, then `/focus`
  or `snapshot_ui`). The rule: the item last highlighted there, else the
  first. `tvos-focus-navigation` covers the fix when the session has it.
- **Digital Crown, gaze and pinch, haptics, the real remote.** The
  simulator approximates or skips them. Claude names each as a manual check
  for the user's device.

Devices: Claude installs and launches with `xcrun devicectl` (commands in
[../build-and-verify/existing-app.md](../build-and-verify/existing-app.md)),
and terminates the app with `xcrun devicectl device process terminate` when
the check ends.

## 5. Computer use (macOS and iPhone Mirroring)

Last resort, for what only a person can do: a real key press in another
app, drag and drop from Finder, a permission prompt. On an iPhone shown in
iPhone Mirroring on the Mac, computer use can tap and swipe it like a Mac
window. See `bama:clone` for setup. Claude asks the user to keep off the
mouse while it runs, and captures the app's own window, never the full
screen. The session stops when the check ends.

## Debug output

A GUI app's `print` is buffered and lost when the process is killed. Write
debug lines to stderr (`FileHandle.standardError.write`) behind an
environment flag (`APP_DEBUG=1`, or `SIMCTL_CHILD_APP_DEBUG=1` in a
simulator).

## Finish

Claude stops every test copy, simulator, debug server session, and
computer use session it started. The scripts shut down their simulator
themselves. The report lists which platforms were tested and at which
level, names every manual check left for the user's device, and ends with
the output of `tools/footprint.sh`.

Done when every acceptance line of the story maps to a passing test,
self-test step, bridge or server command, UI test, or a named manual check
on each platform in its `Platforms:` line, the bug fix has a test that
failed before the fix, and nothing Claude started is still running.
