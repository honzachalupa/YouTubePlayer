import SwiftUI

struct SearchVideosView: View {
    @StateObject private var videoService = YouTubeVideoService.shared
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        VideosGridView(
            videos: videoService.videos,
            title: "Search",
            isLoading: videoService.isLoading,
            onLoadMore: nil
        )
        .searchable(text: $searchText, prompt: "Search videos")
        .onSubmit(of: .search) {
            Task {
                await videoService.searchVideos(query: searchText)
            }
        }
        .alert("Error", isPresented: .constant(videoService.error != nil)) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(videoService.error ?? "Unknown error")
        }
    }
}

#Preview {
    SearchVideosView()
}
