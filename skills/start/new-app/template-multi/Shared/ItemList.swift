import SwiftData
import SwiftUI

/// The item list on the Mac, iPhone, iPad, Apple Watch, and Vision Pro.
/// Apple TV uses ItemGrid instead.
struct ItemList: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    let page: SidebarItem

    private var visible: [Item] {
        page == .starred ? items.filter(\.isStarred) : items
    }

    var body: some View {
        @Bindable var model = model
        list
            .overlay {
                if visible.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: page.symbol,
                        description: Text(Platform.value(mac: "Press Command-N to add one.",
                                                         phone: "Tap + to add one.",
                                                         pad: "Tap + to add one.",
                                                         tv: "Choose New Item to add one.",
                                                         watch: "Tap + to add one.",
                                                         vision: "Tap + to add one."))
                    )
                }
            }
            .navigationTitle(page.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Item", systemImage: "plus") { model.addItem() }
                        #if os(macOS)
                        .help("Add an item (Command-N)")
                        #endif
                }
            }
    }

    @ViewBuilder
    private var list: some View {
        @Bindable var model = model
        #if os(macOS)
        List(selection: $model.selection) {
            ForEach(visible) { item in
                ItemRow(item: item)
                    .tag(item.uuid)
                    .contextMenu {
                        Button("Delete", role: .destructive) { model.delete(item) }
                    }
            }
        }
        #else
        List {
            #if os(watchOS)
            // On the watch the pages are a filter at the top of one list.
            Picker("Show", selection: $model.page) {
                ForEach(SidebarItem.allCases) { Text($0.title).tag($0) }
            }
            #endif
            ForEach(visible) { item in
                NavigationLink(value: item.uuid) {
                    ItemRow(item: item)
                }
            }
            .onDelete { offsets in
                for index in offsets { model.delete(visible[index]) }
            }
        }
        #endif
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        Label(item.title, systemImage: item.isStarred ? "star.fill" : "circle")
    }
}
