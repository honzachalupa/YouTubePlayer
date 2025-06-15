import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var playerManager: PlayerManager
    
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
        .sheet(isPresented: $playerManager.isVideoSheetPresented) {
            if playerManager.selectedVideo != nil {
                VideoView()
                    .environmentObject(playerManager)
            }
        }
        .tabViewBottomAccessory {
            if playerManager.selectedVideo != nil {
                AccessoryControlsView()
                    .padding(.leading, 1)
                    .padding(.trailing, 15)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerManager())
        .environmentObject(YTM.shared)
}
