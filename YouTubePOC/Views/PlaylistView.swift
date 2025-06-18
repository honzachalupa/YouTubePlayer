import SwiftUI

func getPlaylistIcon(_ playlistTitle: String?) -> String {
    switch playlistTitle {
        case "Liked videos": "heart.fill"
        case "Watch later": "star.fill"
        default: "play.fill"
    }
}

struct PlaylistView: View {
    public var playlist: YouTubePlaylist
    
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
    @State private var videos: [YouTubeVideo] = []
    @State private var isLoading = false
    @State private var fetchError: Error? = nil
    @State private var searchText: String = ""
    
    var filteredVideos: [YouTubeVideo] {
        if searchText.isEmpty {
            return videos
        }
        
        return videos.filter { video in
            video.snippet.title.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationStack {
            VideosGridView(
                videos: filteredVideos,
                title: "\(playlist.snippet.title) playlist",
                isLoading: isLoading,
                onLoadMore: {
                    await fetchVideos()
                }
            )
            .searchable(text: $searchText, prompt: "Search videos in playlist")
        }
    }
    
    func fetchVideos() async {
        isLoading = true
        do {
            let items = try await YouTubePlaylistService.shared.fetchPlaylistItems(playlistId: playlist.id)
            withAnimation {
                videos = items.map { item in
                    YouTubeVideo(
                        id: item.contentDetails?.videoId ?? item.snippet.resourceId.videoId,
                        snippet: .init(
                            publishedAt: item.snippet.publishedAt,
                            channelId: item.snippet.channelId,
                            title: item.snippet.title,
                            description: item.snippet.description,
                            thumbnails: item.snippet.thumbnails,
                            channelTitle: item.snippet.channelTitle,
                            tags: nil,
                            categoryId: "",
                            liveBroadcastContent: ""
                        ),
                        contentDetails: nil,
                        statistics: nil
                    )
                }
                isLoading = false
            }
        } catch {
            withAnimation {
                fetchError = error
                videos = []
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistView(playlist: YouTubePlaylist.example)
    }
    .environmentObject(YouTubeServiceWrapper())
}
