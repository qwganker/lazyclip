import SwiftUI

struct FavoritesListView: View {
    @ObservedObject var appState: AppState

    private let rowInsets: EdgeInsets = EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)

    var body: some View {
        List {
            ForEach(appState.favoriteItems) { item in
                HistoryRowView(
                    item: item.historyItem,
                    isFavorited: true,
                    showsDeleteButton: false,
                    onSelect: {
                        do {
                            try appState.select(item: item.historyItem)
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    },
                    onToggleFavorite: {
                        do {
                            try appState.removeFavorite(historyItemID: item.historyItem.id)
                        } catch {
                            appState.storageErrorMessage = error.localizedDescription
                        }
                    },
                    onDelete: nil
                )
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if appState.isLoadingMoreFavorites {
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
