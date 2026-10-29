import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

// __APP_NAME__ runs on every device in tools/platforms, from one set of sources.
//   APP_STORE=<file>            use another database (tests, experiments)
//   APP_SEED=1                  fill an empty test store with sample items (tools/snap.sh)
//   --selftest                  run the self-test on a test store and quit with 0 or 1 (tools/selftest.sh)
//   APP_SNAPSHOT=<dir>          Mac: save a PNG of every page and Settings in light and dark, then quit
//   APP_SNAPSHOT_PAGE=<page>    other devices: show one page and print "SNAPSHOT ready"; tools/snap.sh takes the screenshot
//   APP_APPEARANCE=light|dark   other devices: force light or dark (tools/snap.sh)
//   APP_ACCENT=<id>             run with another accent from Theme.all (UI/Theme.swift)
// Snapshots, seed data, and the self-test need APP_STORE set to a test file
// (the scripts use .work/ in the project), never the real data folder.

@main
struct __APP_NAME__App: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #endif
    @State private var model = AppModel(container: Store.makeContainer())

    init() {
        // Test runs print each line at once, so a script reading the output
        // sees it, and a crash keeps the lines before it.
        if Store.isOverridden { setvbuf(stdout, nil, _IOLBF, 0) }
    }

    var body: some Scene {
        #if os(macOS)
        Window("__APP_NAME__", id: "main") {
            root.frame(minWidth: 760, minHeight: 480)
        }
        .modelContainer(model.container)
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Item") { model.addItem() }
                    .keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
        #else
        WindowGroup {
            root
        }
        .modelContainer(model.container)
        #endif
    }

    private var root: some View {
        ContentView()
            .environment(model)
            .themed()
            .forcedAppearance()
    }
}

extension View {
    /// APP_APPEARANCE=light|dark forces the mode, for snapshots on devices
    /// whose simulator has no appearance switch.
    @ViewBuilder
    func forcedAppearance() -> some View {
        switch ProcessInfo.processInfo.environment["APP_APPEARANCE"] {
        case "light": preferredColorScheme(.light)
        case "dark": preferredColorScheme(.dark)
        default: self
        }
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Started from a terminal, the process is not a foreground app yet.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
#endif
