import SwiftUI
import SwiftCore

struct SettingsView: View {
    #if DEBUG
    @State private var isShowingDebugAuthImporter = false
    #endif

    var body: some View {
        NavigationStack {
            contentView
        }
        #if DEBUG
        .sheet(isPresented: $isShowingDebugAuthImporter) {
            DebugAuthImporterView()
        }
        #endif
    }

    @ViewBuilder
    private var contentView: some View {
        #if os(tvOS)
        List {
            NavigationLink("About") {
                aboutView
                    .navigationTitle("About")
            }

            #if DEBUG
            Button("Debug Auth") {
                isShowingDebugAuthImporter = true
            }
            #endif
        }
        .navigationTitle("Settings")
        #else
        aboutView
            .navigationTitle("About")
            #if DEBUG
            .toolbar {
                ToolbarItem {
                    Button("Debug Auth") {
                        isShowingDebugAuthImporter = true
                    }
                }
            }
            #endif
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

#if DEBUG
private struct DebugAuthImporterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = YouTubeAuthService.shared
    @State private var cookieText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Paste the YouTube auth cookies string copied from a signed-in device. This is intended for simulator/debug use only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Cookies") {
                    cookieInput
                }

                Section("Status") {
                    LabeledContent("Authenticated", value: authService.isAuthenticated ? "Yes" : "No")

                    if let userName = authService.userInfo?.name, !userName.isEmpty {
                        LabeledContent("User", value: userName)
                    }

                    if let authError = authService.authError, !authError.isEmpty {
                        Text(authError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Import Cookies") {
                        Task {
                            await authService.importDebugCookies(cookieText)
                        }
                    }
                    .disabled(cookieText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authService.isLoading)

                    Button("Clear Authentication", role: .destructive) {
                        authService.signOut()
                    }
                    .disabled(authService.isLoading)
                }
            }
            .navigationTitle("Debug Auth")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var cookieInput: some View {
        #if os(tvOS)
        TextField("Cookies", text: $cookieText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        TextEditor(text: $cookieText)
            .frame(minHeight: 180)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #endif
    }
}
#endif

#Preview {
    SettingsView()
}
