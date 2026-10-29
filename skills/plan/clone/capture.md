# Capturing a reference app on each platform

Claude reads only the sections for the platforms it captures.

## Computer use setup

Computer use lets Claude see the Mac's screen and click and type. Mac and
iPhone captures need it.

Requirements: a Pro or Max plan, macOS, and Claude Code signed in with a
claude.ai account.

1. **Claude Code CLI**: the user runs `/mcp` in an interactive session,
   selects `computer-use`, and chooses Enable. It stays on for this
   project. **Claude desktop**: Settings > This computer > Enable computer
   use.
2. The user grants the terminal app (Terminal, iTerm, Ghostty, or the
   Claude app) **Accessibility** and **Screen Recording** in System
   Settings > Privacy & Security (macOS 27 calls the pane just
   **Privacy**). Claude can open each list directly:

   ```bash
   open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
   open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
   ```

   The app may need a restart after.
3. Each session, Claude asks for access to the reference app only (and
   iPhone Mirroring for an iPhone app). The user approves each app.
   Browsers are view-only and terminals are click-only for computer use.

Check: the `mcp__computer-use__*` tools are in the session, and one
`window-shot.sh` capture of the reference app is a non-empty PNG. If the
script says "capture failed", Screen Recording is missing for the terminal.

## Mac

Claude opens the app, walks it with computer use, and saves each screen
with `scripts/window-shot.sh "<App Name>" <out.png>`. The app name is the
one in the menu bar.

## iPhone, through iPhone Mirroring

iPhone Mirroring shows the user's iPhone in a Mac window. Claude drives
that window with computer use: a click is a tap, a scroll is a swipe, and
typing goes to the phone.

- Needs: iOS 18 or later, macOS 15 or later, an Apple silicon Mac (or one
  with a T2 chip), the same Apple Account on both, Bluetooth and Wi-Fi on,
  and the iPhone locked and nearby. Not available in every region (it was
  not in the EU at launch).
- The menu shortcuts help: Command-1 Home Screen, Command-2 App Switcher,
  Command-3 Spotlight. Claude opens the reference app from Spotlight.
- Capture: `scripts/window-shot.sh "iPhone Mirroring" docs/screens/ios/<NN-page>.png`.
  The shot is the mirrored window at the Mac's resolution, which can
  differ from the phone's own pixels. Claude compares layout, not pixel
  sizes, against these shots.
- Limits: no camera, no Face ID prompts, some apps block mirroring (often
  banking, video, and DRM apps show a blank screen), and the phone cannot
  be used while mirrored. For a screen that will not mirror, Claude asks
  the user for a screenshot from the phone (side button and volume up
  together) and an AirDrop to the Mac.

## iPad

There is no iPad mirroring. Claude picks one:

1. **The app's Mac or iPad build on Apple silicon.** Many iPad apps install
   from the Mac App Store and run in a Mac window ("Designed for iPad").
   Claude walks it like a Mac app. The layout is the iPad layout at the
   window's size, not a real iPad screen: Claude notes that in INDEX.md.
2. **The user's screenshots.** Claude gives the walk list from SKILL.md
   step 4 with the app's page names. The user presses the top button and
   volume up together on the iPad, and AirDrops the shots to the Mac (or
   lets iCloud Photos sync them). Claude moves them into
   `docs/screens/ipados/` and renames them in walk order.

## Web

Claude uses a browser tool (the built-in browser, Claude in Chrome, or
Playwright) and saves each screenshot with the tool's file path option.
For a site with a phone layout, Claude also captures at a phone width
into `docs/screens/ios/`.

## Apple TV, Apple Watch, Vision Pro

Claude cannot drive these devices. Claude gives the user the walk list
from SKILL.md step 4, with the app's page names, and asks for the shots:

| Device | How the user takes a screenshot |
| --- | --- |
| Apple TV | On the Mac, Xcode > Window > Devices and Simulators. Select the Apple TV (paired with Xcode on the same network), open the app on the TV, and click Take Screenshot. The shot lands on the Mac's desktop. |
| Apple Watch | On the iPhone, Watch app > General > Enable Screenshots (once). Then press the side button and the Digital Crown together. The shot appears in the iPhone's Photos; AirDrop it to the Mac. |
| Vision Pro | Press the top button and the Digital Crown together, or use Control Center > Capture. The shot goes to Photos; AirDrop it to the Mac or let iCloud Photos sync it. A shot shows the user's surroundings: suggest a plain room or an Environment. |

The user drops the files in `docs/screens/<platform>/` or names a folder.
Claude renames them to `NN-page-or-state.png` in walk order, and asks for
any page on the list that has no shot yet.

## Keep screenshots private

Screenshots of a reference app stay in `docs/screens/` as working files,
and stay out of public repos: `docs/screens/**/*.png` goes in
`.gitignore`, and Claude stages only named paths (CONVENTIONS section 7).
