import SwiftUI
import YouTubeKit

struct AccessoryControlsView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement
    @EnvironmentObject private var videoManager: VideoManager
    @State private var isPlaying = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private func updatePlayState() {
        isPlaying = videoManager.isPlaying
    }
    
    var body: some View {
        HStack {
            if let video = videoManager.selectedVideo {
                if let thumbnailUrl = video.channel?.thumbnails.first?.url, accessoryPlacement != .inline {
                    AsyncImage(url: thumbnailUrl) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .padding(.leading, 0)
                        }
                    }
                }
                
                Text(video.title ?? "")
                    .font(.callout)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .onTapGesture {
                        videoManager.isVideoSheetPresented = true
                    }
                
                Button {
                    videoManager.togglePlayPause()
                } label: {
                    Label(
                        videoManager.isPlaying ? "Pause" : "Play",
                        systemImage: videoManager.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                .onReceive(timer) { _ in
                    updatePlayState()
                }
                .padding(.leading, 5)
            }
        }
    }
}

#Preview {
    let videoManager = VideoManager()
    videoManager.selectedVideo = YTVideo(
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
                width: 480,
                height: 360,
                url: URL(string: "https://i.ytimg.com/vi/cETgTtu6atM/hq720.jpg?sqp=-oaymwEjCOgCEMoBSFryq4qpAxUIARUAAAAAGAElAADIQj0AgKJDeAE=&rs=AOn4CLCewFWvccdDn7llqNJmmFRGHeOCIQ")!
            )
        ]
    )
    
    return AccessoryControlsView()
        .environmentObject(videoManager)
}
