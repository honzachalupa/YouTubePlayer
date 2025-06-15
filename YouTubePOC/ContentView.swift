import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Subscriptions", systemImage: "play.house.fill") {
                SubscriptionsVideosView()
            }
            
            Tab("Recommended", systemImage: "play.rectangle.on.rectangle.fill") {
                RecommendedVideosView()
            }
            
            Tab("Playlists", systemImage: "play.square.stack.fill") {
                PlaylistsView()
            }
            
            /* Tab("Trending", systemImage: "play.house.fill") {
                TrendingVideosView()
            } */
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchVideosView()
            }
        }
        .tabViewBottomAccessory {
            AccessoryControlsView()
                .padding(.leading, 1)
                .padding(.trailing, 15)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    ContentView()
        .environmentObject(VideoStateManager())
        .environmentObject(YTM.shared)
}
