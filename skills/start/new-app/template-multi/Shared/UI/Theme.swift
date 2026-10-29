import SwiftUI

/// One accent color in three shades. Everything else is Apple's look.
/// On the Mac, people pick the accent in Settings (SettingsView.swift).
/// Light and dark mode follow the device: there is no app-specific mode setting.
///   APP_ACCENT=mint     run with another accent, to compare
struct Theme: Identifiable, Hashable {
    struct Shades: Hashable {
        let light: UInt32
        let base: UInt32
        let deep: UInt32
    }

    let id: String
    let name: String
    /// nil follows the system accent color.
    let shades: Shades?
    /// Text on the accent: white, or dark ink for bright accents like yellow.
    var darkText = false

    /// For `.tint`. nil keeps the system accent.
    var tint: Color? { shades.map { Color(hex: $0.base) } }
    /// The flat accent color.
    var accent: Color { tint ?? .accentColor }
    /// Accent-colored text and symbols on a plain background: the deep shade
    /// in light mode, the light shade in dark mode, so both read.
    var accentText: Color { shades.map { Color(light: $0.deep, dark: $0.light) } ?? .accentColor }
    /// Text and symbols on an accent fill.
    var onAccent: Color { darkText ? Color(hex: 0x16161C) : .white }

    static let all: [Theme] = [
        Theme(id: "system", name: "System", shades: nil),
        Theme(id: "blue", name: "Blue", shades: .init(light: 0x7CC0FF, base: 0x0A84FF, deep: 0x0064D2)),
        Theme(id: "indigo", name: "Indigo", shades: .init(light: 0xA5ADFF, base: 0x5E6AD2, deep: 0x4650B8)),
        Theme(id: "pink", name: "Pink", shades: .init(light: 0xFF9CCB, base: 0xE84A93, deep: 0xC0306F)),
        Theme(id: "orange", name: "Orange", shades: .init(light: 0xFFB87A, base: 0xF97316, deep: 0xC2410C)),
        Theme(id: "mint", name: "Mint", shades: .init(light: 0x8EEBC4, base: 0x2BC48A, deep: 0x0F7A55), darkText: true),
        Theme(id: "graphite", name: "Graphite", shades: .init(light: 0xC7C7CC, base: 0x7C7C84, deep: 0x55555C)),
    ]
}

/// The chosen accent, saved in UserDefaults. Views that read `theme` redraw
/// when it changes.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    /// The accent the app ships with. Keep "system" to follow the device.
    static let defaultID = "system"

    var themeID: String {
        didSet { UserDefaults.standard.set(themeID, forKey: "appearance.accent") }
    }

    var theme: Theme { Theme.all.first { $0.id == themeID } ?? Theme.all[0] }

    private init() {
        themeID = ProcessInfo.processInfo.environment["APP_ACCENT"]
            ?? UserDefaults.standard.string(forKey: "appearance.accent") ?? Self.defaultID
    }
}

/// Accent tokens for views. Never hard-code an accent hex in a view.
enum Palette {
    static var accent: Color { ThemeStore.shared.theme.accent }
    static var accentText: Color { ThemeStore.shared.theme.accentText }
    static var onAccent: Color { ThemeStore.shared.theme.onAccent }
}

extension View {
    /// Applies the chosen accent to everything below. Put it on every scene's root.
    func themed() -> some View {
        modifier(Themed())
    }
}

private struct Themed: ViewModifier {
    private var store = ThemeStore.shared

    func body(content: Content) -> some View {
        content.tint(store.theme.tint)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// A color with a light and a dark value: Color(light: 0x0064D2, dark: 0x7CC0FF).
    /// Apple Watch is always dark, so it gets the dark value.
    init(light: UInt32, dark: UInt32) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            NSColor(Color(hex: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light))
        })
        #elseif os(watchOS)
        self.init(hex: dark)
        #else
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #endif
    }
}
