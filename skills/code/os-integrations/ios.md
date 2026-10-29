# iOS and iPadOS integrations

The system surfaces an iPhone or iPad app can reach, the API for each, and
the permission or entitlement it costs. Shapes marked "(check)" are from
Apple's API as Claude knows it and were not verified against a build here:
Claude reads the current Apple docs for them before writing the code
(`research-first`, when the session lists it).

## Contents

- Pick the API
- App Intents and App Shortcuts
- Widgets
- Live Activities
- Control Center controls
- Share and action extensions
- Notifications
- Background tasks
- URL schemes and universal links
- Spotlight and Handoff
- iPad: multiple windows and multitasking
- iPad: Apple Pencil and keyboard

## Pick the API

| Want | API | Target | Permission or entitlement |
| --- | --- | --- | --- |
| Siri, Spotlight, Shortcuts, Action button | `AppIntent` + `AppShortcutsProvider` | app | None |
| Glanceable content on Home Screen, Lock Screen, StandBy | WidgetKit widget | widget extension | App Group to read app data |
| A live countdown or progress (delivery, timer, game) | ActivityKit Live Activity | app starts it, widget extension draws it | `NSSupportsLiveActivities = YES` in the app's Info.plist; push updates need Push Notifications |
| A button or toggle in Control Center, Lock Screen, Action button | `ControlWidget` (iOS 18) | widget extension | None |
| Receive content from other apps | Share extension | share extension | App Group to hand data to the app |
| Act on content inside another app | Action extension | action extension | App Group |
| Alerts, reminders | `UNUserNotificationCenter` | app | User approves once; remote push needs `aps-environment` |
| Refresh data while in the background | `BGTaskScheduler` / `.backgroundTask` | app | `UIBackgroundModes` and `BGTaskSchedulerPermittedIdentifiers` |
| Links from web pages that open the app | Universal links | app | Associated Domains (`applinks:<domain>`) plus a file on the site |
| Links from scripts and other apps | `CFBundleURLTypes` + `.onOpenURL` | app | None |
| The app's content in Spotlight | Core Spotlight `CSSearchableIndex` | app | None |
| Continue on another device | Handoff, `NSUserActivity` | app | `NSUserActivityTypes` in Info.plist |
| Several windows on iPad | `WindowGroup`, `openWindow` | app | `UIApplicationSupportsMultipleScenes = YES` |
| Drawing and handwriting | PencilKit `PKCanvasView` | app | None |
| Keyboard shortcuts on iPad | `.commands` and `.keyboardShortcut` | app | None |
| Camera, microphone, photos, location, contacts | The framework's request call | app | The matching `NS...UsageDescription` key |

Every extension target links `<App>Kit`, joins the App Group, and reads the
store from there (`bama:swift-swiftui`, multiplatform.md).

## App Intents and App Shortcuts

```swift
import AppIntents

struct AddTodo: AppIntent {
    static let title: LocalizedStringResource = "Add To-Do"
    @Parameter(title: "Title") var name: String

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        try AppModel.shared.add(title: name)        // the same code as the button
        return .result(dialog: "Added \(name).")
    }
}

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddTodo(),
                    phrases: ["Add a to-do in \(.applicationName)"],
                    shortTitle: "Add To-Do",
                    systemImageName: "plus.circle")
    }
}
```

- Every phrase contains `\(.applicationName)`. App Shortcuts appear in
  Spotlight and Shortcuts with no setup by the user.
- A phrase shaped like one of Siri's own commands ("Mute X", "Set volume")
  can be taken by Siri instead of the app. In one shipped app, adding a
  preposition ("on the receiver") kept a phrase in the app. Test each
  phrase by voice on a device.
- Model data as `AppEntity` with an `EntityQuery`, so intents take the
  app's own things as parameters.
- These intents are the agent-facing surface of an iOS app: Shortcuts,
  Siri, and Spotlight all call them. `bama:agent-cli` is macOS only.

Check: the shortcut shows in the Shortcuts app after an Xcode build and
runs from Spotlight.

## Widgets

