# BAMA conventions

Every skill in this plugin follows these rules. A skill links here instead of
repeating them. Where a skill and this file disagree, this file wins.

## 1. Voice

- The agent is **Claude**. Skill text says "Claude does X", never "you do X"
  or "I do X". The person is **the user**.
- In everything Claude says to the user (reports, questions, status lines),
  Claude names itself "Claude" and never says "I". Example: "Claude built
  M1. The user should try Command-Return on a task."
- Reports lead with what the user can now do or see, in plain words. File
  paths go at the end, as references.

## 2. Platforms

BAMA builds apps for every Apple platform. The platform ids used in file
names, flags, and folders:

| Id | Platform | Input | Build and run |
| --- | --- | --- | --- |
| `macos` | macOS | pointer, keyboard, menu bar | `./build.sh` installs `~/Applications/<App>.app` |
| `ios` | iPhone | touch | project simulator, or a device with `xcrun devicectl` |
| `ipados` | iPad | touch, pointer, keyboard | project simulator (an iPad device type) |
| `tvos` | Apple TV | Siri Remote, focus | project simulator, or a device |
| `watchos` | Apple Watch | touch, Digital Crown | project simulator |
| `visionos` | Apple Vision Pro | gaze and pinch | project simulator |

- The brief names the **target platforms** (`app-brief`). Every skill reads
  that list first and applies the rules for each target, not only the one
  being worked on.
- A Mac-only app uses the Swift package template. An app with any other
  target uses the multi-platform template (XcodeGen `project.yml`, a shared
  `<App>Kit` package, one app target per platform). See `bama:new-app`.
- Design rules per platform: `bama:mac-design` for macOS,
  `bama:platform-design` for the others.
- In shared code, every size, spacing, and behavior that differs per
  platform goes through one helper (`Platform.value(mac:phone:pad:tv:watch:vision:)`
  in the multi-platform template) or an `#if os(...)` block. A value written
  for one platform never leaks into another. After a change in shared code,
  Claude checks every target, not only the one in front of it.

## 3. The work folder

Every BAMA project has a `.work/` folder at its root, listed in
`.gitignore`. Everything temporary goes there. Claude never writes to `/tmp`
or `/private/tmp`, and never sets `TMPDIR` to them.

| Path | What |
| --- | --- |
| `.work/shots/<platform>/<page>-<light\|dark>.png` | snapshots, plus `-layout.json` grid probes |
| `.work/test.store` | the snapshot run's test database (`APP_STORE`) |
| `.work/self.store` | the self-test's test database |
| `.work/check.store` | the agent CLI check's test database |
| `.work/sock/` | Unix sockets for test runs (short names: socket paths must stay under 104 bytes) |
| `.work/compare/` | pixel comparisons (`design-from-app`, `improve-loop`) |
| `.work/traces/` | Instruments traces and `sample` output |
| `.work/icon/` | icon renders for review |
| `.work/hig/` | cached Human Interface Guidelines pages |
| `.work/simulators` | the project's own simulators, one `<platform> <udid>` per line |
| `.work/tmp/` | anything else; scripts use `mktemp -p "$root/.work/tmp"` |

- Test databases: the app refuses snapshot mode, seed data, and the
  self-test unless `APP_STORE` is set, and it never sets it to the real data
  folder. Scripts always set it to a path in `.work/`.
- `.work/` is disposable. `tools/footprint.sh clean` empties it.

## 4. The footprint: everything outside the project

Some things must live outside the repo: build products (so iCloud or
Dropbox do not sync them), the installed Mac app, simulators. Each project
tracks them in one committed script, `tools/footprint.sh`:

```bash
tools/footprint.sh          # list every location, whether it exists, and its size
tools/footprint.sh clean    # remove build products, the installed app, saved window
                            # state, the project's simulators, and .work/
```

It knows these locations (`<App>` and `<bundle-id>` filled in at scaffold
time):

| Location | What | `clean` removes it |
| --- | --- | --- |
| `.work/` | temporary files | yes |
| `~/Library/Developer/<App>/` | build products, test builds, DerivedData | yes |
| `~/Applications/<App>.app` | installed Mac app | yes |
| `~/Library/Saved Application State/<bundle-id>.savedState` | window state | yes |
| simulators in `.work/simulators` | the project's own simulators and apps in them | yes (`xcrun simctl delete <udid>`) |
| `~/Library/Application Support/<App>/` | **the user's real data** | never; listed only |
| `~/Library/Preferences/<bundle-id>.plist` | the user's real settings (window frames, Settings choices) | never; listed only |
| `~/.local/bin/<cli>` | the agent CLI link (`agent-cli`) | yes, only when it points into the project or its build |
| `~/.claude/skills/<cli>/`, `~/.codex/skills/<cli>/`, Claude Desktop `mcpServers.<cli>` | agent registrations (`agent-cli`) | never; listed only |

A skill that creates something new outside the project adds it to
`tools/footprint.sh` in the same change. When Claude reports, it says which
of these exist after the run.

## 5. Simulators

- Claude uses only the project's own simulators: named
  `bama-<App>-<platform>`, created with `xcrun simctl create`, and recorded
  in `.work/simulators`. The scripts create one on first use. Claude never
  boots, shuts down, or erases a simulator it did not create: other
  sessions and people share this Mac.
