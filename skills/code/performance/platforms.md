# Profiling on each platform

How to measure an iOS, iPadOS, tvOS, watchOS, or visionOS app, and what
limits each platform puts on the numbers. The Mac commands are in
[recipes.md](recipes.md), "Measuring". Commands marked "(check)" were not
run here: Claude runs `--help` on the tool first and adjusts.

## Contents

- Simulator or device
- Find the target
- Record a trace
- Logs and signposts
- Scroll and animation hitches
- iOS and iPadOS
- tvOS
- watchOS
- visionOS
- Numbers from real users

## Simulator or device

| Question | Simulator | Device |
| --- | --- | --- |
| Did this change make the code path faster? | yes, compare before and after | yes |
| Is the app fast enough to ship? | no | yes |
| Memory limit, battery, heat, watchdog kills | no | yes |
| GPU and frame rate | no: it is the Mac's GPU | yes |

A simulator app is a Mac process. So `sample`, `footprint`, and `leaks`
work on it by pid, but they report Mac numbers. Claude labels every number
with where it came from: "simulator on an M2 Mac" or "iPhone 15, release".

Claude uses only the project's own simulators (`.work/simulators`,
CONVENTIONS section 5). A device is the user's: Claude asks before
installing or launching on one.

## Find the target

```bash
xcrun xctrace list devices                         # devices and simulators, with UDIDs
udid=$(awk '$1=="ios"{print $2}' .work/simulators)  # the project's iOS simulator

# Launch the release build on the simulator and get its pid
xcrun simctl launch "$udid" <bundle-id>            # prints "<bundle-id>: <pid>"

# Launch on a device (the user's device, with their go-ahead)
xcrun devicectl device process launch --device <device-udid> <bundle-id>
```

Build the Release configuration for the measurement:
`xcodebuild -scheme <App>-<platform> -configuration Release -destination "id=$udid" -derivedDataPath ~/Library/Developer/<App>/DerivedData build`.

## Record a trace

```bash
mkdir -p .work/traces
xcrun xctrace record --device "$udid" --template 'Time Profiler' \
  --attach <pid> --time-limit 10s --output .work/traces/<App>-<platform>.trace
```

- The same templates as the Mac: `'Time Profiler'`, `'Hangs'`,
  `'Animation Hitches'`, `'Allocations'`, `'Leaks'`, `'App Launch'`.
  `xcrun xctrace list templates` shows the ones installed.
- To record from launch: `--launch -- <path to the .app>` with
  `--device`. (check: the argument form for a device)
- Read the trace as text (`recipes.md`, "Traces as text"), then delete the
  `.trace` and the XML. They hold the app's environment.

Check: the trace's table of contents lists a run with data for the
template.

## Logs and signposts

```bash
# Simulator: stream the app's log while reproducing. Stop it right after.
xcrun simctl spawn "$udid" log stream --level debug \
  --predicate 'subsystem == "<bundle-id>"' > .work/traces/<App>-log.txt &
log_pid=$!
# ... reproduce ...
kill $log_pid
```

- `OSSignposter` intervals around the slow work (`recipes.md`,
  "Measuring") show by name in any trace. Add the signpost instrument to a
  template with `--instrument 'os_signpost'`. (check)
- On a device, read logs and signposts from a trace, or from Console.app
  with the device selected. `log stream` on the Mac does not see a device.
- The development HTTP debug server (`debug-server-architect`, when the
  session lists it) can return a probe's timings as JSON from a simulator
  or device. That is the quickest before-and-after loop.

## Scroll and animation hitches

A hitch is a frame that shows late. Apple's measure is the hitch time
ratio: milliseconds of hitch per second of scrolling.

| Ratio | Feels |
| --- | --- |
| under 5 ms/s | smooth |
| 5 to 10 ms/s | the user notices now and then |
| over 10 ms/s | the user notices, fix it |

- Record with `--template 'Animation Hitches'` while scrolling the slow
  list on a device. (Simulator hitch numbers are not meaningful.)
- A UI test can measure it on each run:
  `measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) { app.swipeUp() }`.
  (check: metric name for the Xcode in use)
- Usual causes: images decoded at full size on the main thread, a row
  `body` that reads many model properties, shadows and blurs per row, and
  `List` rows that rebuild on every change (`recipes.md`, "Lists and
  SwiftUI updates").

## iOS and iPadOS

- 120 Hz on ProMotion devices halves the frame budget to 8.3 ms. Measure
  on the slowest device the brief supports, not the newest.
- Launch: the system ends an app that takes too long to show its first
  frame (the watchdog, about 20 seconds). Aim for the first frame under
  400 ms. Use the `'App Launch'` template. (check: current watchdog limit)
- Memory: no swap. Past its limit, the system ends the app with no crash
  log in the app (a jetsam event, listed under Settings > Privacy & Security >
  Analytics & Improvements > Analytics Data).
  Extensions (widgets, share, Top Shelf) have much smaller limits than
  apps. Keep them to reading a small store and drawing. (check: current
  extension limits)
- Background work gets seconds, not minutes. Measure a
  `BGAppRefreshTask` by timing it with signposts.
- iPad: test the slowest layout, usually the widest window with the most
  columns, and Split View resizing.

## tvOS

- Focus moves drive scrolling. A row that hitches when focus moves is the
  common bug: big images decoded on the main thread. Decode posters at the
  size shown, off the main thread, and cache them.
- The focused item grows and casts a shadow. Many shadows in a long row
  cost a lot: measure with `'Animation Hitches'` while holding the remote
  to scroll.
- Top Shelf runs in its own extension with a small memory limit. It hands
  image URLs to the system instead of loading images.
- Apple TV hardware varies a lot between models. Measure on the oldest one
  the brief supports.

## watchOS

- The app is on screen for seconds. Launch to first frame is the number
  that matters: show cached data at once, refresh after.
- Memory and CPU are small, and the system ends an app that uses too much
  in the background. A workout session is the only way to keep running
  for long. (check: current memory limits per watch model)
- Battery is the main cost. Count wake-ups: background refreshes, timers,
  Watch Connectivity messages, network calls. Use the `'Energy Log'` or
  `'Activity Monitor'` template on the paired watch. (check: which
  templates support watchOS)
- The simulator says nothing useful about speed, memory, or battery on a
  watch. Every final number comes from a real watch.

## visionOS

- The display runs at 90 Hz, so a frame has about 11 ms. Dropped frames in
  a spatial scene cause discomfort, not only stutter: treat the budget as a
  hard limit.
- RealityKit work shows in the `'RealityKit Trace'` template: frame time,
  entity count, draw calls, and render passes. (check: template name)
- Keep entity counts and texture sizes down. Load assets asynchronously,
  never in `body` or on the main actor.
- SwiftUI windows follow the same rules as iPad. A window that redraws
  every frame wastes the budget the 3D scene needs.
- Thermal limits on the headset lower performance over time. Measure after
  several minutes of use, not only right after launch.

## Numbers from real users

MetricKit (`MXMetricManager`) delivers daily reports from devices in use:
launch time, hang rate, memory, and crash diagnostics. Xcode's Organizer
shows the same data for an app on TestFlight or the App Store. When the
brief's app ships, Claude adds a MetricKit subscriber that logs each
report, so a regression shows before users complain. (check: which
platforms MetricKit supports)

Done when the number for the slow action came from a release build on a
named device or simulator, the report says which, and no trace, log
stream, or launched test app is left running.
