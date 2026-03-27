import SwiftUI

struct FavoritesEmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Favorites Yet",
            systemImage: "star",
            description: Text("Star items from history to keep them here.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
