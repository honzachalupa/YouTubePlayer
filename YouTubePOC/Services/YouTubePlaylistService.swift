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
    
    // YouTube requires a video ID when creating a playlist, even if we don't want to add any videos.
    // This is a limitation of their API. We use a known working video ID from YouTubeKit's test cases.
    private let defaultVideoId = "peIBCNTY8hA"
    
    init() {
        Task { await fetchPlaylists() }
    }
    
    func clearData() {
        playlists = []
        error = nil
    }
    
    func fetchPlaylists() async {
        isLoading = true
        error = nil
        
        do {
            print("YouTubePlaylistService: Fetching playlists...")
            
            // Get playlists directly
            let response = try await AccountPlaylistsResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [.browseId: "FEplaylists_aggregation"],
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
        var createdPlaylistId: String? = nil
        
        do {
            print("YouTubePlaylistService: Creating playlist '\(name)'...")
            
            // Validate inputs
            guard !name.isEmpty else {
                error = "Playlist name cannot be empty"
                isLoading = false
                return false
            }
            
            // Create playlist with required parameters including the required video ID
            let requestData: [HeadersList.AddQueryInfo.ContentTypes: String] = [
                .query: name,
                .params: privacy.rawValue,
                .movingVideoId: defaultVideoId
            ]
            print("YouTubePlaylistService: Creating playlist with data:", requestData)
            print("YouTubePlaylistService: Privacy raw value:", privacy.rawValue)
            print("YouTubePlaylistService: Is authenticated:", youtubeService.model.cookies != "")
            
            let response = try await CreatePlaylistResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: requestData,
                useCookies: true
            )
            
            print("YouTubePlaylistService: Response - isDisconnected:", response.isDisconnected)
            print("YouTubePlaylistService: Response - createdPlaylistId:", response.createdPlaylistId ?? "nil")
            print("YouTubePlaylistService: Response - playlistCreatorId:", response.playlistCreatorId ?? "nil")
            
            if response.isDisconnected {
                print("YouTubePlaylistService: Not authenticated")
                error = "Not authenticated. Please sign in."
                isLoading = false
                return false
            }
            
            createdPlaylistId = response.createdPlaylistId
            
            if createdPlaylistId == nil {
                print("YouTubePlaylistService: Failed to get playlist ID from response")
                error = "Failed to get playlist ID from response"
                isLoading = false
                return false
            }
            
            print("YouTubePlaylistService: Created playlist with ID '\(createdPlaylistId!)'")
        } catch let error as BadRequestDataError {
            print("YouTubePlaylistService: Bad request data:", error.parametersValidatorErrors)
            self.error = error.parametersValidatorErrors.map { "\($0.dataType.rawValue): \($0.reason)" }.joined(separator: ", ")
            isLoading = false
            return false
        } catch {
            print("YouTubePlaylistService: Error creating playlist:", error)
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
        
        // Now that we have created the playlist, try to remove the default video
        do {
            print("YouTubePlaylistService: Removing default video from playlist...")
            
            // Need to wait a bit for the playlist to be fully created
            try await Task.sleep(for: .seconds(1))
            
            // Remove VL prefix if present, just like in deletePlaylist
            let playlistIdForRemoval = createdPlaylistId!.hasPrefix("VL") ? String(createdPlaylistId!.dropFirst(2)) : createdPlaylistId!
            
            print("YouTubePlaylistService: Using playlist ID '\(playlistIdForRemoval)' for video removal")
            
            let removeResponse = try await RemoveVideoByIdFromPlaylistResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [
                    .browseId: playlistIdForRemoval,
                    .movingVideoId: defaultVideoId
                ],
                useCookies: true
            )
            
            if !removeResponse.success {
                print("YouTubePlaylistService: Failed to remove default video")
            } else {
                print("YouTubePlaylistService: Successfully removed default video")
            }
        } catch {
            print("YouTubePlaylistService: Error removing default video: \(error)")
            // Don't set the error since the playlist was created successfully
        }
        
        // Fetch playlists to update the list
        await fetchPlaylists()
        isLoading = false
        return true
    }
    
    func deletePlaylist(_ playlist: YTPlaylist) async -> Bool {
        isLoading = true
        error = nil
        
        do {
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
