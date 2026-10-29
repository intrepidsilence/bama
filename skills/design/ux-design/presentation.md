# Where a feature opens

Code for each row of the surface tables in [SKILL.md](SKILL.md). The Mac
sections compile on macOS 26 with Swift 6.2 and main-actor default
isolation (the Mac template from `bama:new-app`). `Item` is the template's
SwiftData model, with a `dueDate: Date` field added for the popover
example. "Other platforms" at the end covers iOS, iPadOS, tvOS, watchOS,
and visionOS.

## Contents

- Inline
- Inspector
- Popover
- Panel
- Sheet
- New window
- Sidebar page or detail
- Confirmation dialog
- Alert
- Status instead of an alert
- Unsaved changes
- Other platforms

## Inline

Use for one value on something already on screen. No surface opens, so
nothing needs closing. Save on Return or when focus leaves the field.

```swift
struct ItemRow: View {
    @Bindable var item: Item
    @FocusState private var editing: Bool

    var body: some View {
        TextField("Title", text: $item.title)
            .textFieldStyle(.plain)
            .focused($editing)
            .onSubmit { editing = false }
    }
}
```

## Inspector

Use for details of the selection while people keep working in the list.
It stays open across selections. `InspectorCommands()` on the scene adds
View > Show Inspector, Control-Command-I.

```swift
List(items, selection: $selection) { item in ItemRow(item: item) }
    .inspector(isPresented: $showInspector) {
        if let item = selection.flatMap(find) {
            ItemInspector(item: item)
        } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.right")
        }
    }
    .inspectorColumnWidth(min: 220, ideal: 260, max: 360)
```

## Popover

Use for a few related choices tied to one control. It closes when people
click outside or pick an item, and it keeps their changes. Only an explicit
Cancel throws them away. It never warns, never holds a warning, and opens
one at a time. A popover people want to keep open can detach into a panel
(AppKit `NSPopover` with `detachableWindow`; SwiftUI has no detach).

```swift
Button("Due Date", systemImage: "calendar") { showDate = true }
    .help("Set the due date")
    .popover(isPresented: $showDate, arrowEdge: .bottom) {
        DatePicker("Due Date", selection: $item.dueDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
    }
```

## Panel

Use when people give input again and again and watch the result (find and
replace, a color or font picker), or keep a tool open beside their work.
A panel floats over the app, hides when the app is not in front, has no
minimize button, and stays out of the Window menu's list. Its title is a
noun ("Inspector"), and its menu item says "Show Inspector", never "panel".

```swift
// In the App body
UtilityWindow("Inspector", id: "inspector") {
    InspectorPanel()
}
```

Prefer sliders, steppers, and pickers over typed values in a panel.

A Spotlight-style panel, a corner card, a countdown, or a HUD is a
different kind: borderless, non-activating, it closes when it loses focus
and stays out of screen recordings. Recipe: mac-design patterns.md,
"Quick-capture panel", and os-integrations recipes.md, "Non-activating
panel".

## Sheet

Use for one short task that must finish or cancel before going on: a few
fields, one screen, no navigation inside. On macOS the toolbar placements
put the buttons at the bottom, bind Return to the confirm button, and bind
Escape to Cancel.

```swift
.sheet(isPresented: $renaming) {
    Form {
        TextField("Name", text: $draft)
    }
    .formStyle(.grouped)
    .frame(width: 360)
    .navigationTitle("Rename Project")
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { renaming = false }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Rename") { project.name = draft; renaming = false }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
```

- A Done button always comes with Cancel, or with Back in a multi-step
  sheet. Never show Cancel, Done, and Back together.
- Open at a size that fits the content. Let people resize it when the
  content would benefit (a long list, a preview).
- Other windows of the app stay usable while the sheet is open.
- People repeat the input and watch results? Use a panel instead.

A sheet that grows a second screen, a sidebar, or a scroll of settings
wants to be a window.

## New window

Use for a long or self-contained task, or something people keep open next
to the main window: an editor, a large preview. Each window remembers its
frame.

```swift
// In the App body
WindowGroup("Item", for: PersistentIdentifier.self) { $id in
    if let id { ItemEditor(id: id) }
}
.defaultSize(width: 640, height: 480)

// In a view
@Environment(\.openWindow) private var openWindow
Button("Open in New Window") { openWindow(value: item.persistentModelID) }
```

## Sidebar page or detail

A place people come back to (Inbox, Today, a project) is a sidebar page.
One item of that list opens in the detail column or the inspector, not in a
sheet. Add the page to the `SidebarItem` enum so snapshot mode visits it.

## Confirmation dialog

Use only for a rare action that destroys data and cannot be undone. For
undoable actions, act at once and offer Undo. The title asks the question,
the button repeats the verb, and the system adds Cancel.

