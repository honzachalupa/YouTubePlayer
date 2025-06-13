import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            HomeVideosView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            TrendingVideosView()
                .tabItem {
                    Label("Trending", systemImage: "flame.fill")
                }

            SubscriptionsVideosView()
                .tabItem {
                    Label("Subscriptions", systemImage: "play.square.stack.fill")
                }
            
            SearchVideosView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(YTM.shared)
} 