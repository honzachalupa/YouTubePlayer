import SwiftUI
import YouTubeKit

struct SubscriptionsVideosView: View {
    @StateObject private var viewModel = VideoListViewModel(videoFetcher: {
        let response = try await AccountSubscriptionsFeedResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [:])
        return response.results
    })

    var body: some View {
        VideosListView(viewModel: viewModel, navigationTitle: "Subscriptions")
    }
}

#Preview {
    SubscriptionsVideosView()
}
