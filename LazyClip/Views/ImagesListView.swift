import SwiftUI

struct ImagesListView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = appState.storageErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }

            if appState.imageItems.isEmpty {
                ContentUnavailableView(
                    "No Image History",
                    systemImage: "photo.on.rectangle",
                    description: Text("Copied images will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.imageItems) { item in
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
                                onDelete: {
                                    do {
                                        try appState.deleteImage(item: item)
                                    } catch {
                                        appState.storageErrorMessage = error.localizedDescription
                                    }
                                }
                            )
                            .onAppear {
                                appState.loadNextImagePageIfNeeded(currentItem: item)
                            }
                        }

                        if appState.isLoadingMoreImages {
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
}
