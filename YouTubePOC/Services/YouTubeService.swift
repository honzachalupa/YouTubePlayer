import Foundation
import YouTubeKit
import SwiftUI
import CryptoKit

@MainActor
final class YouTubeService: ObservableObject {
    static let shared = YouTubeService()
    
    let model: YouTubeModel
    
    @Published var cookies: String {
        didSet {
            model.cookies = cookies
            model.alwaysUseCookies = !cookies.isEmpty
            
            UserDefaults.standard.set(cookies, forKey: "ytm_cookies")
            UserDefaults.standard.set(!cookies.isEmpty, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var alwaysUseCookies: Bool {
        didSet {
            model.alwaysUseCookies = alwaysUseCookies
            
            UserDefaults.standard.set(alwaysUseCookies, forKey: "ytm_always_use_cookies")
        }
    }
    
    @Published var accessToken: String?
    
    private init() {
        self.model = YouTubeModel()
        self.cookies = UserDefaults.standard.string(forKey: "ytm_cookies") ?? ""
        self.alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
        
        model.cookies = self.cookies
        model.alwaysUseCookies = self.alwaysUseCookies
        model.selectedLocale = Bundle.main.preferredLocalizations.first ?? "en"
    }
    
    func setup() {
        model.selectedLocale = Bundle.main.preferredLocalizations.first ?? "en"
        
        if let savedCookies = UserDefaults.standard.string(forKey: "ytm_cookies") {
            cookies = savedCookies
            alwaysUseCookies = UserDefaults.standard.bool(forKey: "ytm_always_use_cookies")
        } else {
            print("YouTubeService: No saved cookies found during setup")
        }
    }
    
    func reset() {
        print("YouTubeService: Starting reset...")
        
        cookies = ""
        alwaysUseCookies = false
        
        // Clear all stored data
        UserDefaults.standard.removeObject(forKey: "ytm_cookies")
        UserDefaults.standard.removeObject(forKey: "ytm_always_use_cookies")
        UserDefaults.standard.removeObject(forKey: "youtube_access_token")
        UserDefaults.standard.removeObject(forKey: "youtube_user_info")
        UserDefaults.standard.synchronize()
    }
    
    func getVisitorData() async {
        if model.visitorData.isEmpty {
            do {
                let response = try await HomeScreenResponse.sendThrowingRequest(
                    youtubeModel: model,
                    data: [:],
                    useCookies: true
                )
                
                if let visitorData = response.visitorData {
                    model.visitorData = visitorData
                } else {
                    print("YouTubeService: Couldn't get visitorData, request may fail.")
                }
            } catch {
                print("YouTubeService: Error getting visitor data:", error.localizedDescription)
            }
        }
    }
    
    func generateSAPISIDHASH(forCookies cookies: String, time: Int? = nil) -> String? {
        guard let SAPISID = cookies.ytkFirstGroupMatch(for: "SAPISID=([^\\s|;]*)") else {
            if cookies.contains("OAUTH_TOKEN=") {
                guard let token = cookies.ytkFirstGroupMatch(for: "OAUTH_TOKEN=([^\\s|;]*)") else {
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
