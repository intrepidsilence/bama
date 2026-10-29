---
name: improve-loop
description: Autonomous loop that works through docs/STORIES.md one story at a time for an Apple platform app, building and snapshotting each platform the story names, comparing against reference screenshots, fixing, and committing, until a milestone is done. Use when the user says "keep going", "work through the backlog", "make it match the reference", or wants an unattended improvement loop.
argument-hint: "[milestone, e.g. M1]"
---

# Improve loop

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Claude follows [CONVENTIONS.md](../../../CONVENTIONS.md) for platforms
(section 2), `.work/` (3), the footprint (4), simulators (5), what may stay
running (6), and git (7).

One pass through the loop takes one story from `todo` to `done`:

```text
pick story -> plan -> code -> build each platform -> snapshot -> compare -> fix -> commit -> update STORIES.md
```

Stop after the milestone the user named, or after the current milestone if
they named none. Then report.

## 0. Start

1. `git status --short` is empty, or holds only files the user named as
   part of this work. Otherwise Claude stops and asks.
2. If the repo is on its default branch (`main` or `master`), Claude
   creates and switches to `bama/<milestone>` (for example `bama/m2`)
   first. Starting the loop is the user's permission for one commit per
   story on that branch.
3. Claude reads the target platforms from the brief: `docs/BRIEF.md` in
   `markdown` mode, `muninn_recall` with the app's name and "targets" in
   `muninn` mode.
4. Claude counts the milestone's `todo` stories (N) and says the plan in
   one line: "M2: 6 stories, platforms macos and ios, about 15 minutes per
   story."

Done with this step when the tree is clean, the branch is not the default
branch, and the plan line is out.

## 1. Pick

Open `docs/STORIES.md`. Take the first `todo` story in the current
milestone whose dependencies are `done`. Set it to `doing`. Print a progress
line: `[3/6] M2-03 Complete tasks with Command-Return (macos, ios)`.

The story's `Platforms:` line (for example `Platforms: ios, tvos`) names
exactly the targets this pass builds and snapshots. A story with no
`Platforms:` line is a gap in `docs/STORIES.md`: Claude fills it with every
target in the brief and notes that in the report.

Acceptance lines carry their check and, when they differ per platform,
their platform:

```markdown
- [unit] A title of only spaces is rejected.
- [snap] tvos: The focused card shows its full title.
- [snap] ios: The toolbar has an Add button.
```

`[unit]` lines are shared logic, proven once in the Kit tests. A `[snap]`
line with a platform prefix is checked only on that platform's snapshots;
one with no prefix, on every platform in `Platforms:`.

## 2. Plan

If the story adds a screen, an action, or words and has no `UX:` block
yet, call the Skill tool with `bama:ux-design` first.

Write two to five lines in the commit body: which files change, which model
fields are new, which command and shortcut it adds, which snapshot page
shows it, and for each platform in `Platforms:` where the control lives (a
Mac menu item and shortcut, an iOS toolbar button, a tvOS focusable
button). If the story needs a new SwiftData field, give it a default value
so existing databases keep loading.

## 3. Code

Follow `bama:swift-swiftui`, the design skill for each platform
(`bama:mac-design` for macOS, `bama:platform-design` for the others), the
story's `UX:` block, and `design/DESIGN-SYSTEM.md` if the app has one.
System hooks follow `bama:os-integrations`. Keep each view file under about
300 lines. Put new pages in the page enum (`SidebarItem` in the template)
so snapshot mode visits them.

Logic goes in the `<App>Kit` package, shared by every target. A value that
differs per platform goes through the platform helper or an `#if os(...)`
block, never a number written for one platform in shared code.

## 4. Build and snapshot

Follow `bama:build-and-verify` for each platform in the story's
`Platforms:` line:

```bash
./build.sh --platform <id> --debug
tools/snap.sh --platform <id>
```

Only the story's platforms are built and snapshotted. One guard from
CONVENTIONS.md, section 2: when the story changed shared code (the Kit or a
shared view), Claude also runs `./build.sh --platform <id> --debug` for the
brief's other targets, build only, so a break on another platform shows in
this story and not three stories later.

If the story has logic, add a test or a self-test step (`bama:test-app`)
and run `tools/selftest.sh --platform <id>`. Use seed data (`APP_SEED=1`)
so pages show real content.

