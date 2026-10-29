#if os(macOS)
import SwiftUI

/// The Mac's Settings window (Command-Comma): one grouped Form that sizes to
/// its content. When it grows past one topic, split it into tabs like the
/// Mac-only template's SettingsView.
/// iPhone, iPad, Apple TV, Watch, and Vision Pro have no Settings window:
/// put settings there in a page of the app (`bama:platform-design`).
struct SettingsView: View {
    @AppStorage("confirmDelete") private var confirmDelete = true
    @Bindable private var themes = ThemeStore.shared
    @State private var height: CGFloat?

    var body: some View {
        Form {
            Section("Items") {
                Toggle("Ask before deleting items", isOn: $confirmDelete)
            }
            Section("Appearance") {
                Picker("Accent color", selection: $themes.themeID) {
                    ForEach(Theme.all) { Text($0.name).tag($0.id) }
                }
            }
        }
        .formStyle(.grouped)
        // Sized to the content, so the window shows no scroll bar it does not need.
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height.rounded(.up) } action: { _, new in
            if abs(new - (height ?? 0)) >= 1 { height = new }
        }
        .frame(width: 460, height: height)
        .scrollBounceBehavior(.basedOnSize)
    }
}
#endif
