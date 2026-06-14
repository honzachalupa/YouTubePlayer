import SwiftUI
import SwiftCore

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            AboutAppView(
                developerId: 1557529575,
                developerName: "Jan Chalupa",
                developerEmail: "me@janchalupa.dev",
                developerWebsite: "https://www.janchalupa.dev/",
                storeCountryCode: "cz"
            )
            .navigationTitle("About")
        }
    }
}

#Preview {
    SettingsView()
}
