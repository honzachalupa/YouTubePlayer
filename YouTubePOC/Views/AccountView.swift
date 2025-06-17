import SwiftUI
import YouTubeKit

struct AccountView: View {
    @StateObject private var authService = YouTubeAuthService.shared
    @State private var isShowingLoginView = false
    @State private var showSignOutConfirmation = false
    
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
                            
                            if let name = authService.userInfo?.name {
                                Text(name)
                                    .font(.title)
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
                        
                        Button("Sign in") {
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
                            showSignOutConfirmation = true
                        } label: {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .tint(.red)
                        .confirmationDialog(
                            "Are you sure you want to sign out?",
                            isPresented: $showSignOutConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Sign out", role: .destructive) {
                                authService.signOut()
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("You will need to sign in again to access your account.")
                        }
                    }
                }
            }
            .navigationTitle(authService.isAuthenticated ? "Account" : "Sign in")
            .sheet(isPresented: $isShowingLoginView) {
                YouTubeLoginWebView { cookies in
                    Task {
                        await authService.handleSignIn(cookies: cookies)
                        isShowingLoginView = false
                    }
                }
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
    }
}

struct AccountToolbarItem: ToolbarContent {
    @StateObject private var authService = YouTubeAuthService.shared
    
    private var userInitials: String {
        guard let name = authService.userInfo?.name else { return "" }
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))"
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return ""
    }
    
    var body: some ToolbarContent {
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                AccountView()
            } label: {
                if authService.isAuthenticated && !userInitials.isEmpty {
                    Text(userInitials)
                } else {
                    Label("Account", systemImage: "person.fill")
                }
            }
        }
    }
}

#Preview {
    let service = YouTubeAuthService.shared
    service.userInfo = YouTubeAuthService.UserInfo(
        name: "John Doe",
        picture: "https://picsum.photos/200"
    )
    service.isAuthenticated = true
    
    return AccountView()
}
