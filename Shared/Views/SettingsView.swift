import SwiftUI
import SwiftCore

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            contentView
        }
    }

    @ViewBuilder
    private var contentView: some View {
        #if os(tvOS)
        List {
            NavigationLink("About") {
                aboutView
                    .navigationTitle("About")
            }
        }
        .navigationTitle("Settings")
        #else
        aboutView
            .navigationTitle("About")
        #endif
    }

    private var aboutView: some View {
        AboutAppView(
            developerId: 1557529575,
            developerName: "Jan Chalupa",
            developerEmail: "me@janchalupa.dev",
            developerWebsite: "https://www.janchalupa.dev/",
            storeCountryCode: "cz"
        )
    }
}

#Preview {
    SettingsView()
}
