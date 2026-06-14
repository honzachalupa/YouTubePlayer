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
    @State private var recommendedVideos: [YTVideo] = []
    @State private var moreInfosResponse: MoreVideoInfosResponse?
    @State private var isLoadingMoreRecommended = false
    
    private var currentVideo: YTVideo {
        videoManager.selectedVideo ?? video
    }

    func fetchDetails(for video: YTVideo) async {
        do {
            await youtubeService.getVisitorData()
            
            let response = try await video.fetchMoreInfosThrowing(
                youtubeModel: youtubeService.model
            )
            
            guard currentVideo.videoId == video.videoId else { return }
            
            withAnimation {
                moreInfosResponse = response
                description = response.videoDescription?.map { part in
                    part.text ?? ""
                }.joined()
                recommendedVideos = response.recommendedVideos.compactMap { $0 as? YTVideo }
            }
        } catch {
            messageService.show(message: error.localizedDescription, type: .error)
        }
    }

    private func loadMoreRecommendedIfNeeded(current video: YTVideo) {
        guard let lastVideo = recommendedVideos.last,
              video.videoId == lastVideo.videoId,
              !isLoadingMoreRecommended else {
            return
        }

        Task { await fetchMoreRecommendedVideos() }
    }

    private func fetchMoreRecommendedVideos() async {
        guard var response = moreInfosResponse,
              response.recommendedVideosContinuationToken != nil else {
            return
        }

        isLoadingMoreRecommended = true

        do {
            let continuation = try await response.getRecommendedVideosContinationThrowing(
                youtubeModel: youtubeService.model
            )
            response.mergeRecommendedVideosContination(continuation)
            let newVideos = continuation.results.compactMap { $0 as? YTVideo }

            withAnimation {
                moreInfosResponse = response
                recommendedVideos.append(contentsOf: newVideos)
            }
        } catch {
            print("Error loading more recommended videos:", error)
        }

        isLoadingMoreRecommended = false
    }
    
    var body: some View {
        NavigationStack {
            XStack(isVertical: horizontalSizeClass == .compact) {
                Group {
                    if horizontalSizeClass == .regular {
                        ZStack {
                            Color.black.ignoresSafeArea()
                            
                            VideoPlayerView(video: currentVideo)
                                .offset(y: -40) // Counteract the toolbar spacing
                        }
                    } else {
                        VideoPlayerView(video: currentVideo)
                    }
                }
                .id(currentVideo.videoId)
                
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 18) {
                        videoDetailsSection

                        if !recommendedVideos.isEmpty {
                            recommendedVideosSection
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                #if os(iOS)
                .frame(width: horizontalSizeClass == .regular ? 420 : nil)
                #endif
            }
            .navigationDestination(for: YTLittleChannelInfos.self) { channelInfo in
                ChannelView(channelInfo: channelInfo)
            }
            .toolbar {
                if horizontalSizeClass == .regular {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .task(id: currentVideo.videoId) {
            description = nil
            recommendedVideos = []
            moreInfosResponse = nil
            await fetchDetails(for: currentVideo)
        }
        .onAppear {
            print("VideoView appeared")
        }
    }

    private var videoDetailsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(currentVideo.title ?? "")
                .font(.title)
            
            if let channelInfo = currentVideo.channel {
                NavigationLink(value: channelInfo) {
                    VideoInfoView(video: currentVideo, mainLabel: .channelName)
                }
                .foregroundStyle(.foreground)
            }
            
            VideoActionsView(video: currentVideo)
            
            if let description {
                Text(.init(description))
            }
        }
    }

    private var recommendedVideosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Related")
                .font(.headline)

            LazyVStack(spacing: 10) {
                ForEach(recommendedVideos, id: \.videoId) { video in
                    RelatedVideoRow(video: video)
                        .onAppear {
                            loadMoreRecommendedIfNeeded(current: video)
                        }
                }

                if isLoadingMoreRecommended {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

private struct RelatedVideoRow: View {
    let video: YTVideo

    @EnvironmentObject private var videoManager: VideoManager

    var body: some View {
        Button {
            videoManager.selectVideo(video)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    if let thumbnailURL = video.thumbnails.last?.url {
                        AsyncImage(url: thumbnailURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                    }

                    if let timeLength = video.timeLength {
                        Text(timeLength)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                            .padding(5)
                    }
                }
                .frame(width: 150, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(video.channel?.name ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    let metadata = [video.viewCount, video.timePosted]
                        .compactMap { $0 }
                        .joined(separator: " • ")

                    if !metadata.isEmpty {
                        Text(metadata)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VideoView(video: YTVideo(videoId: "dQw4w9WgXcQ"))
        .environmentObject(VideoManager())
}
