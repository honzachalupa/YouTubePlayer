import SwiftUI
import UIKit
import YouTubeKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var videoManager: VideoManager
    @StateObject private var authService = YouTubeAuthService.shared
    @StateObject private var playlistService = YouTubePlaylistService.shared
    @State private var selectedTab: ContentTab = YouTubeAuthService.shared.isAuthenticated ? .subscriptions : .recommended
    @State private var isToolbarReady = false
    @State private var hasCompletedInitialAuthRefresh = false
    @State private var sheetRootVideo: YTVideo?
    @State private var videoSheetPath: [VideoSheetRoute] = []
    
    private enum ContentTab: Hashable {
        case subscriptions
        case recommended
        case playlists
        case history
        case playlist(String)
        case allPlaylists
        case search
    }
    
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    private func navigationTabContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    if isToolbarReady {
                        SettingsToolbarItem()
                        AccountToolbarItem()
                    }
                }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            if authService.isAuthenticated {
                Tab("Subscriptions", systemImage: "heart.rectangle.fill", value: ContentTab.subscriptions) {
                    navigationTabContent {
                        SubscriptionsVideosView()
                    }
                }
            }
            
            Tab("Recommended", systemImage: "play.rectangle.on.rectangle.fill", value: ContentTab.recommended) {
                navigationTabContent {
                    RecommendedVideosView()
                }
            }
            
            if authService.isAuthenticated {
                if isPhone {
                    Tab("Playlists", systemImage: "play.square.stack.fill", value: ContentTab.playlists) {
                        navigationTabContent {
                            PlaylistsListView()
                                .navigationTitle("Playlists")
                        }
                    }
                }
                
                Tab("History", systemImage: "memories", value: ContentTab.history) {
                    navigationTabContent {
                        HistoryVideosView()
                    }
                }
                
                if !isPhone {
                    TabSection("Playlists") {
                        ForEach(playlistService.playlists, id: \.playlistId) { playlist in
                            Tab(playlist.title ?? "", systemImage: getPlaylistIcon(playlist.title), value: ContentTab.playlist(playlist.playlistId)) {
                                navigationTabContent {
                                    PlaylistView(playlist: playlist)
                                }
                            }
                        }
                        
                        Tab("All...", systemImage: "list.bullet", value: ContentTab.allPlaylists) {
                            navigationTabContent {
                                PlaylistsListView()
                                    .navigationTitle("Playlists")
                            }
                        }
                    }
                }
            }
            
            Tab("Search", systemImage: "magnifyingglass", value: ContentTab.search, role: .search) {
                navigationTabContent {
                    SearchVideosView()
                }
            }
        }
        .task {
            await authService.refreshAuthenticationFromStoredCookies()
            hasCompletedInitialAuthRefresh = true
            await Task.yield()
            isToolbarReady = true
        }
        .tabViewBottomAccessory(isEnabled: videoManager.shouldShowAccessory) {
            AccessoryControlsView()
                .padding(.leading, 1)
                .padding(.trailing, 15)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $videoManager.isVideoSheetPresented) {
            if let video = sheetRootVideo {
                NavigationStack(path: $videoSheetPath) {
                    VideoView(video: video, followsSelectedVideo: true)
                        .navigationDestination(for: VideoSheetRoute.self) { route in
                            switch route {
                            case .channel(let channelRoute):
                                ChannelView(channelInfo: channelRoute.channelInfo)
                            case .video(let videoRoute):
                                VideoView(video: videoRoute.video, followsSelectedVideo: true)
                            }
                        }
                }
                .environmentObject(videoManager)
                .presentationSizing(.page)
                .presentationDragIndicator(.visible)
            } else {
                ContentUnavailableView("No video selected", systemImage: "play.slash.fill")
                    .presentationSizing(.page)
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            if authService.isAuthenticated {
                selectedTab = .subscriptions
            }
        }
        .onChange(of: videoManager.isVideoSheetPresented) { _, isPresented in
            if isPresented {
                sheetRootVideo = videoManager.selectedVideo
                videoSheetPath.removeAll()
            } else {
                sheetRootVideo = nil
                videoSheetPath.removeAll()
            }
        }
        .onChange(of: videoManager.selectedVideo?.videoId) {
            guard videoManager.isVideoSheetPresented, videoSheetPath.isEmpty else { return }
            if let selectedVideo = videoManager.selectedVideo {
                sheetRootVideo = selectedVideo
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                guard hasCompletedInitialAuthRefresh else { return }
                Task {
                    await authService.refreshAuthenticationFromStoredCookies()
                }
            } else {
                videoManager.saveCurrentPlaybackPosition(force: true)
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            isToolbarReady = false
            if isAuthenticated {
                selectedTab = .subscriptions
            } else {
                selectedTab = .recommended
                playlistService.clearData()
            }
            Task {
                await Task.yield()
                isToolbarReady = true
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
