---
name: ux-design
description: UX pass for one feature of an app on any Apple platform, covering names, flow, where it opens (inline, popover, sheet, window, full screen, ornament), states, words, hover help, accessibility, and AI features, per target platform. Use before coding a story that adds a screen, an action, or text, when user-stories or improve-loop call it, or when the user asks for a UX review, clearer wording, better names, or whether something should be a modal.
argument-hint: "[story ID or screen]"
---

# UX design

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

A feature that works can still confuse people. This pass decides what
things are called, how a person moves through the feature, where it opens,
and what it says, before any code exists. It does this for each target
platform in the brief: the same feature opens in a sheet on iPhone, a
popover on iPad, a full-screen page on Apple TV, and a window on Vision
Pro.

Claude runs it once per story that adds a screen, an action, or words. The
output is a `UX:` block in the story in `docs/STORIES.md` (a working file
in both modes), plus new terms in the glossary. To review a built screen,
Claude runs the same steps against its snapshots and lists what fails, most
serious first.

The glossary follows the records mode:

- `markdown`: the table in `docs/GLOSSARY.md`.
- `muninn`: one memory per term, type `reference`, tags
  `["bama", "<App>", "glossary"]`, with the term, what it means, and the
  words not to use. Claude reads it with `muninn_recall` (the app's name
  and "glossary") and changes a term with `muninn_evolve`.

## 0. Read

Read the brief (`docs/BRIEF.md`, or recall it in `muninn` mode) and its
target platforms, the glossary (create it if missing), the story, and its
reference screenshots. For each target other than macOS, read that
platform's file in `bama:platform-design`; for macOS, `bama:mac-design`.

Check: Claude can name every target platform for this story.

## 1. Name it

Every thing in the app has exactly one name, and every name lives in the
glossary.

```markdown
| Term | Means | Not |
| --- | --- | --- |
| Task | One thing to do, with an optional due date | to-do, item, entry |
| Complete | Mark a task done; it leaves the list | check, finish, close |
```

- Name the things first (the nouns in the brief), then the actions on them.
- Use the user's words, not the code's: "Task", not "TaskEntity" or "record".
- Use Apple's words for system actions: Settings, Quit, Close, Undo, Move
  to Trash (when it can come back), Delete (when it cannot).
- One word per idea across buttons, menus, titles, tooltips, and errors,
  and across platforms. The iPhone and the Mac call a task the same thing.
