---
name: research
description: Online research for an Apple app before building it, run as parallel researcher subagents, saved to docs/research/ or MuninnDB. Use when the user asks what to build, which features matter, how the best apps in a category work on Mac, iPhone, iPad, Apple TV, Apple Watch, or Vision Pro, how an Apple API or integration works, or wants a feature comparison.
argument-hint: "<app category or question>"
---

# Research

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Research answers three questions before code exists: what the best apps in
the category do, what users love and hate about them, and how each target
platform lets Claude build it. The output feeds `bama:app-brief` and
`bama:user-stories`.

## 1. Frame

Claude writes the question in one line, and the decision it informs
("which features go in version one", "Carbon hotkeys or an event tap",
"does the watch app need the phone"). If the user gave only a category, the
question is "what makes the best <category> app on <platforms>".

Claude reads what exists first: the brief (`docs/BRIEF.md`, or
`muninn_recall` with the app's name in `muninn` mode) and earlier research.
The brief's target platforms set the scope. With no brief yet, the targets
are the ones the user named, else "all platforms the leaders ship on", and
the Market track reports which those are.

The step is done when the question, the decision, and the target platforms
are written down.

## 2. Fan out

Claude starts one subagent per track, in parallel, with the brief below. It
picks the tracks that fit. Four is typical. Market and Reviews always run.
Reviews covers many apps: each subagent gets 3 or 4 apps, or the 600 words
run out. Platform runs once per target platform when there are three or
more targets.

| Track | Finds |
| --- | --- |
| Market | The 5 to 8 best apps in the category, their price, which platforms each ships on (Mac, iPhone, iPad, Apple TV, Apple Watch, Vision Pro, web), and headline features per platform |
| Reviews | Per app: what people like and dislike, from App Store reviews on each platform, Mac App Store reviews, Reddit, Hacker News, forums, and "switched from X" posts. Complaints about one platform's version ("the watch app is useless") count. |
| Features | The full feature list of the 2 or 3 leaders, per platform, from docs, changelogs, and help pages |
| Design | Screens, interaction details, and shortcuts or gestures of the leaders on each target platform |
| Platform | For each target platform: the APIs, permissions, entitlements, and limits each feature needs, and what other apps on this Mac already use (global shortcuts, URL schemes, bundle ids). Checklist: [platforms.md](platforms.md) |

Subagent brief (Claude fills in the brackets):

```text
Research [track] for a native Apple app for [target platforms] that
[one-line idea].
Question: [the question]. Decision it informs: [decision].
Search the web. Prefer primary sources: official docs, changelogs, Apple
developer docs, WWDC sessions, the app's own help pages. Use reviews and
forums for opinions only. If a source is blocked, say so and use another
(Hacker News, App Store reviews, Apple developer forums). Do not write
any files.
Tag every claim: [V] verified in a source (give the URL), [K] from the model's
own knowledge, [U] unverified, must be tested. Name the platform a claim
applies to when it is not all of them.
Return at most 600 words: a findings list, a table where it helps, and
the 3 things that matter most for the decision. No intro, no summary.
```

The step is done when every track returned.

## 3. Merge

`markdown` mode: one file per question, `docs/research/<topic>.md`.

```markdown
# <Topic>

Research for <AppName>. Done <YYYY-MM-DD>. Targets: <platform ids>.
[V] verified in a source, [K] from knowledge, [U] unverified, test first.

## Findings
- ... [V](url)
- watchos: ... [V](url)

## Likes and dislikes
| App | Platforms | People like | People dislike | Sources |
| --- | --- | --- | --- | --- |
| App A | macos, ios | <3 to 5 points, most mentioned first> | <3 to 5 points> | <urls> |

Patterns: <likes that repeat across apps (must have), dislikes that repeat
(our chance to do better), and which platform versions people skip>

## Feature matrix
| Feature | App A | App B | App C | Version one? | Platforms |

## Decisions
1. <decision>, because <finding>. Planned test: <test, for a [U] finding>.

## Open questions
- <[U] claim and how to test it>
```

`muninn` mode: one memory per finding, type `fact` (`[V]`) or `observation`
(`[K]`, `[U]`, likes and dislikes), with the tag `[V]`/`[K]`/`[U]` and the
source URL in the content, the platform ids as entities, and the rules in
CONVENTIONS section 8. The feature matrix and the decisions are one memory
each (type `reference` and `decision`), so `bama:user-stories` can recall
the "Version one?" and "Platforms" columns.

Rules for both modes:

- Keep the feature matrix: `bama:user-stories` turns its "Version one?"
  column into stories and its "Platforms" column into each story's
  `Platforms:` line.
- Every "People like" point maps to a decision or to an "accepted gap" line
  in the brief, so nothing loved is dropped by accident.
- Check whether a system store gives sync and capture on other devices for
  free (EventKit for reminders and calendars, CloudKit, HealthKit).
- Turn each `[U]` that a decision depends on into a test before trusting it
  (a probe script, a self-test step, or a preview field in the reference
  app).

The step is done when the file or the memories hold the likes and
dislikes for every market app, the feature matrix, and the decisions.

## 4. Hand off

Claude calls the Skill tool with `bama:clone` if one app stands out as the
reference and Claude or the user can open it. If it is not available on a
device Claude or the user has, Claude links its public help pages,
screenshots, and App Store pages in the research instead. Then Claude
calls the Skill tool with `bama:app-brief`.

Done when every track returned, the research has a likes and dislikes
table for every app in the market list, a feature matrix with a Platforms
column, and a decision list, every target platform has Platform findings,
and every decision cites a `[V]` or a planned test.
