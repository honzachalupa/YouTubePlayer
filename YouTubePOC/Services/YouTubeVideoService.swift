import Foundation
import SwiftUI
import AVKit

private final class PlayerResourceManager {
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    func setPlayer(_ newPlayer: AVPlayer?) {
        cleanup()
        player = newPlayer
    }
    
    func addTimeObserver(for player: AVPlayer, queue: DispatchQueue = .main, block: @escaping (CMTime) -> Void) {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: queue,
            using: block
        )
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
    }
    
    deinit {
        cleanup()
    }
}

@MainActor
class YouTubeVideoService: ObservableObject {
    static let shared: YouTubeVideoService = {
        guard let apiKey = Bundle.main.infoDictionary?["YouTubeAPIKey"] as? String else {
            fatalError("YouTube API Key not found in Info.plist. Add 'YouTubeAPIKey' to your Info.plist file.")
        }
        return YouTubeVideoService(apiKey: apiKey, authService: YouTubeAuthService.shared)
    }()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var videos: [YouTubeVideo] = []
    @Published var nextPageToken: String?
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isPlaying = false
    @Published var likeStatus: String = "none" // "none", "like", "dislike"
    
    private let apiKey: String
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let authService: YouTubeAuthService
    private let playerManager = PlayerResourceManager()
    
