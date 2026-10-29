import Foundation
import SwiftData
import __APP_NAME__Kit
#if os(macOS)
import AppKit
#endif

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, then SELFTEST PASS or SELFTEST FAIL, and
/// quits with exit code 0 or 1. tools/selftest.sh runs it on every platform:
///   Mac:        APP_STORE=.work/self.store ~/Applications/__APP_NAME__.app/Contents/MacOS/__APP_NAME__ --selftest
///   simulator:  SIMCTL_CHILD_APP_STORE=<project>/.work/self.store xcrun simctl launch <udid> <bundle-id> --selftest
/// Add a check for every story with logic.
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Mac: read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        guard Store.isTestStore else {
            print("SELFTEST refused: \(Store.testStoreRule)")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let context = model.container.mainContext
            func items() -> [Item] { (try? context.fetch(FetchDescriptor<Item>())) ?? [] }

            let before = items().count
            let added = model.addItem()
            check("New Item adds one item", items().count == before + 1)
            let opened = Platform.current == .mac
                ? model.selection == added.uuid
                : model.paths[model.page]?.last == added.uuid
            check("the new item opens", opened)

            added.isStarred.toggle()
            check("starring an item marks it starred", added.isStarred)
            model.delete(added)
            check("deleting the item removes it", items().count == before)
            check("deleting the item closes it", model.selection == nil && (model.paths[model.page] ?? []).isEmpty)
            check("titles are cleaned", ItemTitle.clean("  Buy   milk ") == "Buy milk")

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Mac: quits through NSApp.terminate, never exit(), and closes sheets
    /// first: an open sheet refuses terminate, and the run would wait forever.
    /// Other devices: a test run has no one to quit it, so it exits.
    static func finish(code: Int32) {
        exitCode = code
        #if os(macOS)
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
        #else
        fflush(stdout)
        exit(code)
        #endif
    }
}
