---
name: design-system
description: Accent color and design system for an Apple app on any platform, from the accent and its picker to Swift tokens that resolve per platform plus a design/DESIGN-SYSTEM.md that says which token to use when. Use when the user wants a brand or accent color, wants people to pick a color, when an app has more than a few screens, when screens drift apart or animations feel inconsistent, or when the user asks for themes, a style guide, or design tokens.
---

# Design system

Records: `${user_config.records}` (vault `${user_config.muninn_vault}`). See [CONVENTIONS.md](../../../CONVENTIONS.md), section 8.

A design system is a short list of **tokens** in code and one page that
says which token to use when. Every screen uses tokens, never raw values.
Then a change in one place changes the whole app, on every platform, and
an agent can review a screen against one page.

Start from the platform rules: call the Skill tool with `bama:mac-design`
for macOS and `bama:platform-design` for the other targets. Tokens cover
only what the system does not: the accent, custom surfaces, radii, motion,
overlays, and custom controls.

The app keeps Apple's look. Only the accent color changes. For parts of
the app's own (a custom sidebar, buttons, icons), call the Skill tool with
`bama:design-kit`. To copy the look of an app the user names, call it with
`bama:design-from-app`.

## 0. Read the targets

Read the target platforms from the brief: `docs/BRIEF.md` in `markdown`
mode, or `muninn_recall` with the app's name and "targets" in `muninn`
mode. Every token and rule below applies to each target.

The template already has the base in the app's `UI/` folder:
`Sources/<App>/UI/` in the Mac template, `Shared/UI/` in the
multi-platform template (compiled into every app target; the `<App>Kit`
package holds no SwiftUI):

- `Theme.swift`: the accent colors (`Theme.all`), the saved choice
  (`ThemeStore`), the tokens `Palette.accent`, `Palette.accentText`,
  `Palette.onAccent`, and `.themed()`, which tints every scene.
- The accent picker: `AppearanceSettings.swift` in the Mac template,
  inside `Shared/SettingsView.swift` (macOS only, `#if os(macOS)`) in the
  multi-platform template. Light and dark mode follow the device. Apple advises against
  an app-specific mode setting; add a System/Light/Dark picker only when
  the user asks for one, with System as the default. [HIG Dark Mode]
- `Grid.swift`: spacing (call the Skill tool with `bama:layout-grid`).
- `Platform.swift` in the multi-platform template:
  `Platform.value(mac:phone:pad:tv:watch:vision:)`, the one helper every
  per-platform value goes through.

Check: Claude can name every target and the folder that holds `Theme.swift`.

## 1. Pick the accent

Read `## Look` in the brief (or recall "look" in `muninn` mode).

**macOS.** With no color named, keep `system`: it follows the accent the
person set for their Mac. For a brand color, set `ThemeStore.brand` to a
`Theme` and keep `ThemeStore.defaultID = "system"`. The brand then shows
only while the Mac's accent is Multicolor, as in Apple's apps. Any other
accent the person chose wins, and so do sidebar icons, which people expect
in their own accent. [HIG Color, Sidebars]

**iOS, iPadOS, tvOS, watchOS, visionOS.** These have no system-wide accent
setting, so `system` has nothing to follow. The default is the brand
color, or the system blue when the brief names none. Set it in the
`AccentColor` asset too, so system parts that read the asset match.

A brand `Theme` has three shades: `light` (accent text in dark mode),
`base` (fills and tint), and `deep` (accent text in light mode). Set
`darkText: true` when white text on `base` is hard to read (yellow, mint,
cyan).

Use brand color sparingly: the app icon, an empty state, one hero element
in the content. Keep it off most controls. [HIG Branding]

**Where the picker goes**, per target:

| Target | Picker |
| --- | --- |
| macOS | Settings window (the `Settings` scene), Appearance pane |
| iOS, iPadOS | a Settings screen inside the app (a sheet or a tab), Appearance section; the template has none yet, so Claude adds it |
| tvOS | a Settings screen inside the app, one row per color, focusable |
| visionOS | a Settings window or sheet inside the app |
| watchOS | usually none: the watch keeps the brand, or follows the choice synced from the iPhone app |

