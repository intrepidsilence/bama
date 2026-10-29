# Kit parts in SwiftUI

Code for each step of [SKILL.md](SKILL.md). The blocks below, joined into
one file with a `Platform` helper, type-check with Swift 6 and main-actor
default isolation (the `bama:new-app` templates) against the macOS, iOS,
tvOS, watchOS, and visionOS 26 SDKs. Rename `Kit` types freely; keep the
layers.

`Platform.value(mac:phone:pad:tv:watch:vision:)` comes from the
multi-platform template (`Shared/UI/Platform.swift`), which also has its
own `Color(light:dark:)` in `Shared/UI/Theme.swift`: keep one of the two. A Mac-only app replaces each call with its `mac:`
value.

## Contents

- Tokens
- Type
- Part states, hover, and focus
- Buttons
- Checkbox as a Toggle
- Fields
- Sidebar rows
- List rows
- Icons
- Window chrome (macOS)
- Gallery

## Tokens

```swift
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Layer 1: raw colors. Only this file reads Palette.
enum Palette {
    static let gray50 = Color(hex: 0xF9FBFC)
    static let gray900 = Color(hex: 0x202020)
    static let blue100 = Color(hex: 0xDFEDFA)
    static let blue600 = Color(hex: 0x287ABC)
    static let night = Color(hex: 0x1E1F22)
    static let snow = Color(hex: 0xF2F2F2)
}

// Layer 2: meaning, with a light and a dark value. Parts read only this.
enum Ink {
    static let text = Color(light: Palette.gray900, dark: Palette.snow)
    static let sidebar = Color(light: Palette.gray50, dark: Palette.night)
    static let accent = Palette.blue600
    static let selection = Color(light: Palette.blue100, dark: Palette.blue600.opacity(0.25))
}

// Layer 3: scales. Every size that differs per platform goes through Platform.value.
enum Metric {
    /// Row and button height: the platform's default control size (HIG Accessibility).
    static let rowHeight: CGFloat = Platform.value(mac: 28, phone: 44, pad: 44, tv: 66, watch: 44, vision: 60)
    static let rowInset: CGFloat = Platform.value(mac: 8, phone: 16, pad: 16, tv: 24, watch: 8, vision: 16)
    static let radius: CGFloat = Platform.value(mac: 6, phone: 10, pad: 10, tv: 12, watch: 10, vision: 12)
    /// How much a focused part grows. Only tvOS grows; its containers leave room for it.
    static let focusScale: CGFloat = Platform.value(mac: 1, phone: 1, pad: 1, tv: 1.08, watch: 1, vision: 1)
    /// Room around a part for the focus growth and its shadow.
    static let focusRoom: CGFloat = Platform.value(mac: 0, phone: 0, pad: 0, tv: 24, watch: 0, vision: 0)
}

enum Motion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// A color that follows light and dark mode. watchOS is always dark.
    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #elseif os(watchOS)
        self = dark
        #else
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #endif
    }
}
```

The hit sizes (`rowHeight`) are Apple's default control sizes. The insets,
radii, and focus numbers are starting values: tune them in `design/KIT.md`.

## Type

```swift
enum KitType {
    case title, body, label, labelStrong, meta

    /// Text styles scale per platform and with Dynamic Type on their own.
    var font: Font {
        switch self {
        case .title: .title.bold()
        case .body, .label: .body
        case .labelStrong: .body.weight(.semibold)
        case .meta: .caption
        }
    }
}

extension View {
    func kitType(_ type: KitType) -> some View { font(type.font) }
}
```

A measured or bundled size keeps scaling with Dynamic Type when it names a
text style: `Font.custom("Inter-Medium", size: Metric.bodySize, relativeTo: .body)`,
with `bodySize` one `Platform.value` in `Metric`. A bare
`.system(size:)` stays fixed.

## Part states, hover, and focus

Every part computes one state. The gallery forces it, so hover, pressed,
and focused show up in a snapshot.

```swift
enum PartState: String, CaseIterable {
    case rest, hover, pressed, selected, focused, disabled
}

extension EnvironmentValues {
    @Entry var forcedPartState: PartState?
}

extension View {
    /// Pointer hover, where the platform has a pointer. tvOS and watchOS have none.
    func kitHover(_ hovering: Binding<Bool>) -> some View {
        #if os(macOS) || os(iOS) || os(visionOS)
        onHover { hovering.wrappedValue = $0 }
        #else
        self
        #endif
    }

    /// The system highlight for an iPad pointer and for gaze on visionOS.
    func kitHoverEffect() -> some View {
        #if os(iOS) || os(visionOS)
        hoverEffect(.highlight)
        #else
        self
        #endif
    }
}
```

