import SwiftUI

struct HistoryListView: View {
    @ObservedObject var appState: AppState

    private let rowInsets: EdgeInsets = EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)

    var body: some View {
        List {
            ForEach(appState.items) { item in
                HistoryRowView(
                    item: item,
                    isFavorited: appState.isItemFavorited(item.id),
                    showsDeleteButton: true,
                    onSelect: {
                        do {
                            try appState.select(item: item)
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    },
                    onToggleFavorite: {
                        do {
                            if appState.isItemFavorited(item.id) {
                                try appState.removeFavorite(historyItemID: item.id)
                            } else {
                                try appState.addFavorite(historyItemID: item.id)
                            }
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    },
                    onDelete: {
                        do {
                            try appState.delete(item: item)
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    }
                )
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onAppear {
                    do {
                        try appState.loadNextPageIfNeeded(currentItem: item)
                    } catch {
                        appState.storageErrorMessage = error.localizedDescription
                    }
                }
            }

            if appState.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowInsets(rowInsets)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .contentMargins(.top, 2, for: .scrollContent)
        .safeAreaPadding(.leading, 6)
        .safeAreaPadding(.trailing, AppConfiguration.listScrollbarReservedWidth)
    }
}