- Name a feature for what it does for the person, not the technology. A
  toggle gets a verb phrase that says what and for whom ("Enhance
  Dialogue", not "Isolate Vocals"). Say the name in a sentence out loud.
  Method: [writing.md](writing.md#names).

Check: every noun and verb the story puts on screen is in the glossary,
and no glossary term has a second name anywhere.

## 2. Map the flow

Write the flow as one line per target, from every way in to a clear end.

```text
macOS: Command-N, toolbar +, File > New Task -> title field has focus -> Return saves, row appears -> focus stays for the next task
iOS:   + in the toolbar -> sheet with the title field focused -> Add saves, sheet closes, row appears
tvOS:  Add Task button at the end of the row -> full-screen page with the title field -> Done saves, Back returns to the row
```

- List every entry point on each platform: menu command, shortcut,
  toolbar, context menu, swipe action, focusable button, drag and drop,
  widget, notification action.
- Cut steps: fill in good defaults, ask only for what the app cannot
  guess.
- Every step has a way back: Escape or Command-Z on a Mac or an iPad with a
  keyboard, Cancel or a swipe down on iPhone, the Back button on Apple TV,
  a swipe from the left edge on Apple Watch and iPhone.
- The end is visible: the new row, a checkmark, the surface closing.

Check: each target's flow fits on one line, and each step names its way
back.

## 3. Pick the surface

On macOS, go down this list and use the first one that fits. Lighter is
better.

| The feature | Use |
| --- | --- |
| Changes one value on something already on screen | Inline (field, toggle, menu in the row) |
| Shows details of the selection while people keep working | Inspector |
| A few related choices tied to one control | Popover |
| Input people repeat while they watch the result, or a tool kept open beside the work | Panel |
| One short task that must finish or cancel before going on | Sheet |
| A long or self-contained task, or one people keep open beside the main window | New window |
| A place people come back to, like a list or a collection | Sidebar page |
| A rare action that destroys data and cannot be undone | Confirmation dialog |
| A problem people must act on right now | Alert |

On the other platforms, the same needs map to that platform's surfaces:

| The need | iOS | iPadOS | tvOS | watchOS | visionOS |
| --- | --- | --- | --- | --- | --- |
| One value on screen | inline | inline | inline, a focusable control in the page | inline, Crown for numbers | inline |
| Details of a selection | push a page | `.inspector` (a sheet in compact width) | push a full-screen page | push a page | inspector, or a new window beside |
| A few choices on one control | `Menu`, or a sheet with `.medium` detent | popover | `Menu`, or a full-screen list | push a list | popover |
| One short task | sheet | form sheet | full-screen page (`.fullScreenCover` or a push) | sheet, brief and rare | sheet, centered in front of its window |
| An immersive task (camera, player, game) | `.fullScreenCover` | `.fullScreenCover` | full screen; swipes act on the content | full-screen page | immersive space, or a volume for one 3D object |
| A long or side-by-side task | push a page | new window (`openWindow`) | push a page | not on the watch | new window beside the current one |
| A place people come back to | tab | tab or sidebar item | tab in the top tab bar | vertical page or list root | tab (the tab bar ornament) |
| Frequent controls for one window | toolbar | toolbar | buttons in the page | toolbar, or the Crown | toolbar or a custom ornament |
| A rare destructive action | confirmation dialog | confirmation dialog | confirmation dialog | confirmation dialog | confirmation dialog |
| A problem to act on now | alert | alert | alert (no text field in it on tvOS) | alert | alert |

- Show one modal at a time. Never open a popover from a popover, or a
  sheet from a sheet.
- A modal's title names its task: "Rename Project", not "Edit".
- The confirm button names the action. Return confirms and Escape cancels
  where there is a keyboard; on tvOS, Back cancels.
- Ask before closing only when people would lose what they typed (on iOS,
  also before a swipe down closes the sheet).
- Information that needs no action goes inline, never in an alert.

Details and SwiftUI code for each surface: [presentation.md](presentation.md).

Check: the `UX:` block names the surface for each target and the table row
that picked it.

## 4. Cover the states

Every view the story touches has words and a look for each state:

- **Empty**: what it is for, plus the first action as a button.
- **Loading**: only when it can take longer than half a second. Show
  cached content first. A bar when the length is known, with words for
  what is happening ("Importing 12 photos"), and Cancel when it is safe.
- **Error**: inline, next to the problem, with the fix.
- **Too much**: long names truncate with the full text available (a
  tooltip on the Mac and iPad, the detail page elsewhere); a thousand rows
  still scroll smoothly.
- **Done**: visible feedback in the same frame, and Undo where it applies.

Check: each state has a snapshot page or seed data that shows it, on each
target.

## 5. Write the words

- Buttons and menu items start with a verb: "Add Task", "Export…".
- Add an ellipsis when the command asks for more input before it acts.
- Title case for buttons, menu items, and window titles. Sentence case for
  labels, descriptions, and messages.
- Errors say what happened and how to fix it, without blame. Write
  "Unable to load tasks", never "We're having trouble".
- Confirmations repeat the action: "Delete 3 Tasks?" with buttons "Delete"
  and "Cancel", never "Yes" and "No".
- Words for the action match the device. Prefer words that need no verb of
  touch at all ("Choose a photo"); when one is needed:

  | Platform | Say | Never |
  | --- | --- | --- |
  | macOS | click, press (keys), drag | tap |
  | iOS, iPadOS | tap, swipe, drag, touch and hold | click |
  | tvOS | select, press, swipe (on the remote) | tap, click |
  | watchOS | tap, turn the Digital Crown | click |
  | visionOS | tap (look and pinch), pinch and drag | click |

Patterns and before and after examples: [writing.md](writing.md).

A feature that uses AI (a summary, generated text, a model's suggestion)
also follows [ai-features.md](ai-features.md).

Check: read every string aloud. Each one is short, uses glossary terms
only, uses the right verb for each target, and a new user could say what
each button does.

## 6. Add hover help

Hover help exists where there is a pointer or eyes:

- **macOS and iPadOS with a pointer**: every icon-only button gets
  `.help("Add a task to this list (⌘N)")`: what it does, starting with a
  verb, then its shortcut. Not its name again. Rules:
  [writing.md](writing.md#tooltips).
- **visionOS**: looking at a toolbar or tab item reveals its label, so
  every icon-only button has a short text label (`Label`, or
  `.accessibilityLabel` for a symbol button).
- **iOS, tvOS, watchOS**: no hover. Every icon-only control has a text
  label for VoiceOver, and the action is clear without a tooltip.
- Hover can reveal secondary actions on a row. The same actions are also in
  the context menu and on the keyboard.
- Hover feedback shows at once and never shifts the layout.
- Information people need is always visible. Hover only adds detail.

Check: on the Mac build, hover every icon-only control; each shows a
tooltip. On visionOS, look at each (the pointer in the simulator); each
shows its label.

## 7. Check accessibility

On every platform:

- VoiceOver reads every control with the same words as the screen.
- Meaning never rests on color alone: add an icon or a word.
- Text is at or above the platform's minimum and readable in Increase
  Contrast.
- Reduce Motion replaces slides and bounces with fades.
- Every custom control has a label, a value, actions, and feedback.

Per platform:

| Platform | Also |
| --- | --- |
| macOS | the whole flow works with the keyboard alone, in a logical order; text 10 pt or larger |
| iOS, iPadOS | Dynamic Type up to the largest accessibility size without clipping; 44 pt targets; iPad keyboard reaches every area with Tab and arrows |
| tvOS | every element is reachable by focus; focused labels are legible; text 23 pt or larger |
| watchOS | every Crown action also works by touch; text 12 pt or larger |
| visionOS | every action works with a look and a pinch; 60 pt targets; no motion without a still frame of reference |

The audit steps and SwiftUI modifiers: [accessibility.md](accessibility.md).

Check: Claude ran the flow on each target with its input (keyboard only on
the Mac, the remote keys on tvOS) and with VoiceOver where the simulator
supports it, and the Accessibility Inspector audit shows no issues for the
new views.

## 8. Write the UX block

Add the result under the story's acceptance lines. One line per target
where the platforms differ; one line for all where they do not:

```markdown
UX:
- Flow (macOS): Command-N, toolbar +, File > New Task -> title field -> Return saves -> focus stays
- Flow (iOS): toolbar + -> sheet, title focused -> Add saves, sheet closes
- Surface: macOS inline row at the top of the list (changes one value on screen); iOS sheet (one short task)
- States: empty "No Tasks" with "Add Task"; error "Give the task a title." under the field
- Words: "Add Task", tooltip "Add a task to this list (⌘N)" (macOS), "Undo Add Task"
- Access: Return saves, Escape cancels (macOS); VoiceOver "New task title"; Dynamic Type to AX5 (iOS)
```

Done when the story has a `UX:` block covering every target platform,
every term it uses is in the glossary (`docs/GLOSSARY.md`, or MuninnDB in
`muninn` mode), and steps 1 to 7 pass on each target's snapshots.
