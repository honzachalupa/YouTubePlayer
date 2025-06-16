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
                        
                        HStack {
                            Group {
                                Button {
                                    Task {
                                        await video.likeVideo(youtubeModel: YTM.model)
                                    }
                                } label: {
                                    Label("Like", systemImage: "hand.thumbsup")
                                }
                                
                                Button {
                                    Task {
                                        await video.dislikeVideo(youtubeModel: YTM.model)
                                    }
                                } label: {
                                    Label("Disike", systemImage: "hand.thumbsdown")
                                }
                                
                                ShareLink(item: "https://www.youtube.com/watch?v=\(video.videoId)") {
                                    Label("Share", systemImage: "arrowshape.turn.up.right.fill")
                                }
                                
                                Button { } label: {
                                    Label("Save", systemImage: "square.and.arrow.down.fill")
                                }
                                .disabled(true)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if let description {
                            ScrollView(.vertical) {
                                Text(.init(description))
                            }
                        }
                    }
                    .padding(15)
                    
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
