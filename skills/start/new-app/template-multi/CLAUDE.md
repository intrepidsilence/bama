# __APP_NAME__

A native SwiftUI app for several Apple platforms, from one set of sources,
with a local SwiftData database and no server. Claude builds and checks it;
the user decides what it does.

The platforms are in `tools/platforms` (ids: `macos`, `ios`, `ipados`,
`tvos`, `watchos`, `visionos`). Every script works on all of them, or on one
with `--platform <id>`.

## Layout

- `project.yml` the XcodeGen spec: one app target per platform (`__APP_NAME__` for the Mac, `__APP_NAME__-iOS` for iPhone and iPad, `__APP_NAME__-tvOS`, `__APP_NAME__-watchOS`, `__APP_NAME__-visionOS`). `build.sh` generates `__APP_NAME__.xcodeproj` from it on every build. Edit `project.yml`, never the `.xcodeproj` (it is not in git).
- `Shared/` the app, compiled into every target. Per-platform code sits in `#if os(...)` blocks.
  - `App.swift` scenes, Mac menus and Settings. `Store.swift` the database location.
  - `Models.swift` the SwiftData model, the pages, and `AppModel`.
  - `ContentView.swift` navigation per device: a split view on the Mac, tabs with a NavigationStack per tab on iPhone, iPad, Apple TV, and Vision Pro, one NavigationStack on Apple Watch.
  - `ItemList.swift` the list (Mac, iPhone, iPad, Watch, Vision Pro). `ItemGrid.swift` the focusable cards on Apple TV. `ItemDetail.swift` one item.
  - `SeedData.swift`, `SelfTest.swift`, `Snapshot.swift` test support (below).
  - `UI/Platform.swift` `Platform.value(mac:phone:pad:tv:watch:vision:)`. `UI/Grid.swift` spacing and sizes. `UI/Theme.swift` the accent.
- `__APP_NAME__Kit/` a Swift package with rules and data logic and no SwiftUI, shared by every target, with Swift Testing tests.
- `Icon/AppIcon.icon` the icon, an Icon Composer file. Xcode compiles it into the Mac, iPhone, iPad, and Watch apps. Apple TV and Vision Pro need layered icons in an asset catalog (`bama:app-icon`).
- `docs/` the brief, the screen index, and the user stories, when they exist.
- `.work/` everything temporary: snapshots, test stores, logs, the list of project simulators. It is in `.gitignore`. Nothing goes to `/tmp`.

## Build and check

Every long step prints `[n/N] pct% stage` and stops with a `TIMEOUT` line if it hangs.

- Build: `./build.sh` (every platform) or `./build.sh --platform tvos`. `--debug` for a debug build. Logs: `.work/logs/build-<platform>.log`. The build lists this project's warnings; fix them.
  - `macos` installs `~/Applications/__APP_NAME__.app`.
  - Other platforms install into the project simulator `bama-__APP_NAME__-<platform>`, created on first use and listed in `.work/simulators`.
  - `--open` leaves the app open for the user: the Mac app, or the simulator with the app launched.
- Unit tests: `swift test --package-path __APP_NAME__Kit --scratch-path ~/Library/Developer/__APP_NAME__/kit-build`.
- Self-test (the app's real functions on `.work/self.store`): `tools/selftest.sh [--platform <id>]`. Exit 0 when every check passes on every platform. Add a check for every story with logic in `SelfTest.swift`.
- After every UI change, take snapshots with sample data and look at them: `tools/snap.sh [--platform <id>] [--open]`.
  It writes `.work/shots/<platform>/<page>-light.png` and `-dark.png` for every page (`all`, `starred`, `detail`), plus `settings-*.png` on the Mac. `APP_SNAPSHOT_PAGES=all,detail tools/snap.sh` limits the pages.
  On a simulator it launches the app once per page (`APP_SNAPSHOT_PAGE=<page>`), waits for `SNAPSHOT ready`, and takes the screenshot with `xcrun simctl io`. Add a page in `Snapshot.swift`.
  Apple Watch is always dark, and Vision Pro draws its windows on glass, so their light and dark shots look alike.
- Spacing: `tools/grid-lint.sh` prints PASS.
- Snapshots, seed data, and the self-test refuse to run unless `APP_STORE` is set to a test file outside the real data folder. The scripts use `.work/test.store` and `.work/self.store`.
- Never test against the real database (`Application Support/__APP_NAME__/`).
- A change is done when every platform builds with no errors, the self-test passes, and Claude looked at the light and dark snapshots of every platform the change touches. A change in `Shared/` touches every platform.

## Simulators

- Claude uses only this project's simulators, `bama-__APP_NAME__-<platform>`. Other sessions share this Mac: never boot, shut down, or erase another simulator, and never `shutdown all`.
- The scripts shut a simulator down when they finish, unless `--open` or it was already running.
- XcodeBuildMCP tools are fine for taps and screenshots: point them at the UDID in `.work/simulators`.

## Outside the project

- `tools/footprint.sh` lists every place the project keeps files outside this folder (build products in `~/Library/Developer/__APP_NAME__/`, the Mac app, window state, the project simulators), with sizes.
- `tools/footprint.sh clean` removes them all, and `.work/`. It never removes the real data.
- Anything new a change creates outside the project gets a line in `tools/footprint.sh` in the same change.

## Design rules

- Each platform follows its own conventions (`bama:platform-design`, and `bama:mac-design` for the Mac). Shared code is no excuse for one layout everywhere.
- Every size, spacing, or behavior that differs per device goes through `Platform.value(...)` or an `#if os(...)` block. A value chosen for one device never leaks into another.
- Spacing comes from `Space` in `UI/Grid.swift`, on a 4 pt grid. Colors: `.primary`, `.secondary`, `.tint`, `Palette`, and system colors. Never hard-coded colors or fixed grays for text.
- iPhone and iPad: pages open with NavigationStack pushes, so Back and the swipe from the left edge both work. Never hide the system Back button.
- Apple TV: a focused control grows and casts a shadow. Containers around focusable views give it room (`.scrollClipDisabled()`, `Space.focusRoom` padding); never `.clipped()` or `.clipShape` around them. Every focus region is a `focusSection()` that says where focus enters (the item last focused there, else the first) with `.defaultFocus(..., priority: .userInitiated)`. `ItemGrid.swift` shows both. Check the first and last card of a row focused in a snapshot.
- Mac: every action has a menu bar item and a keyboard shortcut. Settings live in the Settings window.
- `Label` for icon and text pairs, SF Symbols for icons, `ContentUnavailableView` for empty states.

## Skills

The bama plugin has a skill for each step. Claude calls them with the Skill
tool: `bama:platform-design` and `bama:mac-design` (design rules),
`bama:design-system`, `bama:layout-grid`, `bama:ux-design`,
`bama:swift-swiftui`, `bama:os-integrations`, `bama:performance`,
`bama:build-and-verify`, `bama:test-app`, `bama:app-icon`,
`bama:user-stories`, and `bama:improve-loop`.

## Git

- Stage named paths (`git add <paths>`), never `git add -A` or `git add .`.
- Commit after each working change, with a message that says what the user can now do. Never push.
