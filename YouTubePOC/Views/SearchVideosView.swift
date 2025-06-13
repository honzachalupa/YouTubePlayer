import SwiftUI
import YouTubeKit

struct SearchVideosView: View {
    @EnvironmentObject private var youtubeWrapper: YouTubeModelWrapper
    @State private var query: String = "WWDC 2025 SwiftUI"
    @State private var videos: [YTVideo] = []
    @State private var error: String?
    @State private var isLoading = false
    
    func fetchVideosSearch() async {
        guard !query.isEmpty else {
            error = "Please enter a search term"
            return
        }
        
        videos.removeAll()
        error = nil
        isLoading = true
        
        print("SearchVideosView: Starting to search for '\(query)'")
        print("Current YTM state:")
        print("- Cookies: \(YTM.cookies)")
        print("- Always use cookies: \(YTM.alwaysUseCookies)")
        print("- Visitor data present: \(!YTM.model.visitorData.isEmpty)")
        
        do {
            let response = try await SearchResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [
                .query: query,
                .params: "EgIQAQ%3D%3D"  // Filter for videos only
            ])
            print("SearchVideosView: Got response")
            print("- Raw results count: \(response.results.count)")
            
            var newVideos: [YTVideo] = []
            var seenIds = Set<String>()
            
            for result in response.results {
                print("Processing result: \(type(of: result))")
                if let video = result as? YTVideo {
                    if !seenIds.contains(video.videoId) {
                        seenIds.insert(video.videoId)
                        newVideos.append(video)
                        print("Added video: \(video.title ?? "untitled") (\(video.videoId))")
                    }
                } else {
                    print("Result is not a video: \(type(of: result))")
                }
            }
            
            // If no results, try without the video filter
            if newVideos.isEmpty {
                print("SearchVideosView: No results with video filter, trying without filter...")
                let unfilteredResponse = try await SearchResponse.sendThrowingRequest(youtubeModel: YTM.model, data: [
                    .query: query
                ])
                
                for result in unfilteredResponse.results {
                    print("Processing unfiltered result: \(type(of: result))")
                    if let video = result as? YTVideo {
                        if !seenIds.contains(video.videoId) {
                            seenIds.insert(video.videoId)
                            newVideos.append(video)
                            print("Added unfiltered video: \(video.title ?? "untitled") (\(video.videoId))")
                        }
                    }
                }
            }
            
            await MainActor.run {
                videos = newVideos
                if newVideos.isEmpty {
                    error = "No videos found for '\(query)'"
                }
                isLoading = false
            }
        } catch {
            print("SearchVideosView: Error searching videos: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    HStack {
                        TextField("Search YouTube", text: $query)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                Task {
                                    await fetchVideosSearch()
                                }
                            }
                        
                        if !query.isEmpty {
                            Button {
                                Task {
                                    await fetchVideosSearch()
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .disabled(isLoading)
                        }
                    }
                }
                .frame(height: 65)
                
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
                            
                            if !query.isEmpty {
                                Button("Try Again") {
                                    Task {
                                        await fetchVideosSearch()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                    } else if isLoading {
                        ProgressView()
                            .controlSize(.large)
                            .padding()
                    } else {
                        Text("Enter a search term to begin")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
            .navigationTitle("Search")
        }
        .task {
            if !query.isEmpty {
                await fetchVideosSearch()
            }
        }
    }
}

#Preview {
    SearchVideosView()
        .environmentObject(YTM.shared)
}
