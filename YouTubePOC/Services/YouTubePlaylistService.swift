import Foundation
import YouTubeKit
import SwiftUI

@MainActor
class YouTubePlaylistService: ObservableObject {
    static let shared = YouTubePlaylistService()
    
    @Published var playlists: [YTPlaylist] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let youtubeService = YouTubeService.shared
    
    // Default video ID to use when creating playlists - using a test video that we know works
    private let defaultVideoId = "peIBCNTY8hA"  // Test video from YouTubeKit test case
    
    init() {
        Task { await fetchPlaylists() }
    }
    
    func clearData() {
        playlists = []
        error = nil
    }
    
    private func initializeYouTube() async -> Bool {
        print("YouTubePlaylistService: Initializing YouTube...")
        
        // Ensure we're using cookies
        youtubeService.alwaysUseCookies = true
        
        // Wait for visitor data
        await youtubeService.getVisitorData()
        
        // Double check we have visitor data
        if youtubeService.model.visitorData.isEmpty {
            print("YouTubePlaylistService: Failed to get visitor data")
            return false
        }
        
        print("YouTubePlaylistService: Successfully initialized with visitor data")
        return true
    }
    
    func fetchPlaylists() async {
        isLoading = true
        error = nil
        
        do {
            // First ensure YouTube is initialized
            guard await initializeYouTube() else {
                error = "Failed to initialize YouTube"
                isLoading = false
                return
            }
            
            print("YouTubePlaylistService: Fetching playlists...")
            
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
            
            // Now fetch playlists using the same context
            let response = try await AccountPlaylistsResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [.visitorData: youtubeService.model.visitorData],
                useCookies: true
            )
            
            if response.isDisconnected {
                error = "Not authenticated. Please sign in."
            } else {
                // Ensure all playlist IDs have VL prefix
                playlists = response.results.map { playlist in
                    var updatedPlaylist = playlist
                    if !updatedPlaylist.playlistId.hasPrefix("VL") {
                        updatedPlaylist.playlistId = "VL" + updatedPlaylist.playlistId
                    }
                    return updatedPlaylist
                }
                print("YouTubePlaylistService: Found \(playlists.count) playlists")
            }
        } catch {
            print("YouTubePlaylistService: Error fetching playlists: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createPlaylist(name: String, privacy: YTPrivacy = .private) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            // First ensure YouTube is initialized
            guard await initializeYouTube() else {
                error = "Failed to initialize YouTube"
                isLoading = false
                return false
            }
            
            print("YouTubePlaylistService: Creating playlist '\(name)'...")
            
            // Validate inputs
            guard !name.isEmpty else {
                error = "Playlist name cannot be empty"
                isLoading = false
                return false
            }
            
            // Create playlist with required parameters
            let response = try await CreatePlaylistResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [
                    .query: name,
                    .params: privacy.rawValue
                ],
                useCookies: true
            )
            
            if response.isDisconnected {
                print("YouTubePlaylistService: Not authenticated")
                error = "Not authenticated. Please sign in."
                isLoading = false
                return false
            }
            
            if let playlistId = response.createdPlaylistId {
                print("YouTubePlaylistService: Created playlist with ID '\(playlistId)'")
                await fetchPlaylists()
                isLoading = false
                return true
            } else {
                print("YouTubePlaylistService: Failed to get playlist ID from response")
                error = "Failed to get playlist ID from response"
                isLoading = false
                return false
            }
        } catch {
            print("YouTubePlaylistService: Error creating playlist: \(error)")
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func deletePlaylist(_ playlist: YTPlaylist) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            // First ensure YouTube is initialized
            guard await initializeYouTube() else {
                error = "Failed to initialize YouTube"
                isLoading = false
                return false
            }
            
            let response = try await DeletePlaylistResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [
                    .browseId: playlist.playlistId.hasPrefix("VL") ? String(playlist.playlistId.dropFirst(2)) : playlist.playlistId
                ],
                useCookies: true
            )
            
            if response.isDisconnected {
                error = "Not authenticated. Please sign in."
                return false
            }
            
            if response.success {
                await fetchPlaylists()
                return true
            } else {
                error = "Failed to delete playlist"
                return false
            }
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
} 
