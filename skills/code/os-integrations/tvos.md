# tvOS integrations

The system surfaces an Apple TV app can reach, the API for each, and the
permission or entitlement it costs. Shapes marked "(check)" were not
verified against a build here: Claude reads the current Apple docs for them
before writing the code. Focus rules (where the highlight enters a row,
what Menu does) belong to `bama:platform-design` and, when the session
lists it, `tvos-focus-navigation`.

## Contents

- Pick the API
- Storage on Apple TV
- Top Shelf
- Siri Remote
- Game controllers
- Several people, one Apple TV
- Background audio and Now Playing
- AirPlay

## Pick the API

| Want | API | Target | Permission or entitlement |
| --- | --- | --- | --- |
| Content on the Home Screen when the app is in the top row | `TVTopShelfContentProvider` | Top Shelf extension | App Group to read app data |
| Remote buttons and swipes | `.onMoveCommand`, `.onPlayPauseCommand`, `.onExitCommand`, focus | app | None |
| Game controllers | GameController `GCController` | app | `GCSupportsControllerUserInteraction` in Info.plist (check) |
| Separate data per person | User Management | app | `com.apple.developer.user-management` (check the values) |
| Music that keeps playing | `AVAudioSession` `.playback` | app | `UIBackgroundModes` = `audio` |
| Now Playing and remote play/pause | `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` | app | None |
| Send video to another screen, or route audio | `AVPlayer` + `AVRoutePickerView` | app | None (check availability on tvOS) |
| Siri and Shortcuts | `AppIntent` | app | None. Fewer surfaces than iOS (check which) |
| Sign in with an iPhone | `ASAuthorizationController`, or a code shown on the TV | app | Sign in with Apple capability when used |

## Storage on Apple TV

Read this before any feature that saves data. tvOS gives an app no
guaranteed persistent local storage:

- User data that must survive goes to iCloud (CloudKit, or
  `NSUbiquitousKeyValueStore` for small values).
- `UserDefaults` holds small state, capped around 500 KB.
- Local files go in `URL.cachesDirectory`, and the system can purge them.
- In one shipped app, file writes into the App Group container failed with
  EPERM on a real Apple TV, while the simulator allowed them. Only
  `UserDefaults(suiteName: "group.<bundle-id>")` worked for sharing with
  the Top Shelf extension.

So Claude tests every storage path on a device, not only the simulator.
(check: current Apple guidance for tvOS storage limits)

## Top Shelf

```swift
import TVServices

final class TopShelfProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> TVTopShelfContent? {
        let recent = SharedCache.loadRecent()                // App Group UserDefaults
        guard !recent.isEmpty else { return nil }
        let items = recent.prefix(10).map { entry in
            let item = TVTopShelfSectionedItem(identifier: entry.id)
            item.title = entry.title
            item.setImageURL(entry.imageURL, for: .screenScale1x)
            item.setImageURL(entry.imageURL, for: .screenScale2x)
            item.displayAction = TVTopShelfAction(url: entry.openURL)   // myapp://item/<id>
            item.playAction = TVTopShelfAction(url: entry.playURL)
            return item
        }
        let section = TVTopShelfItemCollection(items: Array(items))
        section.title = "Recently Played"
        return TVTopShelfSectionedContent(sections: [section])
    }
}
```

- The extension's Info.plist names the provider class
  (`NSExtensionPrincipalClass`) under the
  `com.apple.tv-top-shelf` extension point.
- After the app changes what the shelf shows, it calls
  `TVTopShelfContentProvider.topShelfContentDidChange()` from the one place
  that announces data changes. tvOS still refreshes on its own schedule, so
  the shelf can lag: never show something that is wrong when stale (a
  "Now Playing" track). History and favorites age well.
- Images come from a URL. The shelf has no reliable local image cache on a
  device.
- `TVTopShelfCarouselContent` is the full-width style for video apps.
- The app handles each action URL with `.onOpenURL`, and goes straight to
  the item or starts playback.

Check: move the app to the top row, and the shelf shows the latest items
after a change in the app.

## Siri Remote

- Focus drives everything. Every control is focusable, and the focused one
  grows. Containers around it never clip it (`.scrollClipDisabled()`).
- `.onMoveCommand { direction in }` for arrow presses on a focused view,
  `.onPlayPauseCommand { }` for Play/Pause, `.onExitCommand { }` for the
  Back (Menu) button. Back always goes back one level, and on the root page
  leaves the app.
- Swipes and clicks on the touch surface move focus. Custom gestures are
  rare and get a visible hint.
- Text entry is slow on a remote. Offer sign-in from an iPhone, search with
  dictation, and short lists over typing.

## Game controllers

```swift
import GameController

NotificationCenter.default.addObserver(forName: .GCControllerDidConnect,
                                       object: nil, queue: .main) { note in
    guard let pad = (note.object as? GCController)?.extendedGamepad else { return }
    pad.buttonA.pressedChangedHandler = { _, _, pressed in /* ... */ }
}
```

- The Siri Remote also appears as a `GCController` with a
  `microGamepad` profile.
- Every game that needs a controller says so on its first screen, and the
  remote can still reach Settings and Back. (check: current App Review
  rule on controller-required games)

## Several people, one Apple TV

tvOS can switch users from Control Center. With the User Management
entitlement, the app runs as the current user and each person gets their
own data, Keychain, and Game Center. (check: the entitlement values
`runs-as-current-user` and `runs-as-current-user-with-user-independent-keychain`,
and which tvOS version each needs.)

- Without it, every person shares one set of data. Profiles inside the app
  (pick a person on launch) are the other choice.
- Never store one person's sign-in where another can see it.

## Background audio and Now Playing

```swift
try AVAudioSession.sharedInstance().setCategory(.playback)
try AVAudioSession.sharedInstance().setActive(true)

MPNowPlayingInfoCenter.default().nowPlayingInfo = [
    MPMediaItemPropertyTitle: track.title,
    MPMediaItemPropertyPlaybackDuration: track.duration,
    MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
]
MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget { _ in
    player.toggle(); return .success
}
```

- `UIBackgroundModes` = `audio` in Info.plist, or playback stops when the
  user leaves the app.
- Update elapsed time on play, pause, and seek, not every second.
- Video uses `AVPlayerViewController` (or SwiftUI `VideoPlayer`), which
  brings the standard transport bar, subtitles, and Now Playing.

## AirPlay

- `AVPlayer` plays to AirPlay speakers through the system route. An
  `AVRoutePickerView` in a `UIViewRepresentable` gives an in-app picker.
  (check: availability and look on tvOS)
- The Apple TV is usually the AirPlay target, not the source: an iPhone
  app sends to it. Nothing in the tvOS app is needed for that.

Done when each tvOS hook in the brief works on the project simulator and,
for storage and Top Shelf, on a real Apple TV, and the Back button leaves
every page the way the user expects.
