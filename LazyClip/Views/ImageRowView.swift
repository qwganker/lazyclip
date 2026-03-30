import AppKit
import SwiftUI

struct ImageRowView: View {
    let item: ImageHistoryItem
    let fetchImageData: (Int64) throws -> Data?
    let onSelect: () -> Void
    let onToggleStar: () -> Void
    let onDelete: (() -> Void)?

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: handleSelect) {
                HStack(spacing: 10) {
                    thumbnailView

                    Text(item.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleStar) {
                Image(systemName: item.isStarred ? "star.fill" : "star")
            }
            .buttonStyle(.borderless)
            .help(item.isStarred ? "Remove favorite" : "Add favorite")

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete item")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
        .onHover { hovered in
            isHovered = hovered
        }
    }

    private var thumbnailView: some View {
        Group {
            if let nsImage = thumbnail {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(id: item.id) {
            if let cached = ThumbnailCache.shared.thumbnail(for: item.id) {
                thumbnail = cached
                return
            }
            let itemID = item.id
            // Fetch data on MainActor (SQLite is not thread-safe)
            guard let data = try? fetchImageData(itemID) else { return }
            // Decode NSImage off the main thread
            let image = await Task.detached(priority: .userInitiated) {
                NSImage(data: data)
            }.value
            if let image {
                ThumbnailCache.shared.store(image, for: itemID)
            }
            thumbnail = image
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
    }

    private func handleSelect() {
        isPressed = true
        onSelect()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            isPressed = false
        }
    }
}
