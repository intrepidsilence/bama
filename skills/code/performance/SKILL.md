---
name: performance
description: Make an Apple app fast on every platform by measuring hangs, stutter, scroll hitches, CPU, memory, and energy, then moving work off the main thread and onto the GPU. Use when the app freezes, a shortcut feels slow, scrolling or dragging stutters, the fan spins or the battery drains, memory grows, or the user asks to optimize or profile.
---

# Performance

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

Fast means two numbers: the first frame after a key press or tap shows in
under 100 ms, and nothing on the main thread blocks for more than 50 ms.
Scrolling and animation also stay inside the frame budget of the screen
(table below). Every change in this skill starts and ends with a
**measurement**, so the numbers show it helped.

Symptom-by-symptom fixes are in [recipes.md](recipes.md). For video, audio,
camera, Metal, or large image pipelines, also read
[gpu-media.md](gpu-media.md). For iOS, iPadOS, tvOS, watchOS, and visionOS,
read [platforms.md](platforms.md): how to record on a simulator or device,
and the limits of each platform.

When the session lists `swiftui-performance-audit`, Claude calls it after
the measurement points at SwiftUI view updates, for a code-level review.
BAMA measures first.

| Platform | Frame budget | Where to measure the final number |
| --- | --- | --- |
| macOS | 16.7 ms at 60 Hz, 8.3 ms on a 120 Hz display | the installed release build |
| iOS, iPadOS | 16.7 ms, 8.3 ms on ProMotion devices | a device |
| tvOS | 16.7 ms at 60 Hz | a device |
| watchOS | 16.7 ms, plus short run time and small memory | a device |
| visionOS | about 11 ms at 90 Hz | a device |

Simulator numbers are not device numbers. A simulator runs on the Mac's
CPU and GPU, with the Mac's memory and no heat limits. Use a simulator to
compare two versions of the same code. Report the final number from a
device, and say which one.

## The loop

```text
reproduce -> measure (release build) -> find the line -> fix -> measure again -> commit with the numbers
```

1. **Reproduce.** Write the exact steps, or add a probe command to the
   debug bridge (`bama:test-app`; on other platforms the HTTP debug
   server) that runs the slow action and logs the time of each step.
   Check: the steps make the slow action happen every time.
2. **Measure the release build.** Debug Swift is 3 to 10 times slower and
   points at the wrong code. Check: the build is the Release
   configuration, and the number is written down with the platform and
   device.
3. **Find the line.** Pick the tool for the symptom. On the Mac:

   | Symptom | Tool |
   | --- | --- |
   | App freezes, spinning pointer | `sample <App> 5`, then read the main thread stack |
   | Slow action | Time Profiler: `xcrun xctrace record --template 'Time Profiler' --attach <App> --time-limit 10s --output .work/traces/<App>.trace` |
   | Short freezes while typing or dragging | `--template 'Hangs'` |
   | Stutter while moving or animating | `--template 'Animation Hitches'` |
   | Memory grows | `footprint <App>`, `leaks <App>`, `--template 'Allocations'` |
   | Fan, battery | `--template 'Energy Log'`, look for timers and polling |

   On a simulator or device, the same templates run with `--device <udid>`
   ([platforms.md](platforms.md)).

   Traces go in `.work/traces/`. Read them as text, not in the Instruments
   GUI: see "Measuring" in [recipes.md](recipes.md). Delete every `.trace`
   after reading. A trace stores the app's full environment, and an app
   opened from an agent's shell inherits that shell's tokens. Never commit
   or share one. Check: Claude can name the function that takes the time.

4. **Fix** with the matching recipe. Check: the change touches the line
   the trace named, nothing else.
5. **Measure again** with the same steps on the same device. Put before and
   after in the commit message: "Picker opens in 40 ms, was 600 ms (Mac
   Studio, release)". Check: the after number meets the budget.
6. **Keep the lesson.** When the cause is one that could come back (a
   blocking call, an API trap), Claude adds a fix log entry with a `Rule:`
   line, in the place the `Records:` line above names (CONVENTIONS section 8).
   Check: the entry names the symptom, the cause, and the rule.

Recording stops when the measurement ends: no `xctrace`, `log stream`, or
test copy of the app stays running, and `.work/traces/` is empty.

## The rules that fix most problems

- **Main thread does UI only.** File, network, database, image decoding,
  Accessibility calls, and audio go elsewhere. A main-thread call that waits
  on another process (CoreAudio, AX) can freeze the app for minutes.
- **Show first, work after.** Put the window, panel, or page on screen in
  the same frame as the key press or tap, then load. Never make the UI wait
  for the work.
- **Let the GPU composite.** Large images go in a `CALayer` once. Pointer
  movement changes only small layers. Never redraw a full-screen picture per
  mouse event.
- **Decode at display size.** ImageIO thumbnails, cached in `NSCache`.
  On tvOS a 4K poster row decoded at full size is the usual scroll hitch.
- **Do not animate what must be fast.** Search results and switchers
  update in place.
- **No polling without a reason.** Timers get a tolerance and stop when
  nothing on screen needs them. On iPhone and Apple Watch the battery pays
  for every wake-up.

## Apple silicon notes

- Core Animation, Core Image (one shared `CIContext`), Vision, and
  AVFoundation already run on the GPU or the Neural Engine. Hand them the
  work instead of looping over pixels in Swift.
- Write Metal (`MTKView`, compute shaders) only when a measurement shows
  Core Animation or Core Image is too slow. Most apps never need it.
- Unified memory means a `CGImage` from ScreenCaptureKit passes to a layer
  without a copy. Keep it as a `CGImage` or `IOSurface`. Converting to
  `NSImage` or `UIImage` and back costs copies.

Done when the slow action has a measured before and after on a named
device, the after meets the two numbers at the top and the platform's frame
budget, the commit message names both, and nothing Claude started to
measure is still running.
