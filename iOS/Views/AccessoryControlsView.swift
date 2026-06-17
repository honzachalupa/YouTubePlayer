import SwiftUI
import YouTubeKit

struct AccessoryControlsView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement
    @EnvironmentObject private var videoManager: VideoManager
    
    private var videoTitle: String {
        videoManager.selectedVideo?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    var body: some View {
        Group {
            if let video = videoManager.selectedVideo {
                HStack {
                    if let thumbnailUrl = video.channel?.thumbnails.first?.url {
                        AsyncImage(url: thumbnailUrl) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .layoutPriority(2)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .padding(.leading, 2)
                    }
                    
                    Text(videoTitle)
                        .font(.callout)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .labelStyle(.iconOnly)
                    }
                    .fixedSize()
                    .layoutPriority(2)
                }
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
