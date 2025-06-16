import SwiftUI
import YouTubeKit

struct ContentView: View {
    @EnvironmentObject private var playerManager: PlayerManager
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
    @State private var playlists: [YTPlaylist] = []
    
    func fetchPlaylists() async {
        do {
            await youtubeService.getVisitorData()
            
            let response = try await AccountPlaylistsResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [:]
            )
            
            withAnimation {
                playlists = response.results
            }
        } catch {
            print(error.localizedDescription)
            
            withAnimation {
                playlists = []
            }
        }
    }
    
    var body: some View {
        TabView {
            Tab("Subscriptions", systemImage: "play.house.fill") {
                SubscriptionsVideosView()
            }
            
            Tab("Recommended", systemImage: "play.rectangle.on.rectangle.fill") {
                RecommendedVideosView()
            }
            
            Tab("Playlists", systemImage: "play.square.stack.fill") {
                PlaylistsListView()
            }
            
            /* Tab("Trending", systemImage: "play.house.fill") {
                TrendingVideosView()
            } */
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchVideosView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .sheet(isPresented: $playerManager.isVideoSheetPresented) {
            if playerManager.selectedVideo != nil {
                VideoView()
                    .environmentObject(playerManager)
                    .presentationSizing(.page)
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
        .task { await fetchPlaylists() }
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerManager())
        .environmentObject(YTM.shared)
}