To compare colors, take snapshots with `APP_ACCENT=<id>` for two or three
of them, on each target (`tools/snap.sh --platform <id>`), and show the
user the PNGs from `.work/shots/<platform>/`.

Check: on macOS `ThemeStore.defaultID` is "system"; on the other targets
the default is the brand or blue; each target with a picker has it in the
place the table names; the snapshots show the accent on buttons, toggles,
and selection in light and dark mode on every target.

## 2. Collect

New app with no views yet? Skip this step: write the token files with the
defaults below before the first view.

Existing app: read every view. List each raw value: hex colors,
opacities, corner radii, paddings, frame widths, font sizes, animation
durations and curves, custom button styles, and `#if os(...)` blocks that
pick a size. Group them. Most apps have 3 to 5 of each where 1 or 2 are
meant.

Check: every raw value found is in a group, with the file and line.

## 3. Write the tokens

Accent values live in `Theme.swift`. The rest get one file per group in
the `UI/` folder. Add each token when the app first needs it:

| File | Holds |
| --- | --- |
| `Theme.swift` | the accents, `ThemeStore`, `.themed()`, and `Palette`: `accent`, `onAccent` (text and symbols on accent fills), `accentText` (accent-colored text: deep shade in light mode, light shade in dark mode) |
| `Grid.swift` | the spacing scale (`Space`) and the layout probes |
| `Surfaces.swift` | `surface`, `surfaceHover`, `hairline`, one warning color |
| `Radius.swift` | `xs` chips and key caps, `sm` controls, `row` row fills, `md` cards, `lg` widgets, `xl` floating glass |
| `Hit.swift` | the smallest control size per platform (`Hit.minimum`, `Hit.standard`) |
| `Focus.swift` | how a focused or hovered part shows it: tvOS focus growth and room, iPadOS pointer and visionOS hover effects |
| `Layout.swift` | `contentWidth`, fixed column and sheet widths, screen margins |
| `Motion.swift` | `hover`, `quick` (presses, small flips), `ui`, `select` (selection moving through a live list), `appear`, `dismiss`, `glide`, `numberRoll`, `listChange`, loops (`pulse`) that stop under Reduce Motion |
| `Components.swift` | more control styles: `HoverButtonStyle`, `.hoverFill`, toggles, chips |
| `Overlay.swift` | one panel builder, one entrance, one exit |

**One token, one value per platform.** A size that differs per platform
is one token that resolves through the helper. A TV and a Mac never share
a number:

```swift
enum Hit {
    // HIG Accessibility, default control size per platform.
    static let standard: CGFloat = Platform.value(mac: 28, phone: 44, pad: 44, tv: 66, watch: 44, vision: 60)
    // HIG Accessibility, minimum control size per platform.
    static let minimum: CGFloat = Platform.value(mac: 20, phone: 28, pad: 28, tv: 56, watch: 28, vision: 28)
}

enum Radius {
    static let sm: CGFloat = Platform.value(mac: 8, phone: 10, pad: 10, tv: 12, watch: 10, vision: 12)
    static let md: CGFloat = Platform.value(mac: 12, phone: 16, pad: 16, tv: 20, watch: 14, vision: 20)
}
```

The hit sizes above are Apple's. The radii are starting values; set them
from the platform's own system parts. A Mac-only app has no helper: it
uses plain constants.

**Type.** Use text styles (`.body`, `.headline`, `.title`) for every
role. They already resolve per platform and follow Dynamic Type. A custom
size goes through `Platform.value` with a `relativeTo:` text style, so it
still scales.

**Per-platform rules the tokens carry:**

- **tvOS**: screen margins 60 pt top and bottom, 80 pt at the sides, and
  button centers at least 60 pt apart. [HIG Layout] A focused part grows
  and casts a shadow. `Focus.scale` and `Focus.room` say how much and how
  much space every container leaves around it. Never `.clipped()` or
  `.clipShape` around a focusable part or its row; give scroll views
  `.scrollClipDisabled()` or padding inside the content.
