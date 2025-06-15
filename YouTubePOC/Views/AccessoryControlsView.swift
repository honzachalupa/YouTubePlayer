import SwiftUI
import YouTubeKit

struct AccessoryControlsView: View {
    @EnvironmentObject private var videoState: VideoStateManager
    @StateObject private var playerModel = PlayerViewModel()
    
    var body: some View {
        HStack {
            if let video = videoState.selectedVideo {
                if let thumbnailUrl = video.thumbnails.first?.url {
                    AsyncImage(url: thumbnailUrl) { phase in
                        Group {
                            if let image = phase.image {
                                image.resizable()
                            } else {
                                Color.gray.opacity(0.2)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        }
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                VStack(alignment: .leading) {
                    Text(video.title ?? "")
                        .font(.callout)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    if let channelName = video.channel?.name {
                        Text(channelName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button {
                    videoState.isVideoSheetPresented = true
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .padding(.leading, 5)
            } else {
                EmptyView()
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    let videoStateManager = VideoStateManager()
    videoStateManager.selectedVideo = YTVideo(
        videoId: "cETgTtu6atM",
        title: "WWDC25: What's new in SwiftUI | Apple",
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
    
    return AccessoryControlsView()
        .environmentObject(videoStateManager)
}
