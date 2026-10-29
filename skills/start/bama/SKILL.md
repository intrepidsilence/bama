---
name: bama
description: Build any Apple app. Start here to pick the next skill for a native app on macOS, iPhone, iPad, Apple TV, Apple Watch, or Apple Vision Pro.
disable-model-invocation: true
---

# Build any Apple app

Claude finds where the user is on the path below, then calls the Skill tool
with the skill for that step. One skill per call. Every skill follows
[CONVENTIONS.md](../../../CONVENTIONS.md).

```text
idea -> research -> clone (optional) -> app-brief -> user-stories -> new-app
     -> mac-design / platform-design + design-system + app-icon
     -> improve-loop (ux, code, design, verify, commit) -> repeat
```

## 1. Name the app

Claude picks the app's name first (`bama:app-brief`, step 1) and creates
`<parent>/<AppName>/docs/` before research, so every skill writes into the
same folder. The step is done when the folder exists.

## 2. Which platforms

Claude learns the target platforms before it picks a design or build
skill: `macos`, `ios`, `ipados`, `tvos`, `watchos`, `visionos`
(CONVENTIONS section 2).

- If `docs/BRIEF.md` (or the brief in MuninnDB) names them, Claude uses that list.
- Otherwise Claude asks the user which devices the app is for, and which
  one matters most. `bama:app-brief` records the answer with a reason.

What follows from the list:

| Targets | Then |
| --- | --- |
| macOS only | `bama:new-app` uses the Swift package template. Design with `bama:mac-design`. |
| Any other platform, alone or with macOS | `bama:new-app` uses the multi-platform template (XcodeGen, a shared `<App>Kit` package, one app target per platform). Design with `bama:platform-design`, plus `bama:mac-design` for the Mac target. |

The step is done when Claude can name every target and the primary one.

## 3. Route

### Plan

| The user has | Skill |
| --- | --- |
| A vague idea, or asks "what should I build" | `bama:research`, then `bama:app-brief` |
| An app they want to replace or rebuild | `bama:clone` |
| A brief or a screen index, no backlog | `bama:user-stories` |
| A spec from BAMA's `specs/` folder | `bama:app-brief` (it copies the spec) |

### Build

| The user wants to | Skill |
| --- | --- |
| Start a new project, or add a platform to one | `bama:new-app` |
| Write or fix Swift and SwiftUI code | `bama:swift-swiftui` |
| Hook into the system: hotkeys, menu bar, widgets, Shortcuts, screen capture | `bama:os-integrations` |
| Make it fast: hangs, stutter, GPU, video, memory | `bama:performance` |
| Let Claude Code, Codex, or scripts drive the app: a CLI, an MCP server | `bama:agent-cli` |
| Refactor, clean up, or check the code as it grows | `bama:improve-architecture` |

### Design

| The user wants to | Skill |
| --- | --- |
| Decide how a feature works and what it says: names, flow, modals, accessibility | `bama:ux-design` |
| Make it look and feel like a Mac app | `bama:mac-design` |
| Make it fit iPhone, iPad, Apple TV, Apple Watch, or Vision Pro | `bama:platform-design` |
| An accent or brand color, a color picker, tokens | `bama:design-system` |
| Their own parts and feel, not Apple's: buttons, rows, sidebar, icons | `bama:design-kit` |
| The look of an app they name, or screenshots of one | `bama:design-from-app` |
| One set of colors, radii, motion, and controls for the whole app | `bama:design-system` |
| Fix spacing and alignment, or check the layout on the grid | `bama:layout-grid` |
| An app icon | `bama:app-icon` |

### Ship

| The user wants to | Skill |
| --- | --- |
| Build it and look at every page on every target | `bama:build-and-verify` |
| Tests, a self-test, or an agent that drives the running app | `bama:test-app` |
| Work through the backlog on its own | `bama:improve-loop` |
| See or clean up what the project put outside its folder | `tools/footprint.sh`, then `tools/footprint.sh clean` (CONVENTIONS section 4) |

## Done when

Claude named the step and the target platforms, called the step's skill,
and told the user which skill comes after it.
