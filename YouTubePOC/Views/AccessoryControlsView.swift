import SwiftUI
import YouTubeKit

struct AccessoryControlsView: View {
    @EnvironmentObject private var playerManager: PlayerManager
    @State private var isPlaying = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private func updatePlayState() {
        isPlaying = playerManager.isPlaying
    }
    
    var body: some View {
        HStack {
            if let video = playerManager.selectedVideo {
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
                
                Text(video.title ?? "")
                    .font(.callout)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .onTapGesture {
                        playerManager.isVideoSheetPresented = true
                    }
                
                Button {
                    playerManager.togglePlayPause()
                } label: {
                    Label(
                        isPlaying ? "Pause" : "Play",
                        systemImage: isPlaying ? "pause.fill" : "play.fill"
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

struct AccessoryControlsView_Previews: PreviewProvider {
    static var previews: some View {
        let playerManager = PlayerManager()
        playerManager.selectedVideo = YTVideo(
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
            .environmentObject(playerManager)
    }
}
