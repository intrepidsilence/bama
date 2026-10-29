# watchOS integrations

The system surfaces an Apple Watch app can reach, the API for each, and the
permission or entitlement it costs. Shapes marked "(check)" were not
verified against a build here: Claude reads the current Apple docs for them
before writing the code.

## Contents

- Pick the API
- Limits that shape every feature
- Complications and the Smart Stack
- Workouts and HealthKit
- Watch Connectivity with the iPhone app
- Notifications
- Background refresh

## Pick the API

| Want | API | Target | Permission or entitlement |
| --- | --- | --- | --- |
| Something on the watch face | WidgetKit `accessory*` families | widget extension | App Group to read app data |
| A card in the Smart Stack | WidgetKit widget with relevance | widget extension | App Group |
| Track a workout, heart rate, calories | `HKWorkoutSession` + `HKLiveWorkoutBuilder` | app | HealthKit capability, `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `WKBackgroundModes` = `workout-processing` |
| Share state and commands with the iPhone app | `WCSession` | app (both sides) | None |
| Alerts | `UNUserNotificationCenter`, or the iPhone's notifications forwarded | app | User approves once |
| Update data now and then | `.backgroundTask(.appRefresh)` | app | None |
| Keep running for a short focused task (timer, mindfulness) | `WKExtendedRuntimeSession` | app | The session type in `WKBackgroundModes` (check) |
| Siri, Shortcuts, Action button on Ultra | `AppIntent` + `AppShortcutsProvider` | app | None |
| Crown input | `.digitalCrownRotation($value)` | app | None |

## Limits that shape every feature

- A watch app runs for seconds at a time. It opens, shows one thing, and
  takes one action. Load from a local cache first, then refresh.
- The watch app has its own container and store. It never reads the
  iPhone's files: data arrives through Watch Connectivity, CloudKit, or the
  network.
- Memory and CPU are small. Decode images at display size, and keep lists
  short.
- Network calls may go through the iPhone. Keep them few and small, with a
  timeout the user can live with.
- Simulator numbers say little here. Battery, memory, and timing are
  checked on a real watch (`bama:performance`).

## Complications and the Smart Stack

Complications are WidgetKit widgets in the accessory families:

```swift
struct LauncherComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Launcher", provider: LauncherProvider()) { entry in
            LauncherView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("<App>")
        .supportedFamilies([.accessoryCircular, .accessoryCorner,
                            .accessoryInline, .accessoryRectangular])
    }
}
```

- `.accessoryCorner` exists only on watchOS.
- Faces render in tints. Read `@Environment(\.widgetRenderingMode)` and
  draw `AccessoryWidgetBackground()` only in the tinted modes.
- `.accessoryInline` shows one line of system text: a symbol and a few
  words, nothing drawn.
- A complication that shows data goes stale, and a stale number on a face
  looks true. Show data only when it can stay fresh. A launcher that only
  opens the app never goes stale.
- After the app changes what a complication shows:
  `WidgetCenter.shared.reloadTimelines(ofKind:)`. Pushing data from the
  iPhone with `transferCurrentComplicationUserInfo(_:)` has a daily budget
  (`remainingComplicationUserInfoTransfers`).
- The Smart Stack shows `.accessoryRectangular` widgets. Relevance tells
  the system when to raise one (a timeline entry's `relevance`, or the
  newer relevance configuration in watchOS 26). (check: the current
  relevance API)

## Workouts and HealthKit

```swift
let store = HKHealthStore()
try await store.requestAuthorization(toShare: [HKObjectType.workoutType()],
                                     read: [HKQuantityType(.heartRate),
                                            HKQuantityType(.activeEnergyBurned)])

let config = HKWorkoutConfiguration()
config.activityType = .running
config.locationType = .outdoor
let session = try HKWorkoutSession(healthStore: store, configuration: config)
let builder = session.associatedWorkoutBuilder()
builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
session.delegate = self
builder.delegate = self                       // didCollectDataOf: live statistics

let start = Date()
session.startActivity(with: start)
try await builder.beginCollection(at: start)
// ... later
session.end()
try await builder.endCollection(at: .now)
let workout = try await builder.finishWorkout()
```

- Ask for exactly the types the feature uses. The user can deny reading,
  and HealthKit does not say so: treat "no data" as possibly "no access".
- A running workout session keeps the app on screen and running in the
  background. End it when the workout ends, or the battery drains.
- Mirror the workout to the iPhone with
  `startMirroringToCompanionDevice()` when the iPhone app shows it live.
  (check)
- Delegate callbacks arrive off the main actor. Hop back with
  `Task { @MainActor in ... }` (`bama:swift-swiftui`, Concurrency).

## Watch Connectivity with the iPhone app

Three channels, for three jobs:

| Channel | Delivers | Use for |
| --- | --- | --- |
| `updateApplicationContext(_:)` | Only the newest dictionary, in the background | Current state: "volume is 40" |
| `sendMessage(_:replyHandler:errorHandler:)` | Now, only when `isReachable` | Commands from a button press |
| `transferUserInfo(_:)` | Every item, in order, in the background | Events that must not be lost |

- Activate once at launch: `WCSession.default.delegate = self; WCSession.default.activate()`.
- `activationState == .activated` and `isReachable` are different. Gate
  live commands on reachability, never the whole UI on it.
- Always pass a reply handler and an error handler. Reply with the new
  state, so the watch shows it at once. The receiver calls the reply
  handler exactly once on every path.
- Values are property-list types only (`Bool`, `Int`, `Double`, `String`,
  `Date`, `Data`, arrays, dictionaries). Define the keys once in
  `<App>Kit`, used by both sides.
- Send absolute commands (`setMuted(true)`), not toggles.
- Files and images: `transferFile(_:metadata:)`, not the context.
- The phone side sends state from the one place that announces data
  changes, next to the widget reload.

## Notifications

- When the iPhone app sends a notification and the phone is locked, the
  watch shows it with no watch code. A watch app adds its own look with a
  notification scene (`WKNotificationScene`) and its own actions.
- A standalone watch app asks for permission and schedules with
  `UNUserNotificationCenter`, as on iOS.
- Keep a notification's text short. The user reads it with a wrist raise.

## Background refresh

```swift
.backgroundTask(.appRefresh("refresh")) {
    await AppModel.shared.refresh()
    WidgetCenter.shared.reloadAllTimelines()
}
// schedule: WKApplication.shared().scheduleBackgroundRefresh(
//     withPreferredDate:userInfo:scheduledCompletion:)
```

- The system grants a few refreshes an hour, fewer when the app has no
  complication on the face. (check: current budget)
- Each refresh does the least it can and schedules the next one.

Done when each watchOS hook in the brief works on the project simulator,
data flows both ways with the iPhone app when the brief has one, and every
HealthKit or notification prompt shows its usage text.
