import Foundation
import SwiftUI

// 1078839058958-f8aaiu3kbdkcjspf6ji93ve86he0ejvn.apps.googleusercontent.com

enum YouTubePlaylistError: LocalizedError {
    case invalidResponse
    case notAuthenticated
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from YouTube API"
        case .notAuthenticated: return "Not authenticated. Please sign in."
        case .apiError(let message): return message
        case .networkError(let error): return error.localizedDescription
        }
    }
}

// MARK: - Request Models

private struct CreatePlaylistRequest: Codable {
    let snippet: Snippet
    let status: Status
    
    struct Snippet: Codable {
        let title: String
        let description: String
    }
    
    struct Status: Codable {
        let privacyStatus: String
    }
}

private struct AddPlaylistItemRequest: Codable {
    let snippet: Snippet
    
    struct Snippet: Codable {
        let playlistId: String
        let resourceId: ResourceId
        
        struct ResourceId: Codable {
            let kind: String
            let videoId: String
        }
    }
}

@MainActor
class YouTubePlaylistService: ObservableObject {
    static let shared: YouTubePlaylistService = {
        guard let apiKey = Bundle.main.infoDictionary?["YouTubeAPIKey"] as? String else {
            fatalError("YouTube API Key not found in Info.plist. Add 'YouTubeAPIKey' to your Info.plist file.")
        }
        return YouTubePlaylistService(apiKey: apiKey, authService: YouTubeAuthService.shared)
    }()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var playlists: [YouTubePlaylist] = []
    @Published var playlistItems: [YouTubePlaylistItem] = []
    @Published var nextPageToken: String?
    
    private let apiKey: String
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let authService: YouTubeAuthService
    
