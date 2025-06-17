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
    
    func clearData() {
        playlists = []
        error = nil
    }
    
    func fetchPlaylists() async {
        isLoading = true
        error = nil
        
        do {
            // First ensure we have visitor data
            if YTM.model.visitorData.isEmpty {
                print("YouTubePlaylistService: No visitor data, fetching...")
                await YTM.shared.getVisitorData()
                
                if YTM.model.visitorData.isEmpty {
                    print("YouTubePlaylistService: Failed to get visitor data")
                    error = "Failed to get visitor data"
                    isLoading = false
                    return
                }
            }
            
            print("YouTubePlaylistService: Fetching playlists...")
            
            // Set up the model with required parameters
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            let localeComponents = locale.components(separatedBy: "_")
            let languageCode = localeComponents[0]
            let countryCode = localeComponents.count > 1 ? localeComponents[1] : "US"
            YTM.model.selectedLocale = "\(languageCode)_\(countryCode)"
            
            // Add required headers
            let customHeaders = HeadersList(
                url: URL(string: "https://www.youtube.com/youtubei/v1/browse")!,
                method: .POST,
                headers: [
                    .init(name: "Accept", content: "*/*"),
                    .init(name: "Accept-Encoding", content: "gzip, deflate, br"),
                    .init(name: "Host", content: "www.youtube.com"),
                    .init(name: "User-Agent", content: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15"),
                    .init(name: "Accept-Language", content: "\(YTM.model.selectedLocale);q=0.9"),
                    .init(name: "Origin", content: "https://www.youtube.com/"),
                    .init(name: "Referer", content: "https://www.youtube.com/"),
                    .init(name: "Content-Type", content: "application/json"),
                    .init(name: "X-Origin", content: "https://www.youtube.com")
                ],
                addQueryAfterParts: [],
                httpBody: [
                    "{\"context\":{\"client\":{\"hl\":\"\(languageCode)\",\"gl\":\"\(countryCode)\",\"visitorData\":\"\(YTM.model.visitorData)\",\"deviceMake\":\"Apple\",\"userAgent\":\"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Safari/605.1.15,gzip(gfe)\",\"clientName\":\"WEB\",\"clientVersion\":\"2.20221220.09.00\",\"osName\":\"Macintosh\",\"osVersion\":\"10_15_7\",\"platform\":\"DESKTOP\",\"clientFormFactor\":\"UNKNOWN_FORM_FACTOR\",\"userInterfaceTheme\":\"USER_INTERFACE_THEME_DARK\",\"timeZone\":\"Europe/Zurich\",\"browserName\":\"Safari\",\"browserVersion\":\"16.2\",\"acceptHeader\":\"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\",\"utcOffsetMinutes\":60,\"mainAppWebInfo\":{\"webDisplayMode\":\"WEB_DISPLAY_MODE_BROWSER\",\"isWebNativeShareAvailable\":true}},\"user\":{\"lockedSafetyMode\":false},\"request\":{\"useSsl\":true,\"internalExperimentFlags\":[],\"consistencyTokenJars\":[]}},\"browseId\":\"FEplaylist_aggregation\"}"
                ],
                parameters: [
                    .init(name: "prettyPrint", content: "false")
                ]
            )
            
            YTM.model.customHeaders[.usersPlaylistsHeaders] = customHeaders
            
            let response = try await AccountPlaylistsResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [:],
                useCookies: true
            )
            
            if response.isDisconnected {
                error = "Not authenticated. Please sign in."
            } else {
                playlists = response.results
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
