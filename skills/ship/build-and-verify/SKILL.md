---
name: build-and-verify
description: Build a SwiftUI app for each of its Apple platforms, install it, and check light and dark snapshots of every page before calling a change done. Use after any UI code change, when a build fails, or when the user asks to run, screenshot, or check the app on Mac, iPhone, iPad, Apple TV, Apple Watch, or Vision Pro.
allowed-tools: Bash(./build.sh*) Bash(swift *) Bash(tools/*) Bash(xcrun simctl *) Bash(xcrun devicectl *) Bash(xcodebuild *) Bash(xcodegen *) Bash(*/Contents/MacOS/*) Bash(open *) Read
---

# Build and verify

Claude follows [CONVENTIONS.md](../../../CONVENTIONS.md): the platform ids
(section 2), the `.work/` folder (3), the footprint (4), project simulators
(5), and what may stay running (6).

A change is done when four things are true, on every target platform the
change can reach:

1. `./build.sh --platform <id>` finishes with no errors.
2. Claude looked at the light and dark snapshots of every page the change
   touched.
3. The snapshots match what the user story or reference screenshot asks for.
4. The grid checks pass (`bama:layout-grid`).

Shared code (the `<App>Kit` package, a view used by several targets)
reaches every target. A file in one platform's folder reaches only that
platform. Read the target list in `docs/BRIEF.md` (or the brief in
MuninnDB) and the story's `Platforms:` line first.

App not made from the `bama:new-app` template (an Xcode project, XcodeGen
without the template scripts, a menu bar utility, Swift 5)? Map the commands
below with [existing-app.md](existing-app.md) first.

Claude does not report a UI change as done from the code alone. SwiftUI code
that compiles can still render an empty sidebar, clipped text, a focus
highlight cut off at a row edge, or unreadable dark mode.

## 1. Build

```bash
./build.sh                         # macOS: release build, installs ~/Applications/<App>.app
./build.sh --platform ios          # builds and installs into the project's iPhone simulator
./build.sh --platform tvos --debug # faster build while iterating
./build.sh --open                  # also restarts the Mac app so the user sees the new build
./build.sh --platform ios --open   # leaves the simulator up with the new build launched
```

A Mac-only app has only `macos`, and `--platform` can be left out. A
multi-platform app builds one platform per run. After a change in shared
code, Claude builds every target in the brief.

Read the errors, fix them, and build again. Fix the first error first: later
errors often come from it. If a new file is "not in scope" right after
Claude created it:

- Swift package (Mac-only): `swift package clean --scratch-path ~/Library/Developer/<App>/build`.
- XcodeGen project: run `xcodegen generate` (a new file is not in the
  project until then), then build again.

Each build writes its log to `.work/logs/build-<platform>.log`, and records
the app it built in `.work/built-<platform>`. A build whose log has not
grown for 5 minutes is stuck, not slow. Claude stops it, says so, and reads
the last lines of that log before trying again.

Done with this step when the build line ends with no `error:` lines for
each platform built.

## 2. Snapshot

`tools/snap.sh` starts the app on a fresh test database with sample data
(`APP_SEED=1`), walks every page in light and dark mode, saves one PNG per
page and mode, and quits.

```bash
tools/snap.sh                       # macOS
tools/snap.sh --platform ios        # in the bama-<App>-ios simulator, then shuts it down
# SNAPSHOT <project>/.work/shots/ios/all-light.png
# ...
# [n/n] 100% snapshots in <project>/.work/shots/
```

The Mac-only template ends with `SNAPSHOT done <folder>`. The
multi-platform template ends with `[n/n] 100% snapshots in <folder>`, or
`[n/n] 100% FAILED: <platforms>` when a platform failed.

Images land in `.work/shots/<platform>/<page>-<light|dark>.png`. The
Mac-only template also writes a `-layout.json` grid probe beside each. The
script deletes the old test store
(with its `-wal` and `-shm` files) and, on macOS, the saved window state
first. Without that, seed data goes stale, and one crashed run leaves a
"reopen windows?" alert that hangs every later run.

Use `APP_SNAPSHOT_PAGES=all,detail` (a comma list) to limit the pages. The
template's pages are `all`, `starred`, and `detail`, plus `settings` on the
Mac; an app adds its own. On a simulator, `tools/snap.sh` reads the list
itself and launches the app once per page with
`SIMCTL_CHILD_APP_SNAPSHOT_PAGE=<page>`.

The app runs only against `APP_STORE` in `.work/`. Snapshots never touch the
user's real data in `~/Library/Application Support/<App>/` or a device's
real data.

Done with this step when the script's last line reports success (`SNAPSHOT
done`, or `100% snapshots in`) with no `FAILED` or `TIMEOUT` line, and every
page has a light and a dark PNG for each platform.

### Seed data

Empty pages only show empty states. The template's seed data
(`SeedData.swift`) fills an empty test store when `APP_SEED=1` is set. Grow
it with the app: 10 to 20 items with long and short titles, dates in the
past and future, every priority and status, and only what a person can
create in the app.

### macOS capture problems

Snapshots on macOS use `screencapture -l <window>`, which shows glass,
sidebars, and materials exactly as on screen. It needs Screen Recording
permission for the app that runs the command (Terminal, Ghostty, or
Claude). If a snapshot line ends with `(fallback: ...)`, the permission is
missing and sidebars and glass render blank. Claude asks the user to allow
it in System Settings > Privacy & Security > Screen & System Audio
Recording, then restart the terminal.

If every snapshot fails, or `screencapture` says "could not create image
from window", the display is probably asleep. The template's snapshot mode
wakes it. For captures from outside the app, run `caffeinate -u -t 2`
first.

If some states print "no window" while others work, another app hid the
window during the run. Computer use does this to apps it does not control,
and so does Hide Others. Claude runs the snapshots again, with no computer
use in another session at the same time.

Gray traffic lights mean the window was not key when it was captured:
sidebar text, selection, and toggles look dimmer than in use. A snapshot of
an inactive window does not count as reviewed. Claude runs it again while
nobody else uses the screen, and does not "fix" dim text seen only there.

### Simulator capture problems

- `tools/snap.sh --platform <id>` creates `bama-<App>-<id>` on first use
  and records it in `.work/simulators`. Claude never points it at another
  simulator: other sessions and people use them.
- With XcodeBuildMCP in the session, its `screenshot` and `snapshot_ui`
  tools are fine for one extra look. Claude passes the UDID from
  `.work/simulators`.
- A simulator that sits on the boot screen for 2 minutes is stuck. Claude
  stops the run, runs `xcrun simctl shutdown <udid>` on the project
  simulator only, and starts again.

## 3. Check the grid

```bash
tools/grid-lint.sh                                             # every app
swift tools/check-layout.swift .work/shots/macos/*-layout.json # Mac-only template
```

Both print PASS. The multi-platform template writes no layout probes, so
there `tools/grid-lint.sh` is the grid check, and Claude checks spacing by
eye in step 4. On a FAIL, call the Skill tool with
`bama:layout-grid`: it has the rules, the overlay, and a table of fixes.

## 4. Look

Claude opens every PNG with the Read tool and checks, in this order:

- Nothing is blank, clipped, or overlapping. Text fits. Sidebars and lists
  show their items.
- Dark mode is readable. No fixed white or black surfaces.
- The page matches the story in layout, labels, and order: its `[snap]`
  acceptance lines for this platform (lines prefixed with another platform
  do not apply) and its reference screenshot, `docs/screens/<NN>-<page>.png`
  in a single-platform app or `docs/screens/<platform>/<NN>-<page>.png`
  when there are several.
- The design rules hold: `bama:mac-design` on macOS, `bama:platform-design`
  on the others. Glass only on controls, one accent, SF Symbols, system text
  styles, empty states that invite the first action.

Then the checks for each platform:

| Platform | What to look for |
| --- | --- |
| `macos` | A focus ring or selected text nobody asked for, a scroll bar with nothing to scroll, an empty band under short content (fixes in `bama:mac-design`, "Windows open calm"). For scroll bars as a mouse user sees them, add `-AppleShowScrollBars Always` after the binary path. |
| `ios`, `ipados` | Content under the notch, the Dynamic Island, or the home indicator. Tap targets under 44 pt. Text cut off at the largest Dynamic Type size. On iPad, the layout at full width and in Split View. |
| `tvos` | A focused card or button grows when highlighted. At the first and last item of every row and column, its rounded ends and shadow must show in full, never cut flat by a scroll view or `.clipped()`. Text and cards sized for a TV across the room. |
| `watchos` | One idea per screen. Nothing cut off at the round corners. Text readable at the smallest watch size. |
| `visionos` | Content on glass, not on a solid background. Hover targets at least 60 pt. Nothing placed where the user must turn their head to read it. |

Claude describes what it sees in one or two sentences per page, and names
the PNG paths so the user can open them.

Done with this step when every PNG for every built platform was opened and
described.

## 5. Interaction checks

Snapshots show state, not behavior. Claude runs the self-test on each
built platform and adds a check for each new action:

```bash
tools/selftest.sh                   # macOS
tools/selftest.sh --platform ios    # in the project simulator
```

Each exits 0 when every check passes. `bama:test-app` covers unit tests,
the self-test, key events, the menu check, the debug bridge, and device
testing.

Some behavior tools cannot see. Claude checks it a second way, or asks the
user, and says which:

- **tvOS focus.** Where the highlight lands when the user presses into each
  row, grid, or bar from every side. The rule: the item last highlighted
  there, else the first. Check it in the simulator by pressing the remote
  arrows (XcodeBuildMCP `button`, or `xcrun simctl io` key presses) and
  reading the focused item after each press. `tvos-focus-navigation` covers
  the fix when the session has it.
- **iOS back swipe.** Wherever a page has a Back button, the swipe from the
  left edge must slide the page back with the finger. Simulator tools
  cannot trigger an edge swipe, so a simulator run proves nothing. Claude
  taps Back on every page with the tools, then asks the user to try the
  swipe on a device and confirm.
- **visionOS gaze and pinch** and **watchOS Digital Crown**: the simulator
  approximates them. Claude names any check that needs the user's device.

### Debug output and private screens

A GUI app started with its output going to a file buffers `print`, and the
lines are lost when the process is killed. Write debug lines to stderr
(`FileHandle.standardError.write`) behind an environment flag.

Claude never takes a full-screen Mac capture to check the app: it shows the
user's other windows. Claude captures the app's own window or the project
simulator, or adds a mode to the app that renders the state to see
(prefilled text, an open sheet).

## 6. Finish

1. Stop what the run started. `tools/snap.sh` and `tools/selftest.sh` shut
   their simulator down. Only the app the user should try stays open
   (`./build.sh --open`, or `--platform <id> --open`), and the report names
   it.
2. Run `tools/footprint.sh` and copy its lines into the report.
3. Commit only when the user asked for commits in this session (section 7):
   stage named paths with `git add <paths>`, never `git add -A`, and write
   a message that says what the user can now do: "Add tasks from the
   quick-add panel", not "Update views".

The report leads with what the user can now see or do, then says which
platforms were checked and how (snapshots, self-test, simulator presses,
or "needs the user's device").

Done when the four conditions at the top hold for every target the change
reaches, the report names each platform and how it was checked, the
footprint lines are in the report, and nothing but the named open app is
still running.
