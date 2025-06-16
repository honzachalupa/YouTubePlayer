import Foundation
import YouTubeKit
import SwiftUI

@MainActor
class YouTubePlaylistService: ObservableObject {
    static let shared = YouTubePlaylistService()
    
    @Published var playlists: [YTPlaylist] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // Default video ID to use when creating playlists - using a popular video that's unlikely to be taken down
    private let defaultVideoId = "dQw4w9WgXcQ"  // Never Gonna Give You Up
    
    func fetchPlaylists() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await AccountPlaylistsResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [:]
            )
            
            if response.isDisconnected {
                error = "Not authenticated. Please sign in."
            } else {
                playlists = response.results
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createPlaylist(name: String, privacy: YTPrivacy = .private) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            let response = try await CreatePlaylistResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [
                    .query: name,
                    .params: privacy.rawValue,
                    .movingVideoId: defaultVideoId
                ]
            )
            
            if response.isDisconnected {
                error = "Not authenticated. Please sign in."
                return false
            }
            
            if response.createdPlaylistId != nil {
                // Remove the default video we added
                if let playlistId = response.createdPlaylistId {
                    _ = try? await RemoveVideoByIdFromPlaylistResponse.sendThrowingRequest(
                        youtubeModel: YTM.model,
                        data: [
                            .movingVideoId: defaultVideoId,
                            .browseId: playlistId
                        ],
                        useCookies: true
                    )
                }
                
                await fetchPlaylists()
                return true
            } else {
                error = "Failed to create playlist"
                return false
            }
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
    
    func deletePlaylist(_ playlist: YTPlaylist) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            let response = try await DeletePlaylistResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [
                    .browseId: playlist.playlistId.hasPrefix("VL") ? String(playlist.playlistId.dropFirst(2)) : playlist.playlistId
                ]
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