import SwiftUI

struct AccountView: View {
    @StateObject var authService: YouTubeAuthService
    
    init(authService: YouTubeAuthService = YouTubeAuthService()) {
        _authService = StateObject(wrappedValue: authService)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let userInfo = authService.userInfo, authService.isAuthenticated {
                    List {
                        HStack {
                            AsyncImage(url: URL(string: userInfo.picture)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 8) {
                                Text(userInfo.name)
                                    .font(.title2)
                                    .bold()
                                
                                Text(userInfo.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        Text("Sign in to access your YouTube account")
                            .multilineTextAlignment(.center)
                        
                        Button("Sign in with Google") {
                            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                  let window = windowScene.windows.first else {
                                return
                            }
                            
                            authService.signIn(from: window)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .toolbar {
                if authService.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            authService.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .tint(.red)
                    }
                }
            }
            .navigationTitle(authService.isAuthenticated ? "Account" : "Sign in")
        }
        .toolbarVisibility(.hidden, for: .tabBar)
    }
}

#Preview("Signed Out") {
    AccountView()
}

#Preview("Signed In") {
    AccountView(authService: {
        let service = YouTubeAuthService()
        service.isAuthenticated = true
        service.userInfo = YouTubeAuthService.UserInfo(
            name: "John Doe",
            email: "john.doe@example.com",
            picture: "https://picsum.photos/200"
        )
        return service
    }())
}
