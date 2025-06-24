import SwiftUI
import YouTubeKit

struct SearchVideosView: View {
    private let youtubeService = YouTubeService.shared
    @State private var query = ""
    @State private var videos: [YTVideo] = []
    @State private var channels: [YTChannel] = []
    @State private var fetchError: Error? = nil
    @State private var isLoading = false
    @State private var continuationToken: String? = nil
    @State private var hasMoreResults = true
    @State private var visitorData: String? = nil

    func searchVideos(loadMore: Bool = false) async {
        print("searchVideos called with loadMore: \(loadMore)")
        print("Current continuation token: \(continuationToken ?? "none")")
        print("Current query: \(query)")
        
        guard !query.isEmpty && !isLoading else {
            if query.isEmpty {
                withAnimation {
                    videos = []
                    channels = []
                    continuationToken = nil
                    hasMoreResults = false
                }
            }
            return
        }
        
        isLoading = true
        
        do {
            if loadMore {
                guard let token = continuationToken, let visitorData = visitorData else {
                    print("Missing token or visitor data for continuation")
                    isLoading = false
                    return
                }
                
                let data: [HeadersList.AddQueryInfo.ContentTypes: String] = [
                    .continuation: token,
                    .visitorData: visitorData
                ]
                
                print("Continuation request data: \(data)")
                
                let response = try await SearchResponse.Continuation.sendThrowingRequest(
                    youtubeModel: youtubeService.model,
                    data: data
                )
                
                print("Continuation response - token: \(response.continuationToken ?? "none"), results: \(response.results.count)")
                
                withAnimation {
                    videos.append(contentsOf: response.results.compactMap { $0 as? YTVideo })
                    continuationToken = response.continuationToken
                    hasMoreResults = response.continuationToken != nil
                }
            } else {
                let data: [HeadersList.AddQueryInfo.ContentTypes: String] = [
                    .query: query
                ]
                
                print("Initial search request data: \(data)")
                
                let response = try await SearchResponse.sendThrowingRequest(
                    youtubeModel: youtubeService.model,
                    data: data
                )
                
                print("Initial response - token: \(response.continuationToken ?? "none"), results: \(response.results.count), visitor data: \(response.visitorData ?? "none")")
                
                withAnimation {
                    videos = response.results.compactMap { $0 as? YTVideo }
                    channels = response.results.compactMap { $0 as? YTChannel }
                    continuationToken = response.continuationToken
                    visitorData = response.visitorData
                    hasMoreResults = response.continuationToken != nil
                }
            }
        } catch {
            print("Search error: \(error)")
            fetchError = error
        }
        
        isLoading = false
    }
    
    var body: some View {
        VStack {
            if !channels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(channels, id: \.channelId) { channel in
                            NavigationLink(destination: ChannelView(channel: channel)) {
                                VStack {
                                    AsyncImage(url: channel.thumbnails.first?.url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    
                                    Text(channel.name ?? "Unknown")
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 100)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            VideosGridView(
                videos: videos,
                error: fetchError,
                fetchVideos: { await searchVideos() },
                loadMoreIfNeeded: { video in
                    print("Load more triggered for video: \(video.videoId)")
                    Task {
                        await searchVideos(loadMore: true)
                    }
                }
            )
        }
        .searchable(text: $query, prompt: "Search videos or channels...")
        .onChange(of: query) {
            Task { await searchVideos() }
        }
    }
}

#Preview {
    SearchVideosView()
}