- XcodeBuildMCP tools, when the session has them, are fine for build, run,
  screenshot, and UI taps. Point them at the project simulator's UDID.
- A script that boots a project simulator shuts it down when it finishes,
  except `--open` (below).

## 6. What may stay running

At the end of a run, the app being built may stay open so the user can try
it: on macOS, the installed app (`./build.sh --open`); on another platform,
the one project simulator with the app launched (`--open`). Claude names
what it left open in its report. Everything else Claude started stops when
its measurement ends: test copies of the app, other booted simulators, log
streams, Instruments recordings, computer use sessions.

## 7. Git

- Claude stages named paths (`git add <paths>`), never `git add -A` or
  `git add .`, so `.work/`, screenshots, and stray files stay out.
- Claude never pushes, and never rewrites history.
- `new-app` makes the first commit of the repo it just created.
- `improve-loop` commits one story per commit. Starting the loop is the
  user's permission for those commits. If the repo is on its default branch,
  the loop first creates `bama/<milestone>` (for example `bama/m2`) and
  works there.
- Other skills commit only when the user asked for commits in this session.
- A commit message says what the user can now do. When the session gives
  commit attribution lines, Claude adds them.

## 8. Records: Markdown files or MuninnDB

The plugin setting `records` picks where durable knowledge goes. Claude
Code fills setting values into SKILL.md files only, not into this file, so
every skill that reads or writes knowledge carries this line near its top:

```markdown
Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](<relative path>), section 8.
```

The value shown there is the mode. If it shows the raw `${user_config...}`
text (another agent, or the setting is unset), the mode is `markdown`. The
user changes it in `/config`, or with
`claude plugin configure bama@<marketplace>`.

Two kinds of files:

- **Working files** stay files in both modes, because scripts and the loop
  read and edit them: `docs/STORIES.md` (the backlog and its status),
  `docs/screens/INDEX.md` (pairs with the PNGs), `design/DESIGN-SYSTEM.md`
  and `design/KIT.md` (pair with the Swift tokens), `ARCHITECTURE.md`.
- **Knowledge** follows the setting:

| Knowledge | `markdown` | `muninn` |
| --- | --- | --- |
| Research findings | `docs/research/<topic>.md` | one memory per finding, type `fact` or `observation` |
| The brief | `docs/BRIEF.md` | one memory per section (idea, users, targets, scope, non-goals), type `goal` or `decision` |
| Glossary | `docs/GLOSSARY.md` | one memory per term, type `reference` |
| Fix log | `docs/FIXLOG.md` | one memory per fix, type `issue`, with the `Rule:` line in the content |
| Architecture decisions | `docs/adr/NNNN-<title>.md` | one memory per decision, type `decision` |
| Architecture review | `docs/architecture-review-<date>.md` | one memory per card, type `observation`; the chosen one evolves into a `decision` |
| UX decisions (`UX:` blocks) | inside `docs/STORIES.md` | inside `docs/STORIES.md` (working file) |

In `muninn` mode:

- Write with `muninn_remember_batch` (several facts) or `muninn_remember`.
  Vault: the one on the skill's `Records:` line (`default` when unset).
- Every memory gets `summary`, `type`, `tags: ["bama", "<App>"]`,
  `entities` (always the app as a `project` entity, plus every API,
  framework, app, or person named), and `entity_relationships` that link
  them. The server extracts nothing on its own. Entity types must be one of
  MuninnDB's own (`project`, `technology`, `framework`, `tool`, `product`,
  `concept`, `person`, `organization`, ...); a platform such as tvOS is a
  `product`.
- Change a memory with `muninn_evolve`, not a delete and a new write.
- Read before writing: `muninn_recall` with the app's name and the topic.
  A skill that reads the brief, research, or fix log in `markdown` mode
  recalls them instead.
- If the MuninnDB tools are not in the session, Claude says so once, uses
  `markdown` for this run, and names the files it wrote.

## 9. Skill names

A skill calls another with "Call the Skill tool with `bama:<name>`". The
skills: `bama`, `app-brief`, `research`, `clone`, `user-stories`,
`new-app`, `swift-swiftui`, `os-integrations`, `performance`,
`improve-architecture`, `agent-cli`, `ux-design`, `mac-design`,
`platform-design`, `design-system`, `layout-grid`, `design-kit`,
`design-from-app`, `app-icon`, `build-and-verify`, `test-app`,
`improve-loop`.

## 10. Other skills in the session

When the session lists these skills, BAMA uses them for what they do best
instead of repeating them:

| Need | Skill, when present |
| --- | --- |
| Deep SwiftUI, concurrency, or SwiftData review | `swiftui-pro`, `swift-concurrency-pro`, `swiftdata-pro` |
| SwiftUI rendering performance from code | `swiftui-performance-audit` (BAMA's `performance` measures first) |
| tvOS focus flows | `tvos-focus-navigation` |
| Liquid Glass API details | `swiftui-liquid-glass` |
| An HTTP debug server for devices | `debug-server-architect` |
| Investigating an unfamiliar API before code | `research-first` |
| Module and seam vocabulary | `codebase-design` |
