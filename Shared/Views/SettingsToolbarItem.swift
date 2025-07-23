import SwiftUI

struct SettingsToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }
}

#Preview {
    NavigationStack {
        VStack {}
            .toolbar {
                SettingsToolbarItem()
            }
    }
}
