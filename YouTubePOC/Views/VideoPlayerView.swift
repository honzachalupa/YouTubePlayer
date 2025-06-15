import SwiftUI
import AVKit
import YouTubeKit

struct VideoPlayerView: View {
    let video: YTVideo
    @StateObject private var playerModel: PlayerViewModel
    @State private var isFullscreen: Bool = false
    
    init(video: YTVideo) {
        self.video = video
        _playerModel = StateObject(wrappedValue: PlayerViewModel())
    }
    
    var body: some View {
        Group {
            if playerModel.isLoading {
                Color.gray.opacity(0.2)
                    .overlay {
                        ProgressView()
                            .controlSize(.large)
                    }
            } else if let error = playerModel.error {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle.fill")
            } else {
                if !isFullscreen {
                    VideoPlayer(player: playerModel.player)
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .task {
            playerModel.loadVideo(video: video)
        }
        .onDisappear {
            playerModel.cleanup()
        }
    }
}

#Preview {
    let video = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What's new in SwiftUI | Apple",
        channel: YTLittleChannelInfos(
            channelId: "",
            name: "MacRumors"
        ),
        viewCount: "64K views",
        timeLength: "6:31",
        thumbnails: [
            YTThumbnail(
                url: URL(string: "https://i.ytimg.com/vi/cETgTtu6atM/hq720.jpg?sqp=-oaymwEjCOgCEMoBSFryq4qpAxUIARUAAAAAGAElAADIQj0AgKJDeAE=&rs=AOn4CLCewFWvccdDn7llqNJmmFRGHeOCIQ")!
            )
        ]
    )
    
    VideoPlayerView(video: video)
}
