import SwiftUI
import YouTubeKit

@MainActor final class AccountViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    private let authService: YouTubeAuthService
    
    init() {
        self.authService = YouTubeAuthService.shared
    }
    
    func signOut() {
        isLoading = true
        authService.signOut()
        isLoading = false
    }
}

struct AccountView: View {
    @StateObject private var viewModel = AccountViewModel()
    @ObservedObject private var authService = YouTubeAuthService.shared
    @State private var isShowingLoginView = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if authService.isAuthenticated {
                    // This part will not show user info yet, as we are not fetching it.
                    // It will just confirm that the user is logged in.
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                             .font(.system(size: 100))
                             .foregroundColor(.gray)
                        Text("Signed In")
                            .font(.title2)
                        Text("You are signed in with your YouTube account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Text("Sign in to access your YouTube account")
                            .font(.headline)
                        
                        Button("Sign In") {
                            isShowingLoginView = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                if authService.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .tint(.red)
                    }
                }
            }
            .navigationTitle(authService.isAuthenticated ? "Account" : "Sign in")
            .sheet(isPresented: $isShowingLoginView) {
                YouTubeLoginWebView { cookies in
                    authService.handleSignIn(cookies: cookies)
                    isShowingLoginView = false
                }
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
    }
}

#Preview {
    let service = YouTubeAuthService.shared
    service.userInfo = .init(
        name: "John Doe",
        email: "john@example.com",
        picture: "https://picsum.photos/200"
    )
    
    return AccountView()
}
