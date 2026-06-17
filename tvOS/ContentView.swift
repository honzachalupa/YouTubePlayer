import SwiftUI
import SwiftData
import YouTubeKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @EnvironmentObject private var videoManager: VideoManager
    @StateObject private var authService = YouTubeAuthService.shared
    @StateObject private var playlistService = YouTubePlaylistService.shared
    @State private var hasCompletedInitialAuthRefresh = false
    
    var body: some View {
        TabView {
            if authService.isAuthenticated {
                Tab("Subscriptions", systemImage: "heart.rectangle.fill") {
                    NavigationStack {
                        SubscriptionsVideosView()
                    }
                }
            }
            
            Tab("Recommended", systemImage: "play.rectangle.on.rectangle.fill") {
                NavigationStack {
                    RecommendedVideosView()
                }
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
                    NavigationStack {
                        HistoryVideosView()
                    }
                }
                
                /// iPadOS + macOS
                if horizontalSize == .regular {
                    TabSection("Playlists") {
                        ForEach(playlistService.playlists, id: \.playlistId) { playlist in
                            Tab(playlist.title ?? "", systemImage: getPlaylistIcon(playlist.title)) {
                                NavigationStack {
                                    PlaylistView(playlist: playlist)
                                }
                            }
                        }
                        
                        Tab("All...", systemImage: "list.bullet") {
                            NavigationStack {
                                PlaylistsListView()
                            }
                        }
                    }
                }
            }
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    SearchVideosView()
                }
            }
        }
        .accentColor(Color("AccentColor"))
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                playlistService.clearData()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            guard hasCompletedInitialAuthRefresh else { return }
            Task {
                await authService.refreshAuthenticationFromStoredCookies()
            }
        }
        .task {
            await authService.refreshAuthenticationFromStoredCookies()
            hasCompletedInitialAuthRefresh = true
        }
        .messageOverlay()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: AuthenticationModel.self)
}
