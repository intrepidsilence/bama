#if os(tvOS)
import SwiftData
import SwiftUI

/// The items on Apple TV: a New Item button and a grid of cards, read from
/// across the room and moved through with the Siri Remote.
///
/// Two rules every Apple TV page in this app follows:
/// - A focused card grows and casts a shadow. Nothing around it clips: the
///   scroll view has `.scrollClipDisabled()`, the content has `Space.focusRoom`
///   padding, and no `.clipped()` or `.clipShape` sits around a focusable view.
/// - Each focus region (the button row, the grid) is a `focusSection()` and
///   says where the highlight enters: the item last highlighted there, else
///   the first, with `.defaultFocus(..., priority: .userInitiated)`.
struct ItemGrid: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    let page: SidebarItem

    @FocusState private var focused: UUID?
    @State private var lastFocused: UUID?

    private var visible: [Item] {
        page == .starred ? items.filter(\.isStarred) : items
    }

    /// Where the highlight enters the grid.
    private var entry: UUID? {
        if let lastFocused, visible.contains(where: { $0.uuid == lastFocused }) { return lastFocused }
        return visible.first?.uuid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                HStack {
                    Button("New Item", systemImage: "plus") { model.addItem() }
                    Spacer()
                }
                .focusSection()

                if visible.isEmpty {
                    ContentUnavailableView("No Items", systemImage: page.symbol,
                                           description: Text("Choose New Item to add one."))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: CardSize.width), spacing: CardSize.gap)],
                              alignment: .leading, spacing: CardSize.gap) {
                        ForEach(visible) { item in
                            NavigationLink(value: item.uuid) {
                                ItemCard(item: item)
                            }
                            .buttonStyle(.card)
                            .focused($focused, equals: item.uuid)
                        }
                    }
                    .focusSection()
                    .defaultFocus($focused, entry, priority: .userInitiated)
                }
            }
            .padding(Space.focusRoom)
        }
        .scrollClipDisabled()
        .onChange(of: focused) { _, new in
            if let new { lastFocused = new }
        }
        .task {
            // Snapshots show the first card focused: the first and last cards
            // in a row are where clipping shows.
            if Snapshot.isRunning {
                try? await Task.sleep(for: .seconds(0.5))
                focused = visible.first?.uuid
            }
        }
    }
}

private struct ItemCard: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Image(systemName: item.isStarred ? "star.fill" : "circle")
                .font(.title3)
                .foregroundStyle(Palette.accentText)
            Spacer(minLength: 0)
            Text(item.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(Space.xxl)
        .frame(width: CardSize.width, height: CardSize.height, alignment: .leading)
    }
}
#endif
