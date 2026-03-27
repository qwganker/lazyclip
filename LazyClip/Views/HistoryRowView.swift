import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardHistoryItem
    let isFavorited: Bool
    let showsDeleteButton: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: (() -> Void)?

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: handleSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorited ? "star.fill" : "star")
            }
            .buttonStyle(.borderless)
            .help(isFavorited ? "Remove favorite" : "Add favorite")

            if showsDeleteButton, let onDelete {
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
