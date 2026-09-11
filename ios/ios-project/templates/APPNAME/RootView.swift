import DesignSystem
import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "__DISPLAY_NAME__",
                systemImage: "sparkles",
                description: Text("Scaffolded and ready. Replace RootView with your first screen.")
            )
            .navigationTitle("__DISPLAY_NAME__")
        }
        .accessibilityIdentifier("root-view")
    }
}

#Preview {
    RootView()
}
