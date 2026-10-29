---
name: clone
description: Walk through any existing app (Mac app or iPhone app with computer use, web app with a browser, iPad, Apple TV, Apple Watch, or Vision Pro app from the user's screenshots), capture every screen, menu, and dialog, write a screen index, and turn it into user stories. Use when the user wants to clone, rebuild, replace, or copy the design of an app, or says "screenshot every screen".
argument-hint: "<app name as shown in the menu bar, or a URL>"
---

# Clone

Output: a folder of screenshots, one index that describes everything the
app shows, and a backlog built from it. Both are working files
(CONVENTIONS section 8).

```text
docs/screens/
  INDEX.md
  01-inbox.png            (one platform: files at the top)
  ios/01-inbox.png        (several platforms: one folder per platform id)
  ...
docs/STORIES.md           (from bama:user-stories)
```

## 1. Pick the capture method per platform

Claude asks the user which platforms of the reference app to capture
(normally the brief's targets), then picks a method for each:

| The app runs on | Claude captures with |
| --- | --- |
| Mac (native or Electron) | Computer use, and `scripts/window-shot.sh` |
| iPhone | Computer use on the iPhone Mirroring app, and `scripts/window-shot.sh "iPhone Mirroring"` |
| Web | A browser tool: the built-in browser, Claude in Chrome, or Playwright |
| iPad | The user's screenshots, or the iPad build on an Apple silicon Mac if one exists |
| Apple TV, Apple Watch, Vision Pro | The user's screenshots. Claude cannot drive these. |

Setup, limits, and the exact steps for the user are in
[capture.md](capture.md). Computer use needs a one-time setup there. The
step is done when every platform has a method and its setup works (one
test capture saved).

## 2. Agree on privacy

Claude tells the user it will see everything in the app. It suggests a demo
account or sample data. Claude looks and does not touch: it opens screens
and menus, and presses Escape (or Back) to close dialogs. It types, creates,
changes, or deletes only when the user says so. The step is done when the
user agreed.

## 3. Save real files

Computer use screenshots come to Claude downscaled, not to disk. Claude
saves each screen at full resolution with the script in this skill:

```bash
"${CLAUDE_SKILL_DIR}/scripts/window-shot.sh" "<App Name>" docs/screens/01-inbox.png
"${CLAUDE_SKILL_DIR}/scripts/window-shot.sh" "iPhone Mirroring" docs/screens/ios/01-inbox.png
```

It captures the app's largest window. For menus and popovers outside the
window, Claude uses `screencapture -x docs/screens/<name>.png` and notes it
in the index. In a browser, it uses the tool's screenshot with a file path.
Screenshots from the user go into `docs/screens/<platform>/`, renamed to
the walk order. The step is done when each capture is a non-empty PNG in
`docs/screens/`.

## 4. Walk the app in this order

1. Main window or first screen, default page.
2. Every sidebar item, tab, or top-level row, in order. Expand collapsed
   groups.
3. Every view mode (list, board, calendar), sort menu, filter menu.
4. One item opened in detail: panel, fields, sub-items.
5. Creation flows: add button, quick-add panel (global shortcut), inline
   editor. Empty and half filled in, then Escape or Cancel.
6. Context menus on an item, a section, a sidebar entry (long press on
   touch platforms).
7. Mac: the menu bar, every menu once, every item and shortcut. Other
   platforms: toolbars, swipe actions, and the Share sheet.
8. Settings: every pane.
9. Empty states.
10. Dark mode: the two or three main pages again.
11. System surfaces the app adds: widgets, complications, Top Shelf,
    notifications, menu bar item.

Claude names files `NN-page-or-state.png` in capture order. For a platform
the user captures, Claude gives the user this list, filled in with the
app's real page names. The walk is exhaustive when every sidebar item or
tab, menu, and settings pane has a file on each captured platform.

## Lessons from real walkthroughs

- Many "Mac apps" are Electron. Their menu bars are nearly empty, and the
  actions hide in hover toolbars, right-click menus, and command palettes.
  Claude hovers rows and searches the palettes (typing in a palette search
  is safe; Claude does not press Return).
- Background clicks (`app_*` tools) fail on some Electron screens. Then
  Claude asks for full-screen control, and tells the user to keep off the
  mouse.
- Preview fields test behavior without saving. A "Type a date" box in a
  to-do app shows how it parses a phrase before anything is stored. 30
  phrases there corrected 3 answers from the docs.
- Claude notes any change in the user's data during the walk, even if it
  is not sure it caused it, and tells the user.

## 5. Write docs/screens/INDEX.md

One section per screenshot, named by its path under `docs/screens/`:

```markdown
## ios/03-upcoming.png

Platform: ios. Page: Upcoming. Reached from: tab bar > Upcoming.
Layout: header with month picker and "Today" button; week strip; tasks
grouped by day, each day a section with a heading and an add button.
Elements: task row (checkbox, title, description line, date, project tag,
priority flag color).
Actions: complete, open, drag to another day, add to a day.
Shortcuts or gestures seen: swipe right to complete.
```

End with three lists:

- **Navigation map**: per platform, the sidebar items, tabs, or top-level
  rows and where each leads.
- **Command map**: every menu item, keyboard shortcut, and gesture, with
  its platform.
- **Data model guess**: the nouns and fields seen (shared by all platforms).

Claude describes structure and behavior. It takes no text, logo, or icon
from the app: rebuilding for personal use is fine, copying a brand is not.
The PNGs stay out of public repos: Claude adds `docs/screens/**/*.png` to
`.gitignore` and never stages them (CONVENTIONS section 7). The step is
done when `.gitignore` has that line.

## 6. Turn it into stories

Claude stops computer use and closes iPhone Mirroring if it opened it
(CONVENTIONS section 6). Then it calls the Skill tool with
`bama:user-stories`. Every screen in the index ends up linked from at
least one story, or listed under `## Dropped`.

Done when INDEX.md has a section per PNG, the three maps exist,
`docs/screens/**/*.png` is in `.gitignore`, computer use is stopped, and
`docs/STORIES.md` covers every screen.
