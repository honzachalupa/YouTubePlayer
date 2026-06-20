import SwiftUI
import YouTubeKit

struct ChannelView: View {
    private let youtubeService = YouTubeService.shared
    private let initialChannel: YTChannel?
    private let initialChannelInfo: YTLittleChannelInfos

    @State private var channelResponse: ChannelInfosResponse?
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error?
    @State private var isLoadingChannel = false
    @State private var isLoadingMore = false

    init(channel: YTChannel) {
        initialChannel = channel
        initialChannelInfo = YTLittleChannelInfos(
            channelId: channel.channelId,
            name: channel.name,
            thumbnails: channel.thumbnails
        )
    }

    init(channelInfo: YTLittleChannelInfos) {
        initialChannel = nil
        initialChannelInfo = channelInfo
    }

    private var channelID: String {
        initialChannelInfo.channelId
    }

    private var displayName: String {
        channelResponse?.name
            ?? initialChannelInfo.name
            ?? initialChannel?.name
            ?? "Channel"
    }

    private var displayHandle: String? {
        channelResponse?.handle ?? initialChannel?.handle
    }

    private var displaySubscriberCount: String? {
        channelResponse?.subscriberCount ?? initialChannel?.subscriberCount
    }

    private var displayVideoCount: String? {
        channelResponse?.videoCount ?? initialChannel?.videoCount
    }

    private var displayDescription: String? {
        channelResponse?.shortDescription
    }

    private var displayAvatarURL: URL? {
        channelResponse?.avatarThumbnails.last?.url
            ?? initialChannelInfo.thumbnails.last?.url
            ?? initialChannel?.thumbnails.last?.url
    }

    private var displayBannerURL: URL? {
        channelResponse?.bannerThumbnails.last?.url
    }

    private var hasVideoContinuation: Bool {
        guard let channelResponse else { return false }

        switch channelResponse.channelContentContinuationStore[.videos] {
        case .some(.some):
            return true
        default:
            return false
        }
    }

    private var channelStatsLine: String? {
        [displayHandle, displaySubscriberCount, displayVideoCount]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " • ")
            .nilIfEmpty
    }

    private func resolvedVideos(from response: ChannelInfosResponse) -> [YTVideo] {
        guard let content = response.channelContentStore[.videos] as? ChannelInfosResponse.Videos else {
            return []
        }

        return content.items.compactMap { $0 as? YTVideo }
    }

    private func fetchChannel() async {
        guard !isLoadingChannel else { return }

        isLoadingChannel = true
        fetchError = nil

        do {
            await youtubeService.getVisitorData()

            let baseResponse = try await initialChannelInfo.fetchInfosThrowing(
                youtubeModel: youtubeService.model,
                useCookies: true
            )
            let videosResponse = try await baseResponse.getChannelContentReusingCacheThrowing(
                forType: .videos,
                youtubeModel: youtubeService.model,
                useCookies: true
            )

            withAnimation {
                channelResponse = videosResponse
                videos = resolvedVideos(from: videosResponse)
            }
        } catch {
            fetchError = error
        }

        isLoadingChannel = false
    }

    private func loadMoreVideos() async {
        guard !isLoadingMore, hasVideoContinuation, var channelResponse else { return }

        isLoadingMore = true

        do {
            let continuation = try await channelResponse.getChannelContentContinuationThrowing(
                ChannelInfosResponse.Videos.self,
                youtubeModel: youtubeService.model,
                useCookies: true
            )

            channelResponse.mergeListableChannelContentContinuation(continuation)

            withAnimation {
                self.channelResponse = channelResponse
                videos = resolvedVideos(from: channelResponse)
            }
        } catch {
            fetchError = error
        }

        isLoadingMore = false
    }

    var body: some View {
        Group {
            if channelID.isEmpty {
                ContentUnavailableView(
                    "Channel unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ChannelHeaderView(
                            name: displayName,
                            statsLine: channelStatsLine,
                            description: displayDescription,
                            avatarURL: displayAvatarURL,
                            bannerURL: displayBannerURL
                        )

                        Divider()

                        ChannelVideosSection(
                            videos: videos,
                            error: fetchError,
                            isLoading: isLoadingChannel,
                            isLoadingMore: isLoadingMore,
                            channelThumbnailURL: displayAvatarURL,
                            loadMoreAction: hasVideoContinuation ? {
                                Task {
                                    await loadMoreVideos()
                                }
                            } : nil
                        )
                    }
                }
                .refreshable {
                    await fetchChannel()
                }
                .task(id: channelID) {
                    await fetchChannel()
                }
            }
        }
        .navigationTitle(displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct ChannelHeaderView: View {
    let name: String
    let statsLine: String?
    let description: String?
    let avatarURL: URL?
    let bannerURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.quaternary)
                .overlay {
                    if let bannerURL {
                        AsyncImage(url: bannerURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if avatarURL != nil {
                        ChannelAvatarView(url: avatarURL, size: 88)
                            .padding(16)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let statsLine, !statsLine.isEmpty {
                    Text(statsLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChannelVideosSection: View {
    let videos: [YTVideo]
    let error: Error?
    let isLoading: Bool
    let isLoadingMore: Bool
    let channelThumbnailURL: URL?
    let loadMoreAction: (() -> Void)?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 20, alignment: .top)]
    }

    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                AppProgressView()
                    .frame(minHeight: 80)
                    .padding(.vertical, 40)
            } else if let error, videos.isEmpty {
                ContentUnavailableView(
                    "Failed to load channel",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(error.localizedDescription)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if videos.isEmpty {
                ContentUnavailableView("No videos found", systemImage: "play.slash.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(videos, id: \.videoId) { video in
                        VideoGridItemView(
                            video: video,
                            navigationValue: .video(VideoSheetVideoRoute(video: video)),
                            channelThumbnailURL: channelThumbnailURL
                        )
                            .onAppear {
                                if let lastVideo = videos.last, lastVideo.videoId == video.videoId {
                                    loadMoreAction?()
                                }
                        }
                    }

                    if isLoadingMore {
                        AppProgressView(.inline)
                            .frame(maxWidth: .infinity)
                            .gridCellColumns(columns.count)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

private struct ChannelAvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.quaternary)

            if let url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.clear
                }
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview("Channel From Search") {
    NavigationStack {
        ChannelView(
            channel: YTChannel(
                name: "OpenAI",
                channelId: "UCtcmk_u_kqeibnHqxTSNitg",
                handle: "@openai",
                thumbnails: [
                    YTThumbnail(url: URL(string: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s176-c-k-c0x00ffffff-no-rj")!)
                ],
                subscriberCount: "1M subscribers",
                videoCount: "250 videos"
            )
        )
    }
}

#Preview("Channel From Video") {
    NavigationStack {
        ChannelView(
            channelInfo: YTLittleChannelInfos(
                channelId: "UCtcmk_u_kqeibnHqxTSNitg",
                name: "OpenAI",
                thumbnails: [
                    YTThumbnail(url: URL(string: "https://yt3.ggpht.com/QM10AqUfNyZxhp92xKOfs5PBnS5vCngEKlbiC--ZHTraiZRubULznnjh9lDWFiGYLkLTRf3g=s176-c-k-c0x00ffffff-no-rj")!)
                ]
            )
        )
    }
}
