import SwiftUI
import YouTubeKit

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @EnvironmentObject private var playerManager: PlayerManager
    @EnvironmentObject private var youtubeService: YouTubeService
    @StateObject private var authService = YouTubeAuthService.shared
    @StateObject private var playlistService = YouTubePlaylistService.shared
    
    var body: some View {
        TabView {
            Tab("Subscriptions", systemImage: "play.house.fill") {
                SubscriptionsVideosView()
            }
            
            Tab("Recommended", systemImage: "play.rectangle.on.rectangle.fill") {
                RecommendedVideosView()
            }
            
            if authService.isAuthenticated {
                if horizontalSize == .regular {
                    TabSection("Playlists") {
                        ForEach(playlistService.playlists, id: \.playlistId) { playlist in
                            Tab(playlist.title ?? "", systemImage: getPlaylistIcon(playlist.title)) {
                                PlaylistView(playlist: playlist)
                            }
                        }
                        
                        Tab("All...", systemImage: "list.bullet") {
                            PlaylistsListView()
                        }
                    }
                } else {
                    Tab("Playlists", systemImage: "play.square.stack.fill") {
                        NavigationStack {
                            PlaylistsListView()
                                .navigationTitle("Playlists")
                        }
                    }
                }
            }
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchVideosView()
            }
        }
        .accentColor(Color("AccentColor"))
        .tabViewStyle(.sidebarAdaptable)
        .sheet(isPresented: $playerManager.isVideoSheetPresented) {
            if playerManager.selectedVideo != nil {
                VideoView()
                    .environmentObject(playerManager)
                    .presentationSizing(.page)
                    .presentationDragIndicator(.visible)
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
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                playlistService.clearData()
            }
        }
        .messageOverlay()
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerManager())
        .environmentObject(YouTubeService.shared)
}
