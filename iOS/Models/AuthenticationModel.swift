import Foundation
import SwiftData

@Model
final class AuthenticationModel {
    var id: String = UUID().uuidString
    var cookies: String = ""
    var visitorData: String = ""
    var userInfo: YouTubeAuthService.UserInfo?
    var lastUpdated: Date = Date()
    
    init(cookies: String, visitorData: String, userInfo: YouTubeAuthService.UserInfo? = nil) {
        self.cookies = cookies
        self.visitorData = visitorData
        self.userInfo = userInfo
        self.lastUpdated = Date()
    }
} 