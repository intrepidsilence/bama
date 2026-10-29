import SwiftData
import SwiftUI

/// One item: the Mac's detail column, a pushed page everywhere else.
struct ItemDetail: View {
    @Query private var items: [Item]
    let id: UUID?

    var body: some View {
        if let item = items.first(where: { $0.uuid == id }) {
            ItemForm(item: item)
        } else {
            ContentUnavailableView("No Selection", systemImage: "doc.text")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ItemForm: View {
    @Environment(AppModel.self) private var model
    @Bindable var item: Item

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $item.title)
                Toggle("Starred", isOn: $item.isStarred)
                TextField("Notes", text: $item.notes, axis: .vertical)
                    .lineLimit(4...)
            }
            #if !os(macOS)
            // The Mac deletes from the list's context menu.
            Section {
                Button("Delete Item", systemImage: "trash", role: .destructive) { model.delete(item) }
            }
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle(item.title)
    }
}