```swift
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Today", provider: TodayProvider()) { entry in
            TodayView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
```

- The provider reads from the App Group store and returns a timeline. The
  system decides when to ask, so the app calls
  `WidgetCenter.shared.reloadTimelines(ofKind: "Today")` after each data
  change that widget shows.
- Buttons and toggles in a widget take an App Intent:
  `Button(intent: ToggleTodo(id: todo.uid)) { ... }`.
- `AppIntentConfiguration` with a `WidgetConfigurationIntent` gives the
  user options (which list to show).
- A tap opens the app at the exact place: `.widgetURL(url)` or `Link`.
- `accessory*` families show on the Lock Screen in one tint. They must read
  without color.

## Live Activities

```swift
struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var stage: String; var eta: Date }
    var orderNumber: String
}

// App side: start, update, end
let activity = try Activity.request(
    attributes: DeliveryAttributes(orderNumber: "42"),
    content: .init(state: .init(stage: "Packed", eta: eta), staleDate: nil))
await activity.update(.init(state: .init(stage: "On the way", eta: eta), staleDate: nil))
await activity.end(nil, dismissalPolicy: .default)

// Widget extension: the views
ActivityConfiguration(for: DeliveryAttributes.self) { context in
    LockScreenView(context: context)
} dynamicIsland: { context in
    DynamicIsland {
        DynamicIslandExpandedRegion(.center) { Text(context.state.stage) }
    } compactLeading: { Image(systemName: "shippingbox") }
      compactTrailing: { Text(context.state.eta, style: .timer) }
      minimal: { Image(systemName: "shippingbox") }
}
```

- A Live Activity runs up to 8 hours, then stays on the Lock Screen up to 4
  more.
- `Text(date, style: .timer)` counts on its own. Never update once a
  second to move a clock.
- Updates while the app is not running come by push
  (`pushType: .token`), which needs the Push Notifications capability and a
  server. (check: the current push payload format)
- Buttons in it take an App Intent, as in widgets.

## Control Center controls

iOS 18 and later. A control is a button or toggle that runs an App Intent.

```swift
struct StartTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.example.app.start-timer") {
            ControlWidgetButton(action: StartTimer()) {
                Label("Start Timer", systemImage: "timer")
            }
        }
    }
}
```

- A toggle uses `ControlWidgetToggle(isOn:action:)` with a
  `SetValueIntent`, and a `ControlValueProvider` that reads the current
  state. (check)
- After the app changes that state:
  `ControlCenter.shared.reloadControls(ofKind:)`. (check)
- Controls live in the widget extension's `WidgetBundle`.

## Share and action extensions

- A share extension target in `project.yml` with an
  `NSExtensionActivationRule` in its Info.plist that names the types it
  accepts (for example `NSExtensionActivationSupportsWebURLWithMaxCount = 1`).
  Never `TRUEPREDICATE` in a shipping app: App Review rejects it.
- Its view controller hosts a SwiftUI view (`UIHostingController`). It
  reads `extensionContext?.inputItems`, writes to the App Group store, and
  calls `extensionContext?.completeRequest(returningItems: nil)`.
- The app sees the new data the next time it reads the store. Post a
  Darwin notification (`notify_post`) if it is running.
- The extension has a small memory limit. Decode images at display size.

## Notifications

```swift
let center = UNUserNotificationCenter.current()
let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

let content = UNMutableNotificationContent()
content.title = "Call the dentist"
let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
try await center.add(UNNotificationRequest(identifier: todo.uid.uuidString,
                                           content: content, trigger: trigger))
```

- Ask when the user first sets a reminder, not at launch.
- Use the model's id as the request id, so editing or deleting the item
  replaces or removes its notification
  (`removePendingNotificationRequests(withIdentifiers:)`).
- Actions on a notification: `UNNotificationCategory` with
  `UNNotificationAction`, handled in a `UNUserNotificationCenterDelegate`.
- Remote push: the Push Notifications capability (`aps-environment`) and
  `UIApplication.shared.registerForRemoteNotifications()`.

## Background tasks

