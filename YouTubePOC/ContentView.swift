import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @EnvironmentObject private var playerManager: PlayerManager
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
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
            
            /* Tab("Trending", systemImage: "play.house.fill") {
                TrendingVideosView()
            } */
            
            if authService.isAuthenticated {
                if horizontalSize == .regular {
                    TabSection("Playlists") {
                        ForEach(playlistService.playlists) { playlist in
                            Tab(playlist.snippet.title, systemImage: getPlaylistIcon(playlist.snippet.title)) {
                                PlaylistView(playlist: playlist)
                            }
                        }
                        
                        Tab("All...", systemImage: "list.bullet") {
                            PlaylistsListView()
                        }
                    }
                } else {
                    Tab("Playlists", systemImage: "play.square.stack.fill") {
                        PlaylistsListView()
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
            if let video = playerManager.selectedVideo {
                VideoView(video: video)
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
        .task {
            if authService.isAuthenticated {
                do {
                    _ = try await playlistService.fetchPlaylists()
                } catch {
                    // Error is handled by the service
                }
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task {
                    do {
                        _ = try await playlistService.fetchPlaylists()
                    } catch {
                        // Error is handled by the service
                    }
                }
            } else {
                playlistService.clearData()
            }
        }
        .messageOverlay()
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerManager())
        .environmentObject(YouTubeServiceWrapper())
}
