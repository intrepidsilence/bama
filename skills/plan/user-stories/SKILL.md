---
name: user-stories
description: Prioritized backlog of user stories with checkable acceptance criteria and target platforms (docs/STORIES.md) for an Apple app, built from a brief, research, or screen index. Use after app-brief or clone, or when the user asks for user stories, a backlog, a feature list, or "what do we build first".
---

# User stories

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Screens show what an app looks like. Stories say what a person does with
it. Claude builds and tests stories, not screens.

Claude reads the brief and the research: in `markdown` mode
`docs/BRIEF.md` and `docs/research/*.md`; in `muninn` mode `muninn_recall`
with the app's name and "brief", then "research". It also reads
`docs/screens/INDEX.md` where it exists. It writes `docs/STORIES.md`, a
working file in both modes. The brief's target platforms and primary
platform shape everything below.

## Story format

```markdown
### S-012 Complete a task
As the user, I complete the selected task.
Platforms: macos, ios
Screens: macos/01-inbox.png, ios/01-inbox.png
Depends: S-004
Acceptance:
- [unit] A recurring task moves to its next date.
- [self] An "Undo" banner shows for five seconds.
- [snap] macos: Command-Return fills the circle and the row fades out within half a second.
- [snap] ios: A swipe from the leading edge completes it; the row fades out.
- [manual] ios: The swipe follows the finger on a device.
Status: todo
```

- One action per story. "Rename a project from its context menu", not
  "Manage projects".
- `Platforms:` lists the platform ids the story ships on, from the brief's
  targets. A story for every target says so explicitly, not "all".
- Every acceptance line starts with how it is checked: `[snap]` snapshot,
  `[unit]` unit test, `[self]` self-test, `[manual]` a person must try it.
  "Works well" is not checkable.
- A line with no platform holds on every platform in `Platforms:`. Where
  behavior differs (a shortcut on the Mac, a swipe on iPhone, focus on
  Apple TV, the Digital Crown on the watch), Claude writes one line per
  platform, prefixed `<platform>:` after the tag. Shared logic gets
  `[unit]` lines once, without a platform.
- `Screens:` links reference screenshots (path under `docs/screens/`), so
  `bama:improve-loop` knows what to compare. Without a reference app,
  Claude names the snapshot pages that will show the story, per platform.
  A panel, sheet, or menu needs its own snapshot page.
- `Depends:` (optional) lists stories that must be done first.
- A control and the only surface that shows it stay in one story: a
  highlighting field that lives only in the quick-add panel ships with the
  panel.
- Status: `todo`, `doing`, `done`, or `dropped`.

## Milestones

Each milestone ends with an app the user can use for a day.

1. **M1 Core loop**: the one thing the app is for, end to end, on the
   primary platform. Data survives a restart.
2. **M2 Organize**: the main structure, sidebar pages or tabs, moving items.
3. **M3 Time**: dates, Today and Upcoming, recurrence, reminders.
4. **M4 Speed**: quick-add, global shortcut, natural language input,
   keyboard navigation, search, menu commands.
5. **M5 System**: menu bar, widgets, Share, Shortcuts, notifications, CLI.
6. **M6 Polish**: drag and drop, context menus, empty states, icon, settings.

With more than one target, Claude stages platforms. The primary platform
goes first. Each other platform gets its own milestone once the core loop
works on the primary, holding only the stories the brief gives that
platform. Example: M1 to M3 on iPhone, M4 iPad (sidebar and columns), M5
Apple TV (browse and play), M6 System on all three. If the brief asks for
two platforms from the start, M1 lists both on its core stories.

Claude renames milestones to fit the app. Inside a milestone, stories that
others depend on come first. The step is done when every story sits in
one milestone and every target platform appears in at least one.

## Seed data

Every attribute the seed data sets (symbols, colors, notes) is something a
story lets the user create in the app, on at least one platform. Otherwise
snapshots show features no one can use.

## Leave things out

Claude drops what exists only for other people or for the vendor: accounts,
sharing, teams, integrations, upgrade prompts, gamification. They go under
`## Dropped`, one line each, so the decision is visible. The brief's
per-platform non-goals go there too, prefixed with the platform id.

## UX notes

For each M1 story that adds a screen, an action, or words, Claude calls the
Skill tool with `bama:ux-design`. It adds a `UX:` block under the
acceptance lines and starts the glossary, so every story uses the same
names. Later milestones get their UX notes in `bama:improve-loop`, just
before they are built.

## Size check

M1 has 5 to 10 stories. Over 60 stories in total means version one is too
big: Claude moves stories to `## Later`. A platform milestone over 15
stories usually copies the primary instead of fitting the device: Claude
cuts it back to the jobs in the brief.

Done when every main job in the brief, every "Version one: yes" row in the
research matrix, and every screen in the index maps to a story or a
`Dropped` line, every story has a `Platforms:` line, every target platform
has a milestone, and every M1 story with UI has a `UX:` block.
