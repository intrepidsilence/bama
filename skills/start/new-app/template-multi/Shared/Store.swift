import Foundation
import SwiftData

/// Where the data lives: Application Support/__APP_NAME__/__APP_NAME__.store.
/// On the Mac that is ~/Library/Application Support/__APP_NAME__/; on the
/// other devices it sits inside the app's own container.
/// On Apple TV the system may purge local files when space runs low: a
/// shipping tvOS app keeps the data that matters in iCloud.
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    /// The real data folder. Test runs never touch it.
    static var realFolder: URL {
        URL.applicationSupportDirectory.appending(path: "__APP_NAME__", directoryHint: .isDirectory)
    }

    /// True when APP_STORE is set and points outside the real data folder.
    /// Snapshots, seed data, and the self-test run only then.
    static var isTestStore: Bool {
        guard isOverridden else { return false }
        let real = realFolder.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        let store = url.standardizedFileURL.resolvingSymlinksInPath().path
        return !store.hasPrefix(real)
    }

    /// Why a test run refuses to start.
    static let testStoreRule = "APP_STORE must be set to a test file (like .work/test.store), outside the real data folder Application Support/__APP_NAME__/"

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = realFolder
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "__APP_NAME__.store")
    }

    /// True when the run asks for seed data, snapshots, or the self-test.
    static var isTestRun: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["APP_SEED"] == "1" || !(env["APP_SNAPSHOT"] ?? "").isEmpty
            || !(env["APP_SNAPSHOT_PAGE"] ?? "").isEmpty || CommandLine.arguments.contains("--selftest")
    }

    static func makeContainer() -> ModelContainer {
        // A test run without a test store refuses to start (SeedData, Snapshot,
        // SelfTest). Until it quits it gets a database in memory, so it never
        // opens or creates a file in the real data folder.
        let configuration = isTestRun && !isTestStore
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(url: url)
        do {
            return try ModelContainer(for: Item.self, configurations: configuration)
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
