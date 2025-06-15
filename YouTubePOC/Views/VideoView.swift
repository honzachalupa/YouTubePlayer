import SwiftUI
import YouTubeKit

struct VideoView: View {
    @EnvironmentObject private var youtubeService: YouTubeServiceWrapper
    @EnvironmentObject private var videoState: VideoStateManager
    
    var body: some View {
        if let video = videoState.selectedVideo {
            NavigationStack {
                VStack {
                    VideoPlayerView(video: video)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text(video.title ?? "")
                            .font(.title)
                        
                        if let channelInfo = video.channel {
                            NavigationLink(value: channelInfo) {
                                ChannelInfoView(channel: channelInfo)
                            }
                            .foregroundStyle(.foreground)
                        }
                        
                        Text("Posted: \(video.timePosted ?? ""), views count: \(video.viewCount ?? "")")
                            .font(.caption)
                        
                        HStack {
                            ControlGroup {
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
                            }
                            
                            Button { } label: {
                                Label("Share", systemImage: "arrowshape.turn.up.right.fill")
                            }
                            
                            Button { } label: {
                                Label("Save", systemImage: "square.and.arrow.down.fill")
                            }
                        }
                    }
                    .padding(15)
                    
                    Spacer()
                }
                .navigationDestination(for: YTLittleChannelInfos.self) { channelInfo in
                    ChannelView(channelInfo: channelInfo)
                }
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
