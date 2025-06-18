import Foundation
import SwiftUI
import AVKit

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentVideo: YouTubeVideo?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    @Published var showVideoInfo = true
    @Published var showControls = true
    @Published var isFullScreen = false
    
    private let videoService: YouTubeVideoService
    
    init() {
        self.videoService = YouTubeVideoService.shared
    }
    
    var player: AVPlayer? {
        videoService.player
    }
    
    var videoTitle: String {
        currentVideo?.snippet.title ?? ""
    }
    
    var channelTitle: String {
        currentVideo?.snippet.channelTitle ?? ""
    }
    
    var viewCount: String {
        guard let count = currentVideo?.statistics?.viewCount else { return "0" }
        return formatCount(count)
    }
    
    var likeCount: String {
        guard let count = currentVideo?.statistics?.likeCount else { return "0" }
        return formatCount(count)
    }
    
    var thumbnailURL: String {
        currentVideo?.bestThumbnail ?? ""
    }
    
    private func formatCount(_ count: String) -> String {
        guard let number = Double(count) else { return "0" }
        
        switch number {
        case 0..<1000:
            return String(format: "%.0f", number)
        case 1000..<1_000_000:
            return String(format: "%.1fK", number / 1000)
        case 1_000_000..<1_000_000_000:
            return String(format: "%.1fM", number / 1_000_000)
        default:
            return String(format: "%.1fB", number / 1_000_000_000)
        }
    }
    
    func loadVideo(_ video: YouTubeVideo) async {
        currentVideo = video
        isLoading = true
        error = nil
        
        await videoService.loadVideo(video)
        
        isLoading = videoService.isLoading
        error = videoService.error
        showError = error != nil
        isPlaying = videoService.isPlaying
    }
    
    func togglePlayPause() {
        videoService.togglePlayPause()
        isPlaying = videoService.isPlaying
    }
    
    func toggleFullScreen() {
        isFullScreen.toggle()
    }
    
    func toggleControls() {
        showControls.toggle()
    }
    
    func cleanup() {
        videoService.cleanup()
        currentVideo = nil
        isPlaying = false
        isLoading = false
        error = nil
        showError = false
    }
}
