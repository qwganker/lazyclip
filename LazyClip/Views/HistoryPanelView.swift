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
                if appState.historyContentTab == .text {
                    TextField("Search clipboard history", text: searchBinding)
                        .textFieldStyle(.roundedBorder)
                }

                Picker("", selection: historyContentTabBinding) {
                    Text("Text").tag(AppState.ContentType.text)
                    Text("Images").tag(AppState.ContentType.images)
                }
                .pickerStyle(.segmented)

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

            if appState.historyContentTab == .text {
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
            } else {
                ImagesListView(appState: appState)
            }
        }
    }

    private var favoritesPage: some View {
        VStack(spacing: 0) {
            favoritesHeader
            Divider()

            VStack(spacing: 6) {
                Picker("", selection: favoritesContentTabBinding) {
                    Text("Text").tag(AppState.ContentType.text)
                    Text("Images").tag(AppState.ContentType.images)
                }
                .pickerStyle(.segmented)

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

            if appState.favoritesContentTab == .text {
                if appState.favoriteItems.isEmpty {
                    FavoritesEmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    FavoritesListView(appState: appState)
                }
            } else {
                starredImagesContent
            }
        }
    }

    private var starredImagesContent: some View {
        Group {
            if appState.starredImageItems.isEmpty {
                ContentUnavailableView(
                    "No Starred Images",
                    systemImage: "star",
                    description: Text("Star an image to keep it here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.starredImageItems) { item in
                            ImageRowView(
                                item: item,
                                fetchImageData: { id in try appState.fetchImageData(id: id) },
                                onSelect: {
                                    do {
                                        try appState.selectImage(item: item)
                                    } catch {
                                        appState.storageErrorMessage = error.localizedDescription
                                    }
                                },
                                onToggleStar: {
                                    do {
                                        try appState.toggleImageStar(item: item)
                                    } catch {
                                        appState.storageErrorMessage = error.localizedDescription
                                    }
                                },
                                onDelete: nil
                            )
                            .onAppear {
                                appState.loadNextStarredImagePageIfNeeded(currentItem: item)
                            }
                        }

                        if appState.isLoadingMoreStarredImages {
                            ProgressView()
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
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
            Text("Clipboard History")
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
            .help("Back")

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

    private var historyContentTabBinding: Binding<AppState.ContentType> {
        Binding(
            get: { appState.historyContentTab },
            set: { tab in
                do {
                    try appState.switchHistoryContentTab(tab)
                } catch {
                    appState.storageErrorMessage = error.localizedDescription
                }
            }
        )
    }

    private var favoritesContentTabBinding: Binding<AppState.ContentType> {
        Binding(
            get: { appState.favoritesContentTab },
            set: { tab in
                do {
                    try appState.switchFavoritesContentTab(tab)
                } catch {
                    appState.storageErrorMessage = error.localizedDescription
                }
            }
        )
    }
}