- **iPadOS with a pointer, visionOS**: custom controls get a hover effect
  (`.hoverEffect(.highlight)` or `.lift`) so the pointer and gaze show
  what they are on. visionOS never tells the app where people look.
- **watchOS**: always dark. Surfaces are black; a custom color needs only
  its dark value checked.

Surfaces adapt to light and dark. Views read the accent through `.tint` or
`Palette`, so a new choice in Settings redraws the whole app.

Check: every token that differs per platform is one `Platform.value` call
(or one `#if os(...)` block), and no view picks a size with its own
`#if os(...)`.

## 4. Write design/DESIGN-SYSTEM.md

One section per file above. Each section says which token to use when,
and the rules that go with it, with a column per target where values
differ. Keep it under 120 lines. Rules that transfer to most apps:

- Never hard-code a hex accent. Use `.tint` or `Palette.accent`.
- Every custom color has four values: light, dark, and a stronger one of
  each for Increase Contrast (`Color(light:dark:highContrastLight:highContrastDark:)`
  in `Theme.swift`). [HIG Color]
- Never redefine or copy a semantic color (`.separator` as text, a label
  color as a fill). Their values change per release.
- A custom surface in its neutral state is a little translucent, so it
  picks up the tint behind it like system surfaces. A colored state is
  opaque.
- A custom font only for headings. Body and captions stay in the system
  font, and every custom font has a bold weight for the Bold Text setting.
- Accent-colored text uses `Palette.accentText`. Text on an accent fill
  uses `Palette.onAccent`, never a fixed white.
- Style controls with `ButtonStyle` and `ToggleStyle`. Never rebuild a
  control from shapes: it loses the keyboard, focus, and VoiceOver.
- Every control is at least `Hit.minimum` on each target.
- Inner corners are concentric: inner radius = outer radius - inset.
- Every animation goes through `Motion`, so a per-feature "Full, Fast,
  Off" setting and Reduce Motion apply everywhere.
- Search results and switchers do not animate. Speed wins.
- Hover never moves a selection. Only a click, a tap, or a key does. On
  tvOS, focus is not selection either: selecting takes a press.
- Units ("KB/s", "%") never animate. Only the number does
  (`.contentTransition(.numericText())`).
- Never animate a view's first layout. Overlays wait one frame, then
  animate opacity, scale, and a few points of travel.
- Leave room around glass for its shadow (about 3 times the shadow
  radius), and around a tvOS focusable part for its growth.
- One primary button per page or card.

Check: DESIGN-SYSTEM.md has a section for every token file and states the
value per target wherever a value differs.

## 5. Migrate

Replace raw values screen by screen, one commit per screen when the user
asked for commits. After each, build and snapshot every target (call the
Skill tool with `bama:build-and-verify`, or `tools/snap.sh --platform <id>`
per target). The screen looks the same or better on each target, never
worse.

On tvOS, after any change to a focusable part or its container: focus the
first and the last item of each row and column, snapshot, and zoom on the
focused part's four edges in the PNG. The rounded ends and the shadow are
whole. A flat or cut edge means a container clips: give it room.

Check: each migrated screen's snapshots on every target are the same or
better than before, and the tvOS edge check shows no clipped focus.

## 6. Point agents at it

Add one line to the app's `CLAUDE.md` (create the file if it is missing):
"Design rules: `design/DESIGN-SYSTEM.md`. Use its tokens; never raw colors,
radii, sizes, or durations. Per-platform values go through
`Platform.value`."

Check: the app's `CLAUDE.md` has that line.

Done when this finds no hits outside the token files:

```bash
grep -rnE 'cornerRadius: [0-9]{1,2}\b|duration: [0-9]|\.spring\(response|\.snappy\b|\.easeInOut|\.easeOut\(|Color\(hex:|Color\(red:|\.font\(\.system\(size' Sources/ \
  | grep -v 'Path(roundedRect'
```

(in the multi-platform template, run it on `Shared/` too; hex strings in data and comments are fine), DESIGN-SYSTEM.md has a
section for every token file with per-target values, every target's
snapshots show the accent and the picker where the table in step 1 puts
it, and the tvOS focus edge check passes when tvOS is a target.
