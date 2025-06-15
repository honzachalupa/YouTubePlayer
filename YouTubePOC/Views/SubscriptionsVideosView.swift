import SwiftUI
import YouTubeKit

struct SubscriptionsVideosView: View {
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil

    func fetchVideos() async {
        do {
            let response = try await AccountSubscriptionsFeedResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [:]
            )
            
            withAnimation {
                // Filter out shorts
                videos = response.results.filter {
                    $0.channel?.thumbnails != nil
                }
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
            VideosGridView(videos: videos, error: fetchError) {
                await fetchVideos()
            }
            .navigationTitle("Subscriptions")
        }
    }
}

#Preview {
    SubscriptionsVideosView()
}
