import SwiftUI
import YouTubeKit

struct SearchVideosView: View {
    @StateObject private var viewModel = VideoListViewModel(videoFetcher: {
        let response = try await AccountSubscriptionsFeedResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [:])
        return response.results
    })
    @State private var query: String = ""
    @State private var videos: [YTVideo] = []
    
    func performSearch() async {
        guard !query.isEmpty else {
            // Clear videos if query is empty
            videos = []
            return
        }
        
        do {
            let response = try await SearchResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [.query: query]
            )
            // Extract only YTVideo objects from the results
            self.videos = response.results.compactMap { $0 as? YTVideo }
        } catch {
            print("Error searching videos: \(error)")
            // Handle error, maybe show an alert to the user
            self.videos = []
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search YouTube...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit(of: .text) {
                            Task { await performSearch() }
                        }
                    
                    Button(action: {
                        Task { await performSearch() }
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .padding()
                
                if !videos.isEmpty {
                    VideosListView(viewModel: viewModel, navigationTitle: "Search")
                } else {
                    Spacer()
                    Text("Enter a search term to begin.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchVideosView()
}
