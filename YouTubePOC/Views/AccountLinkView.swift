import SwiftUI

struct AccountLinkView: View {
    @ObservedObject private var authService = YouTubeAuthService.shared
    
    var body: some View {
        NavigationLink {
            AccountView()
        } label: {
            /* if authService.isAuthenticated {
                if let userInfo = authService.userInfo {
                    AsyncImage(url: URL(string: userInfo.picture)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipped()
                    } placeholder: {
                        Label("Account", systemImage: "person.fill")
                            .frame(width: 50, height: 50)
                    }
                }
            } else {
                Label("Account", systemImage: "person.fill")
            } */
            
            Label("Account", systemImage: "person.fill")
        }
    }
}

#Preview {
    NavigationStack {
        AccountLinkView()
    }
}
