---
name: improve-architecture
description: Architecture check-in for a growing Apple platform Swift codebase, Mac-only or multi-platform. Finds hot spots, proposes deeper modules, and refactors one step per commit with behavior proven unchanged on every target. Use at the end of a milestone, before a big feature, when a file passes 600 lines, when one feature touches many files or targets, when `#if os` blocks spread, when bugs repeat in one area, or when the user asks to refactor or clean up the code.
---

# Improve architecture

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Features pile up, and an app that was easy to change gets hard to change.
A **check-in** catches that early: survey, propose, let the user pick, then
refactor in small steps that keep behavior the same. The target shape for
apps that grow, Mac-only and multi-platform, is in
[architecture.md](architecture.md).

## When to run

Any one signal is enough:

- The end of a milestone (`bama:improve-loop` calls this skill there).
- Before a big feature. Ask: "What change to the code would make this
  feature easy?"
- A Swift file over 600 lines (act at 1,000), a type over 400 lines, or
  "unable to type-check this expression".
- One feature touched more than 6 files or more than 2 targets.
- The same area shows up in 3 fix-log entries, or the same kind of bug
  happens twice.
- State that changes more than 10 times a second sits on a model that many
  views observe.
- A dependency cannot be replaced in a test.
- Multi-platform: one file holds more than 3 `#if os(...)` blocks, the same
  view exists once per platform with small differences, or a size or
  behavior written for one platform shows up on another.

## Vocabulary

These words match the `codebase-design` skill. When the session lists that
skill, Claude calls it for the deeper treatment of modules and seams. Use
these words exactly, so proposals stay comparable:

- **Module**: anything with an interface and an implementation (a type, a
  file group, a target, a package).
- **Interface**: everything a caller must know: signatures, ordering,
  error modes, threading, performance, and which platforms it exists on.
- **Depth**: how much a module does per unit of interface. Deep modules hide
  a lot behind a small interface. Shallow modules are pass-throughs.
- **Seam**: a place where behavior can be swapped without editing callers.
  A platform difference is a seam too: one interface, one adapter per
  platform.
- **Adapter**: one implementation behind a seam. One adapter is a
  hypothetical seam. Two (production and test, or macOS and iOS) make it
  real.
- **Locality**: a change touches one place. **Leverage**: callers get a lot
  for little.

## 1. Survey

Claude changes no code in this step.

1. Read `CLAUDE.md` and `ARCHITECTURE.md` where they exist. Read the
   decisions and the fix log:
   - `markdown`: `docs/adr/` and `docs/FIXLOG.md`.
   - `muninn`: `muninn_recall` with the app's name and "architecture
     decision", then with the app's name and "fix log".
2. Learn the shape. A Mac-only app is one Swift package (`Package.swift`,
   `Sources/`). A multi-platform app has `project.yml` (XcodeGen), a shared
   `<App>Kit` package, and one app folder per platform. Read the target
   platforms from the brief.
3. Find hot spots. Run from the repo root, so the Kit package and every
   app folder are included:

   ```bash
   git log --since=30.days --name-only --format= -- '*.swift' | sort | uniq -c | sort -rn | head -20
   git ls-files '*.swift' | xargs wc -l | sort -n | tail -20
   git grep -c '#if os(' -- '*.swift' | sort -t: -k2 -n | tail -10
   ```

4. Map the structure: targets and packages and their dependencies, which
   files each platform target compiles, protocols and their conformers,
   `@MainActor` types that do I/O, and what runs on which queue.
5. Look for Swift friction:
   - A view model that owns everything (a god model).
   - Wrappers that only forward calls.
   - App code that reaches into a library's internals.
   - Test hooks in the app target.
   - Fast-changing state published to every view.
   - Slow work on the main thread or a real-time queue.
   - Protocols with one conformer and no test adapter.
   - Drifted copies: the same `private struct <Name>` defined in two files
     (`git grep -h 'private struct' -- '*.swift' | awk '{print $3}' | sort | uniq -d`).
   - A settings or detail page that lives far from its feature. Pages live
     in the feature's folder.
   - Pure logic inside a `@MainActor` store, which tests cannot compile
     alone. Move it into a plain type in the Kit that takes plain values.
6. Look for multi-platform friction:
   - **`#if os` sprawl**: platform checks scattered through one view or
     model. Each is a seam with no name. The fix is one interface with one
     adapter per platform, or a value from the platform helper.
   - **Platform values leaking across targets**: a size, padding, font, or
     behavior tuned for one platform sitting in shared code with no
     platform check (a tvOS card size used on the Mac, a Mac hover effect
     on iOS). Find numbers in shared views that do not go through
     `Platform.value(...)`.
   - **Per-platform duplication**: the same screen written once per app
     folder, drifting apart. Shared structure goes in the Kit or a shared
     view; only the parts that truly differ stay per platform.
   - **Logic in an app target** that another platform also needs. It
     belongs in the Kit, where one test run covers every platform.
   - **The Kit importing a UI framework** (SwiftUI, UIKit, AppKit) for
     logic that needs none.