Per platform:

- **macOS, iPadOS with a keyboard**: focused draws the kit's ring. Add
  `.focusEffectDisabled()` at the root so the system ring does not draw
  over it.
- **tvOS**: focused grows by `Metric.focusScale` and casts a shadow. The
  part keeps `Metric.focusRoom` free on every side: no `.clipped()` or
  `.clipShape` around it, and `.scrollClipDisabled()` on the scroll view
  that holds it.
- **visionOS**: the app never learns where people look. `.kitHoverEffect()`
  lets the system draw the highlight.

## Buttons

A real `Button` with a `ButtonStyle`: the keyboard, focus, the remote, and
VoiceOver work.

```swift
struct KitButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        KitButtonBody(configuration: configuration, kind: kind)
    }
}

extension ButtonStyle where Self == KitButtonStyle {
    static func kit(_ kind: KitButtonStyle.Kind = .primary) -> KitButtonStyle { KitButtonStyle(kind: kind) }
}

private struct KitButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: KitButtonStyle.Kind
    @Environment(\.forcedPartState) private var forced
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var hovering = false

    private var state: PartState {
        forced ?? (!isEnabled ? .disabled : configuration.isPressed ? .pressed
            : hovering ? .hover : isFocused ? .focused : .rest)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
        configuration.label
            .kitType(.labelStrong)
            .padding(.horizontal, Metric.rowInset)
            .frame(minHeight: Metric.rowHeight)
            .foregroundStyle(kind == .primary ? AnyShapeStyle(.white) : AnyShapeStyle(Ink.text))
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Ink.accent, lineWidth: state == .focused && Metric.focusScale == 1 ? 2 : 0))
            .contentShape(shape)
            .kitHoverEffect()
            .opacity(state == .disabled ? 0.4 : 1)
            .scaleEffect(state == .pressed ? 0.98 : state == .focused ? Metric.focusScale : 1)
            .shadow(color: .black.opacity(state == .focused && Metric.focusScale > 1 ? 0.35 : 0), radius: 12, y: 8)
            .animation(Motion.press, value: state)
            .kitHover($hovering)
    }

    private var fill: Color {
        switch kind {
        case .primary: Ink.accent.opacity(state == .hover ? 0.9 : state == .pressed ? 0.8 : 1)
        case .secondary: Ink.selection.opacity(state == .hover || state == .pressed || state == .focused ? 1 : 0.6)
        case .ghost: state == .hover || state == .pressed || state == .focused ? Ink.selection : .clear
        }
    }
}
```

Use it: `Button("Add Task", action: add).buttonStyle(.kit())`.

## Checkbox as a Toggle

A custom check is a `ToggleStyle`, so it stays a real toggle.

```swift
struct RoundCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle().strokeBorder(Ink.text.opacity(0.4), lineWidth: 1)
                    if configuration.isOn {
                        Circle().fill(Ink.accent)
                        Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(.white)
                    }
                }
                .frame(width: Metric.rowHeight * 0.55, height: Metric.rowHeight * 0.55)
                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Checked" : "Unchecked")
    }
}
```

## Fields

`TextFieldStyle` cannot be written outside Apple's code, so style a plain
field with a modifier. On tvOS and watchOS a text field opens the system's
own entry screen; the kit styles only the field's resting look.

```swift
struct KitField: ViewModifier {
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .kitType(.body)
            .focused($focused)
            .padding(.horizontal, Metric.rowInset)
            .frame(minHeight: Metric.rowHeight)
            .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Ink.selection.opacity(0.4)))
            .overlay(RoundedRectangle(cornerRadius: Metric.radius)
                .strokeBorder(focused ? Ink.accent : .clear, lineWidth: 1.5))
    }
}
```

Use it: `TextField("Task name", text: $name).modifier(KitField())`.

## Sidebar rows

`KitRowStyle` styles a row on every platform. Where the rows live differs:

- **macOS**: a custom sidebar replaces `List`, so it adds back what `List`
  gave: arrow keys and selection for VoiceOver (`KitSidebar` below).
