import SwiftUI
import YouTubeKit

// By moving the conformance here, we can often resolve build system warnings
// while keeping the functionality that depends on it.
extension YTVideo: @retroactive Identifiable {
    public var id: String { self.videoId }
}

struct RecommendedVideosView: View {
    // A concrete viewModel, initialized with the specific fetcher for the home screen.
    @StateObject private var viewModel = VideoListViewModel(videoFetcher: {
        // This closure provides the logic for fetching home screen videos.
        let response = try await HomeScreenResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [:])
        return response.results
    })

    var body: some View {
        // Use the generic VideosListView, passing in the viewModel and a title.
        VideosListView(viewModel: viewModel, navigationTitle: "Recommended")
    }
}

#Preview {
    RecommendedVideosView()
}
