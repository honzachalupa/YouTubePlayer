import SwiftUI
import YouTubeKit

struct TrendingVideosView: View {
    @EnvironmentObject private var youtubeWrapper: YouTubeModelWrapper
    @State private var videos: [YTVideo] = []
    @State private var error: String?
    
    func fetchVideos() async {
        videos.removeAll()
        error = nil
        
        print("TrendingVideosView: Starting to fetch videos")
        print("Current YTM state:")
        print("- Cookies: \(YTM.cookies)")
        print("- Always use cookies: \(YTM.alwaysUseCookies)")
        print("- Visitor data present: \(!YTM.model.visitorData.isEmpty)")
        
        do {
            let response = try await TrendingVideosResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [:])
            print("TrendingVideosView: Got response")
            
            var newVideos: [YTVideo] = []
            var seenIds = Set<String>()
            
            // Print available categories
            print("Available categories: \(response.categoriesContentsStore.keys.joined(separator: ", "))")
            
            // Try to get videos from the current category
            if let currentIdentifier = response.currentContentIdentifier {
                print("Current category: \(currentIdentifier)")
                if let categoryVideos = response.categoriesContentsStore[currentIdentifier] {
                    print("Found \(categoryVideos.count) videos in current category")
                    for video in categoryVideos {
                        if !seenIds.contains(video.videoId) {
                            seenIds.insert(video.videoId)
                            newVideos.append(video)
                            print("Added video: \(video.title ?? "untitled") (\(video.videoId))")
                        }
                    }
                } else {
                    print("No videos found in current category")
                }
            } else {
                print("No current category identifier")
                
                // Fallback: try to get videos from any available category
                for (category, videos) in response.categoriesContentsStore {
                    print("Trying category: \(category)")
                    for video in videos {
                        if !seenIds.contains(video.videoId) {
                            seenIds.insert(video.videoId)
                            newVideos.append(video)
                            print("Added video: \(video.title ?? "untitled") (\(video.videoId))")
                        }
                    }
                    if !newVideos.isEmpty {
                        print("Found videos in category \(category), stopping search")
                        break
                    }
                }
            }
            
            await MainActor.run {
                videos = newVideos
                if newVideos.isEmpty {
                    error = "No trending videos found"
                }
            }
        } catch {
            print("TrendingVideosView: Error fetching videos: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if !videos.isEmpty {
                    VideosListView(videos: videos)
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
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .navigationTitle("Trending")
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
}

#Preview {
    TrendingVideosView()
        .environmentObject(YTM.shared)
}