**Watchdog.** A build or snapshot run prints a line at least every minute
(`... still building ios, 3 min`). A step that prints nothing for 5 minutes,
or runs longer than 15, is stuck: Claude stops it, says so in a progress
line, reads the last lines of its log (`.work/logs/build-<platform>.log`,
or the script's own output for a snapshot run), and treats it as a failed round
(section 5).

## 5. Compare

Open each platform's snapshot and the story's reference screenshot side by
side with the Read tool. The story's `Screens:` line names the reference:
`docs/screens/<NN>-<page>.png` in a single-platform app,
`docs/screens/<platform>/<NN>-<page>.png` when the app has several. A
platform with no reference of its own compares against the story's
acceptance lines and that platform's design skill. Write down the differences that matter, in this
order:

1. Missing or wrong behavior from the acceptance criteria.
2. Words and flow: names, surface, and states that differ from the `UX:`
   block or the glossary (`docs/GLOSSARY.md`, or `muninn_recall` in
   `muninn` mode).
3. Layout: wrong column, wrong order, missing element, and every FAIL from
   the grid checks.
4. Platform fit: the control sits where that platform's users look for it.
   On tvOS, a focused item at a row's edge is not cut off.
5. Hierarchy: what is biggest, boldest, first.
6. Spacing and alignment.
7. Color and details.

The goal is the same structure and behavior, built from Apple's own
controls. It is not a pixel copy. When the reference uses a web-style
custom control and the platform has a native one (a toolbar, a sidebar, a
context menu, a date picker, a tab bar), use the native one. A reference
taken on one platform guides the structure on the others; it does not set
their sizes.

No reference screenshot (no app was cloned)? Compare against the story's
acceptance lines and the platform's design skill instead.

Snapshot only the pages a story touches (`APP_SNAPSHOT_PAGES`), and the
full set on every target at the end of each milestone. Comparison images
go in `.work/compare/`.

Fix, rebuild, and compare again. Three rounds per story at most. If it still
does not match, set the story to `todo` again with a note that says what is
blocking, print `[3/6] M2-03 blocked: <reason>`, and move on.

## 6. Commit and record

Stage the files the story changed, by name, with the story file:

```bash
git status --short
git add Sources/Tasks/TaskList.swift Sources/Tasks/Commands.swift docs/STORIES.md
git commit -m "Complete tasks with Command-Return"
```

Claude never uses `git add -A` or `git add .`: they would pick up `.work/`
leftovers and stray files. Before committing, `git status --short` shows
nothing unexpected staged. Set the story to `done` in `docs/STORIES.md` and
commit that with the code. When the session gives commit attribution
lines, Claude adds them. Claude never pushes.

One story per commit, so any story can be reverted on its own. M1 may land
as one commit when its stories share one skeleton (model, pages, list,
persistence); from M2 on, one story per commit.

Print `[3/6] M2-03 done (<short hash>)`.

### Fix log

When a story fixes a bug, Claude records it: symptom, cause, fix, and a
last line `Rule: <what to always or never do>`.

- `markdown`: add an entry to `docs/FIXLOG.md` and commit it with the fix.
- `muninn`: one memory, type `issue`, with the `Rule:` line in the content,
  `tags: ["bama", "<App>"]`, the app as a `project` entity plus every API
  named, and `entity_relationships` that link them.

The fix log outlives squashed history, and the milestone check-in reads it.

## Milestone check-in

When the last story of a milestone is `done`:

1. Snapshot every page on every target in the brief and look at each.
2. Call the Skill tool with `bama:improve-architecture`. Unattended, it
   does its top recommendation only if it is `Strong` and leaves the rest
   for the user.

Done with the check-in when the full snapshot set exists for every target
and the architecture review is recorded.

## 7. Report

At the end of the loop:

1. Stop everything the loop started: test copies, simulators other than the
   one left open, log streams.
2. Leave the new build open for the user: `./build.sh --open` for macOS,
   or `tools/snap.sh --platform <id> --open` for the main other target.
3. Run `tools/footprint.sh`.

Then report to the user:

- What the user can now do, one line per done story, with the snapshot
  paths that show it and the platforms checked.
- Stories blocked, and why.
- Anything to try by hand: shortcuts, drag and drop, the iOS back swipe on
  a device, tvOS focus with the real remote.
- What Claude left open (the Mac app, or the named simulator with the app
  launched).
- The branch name and the commits, and that nothing was pushed.
- The `tools/footprint.sh` lines.
- The next story in line.

## Running it unattended

The loop works with no one watching, because every step checks itself:
the build, the snapshots, the self-test, the acceptance criteria. To let it
run longer, the user starts it with a clear limit ("finish M2, then stop")
on a committed tree. It never touches the user's real data. Each story is a
separate commit on the `bama/<milestone>` branch, so the user can review
the history in the morning and revert anything they do not like.

Done when every story in the milestone is `done` or named in the report as
blocked with a reason, each done story has its own commit on a non-default
branch, the fix log has an entry for each bug fixed, the app is left open
as named, and the user has the report with the footprint lines.
