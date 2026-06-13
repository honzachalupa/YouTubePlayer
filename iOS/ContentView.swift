import SwiftUI
import YouTubeKit

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @EnvironmentObject private var videoManager: VideoManager
    @StateObject private var authService = YouTubeAuthService.shared
    @StateObject private var playlistService = YouTubePlaylistService.shared
    
    private func navigationTabContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    SettingsToolbarItem()
                    AccountToolbarItem()
                }
        }
    }
    
    var body: some View {
        TabView {
            if authService.isAuthenticated {
                Tab("Subscriptions", systemImage: "heart.rectangle.fill") {
                    navigationTabContent {
                        SubscriptionsVideosView()
                    }
                }
            }
            
            Tab("Recommended", systemImage: "play.rectangle.on.rectangle.fill") {
                navigationTabContent {
                    RecommendedVideosView()
                }
            }
            
            if authService.isAuthenticated {
                /// iOS
                if horizontalSize == .compact {
                    Tab("Playlists", systemImage: "play.square.stack.fill") {
                        navigationTabContent {
                            PlaylistsListView()
                                .navigationTitle("Playlists")
                        }
                    }
                }
                
                Tab("History", systemImage: "memories") {
                    navigationTabContent {
                        HistoryVideosView()
                    }
                }
                
                /// iPadOS + macOS
                if horizontalSize == .regular {
                    TabSection("Playlists") {
                        ForEach(playlistService.playlists, id: \.playlistId) { playlist in
                            Tab(playlist.title ?? "", systemImage: getPlaylistIcon(playlist.title)) {
                                navigationTabContent {
                                    PlaylistView(playlist: playlist)
                                }
                            }
                        }
                        
                        Tab("All...", systemImage: "list.bullet") {
                            navigationTabContent {
                                PlaylistsListView()
                                    .navigationTitle("Playlists")
                            }
                        }
                    }
                }
            }
            
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                navigationTabContent {
                    SearchVideosView()
                }
            }
        }
        .tabViewBottomAccessory(isEnabled: videoManager.shouldShowAccessory) {
            AccessoryControlsView()
                .padding(.leading, 1)
                .padding(.trailing, 15)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $videoManager.isVideoSheetPresented) {
            if let video = videoManager.selectedVideo {
                VideoView(video: video)
                    .environmentObject(videoManager)
                    .presentationSizing(.page)
                    .presentationDragIndicator(.visible)
            } else {
                ContentUnavailableView("No video selected", systemImage: "play.slash.fill")
                    .presentationSizing(.page)
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                playlistService.clearData()
            }
        }
        .accentColor(Color("AccentColor"))
        .messageOverlay()
    }
}

#Preview {
    ContentView()
        .environmentObject(VideoManager())
}
