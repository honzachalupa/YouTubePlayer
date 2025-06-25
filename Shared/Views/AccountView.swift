import SwiftUI
import YouTubeKit

struct AccountToolbarItem: ToolbarContent {
    @StateObject private var authService = YouTubeAuthService.shared
    @State private var isPopoverPresented: Bool = false
    @State private var isShowingLoginView = false
    
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
        // ToolbarSpacer(.fixed, placement: .topBarTrailing)
        
        ToolbarItem(placement: .topBarTrailing) {
            if authService.isAuthenticated {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    if authService.isAuthenticated && !userInitials.isEmpty {
                        Text(userInitials)
                    } else {
                        Label("Account", systemImage: "person.fill")
                    }
                }
                #if os(iOS)
                .popover(isPresented: $isPopoverPresented) {
                    HStack(spacing: 15) {
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
                        
                        Text(authService.userInfo?.name ?? "")
                            .fontWeight(.bold)
                        
                        Button {
                            authService.signOut()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .tint(.red)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                    }
                    .padding()
                    .presentationCompactAdaptation(.popover)
                }
                #endif
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