```swift
// App scene
.backgroundTask(.appRefresh("com.example.app.refresh")) {
    await AppModel.shared.refresh()
    scheduleRefresh()
}

func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.app.refresh")
    request.earliestBeginDate = .now.addingTimeInterval(60 * 60)
    try? BGTaskScheduler.shared.submit(request)
}
```

- Info.plist: `BGTaskSchedulerPermittedIdentifiers` lists each id, and
  `UIBackgroundModes` has `fetch` (app refresh) or `processing` (long work).
- The system picks the time. `earliestBeginDate` is a floor, not a
  schedule. Nothing runs after the user force-quits the app.
- Test in the debugger with
  `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.example.app.refresh"]`.
  (check: private debug call, may change)
- Audio, location, and VoIP have their own background modes. Ask for only
  the ones the brief needs: App Review checks each.

## URL schemes and universal links

- URL scheme: `CFBundleURLTypes` in Info.plist, handled with `.onOpenURL`
  on the scene, same as the Mac (`recipes.md`, "URL scheme").
- Universal link: the Associated Domains entitlement
  (`com.apple.developer.associated-domains` = `["applinks:example.com"]`),
  and `https://example.com/.well-known/apple-app-site-association` served
  as JSON over HTTPS with no redirect. SwiftUI delivers the link to
  `.onOpenURL` as well. (check: the current AASA `components` format)
- One router parses both kinds into the app's action enum, the same enum
  the App Intents use.

## Spotlight and Handoff

- Core Spotlight: index each item with a `CSSearchableItem` whose
  `uniqueIdentifier` is the model's `uid`. Delete the item from the index
  when the model is deleted. A tap arrives as an `NSUserActivity` of type
  `CSSearchableItemActionType`:
  `.onContinueUserActivity(CSSearchableItemActionType) { activity in ... }`.
- An `AppEntity` that adopts `IndexedEntity` is indexed for Spotlight and
  Siri together (iOS 18). (check)
- Handoff: `.userActivity("com.example.app.viewing") { activity in
  activity.title = todo.title; activity.targetContentIdentifier = todo.uid.uuidString }`
  on the view, `.onContinueUserActivity("com.example.app.viewing")` on the
  scene, and the type listed in `NSUserActivityTypes`. Both devices use the
  same Apple Account, and the Mac app needs the same team id.

## iPad: multiple windows and multitasking

- `UIApplicationSceneManifest` > `UIApplicationSupportsMultipleScenes = YES`
  lets the user open the app twice side by side.
- `WindowGroup(for: Todo.ID.self) { $id in DetailView(id: id) }` and
  `@Environment(\.openWindow)` open a detail in its own window. Each window
  keeps its own selection: no app-wide "current item".
- Every layout works from a third of the screen to full width. Use
  `horizontalSizeClass` for layout, never the device idiom alone. Check
  each page at compact and regular width.
- Drag and drop between windows and apps: `.draggable` and
  `.dropDestination` with a `Transferable` type.
- Support every orientation. An app that sets `UIRequiresFullScreen` opts
  out of multitasking.

## iPad: Apple Pencil and keyboard

- Drawing: `PKCanvasView` in a `UIViewRepresentable`, with `PKToolPicker`.
  The drawing saves as `PKDrawing.dataRepresentation()`.
- Pencil double tap and squeeze: `.onPencilDoubleTap { }` and
  `.onPencilSqueeze { }` (iOS 17.5). Respect
  `@Environment(\.preferredPencilDoubleTapAction)`. (check)
- Scribble works in standard text fields for free. Custom text views adopt
  `UIScribbleInteraction`.
- Keyboard: the Mac's `.commands` work on iPad and show in the menu bar and
  in the overlay when the user holds Command. Give every main action a
  shortcut, with the same rules as the Mac (`bama:swift-swiftui`, Menu
  commands).
- Pointer: `.hoverEffect()` on custom controls, so the pointer shows what
  can be clicked.

Done when each iOS or iPadOS hook in the brief works from a fresh install
on the project simulator, each permission prompt shows its usage text, and
each extension shows the app's latest data after a change.