When people chose the action on purpose (Empty Trash from a menu), the
confirm button gets no destructive role, so Return confirms what they asked
for. Use `role: .destructive` only for a destructive button people did not
ask for, such as "Don't Save" when closing an edited document. [HIG Buttons]

```swift
.confirmationDialog("Empty Trash?", isPresented: $confirmEmpty) {
    Button("Empty Trash") { emptyTrash() }
} message: {
    Text("You can't undo this action.")
}
```

## Alert

Use for a problem people must act on now. The title says what happened.
The message, if any, says what to do.

- Never at launch, never only to inform, and never for a common delete
  that Undo covers.
- The default button sits on the trailing side. Escape and Command-Period
  cancel. Avoid "OK" except for a purely informational alert.
- An alert that repeats for a task people do often gets a "Do not show
  again" checkbox: `.dialogSuppressionToggle(isSuppressed: $skip)`.
- The caution symbol only for a real risk of losing data, never for a
  routine overwrite or Empty Trash.

```swift
.alert("Unable to Export", isPresented: $exportFailed) {
    Button("Choose Another Folder") { chooseFolder() }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("The folder is read-only. Choose a folder you can write to.")
}
```

## Status instead of an alert

Information that needs no action goes where it applies. Offline, show the
cached content and a quiet label, the way Mail does.

```swift
.safeAreaInset(edge: .bottom) {
    if isOffline {
        Label("Offline. Changes save when you reconnect.", systemImage: "wifi.slash")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(8)
    }
}
```

## Unsaved changes

Ask before closing only when people would lose what they typed. Offer to
keep it.

```swift
Button("Cancel") {
    if draft.isEmpty { dismiss() } else { confirmDiscard = true }
}
.confirmationDialog("Discard this note?", isPresented: $confirmDiscard) {
    Button("Discard", role: .destructive) { dismiss() }
    Button("Keep Editing", role: .cancel) {}
}
```

## Other platforms

The same SwiftUI modifiers present differently per platform. Where the
right surface differs, branch with `#if os(...)` or
`Platform.value(...)`, never a size class check alone (an iPad in a narrow
window is compact, but it is still an iPad).

### iOS and iPadOS

A sheet for a short task. On iPhone, add detents when the top half is
useful on its own; on iPad it shows as a centered form sheet.

```swift
.sheet(isPresented: $showingNew) {
    NewTaskForm()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(form.hasChanges)   // ask before a swipe loses typing
}
```

A popover on iPad, which iPhone shows as a sheet. Ask for the popover in
compact width too only when the content is small:

```swift
.popover(isPresented: $showingDate) {
    DatePicker("Due", selection: $item.dueDate).padding()
        .presentationCompactAdaptation(.popover)
}
```

Details beside the content on iPad, a sheet on iPhone:

```swift
.inspector(isPresented: $showingInspector) { ItemDetails(item: item) }
```

A camera, player, or game:

```swift
.fullScreenCover(isPresented: $playing) { PlayerView(item: item) }
```

### tvOS

There are no popovers or inspectors. A task opens as a full-screen page:
a push in the current `NavigationStack`, or `.fullScreenCover`. Back
closes it. A text field goes on its own page, not in an alert.

```swift
NavigationLink(value: Route.newTask) { Label("Add Task", systemImage: "plus") }
// ...
.navigationDestination(for: Route.self) { route in
    if route == .newTask { NewTaskPage() }   // full screen; Back returns to the row
}
```

### watchOS

Navigation is a short `NavigationStack` or vertical pages. A sheet is
brief and rare, never a way to move through the app.

```swift
TabView {
    TodayPage()
    StatsPage()
}
.tabViewStyle(.verticalPage)      // the Digital Crown pages through
```

### visionOS

Windows are the main surface. A side task opens a new window beside the
current one; one 3D object goes in a volume; a big moment goes in an
immersive space. Frequent controls for a window go in its toolbar, which
the system shows as an ornament.

```swift
@main struct TasksApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        WindowGroup(id: "details", for: Item.ID.self) { $id in ItemDetails(id: id) }
            .defaultWindowPlacement { _, context in
                guard let main = context.windows.first else { return WindowPlacement() }
                return WindowPlacement(.trailing(main))   // beside the main window
            }
        ImmersiveSpace(id: "focus") { FocusRoom() }
    }
}

// Open them:
@Environment(\.openWindow) private var openWindow
@Environment(\.openImmersiveSpace) private var openImmersiveSpace
Button("Show Details") { openWindow(id: "details", value: item.id) }
Button("Enter Focus Room") { Task { await openImmersiveSpace(id: "focus") } }
```

A custom ornament, for controls only:

```swift
.ornament(attachmentAnchor: .scene(.bottom)) {
    PlaybackControls().padding().glassBackgroundEffect()
}
```
