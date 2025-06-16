import SwiftUI
import YouTubeKit

struct AccountView: View {
    @StateObject private var authService = YouTubeAuthService.shared
    @State private var isShowingLoginView = false
    
    var body: some View {
        NavigationStack {
            Group {
                if authService.isAuthenticated {
                    List {
                        HStack {
                            if let pictureUrl = authService.userInfo?.picture {
                                AsyncImage(url: URL(string: pictureUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 8) {
                                if let name = authService.userInfo?.name {
                                    Text(name)
                                        .font(.title)
                                        .bold()
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        await authService.fetchUserInfo()
                    }
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
                if authService.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
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

struct AccountToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                AccountView()
            } label: {
                Label("Account", systemImage: "person.fill")
            }

        }
    }
}

#Preview {
    let service = YouTubeAuthService.shared
    service.userInfo = .init(
        name: "John Doe",
        picture: "https://picsum.photos/200"
    )
    
    return AccountView()
}
