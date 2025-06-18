import Foundation
import SwiftUI
import CryptoKit

extension String {
    func firstMatch(for pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            if let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)) {
                if match.numberOfRanges > 1, // Ensure there's at least one capture group
                   let range = Range(match.range(at: 1), in: self) {
                    return String(self[range])
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        return nil
    }
}

class YouTubeServiceWrapper: ObservableObject {
    @Published var cookies: String {
        didSet {
            UserDefaults.standard.set(cookies, forKey: "ytm_cookies")
        }
    }
    
    @Published var alwaysUseCookies: Bool {
        didSet {
            UserDefaults.standard.set(alwaysUseCookies, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var accessToken: String?
    @Published var visitorData: String = ""
    
    init() {
        self.cookies = UserDefaults.standard.string(forKey: "ytm_cookies") ?? ""
        self.alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
    }
    
    func generateSAPISIDHASH(forCookies cookies: String, time: Int? = nil) -> String? {
        guard let SAPISID = cookies.firstMatch(for: "SAPISID=([^\\s|;]*)") else {
            if cookies.contains("OAUTH_TOKEN=") {
                guard let token = cookies.firstMatch(for: "OAUTH_TOKEN=([^\\s|;]*)") else {
                    return nil
                }
                
                let sapisidValue = String(token.prefix(40))
                let currentTime = time ?? Int(Date().timeIntervalSince1970)
                let hashInput = "\(currentTime) \(sapisidValue) https://www.youtube.com"
                let inputData = Data(hashInput.utf8)
                let hashed = Insecure.SHA1.hash(data: inputData)
                let hashString = hashed.map { String(format: "%02hhx", $0) }.joined()
                
                return "SAPISIDHASH \(currentTime)_\(hashString)"
            }
            return nil
        }
        
        let currentTime = time ?? Int(Date().timeIntervalSince1970)
        let hashInput = "\(currentTime) \(SAPISID) https://www.youtube.com"
        let inputData = Data(hashInput.utf8)
        let hashed = Insecure.SHA1.hash(data: inputData)
        let hashString = hashed.map { String(format: "%02hhx", $0) }.joined()
        
        return "SAPISIDHASH \(currentTime)_\(hashString)"
    }
}

final class YTM {
    private init() {}
    
    private static let wrapper = YouTubeServiceWrapper()
    
    static var shared: YouTubeServiceWrapper {
        return wrapper
    }
    
    static var cookies: String {
        get { shared.cookies }
        set { shared.cookies = newValue }
    }
    
    static var alwaysUseCookies: Bool {
        get { shared.alwaysUseCookies }
        set { shared.alwaysUseCookies = newValue }
    }
    
    static var accessToken: String? {
        get { shared.accessToken }
        set { shared.accessToken = newValue }
    }
    
    static func setup() {
        if let savedCookies = UserDefaults.standard.string(forKey: "ytm_cookies") {
            cookies = savedCookies
            alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
        } else {
            print("YTM: No saved cookies found during setup")
        }
    }
    
    static func reset() {
        print("YTM: Starting reset...")
        
        cookies = ""
        alwaysUseCookies = false
        
        // Clear all stored data
        UserDefaults.standard.removeObject(forKey: "ytm_cookies")
        UserDefaults.standard.removeObject(forKey: "ytm_always_use_cookies")
        UserDefaults.standard.removeObject(forKey: "youtube_access_token")
        UserDefaults.standard.removeObject(forKey: "youtube_user_info")
        UserDefaults.standard.synchronize()
    }
} 
