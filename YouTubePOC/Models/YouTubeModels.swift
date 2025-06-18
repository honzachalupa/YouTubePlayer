import Foundation

// MARK: - Common Types
struct YouTubeThumbnail: Codable, Equatable {
    let url: String
    let width: Int?
    let height: Int?
}

struct YouTubeThumbnails: Codable, Equatable {
    let `default`: YouTubeThumbnail?
    let medium: YouTubeThumbnail?
    let high: YouTubeThumbnail?
    let standard: YouTubeThumbnail?
    let maxres: YouTubeThumbnail?
}

// MARK: - Video
struct YouTubeVideo: Codable, Identifiable, Equatable {
    let id: String
    let snippet: VideoSnippet
    let contentDetails: ContentDetails?
    let statistics: Statistics?
    
    struct VideoSnippet: Codable, Equatable {
        let publishedAt: String
        let channelId: String
        let title: String
        let description: String
        let thumbnails: YouTubeThumbnails
        let channelTitle: String
        let tags: [String]?
        let categoryId: String?
        let liveBroadcastContent: String?
    }
    
    struct ContentDetails: Codable, Equatable {
        let duration: String?
        let dimension: String?
        let definition: String?
        let caption: String?
        let licensedContent: Bool?
        let projection: String?
    }
    
    struct Statistics: Codable, Equatable {
        let viewCount: String?
        let likeCount: String?
        let favoriteCount: String?
        let commentCount: String?
    }
    
    var bestThumbnail: String {
        if let maxres = snippet.thumbnails.maxres?.url {
            return maxres
        }
        if let standard = snippet.thumbnails.standard?.url {
            return standard
        }
        if let high = snippet.thumbnails.high?.url {
            return high
        }
        if let medium = snippet.thumbnails.medium?.url {
            return medium
        }
        return snippet.thumbnails.default?.url ?? ""
    }
}

// MARK: - Channel
struct YouTubeChannel: Codable, Identifiable, Equatable {
    let id: String
    let snippet: ChannelSnippet
    let statistics: ChannelStatistics?
    
    struct ChannelSnippet: Codable, Equatable {
        let title: String
        let description: String
        let thumbnails: YouTubeThumbnails
        let customUrl: String?
    }
    
    struct ChannelStatistics: Codable, Equatable {
        let viewCount: String?
        let subscriberCount: String?
        let videoCount: String?
    }
}

// MARK: - Playlist
struct YouTubePlaylist: Codable, Identifiable, Equatable {
    let id: String
    let snippet: PlaylistSnippet
    let status: PlaylistStatus
    let contentDetails: PlaylistContentDetails?
    
    static let example = YouTubePlaylist(
        id: "PLWz5rJ2EKKc_xXXubDti2eRnIKU0p7wHd",
        snippet: PlaylistSnippet(
            title: "Android Developer Story",
            description: "Learn how developers built successful apps and games on Android",
            thumbnails: YouTubeThumbnails(
                default: YouTubeThumbnail(
                    url: "https://i.ytimg.com/vi/default.jpg",
                    width: nil,
                    height: nil
                ),
                medium: YouTubeThumbnail(
                    url: "https://i.ytimg.com/vi/medium.jpg",
                    width: nil,
                    height: nil
                ),
                high: YouTubeThumbnail(
                    url: "https://i.ytimg.com/vi/high.jpg",
                    width: nil,
                    height: nil
                ),
                standard: nil,
                maxres: nil
            ),
            channelId: "UCVHFbqXqoYvEWM1Ddxl0QDg",
            channelTitle: "Android Developers"
        ),
        status: PlaylistStatus(privacyStatus: "public"),
        contentDetails: PlaylistContentDetails(itemCount: 42)
    )
    
    struct PlaylistSnippet: Codable, Equatable {
        let title: String
        let description: String?
        let thumbnails: YouTubeThumbnails?
        let channelId: String
        let channelTitle: String
    }
    
    struct PlaylistStatus: Codable, Equatable {
        let privacyStatus: String
    }
    
    struct PlaylistContentDetails: Codable, Equatable {
        let itemCount: Int
    }
}

// MARK: - Playlist Item
struct YouTubePlaylistItem: Codable, Identifiable, Equatable {
    let id: String
    let snippet: PlaylistItemSnippet
    let contentDetails: PlaylistItemContentDetails?
    
    struct PlaylistItemSnippet: Codable, Equatable {
        let publishedAt: String
        let channelId: String
        let title: String
        let description: String
        let thumbnails: YouTubeThumbnails
        let channelTitle: String
        let playlistId: String
        let position: Int
        let resourceId: ResourceId
        
        struct ResourceId: Codable, Equatable {
            let kind: String
            let videoId: String
        }
    }
    
    struct PlaylistItemContentDetails: Codable, Equatable {
        let videoId: String
        let startAt: String?
        let endAt: String?
        let note: String?
    }
}

// MARK: - Search Result
struct YouTubeSearchResult: Codable, Equatable {
    let kind: String?
    let id: SearchResultId
    let snippet: SearchResultSnippet
    
    struct SearchResultId: Codable, Equatable {
        let kind: String?
        let videoId: String?
        let channelId: String?
        let playlistId: String?
    }
    
    struct SearchResultSnippet: Codable, Equatable {
        let publishedAt: String
        let channelId: String
        let title: String
        let description: String
        let thumbnails: YouTubeThumbnails
        let channelTitle: String
        let liveBroadcastContent: String?
    }
}

// MARK: - API Responses
struct YouTubeListResponse<T: Codable & Equatable>: Codable, Equatable {
    let kind: String?
    let etag: String?
    let nextPageToken: String?
    let prevPageToken: String?
    let pageInfo: PageInfo?
    let items: [T]
    
    struct PageInfo: Codable, Equatable {
        let totalResults: Int?
        let resultsPerPage: Int?
    }
}

// MARK: - Error Response
struct YouTubeErrorResponse: Codable, Equatable {
    let error: APIError
    
    struct APIError: Codable, Equatable {
        let code: Int
        let message: String
        let errors: [ErrorDetail]?
        let status: String?
        let details: [ErrorDetail]?
        
        struct ErrorDetail: Codable, Equatable {
            let message: String?
            let domain: String?
            let reason: String?
            let location: String?
            let locationType: String?
            
            enum CodingKeys: String, CodingKey {
                case message
                case domain
                case reason
                case location
                case locationType = "location_type"
            }
        }
    }
}

// MARK: - Subscription
struct YouTubeSubscription: Codable, Identifiable, Equatable {
    let id: String
    let snippet: SubscriptionSnippet
    
    struct SubscriptionSnippet: Codable, Equatable {
        let title: String
        let description: String?
        let resourceId: ResourceId
        let channelId: String
        let thumbnails: YouTubeThumbnails
        
        struct ResourceId: Codable, Equatable {
            let kind: String?
            let channelId: String
        }
    }
} 
