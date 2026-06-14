import SwiftUI
import YouTubeKit

struct AccountToolbarItem: ToolbarContent {
    @StateObject private var authService = YouTubeAuthService.shared
    @State private var isShowingLoginView = false
    
    private var userName: String {
        authService.userInfo?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var accountPictureURL: URL? {
        guard let picture = authService.userInfo?.picture, !picture.isEmpty else { return nil }
        return URL(string: picture)
    }
    
    var body: some ToolbarContent {
        ToolbarItem(id: "toolbar.account", placement: .topBarTrailing) {
            if authService.isAuthenticated {
                Menu {
                    Button(role: .destructive) {
                        authService.signOut()
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    if authService.isAuthenticated && !userName.isEmpty {
                        HStack(spacing: 8) {
                            AsyncImage(url: accountPictureURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                default:
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 8, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                }
                            }
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())

                            Text(userName)
                        }
                    }
                }
            } else {
                Button {
                    isShowingLoginView = true
                } label: {
                    Label("Account", systemImage: "person.fill")
                }
                #if os(iOS)
                .sheet(isPresented: $isShowingLoginView) {
                    YouTubeLoginWebView { cookies in
                        Task {
                            await authService.handleSignIn(cookies: cookies)
                            isShowingLoginView = false
                        }
                    }
                }
                #endif
            }
        }
    }
}

/* #Preview("Signed in") {
    let service = YouTubeAuthService.shared
    service.userInfo = YouTubeAuthService.UserInfo(
        name: "John Doe",
        picture: "https://picsum.photos/200"
    )
    service.isAuthenticated = true
    
    NavigationStack {
        VStack {}
            .toolbar {
                AccountToolbarItem()
            }
    }
}

#Preview("Signed out") {
    let service = YouTubeAuthService.shared
    service.isAuthenticated = false
    
    NavigationStack {
        VStack {}
            .toolbar {
                AccountToolbarItem()
            }
    }
} */
