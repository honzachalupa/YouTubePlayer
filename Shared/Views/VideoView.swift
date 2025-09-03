import SwiftUI
import YouTubeKit

struct VideoView: View {
    public let video: YTVideo
    
    private let youtubeService = YouTubeService.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var videoManager: VideoManager
    @StateObject private var messageService = MessageService.shared
    @State private var description: String? = nil
    
    func fetchDetails() async {
        do {
            await youtubeService.getVisitorData()
            
            let response = try await video.fetchMoreInfosThrowing(
                youtubeModel: youtubeService.model
            )
            
            withAnimation {
                description = response.videoDescription?.map { part in
                    part.text ?? ""
                }.joined()
            }
        } catch {
            messageService.show(message: error.localizedDescription, type: .error)
        }
    }
    
    var body: some View {
        NavigationStack {
            XStack(isVertical: horizontalSizeClass == .compact) {
                Group {
                    if horizontalSizeClass == .regular {
                        ZStack {
                            Color.black.ignoresSafeArea()
                            
                            VideoPlayerView(video: video)
                                .offset(y: -40) // Counteract the toolbar spacing
                        }
                    } else {
                        VideoPlayerView(video: video)
                    }
                }
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
                    .padding()
                }
            }
            .navigationDestination(for: YTLittleChannelInfos.self) { channelInfo in
                ChannelView(channelInfo: channelInfo)
            }
            .toolbar {
                if horizontalSizeClass == .regular {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Close", systemImage: "xmark")
                        }
                    }
                }
            }
        }
        .task { await fetchDetails() }
        .onAppear {
            print("VideoView appeared")
        }
    }
}

#Preview {
    VideoView(video: YTVideo(videoId: "dQw4w9WgXcQ"))
        .environmentObject(VideoManager())
}
