import Foundation
import SwiftData
import __APP_NAME__Kit

@Model
final class Item {
    var title: String
    var notes: String = ""
    var isStarred: Bool = false
    var createdAt: Date = Date.now
    /// A stable id for navigation, links, sync, and the agent CLI.
    var uuid: UUID = UUID()

    init(title: String) {
        self.title = title
    }
}

/// The app's pages: sidebar rows on the Mac, tabs on iPhone, iPad, Apple TV,
/// and Vision Pro, a filter on Apple Watch. Snapshot mode walks through every case.
enum SidebarItem: String, CaseIterable, Identifiable {
    case all, starred

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Items"
        case .starred: "Starred"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray"
        case .starred: "star"
        }
    }
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    let container: ModelContainer
    var page: SidebarItem = .all
    /// Mac: the item in the detail column.
    var selection: UUID?
    /// Other devices: each page's navigation stack, as the ids of the pushed items.
    var paths: [SidebarItem: [UUID]] = [:]

    init(container: ModelContainer) {
        self.container = container
    }

    /// Adds an item and opens it: selected on the Mac, pushed elsewhere.
    @discardableResult
    func addItem(title: String = "") -> Item {
        let item = Item(title: ItemTitle.clean(title))
        if page == .starred { item.isStarred = true }
        container.mainContext.insert(item)
        try? container.mainContext.save()
        open(item)
        return item
    }

    func open(_ item: Item) {
        if Platform.current == .mac {
            selection = item.uuid
        } else {
            paths[page, default: []].append(item.uuid)
        }
    }

    /// Deletes an item and closes it wherever it is open.
    func delete(_ item: Item) {
        let id = item.uuid
        if selection == id { selection = nil }
        for page in paths.keys { paths[page]?.removeAll { $0 == id } }
        container.mainContext.delete(item)
        try? container.mainContext.save()
    }
}
