import SwiftUI

struct AccountLinkView: View {
    @StateObject private var authService = YouTubeAuthService()
    
    var body: some View {
        NavigationLink {
            AccountView()
        } label: {
            if let userInfo = authService.userInfo {
                AsyncImage(url: URL(string: userInfo.picture)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } placeholder: {
                    Label("Account", systemImage: "person.fill")
                        .frame(width: 50, height: 50)
                }
            } else {
                Label("Account", systemImage: "person.fill")
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    AccountLinkView()
}
