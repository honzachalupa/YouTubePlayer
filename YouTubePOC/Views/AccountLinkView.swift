import SwiftUI

struct AccountLinkView: View {
    @ObservedObject private var authService = YouTubeAuthService.shared
    
    var body: some View {
        NavigationLink {
            AccountView()
        } label: {
            if authService.isAuthenticated {
                Image(systemName: "person.circle.fill")
                    .font(.title)
            } else {
                Image(systemName: "person.circle")
                    .font(.title)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountLinkView()
    }
}
