---
name: app-brief
description: One-page brief for a new Apple app (docs/BRIEF.md or MuninnDB), written before any code, naming its target platforms. Use when the user has an app idea, wants to replace an app they pay for, or the research and clone skills are done.
argument-hint: "[idea in a few words]"
---

# App brief

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Claude writes the brief for a folder named after the app
(`<parent>/<AppName>/`; Claude asks for the parent folder, default
`~/Developer`). Every later skill reads it. It fits on one page.

- `markdown`: the brief is `docs/BRIEF.md`.
- `muninn`: the brief is one memory per section (idea, users, targets,
  scope, non-goals), type `goal` or `decision`, with the rules in
  CONVENTIONS section 8. `docs/` still exists for the working files.

## 1. Name and read what exists

Claude picks the name first: one UpperCamelCase word (`Tasks`, `DailyLog`),
not the name of an app already in `~/Applications`, and a bundle id
`com.<developer>.<appname>` in lowercase. The folder, the research, and the
scaffold all use it. The step is done when `<parent>/<AppName>/docs/` exists.

Claude reads the research and the screen index first: `docs/research/`
(or `muninn_recall` with the app's name in `muninn` mode) and
`docs/screens/INDEX.md`. It skips every question they already answer.

If the user gives a spec from BAMA's `specs/` folder (a file or a link), it
already holds the brief and the stories. Claude copies its **Brief** block
to the brief and its **Stories** block to `docs/STORIES.md`, and keeps the
rest of the spec as `docs/SPEC.md`, so later skills read its **How it
works** and **Gotchas**. Specs were written for the Mac: Claude asks which
platforms the user wants and what they want to change, then calls the
Skill tool with `bama:new-app`.

## 2. Interview

Claude asks a few questions at a time. If the user asked Claude to decide
everything, Claude answers each question from the research, writes the
choice in the brief, and notes "decided by Claude" next to it.

1. What does the user do today, and which app or habit does it replace?
2. Which devices is it for, and which one matters most? Why that one?
   For each device: what does the user do there that they do not do on
   the others? See [platforms.md](platforms.md) for what each platform's
   version is good at.
3. What are the three things the user does most often? These become the
   main pages.
4. What data does it hold? Name the nouns: tasks, notes, recipes, invoices.
5. Is there a reference app the user likes? Then `bama:clone` comes next.
6. Where does it live on each device: a window with a sidebar, a menu bar
   item, a tab bar, a widget, a complication, a full-screen TV page, a
   window or a space on Vision Pro, or a mix?
7. Does it need the internet? Default: no. Data on more than one device
   needs sync: note iCloud (CloudKit) or "later: sync".
8. Which three things are out of scope for version one, overall and per
   platform?
9. Should it look like a built-in Apple app, or have its own look? Note a
   brand or accent color, and any app the user names ("like Things"):
   `bama:design-from-app` rebuilds its look. No answer means native with
   the system accent color.

The step is done when every question has an answer from the user, the
research, or Claude.

## 3. Cut scope

A personal app has one user. Claude removes what exists only for other
users: accounts, sharing, teams, sync servers, billing, onboarding,
analytics.

Version one is one afternoon of agent time on the primary platform: two to
five main pages, one data model with two to four types. Smart lists that
filter one model (Today, Upcoming, Someday) count as one page. Each other
platform gets only the jobs that fit it (see [platforms.md](platforms.md)),
not a copy of every page. The step is done when every platform's job list
is shorter than or equal to the primary's.

## 4. Write the brief

In `markdown` mode, `docs/BRIEF.md`:

```markdown
# <AppName>

One sentence: what it is and who it is for.

## Replaces
<app or habit>

## Platforms
Primary: <platform id>, because <reason>.
Targets: <ids, e.g. ios, ipados, macos>, minimum OS 26 on each.
- ios: <what the user does here; where it lives (tab bar, widget)>
- macos: <...>
- watchos: <the one or two glanceable jobs, not the phone app shrunk>

## Main jobs
1. ...
2. ...
3. ...

## Data
- <Type>: <fields>
Storage: local. Sync: <none / iCloud / later>. Works offline. No accounts.

## System hooks
<per platform: global shortcut, menu bar, widgets, complications, Share,
Shortcuts, Top Shelf, CLI, or "none">

## Reference
<app name and the platforms it was captured on, or "none">

## Look
<native with an accent color (name it, or "system"), own parts, or "like <app>", and why>

## Not in version one
- ...
- tvos: <platform-specific non-goal, e.g. "no text entry beyond search">
```

In `muninn` mode, the same content goes in five memories: idea (the
sentence, Replaces, Main jobs, Data), users, targets (the Platforms
section, System hooks, Look), scope (the cut), and non-goals. Each memory
gets the platform ids as entities with type `product` (MuninnDB has no platform type; any other type is stored as `other`), linked to the app.

The step is done when the brief has every section, a primary platform with
a reason, one line per target, and at least one non-goal for each target
that is not primary.

## 5. Hand off

Claude calls the Skill tool with `bama:user-stories`, or with `bama:new-app`
if the user wants to see a window first. Claude tells the user where the
brief is (the file, or "in MuninnDB, vault <vault>").

Done when the brief exists (file or memories), fits on one page, has every
section, and names the target platforms, the primary one, and why.
