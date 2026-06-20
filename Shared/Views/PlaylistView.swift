import SwiftUI
import YouTubeKit

func getPlaylistIcon(_ playlistTitle: String?) -> String {
    switch playlistTitle {
        case "Liked videos": "heart.fill"
        case "Watch later": "star.fill"
        default: "play.fill"
    }
}

struct PlaylistView: View {
    public var playlist: YTPlaylist
    
    private let youtubeService = YouTubeService.shared
    @StateObject private var messageService = MessageService.shared
    @StateObject private var playlistService = YouTubePlaylistService.shared
    @State private var videos: [YTVideo] = []
    @State private var fetchError: Error? = nil
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingPlaylist = false
    @State private var isToolbarReady = false
    
    var filteredVideos: [YTVideo] {
        if searchText.isEmpty {
            return videos
        }
        
        return videos.filter { video in
            guard let title = video.title else { return false }
            return title.lowercased().contains(searchText.lowercased())
        }
    }

    private func playbackQueueContext(for _: YTVideo) -> VideoManager.PlaybackQueueContext {
        VideoManager.PlaybackQueueContext(
            source: .playlist(title: playlist.title ?? "Playlist"),
            videos: filteredVideos
        )
    }
    
    func fetchVideos() async {
        guard !isLoading else { return }  // Prevent multiple simultaneous fetches
        
        isLoading = true
        
        do {
            // First get the home screen response to ensure we have proper context
            let homeResponse = try await HomeScreenResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [:],
                useCookies: true
            )
            
            // Update visitor data if available
            if let visitorData = homeResponse.visitorData {
                youtubeService.model.visitorData = visitorData
            }
            
            // Get the current locale
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            let localeComponents = locale.components(separatedBy: "_")
            let languageCode = localeComponents[0]
            let countryCode = localeComponents.count > 1 ? localeComponents[1] : "US"
            
            // Set up the context data
            let contextData: [String: Any] = [
                "context": [
                    "client": [
                        "hl": languageCode,
                        "gl": countryCode,
                        "clientName": "WEB",
                        "clientVersion": "2.20240101",
                        "platform": "DESKTOP"
                    ]
                ],
                "browseId": VideoPlaylistStateMapper.playlistIDWithVLPrefix(playlist.playlistId)
            ]
            
            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: contextData)
            
            // Set up headers
            let headers = [
                HeadersList.Header(name: "Content-Type", content: "application/json"),
                HeadersList.Header(name: "Accept", content: "*/*"),
                HeadersList.Header(name: "Origin", content: "https://www.youtube.com"),
                HeadersList.Header(name: "Referer", content: "https://www.youtube.com/"),
                HeadersList.Header(name: "Accept-Language", content: "\(languageCode)_\(countryCode)")
            ]
            
            // Set up the request in YouTubeKit
            youtubeService.model.customHeaders[.playlistHeaders] = HeadersList(
                url: URL(string: "https://www.youtube.com/youtubei/v1/browse")!,
                method: .POST,
                headers: headers,
                addQueryAfterParts: [],
                httpBody: [String(data: jsonData, encoding: .utf8)!],
                parameters: []
            )
            
            // Now fetch the playlist videos
            let response = try await playlist.fetchVideosThrowing(
                youtubeModel: youtubeService.model,
                useCookies: true
            )
            
            await MainActor.run {
                withAnimation {
                    videos = response.results
                    fetchError = nil
                }
            }
        } catch {
            print("PlaylistView: Error fetching videos: \(error)")
            
            await MainActor.run {
                messageService.show(message: error.localizedDescription, type: .error)
                
                withAnimation {
                    videos = []
                }
            }
        }
        
        await MainActor.run {
            withAnimation {
                isLoading = false
            }
        }
    }
    
    var body: some View {
        VideosGridView(
            videos: filteredVideos,
            error: fetchError,
            fetchVideos: {
            await fetchVideos()
        },
            playbackQueueContextProvider: playbackQueueContext(for:)
        )
        .toolbar {
            if isToolbarReady {
                ToolbarItem(id: "toolbar.playlist.delete", placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        if isDeletingPlaylist {
                            ProgressView()
                        } else {
                            Label("Delete playlist", systemImage: "trash.fill")
                        }
                    }
                    .tint(.red)
                    .disabled(isDeletingPlaylist)
                    .confirmationDialog(
                        "Are you sure you want to delete this playlist?",
                        isPresented: $showingDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            isDeletingPlaylist = true
                            Task {
                                let success = await playlistService.deletePlaylist(playlist)
                                isDeletingPlaylist = false
                                if !success {
                                    messageService.show(message: playlistService.error ?? "Failed to delete playlist.", type: .error)
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search videos in playlist")
        .navigationTitle(playlist.title != nil ? "\(playlist.title ?? "") playlist" : "Playlist")
        .task {
            await Task.yield()
            isToolbarReady = true
        }
        .onDisappear {
            isToolbarReady = false
        }
    }
}

#Preview {
    let playlist = YTPlaylist(
        id: 123,
        playlistId: "123",
        title: "Title",
        thumbnails: [],
        videoCount: "videoCount",
        channel: nil,
        timePosted: "timePosted",
        frontVideos: []
    )
    
    PlaylistView(playlist: playlist)
}