    init(apiKey: String, authService: YouTubeAuthService) {
        self.apiKey = apiKey
        self.authService = authService
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session:", error)
        }
    }
    
    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var components = URLComponents(string: "\(baseURL)/\(path)")!
        
        // Add API key to all requests
        var queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        // If there are existing query items, append them
        if let existingItems = components.queryItems {
            queryItems.append(contentsOf: existingItems)
        }
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        
        // Add auth token if available
        if let token = authService.accessToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    // MARK: - Video Search and Listing
    
    func searchVideos(query: String, pageToken: String? = nil) async {
        isLoading = true
        error = nil
        
        do {
            var path = "search?part=snippet&type=video&maxResults=5&q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let pageToken = pageToken {
                path += "&pageToken=\(pageToken)"
            }
            
            let request = makeRequest(path: path)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                let searchResponse = try JSONDecoder().decode(YouTubeListResponse<YouTubeSearchResult>.self, from: data)
                
                // Get full video details
                let videoIds = searchResponse.items.compactMap { $0.id.videoId }.joined(separator: ",")
                await fetchVideoDetails(videoIds: videoIds, append: false)
                
                nextPageToken = searchResponse.nextPageToken
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
                print("YouTubeVideoService: Error searching videos: \(error ?? "Unknown error")")
            }
        } catch {
            self.error = error.localizedDescription
            print("YouTubeVideoService: Error searching videos: \(error)")
        }
        
        isLoading = false
    }
    
    func fetchTrendingVideos() async {
        isLoading = true
        error = nil
        
        do {
            let request = makeRequest(
                path: "videos?part=snippet,contentDetails,statistics&chart=mostPopular&maxResults=5&regionCode=US"
            )
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                let videoResponse = try JSONDecoder().decode(YouTubeListResponse<YouTubeVideo>.self, from: data)
                videos = videoResponse.items
                nextPageToken = videoResponse.nextPageToken
                print("YouTubeVideoService: Fetched \(videos.count) trending videos")
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
                print("YouTubeVideoService: Error fetching trending videos: \(error ?? "Unknown error")")
            }
        } catch {
            self.error = error.localizedDescription
            print("YouTubeVideoService: Error fetching trending videos: \(error)")
        }
        
        isLoading = false
    }
    
    func fetchSubscriptionVideos() async {
        isLoading = true
        error = nil
        
        guard authService.accessToken != nil else {
            error = "Not authenticated. Please sign in."
            isLoading = false
            return
        }
        
        do {
            let request = makeRequest(
                path: "subscriptions?part=snippet&mine=true&maxResults=5"
            )
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                let subscriptionResponse = try JSONDecoder().decode(YouTubeListResponse<YouTubeSubscription>.self, from: data)
                // Use the channel ID from the resourceId in the subscription snippet
                let channelIds = subscriptionResponse.items.map { $0.snippet.resourceId.channelId }
                
                // Get latest videos from subscribed channels
                await fetchChannelsVideos(channelIds: channelIds)
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
                print("YouTubeVideoService: Error fetching subscriptions: \(error ?? "Unknown error")")
            }
        } catch {
            self.error = error.localizedDescription
            print("YouTubeVideoService: Error fetching subscriptions: \(error)")
        }
        
        isLoading = false
    }
    
    private func fetchChannelsVideos(channelIds: [String]) async {
        var allVideos: [YouTubeVideo] = []
        var errors: [String] = []
        
        // Take only first 3 channels to reduce API calls
        let limitedChannelIds = Array(channelIds.prefix(3))
        
        // Get latest videos from each channel individually
        for channelId in limitedChannelIds {
            do {
                let path = "search?part=snippet&type=video&maxResults=2&order=date&channelId=\(channelId)"
                let request = makeRequest(path: path)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    errors.append("Invalid response for channel \(channelId)")
                    continue
                }
                
                if httpResponse.statusCode == 200 {
                    let searchResponse = try JSONDecoder().decode(YouTubeListResponse<YouTubeSearchResult>.self, from: data)
                    
                    // Get full video details
                    let videoIds = searchResponse.items.compactMap { $0.id.videoId }.joined(separator: ",")
                    if !videoIds.isEmpty {
                        let videoRequest = makeRequest(path: "videos?part=snippet,contentDetails,statistics&id=\(videoIds)")
                        let (videoData, videoResponse) = try await URLSession.shared.data(for: videoRequest)
                        
                        if let videoHttpResponse = videoResponse as? HTTPURLResponse,
                           videoHttpResponse.statusCode == 200 {
                            let videoListResponse = try JSONDecoder().decode(YouTubeListResponse<YouTubeVideo>.self, from: videoData)
                            allVideos.append(contentsOf: videoListResponse.items)
                        } else {
                            let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: videoData)
                            errors.append("Error fetching video details: \(errorResponse.error.message)")
                        }
                    }
                } else {
                    let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                    errors.append("Error fetching channel \(channelId): \(errorResponse.error.message)")
                }
            } catch {
                errors.append("Error processing channel \(channelId): \(error.localizedDescription)")
            }
        }
        
        // Sort all videos by date (newest first)
        videos = allVideos.sorted { video1, video2 in
            video1.snippet.publishedAt > video2.snippet.publishedAt
        }
        
        if !errors.isEmpty {
            self.error = errors.joined(separator: "\n")
        }
    }
    
    private func fetchVideoDetails(videoIds: String, append: Bool = true) async {
        do {
            let request = makeRequest(
                path: "videos?part=snippet,contentDetails,statistics&id=\(videoIds)"
            )
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                return
            }
            
            if httpResponse.statusCode == 200 {
                let videoResponse = try JSONDecoder().decode(YouTubeListResponse<YouTubeVideo>.self, from: data)
                if append {
                    videos.append(contentsOf: videoResponse.items)
                } else {
                    videos = videoResponse.items
                }
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Video Playback
    
    private func setPlayer(_ newPlayer: AVPlayer?) {
        playerManager.setPlayer(newPlayer)
        player = newPlayer
    }

    private func setIsPlaying(_ value: Bool) {
        isPlaying = value
    }

    func loadVideo(_ video: YouTubeVideo) async {
        isLoading = true
        error = nil
        
        do {
            // Get video streaming URL
            let request = makeRequest(path: "videos?part=player&id=\(video.id)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                _ = try JSONDecoder().decode(YouTubeListResponse<YouTubeVideo>.self, from: data)
                
                // TODO: Extract streaming URL from player data
                // For now, this is a placeholder as we'll need to implement proper video URL extraction
                guard let streamingURL = URL(string: "https://example.com/video.mp4") else {
                    error = "Failed to get video streaming URL"
                    isLoading = false
                    return
                }
                
                let newPlayer = AVPlayer(url: streamingURL)
                setupPlayerObservation(for: newPlayer)
                setPlayer(newPlayer)
                newPlayer.play()
                setIsPlaying(true)
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func setupPlayerObservation(for player: AVPlayer) {
        playerManager.addTimeObserver(for: player) { _ in
            // Update playback progress if needed
        }
        
        // Observe player item status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTime),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    @objc private func playerItemDidPlayToEndTime() {
        isPlaying = false
    }
    
    func togglePlayPause() {
        guard let currentPlayer = player else { return }
        
        if isPlaying {
            currentPlayer.pause()
            setIsPlaying(false)
        } else {
            currentPlayer.play()
            setIsPlaying(true)
        }
    }
    
    func getStreamURL(for videoId: String) async throws -> URL {
        // For now, return a direct YouTube watch URL
        // In a production app, you would use a proper video streaming solution
        return URL(string: "https://www.youtube.com/watch?v=\(videoId)")!
    }
    
    func cleanup() {
        playerManager.cleanup()
        player = nil
        isPlaying = false
    }
    
    deinit {
        playerManager.cleanup()
    }
} 