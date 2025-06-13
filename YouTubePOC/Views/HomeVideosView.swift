import SwiftUI
import YouTubeKit

struct HomeVideosView: View {
    @StateObject private var authService = YouTubeAuthService.shared
    @State private var videos: [YTVideo] = []
    @State private var error: String?
    @State private var isFetching = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isFetching {
                    ProgressView()
                        .controlSize(.large)
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            Task {
                                await fetchVideos()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if videos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "play.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No videos available")
                            .foregroundColor(.gray)
                    }
                } else {
                    List(videos, id: \.id) { video in
                        VideoRowView(video: video)
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccountLinkView()
                }
            }
        }
        .task {
            await fetchVideos()
        }
    }
    
    func fetchVideos() async {
        print("HomeVideosView: Starting to fetch videos")
        print("Current YTM state:")
        print("- Cookies: \(YTM.cookies)")
        print("- Always use cookies: \(YTM.alwaysUseCookies)")
        
        await MainActor.run {
            isFetching = true
            error = nil
            videos.removeAll()
        }
        
        print("HomeVideosView: Fetching home feed with cookies...")
        let result = await withCheckedContinuation { continuation in
            HomeScreenResponse.sendNonThrowingRequest(youtubeModel: YTM.model, data: [:]) { responseResult in
                continuation.resume(returning: responseResult)
            }
        }
        switch result {
        case .success(let homeResponse):
            print("HomeVideosView: Got response")
            print("- Raw results count: \(homeResponse.results.count)")
            print("- Has continuation: \(homeResponse.continuationToken != nil)")
            print("- Visitor data: \(homeResponse.visitorData ?? "nil")")
            await MainActor.run {
                videos = homeResponse.results
                if homeResponse.results.isEmpty {
                    error = "No videos available. Please try again later."
                }
                isFetching = false
            }
        case .failure(let error):
            print("HomeVideosView: Error fetching videos: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isFetching = false
            }
        }
    }
}

struct VideoRowView: View {
    let video: YTVideo
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(video.title ?? "Untitled")
                .font(.headline)
            if let channel = video.channel?.name {
                Text(channel)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            if let viewCount = video.viewCount {
                Text(viewCount)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    HomeVideosView()
        .environmentObject(YTM.shared)
}
