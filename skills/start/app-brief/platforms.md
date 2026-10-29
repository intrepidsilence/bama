# What each platform's version is for

Each platform's version of the app does what that device is good at. A
watch app is not a phone app made smaller, and a TV app is not an iPad app
made larger. Claude uses this table to fill the brief's `## Platforms`
lines and the per-platform non-goals. The design rules themselves live in
`bama:mac-design` and `bama:platform-design`.

| Platform | Good at | Usually not in version one |
| --- | --- | --- |
| `macos` | Long sessions at a desk. A window with a sidebar, many items on screen, menu bar commands with shortcuts, drag and drop, several windows, a menu bar item, a global shortcut. | Touch-first layouts. |
| `ios` | Quick capture and checking on the go. One column, a tab bar or a navigation stack, swipe actions, widgets, Share sheet, notifications, Live Activities. | Dense multi-column editing, menu-heavy flows. |
| `ipados` | The phone's jobs with more room: two or three columns (sidebar, list, detail), pointer and keyboard shortcuts, Split View, Apple Pencil where it fits. | A stretched phone layout. |
| `tvos` | Viewing from the couch, three meters away. Big focusable rows and grids, driven by the Siri Remote (swipe, click, Menu/Back). Media, dashboards, browsing. Top Shelf. | Text entry beyond search, dense lists, editing, anything that needs a pointer. |
| `watchos` | Glances of a few seconds. One or two jobs: see today's item, check one off, start a timer. Complications, Smart Stack widgets, notifications, the Digital Crown. | Browsing, settings, creation beyond dictation or a short list. |
| `visionos` | Spatial use: windows placed around the user, volumes for 3D content, an immersive space when the app needs the room. Gaze and pinch, ornaments for toolbars. | Full immersion when a window does the job; tiny tap targets. |

## Questions per target

Claude asks only for the targets the user named.

- **tvOS**: What does the user look at from the couch? What is the one
  action per screen? Is there anything to type? (If yes, keep it to search
  or move it to the phone.)
- **watchOS**: What does the user check in two seconds? Which one action
  happens on the wrist? Does it need the phone nearby, or run on its own?
- **visionOS**: Does it stay in a window, or does it need a volume or an
  immersive space? Why?
- **iPadOS**: Which pages get a second or third column? Is there a
  keyboard-first flow?
- **iOS and macOS together**: Which jobs happen on the phone (capture,
  check) and which at the desk (organize, review)?

## Primary platform

The primary platform is where the core loop is built and tested first (M1
in `bama:user-stories`). Pick the device where the user does the main job
most often. Examples of a reason: "most capture happens on the phone",
"the user reviews the week at the desk", "the app is for the living room".
