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