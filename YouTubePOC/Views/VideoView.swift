import SwiftUI
import YouTubeKit

struct VideoView: View {
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
    @EnvironmentObject private var playerManager: PlayerManager
    @StateObject private var messageService = MessageService.shared
    @State private var description: String? = nil
    
    func fetchDetails() async {
        if let video = playerManager.selectedVideo {
            do {
                await youtubeService.getVisitorData()
                
                let response = try await video.fetchMoreInfosThrowing(
                    youtubeModel: YTM.model
                )
                
                withAnimation {
                    description = response.videoDescription?.map { part in
                        part.text ?? ""
                    }.joined()
                }
            } catch {
                messageService.show(message: error.localizedDescription, type: .error)
            }
        } else {
            messageService.show(message: "Error: Video ID not provided.", type: .error)
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
                                        VideoInfoView(video: video, mainLabel: .channelName)
                                    }
                                    .foregroundStyle(.foreground)
                                }
                                
                                VideoActionsView(video: video)
                                
                                if let description {
                                    Text(.init(description))
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(20)
                    }
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
                .environmentObject(YouTubeServiceWrapper(model: YTM.model))
                .environmentObject(PlayerManager())
        }
}
