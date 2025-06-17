import SwiftUI
import YouTubeKit

func getPlaylistIcon(_ playlistTitle: String?) -> String {
    switch playlistTitle {
        case "Liked videos": "heart.fill"
        case "Watch later": "star.fill"
        default: "play.fill"
    }
}

struct PlaylistView: View {
    public var playlist: YTPlaylist
    
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
    @State private var videos: [YTVideo] = []
    @State private var searchText: String = ""
    
    var filteredVideos: [YTVideo] {
        if searchText.isEmpty {
            return videos
        }
        
        return videos.filter { video in
            guard let title = video.title else { return false }
            return title.lowercased().contains(searchText.lowercased())
        }
    }
    
    func fetchVideos() async {
        do {
            await youtubeService.getVisitorData()
            
            let response = try await playlist.fetchVideosThrowing(
                youtubeModel: YTM.model
            )
            
            withAnimation {
                videos = response.results
            }
        } catch {
            print(error.localizedDescription)
            
            withAnimation {
                videos = []
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VideosGridView(videos: filteredVideos) {
                await fetchVideos()
            }
            .searchable(text: $searchText, prompt: "Search videos in playlist")
            .navigationTitle(playlist.title != nil ? "\(playlist.title ?? "") playlist" : "Playlist")
        }
    }
}

#Preview {
    let playlist = YTPlaylist(
        id: 123,
        playlistId: "123",
        title: "Title",
        thumbnails: [],
        videoCount: "videoCount",
        channel: nil,
        timePosted: "timePosted",
        frontVideos: []
    )
    
    PlaylistView(playlist: playlist)
}
