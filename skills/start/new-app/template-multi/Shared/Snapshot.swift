import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
import IOKit.pwr_mgt
#endif

/// Screenshot mode for agents. tools/snap.sh drives it on every platform and
/// writes .work/shots/<platform>/<page>-<light|dark>.png.
///
/// The pages: every SidebarItem, plus "detail" (the first item opened).
///
/// Mac: the app takes its own screenshots, then quits.
///   APP_STORE=.work/test.store APP_SEED=1 APP_SNAPSHOT=.work/shots/macos ~/Applications/__APP_NAME__.app/Contents/MacOS/__APP_NAME__
///   Also writes settings-light.png and settings-dark.png.
///   APP_SNAPSHOT_PAGES=all,settings limits the pages.
///
/// Other devices: the simulator takes the screenshot. The app shows one page,
/// prints "SNAPSHOT ready <page>", and waits for tools/snap.sh to capture and
/// quit it. APP_SNAPSHOT_PAGE=list prints "SNAPSHOT pages all,starred,detail" and quits.
///
/// Add a page: add a case to SidebarItem, or a name to `extraPages` and a
/// branch in `show(_:model:)`.
enum Snapshot {
    static let extraPages = ["detail"]
    static var pages: [String] { SidebarItem.allCases.map(\.rawValue) + extraPages }

    /// True during a snapshot run. Views use it to show a steady state
    /// (Apple TV focuses the first card).
    static var isRunning: Bool {
        let env = ProcessInfo.processInfo.environment
        return !(env["APP_SNAPSHOT"] ?? "").isEmpty || !(env["APP_SNAPSHOT_PAGE"] ?? "").isEmpty
    }

    /// Puts the app on one page.
    static func show(_ page: String, model: AppModel) {
        if let item = SidebarItem(rawValue: page) {
            model.page = item
            model.selection = nil
            model.paths = [:]
        } else if page == "detail" {
            model.page = .all
            let first = try? model.container.mainContext.fetch(
                FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])).first
            if let first {
                model.paths = [:]
                model.open(first)
            }
        }
    }

    #if os(macOS)
    static func runIfRequested(model: AppModel, openSettings: OpenSettingsAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        // Snapshots never run against the real database.
        guard Store.isTestStore else {
            print("SNAPSHOT refused: \(Store.testStoreRule)")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it; the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                for page in pages where only?.contains(page) ?? true {
                    show(page, model: model)
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/\(page)-\(mode).png")
                }
            }
            if only == nil || only?.contains("settings") == true {
                let main = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet }
                openSettings()
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    try? await Task.sleep(for: .seconds(0.8))
                    let settings = NSApp.windows.first { $0.isVisible && $0 !== main && !$0.isSheet }
                    capture(to: "\(dir)/settings-\(mode).png", window: settings)
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (the terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    private static func capture(to path: String, window: NSWindow? = nil) {
        // Another app can hide this one while snapshots run. Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT no window")
            return
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission, sidebars and glass are blank)")
        }
    }
    #else
    static func runIfRequested(model: AppModel) {
        guard let page = ProcessInfo.processInfo.environment["APP_SNAPSHOT_PAGE"], !page.isEmpty else { return }
        // Snapshots never run against the real database.
        guard Store.isTestStore else {
            print("SNAPSHOT refused: \(Store.testStoreRule)")
            exit(1)
        }
        if page == "list" {
            print("SNAPSHOT pages \(pages.joined(separator: ","))")
            exit(0)
        }
        guard pages.contains(page) else {
            print("SNAPSHOT unknown page \(page); pages: \(pages.joined(separator: ","))")
            exit(1)
        }
        Task {
            show(page, model: model)
            // Let navigation, focus, and images settle before the simulator captures.
            try? await Task.sleep(for: .seconds(2))
            print("SNAPSHOT ready \(page)")
        }
    }
    #endif
}
