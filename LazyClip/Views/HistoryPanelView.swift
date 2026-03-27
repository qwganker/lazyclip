import AppKit
import SwiftUI

struct HistoryPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.currentPage {
            case .history:
                historyPage
            case .favorites:
                favoritesPage
            case .settings:
                settingsPage
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var historyPage: some View {
        VStack(spacing: 0) {
            historyHeader
            Divider()

            if appState.settings.isPaused {
                PausedBannerView()
            }

            VStack(spacing: 6) {
                TextField("Search clipboard history", text: searchBinding)
                    .textFieldStyle(.roundedBorder)

                if let storageErrorMessage = appState.storageErrorMessage {
                    Text(storageErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(Color(nsColor: .windowBackgroundColor))

            if appState.items.isEmpty {
                ContentUnavailableView(
                    "No Clipboard History",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copied text will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HistoryListView(appState: appState)
            }
        }
    }

    private var favoritesPage: some View {
        VStack(spacing: 0) {
            favoritesHeader
            Divider()

            if let storageErrorMessage = appState.storageErrorMessage {
                Text(storageErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }

            if appState.favoriteItems.isEmpty {
                FavoritesEmptyStateView()
            } else {
                FavoritesListView(appState: appState)
            }
        }
        .task {
            if appState.favoriteItems.isEmpty {
                try? appState.loadFavorites()
            }
        }
    }

    private var settingsPage: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            SettingsView(appState: appState)
        }
    }

    private var historyHeader: some View {
        HStack(spacing: 12) {
            Label("LazyClip", image: "MenuBarIcon")
                .font(.headline)

            Spacer()

            Button {
                appState.currentPage = .favorites
            } label: {
                Image(systemName: "star")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Favorites")

            Button {
                appState.currentPage = .settings
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var favoritesHeader: some View {
        HStack(spacing: 12) {
            Button {
                appState.currentPage = .history
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back to History")

            Text("Favorites")
                .font(.headline)

            Spacer()

            Button {
                appState.currentPage = .settings
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Button {
                appState.currentPage = .history
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back")

            Text("Settings")
                .font(.headline)

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { appState.searchText },
            set: { newValue in
                do {
                    try appState.updateSearchText(newValue)
                } catch {
                    appState.storageErrorMessage = error.localizedDescription
                }
            }
        )
    }
}
