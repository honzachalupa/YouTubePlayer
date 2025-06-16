import SwiftUI
import YouTubeKit

struct VideoView: View {
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
    @EnvironmentObject private var playerManager: PlayerManager
    @State private var description: String? = nil
    
    func fetchDetails() async {
        if let videoId = playerManager.selectedVideo?.videoId {
            do {
                await youtubeService.getVisitorData()
                
                let response = try await VideoInfosResponse.sendThrowingRequest(
                    youtubeModel: YTM.model,
                    data: [.query: videoId]
                )
                
                withAnimation {
                    description = response.videoDescription
                }
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Video ID not provided.")
        }
    }
    
    var body: some View {
        if let video = playerManager.selectedVideo {
            NavigationStack {
                VStack {
                    VideoPlayerView(video: video)
                        .id(video.videoId) // Force recreation when video changes
                    
                    ScrollView(.vertical) {
                        HStack {
                            VStack(alignment: .leading, spacing: 15) {
                                Text(video.title ?? "")
                                    .font(.title)
                                
                                if let channelInfo = video.channel {
                                    NavigationLink(value: channelInfo) {
                                        ChannelInfoView(channel: channelInfo)
                                    }
                                    .foregroundStyle(.foreground)
                                }
                                
                                VideoStatsView(video: video)
                                VideoActionsView(video: video)
                                
                                if let description {
                                    Text(.init(description))
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(15)
                    }
                    
                    Spacer()
                }
                .navigationDestination(for: YTLittleChannelInfos.self) { channelInfo in
                    ChannelView(channelInfo: channelInfo)
                }
                .task { await fetchDetails() }
            }
        }
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            VideoView()
        }
        .environmentObject(YTM.shared)
}
