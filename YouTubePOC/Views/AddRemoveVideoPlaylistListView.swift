import SwiftUI
import YouTubeKit

struct AddRemoveVideoPlaylistListView: View {
    public let video: YTVideo
    
    @StateObject private var playlistsViewModel: VideoPlaylistsViewModel
    
    init(video: YTVideo) {
        self.video = video
        self._playlistsViewModel = StateObject(wrappedValue: VideoPlaylistsViewModel(video: video, playerManager: PlayerManager()))
    }
    
    var body: some View {
        if playlistsViewModel.playlistStates.isEmpty {
            Text("No playlists available")
        } else {
            ForEach(playlistsViewModel.playlistStates, id: \.playlist.playlistId) { item in
                if item.isVideoPresentInside {
                    Button(role: .destructive) {
                        playlistsViewModel.removeFromPlaylist(item.playlist)
                    } label: {
                        Label(item.playlist.title ?? "", systemImage: "minus.circle")
                    }
                } else {
                    Button {
                        playlistsViewModel.addToPlaylist(item.playlist)
                    } label: {
                        Label(item.playlist.title ?? "", systemImage: "plus.circle")
                    }
                }
            }
        }
    }
}

#Preview {
    let video = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What's new in SwiftUI",
        channel: YTLittleChannelInfos(
            channelId: "",
            name: "MacRumors",
            thumbnails: [
                YTThumbnail(url: URL(string: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s68-c-k-c0x00ffffff-no-rj")!)
            ]
        ),
        viewCount: "64K views",
        timeLength: "6:31",
        thumbnails: [
            YTThumbnail(
                url: URL(string: "https://i.ytimg.com/vi/cETgTtu6atM/hq720.jpg?sqp=-oaymwEjCOgCEMoBSFryq4qpAxUIARUAAAAAGAElAADIQj0AgKJDeAE=&rs=AOn4CLCewFWvccdDn7llqNJmmFRGHeOCIQ")!
            )
        ]
    )
    
    AddRemoveVideoPlaylistListView(video: video)
}