- **iOS, iPadOS, visionOS**: keep `NavigationSplitView` with
  `List(selection:)` and style the rows; the system keeps swipe back,
  pointer, and gaze.
- **tvOS**: the rows are buttons in a `VStack` or `List`; the focus engine
  moves between them. Wrap the column in `.focusSection()` and decide
  where focus enters it (call the Skill tool with `bama:platform-design`).

```swift
#if os(macOS)
struct KitSidebar: View {
    let items: [String]
    @Binding var selection: String

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button(item) { selection = item }
                    .buttonStyle(KitRowStyle(isSelected: item == selection))
                    .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            guard let index = items.firstIndex(of: selection) else { return }
            switch direction {
            case .up: selection = items[max(index - 1, 0)]
            case .down: selection = items[min(index + 1, items.count - 1)]
            default: break
            }
        }
    }
}
#endif

struct KitRowStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration, isSelected: isSelected)
    }

    private struct RowBody: View {
        let configuration: Configuration
        let isSelected: Bool
        @Environment(\.forcedPartState) private var forced
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var hovering = false

        var body: some View {
            let state = forced ?? (!isEnabled ? .disabled : isFocused && Metric.focusScale > 1 ? .focused
                : isSelected ? .selected : configuration.isPressed ? .pressed : hovering ? .hover : .rest)
            let shape = RoundedRectangle(cornerRadius: Metric.radius)
            configuration.label
                .kitType(.label)
                .foregroundStyle(state == .selected ? Ink.accent : Ink.text)
                .padding(.horizontal, Metric.rowInset)
                .frame(maxWidth: .infinity, minHeight: Metric.rowHeight, alignment: .leading)
                .background(shape.fill(state == .selected || state == .focused ? Ink.selection
                    : state == .hover || state == .pressed ? Ink.selection.opacity(0.5) : .clear))
                .overlay(shape.strokeBorder(Ink.accent, lineWidth: state == .focused && Metric.focusScale == 1 ? 2 : 0))
                .contentShape(.rect)
                .kitHoverEffect()
                .opacity(state == .disabled ? 0.4 : 1)
                .scaleEffect(state == .focused ? Metric.focusScale : 1)
                .shadow(color: .black.opacity(state == .focused && Metric.focusScale > 1 ? 0.35 : 0), radius: 12, y: 8)
                .kitHover($hovering)
                .animation(Motion.hover, value: state)
                .padding(.horizontal, Metric.rowInset)
        }
    }
}
```

The trailing `.padding` is the row's room: on tvOS the focused row grows
into it, so keep `Metric.rowInset` at least `Metric.focusRoom` there.

## List rows

Rows draw their own divider, inset to where the text starts.

```swift
struct KitListRow: View {
    let title: String
    @Binding var done: Bool

    var body: some View {
        Toggle(isOn: $done) { Text(title).kitType(.body).foregroundStyle(Ink.text) }
            .toggleStyle(RoundCheckboxStyle())
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Ink.text.opacity(0.08)).frame(height: 0.5).padding(.leading, 24)
            }
    }
}
```

## Icons

Views name a `KitIcon`. The set maps each name to an SF Symbol or to a
drawn shape, in one place. The size is one value per platform.

```swift
enum KitIcon {
    case inbox, today, search, custom(KitGlyph)

    var symbol: String? {
        switch self {
        case .inbox: "tray"
        case .today: "calendar"
        case .search: "magnifyingglass"
        case .custom: nil
        }
    }
}

struct KitIconView: View {
    let icon: KitIcon
    var size: CGFloat = Platform.value(mac: 14, phone: 20, pad: 20, tv: 32, watch: 18, vision: 20)
    var filled = false

    var body: some View {
        Group {
            if case .custom(let glyph) = icon {
                glyph.stroke(style: StrokeStyle(lineWidth: size / 11, lineCap: .round, lineJoin: .round))
            } else if let name = icon.symbol {
                Image(systemName: filled ? name + ".fill" : name).font(.system(size: size, weight: .light))
            }
        }
        .frame(width: size, height: size)
    }
}

/// An icon of the app's own: an SVG path from a 24 x 24 box, scaled to any size.
/// This one is a tray: copy the numbers from the SVG's `d` attribute.
/// `nonisolated`: Shape's methods run off the main actor.
nonisolated struct KitGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 3, y: 13))
        path.addLine(to: CGPoint(x: 8, y: 13))
        path.addLine(to: CGPoint(x: 10, y: 16))
        path.addLine(to: CGPoint(x: 14, y: 16))
        path.addLine(to: CGPoint(x: 16, y: 13))
        path.addLine(to: CGPoint(x: 21, y: 13))
        path.addRoundedRect(in: CGRect(x: 3, y: 5, width: 18, height: 14), cornerSize: CGSize(width: 3, height: 3))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
```

