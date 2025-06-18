import SwiftUI

struct AccessoryControlsView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement
    @EnvironmentObject private var playerManager: PlayerManager
    @State private var isPlaying = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private func updatePlayState() {
        isPlaying = playerManager.isPlaying
    }
    
    var body: some View {
        HStack {
            if let video = playerManager.selectedVideo {
                if let thumbnailUrl = URL(string: video.snippet.thumbnails.default?.url ?? ""), accessoryPlacement != .inline {
                    AsyncImage(url: thumbnailUrl) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .padding(.leading, 0)
                        }
                    }
                }
                
                Text(video.snippet.title)
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
        playerManager.selectedVideo = YouTubeVideo(
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
        
        return AccessoryControlsView()
            .environmentObject(playerManager)
    }
}
