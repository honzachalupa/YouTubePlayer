import SwiftUI
import YouTubeKit

struct SearchVideosView: View {
    @State private var query: String = "Jon Olson"
    @State private var videos: [YTVideo] = []
    @State private var channels: [YTChannel] = []
    @State private var fetchError: Error? = nil

    func searchVideos() async {
        guard !query.isEmpty else {
            withAnimation {
                videos = []
            }
            
            return
        }
        
        do {
            let response = try await SearchResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [.query: query]
            )
            
            withAnimation {
                videos = response.results.compactMap { $0 as? YTVideo }
                channels = response.results.compactMap { $0 as? YTChannel }
            }
        } catch {
            withAnimation {
                fetchError = error
                videos = []
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(channels, id: \.channelId) { channel in
                        NavigationLink {
                            ChannelView(channel: channel)
                        } label: {
                            Text(channel.name ?? "")
                                .frame(width: 150, height: 150)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
            }
            
            VideosGridView(videos: videos, error: fetchError) {
                await searchVideos()
            }
            .onChange(of: query) {
                Task { await searchVideos() }
            }
            .searchable(text: $query, prompt: "Search videos or channels...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccountLinkView()
                }
            }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchVideosView()
}
