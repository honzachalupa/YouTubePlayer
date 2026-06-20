import Foundation
import SwiftData

@Model
final class AuthenticationModel {
    var id: String = UUID().uuidString
    var cookies: String = ""
    var visitorData: String = ""
    var userInfo: YouTubeUserInfo?
    var lastUpdated: Date = Date()
    
    init(cookies: String, visitorData: String, userInfo: YouTubeUserInfo? = nil) {
        self.cookies = cookies
        self.visitorData = visitorData
        self.userInfo = userInfo
        self.lastUpdated = Date()
    }
}

@Model
final class PlaybackPositionModel {
    var videoId: String = ""
    var positionSeconds: Double = 0
    var durationSeconds: Double?
    var updatedAt: Date = Date()

    init(
        videoId: String,
        positionSeconds: Double,
        durationSeconds: Double? = nil,
        updatedAt: Date = Date()
    ) {
        self.videoId = videoId
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.updatedAt = updatedAt
    }
}
