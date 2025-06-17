import Foundation
import YouTubeKit
import SwiftUI

@MainActor
class YouTubePlaylistService: ObservableObject {
    static let shared = YouTubePlaylistService()
    
    @Published var playlists: [YTPlaylist] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // Default video ID to use when creating playlists - using a test video that we know works
    private let defaultVideoId = "peIBCNTY8hA"  // Test video from YouTubeKit test case
    
    func clearData() {
        playlists = []
        error = nil
    }
    
    private func setupHeaders(url: String, queryParts: [HeadersList.AddQueryInfo] = [], httpBody: [String]) -> HeadersList {
        // Set up locale for request
        let locale = Bundle.main.preferredLocalizations.first ?? "en"
        let localeComponents = locale.components(separatedBy: "_")
        let languageCode = localeComponents[0]
        let countryCode = localeComponents.count > 1 ? localeComponents[1] : "US"
        YTM.model.selectedLocale = "\(languageCode)_\(countryCode)"
        
        return HeadersList(
            url: URL(string: url)!,
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
            addQueryAfterParts: queryParts,
            httpBody: httpBody
        )
    }
    
    private func getRequestContext(languageCode: String, countryCode: String) -> [String: Any] {
        return [
            "context": [
                "client": [
                    "hl": languageCode,
                    "gl": countryCode,
                    "visitorData": YTM.model.visitorData,
                    "deviceMake": "Apple",
                    "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Safari/605.1.15,gzip(gfe)",
                    "clientName": "WEB",
                    "clientVersion": "2.20221220.09.00",
                    "osName": "Macintosh",
                    "osVersion": "10_15_7",
                    "platform": "DESKTOP",
                    "clientFormFactor": "UNKNOWN_FORM_FACTOR",
                    "userInterfaceTheme": "USER_INTERFACE_THEME_DARK",
                    "timeZone": "Europe/Zurich",
                    "browserName": "Safari",
                    "browserVersion": "16.2",
                    "acceptHeader": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    "utcOffsetMinutes": 60,
                    "mainAppWebInfo": [
                        "webDisplayMode": "WEB_DISPLAY_MODE_BROWSER",
                        "isWebNativeShareAvailable": true
                    ]
                ],
                "user": [
                    "lockedSafetyMode": false
                ],
                "request": [
                    "useSsl": true,
                    "internalExperimentFlags": [],
                    "consistencyTokenJars": []
                ]
            ]
        ]
    }
    
    private func jsonString(from dict: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [])
        return String(data: data, encoding: .utf8)!
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
            
            // Set up locale for request
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            let localeComponents = locale.components(separatedBy: "_")
            let languageCode = localeComponents[0]
            let countryCode = localeComponents.count > 1 ? localeComponents[1] : "US"
            
            // Create request body
            var requestBody = getRequestContext(languageCode: languageCode, countryCode: countryCode)
            requestBody["browseId"] = "FEplaylist_aggregation"
            
            // Add required headers
            let customHeaders = setupHeaders(
                url: "https://www.youtube.com/youtubei/v1/browse",
                httpBody: [jsonString(from: requestBody)]
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
            // First ensure we have visitor data
            if YTM.model.visitorData.isEmpty {
                print("YouTubePlaylistService: No visitor data, fetching...")
                await YTM.shared.getVisitorData()
                
                if YTM.model.visitorData.isEmpty {
                    print("YouTubePlaylistService: Failed to get visitor data")
                    error = "Failed to get visitor data"
                    isLoading = false
                    return false
                }
            }
            
            print("YouTubePlaylistService: Creating playlist '\(name)'...")
            
            // Validate inputs
            guard !name.isEmpty else {
                error = "Playlist name cannot be empty"
                isLoading = false
                return false
            }
            
            // Set up locale for request
            let locale = Bundle.main.preferredLocalizations.first ?? "en"
            let localeComponents = locale.components(separatedBy: "_")
            let languageCode = localeComponents[0]
            let countryCode = localeComponents.count > 1 ? localeComponents[1] : "US"
            
            // Create request body parts
            let baseContext = getRequestContext(languageCode: languageCode, countryCode: countryCode)
            let part1 = """
            {
                "context": \(jsonString(from: baseContext["context"] as! [String: Any])),
                "title": "
            """
            
            let part2 = """
            ",
                "privacyStatus": "
            """
            
            let part3 = """
            ",
                "videoIds": ["
            """
            
            let part4 = """
            "]}
            """
            
            // Add required headers with body parts
            let customHeaders = setupHeaders(
                url: "https://www.youtube.com/youtubei/v1/playlist/create",
                queryParts: [
                    .init(index: 0, encode: false, content: .query),      // For playlist name
                    .init(index: 1, encode: false, content: .params),     // For privacy status
                    .init(index: 2, encode: false, content: .movingVideoId)  // For video ID
                ],
                httpBody: [part1, part2, part3, part4]
            )
            
            YTM.model.customHeaders[.createPlaylistHeaders] = customHeaders
            
            // Create playlist with required parameters
            let response = try await CreatePlaylistResponse.sendThrowingRequest(
                youtubeModel: YTM.model,
                data: [
                    .query: name,                    // Used as title in request body
                    .params: privacy.rawValue,       // Used as privacyStatus in request body
                    .movingVideoId: defaultVideoId   // Used in videoIds array in request body
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
