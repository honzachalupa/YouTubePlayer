import SwiftUI
import SwiftData
import YouTubeKit

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @EnvironmentObject private var videoManager: VideoManager
    @StateObject private var authService = YouTubeAuthService.shared
    @StateObject private var playlistService = YouTubePlaylistService.shared
    
    var body: some View {
        TabView {
            if authService.isAuthenticated {
                Tab("Subscriptions", systemImage: "heart.rectangle.fill") {
                    SubscriptionsVideosView()
                }
            }
            
            Tab("Recommended", systemImage: "play.rectangle.on.rectangle.fill") {
                RecommendedVideosView()
            }
            
            if authService.isAuthenticated {
                /// iOS
                if horizontalSize == .compact {
                    Tab("Playlists", systemImage: "play.square.stack.fill") {
                        NavigationStack {
                            PlaylistsListView()
                                .navigationTitle("Playlists")
                        }
                    }
                }
                
                Tab("History", systemImage: "memories") {
                    HistoryVideosView()
                }
                
                /// iPadOS + macOS
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
                }
            }
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchVideosView()
            }
        }
        .accentColor(Color("AccentColor"))
        .tabViewStyle(.sidebarAdaptable)
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
        .modelContainer(for: AuthenticationModel.self)
}