7. **Deletion test** for each candidate: if this module were deleted,
   would its complexity concentrate in one place (keep it) or spread to
   every caller (it earns its place)? Pass-throughs fail the test.

Done with this step when every signal from "When to run" was checked and
each candidate has a deletion-test result.

## 2. Propose

Claude writes one card per candidate:

```markdown
## <Title in domain nouns>  [Strong | Worth exploring | Speculative]

Files: TasksKit/Sources/TasksKit/EditorModel.swift (1,750 lines), ...
Platforms: <which targets compile these files>
Signal: <which trigger above>
Problem: <what is hard to change today, with one example>
Proposal: <the new module and its interface, 15 lines of Swift at most>
Benefits: <locality and leverage; which tests get simpler>
Proof of same behavior: <tests, golden files, snapshots on every platform, perf baseline>
Plan: <one commit per step>
```

End with a **top recommendation** and a short "considered, not
recommended" list. "The code is fine" is a valid result: then every card is
`Speculative` or there are none.

Where the cards go:

- `markdown`: `docs/architecture-review-<YYYY-MM-DD>.md`.
- `muninn`: one memory per card, type `observation`, `tags: ["bama",
  "<App>", "architecture-review"]`, the app as a `project` entity plus each
  module and framework named, and `entity_relationships` that link them.
  One more memory holds the top recommendation and the "considered" list.

Then Claude stops and asks the user which candidate to do. In an
unattended loop, Claude does the top recommendation only if it is
`Strong`, and leaves the rest recorded for the user.

Done with this step when the cards are recorded and the user picked one
(or, unattended, the top card is `Strong` or the loop moves on).

## 3. Refactor

Claude refactors only the candidate the user picked (or the unattended
`Strong` one).

- **Before:** record the proof: tests at the interface, golden outputs
  (file bytes or hashes, old files that must still load), snapshot PNGs on
  every target the files compile into (`tools/snap.sh --platform <id>`,
  copied to `.work/compare/before/<platform>/`), and a performance baseline
  where speed matters.
- One refactor per commit. Behavior stays the same. No features mixed in.
- New types go in new files that compile first. Then move callers over.
  The project builds after every step, on every target that compiles the
  changed files (`./build.sh --platform <id>` for each). In an XcodeGen
  project, run `xcodegen generate` after adding a file.
- Replacing an engine: keep the old path behind a flag for one milestone,
  then delete it.
- Replace tests, do not layer them: delete the old shallow tests that the
  new interface tests cover.
- If a diff passes about 10 files, split it.
- If the interface is open, design it twice: sketch two or three
  interfaces under different constraints (fewest entry points, simplest
  common caller, ports and adapters, one adapter per platform) and pick one
  with a reason.

**Commits.** Each step is its own commit, made only after the user picked
the candidate (or unattended, for the `Strong` one). Claude stages named
paths (`git add <paths>`, never `git add -A`), writes a message that says
what changed for the reader of the code, adds the session's attribution
lines when it gives them, and never pushes.

**After:** the same tests pass, golden outputs match, and the snapshots on
every target match the "before" set (`magick compare -metric AE -fuzz 8%`
into `.work/compare/`, zero changed pixels on static pages).

Done with this step when every step is committed and the proof gives the
same results before and after on every target.

## 4. Record

- Update `ARCHITECTURE.md` (a working file in both modes): targets and
  packages, which platform compiles what, layers, dependency direction,
  seams, and the platform helper.
- Add an architecture decision only when it is hard to reverse, surprising
  without context, and a real trade-off:
  - `markdown`: `docs/adr/NNNN-<title>.md`.
  - `muninn`: one memory, type `decision`. The chosen review card evolves
    into it with `muninn_evolve`.
- Record any bug the refactor found in the fix log, ending with a
  `Rule:` line:
  - `markdown`: an entry in `docs/FIXLOG.md`.
  - `muninn`: one memory, type `issue`, with the `Rule:` line in the
    content.

Every MuninnDB memory carries `summary`, `type`, `tags`, `entities`, and
`entity_relationships` (CONVENTIONS.md, section 8). If the MuninnDB tools
are not in the session, Claude says so once and writes the `markdown`
files instead.

## 5. Report

Claude tells the user what got easier to change, in plain words, which
candidate was done, which platforms were checked and how, where the cards
and decisions were recorded, the commits made (none pushed), and the
`tools/footprint.sh` lines. Snapshot runs shut their simulators down;
nothing else stays running.

Done when the review cards are recorded, the chosen refactor is committed
in steps, the proof gives the same results before and after on every
target, `ARCHITECTURE.md` matches the code, and the user has the report.
