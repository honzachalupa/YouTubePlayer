import Foundation
import YouTubeKit
import SwiftUI
import Combine

@MainActor
class YouTubePlaylistService: ObservableObject {
    static let shared = YouTubePlaylistService()
    
    @Published var playlists: [YTPlaylist] = []
    @Published private(set) var editablePlaylists: [YTPlaylist] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let youtubeService = YouTubeService.shared
    private var fetchPlaylistsTask: (id: UUID, task: Task<(playlists: [YTPlaylist], error: String?), Never>)?
    private var fetchPlaylistsRequestID: UUID?
    
    // YouTube requires a video ID when creating a playlist, even if we don't want to add any videos.
    // This is a limitation of their API. We use a known working video ID from YouTubeKit's test cases.
    private let defaultVideoId = "peIBCNTY8hA"
    
    init() {
        Task { await fetchPlaylists() }
    }
    
    func clearData() {
        fetchPlaylistsTask?.task.cancel()
        fetchPlaylistsTask = nil
        fetchPlaylistsRequestID = nil
        playlists = []
        editablePlaylists = []
        isLoading = false
        error = nil
    }

    func cacheEditablePlaylists(_ playlists: [YTPlaylist]) {
        editablePlaylists = VideoPlaylistStateMapper.currentEditablePlaylists(from: playlists)
    }
    
    func fetchPlaylists(forceRefresh: Bool = false) async {
        if !forceRefresh, let fetchPlaylistsTask {
            let result = await fetchPlaylistsTask.task.value
            guard fetchPlaylistsRequestID == fetchPlaylistsTask.id else { return }
            playlists = result.playlists
            error = result.error
            return
        }

        if forceRefresh {
            fetchPlaylistsTask?.task.cancel()
        }

        isLoading = true
        error = nil
        let requestID = UUID()
        fetchPlaylistsRequestID = requestID

        let task = Task<(playlists: [YTPlaylist], error: String?), Never> { [youtubeService] in
            do {
                let response = try await AccountPlaylistsResponse.sendThrowingRequest(
                    youtubeModel: youtubeService.model,
                    data: [.browseId: "FEplaylist_aggregation"],
                    useCookies: true
                )

                guard !response.isDisconnected else {
                    return (playlists: [], error: "Not authenticated. Please sign in.")
                }

                let playlists = response.results.map { playlist in
                    var updatedPlaylist = playlist
                    updatedPlaylist.playlistId = VideoPlaylistStateMapper.playlistIDWithVLPrefix(updatedPlaylist.playlistId)
                    return updatedPlaylist
                }
                return (playlists: playlists, error: nil as String?)
            } catch {
                return (playlists: [], error: error.localizedDescription)
            }
        }
        fetchPlaylistsTask = (id: requestID, task: task)

        let result = await task.value
        guard fetchPlaylistsRequestID == requestID else { return }

        playlists = result.playlists
        error = result.error
        fetchPlaylistsTask = nil
        fetchPlaylistsRequestID = nil
        isLoading = false
    }

    func createPlaylist(name: String, privacy: YTPrivacy = .private) async -> Bool {
        isLoading = true
        error = nil
        var createdPlaylistId: String? = nil
        
        do {
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
            
            let response = try await CreatePlaylistResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: requestData,
                useCookies: true
            )
            
            if response.isDisconnected {
                error = "Not authenticated. Please sign in."
                isLoading = false
                return false
            }
            
            guard let createdId = response.createdPlaylistId else {
                error = "Failed to get playlist ID from response"
                isLoading = false
                return false
            }
            createdPlaylistId = createdId
        } catch let error as BadRequestDataError {
            self.error = error.parametersValidatorErrors.map { "\($0.dataType.rawValue): \($0.reason)" }.joined(separator: ", ")
            isLoading = false
            return false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
        
        // Now that we have created the playlist, try to remove the default video
        do {
            // Need to wait a bit for the playlist to be fully created
            try await Task.sleep(for: .seconds(1))
            
            guard let createdPlaylistId else { return true }

            let playlistIdForRemoval = VideoPlaylistStateMapper.playlistIDWithoutVLPrefix(createdPlaylistId)
            
            let removeResponse = try await RemoveVideoByIdFromPlaylistResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [
                    .browseId: playlistIdForRemoval,
                    .movingVideoId: defaultVideoId
                ],
                useCookies: true
            )
            _ = removeResponse.success
        } catch {
            // Don't set the error since the playlist was created successfully
        }
        
        // Fetch playlists to update the list
        await fetchPlaylists(forceRefresh: true)
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
                    .browseId: VideoPlaylistStateMapper.playlistIDWithoutVLPrefix(playlist.playlistId)
                ],
                useCookies: true
            )
            
            if response.isDisconnected {
                error = "Not authenticated. Please sign in."
                return false
            }
            
            if response.success {
                await fetchPlaylists(forceRefresh: true)
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