    init(apiKey: String, authService: YouTubeAuthService) {
        self.apiKey = apiKey
        self.authService = authService
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
    
    func fetchPlaylists() async throws -> [YouTubePlaylist] {
        isLoading = true
        error = nil
        
        guard authService.accessToken != nil else {
            error = "Not authenticated. Please sign in."
            isLoading = false
            throw YouTubePlaylistError.notAuthenticated
        }
        
        do {
            let request = makeRequest(
                path: "playlists?part=snippet,status,contentDetails&mine=true&maxResults=50"
            )
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                throw YouTubePlaylistError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let playlistResponse = try JSONDecoder().decode(YouTubeListResponse<YouTubePlaylist>.self, from: data)
                playlists = playlistResponse.items
                nextPageToken = playlistResponse.nextPageToken
                isLoading = false
                return playlistResponse.items
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
                isLoading = false
                throw YouTubePlaylistError.apiError(errorResponse.error.message)
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw YouTubePlaylistError.networkError(error)
        }
    }
    
    func fetchPlaylistItems(playlistId: String, pageToken: String? = nil) async throws -> [YouTubePlaylistItem] {
        isLoading = true
        error = nil
        
        do {
            var path = "playlistItems?part=snippet,contentDetails&maxResults=50&playlistId=\(playlistId)"
            if let pageToken = pageToken {
                path += "&pageToken=\(pageToken)"
            }
            
            let request = makeRequest(path: path)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                throw YouTubePlaylistError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let itemsResponse = try JSONDecoder().decode(YouTubeListResponse<YouTubePlaylistItem>.self, from: data)
                if pageToken == nil {
                    playlistItems = itemsResponse.items
                } else {
                    playlistItems.append(contentsOf: itemsResponse.items)
                }
                nextPageToken = itemsResponse.nextPageToken
                isLoading = false
                return itemsResponse.items
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
                isLoading = false
                throw YouTubePlaylistError.apiError(errorResponse.error.message)
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw YouTubePlaylistError.networkError(error)
        }
    }
    
    func createPlaylist(name: String, privacy: String) async throws -> Bool {
        isLoading = true
        error = nil
        
        guard authService.accessToken != nil else {
            error = "Not authenticated. Please sign in."
            isLoading = false
            throw YouTubePlaylistError.notAuthenticated
        }
        
        do {
            let playlist = CreatePlaylistRequest(
                snippet: .init(
                    title: name,
                    description: ""
                ),
                status: .init(
                    privacyStatus: privacy
                )
            )
            
            let encoder = JSONEncoder()
            let body = try encoder.encode(playlist)
            
            var request = makeRequest(path: "playlists?part=snippet,status", method: "POST")
            request.httpBody = body
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                throw YouTubePlaylistError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let newPlaylist = try JSONDecoder().decode(YouTubePlaylist.self, from: data)
                playlists.append(newPlaylist)
                isLoading = false
                return true
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
                isLoading = false
                throw YouTubePlaylistError.apiError(errorResponse.error.message)
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw YouTubePlaylistError.networkError(error)
        }
    }
    
    func addVideoToPlaylist(playlistId: String, videoId: String) async throws -> YouTubePlaylistItem {
        isLoading = true
        error = nil
        
        guard authService.accessToken != nil else {
            error = "Not authenticated. Please sign in."
            isLoading = false
            throw YouTubePlaylistError.notAuthenticated
        }
        
        do {
            let playlistItem = AddPlaylistItemRequest(
                snippet: .init(
                    playlistId: playlistId,
                    resourceId: .init(
                        kind: "youtube#video",
                        videoId: videoId
                    )
                )
            )
            
            let encoder = JSONEncoder()
            let body = try encoder.encode(playlistItem)
            
            var request = makeRequest(path: "playlistItems?part=snippet", method: "POST")
            request.httpBody = body
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                throw YouTubePlaylistError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let newItem = try JSONDecoder().decode(YouTubePlaylistItem.self, from: data)
                playlistItems.append(newItem)
                isLoading = false
                return newItem
            } else {
                let errorResponse = try JSONDecoder().decode(YouTubeErrorResponse.self, from: data)
                error = errorResponse.error.message
                isLoading = false
                throw YouTubePlaylistError.apiError(errorResponse.error.message)
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw YouTubePlaylistError.networkError(error)
        }
    }
    
    func removeVideoFromPlaylist(itemId: String) async throws {
        isLoading = true
        error = nil
        
        guard authService.accessToken != nil else {
            error = "Not authenticated. Please sign in."
            isLoading = false
            throw YouTubePlaylistError.notAuthenticated
        }
        
        do {
            let request = makeRequest(path: "playlistItems?id=\(itemId)", method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                throw YouTubePlaylistError.invalidResponse
            }
            
            if httpResponse.statusCode == 204 {
                // Remove the item from our local array
                playlistItems.removeAll { $0.id == itemId }
                isLoading = false
            } else {
                error = "Failed to remove video from playlist"
                isLoading = false
                throw YouTubePlaylistError.apiError("Failed to remove video from playlist")
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw YouTubePlaylistError.networkError(error)
        }
    }
    
    func getPlaylistItemId(playlistId: String, videoId: String) async throws -> String? {
        let items = try await fetchPlaylistItems(playlistId: playlistId)
        return items.first { $0.snippet.resourceId.videoId == videoId }?.id
    }
    
    func deletePlaylist(_ playlist: YouTubePlaylist) async throws -> Bool {
        isLoading = true
        error = nil
        
        guard authService.accessToken != nil else {
            error = "Not authenticated. Please sign in."
            isLoading = false
            throw YouTubePlaylistError.notAuthenticated
        }
        
        do {
            let request = makeRequest(path: "playlists?id=\(playlist.id)", method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                isLoading = false
                throw YouTubePlaylistError.invalidResponse
            }
            
            if httpResponse.statusCode == 204 {
                // Remove the playlist from our local array
                playlists.removeAll { $0.id == playlist.id }
                isLoading = false
                return true
            } else {
                error = "Failed to delete playlist"
                isLoading = false
                throw YouTubePlaylistError.apiError("Failed to delete playlist")
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            throw YouTubePlaylistError.networkError(error)
        }
    }
    
    func clearData() {
        playlists = []
        playlistItems = []
        nextPageToken = nil
        error = nil
        isLoading = false
    }
} 
