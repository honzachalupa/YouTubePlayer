import SwiftUI
import YouTubeKit

struct VideoActionsView: View {
    public let video: YTVideo
    
    @EnvironmentObject private var playerManager: PlayerManager
    
    var body: some View {
        HStack {
            Group {
                Button {
                    playerManager.toggleLike()
                } label: {
                    Label("Like", systemImage: playerManager.likeStatus == .liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                .tint(playerManager.likeStatus == .liked ? .green : .none)
                .symbolEffect(.bounce, value: playerManager.likeStatus == .liked)
                
                Button {
                    playerManager.toggleDislike()
                } label: {
                    Image(systemName: playerManager.likeStatus == .disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                }
                .tint(playerManager.likeStatus == .disliked ? .red : .none)
                .symbolEffect(.bounce, value: playerManager.likeStatus == .disliked)
                
                ShareLink(item: "https://www.youtube.com/watch?v=\(video.videoId)") {
                    Label("Share", systemImage: "arrowshape.turn.up.right.fill")
                }
                
                Menu {
                    AddRemoveVideoPlaylistListView(video: video)
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down.fill")
                }
                .menuStyle(.button)
                .foregroundStyle(.primary)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .glassEffect(.regular.interactive())
            }
            .buttonStyle(.glass)
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
    
    VideoActionsView(video: video)
        .environmentObject(PlayerManager())
}
