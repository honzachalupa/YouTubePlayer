import SwiftUI
import YouTubeKit

struct VideoActionsToolbarView: ToolbarContent {
    public let video: YTVideo
    
    @EnvironmentObject private var videoManager: VideoManager

    private var isVideoInAnyPlaylist: Bool {
        videoManager.selectedVideo?.videoId == video.videoId
            && videoManager.availablePlaylistsVideoId == video.videoId
            && videoManager.availablePlaylists.contains { $0.isVideoPresentInside }
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button {
                Task { await videoManager.likeVideo() }
            } label: {
                Image(systemName: videoManager.likeStatus == .liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    
                Text("Like")
            }
            .tint(videoManager.likeStatus == .liked ? .green : .none)
            .symbolEffect(.bounce, value: videoManager.likeStatus == .liked)
        }
        
        #if !os(tvOS)
        ToolbarSpacer(.fixed, placement: .bottomBar)
        #endif
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                Task { await videoManager.dislikeVideo() }
            } label: {
                Image(systemName: videoManager.likeStatus == .disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
            .tint(videoManager.likeStatus == .disliked ? .red : .none)
            .symbolEffect(.bounce, value: videoManager.likeStatus == .disliked)
        }
        
        #if !os(tvOS)
        ToolbarSpacer(placement: .bottomBar)
        #endif
        
        #if os(iOS)
        ToolbarItem(placement: .bottomBar) {
            ShareLink(item: "https://www.youtube.com/watch?v=\(video.videoId)") {
                Label("Share", systemImage: "arrowshape.turn.up.right")
            }
        }
        #endif
        
        ToolbarItem(placement: .bottomBar) {
            Menu {
                AddRemoveVideoPlaylistListView(video: video)
                    .id(video.videoId)
            } label: {
                Label("Save", systemImage: isVideoInAnyPlaylist ? "bookmark.fill" : "bookmark")
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
    
    NavigationStack {
        Color.clear
            .toolbar {
                VideoActionsToolbarView(video: video)
            }
    }
    .environmentObject(VideoManager())
}
