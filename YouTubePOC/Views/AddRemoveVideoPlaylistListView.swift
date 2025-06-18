import SwiftUI

struct AddRemoveVideoPlaylistListView: View {
    public let video: YouTubeVideo
    
    @StateObject private var playlistsViewModel: VideoPlaylistsViewModel
    
    init(video: YouTubeVideo) {
        self.video = video
        self._playlistsViewModel = StateObject(wrappedValue: VideoPlaylistsViewModel(video: video, playerManager: PlayerManager.shared))
    }
    
    var body: some View {
        if playlistsViewModel.playlistStates.isEmpty {
            Text("No playlists available")
        } else {
            ForEach(playlistsViewModel.playlistStates, id: \.playlist.id) { item in
                if item.isVideoPresentInside {
                    Button(role: .destructive) {
                        playlistsViewModel.removeFromPlaylist(item.playlist)
                    } label: {
                        Label(item.playlist.snippet.title, systemImage: "minus.circle")
                    }
                } else {
                    Button {
                        playlistsViewModel.addToPlaylist(item.playlist)
                    } label: {
                        Label(item.playlist.snippet.title, systemImage: "plus.circle")
                    }
                }
            }
        }
    }
}

#Preview {
    let video = YouTubeVideo(
        id: "cETgTtu6atM",
        snippet: YouTubeVideo.VideoSnippet(
            publishedAt: "2024-03-10T12:00:00Z",
            channelId: "UC9M7-jzdU8CVrQo1JwmIdWA",
            title: "WWDC25: What's new in SwiftUI",
            description: "A preview of the new SwiftUI features announced at WWDC25",
            thumbnails: YouTubeThumbnails(
                default: YouTubeThumbnail(
                    url: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s68-c-k-c0x00ffffff-no-rj",
                    width: 120,
                    height: 90
                ),
                medium: nil,
                high: nil,
                standard: nil,
                maxres: nil
            ),
            channelTitle: "MacRumors",
            tags: ["WWDC25", "SwiftUI", "iOS"],
            categoryId: "28",
            liveBroadcastContent: "none"
        ),
        contentDetails: YouTubeVideo.ContentDetails(
            duration: "PT6M31S",
            dimension: "2d",
            definition: "hd",
            caption: "false",
            licensedContent: true,
            projection: "rectangular"
        ),
        statistics: YouTubeVideo.Statistics(
            viewCount: "64000",
            likeCount: "1200",
            favoriteCount: "0",
            commentCount: "150"
        )
    )
    
    AddRemoveVideoPlaylistListView(video: video)
}
