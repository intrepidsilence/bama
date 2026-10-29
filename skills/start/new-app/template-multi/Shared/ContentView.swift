import SwiftData
import SwiftUI

/// The window's root. Each device gets its own navigation:
/// - Mac: a split view (sidebar, list, detail), with menus and Settings.
/// - iPhone and iPad: tabs (a sidebar on iPad), each a NavigationStack, so
///   Back and the swipe from the left edge both work.
/// - Apple TV: tabs across the top, each a NavigationStack of focusable cards.
/// - Vision Pro: tabs in an ornament, each a NavigationStack.
/// - Apple Watch: one NavigationStack, with the page as a filter.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var body: some View {
        navigation
            .task {
                SeedData.insertIfRequested(into: model)
                SelfTest.runIfRequested(model: model)
                #if os(macOS)
                Snapshot.runIfRequested(model: model, openSettings: openSettings)
                #else
                Snapshot.runIfRequested(model: model)
                #endif
            }
    }

    @ViewBuilder
    private var navigation: some View {
        @Bindable var model = model
        #if os(macOS)
        NavigationSplitView {
            List(SidebarItem.allCases, selection: Binding($model.page)) { page in
                Label(page.title, systemImage: page.symbol)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 212)
        } content: {
            ItemList(page: model.page)
                .navigationSplitViewColumnWidth(min: 260, ideal: 320)
        } detail: {
            ItemDetail(id: model.selection)
        }
        #elseif os(watchOS)
        NavigationStack(path: model.path(for: model.page)) {
            ItemList(page: model.page)
                .navigationDestination(for: UUID.self) { ItemDetail(id: $0) }
        }
        #else
        TabView(selection: $model.page) {
            ForEach(SidebarItem.allCases) { page in
                Tab(page.title, systemImage: page.symbol, value: page) {
                    PageStack(page: page)
                }
            }
        }
        #if os(iOS)
        .tabViewStyle(.sidebarAdaptable)
        #endif
        #endif
    }
}

/// One page's NavigationStack: the list, and the items pushed on top of it.
struct PageStack: View {
    @Environment(AppModel.self) private var model
    let page: SidebarItem

    var body: some View {
        NavigationStack(path: model.path(for: page)) {
            Group {
                #if os(tvOS)
                ItemGrid(page: page)
                #else
                ItemList(page: page)
                #endif
            }
            .navigationDestination(for: UUID.self) { ItemDetail(id: $0) }
        }
    }
}

extension AppModel {
    /// A binding to one page's navigation stack.
    func path(for page: SidebarItem) -> Binding<[UUID]> {
        Binding { self.paths[page] ?? [] } set: { self.paths[page] = $0 }
    }
}
