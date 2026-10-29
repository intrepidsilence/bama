# visionOS integrations

The spatial surfaces an Apple Vision Pro app can use, the API for each, and
the permission or entitlement it costs. Shapes marked "(check)" were not
verified against a build here: Claude reads the current Apple docs for them
before writing the code. Most iPad integrations (App Intents, notifications,
URL schemes, Spotlight) work the same way: see [ios.md](ios.md).

## Contents

- Pick the API
- Windows
- Volumes
- Immersive spaces
- Ornaments
- RealityKit content
- Hand tracking and world sensing
- SharePlay

## Pick the API

| Want | API | Permission or entitlement |
| --- | --- | --- |
| A flat window of UI | `WindowGroup` (glass background by default) | None |
| A 3D object the user can walk around, next to other apps | `WindowGroup` with `.windowStyle(.volumetric)` | None |
| Take over the space (a scene, a theater) | `ImmersiveSpace` with an immersion style | None |
| Controls attached to a window's edge | `.ornament(attachmentAnchor:contentAlignment:)` | None |
| 3D models and effects | RealityKit `RealityView`, `Model3D` | None |
| Track the user's hands | ARKit `HandTrackingProvider` in an `ARKitSession` | `NSHandsTrackingUsageDescription`, user approves; immersive space only |
| Find walls, tables, the room | ARKit `PlaneDetectionProvider`, `WorldTrackingProvider` | `NSWorldSensingUsageDescription`, user approves; immersive space only |
| Do it together on a FaceTime call | GroupActivities (SharePlay) | Group Activities capability (`com.apple.developer.group-session`) |

Start with a window. Add a volume or an immersive space only when the
brief's story needs depth: each one is a separate scene the user has to
open and close.

## Windows

```swift
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup(id: "main") { ContentView() }
            .defaultSize(width: 1000, height: 700)

        WindowGroup(id: "detail", for: Todo.ID.self) { $id in DetailView(id: id) }
    }
}
// open another: @Environment(\.openWindow) var openWindow; openWindow(id: "detail", value: todo.uid)
```

- Windows have a glass background. Do not paint an opaque background over
  the whole window: text and controls sit on the glass.
- Every interactive element gets a hover effect (standard controls have
  it) and a hit area of at least 60 pt, because the eyes aim less finely
  than a pointer.
- `TabView` becomes the side tab bar, `NavigationSplitView` the sidebar.
  Toolbars become bottom ornaments.

## Volumes

```swift
WindowGroup(id: "globe") { GlobeView() }
    .windowStyle(.volumetric)
    .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)
```

- A volume shows 3D content from every side, next to other apps. Content
  stays inside its bounds and is clipped at them.
- Put controls in an ornament or a toolbar, not floating in the volume.

## Immersive spaces

```swift
// Scene
ImmersiveSpace(id: "theater") { TheaterView() }
    .immersionStyle(selection: $style, in: .mixed, .progressive, .full)

// View
@Environment(\.openImmersiveSpace) private var openImmersiveSpace
@Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

switch await openImmersiveSpace(id: "theater") {
case .opened: isImmersed = true
default: isImmersed = false            // .error or .userCancelled: show why
}
```

- One immersive space is open at a time, for the whole app. Track whether
  it is open in the model, and close it before opening another.
- In one shipped app, `openImmersiveSpace` read from a view inside an
  ornament or deep in the tree did not open the space reliably. Read it in
  the window's root view and route requests there.
- `.mixed` keeps the room visible, `.progressive` lets the Digital Crown
  dial it in, `.full` replaces the room. Start mixed unless the story needs
  more.
- Always give a visible way out (a button in a window or an attachment),
  besides the Digital Crown.

## Ornaments

```swift
PlayerView()
    .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
        TransportControls()
            .padding()
            .glassBackgroundEffect()
    }
```

- An ornament is attached to a window's edge and moves with it. Use it for
  controls that belong to the window: playback, tools.
- `contentAlignment: .top` with a `.bottom` anchor puts the whole ornament
  below the window.

## RealityKit content

```swift
RealityView { content in
    if let model = try? await Entity(named: "Globe", in: realityKitContentBundle) {
        content.add(model)
    }
} update: { content in
    // apply model changes to entities
}
```

- `Model3D(named:)` for a single model with no logic.
- Assets come from a Reality Composer Pro package in the project. Load
  them asynchronously, never on the main actor in `body`.
- Taps on entities need an `InputTargetComponent` and a
  `CollisionComponent`, then `.gesture(TapGesture().targetedToAnyEntity())`.
- SwiftUI views inside a `RealityView` are attachments. Keep them small.

## Hand tracking and world sensing

```swift
let session = ARKitSession()
let hands = HandTrackingProvider()
guard HandTrackingProvider.isSupported else { return }
try await session.run([hands])          // asks the user the first time
for await update in hands.anchorUpdates {
    let anchor = update.anchor          // HandAnchor: chirality, skeleton joints
}
```

- Works only while the app has an immersive space open. In a window or
  volume the app gets the system's gestures (tap, pinch, drag), which need
  no permission.
- Info.plist: `NSHandsTrackingUsageDescription`, and
  `NSWorldSensingUsageDescription` for planes, scene reconstruction, and
  world anchors.
- The simulator has no hand tracking. Test it on a device. (check:
  current simulator support)

## SharePlay

- Define a `GroupActivity` with metadata, and call `activate()` while the
  user is on a FaceTime call. Each participant's app receives a
  `GroupSession` from `MyActivity.sessions()`.
- Sync state with a `GroupSessionMessenger`, and media with
  `AVPlayerPlaybackCoordinator`.
- Spatial Personas: `SystemCoordinator` in the session sets how people
  are placed around shared content. (check: current API)
- The capability is Group Activities. Test with two devices on one
  FaceTime call: the simulator cannot join one.

Done when each visionOS hook in the brief works on the project simulator
(hand tracking and SharePlay on a device), every window and volume opens
and closes from the UI, and an immersive space always has a visible way
out.
