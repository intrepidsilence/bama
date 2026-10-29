---
name: new-app
description: Native SwiftUI app scaffold for any Apple platform (macOS, iPhone, iPad, Apple TV, Apple Watch, Vision Pro) from a working template with SwiftData, build scripts, snapshot mode, a self-test, and git, with no Xcode GUI. Use when the user wants to start a new Apple app, scaffold a Mac or multi-platform project, or turn a brief into a first build.
argument-hint: "<AppName> <bundle-id> [parent-folder] [--platforms ios,tvos,...]"
allowed-tools: Bash(*/new-app.sh *) Bash(git *) Bash(swift *) Bash(./build.sh *) Bash(tools/*) Bash(xcrun simctl *) Bash(xcodegen *) Read Write Edit
---

# New app

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Claude follows [CONVENTIONS.md](../../../CONVENTIONS.md): voice, platform ids,
the `.work/` folder, the footprint, simulators, and git. Both templates build
and run as they are. The first build proves the toolchain works before any
feature code.

## Pick the template from the platforms

The brief's **target platforms** decide (`docs/BRIEF.md`, or the brief
recalled from MuninnDB in `muninn` mode). Without a brief, Claude asks the
user which devices the app is for. Ids: `macos`, `ios`, `ipados`, `tvos`,
`watchos`, `visionos`.

| Platforms | Template | What it is |
| --- | --- | --- |
| `macos` only | `template/` | A Swift package. `build.sh` wraps the binary in a real `.app`. No Xcode project. |
| anything else | `template-multi/` | An XcodeGen `project.yml` with one app target per platform, a shared `<App>Kit` package, and shared SwiftUI in `Shared/`. |

Both templates hold the same app: a list of items in SwiftData, sample data,
snapshot mode, and a self-test. Every BAMA skill works on either.

## What the templates hold

```text
macOS only (template/)
  Package.swift            macOS 26, Swift 6.2 tools, main-actor default isolation
  Info.plist.in            bundle id, name, icon, minimum macOS
  Sources/<App>/           App, Models, ContentView, Snapshot, SelfTest, SeedData, Settings, UI/
  Sources/<App>Kit/        logic with no SwiftUI; Tests/<App>KitTests/
  tools/make_icon.sh       Icon/AppIcon.icon -> Resources/Assets.car + AppIcon.icns
  tools/check-layout.swift checks the layout files from snapshot mode

multi-platform (template-multi/)
  project.yml              XcodeGen spec, only the targets asked for, deployment 26.0
  tools/platforms          this project's platform ids
  Shared/                  App, Store, Models, ContentView, ItemList, ItemGrid (tvOS),
                           ItemDetail, Snapshot, SelfTest, SeedData, SettingsView (macOS)
  Shared/UI/Platform.swift Platform.value(mac:phone:pad:tv:watch:vision:)
  <App>Kit/                Swift package: logic with no SwiftUI, Swift Testing tests
  tools/lib.sh             shared script code: stages, timeouts, project simulators

both
  build.sh  CLAUDE.md  Icon/AppIcon.icon  .gitignore (.work/ included)
  tools/snap.sh  tools/selftest.sh  tools/footprint.sh  tools/grid-lint.sh
  tools/icon_review.sh  tools/icon_sheet.swift
```

Navigation per device in the multi-platform template: a split view on the
Mac; tabs on iPhone, iPad (a sidebar), Apple TV, and Vision Pro, each tab a
NavigationStack so Back and the edge swipe work; one NavigationStack on Apple
Watch. On Apple TV the cards sit in a scroll view with `.scrollClipDisabled()`
and focus room, and each focus region declares where focus enters.

## The scripts

Same flags in both templates. A Mac-only project takes only `macos`.

```bash
./build.sh [--platform <id>] [--debug] [--open]   # all platforms when no --platform
tools/snap.sh [--platform <id>] [--open]          # .work/shots/<platform>/<page>-<light|dark>.png
tools/selftest.sh [--platform <id>]               # PASS per check, exit 0
tools/footprint.sh [list|clean]                   # everything outside the project
tools/grid-lint.sh                                # spacing on the 4 pt grid
tools/icon_review.sh                              # .work/icon/review*.png
```

- `macos` installs `~/Applications/<App>.app`. Other platforms build with
  `xcodebuild -derivedDataPath ~/Library/Developer/<App>/DerivedData` and
  install into the project simulator `bama-<App>-<platform>`, which the
  scripts create on first use and list in `.work/simulators`.
- The scripts shut a simulator down when they finish, unless `--open` or it
  was already running. `--open` leaves the app open for the user.
- Multi-platform scripts print `[n/N] pct% stage` per step, a heartbeat each
  minute, and a `TIMEOUT` line when a step hangs. Build logs go to
  `.work/logs/`.

## Steps

1. Check the toolchain:

   ```bash
   swift --version            # Swift 6.2 or later
   xcodebuild -version        # Xcode 26 or later
   sw_vers -productVersion    # 26.0 or later
   which xcodegen             # multi-platform only: brew install xcodegen
   ```

   For a non-Mac platform, `xcrun simctl list runtimes` must list its runtime
   (Xcode > Settings > Components installs one).

2. Pick the name (one UpperCamelCase word), the bundle id (reverse DNS), and
   the platforms. If the brief exists, use its name and target platforms.

3. Run the script with the parent folder. It copies the template, fills in
   the name and bundle id, writes `project.yml` for the chosen platforms, runs
   `git init`, stages the files it created by name, and commits. It keeps a
   folder that holds only `docs/` and commits `docs/` too.

   ```bash
   "${CLAUDE_SKILL_DIR}/scripts/new-app.sh" Tasks com.yourname.tasks ~/Developer
   "${CLAUDE_SKILL_DIR}/scripts/new-app.sh" Tasks com.yourname.tasks ~/Developer --platforms ios,ipados,watchos
   ```

   In a Dropbox or iCloud Drive folder the script can take minutes: Claude
   runs it in the background.

4. Build every platform. On a Mac target, add `--open` at the end so the user
   can try it.

   ```bash
   cd ~/Developer/Tasks && ./build.sh
   ```

5. Run the checks, then look at the snapshots of every platform
   (`bama:build-and-verify`):

   ```bash
   swift test --scratch-path ~/Library/Developer/Tasks/test-build                          # Mac-only Kit tests
   swift test --package-path TasksKit --scratch-path ~/Library/Developer/Tasks/kit-build   # multi-platform Kit tests
   tools/selftest.sh
   tools/snap.sh
   ```

   Claude opens a light and a dark PNG per platform and confirms they show
   the sample items.

6. If the brief exists, rename `Item` to the brief's main type and the pages
   to the brief's pages. Nothing else: features go through
   `bama:improve-loop`, one story at a time. Build, snapshot, commit.

7. Report to the user what they can now open or try, which platforms built,
   and what `tools/footprint.sh` lists. Name anything left running.

## Later changes

- Add a platform to a multi-platform project: append its block from this
  skill's `template-multi/project/<id>.yml` to `project.yml` (fill
  `__APP_NAME__`, `__BUNDLE_ID__`, and for iOS `__IOS_FAMILY__`), add its id to
  `tools/platforms`, then build and snapshot it.
- A Mac-only app that needs App Intents, an asset catalog, extensions, or
  widgets moves to an XcodeGen project the same way: start from
  `template-multi/` with `--platforms macos,...` or write `project.yml` by
  hand. Keep `project.yml` in git and the `.xcodeproj` out of it.
- Apple TV and Vision Pro icons are layered images in an asset catalog, not
  the `.icon` file: `bama:app-icon`.
- The watch app is standalone (`<bundle-id>.watchkitapp`). Pairing it with
  the iPhone app is a later story.

## Signing

The Mac app is signed with the first "Apple Development" certificate in the
keychain, or ad hoc without one. Permissions (Accessibility, Screen
Recording, camera) are stored per signature and path; ad hoc builds ask again
after every rebuild. A free Apple ID makes a certificate in Xcode > Settings >
Accounts > Manage Certificates. Simulator builds are ad hoc. A real iPhone,
Apple TV, or Watch needs a team and a provisioning profile.

## A CLI for agents

To let Claude Code, Codex, or scripts read and change the app's data, call
the Skill tool with `bama:agent-cli`.

## When the build fails

- `cannot find 'X' in scope` after adding a file (Mac-only): SwiftPM cached
  the file list. Run `swift package clean --scratch-path ~/Library/Developer/<App>/build`.
- Multi-platform: `build.sh` regenerates the project each time, so new files
  join every target. Read `.work/logs/build-<platform>.log`. An API missing on
  one platform needs an `#if os(...)` block.
- `database is locked`: another build of the same project is still running.
  Stop it before building again.
- `binary is older than ...`: a file did not compile. Read the first errors.
- Concurrency errors: call the Skill tool with `bama:swift-swiftui`.

Done when every chosen platform builds, the self-test passes on each, the
light and dark snapshots of each show the sample items, the first commit
exists, and the report names what `tools/footprint.sh` lists and anything
left open.