Use `.custom(KitGlyph())` for a drawn icon. A set of drawn icons is one
`Shape` per icon, all on the same 24 x 24 box, with the stroke scaled to
the size.

## Window chrome (macOS)

Hide the title bar, keep the traffic lights, and move them where the kit
wants them. SwiftUI has no API for the position, so this reaches the
`NSWindow`. Other platforms keep the system bars.

```swift
#if os(macOS)
struct WindowChrome: NSViewRepresentable {
    var firstButtonCenter = CGPoint(x: 20, y: 20)
    var buttonSpacing: CGFloat = 20

    func makeNSView(context: Context) -> NSView {
        let view = ChromeView()
        view.configure = configure
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func configure(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        for (index, type) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
            guard let button = window.standardWindowButton(type), let container = button.superview else { continue }
            let x = firstButtonCenter.x + CGFloat(index) * buttonSpacing
            button.setFrameOrigin(NSPoint(x: x - button.frame.width / 2,
                                          y: container.frame.height - firstButtonCenter.y - button.frame.height / 2))
        }
    }

    private final class ChromeView: NSView {
        var configure: ((NSWindow) -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self] in self?.configure?(window) }
            // AppKit moves the buttons back on resize.
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification,
                                                              object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.configure?(window) }
            }
        }
    }
}
#endif
```

In the Mac App:

```swift
Window("Tasks", id: "main") {
    ContentView()
        .ignoresSafeArea()
        .background(WindowChrome())
        .focusEffectDisabled()
}
.windowStyle(.hiddenTitleBar)
.defaultSize(width: 1000, height: 742)
.restorationBehavior(.disabled)
```

Set the size with `.defaultSize`, not a fixed `.frame`: with a hidden title
bar a fixed frame makes the window taller by the title bar's height, and a
window that cannot resize grays out the green button.

## Gallery

Every part in every state, light and dark. Show it instead of the app
when `APP_KIT_GALLERY=1`, then snapshot each target with
`APP_KIT_GALLERY=1 tools/snap.sh --platform <id>` after
`./build.sh --platform <id>`. The gallery scrolls both
ways, so a phone or a watch can show the wide state grid, and it never
clips, so the tvOS focused column shows its full growth.

```swift
struct KitGallery: View {
    static let enabled = ProcessInfo.processInfo.environment["APP_KIT_GALLERY"] == "1"
    @State private var done = false
    @State private var name = ""
    private let gap: CGFloat = Platform.value(mac: 24, phone: 16, pad: 24, tv: 48, watch: 8, vision: 24)

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: gap) {
                Grid(alignment: .leading, horizontalSpacing: gap, verticalSpacing: gap) {
                    GridRow {
                        Text("")
                        ForEach(PartState.allCases, id: \.self) { Text($0.rawValue).kitType(.meta) }
                    }
                    row("Primary") { Button("Add Task") {}.buttonStyle(.kit()) }
                    row("Secondary") { Button("Plan Week") {}.buttonStyle(.kit(.secondary)) }
                    row("Ghost") { Button("Cancel") {}.buttonStyle(.kit(.ghost)) }
                    row("Row") { Button("Inbox") {}.buttonStyle(KitRowStyle(isSelected: false)).frame(width: Metric.rowHeight * 6) }
                }
                Text("Controls").kitType(.labelStrong)
                KitListRow(title: "Write the launch post", done: $done)
                TextField("Task name", text: $name).modifier(KitField())
            }
            // Room for tvOS focus growth on every side, inside the scroll content.
            .padding(gap + Metric.focusRoom)
        }
        .scrollClipDisabled()
    }

    private func row(_ name: String, @ViewBuilder part: @escaping () -> some View) -> some View {
        GridRow {
            Text(name).kitType(.label)
            ForEach(PartState.allCases, id: \.self) { state in
                part()
                    .environment(\.forcedPartState, state)
                    .disabled(state == .disabled)
            }
        }
    }
}
```

In the App: `if KitGallery.enabled { KitGallery() } else { ContentView() }`.
